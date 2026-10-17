import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/content_source.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('前台任务会阻止预测任务启动，并取消不相关的后台请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(milliseconds: 5),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);
    final foreground = Completer<void>();

    final foregroundFuture = service.runForeground(
      'foreground:test',
      () => foreground.future,
    );
    service.scheduleStartup();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(api.calls, isEmpty);

    foreground.complete();
    await foregroundFuture;
    // 启动预取把 hanime 首页预热插到最前（CF 验证优先），随后才是登录态队列。
    await api.hanimeHomeStarted.future.timeout(const Duration(seconds: 1));
    expect(api.calls.first, 'hanime-home');
    await api.favoritesStarted.future.timeout(const Duration(seconds: 1));
    expect(api.calls, contains('favorites'));
    final firstToken = api.favoritesTokens.single;
    expect(firstToken.isCancelled, isFalse);

    await service.runForeground(
      PredictivePrefetchKey.video('9'),
      () async => const VideoItem(id: '9', title: '前台视频', slug: 'front'),
    );

    expect(firstToken.isCancelled, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(api.favoritesTokens, hasLength(1));
  });

  test('Rule34Video 候选视频不会预测加载详情，避免污染观看历史', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(milliseconds: 1),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);

    service.offerLikelyVideos(const [
      VideoItem(id: '1', title: '第一条', slug: 'first'),
      VideoItem(id: '2', title: '第二条', slug: 'second'),
      VideoItem(id: '3', title: '第三条', slug: 'third'),
      VideoItem(id: '4', title: '第四条', slug: 'fourth'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // R34V 服务端在详情页 GET 时就会写入历史，因此这里必须一个都不预取。
    expect(api.calls, isEmpty);
  });

  test('Hanime 候选视频会按照可见顺序逐个预测加载详情', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(milliseconds: 1),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);

    service.offerLikelyVideos(const [
      VideoItem(id: '1', title: '第一条', slug: 'first', siteId: 'hanime1'),
      VideoItem(id: '2', title: '第二条', slug: 'second', siteId: 'hanime1'),
      VideoItem(id: '3', title: '第三条', slug: 'third', siteId: 'hanime1'),
      VideoItem(id: '4', title: '第四条', slug: 'fourth', siteId: 'hanime1'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(api.calls, ['video:1', 'video:2', 'video:3']);
  });

  test('使用过 Hanime 后启动预加载会在后台预热其首页', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setActiveSite(ContentSite.hanime1);
    await settings.setActiveSite(ContentSite.rule34video);
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      settingsRepository: settings,
      idleDelay: const Duration(milliseconds: 1),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);

    service.scheduleStartup();
    await api.hanimeHomeStarted.future.timeout(const Duration(seconds: 1));

    expect(api.calls, ['hanime-home']);
  });
}

final class _PrefetchApi extends Rule34VideoApi {
  _PrefetchApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  final List<String> calls = [];
  final Completer<void> favoritesStarted = Completer<void>();
  final Completer<void> hanimeHomeStarted = Completer<void>();
  final List<CancelToken> favoritesTokens = [];

  @override
  Future<void> prefetchFavorites({required CancelToken cancelToken}) async {
    calls.add('favorites');
    favoritesTokens.add(cancelToken);
    if (!favoritesStarted.isCompleted) {
      favoritesStarted.complete();
    }
    await cancelToken.whenCancel;
    throw const RequestCancelledException();
  }

  @override
  Future<void> prefetchHistory({required CancelToken cancelToken}) async {
    calls.add('history');
  }

  @override
  Future<void> prefetchPlaylists({required CancelToken cancelToken}) async {
    calls.add('playlists');
  }

  @override
  Future<void> prefetchSubscriptions({required CancelToken cancelToken}) async {
    calls.add('subscriptions');
  }

  @override
  Future<void> prefetchFollowingFeed({required CancelToken cancelToken}) async {
    calls.add('following');
  }

  @override
  Future<void> prefetchVideoDetails(
    VideoItem video, {
    required CancelToken cancelToken,
  }) async {
    calls.add('video:${video.id}');
  }

  @override
  Future<void> prewarmHanimeHome() async {
    calls.add('hanime-home');
    if (!hanimeHomeStarted.isCompleted) hanimeHomeStarted.complete();
  }

  @override
  void close() {}
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;
}
