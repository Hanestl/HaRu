import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../../features/settings/data/app_settings_repository.dart';
import '../api/hanime1_parser.dart';
import '../api/rule34video_api.dart';
import '../logging/app_log_service.dart';
import '../models/content_source.dart';
import '../models/hanime_search_models.dart';
import '../models/video_models.dart';
import '../session/session_store.dart';
import 'subscription_activity_index.dart';

abstract final class PredictivePrefetchKey {
  static String video(String id, {String siteId = 'rule34video'}) =>
      siteId == 'rule34video' ? 'video:$id' : 'video:$siteId:$id';

  static String feed(String scope, int page) => 'feed:$scope:$page';

  static String favorites(int page) => 'library:favorites:$page';

  static String history(int page) => 'library:history:$page';

  static const playlists = 'library:playlists';
  static const subscriptions = 'library:subscriptions';
  static const following = 'home:following';
  static const hanimeHome = 'home:hanime1';
  static String libraryHanimeLikes(int page) => 'library:hanime-likes:$page';
  static String libraryHanimeSaves(int page) => 'library:hanime-saves:$page';
  static String libraryHanimeHistory(String sort, int page) =>
      'library:hanime-history:$sort:$page';
  static String libraryHanimeSubscriptions(int page) =>
      'library:hanime-subscriptions:$page';
  static String libraryHanimePlaylist(String listCode, int page) =>
      'library:hanime-playlist:$listCode:$page';
  static String hanimeHomeChannel(String channel, int page) =>
      'home:hanime1:channel:$channel:$page';
}

final class PredictivePrefetchService {
  PredictivePrefetchService({
    required this.api,
    required this.sessionStore,
    this.settingsRepository,
    this.idleDelay = const Duration(milliseconds: 700),
    this.interJobDelay = const Duration(milliseconds: 180),
  });

  final Rule34VideoApi api;
  final SessionStore sessionStore;
  final AppSettingsRepository? settingsRepository;
  final Duration idleDelay;
  final Duration interJobDelay;
  final ListQueue<_PrefetchJob> _queue = ListQueue();
  final Set<String> _queuedKeys = {};

  Timer? _idleTimer;
  CancelToken? _activeToken;
  _PrefetchJob? _activeJob;
  String? _activeKey;
  String? _knownUserId;
  var _foregroundCount = 0;
  var _disposed = false;

  void scheduleStartup() {
    _syncSessionQueue();
    // 尽力预热 Hanime 首页；被拦截时安静放弃，留给用户前台操作验证。
    // 插到登录态预取之前，但仍须遵守前台优先和后台请求串行调度。
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.hanimeHome,
        action: (_) async {
          await api.prewarmHanimeHome();
        },
      ),
      first: true,
    );
    _scheduleNext(delay: Duration.zero);
  }

  void onSessionChanged() {
    if (_knownUserId == sessionStore.currentUserId) {
      return;
    }
    _cancelActive('账号状态发生变化', requeue: false);
    _queue.clear();
    _queuedKeys.clear();
    _syncSessionQueue();
    _scheduleNext();
  }

  void offerLikelyVideos(Iterable<VideoItem> videos) {
    // Rule34Video 服务端只要收到视频详情页 GET 就会写入当前账号的观看
    // 历史，因此这里绝不能对 rule34video 做预测性详情预取，否则首页 /
    // 榜单里用户没有点开的视频会被写进历史（实机日志与历史页均已复现）。
    // Hanime 的历史由播放接口单独上报，详情页预取不会污染历史。
    final candidates = videos
        .where((video) => video.site != ContentSite.rule34video)
        .take(3)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return;
    }
    for (final video in candidates.reversed) {
      _enqueue(
        _PrefetchJob(
          key: PredictivePrefetchKey.video(video.id, siteId: video.siteId),
          action: (token) =>
              api.prefetchVideoDetails(video, cancelToken: token),
        ),
        first: true,
      );
    }
    _scheduleNext();
  }

  void scheduleHanimeHomeChannel({
    required String channelKey,
    required HanimeSearchFilters filters,
    int page = 1,
  }) {
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.hanimeHomeChannel(channelKey, page),
        action: (token) async {
          await api.hanime1Api.loadHomeChannel(
            channelKey,
            page,
            filters: filters,
            cancelToken: token,
            // 预取属于后台行为，不允许弹出前台验证卡片。
            allowForegroundVerification: false,
          );
        },
      ),
    );
    _scheduleNext();
  }

  Future<T> runForeground<T>(
    String key,
    Future<T> Function() operation, {
    Duration? resumeDelay,
  }) async {
    _beginForeground(key);
    try {
      return await operation();
    } finally {
      _endForeground(resumeDelay: resumeDelay);
    }
  }

  void prioritizeForeground({String? adoptKey}) {
    if (_disposed) {
      return;
    }
    _idleTimer?.cancel();
    if (adoptKey != null) {
      _removeQueued(adoptKey);
    }
    if (_activeKey != null && _activeKey != adoptKey) {
      _cancelActive('用户开始了更高优先级的操作', requeue: false);
    }
    _scheduleNext();
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _cancelActive('预加载服务已销毁', requeue: false);
    _queue.clear();
    _queuedKeys.clear();
  }

  void _beginForeground(String key) {
    if (_disposed) {
      return;
    }
    _foregroundCount += 1;
    _idleTimer?.cancel();
    _removeQueued(key);
    if (_activeKey != null && _activeKey != key) {
      _cancelActive('前台内容开始加载', requeue: false);
    }
  }

  void _endForeground({Duration? resumeDelay}) {
    if (_disposed) {
      return;
    }
    if (_foregroundCount > 0) {
      _foregroundCount -= 1;
    }
    _scheduleNext(delay: resumeDelay);
  }

  void _syncSessionQueue() {
    _knownUserId = sessionStore.currentUserId;
    if (!sessionStore.isLoggedIn) {
      return;
    }
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.favorites(1),
        action: (token) => api.prefetchFavorites(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.history(1),
        action: (token) => api.prefetchHistory(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.playlists,
        action: (token) => api.prefetchPlaylists(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.subscriptions,
        action: (token) => api.prefetchSubscriptions(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.following,
        action: (token) => api.prefetchFollowingFeed(cancelToken: token),
      ),
    );
  }

  void _enqueue(_PrefetchJob job, {bool first = false}) {
    if (_disposed || _queuedKeys.contains(job.key) || _activeKey == job.key) {
      return;
    }
    _queuedKeys.add(job.key);
    if (first) {
      _queue.addFirst(job);
    } else {
      _queue.addLast(job);
    }
  }

  void _removeQueued(String key) {
    if (!_queuedKeys.remove(key)) {
      return;
    }
    _queue.removeWhere((job) => job.key == key);
  }

  void _scheduleNext({Duration? delay}) {
    if (_disposed ||
        _foregroundCount > 0 ||
        _activeKey != null ||
        _queue.isEmpty) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(delay ?? idleDelay, _runNext);
  }

  void _runNext() {
    if (_disposed ||
        _foregroundCount > 0 ||
        _activeKey != null ||
        _queue.isEmpty) {
      return;
    }
    final job = _queue.removeFirst();
    _queuedKeys.remove(job.key);
    final token = CancelToken();
    _activeKey = job.key;
    _activeToken = token;
    _activeJob = job;
    unawaited(
      AppLogService.instance.info(
        '预加载任务开始；任务=${job.key}',
        component: 'prefetch',
      ),
    );
    unawaited(
      job
          .action(token)
          .catchError((Object error, StackTrace stackTrace) {
            // 预测性任务失败或被取消都不应打断前台页面。
            if (error is RequestCancelledException ||
                error is SubscriptionActivityCancelledException) {
              unawaited(
                AppLogService.instance.info(
                  '预加载任务已取消；任务=${job.key}',
                  component: 'prefetch',
                ),
              );
              return;
            }
            if (error is HanimeCloudflareException) {
              // 后台预取不允许弹前台验证，被拦截属于预期结果，不该记成错误。
              unawaited(
                AppLogService.instance.info(
                  '预加载任务被 Cloudflare 拦截，稍后由前台操作重新验证；'
                  '任务=${job.key}',
                  component: 'prefetch',
                ),
              );
              return;
            }
            unawaited(
              AppLogService.instance.error(
                error,
                stackTrace,
                component: 'prefetch:${job.key}',
              ),
            );
          })
          .whenComplete(() {
            if (_disposed || !identical(_activeToken, token)) {
              return;
            }
            _activeKey = null;
            _activeToken = null;
            _activeJob = null;
            _idleTimer?.cancel();
            _idleTimer = Timer(interJobDelay, _scheduleNext);
          }),
    );
  }

  void _cancelActive(String reason, {bool requeue = true}) {
    final token = _activeToken;
    final job = _activeJob;
    final key = _activeKey;
    _activeToken = null;
    _activeKey = null;
    _activeJob = null;
    if (requeue && job != null) {
      _enqueue(job, first: true);
    }
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
    if (key != null) {
      unawaited(
        AppLogService.instance.info(
          '预加载任务让位；任务=$key；原因=$reason；重新排队=$requeue',
          component: 'prefetch',
        ),
      );
    }
  }
}

final class _PrefetchJob {
  const _PrefetchJob({required this.key, required this.action});

  final String key;
  final Future<void> Function(CancelToken token) action;
}
