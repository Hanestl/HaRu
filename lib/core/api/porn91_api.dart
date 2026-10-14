import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

import '../logging/app_log_service.dart';
import '../models/content_source.dart';
import '../models/porn91_models.dart';
import '../models/video_models.dart';
import '../security/error_redaction.dart';
import '../session/session_store.dart';
import 'porn91_parser.dart';
import 'rule34video_api.dart';

/// 91porn 客户端。
///
/// 与其它站点不同，本站点有两条必须处理的反抓取行为（均为实测结论）：
///
/// 1. **会话未预热时会返回别人的视频**：新建会话后第一次打开详情页，
///    站点会把整页替换成另一个视频的详情页（HTTP 200，海报与播放源同时
///    换成同一个无关编号）。实测打开首页不会预热，而请求任意
///    `v.php?category=…` 列表页之后，随后第一次详情页请求就是正确的。
///    因此 [loadVideoDetails] 在真正取详情前先预热会话。
/// 2. **直接播放直链仍可能被折回列表页**：首次带 tokened 直链请求时，
///    响应体是 HTML 而不是视频字节。实测连续播放两次即稳定，
///    因此播放器侧需要允许一次重试（`refreshVideoDetails` 已覆盖）。
final class Porn91Api {
  static const _warmupPath = '/v.php';
  static const _warmupQuery = {'category': 'rf'};
  static const _detailsTtl = Duration(minutes: 5);
  static const _detailsCacheLimit = 60;

  static const browserUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  Porn91Api({
    required this.sessionStore,
    HttpClientAdapter? httpClientAdapter,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ContentSite.porn91.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        followRedirects: true,
        headers: const {
          'User-Agent': browserUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
          // 站点按此头决定标题语言；不带会回落英文，导致标题与浏览器里看到的不一致。
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
        // 站点在限流时会返回 4xx；交给调用方判定具体状态。
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
      _transportLabel = 'injected';
    } else if (Platform.isAndroid) {
      _dio.httpClientAdapter = NativeAdapter(
        createCronetEngine: () => CronetEngine.build(
          userAgent: browserUserAgent,
          enableHttp2: true,
          enableQuic: false,
        ),
      );
      _transportLabel = 'cronet';
    } else {
      _transportLabel = 'dio';
    }
    _dio.interceptors.add(
      CookieManager(sessionStore.cookieJar, ignoreInvalidCookies: true),
    );
  }

  final SessionStore sessionStore;
  late final Dio _dio;
  late final String _transportLabel;
  final Map<String, _Porn91DetailsCacheEntry> _detailsCache = {};
  final Map<String, Future<VideoDetails>> _detailsRequests = {};
  bool _sessionWarmed = false;

  Future<String?> sessionCookieHeader() {
    return sessionStore.cookieHeaderFor(ContentSite.porn91.origin);
  }

  Future<Map<String, String>> mediaHeaders() async {
    return ContentSite.porn91.mediaHeaders(cookie: await sessionCookieHeader());
  }

  /// 列表页。[page] 从 1 开始；站点末页之后不返回空列表而是循环内容，
  /// 因此分页终止由 [VideoFeed] 依据重复条目判定。
  Future<List<VideoItem>> loadCategoryVideos(
    Porn91Category category,
    int page, {
    CancelToken? cancelToken,
  }) async {
    final body = await _get(
      '/v.php',
      query: {
        'category': category.code,
        'viewtype': 'basic',
        ...category.extraQuery,
        if (page > 1) 'page': '$page',
      },
      cancelToken: cancelToken,
    );
    _sessionWarmed = true;
    return Porn91Parser.videoList(body);
  }

  /// 搜索。站点只认 `search_id`；`search_key` 实测返回 0 条。
  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final body = await _get(
      '/search_result.php',
      query: {
        'search_id': normalized,
        'viewtype': 'basic',
        if (page > 1) 'page': '$page',
      },
      cancelToken: cancelToken,
    );
    _sessionWarmed = true;
    return Porn91Parser.videoList(body);
  }

  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    CancelToken? cancelToken,
  }) {
    final key = '${sessionStore.currentUserId ?? 'public'}:${video.id}';
    final cached = _detailsCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _detailsTtl) {
      return Future.value(cached.details);
    }
    final pending = _detailsRequests[key];
    if (pending != null) return pending;
    final request = _fetchVideoDetails(video, cancelToken: cancelToken)
        .then((details) {
          _detailsCache[key] = _Porn91DetailsCacheEntry(
            details: details,
            createdAt: DateTime.now(),
          );
          _pruneDetailsCache();
          return details;
        })
        .whenComplete(() => _detailsRequests.remove(key));
    _detailsRequests[key] = request;
    return request;
  }

  Future<VideoDetails> _fetchVideoDetails(
    VideoItem video, {
    CancelToken? cancelToken,
  }) async {
    // 预热必须发生在详情请求之前：否则站点返回的是另一个视频的详情页，
    // 且该页面自洽（海报编号与播放源编号一致），事后无法识别。
    await _warmSession(cancelToken: cancelToken);
    final body = await _get(
      '/view_video.php',
      query: {'viewkey': video.id, 'viewtype': 'basic'},
      cancelToken: cancelToken,
    );
    return Porn91Parser.videoDetails(source: body, fallback: video);
  }

  Future<void> _warmSession({CancelToken? cancelToken}) async {
    if (_sessionWarmed) return;
    try {
      await _get(
        _warmupPath,
        query: Map<String, dynamic>.from(_warmupQuery),
        cancelToken: cancelToken,
      );
      _sessionWarmed = true;
    } on Object catch (error) {
      // 预热失败不阻断详情请求：最坏情况退化成“可能拿到别人的视频”，
      // 由页面标题与海报编号的差异在日志中暴露。
      unawaited(
        AppLogService.instance.warning(
          '91porn 会话预热失败，直接请求详情；错误=${error.runtimeType}',
          component: 'porn91_network',
        ),
      );
    }
  }

  void _pruneDetailsCache() {
    if (_detailsCache.length <= _detailsCacheLimit) return;
    final entries = _detailsCache.entries.toList()
      ..sort(
        (left, right) => left.value.createdAt.compareTo(right.value.createdAt),
      );
    for (final entry in entries) {
      if (_detailsCache.length <= _detailsCacheLimit) break;
      _detailsCache.remove(entry.key);
    }
  }

  Future<String> _get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw HttpStatusException(status);
      }
      await AppLogService.instance.info(
        '91porn 请求成功；路径=${_logPath(path)}；状态=$status；'
        '耗时=${stopwatch.elapsedMilliseconds}ms；传输=$_transportLabel',
        component: 'porn91_network',
      );
      return response.data ?? '';
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      final status = error.response?.statusCode;
      await AppLogService.instance.warning(
        '91porn 请求失败；路径=${_logPath(path)}；状态=${status ?? 0}；'
        '类型=${error.type.name}',
        component: 'porn91_network',
      );
      throw status == null
          ? const ApiException('网络请求失败，请稍后重试。')
          : HttpStatusException(status);
    }
  }

  String _logPath(String path) => redactSensitiveText(path.split('?').first);

  /// 预热状态仅用于测试断言。
  bool get isSessionWarmed => _sessionWarmed;
}

final class _Porn91DetailsCacheEntry {
  const _Porn91DetailsCacheEntry({
    required this.details,
    required this.createdAt,
  });

  final VideoDetails details;
  final DateTime createdAt;
}
