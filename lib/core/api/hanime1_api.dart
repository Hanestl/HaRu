import 'dart:async';
import 'dart:collection';
import 'dart:io' show Cookie, Platform;

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../logging/app_log_service.dart';
import '../models/account_models.dart';
import '../models/content_source.dart';
import '../models/hanime_comment_models.dart';
import '../models/hanime_library_models.dart';
import '../models/hanime_playlist_models.dart';
import '../models/hanime_search_models.dart';
import '../models/video_models.dart';
import '../security/error_redaction.dart';
import '../session/session_store.dart';
import 'hanime1_parser.dart';
import 'http_adapter_factory.dart';
import 'parse_isolate.dart';
import 'rule34video_api.dart';

final class Hanime1Api {
  static const _homeCacheTtl = Duration(minutes: 30);
  static const _homeChannelFreshTtl = Duration(minutes: 5);
  static const _homeChannelCacheTtl = Duration(minutes: 30);
  static const _homeChannelCacheLimit = 64;

  /// "可信空结果"的缓存时长。
  ///
  /// 空结果有两种来源：站点确实没有内容，和被拦截/重定向后解析出的空壳。
  /// 后者在 [_get] 里已被目标身份校验挡住（会抛 HanimeCloudflareException），
  /// 所以能正常返回的空列表是可信的，应当写进缓存——否则旧的 30 分钟非空
  /// 缓存会在下一次读取时复活，用户看到的列表和刚刚那次刷新结果不一致。
  /// 用较短的 TTL 兼顾"站点恢复后尽快显示内容"。
  static const _emptyResultCacheTtl = Duration(minutes: 2);
  static const _emptyResultFreshTtl = Duration(seconds: 30);

  static const browserUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  Hanime1Api({
    required this.sessionStore,
    this.browserPageHandler,
    HttpClientAdapter? httpClientAdapter,
    this.backgroundRequestInterval = const Duration(milliseconds: 300),
  }) : assert(!backgroundRequestInterval.isNegative) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ContentSite.hanime1.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        followRedirects: true,
        headers: const {
          'User-Agent': browserUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
      _transportLabel = 'injected';
    } else {
      _dio.httpClientAdapter = createHttpAdapter(
        userAgent: browserUserAgent,
        component: 'hanime1_api',
      );
      _transportLabel = Platform.isAndroid ? 'cronet' : 'dio';
    }
    _dio.interceptors.add(
      CookieManager(sessionStore.cookieJar, ignoreInvalidCookies: true),
    );
  }

  final SessionStore sessionStore;

  /// 后台请求完成后至少间隔一小段时间再启动下一个；前台请求不进入此队列。
  final Duration backgroundRequestInterval;
  final Queue<_HanimeBackgroundRequest> _backgroundRequests = Queue();
  _HanimeBackgroundRequest? _activeBackgroundRequest;
  Timer? _backgroundRequestTimer;
  var _closed = false;
  final Future<String?> Function(
    Uri targetUri,
    bool allowForegroundVerification,
  )?
  browserPageHandler;
  late final Dio _dio;
  late final String _transportLabel;
  final Map<String, _HanimeHomeCacheEntry> _homeCache = {};

  /// 按"是否允许前台验证"分开合并首页请求：后台预热发起的请求永远不弹
  /// 卡片，前台用户请求复用它只会拿到空结果，而且看不到任何验证入口。
  final Map<bool, Future<List<HanimeHomeSection>>> _homeRequests = {};
  final Map<String, _HanimeHomeChannelCacheEntry> _homeChannelCache = {};
  final Map<String, Future<List<VideoItem>>> _homeChannelRequests = {};
  _HanimeProfileCacheEntry? _profileCache;
  Future<HanimeAccountProfile?>? _profileRequest;
  final Map<String, _HanimeCommentsCacheEntry> _commentsCache = {};
  final Map<String, Future<List<HanimeComment>>> _commentsRequests = {};

  Future<List<HanimeHomeSection>> loadHomeSections({
    bool force = false,
    bool allowForegroundVerification = true,
  }) async {
    final cached = _homeCache['home'];
    final cachedTtl = cached != null && cached.sections.isEmpty
        ? _emptyResultCacheTtl
        : _homeCacheTtl;
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < cachedTtl) {
      unawaited(
        AppLogService.instance.info(
          'Hanime 首页分区命中缓存；分区=${cached.sections.length}',
          component: 'hanime_home_cache',
        ),
      );
      return cached.sections;
    }
    final pending = _homeRequests[allowForegroundVerification];
    if (!force && pending != null) return pending;
    final request =
        _get(
          '/',
          allowForegroundVerification: allowForegroundVerification,
        ).then((body) async {
          final sections = await _parseHomeSections(body);
          // 与频道缓存同样的取舍：被拦截/身份不符的正文在 [_get] 里已经抛
          // 异常，能走到这里说明这是一份可信的首页文档，空分区也应当写入
          // （否则旧的 30 分钟缓存会在下一次读取时复活）。
          _homeCache['home'] = _HanimeHomeCacheEntry(
            sections: sections,
            createdAt: DateTime.now(),
          );
          return sections;
        });
    _homeRequests[allowForegroundVerification] = request;
    try {
      return await request;
    } finally {
      if (identical(_homeRequests[allowForegroundVerification], request)) {
        _homeRequests.remove(allowForegroundVerification);
      }
    }
  }

  List<HanimeHomeSection> get cachedHomeSections =>
      _homeCache['home']?.sections ?? const [];

  Future<List<VideoItem>> loadHomeChannel(
    String channelKey,
    int page, {
    required HanimeSearchFilters filters,
    bool force = false,
    CancelToken? cancelToken,
    bool allowForegroundVerification = true,
  }) async {
    final cacheKey = '$channelKey:$page';
    if (!force) {
      final cached = _homeChannelCache[cacheKey];
      if (cached != null) {
        final age = DateTime.now().difference(cached.createdAt);
        // 空结果用更短的保留期与新鲜期：它可能是站点真的空了，也可能是
        // 刚刚恢复前的一次空响应，尽快重新确认比长时间沿用更安全。
        final ttl = cached.items.isEmpty
            ? _emptyResultCacheTtl
            : _homeChannelCacheTtl;
        final freshTtl = cached.items.isEmpty
            ? _emptyResultFreshTtl
            : _homeChannelFreshTtl;
        if (age < ttl) {
          final stale = age >= freshTtl;
          unawaited(
            AppLogService.instance.info(
              'Hanime 首页频道命中缓存；频道=$channelKey；页码=$page；'
              '条数=${cached.items.length}；状态=${stale ? '后台刷新' : '新鲜'}；'
              '年龄秒=${age.inSeconds}',
              component: 'hanime_home_cache',
            ),
          );
          if (stale &&
              !_homeChannelRequests.containsKey('$cacheKey#fg=false')) {
            unawaited(
              _requestHomeChannel(
                cacheKey,
                channelKey,
                page,
                filters,
                cancelToken: cancelToken,
                // 后台刷新永远不弹前台验证卡片：用户此刻可能正在别的页面，
                // 卡片闪出来既无上下文也救不回请求。
                allowForegroundVerification: false,
              ).catchError((Object error, StackTrace stackTrace) {
                unawaited(
                  AppLogService.instance.error(
                    error,
                    stackTrace,
                    component: 'hanime_home_refresh:$channelKey',
                  ),
                );
                return cached.items;
              }),
            );
          }
          return cached.items;
        }
      }
    }
    return _requestHomeChannel(
      cacheKey,
      channelKey,
      page,
      filters,
      cancelToken: cancelToken,
      allowForegroundVerification: allowForegroundVerification,
    );
  }

  Future<List<VideoItem>> _requestHomeChannel(
    String cacheKey,
    String channelKey,
    int page,
    HanimeSearchFilters filters, {
    CancelToken? cancelToken,
    required bool allowForegroundVerification,
  }) async {
    // 按"是否允许前台验证"分开合并：后台刷新发起的请求永远不弹卡片，如果让
    // 前台用户请求复用它，用户就会拿到一个注定失败的空结果，卡片也不会出现。
    final requestKey = '$cacheKey#fg=$allowForegroundVerification';
    final pending = _homeChannelRequests[requestKey];
    if (pending != null) {
      unawaited(
        AppLogService.instance.info(
          'Hanime 首页频道合并请求；频道=$channelKey；页码=$page',
          component: 'hanime_home_cache',
        ),
      );
      return pending;
    }
    final request =
        searchVideos(
          '',
          page,
          filters: filters,
          cancelToken: cancelToken,
          allowForegroundVerification: allowForegroundVerification,
        ).then((items) {
          // 空结果同样写缓存，但用更短的 TTL（见 [_emptyResultCacheTtl]）。
          // 之前"空结果跳过写入"会让上一次的非空缓存继续生效：用户刷新后
          // 看到的仍是旧列表，与刚刚这次响应不一致；而真正被拦截/身份不符
          // 的情况在 [_get] 里已经抛异常，走不到这里，不会污染缓存。
          _homeChannelCache.remove(cacheKey);
          _homeChannelCache[cacheKey] = _HanimeHomeChannelCacheEntry(
            items: List.unmodifiable(items),
            createdAt: DateTime.now(),
          );
          while (_homeChannelCache.length > _homeChannelCacheLimit) {
            _homeChannelCache.remove(_homeChannelCache.keys.first);
          }
          unawaited(
            AppLogService.instance.info(
              items.isEmpty
                  ? 'Hanime 首页频道已缓存空结果；频道=$channelKey；页码=$page；'
                        '保留秒=${_emptyResultCacheTtl.inSeconds}'
                  : 'Hanime 首页频道已缓存；频道=$channelKey；页码=$page；'
                        '条数=${items.length}',
              component: 'hanime_home_cache',
            ),
          );
          return items;
        });
    _homeChannelRequests[requestKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_homeChannelRequests[requestKey], request)) {
        _homeChannelRequests.remove(requestKey);
      }
    }
  }

  Future<List<VideoItem>> loadFeed(FeedKind kind, int page) async {
    if (page == 1) {
      final sections = await loadHomeSections();
      final items = sections.expand((section) => section.items).toList();
      if (kind == FeedKind.newest || items.length < 2) return items;
      final sorted = items.toList();
      if (kind == FeedKind.popular) {
        sorted.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
      } else {
        sorted.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      }
      return sorted;
    }
    final path = page > 1 ? '/?page=$page' : '/';
    final body = await _get(path);
    final items = await _parseVideoList(body);
    if (kind == FeedKind.newest || items.length < 2) return items;
    final sorted = items.toList();
    if (kind == FeedKind.popular) {
      sorted.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
    } else {
      sorted.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    }
    return sorted;
  }

  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    HanimeSearchFilters filters = const HanimeSearchFilters(),
    CancelToken? cancelToken,
    bool allowForegroundVerification = true,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty && filters.isEmpty) return const [];
    final stopwatch = Stopwatch()..start();
    final queryParameters = _searchQueryParameters(normalized, page, filters);
    await AppLogService.instance.info(
      'Hanime 搜索发起；query=${_logSearchQuery(normalized)}；'
      '筛选=${_filtersSummary(filters)}；页码=$page',
      component: 'hanime_search',
    );
    final body = await _get(
      '/search',
      query: queryParameters,
      cancelToken: cancelToken,
      allowForegroundVerification: allowForegroundVerification,
    );
    final items = await _parseVideoList(body);
    await AppLogService.instance.info(
      'Hanime 搜索完成；query=${_logSearchQuery(normalized)}；'
      '筛选=${_filtersSummary(filters)}；页码=$page；结果=${items.length}；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_search',
    );
    return items;
  }

  /// 组装 `/search` 的 query 参数。tags/brands 以 `tags[]`/`brands[]`
  /// 重复键形式发送（与 Han1meViewer 的 Retrofit @Query("tags[]") 一致）。
  static Map<String, dynamic> _searchQueryParameters(
    String query,
    int page,
    HanimeSearchFilters filters,
  ) {
    final result = <String, dynamic>{'query': query, 'page': page};
    final genre = filters.genre;
    if (genre != null && genre.trim().isNotEmpty) result['genre'] = genre;
    final sort = filters.sort;
    if (sort != null && sort.trim().isNotEmpty) result['sort'] = sort;
    final date = filters.date?.searchKey;
    if (date != null && date.trim().isNotEmpty) result['date'] = date;
    final duration = filters.duration;
    if (duration != null && duration.trim().isNotEmpty) {
      result['duration'] = duration;
    }
    if (filters.tags.isNotEmpty) result['tags[]'] = filters.tags.toList();
    if (filters.brands.isNotEmpty) result['brands[]'] = filters.brands.toList();
    if (filters.broad) result['broad'] = 'on';
    return result;
  }

  String _filtersSummary(HanimeSearchFilters filters) =>
      hanimeFiltersSummary(filters);

  String _logSearchQuery(String query) {
    final trimmed = query.trim();
    return 'length=${trimmed.length}';
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return '***';
    return '${email.substring(0, 1)}***@${email.substring(at + 1)}';
  }

  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    CancelToken? cancelToken,
    bool allowForegroundVerification = true,
  }) async {
    final body = await _get(
      '/watch',
      query: {'v': video.id},
      cancelToken: cancelToken,
      allowForegroundVerification: allowForegroundVerification,
    );
    final details = await _parseVideoDetails(body, video);
    if (details.sources.isEmpty) {
      throw const ApiException('Hanime 详情页没有返回可播放的视频源。');
    }
    unawaited(
      AppLogService.instance.info(
        'Hanime 详情解析完成；video=${video.id}；sources=${details.sources.length}；'
        'views=${details.video.views ?? -1}；title=${details.descriptionTitle != null}；'
        'descriptionLength=${details.description?.length ?? 0}；'
        'uploader=${details.uploader != null}；liked=${details.hanimeLiked}；'
        'disliked=${details.hanimeDisliked}；saved=${details.isSaved}',
        component: 'hanime_parser',
      ),
    );
    return details;
  }

  static Future<List<HanimeHomeSection>> _parseHomeSections(String body) {
    return parseHtmlOffThread(body, () => HanimePageParser.homeSections(body));
  }

  static Future<List<HanimeComment>> _parseComments(String body) {
    return parseHtmlOffThread(body, () => HanimePageParser.comments(body));
  }

  static Future<List<VideoItem>> _parseVideoList(String body) {
    return parseHtmlOffThread(body, () => HanimePageParser.videoList(body));
  }

  static Future<VideoDetails> _parseVideoDetails(
    String body,
    VideoItem fallback,
  ) {
    return parseHtmlOffThread(
      body,
      () => HanimePageParser.videoDetails(source: body, fallback: fallback),
    );
  }

  Future<String?> sessionCookieHeader() {
    return sessionStore.cookieHeaderFor(ContentSite.hanime1.origin);
  }

  Future<Map<String, String>> mediaHeaders() async {
    return ContentSite.hanime1.mediaHeaders(
      cookie: await sessionCookieHeader(),
    );
  }

  Future<void> importBrowserCookieHeader(String cookieHeader) async {
    final origin = ContentSite.hanime1.origin;
    final cookies = parseBrowserCookieHeader(cookieHeader, origin);
    if (cookies.isNotEmpty) {
      await sessionStore.cookieJar.saveFromResponse(origin, cookies);
      final matched = await sessionStore.cookieJar.loadForRequest(origin);
      await AppLogService.instance.info(
        '浏览器 Cookie 已导入；读取到的名称：${cookieNamesForLog(matched)}',
        component: 'hanime_cookie',
      );
    }
  }

  /// 表单登录：取登录页 CSRF 令牌 → POST /login（关闭重定向跟随以捕获
  /// Set-Cookie）→ 再访问 /login 返回 404 判定成功（Laravel 已登录行为，
  /// 与 Han1meViewer 一致）→ 解析账号信息并记录 hanime 身份。
  Future<HanimeAccountProfile> login({
    required String email,
    required String password,
  }) async {
    final stopwatch = Stopwatch()..start();
    await AppLogService.instance.info(
      'Hanime 登录发起；邮箱=${_maskEmail(email)}',
      component: 'hanime_auth',
    );
    final loginPage = await _get('/login');
    final token = HanimePageParser.loginToken(loginPage);
    if (token == null) {
      await AppLogService.instance.warning(
        '登录页未找到 CSRF 令牌',
        component: 'hanime_auth',
      );
      throw const ApiException('无法获取登录表单的校验令牌。');
    }
    final Response<String> response;
    try {
      response = await _dio.post<String>(
        '/login',
        data: {'_token': token, 'email': email, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'X-CSRF-TOKEN': token,
            'Referer': '${ContentSite.hanime1.baseUrl}/login',
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
    } on DioException catch (error) {
      await AppLogService.instance.warning(
        'Hanime 登录请求失败；类型=${error.type.name}',
        component: 'hanime_auth',
      );
      throw ApiException(
        'Hanime 登录请求失败：${redactSensitiveText(error.message ?? '未知错误')}',
      );
    }
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      await AppLogService.instance.warning(
        'Hanime 登录被拒；HTTP=$status',
        component: 'hanime_auth',
      );
      throw const ApiException('登录失败，请检查账号和密码。');
    }
    final setCookies = response.headers['set-cookie'] ?? const <String>[];
    final cookieHeader = setCookies
        .map((cookie) => cookie.split(';').first.trim())
        .where((pair) => pair.isNotEmpty)
        .join('; ');
    if (cookieHeader.isNotEmpty) {
      await importBrowserCookieHeader(cookieHeader);
    }
    // 登录成功判定：Laravel 登录成功后 POST /login 会 302 重定向到首页
    // （浏览器实测确认），随后首页 user-modal 区块携带登录账号信息。
    // 直接解析首页账号即可判定成功，避免依赖 302/404 的具体差异。
    final home = await _get('/');
    final account = await parseHtmlOffThread(
      home,
      () => HanimePageParser.accountInfo(home),
    );
    final userId = account?.id;
    if (userId == null) {
      await AppLogService.instance.warning(
        '登录未成功（POST 已返回，但首页未携带账号信息）',
        component: 'hanime_auth',
      );
      throw const ApiException('登录失败，请检查账号和密码。');
    }
    await sessionStore.authenticateHanime(userId);
    await sessionStore.saveHanimeCredentials(email: email, password: password);
    var profile = account!;
    try {
      final userPage = await _get('/user/$userId');
      final displayName = account.displayName;
      final avatarUrl = account.avatarUrl;
      profile =
          await parseHtmlOffThread(
            userPage,
            () => HanimePageParser.userPageStats(
              userPage,
              userId: userId,
              displayName: displayName,
              avatarUrl: avatarUrl,
            ),
          ) ??
          account;
    } on Object {
      // 订阅数/视频数为增强信息，解析失败保留基础资料。
    }
    await AppLogService.instance.info(
      'Hanime 登录成功；资料解析=成功；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_auth',
    );
    return profile;
  }

  Future<void> logout() async {
    await AppLogService.instance.info('Hanime 登出发起', component: 'hanime_auth');
    try {
      await _dio.get<String>(
        '/logout',
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
    } on Object catch (error) {
      await AppLogService.instance.warning(
        'Hanime 登出请求失败（忽略）；$error',
        component: 'hanime_auth',
      );
    }
    await sessionStore.clearHanime(forgetCredentials: true);
    await sessionStore.clearCookiesFor(ContentSite.hanime1.origin);
    await AppLogService.instance.info('Hanime 登出完成', component: 'hanime_auth');
  }

  /// 读取当前 hanime 账号资料（来源首页 user-modal 区块）。
  /// 已登录但解析不到用户信息时视为会话过期并自动登出，返回 null。
  /// 带短时缓存（60s）并合并并发请求，避免“我的”页与账号详情页
  /// 反复请求首页导致头像闪现、重复加载。
  Future<HanimeAccountProfile?> loadHanimeAccountProfile({
    bool force = false,
  }) async {
    final cached = _profileCache;
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(seconds: 60)) {
      return cached.profile;
    }
    if (!force && _profileRequest != null) return _profileRequest!;
    final request = _fetchHanimeAccountProfile();
    _profileRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_profileRequest, request)) _profileRequest = null;
    }
  }

  Future<HanimeAccountProfile?> _fetchHanimeAccountProfile() async {
    final body = await _get('/');
    final account = await parseHtmlOffThread(
      body,
      () => HanimePageParser.accountInfo(body),
    );
    if (account == null) {
      await sessionStore.clearHanime();
      await AppLogService.instance.info(
        'Hanime 会话已过期，已自动登出',
        component: 'hanime_account',
      );
      return null;
    }
    _profileCache = _HanimeProfileCacheEntry(
      profile: account,
      createdAt: DateTime.now(),
    );
    await AppLogService.instance.info(
      'Hanime 账号资料已读取；状态=有效',
      component: 'hanime_account',
    );
    return account;
  }

  String? get _hanimeUserId => sessionStore.hanimeUserId;

  /// 当前账号的点赞列表（`user/{id}/likes?page=N`，需登录）。
  Future<List<VideoItem>> loadLikes(int page) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/user/$userId/likes', query: {'page': page});
    final items = await _parseVideoList(body);
    await AppLogService.instance.info(
      'Hanime 点赞列表加载；页码=$page；结果=${items.length}',
      component: 'hanime_library',
    );
    return items;
  }

  /// 当前账号的稍后观看列表（`user/{id}/saves?page=N`，需登录）。
  Future<List<VideoItem>> loadSaves(int page) async {
    final userId = _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final body = await _get('/user/$userId/saves', query: {'page': page});
    final items = await _parseVideoList(body);
    await AppLogService.instance.info(
      'Hanime 稍后观看加载；页码=$page；结果=${items.length}；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
    return items;
  }

  /// 当前账号的在线观看历史（需登录）。
  Future<List<VideoItem>> loadWatchHistory(
    int page, {
    HanimeHistorySort sort = HanimeHistorySort.latest,
  }) async {
    final userId = _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final body = await _get(
      '/user/$userId/histories',
      query: {'sort': sort.queryValue, 'page': page},
    );
    final items = await _parseVideoList(body);
    await AppLogService.instance.info(
      'Hanime 在线历史加载；排序=${sort.queryValue}；页码=$page；'
      '结果=${items.length}；耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
    return items;
  }

  /// 当前账号订阅的作者与更新视频（`subscriptions?page=N`，需登录）。
  Future<HanimeSubscriptionPage> loadSubscriptionPage(int page) async {
    _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final body = await _get('/subscriptions', query: {'page': page});
    final result = await parseHtmlOffThread(
      body,
      () => HanimePageParser.subscriptionPage(body),
    );
    await AppLogService.instance.info(
      'Hanime 订阅加载；页码=$page；作者=${result.artists.length}；'
      '视频=${result.videos.length}；耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
    return result;
  }

  /// 当前账号的播放列表（`user/{id}/playlists?page=N`，需登录）。
  Future<List<HanimePlaylist>> loadPlaylists(int page) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/user/$userId/playlists', query: {'page': page});
    final items = await parseHtmlOffThread(
      body,
      () => HanimePageParser.playlists(body),
    );
    await AppLogService.instance.info(
      'Hanime 播放列表加载；页码=$page；结果=${items.length}',
      component: 'hanime_library',
    );
    return items;
  }

  /// 单个播放列表内容（`playlist?list={listCode}&page=N`，公开）。
  Future<List<VideoItem>> loadPlaylistVideos(String listCode, int page) async {
    final body = await _get(
      '/playlist',
      query: {'list': listCode, 'page': page},
    );
    final items = await _parseVideoList(body);
    await AppLogService.instance.info(
      'Hanime 播放列表内容加载；list=$listCode；页码=$page；结果=${items.length}',
      component: 'hanime_library',
    );
    return items;
  }

  /// 点赞/取消点赞视频（POST /like）。like-status 空串=添加、"1"=取消
  /// （与 Han1meViewer 一致）；成功返回目标状态。
  Future<bool> setLike(String videoId, {required bool liked}) async {
    final userId = _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final detailBody = await _get('/watch', query: {'v': videoId});
    final current = HanimePageParser.videoRatingState(detailBody).liked;
    if (current == liked) {
      await AppLogService.instance.info(
        'Hanime 点赞状态已符合目标；video=$videoId；liked=$liked',
        component: 'hanime_library',
      );
      return liked;
    }
    final token = HanimePageParser.loginToken(detailBody);
    if (token == null) {
      await AppLogService.instance.warning(
        '详情页未找到 CSRF 令牌',
        component: 'hanime_library',
      );
      throw const ApiException('无法获取操作令牌。');
    }
    final response = await _dio.post<String>(
      '/like',
      data: {
        '_token': token,
        'like-foreign-id': videoId,
        'like-status': liked ? '' : '1',
        'like-user-id': userId,
        'like-is-positive': '1',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-TOKEN': token},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    _checkResponseStatus(
      response,
      action: 'Hanime 点赞操作',
      component: 'hanime_library',
      path: '/like',
    );
    await AppLogService.instance.info(
      'Hanime 点赞${liked ? '已添加' : '已取消'}；video=$videoId；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
    return liked;
  }

  /// 加入或移出稍后观看。站点以 `input_id=save` 表示内建待看清单。
  Future<bool> setSaved(String videoId, {required bool saved}) async {
    _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final detailBody = await _get('/watch', query: {'v': videoId});
    final current = HanimePageParser.videoSavedState(detailBody);
    if (current == saved) {
      await AppLogService.instance.info(
        'Hanime 稍后观看状态已符合目标；video=$videoId；saved=$saved',
        component: 'hanime_library',
      );
      return saved;
    }
    final token = HanimePageParser.loginToken(detailBody);
    if (token == null) {
      await AppLogService.instance.warning(
        'Hanime 稍后观看操作缺少 CSRF 令牌',
        component: 'hanime_library',
      );
      throw const ApiException('无法获取操作令牌。');
    }
    await _postLibraryForm('/save', {
      '_token': token,
      'input_id': 'save',
      'video_id': videoId,
      'is_checked': saved.toString(),
      'user_id': '',
    });
    await AppLogService.instance.info(
      'Hanime 稍后观看${saved ? '已加入' : '已移出'}；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
    return saved;
  }

  /// 删除单条在线观看历史。
  Future<void> deleteWatchHistory(String videoId) async {
    _requireHanimeLogin();
    final stopwatch = Stopwatch()..start();
    final detailBody = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(detailBody);
    if (token == null) {
      await AppLogService.instance.warning(
        'Hanime 历史删除缺少 CSRF 令牌',
        component: 'hanime_library',
      );
      throw const ApiException('无法获取操作令牌。');
    }
    final response = await _dio.delete<String>(
      '/user/tab-item/$videoId',
      data: {'tab': 'histories'},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-TOKEN': token},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    _checkResponseStatus(
      response,
      action: 'Hanime 历史删除',
      component: 'hanime_library',
      path: '/user/tab-item/$videoId',
    );
    await AppLogService.instance.info(
      'Hanime 历史已删除；耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_library',
    );
  }

  void _checkResponseStatus(
    Response<dynamic> response, {
    required String action,
    required String component,
    String? path,
  }) {
    final status = response.statusCode ?? 0;
    final location = response.headers.value('location') ?? '';
    if ((status >= 300 && status < 400 && location.contains('/login')) ||
        status >= 400) {
      unawaited(
        AppLogService.instance.warning(
          '$action失败；${path != null ? '路径=$path；' : ''}HTTP=$status；Location=$location',
          component: component,
        ),
      );
      if (location.contains('/login')) {
        throw const SessionExpiredException();
      }
      throw HttpStatusException(status);
    }
    if (status >= 300 && status < 400) {
      // followRedirects=false 时非登录重定向会被当作成功返回；站点在校验失败、
      // CSRF 失效或限流时也可能 302 回原页面，这里保留 warning 以便排查，
      // 但仍按成功处理（库操作成功后是否返回 302 尚未抓包确认，见
      // review-v6 新问题 A）。
      unawaited(
        AppLogService.instance.warning(
          '$action返回重定向，按成功处理；${path != null ? '路径=$path；' : ''}'
          'HTTP=$status；Location=${location.isEmpty ? '(无)' : location}',
          component: component,
        ),
      );
    }
  }

  Future<void> _postLibraryForm(String path, Map<String, String> data) async {
    final response = await _dio.post<String>(
      path,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-TOKEN': data['_token'] ?? ''},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    _checkResponseStatus(
      response,
      action: 'Hanime 媒体库操作',
      component: 'hanime_library',
      path: path,
    );
    final errors = HanimePageParser.formErrors(response.data ?? '');
    if (errors.isNotEmpty) {
      throw ApiException(errors.first);
    }
  }

  Future<void> setPlaylistMembership(
    String videoId,
    String listCode, {
    required bool included,
  }) async {
    _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/save', {
      '_token': token,
      'input_id': listCode,
      'video_id': videoId,
      'is_checked': included.toString(),
      'user_id': '',
    });
    await AppLogService.instance.info(
      'Hanime 播放列表成员已更新；action=${included ? 'add' : 'remove'}',
      component: 'hanime_library',
    );
  }

  Future<void> createPlaylist({
    required String videoId,
    required String title,
    String description = '',
  }) async {
    _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/createPlaylist', {
      '_token': token,
      'create-playlist-video-id': videoId,
      'playlist-title': title,
      'playlist-description': description,
    });
    await AppLogService.instance.info(
      'Hanime 播放列表已创建；标题长度=${title.length}',
      component: 'hanime_library',
    );
  }

  Future<void> updatePlaylist(
    String listCode, {
    required String title,
    String description = '',
  }) async {
    _requireHanimeLogin();
    final body = await _get('/playlist', query: {'list': listCode});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/playlist/$listCode', {
      '_token': token,
      '_method': 'PUT',
      'playlist-title': title,
      'playlist-description': description,
    });
    await AppLogService.instance.info(
      'Hanime 播放列表资料已更新；标题长度=${title.length}',
      component: 'hanime_library',
    );
  }

  Future<void> deletePlaylist(String listCode) async {
    _requireHanimeLogin();
    final body = await _get('/playlist', query: {'list': listCode});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/playlist/$listCode', {
      '_token': token,
      '_method': 'PUT',
      'playlist-delete': 'on',
    });
    await AppLogService.instance.info(
      'Hanime 播放列表已删除',
      component: 'hanime_library',
    );
  }

  Future<void> removePlaylistVideo(
    String listCode,
    String videoId, {
    int count = 1,
  }) async {
    _requireHanimeLogin();
    final body = await _get('/playlist', query: {'list': listCode});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/deletePlayitem', {
      '_token': token,
      'playlist_id': listCode,
      'video_id': videoId,
      'count': '$count',
    });
    await AppLogService.instance.info(
      'Hanime 播放列表视频已移除',
      component: 'hanime_library',
    );
  }

  Future<bool> setArtistSubscribed(
    String videoId, {
    required bool subscribed,
  }) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final current = HanimePageParser.videoSubscriptionState(body);
    if (current == subscribed) {
      await AppLogService.instance.info(
        'Hanime 作者订阅状态已符合目标；subscribed=$subscribed',
        component: 'hanime_library',
      );
      return subscribed;
    }
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    final artistId = HanimePageParser.subscriptionArtistId(body);
    if (artistId == null) throw const ApiException('无法识别视频作者。');
    await _postLibraryForm('/subscribe', {
      '_token': token,
      'subscribe-user-id': userId,
      'subscribe-artist-id': artistId,
      'subscribe-status': subscribed ? '' : '1',
    });
    await AppLogService.instance.info(
      'Hanime 作者订阅已更新；subscribed=$subscribed',
      component: 'hanime_library',
    );
    return subscribed;
  }

  Future<void> rateVideo(String videoId, {required bool positive}) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    final state = HanimePageParser.videoRatingState(body);
    await _postLibraryForm('/like', {
      '_token': token,
      'like-foreign-id': videoId,
      'like-is-positive': positive ? '1' : '0',
      'like-status': state.liked ? '1' : '',
      'unlike-status': state.disliked ? '1' : '',
      'likes-count': '${state.likes}',
      'unlikes-count': '${state.dislikes}',
      'like-user-id': userId,
    });
    await AppLogService.instance.info(
      'Hanime 视频评分已提交；positive=$positive',
      component: 'hanime_video',
    );
  }

  Future<bool> setDislike(String videoId, {required bool disliked}) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final state = HanimePageParser.videoRatingState(body);
    if (state.disliked == disliked) {
      await AppLogService.instance.info(
        'Hanime 踩状态已符合目标；video=$videoId；disliked=$disliked',
        component: 'hanime_video',
      );
      return disliked;
    }
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/like', {
      '_token': token,
      'like-foreign-id': videoId,
      'like-is-positive': '0',
      'like-status': state.liked ? '1' : '',
      'unlike-status': state.disliked ? '1' : '',
      'likes-count': '${state.likes}',
      'unlikes-count': '${state.dislikes}',
      'like-user-id': userId,
    });
    await AppLogService.instance.info(
      'Hanime 踩状态已更新；video=$videoId；disliked=$disliked',
      component: 'hanime_video',
    );
    return disliked;
  }

  Future<HanimeAccountEditData> loadAccountEditData() async {
    final userId = _requireHanimeLogin();
    final body = await _get('/user/$userId/edit');
    final data = await parseHtmlOffThread(
      body,
      () => HanimePageParser.accountEditData(body),
    );
    if (data == null) throw const ApiException('无法解析账号编辑资料。');
    return data;
  }

  Future<void> updateAccountProfile({
    required String name,
    required String email,
  }) async {
    final userId = _requireHanimeLogin();
    final edit = await loadAccountEditData();
    await _postLibraryForm('/user/$userId', {
      '_token': edit.token,
      '_method': 'patch',
      'type': 'profile',
      'name': name,
      'email': email,
    });
    _profileCache = null;
    await AppLogService.instance.info(
      'Hanime 账号资料已更新；名称长度=${name.length}',
      component: 'hanime_account',
    );
  }

  Future<void> updateAccountPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final userId = _requireHanimeLogin();
    final edit = await loadAccountEditData();
    await _postLibraryForm('/user/$userId', {
      '_token': edit.token,
      '_method': 'patch',
      'type': 'password',
      'password_old': oldPassword,
      'password_new': newPassword,
      'password_new_confirm': newPassword,
    });
    await AppLogService.instance.info(
      'Hanime 账号密码已更新',
      component: 'hanime_account',
    );
  }

  Future<void> updateAccountAvatar(String filePath) async {
    final userId = _requireHanimeLogin();
    final edit = await loadAccountEditData();
    final response = await _dio.post<String>(
      '/user/$userId',
      data: FormData.fromMap({
        '_token': edit.token,
        '_method': 'patch',
        'type': 'photo',
        'photo': await MultipartFile.fromFile(filePath),
      }),
      options: Options(
        headers: {'X-CSRF-TOKEN': edit.token},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    _checkResponseStatus(
      response,
      action: 'Hanime 账号头像上传',
      component: 'hanime_account',
      path: '/user/$userId',
    );
    final errors = HanimePageParser.formErrors(response.data ?? '');
    if (errors.isNotEmpty) throw ApiException(errors.first);
    _profileCache = null;
    await AppLogService.instance.info(
      'Hanime 账号头像已更新',
      component: 'hanime_account',
    );
  }

  Future<void> reportComment({
    required String videoId,
    required String commentId,
    required String reason,
    String reportableType = 'comment',
  }) async {
    final userId = _requireHanimeLogin();
    final body = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(body);
    if (token == null) throw const ApiException('无法获取操作令牌。');
    await _postLibraryForm('/user/$userId/report', {
      '_token': token,
      'redirect-url': '/watch?v=$videoId',
      'reportable-id': commentId,
      'reportable-type': reportableType,
      'reason': reason,
    });
    await AppLogService.instance.info(
      'Hanime 评论举报已提交；原因长度=${reason.length}',
      component: 'hanime_comment',
    );
  }

  String _requireHanimeLogin() {
    final userId = _hanimeUserId;
    if (userId == null) {
      throw const ApiException('请先登录 Hanime 账号。');
    }
    return userId;
  }

  /// 加载视频评论列表（`loadComment?type=video&id=`，公开可读）。
  /// 带短时缓存（60s）并合并并发请求：详情页评论 Tab 切换、刷新时
  /// 不会反复请求同一视频的评论。
  Future<List<HanimeComment>> loadComments(String videoId) async {
    final cacheKey = videoId;
    final cached = _commentsCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(seconds: 60)) {
      return cached.comments;
    }
    final pending = _commentsRequests[cacheKey];
    if (pending != null) return pending;
    final request = () async {
      final stopwatch = Stopwatch()..start();
      final body = await _get(
        '/loadComment',
        query: {'type': 'video', 'id': videoId},
      );
      final comments = await _parseComments(body);
      _commentsCache[cacheKey] = _HanimeCommentsCacheEntry(
        comments: comments,
        createdAt: DateTime.now(),
      );
      await AppLogService.instance.info(
        'Hanime 评论加载；video=$videoId；结果=${comments.length}；'
        '耗时=${stopwatch.elapsedMilliseconds}ms',
        component: 'hanime_comment',
      );
      return comments;
    }();
    _commentsRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      _commentsRequests.remove(cacheKey);
    }
  }

  /// 加载评论回复（`loadReplies?id=`，公开可读）。
  Future<List<HanimeComment>> loadReplies(String commentId) async {
    final stopwatch = Stopwatch()..start();
    final body = await _get('/loadReplies', query: {'id': commentId});
    final comments = await _parseComments(body);
    await AppLogService.instance.info(
      'Hanime 评论回复加载；comment=$commentId；结果=${comments.length}；'
      '耗时=${stopwatch.elapsedMilliseconds}ms',
      component: 'hanime_comment',
    );
    return comments;
  }

  /// 提取详情页 CSRF 令牌（发表/回复/赞踩评论共用）。
  Future<String> _csrfTokenFor(String videoId) async {
    final body = await _get('/watch', query: {'v': videoId});
    final token = HanimePageParser.loginToken(body);
    if (token == null) {
      await AppLogService.instance.warning(
        '详情页未找到 CSRF 令牌；video=$videoId',
        component: 'hanime_comment',
      );
      throw const ApiException('无法获取操作令牌。');
    }
    return token;
  }

  Future<void> _postForm(String path, Map<String, String> data) async {
    final response = await _dio.post<String>(
      path,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-TOKEN': data['_token'] ?? ''},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    _checkResponseStatus(
      response,
      action: 'Hanime 评论操作',
      component: 'hanime_comment',
      path: path,
    );
  }

  /// 发表评论（POST /createComment，需登录）。
  Future<void> createComment({
    required String videoId,
    required String text,
  }) async {
    final userId = _requireHanimeLogin();
    final token = await _csrfTokenFor(videoId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ApiException('评论内容不能为空。');
    }
    await _postForm('/createComment', {
      '_token': token,
      'comment-user-id': userId,
      'comment-type': 'video',
      'comment-foreign-id': videoId,
      'comment-text': trimmed,
      'comment-count': '1',
      'comment-is-political': '0',
    });
    await AppLogService.instance.info(
      'Hanime 评论已发表；video=$videoId；长度=${trimmed.length}',
      component: 'hanime_comment',
    );
  }

  /// 回复评论（POST /replyComment，需登录；token 从目标视频详情页提取）。
  Future<void> replyComment({
    required String videoId,
    required String commentId,
    required String text,
  }) async {
    _requireHanimeLogin();
    final token = await _csrfTokenFor(videoId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ApiException('回复内容不能为空。');
    }
    await _postForm('/replyComment', {
      '_token': token,
      'reply-comment-id': commentId,
      'reply-comment-text': trimmed,
    });
    await AppLogService.instance.info(
      'Hanime 评论回复已发表；comment=$commentId；长度=${trimmed.length}',
      component: 'hanime_comment',
    );
  }

  /// 赞/踩评论（POST /commentLike，需登录）。
  Future<void> likeComment({
    required String videoId,
    required String commentId,
    required bool positive,
    bool? liked,
    bool? disliked,
    int likesCount = 1,
    int likesSum = 1,
  }) async {
    final userId = _requireHanimeLogin();
    final token = await _csrfTokenFor(videoId);
    await _postForm('/commentLike', {
      '_token': token,
      'foreign_type': 'comment',
      'foreign_id': commentId,
      'is_positive': positive ? '1' : '0',
      'comment-like-user-id': userId,
      'comment-likes-count': '$likesCount',
      'comment-likes-sum': '$likesSum',
      'like-comment-status': (liked ?? positive) ? '1' : '0',
      'unlike-comment-status': (disliked ?? !positive) ? '1' : '0',
    });
    await AppLogService.instance.info(
      'Hanime 评论${positive ? '赞' : '踩'}；comment=$commentId',
      component: 'hanime_comment',
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _backgroundRequestTimer?.cancel();
    final active = _activeBackgroundRequest;
    if (active != null) _cancelBackgroundRequest(active);
    for (final request in _backgroundRequests) {
      _cancelBackgroundRequest(request);
    }
    _backgroundRequests.clear();
    _dio.close(force: true);
  }

  Future<String> _get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool allowBrowserFallback = true,
    bool allowForegroundVerification = true,
  }) {
    if (_closed || (cancelToken?.isCancelled ?? false)) {
      return Future.error(const RequestCancelledException());
    }
    if (allowForegroundVerification) {
      return _getNow(
        path,
        query: query,
        cancelToken: cancelToken,
        allowBrowserFallback: allowBrowserFallback,
      );
    }
    final token = CancelToken();
    final request = _HanimeBackgroundRequest(
      token: token,
      operation: () => _getNow(
        path,
        query: query,
        cancelToken: token,
        allowBrowserFallback: allowBrowserFallback,
        allowForegroundVerification: false,
      ),
    );
    _backgroundRequests.add(request);
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel.then((_) {
          if (request.completer.isCompleted) return;
          _backgroundRequests.remove(request);
          _cancelBackgroundRequest(request);
        }),
      );
    }
    _startNextBackgroundRequest();
    return request.completer.future;
  }

  void _cancelBackgroundRequest(_HanimeBackgroundRequest request) {
    request.token.cancel('后台请求已取消');
    if (!request.completer.isCompleted) {
      request.completer.completeError(const RequestCancelledException());
    }
  }

  void _startNextBackgroundRequest() {
    if (_closed ||
        _activeBackgroundRequest != null ||
        _backgroundRequestTimer != null ||
        _backgroundRequests.isEmpty) {
      return;
    }
    final request = _backgroundRequests.removeFirst();
    _activeBackgroundRequest = request;
    unawaited(() async {
      try {
        final body = await request.operation();
        if (!request.completer.isCompleted) request.completer.complete(body);
      } on Object catch (error, stackTrace) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(error, stackTrace);
        }
      } finally {
        _activeBackgroundRequest = null;
        if (!_closed) {
          _backgroundRequestTimer = Timer(backgroundRequestInterval, () {
            _backgroundRequestTimer = null;
            _startNextBackgroundRequest();
          });
        }
      }
    }());
  }

  Future<String> _getNow(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool allowBrowserFallback = true,
    bool allowForegroundVerification = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final body = response.data ?? '';
      if (response.statusCode == 403 || HanimePageParser.isChallenge(body)) {
        await AppLogService.instance.warning(
          'Hanime 请求被拦截；HTTP=${response.statusCode ?? 0}；'
          '请求 Cookie 名称：${cookieHeaderNamesForLog(response.requestOptions.headers['Cookie'])}',
          component: 'hanime_network',
        );
        final browserBody = await _browserBody(
          response.requestOptions.uri,
          allowBrowserFallback: allowBrowserFallback,
          allowForegroundVerification: allowForegroundVerification,
        );
        if (browserBody != null) {
          return _retryAfterBrowser(
            path,
            query: query,
            cancelToken: cancelToken,
            browserBody: browserBody,
            statusCode: response.statusCode,
            targetUri: response.requestOptions.uri,
          );
        }
        throw HanimeCloudflareException(statusCode: response.statusCode);
      }
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw HttpStatusException(response.statusCode ?? 0);
      }
      await AppLogService.instance.info(
        'Hanime 请求成功；路径=${_logPath(path)}；'
        '状态=${response.statusCode}；耗时=${stopwatch.elapsedMilliseconds}ms；'
        '传输=$_transportLabel',
        component: 'hanime_network',
      );
      return body;
    } on HanimeCloudflareException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      if (_supportsBrowserFallback(error)) {
        await AppLogService.instance.warning(
          'Hanime 请求失败并启用浏览器兜底；类型=${error.type.name}；'
          '请求 Cookie 名称：${cookieHeaderNamesForLog(error.requestOptions.headers['Cookie'])}',
          component: 'hanime_network',
        );
        final browserBody = await _browserBody(
          error.requestOptions.uri,
          allowBrowserFallback: allowBrowserFallback,
          allowForegroundVerification: allowForegroundVerification,
        );
        if (browserBody != null) {
          return _retryAfterBrowser(
            path,
            query: query,
            cancelToken: cancelToken,
            browserBody: browserBody,
            statusCode: error.response?.statusCode,
            targetUri: error.requestOptions.uri,
          );
        }
      }
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode >= 400) {
        throw HttpStatusException(statusCode);
      }
      throw ApiException(
        'Hanime 网络请求失败：${redactSensitiveText(error.message ?? '未知错误')}',
      );
    }
  }

  Future<String> _retryAfterBrowser(
    String path, {
    required Map<String, dynamic>? query,
    required CancelToken? cancelToken,
    required String browserBody,
    required int? statusCode,
    required Uri targetUri,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final body = response.data ?? '';
      if (response.statusCode != null &&
          response.statusCode! < 400 &&
          !HanimePageParser.isChallenge(body)) {
        // 原生重试成功也要验一遍身份：跟随重定向后拿到的 200 可能是登录页、
        // 站点维护页或别的视频详情页，直接当成本次请求的正文会污染上层缓存。
        final inspection = HanimePageParser.inspectBrowserDocument(
          source: body,
          targetUri: targetUri,
        );
        if (inspection.isTarget) {
          await AppLogService.instance.info(
            '浏览器验证后原请求重试成功；路径=${_logPath(path)}；'
            '状态=${response.statusCode}；耗时=${stopwatch.elapsedMilliseconds}ms；'
            '传输=$_transportLabel',
            component: 'hanime_network',
          );
          return body;
        }
        await AppLogService.instance.warning(
          '浏览器验证后原请求返回了非目标文档；路径=${_logPath(path)}；'
          '状态=${response.statusCode ?? 0}；'
          '文档状态=${inspection.status.name}；文档类型=${inspection.kind.name}；'
          '原因=${inspection.reason}',
          component: 'hanime_network',
        );
      } else {
        await AppLogService.instance.warning(
          '浏览器验证后原请求仍被拦截；路径=${_logPath(path)}；'
          '状态=${response.statusCode ?? 0}；'
          '请求 Cookie 名称：${cookieHeaderNamesForLog(response.requestOptions.headers['Cookie'])}',
          component: 'hanime_network',
        );
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      await AppLogService.instance.warning(
        '浏览器验证后原请求重试失败；路径=${_logPath(path)}；'
        '类型=${error.type.name}；底层=${error.error.runtimeType}；'
        '诊断=${redactSensitiveText(error.message, maxLength: 180)}；'
        '耗时=${stopwatch.elapsedMilliseconds}ms；'
        '请求 Cookie 名称：${cookieHeaderNamesForLog(error.requestOptions.headers['Cookie'])}',
        component: 'hanime_network',
      );
      return _adoptBrowserBody(
        browserBody,
        path: path,
        statusCode: statusCode,
        targetUri: targetUri,
      );
    }
    return _adoptBrowserBody(
      browserBody,
      path: path,
      statusCode: statusCode,
      targetUri: targetUri,
    );
  }

  /// 浏览器兜底正文是否可以当作本次请求的响应返回。
  ///
  /// 原生重试已经失败，说明这次"验证"并没有让 Cloudflare 放行。此前这里直接
  /// `return browserBody`，把浏览器里的那份 HTML 当成成功响应交给上层：
  /// 它常常是 403 文本页、登录页或上一次导航残留的文档，解析出 0 条结果后
  /// 还会被写进 30 分钟频道缓存（日志里 18 次"结果=0"与空白频道都源于此）。
  ///
  /// 判据不能是字符串 contains（脚本里的类名、注释、隐藏模板都能骗过它），
  /// 必须是完整 DOM 结构 + 目标身份：正文里的 canonical/og:url 与请求 URI
  /// 一致、且该页面类型该有的业务容器存在。
  Future<String> _adoptBrowserBody(
    String browserBody, {
    required String path,
    required int? statusCode,
    required Uri targetUri,
  }) async {
    final inspection = HanimePageParser.inspectBrowserDocument(
      source: browserBody,
      targetUri: targetUri,
    );
    if (inspection.isTarget) {
      await AppLogService.instance.info(
        '浏览器兜底正文被采用；路径=${_logPath(path)}；'
        '状态=${statusCode ?? 0}；类型=${inspection.kind.name}；'
        '长度=${browserBody.length}',
        component: 'hanime_network',
      );
      return browserBody;
    }
    await AppLogService.instance.warning(
      '浏览器兜底正文与请求目标不一致，不予采用；路径=${_logPath(path)}；'
      '状态=${statusCode ?? 0}；文档状态=${inspection.status.name}；'
      '文档类型=${inspection.kind.name}；原因=${inspection.reason}',
      component: 'hanime_network',
    );
    throw HanimeCloudflareException(statusCode: statusCode);
  }

  Future<String?> _browserBody(
    Uri targetUri, {
    required bool allowBrowserFallback,
    required bool allowForegroundVerification,
  }) async {
    final handler = browserPageHandler;
    if (!allowBrowserFallback || handler == null) return null;
    final body = await handler(targetUri, allowForegroundVerification);
    if (body == null ||
        body.trim().isEmpty ||
        HanimePageParser.isChallenge(body) ||
        _isBrowserErrorPage(body)) {
      return null;
    }
    return body;
  }

  bool _isBrowserErrorPage(String body) {
    final lower = body.toLowerCase();
    return lower.contains('chrome-error://') ||
        lower.contains('net::err_') ||
        lower.contains('err_connection_refused') ||
        lower.contains('webpage not available');
  }

  /// 哪些 Dio 异常值得弹一次浏览器辅助验证。
  ///
  /// 只有 `connectionError`（连接被重置/握手失败，常见于 Cloudflare 直接断开
  /// Cronet 连接）才可能是"被拦截"的表现。超时（connection/send/receive）与
  /// `unknown` 属于普通网络抖动，把它们也当成拦截会让一次弱网就闪出验证
  /// 卡片，用户点掉后请求还是失败——这正是"无规律闪出"的来源之一。
  bool _supportsBrowserFallback(DioException error) {
    return error.type == DioExceptionType.connectionError;
  }

  String _logPath(String path) => redactSensitiveText(path.split('?').first);
}

final class _HanimeBackgroundRequest {
  _HanimeBackgroundRequest({required this.token, required this.operation});

  final CancelToken token;
  final Future<String> Function() operation;
  final Completer<String> completer = Completer<String>();
}

final class _HanimeHomeCacheEntry {
  const _HanimeHomeCacheEntry({
    required this.sections,
    required this.createdAt,
  });

  final List<HanimeHomeSection> sections;
  final DateTime createdAt;
}

final class _HanimeHomeChannelCacheEntry {
  const _HanimeHomeChannelCacheEntry({
    required this.items,
    required this.createdAt,
  });

  final List<VideoItem> items;
  final DateTime createdAt;
}

final class _HanimeProfileCacheEntry {
  const _HanimeProfileCacheEntry({
    required this.profile,
    required this.createdAt,
  });

  final HanimeAccountProfile profile;
  final DateTime createdAt;
}

final class _HanimeCommentsCacheEntry {
  const _HanimeCommentsCacheEntry({
    required this.comments,
    required this.createdAt,
  });

  final List<HanimeComment> comments;
  final DateTime createdAt;
}

List<Cookie> parseBrowserCookieHeader(String header, Uri origin) {
  final cookies = <Cookie>[];
  for (final part in header.split(';')) {
    final pair = part.trim();
    if (pair.isEmpty) continue;
    final separator = pair.indexOf('=');
    if (separator <= 0) continue;
    final name = pair.substring(0, separator).trim();
    final value = pair.substring(separator + 1).trim();
    if (name.isEmpty) continue;
    cookies.add(
      Cookie(name, value)
        ..domain = origin.host
        ..path = '/'
        ..secure = origin.scheme == 'https',
    );
  }
  return cookies;
}

String cookieNamesForLog(Iterable<Cookie> cookies) {
  final names = cookies.map((cookie) => cookie.name).toSet().toList()..sort();
  return names.isEmpty ? '无' : names.join('、');
}

String cookieHeaderNamesForLog(Object? cookieHeader) {
  final header = cookieHeader?.toString() ?? '';
  if (header.trim().isEmpty) return '无';
  final names = <String>{};
  for (final part in header.split(';')) {
    final separator = part.indexOf('=');
    final name = (separator < 0 ? part : part.substring(0, separator)).trim();
    if (name.isNotEmpty) names.add(name);
  }
  final sorted = names.toList()..sort();
  return sorted.isEmpty ? '无' : sorted.join('、');
}
