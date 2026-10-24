import 'dart:async';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/network_status_service.dart';
import 'package:flule34/core/services/screen_wake_lock_service.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/video/video_detail_page.dart';
import 'package:flule34/features/video/video_player_page.dart';
import 'package:flule34/shared/video_card.dart';
import 'package:flule34/shared/video_collection_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('全屏内部路由不会触发详情页暂停策略', () {
    expect(shouldPauseVideoForRoutePush(true), isFalse);
    expect(shouldPauseVideoForRoutePush(false), isTrue);
  });

  testWidgets('播放时锁定播放器，明确暂停后才可上推并固定详情页签', (tester) async {
    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await platform.close();
    });
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _FakeVideoApi(harness.sessionStore);
    final playerHandle = VideoPlayerHandle();
    addTearDown(playerHandle.dispose);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(
            api: api,
            video: _video,
            playerHandle: playerHandle,
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    playerHandle.debugSetPlaybackState(playing: true, buffering: false);
    await tester.pump();
    expect(playerHandle.canCollapseDetails, isFalse);

    expect(find.text('喜欢'), findsNothing);
    expect(find.text('不喜欢'), findsNothing);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('本地分类库'), findsOneWidget);
    expect(find.text('3D · ↑12 ↓3'), findsOneWidget);
    // 新布局：简介|评论 Tab（rule34video 评论 Tab 为占位，无真实输入框）。
    expect(find.text('简介'), findsOneWidget);
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('新增一则公开评论...'), findsNothing);
    expect(find.text('播放'), findsNothing);
    final playerFinder = find.byKey(
      const ValueKey('video-detail-player-region'),
    );
    expect(playerFinder, findsOneWidget);
    final playerTop = tester.getTopLeft(playerFinder).dy;
    final nestedState = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is NotificationListener<OverscrollIndicatorNotification>,
      ),
      findsOneWidget,
    );
    final detailScrollView = find.byKey(
      const ValueKey('video-detail-scroll-view'),
    );
    final innerScrollable = find.descendant(
      of: detailScrollView,
      matching: find.byType(Scrollable),
    );
    final innerPosition = tester
        .state<ScrollableState>(innerScrollable)
        .position;

    final playingGesture = await tester.startGesture(
      tester.getCenter(detailScrollView),
    );
    for (var index = 0; index < 6; index += 1) {
      await playingGesture.moveBy(const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(nestedState.outerController.offset, closeTo(0, 0.01));
      expect(tester.getTopLeft(playerFinder).dy, closeTo(playerTop, 0.1));
    }
    await playingGesture.up();
    await tester.pumpAndSettle();
    expect(nestedState.outerController.offset, closeTo(0, 0.01));
    expect(tester.getTopLeft(playerFinder).dy, closeTo(playerTop, 0.1));

    final reverseGesture = await tester.startGesture(
      tester.getCenter(detailScrollView),
    );
    for (var index = 0; index < 3; index += 1) {
      await reverseGesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 16));
      expect(nestedState.outerController.offset, closeTo(0, 0.01));
      expect(tester.getTopLeft(playerFinder).dy, closeTo(playerTop, 0.1));
    }
    await reverseGesture.up();
    await tester.pumpAndSettle();
    expect(nestedState.outerController.offset, closeTo(0, 0.01));
    expect(tester.getTopLeft(playerFinder).dy, closeTo(playerTop, 0.1));
    final innerBeforePause = innerPosition.pixels;
    expect(innerBeforePause, greaterThan(0));

    playerHandle.debugSetPlaybackState(playing: false, buffering: false);
    await tester.pump();
    expect(playerHandle.canCollapseDetails, isTrue);
    expect(nestedState.outerController.offset, closeTo(0, 0.01));
    expect(innerPosition.pixels, closeTo(innerBeforePause, 0.01));

    await tester.fling(detailScrollView, const Offset(0, -1200), 3000);
    await tester.pumpAndSettle();
    expect(nestedState.outerController.offset, greaterThan(0));
    final innerBeforeResume = innerPosition.pixels;
    expect(innerBeforeResume, greaterThanOrEqualTo(0));
    expect(tester.getTopLeft(find.text('简介')).dy, greaterThanOrEqualTo(0));

    playerHandle.debugSetPlaybackState(playing: true, buffering: false);
    await tester.pump();
    expect(nestedState.outerController.offset, greaterThan(0));
    expect(innerPosition.pixels, closeTo(innerBeforeResume, 0.01));
    final outerSamples = <double>[];
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      outerSamples.add(nestedState.outerController.offset);
      expect(innerPosition.pixels, closeTo(innerBeforeResume, 0.01));
    }
    expect(
      outerSamples,
      contains(isNot(nestedState.outerController.position.maxScrollExtent)),
    );
    await tester.pumpAndSettle();
    expect(nestedState.outerController.offset, closeTo(0, 0.01));
    expect(innerPosition.pixels, closeTo(innerBeforeResume, 0.01));
    expect(tester.getTopLeft(playerFinder).dy, closeTo(playerTop, 0.1));
  });

  testWidgets('视频详情加载失败后可原位重试且不会因重建重复请求', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _RetryVideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('详情暂时不可用'), findsOneWidget);
    expect(api.detailLoads, 1);
    await tester.pump();
    expect(api.detailLoads, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('此视频未提供可直接播放的 MP4 源。'), findsOneWidget);
    expect(api.detailLoads, 2);
  });

  testWidgets('超长分类标签卡片会自动换行而不是截断', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _LongMetadataApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = 'very-long-bilingual-tag-that-must-wrap-on-a-phone-screen';
    final labelFinder = find.text(label);
    expect(labelFinder, findsOneWidget);
    expect(tester.getSize(labelFinder).height, greaterThan(20));
  });

  testWidgets('长按详情页标题行的文字外空白处也可打开标题编辑', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _FakeVideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final region = find.byKey(
      const ValueKey('video-detail-title-translation-region'),
    );
    final rect = tester.getRect(region);
    expect(rect.width, greaterThan(tester.getSize(find.text('测试视频')).width));

    final gesture = await tester.startGesture(
      Offset(rect.right - 8, rect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    expect(find.text('编辑译文'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('详情页相关视频采用 VideoCollectionSliver 懒加载承载', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final relatedVideos = List<VideoItem>.generate(
      40,
      (index) => VideoItem(
        id: '${500 + index}',
        title: '相关推荐视频 $index',
        slug: 'related-video-$index',
      ),
    );
    final api = _RelatedFakeVideoApi(harness.sessionStore, relatedVideos);
    final playerHandle = VideoPlayerHandle();
    addTearDown(playerHandle.dispose);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(
            api: api,
            video: _video,
            playerHandle: playerHandle,
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(VideoCollectionSliver, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('相关视频'), findsOneWidget);
    // 40 条相关视频不会一次性全部构建：首屏只应构建可见的少量卡片。
    final builtCards = find
        .byType(VideoCard, skipOffstage: false)
        .evaluate()
        .length;
    expect(builtCards, greaterThan(0));
    expect(
      builtCards,
      lessThan(relatedVideos.length),
      reason: '懒加载应只构建首屏可见卡片，实际构建 $builtCards / ${relatedVideos.length}',
    );
    expect(find.text('相关推荐视频 39'), findsNothing);
  });

  testWidgets('网络从离线恢复到连网时，可恢复错误会自动触发重试自愈', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _NetworkAutoRetryApi(harness.sessionStore);
    final statusController = StreamController<NetworkClass>.broadcast();
    addTearDown(statusController.close);
    final networkStatus = _FakeNetworkStatusService(
      initial: NetworkClass.offline,
      statusStream: statusController.stream,
    );
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(networkStatus),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法连接到网站，请检查网络。'), findsOneWidget);
    expect(api.detailLoads, 1);

    // 模拟网络恢复
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(api.detailLoads, 2);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('无法连接到网站，请检查网络。'), findsNothing);
  });

  testWidgets('不可恢复错误（如 HTTP 403 / Cloudflare）即使网络恢复也不会盲目自愈', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _NetworkAutoRetryApi(
      harness.sessionStore,
      failureError: const HttpStatusException(403),
    );
    final statusController = StreamController<NetworkClass>.broadcast();
    addTearDown(statusController.close);
    final networkStatus = _FakeNetworkStatusService(
      initial: NetworkClass.offline,
      statusStream: statusController.stream,
    );
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(networkStatus),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务器返回了 HTTP 403。'), findsOneWidget);
    expect(api.detailLoads, 1);

    // 模拟网络恢复，不应盲目重试 403 业务错误
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.detailLoads, 1);
    expect(find.text('服务器返回了 HTTP 403。'), findsOneWidget);
  });

  for (final status in const [502, 503, 504]) {
    testWidgets('HTTP $status 视为可恢复错误，连网恢复后自动重试自愈', (tester) async {
      final harness = TestSessionHarness.create();
      addTearDown(harness.dispose);
      await harness.sessionStore.load();
      final api = _NetworkAutoRetryApi(
        harness.sessionStore,
        failureError: HttpStatusException(status),
      );
      final statusController = StreamController<NetworkClass>.broadcast();
      addTearDown(statusController.close);
      final networkStatus = _FakeNetworkStatusService(
        initial: NetworkClass.offline,
        statusStream: statusController.stream,
      );
      final container = ProviderContainer(
        overrides: [
          rule34VideoApiProvider.overrideWithValue(api),
          appDatabaseProvider.overrideWithValue(harness.database),
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          downloadPlatformServiceProvider.overrideWithValue(
            _FakeDownloadPlatformService(),
          ),
          networkStatusServiceProvider.overrideWithValue(networkStatus),
          screenWakeLockServiceProvider.overrideWithValue(
            _FakeScreenWakeLockService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: VideoDetailPage(api: api, video: _video),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('站点服务暂时不可用，请稍后重试'), findsOneWidget);
      expect(api.detailLoads, 1);

      // 5xx 属于可恢复错误：网络恢复后应自动重试自愈，而不是像 403 那样干等。
      statusController.add(NetworkClass.wifi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(api.detailLoads, 2);
      expect(find.text('站点服务暂时不可用，请稍后重试'), findsNothing);
      expect(find.text('测试视频'), findsOneWidget);
    });
  }

  testWidgets('自动重试严格遵守最多 2 次上限，手动点击重试可重置计数', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _NetworkAutoRetryApi(
      harness.sessionStore,
      failureCount: 3, // 前3次（初始+2次自愈）失败，第4次手动重试成功
    );
    final statusController = StreamController<NetworkClass>.broadcast();
    addTearDown(statusController.close);
    final networkStatus = _FakeNetworkStatusService(
      initial: NetworkClass.offline,
      statusStream: statusController.stream,
    );
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(networkStatus),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.detailLoads, 1);

    // 第 1 次网络恢复自愈
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 2);

    // 再次掉线再恢复：第 2 次自愈
    statusController.add(NetworkClass.offline);
    await tester.pump();
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 3);

    // 再次掉线再恢复：已达 2 次自动上限，不应再自愈
    statusController.add(NetworkClass.offline);
    await tester.pump();
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 3);

    // 用户手动点击重试：重置计数并成功请求第 4 次
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 4);
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('无法连接到网站，请检查网络。'), findsNothing);
  });

  testWidgets('详情加载骨架屏在窄屏(320dp/360dp)下自适应换行且无RenderFlex溢出', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final completer = Completer<VideoDetails>();
    final api = _BlockingDetailApi(harness.sessionStore, completer.future);

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: VideoDetailPage(api: api, video: _video),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('简介'), findsOneWidget);
      expect(find.text('评论'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('延迟 current 时首个事件直接为 Wi-Fi，仍能触发自愈且 current 迟到返回 offline 不会重复请求', (
    tester,
  ) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final currentCompleter = Completer<NetworkClass>();
    final statusController = StreamController<NetworkClass>.broadcast();
    addTearDown(statusController.close);

    final networkService = _ControlledNetworkStatusService(
      currentFuture: currentCompleter.future,
      statusStream: statusController.stream,
    );

    final api = _NetworkAutoRetryApi(harness.sessionStore, failureCount: 1);

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(networkService),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.detailLoads, 1);
    expect(find.text('无法连接到网站，请检查网络。'), findsOneWidget);

    // 首个 stream 事件直接为 Wi-Fi（未先发送 offline）
    statusController.add(NetworkClass.wifi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 2);

    // 迟到的 current() 返回 offline，被拦截丢弃
    currentCompleter.complete(NetworkClass.offline);
    await tester.pump();
    await tester.pumpAndSettle();

    // 断言恢复请求只执行了一次，且页面成功展现
    expect(api.detailLoads, 2);
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('无法连接到网站，请检查网络。'), findsNothing);
  });

  testWidgets('请求在途时发生网络恢复，失败后能自动触发自愈重试', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final statusController = StreamController<NetworkClass>.broadcast();
    addTearDown(statusController.close);

    final networkService = _FakeNetworkStatusService(
      initial: NetworkClass.offline,
      statusStream: statusController.stream,
    );

    final requestCompleter = Completer<VideoDetails>();
    final api = _DeferredFailureDetailApi(
      harness.sessionStore,
      firstDeferredFuture: requestCompleter.future,
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(networkService),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pump();
    expect(api.detailLoads, 1);

    statusController.add(NetworkClass.wifi);
    await tester.pump();

    requestCompleter.completeError(const ApiException('无法连接到网站，请检查网络。'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(api.detailLoads, 2);
    expect(find.text('测试视频'), findsOneWidget);
  });

  testWidgets('切换视频时旧请求失败不会覆盖新请求状态', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final completerA = Completer<VideoDetails>();
    final completerB = Completer<VideoDetails>();
    final api = _MultiVideoDeferredApi(
      harness.sessionStore,
      futures: {'123': completerA.future, '456': completerB.future},
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    const videoA = VideoItem(id: '123', title: '视频A', slug: 'video-a');
    const videoB = VideoItem(id: '456', title: '视频B', slug: 'video-b');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: videoA),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: videoB),
        ),
      ),
    );
    await tester.pump();

    completerA.completeError(const ApiException('无法连接到网站，请检查网络。'));
    await tester.pump();

    expect(find.text('重试'), findsNothing);

    completerB.complete(
      const VideoDetails(
        video: videoB,
        sources: [],
        categories: [],
        tags: [],
        models: [],
        isFavorite: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('视频B'), findsOneWidget);
  });

  testWidgets('标签超过5个时默认折叠并显示剩余数量，点击可展开与收起', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    const videoWithManyTags = VideoDetails(
      video: _video,
      sources: [],
      categories: ['3D'],
      tags: ['tag1', 'tag2', 'tag3', 'tag4', 'tag5', 'tag6', 'tag7', 'tag8'],
      models: [],
      isFavorite: false,
    );
    final api = _BlockingDetailApi(
      harness.sessionStore,
      Future.value(videoWithManyTags),
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认显示前 5 个标签（tag1~tag5），tag6~tag8 被折叠
    expect(find.text('tag1'), findsOneWidget);
    expect(find.text('tag5'), findsOneWidget);
    expect(find.text('tag6'), findsNothing);
    // 剩余标签为 8 - 5 = 3 个，显示展开(3)
    expect(find.text('展开(3)'), findsOneWidget);

    // 点击展开
    await tester.ensureVisible(find.text('展开(3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开(3)'));
    await tester.pumpAndSettle();

    // 全部展示，按钮变为收起
    expect(find.text('tag6'), findsOneWidget);
    expect(find.text('tag8'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    // 点击收起
    await tester.ensureVisible(find.text('收起'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收起'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 恢复只显示前 5 个，按钮变回展开(3)
    expect(find.text('tag6'), findsNothing);
    expect(find.text('展开(3)'), findsOneWidget);
  });
}

class _NetworkAutoRetryApi extends Rule34VideoApi {
  _NetworkAutoRetryApi(
    SessionStore sessionStore, {
    this.failureError,
    this.failureCount = 1,
  }) : super(sessionStore: sessionStore);

  final Object? failureError;
  final int failureCount;
  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    detailLoads += 1;
    if (detailLoads <= failureCount) {
      throw failureError ?? const ApiException('无法连接到网站，请检查网络。');
    }
    return const VideoDetails(
      video: _video,
      sources: [],
      categories: ['3D'],
      tags: ['example'],
      models: [],
      isFavorite: false,
    );
  }

  @override
  Future<VideoDetails> refreshVideoDetails(VideoItem video) =>
      loadVideoDetails(video);

  @override
  void close() {}
}

class _RelatedFakeVideoApi extends Rule34VideoApi {
  _RelatedFakeVideoApi(SessionStore sessionStore, this.relatedVideos)
    : super(sessionStore: sessionStore);

  final List<VideoItem> relatedVideos;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    return VideoDetails(
      video: _video,
      sources: const [],
      categories: const ['3D'],
      tags: const ['example'],
      models: const ['Artist'],
      isFavorite: false,
      relatedVideos: relatedVideos,
    );
  }

  @override
  Future<VideoDetails> refreshVideoDetails(VideoItem video) =>
      loadVideoDetails(video);

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}

final class _FakeNetworkStatusService implements NetworkStatusService {
  _FakeNetworkStatusService({
    this.initial = NetworkClass.wifi,
    this.statusStream,
  });

  final NetworkClass initial;
  final Stream<NetworkClass>? statusStream;

  @override
  Future<NetworkClass> current() async => initial;

  @override
  Stream<NetworkClass> get onStatusChanged =>
      statusStream ?? const Stream.empty();
}

final class _FakeScreenWakeLockService implements ScreenWakeLockService {
  @override
  Future<void> setEnabled(bool enabled) async {}
}

const _video = VideoItem(id: '123', title: '测试视频', slug: 'test-video');

const _details = VideoDetails(
  video: _video,
  sources: [],
  categories: ['3D'],
  tags: ['example'],
  models: ['Artist'],
  metadataItems: [
    VideoMetadataItem(
      id: '1',
      title: '3D',
      path: '/categories/1/3d/',
      kind: DiscoveryKind.category,
      upScore: 12,
      downScore: 3,
    ),
  ],
  isFavorite: false,
);

class _FakeVideoApi extends Rule34VideoApi {
  _FakeVideoApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    detailLoads += 1;
    return _details;
  }

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}

class _RetryVideoApi extends Rule34VideoApi {
  _RetryVideoApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    detailLoads += 1;
    if (detailLoads == 1) {
      throw const ApiException('详情暂时不可用');
    }
    return const VideoDetails(
      video: _video,
      sources: [],
      categories: [],
      tags: [],
      models: [],
      isFavorite: false,
    );
  }

  @override
  void close() {}
}

class _LongMetadataApi extends Rule34VideoApi {
  _LongMetadataApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async => const VideoDetails(
    video: _video,
    sources: [],
    categories: [],
    tags: [],
    models: [],
    metadataItems: [
      VideoMetadataItem(
        id: 'long-tag',
        title: 'very-long-bilingual-tag-that-must-wrap-on-a-phone-screen',
        path: '/tags/long-tag/',
        kind: DiscoveryKind.tag,
        upScore: 0,
        downScore: 0,
      ),
    ],
    isFavorite: false,
  );

  @override
  void close() {}
}

final class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast();

  int playCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    Timer.run(() {
      if (!_events.isClosed) {
        _events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(1280, 720),
          ),
        );
      }
    });
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> play(int playerId) async {
    playCount += 1;
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration value) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setVolume(int playerId, double value) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double value) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> dispose(int playerId) async {}

  Future<void> close() => _events.close();
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  @override
  Stream<DownloadPlatformEvent> get events => const Stream.empty();

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> pause(String taskId) async => true;

  @override
  Future<bool> resume(String taskId) async => true;

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async => true;

  @override
  void setCompletionSink(
    Future<void> Function(DownloadStatusEvent event)? sink,
  ) {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> taskExists(String taskId) async => false;

  @override
  Future<bool> enqueue(DownloadRequest request) async => true;

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<bool> ensureSharedStoragePermission() async => true;

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async =>
      const DownloadFileInspection(exists: true, readable: true);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMaxConcurrent(int value) async {}

  @override
  Future<bool> openFile(String fileUri) async => true;
}

final class _ControlledNetworkStatusService implements NetworkStatusService {
  _ControlledNetworkStatusService({
    required this.currentFuture,
    required this.statusStream,
  });

  final Future<NetworkClass> currentFuture;
  final Stream<NetworkClass> statusStream;

  @override
  Future<NetworkClass> current() => currentFuture;

  @override
  Stream<NetworkClass> get onStatusChanged => statusStream;
}

final class _BlockingDetailApi extends Rule34VideoApi {
  _BlockingDetailApi(SessionStore sessionStore, this.blockingFuture)
    : super(sessionStore: sessionStore);

  final Future<VideoDetails> blockingFuture;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) => blockingFuture;

  @override
  Future<VideoDetails> refreshVideoDetails(VideoItem video) => blockingFuture;

  @override
  void close() {}
}

final class _DeferredFailureDetailApi extends Rule34VideoApi {
  _DeferredFailureDetailApi(
    SessionStore sessionStore, {
    required this.firstDeferredFuture,
  }) : super(sessionStore: sessionStore);

  final Future<VideoDetails> firstDeferredFuture;
  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) {
    detailLoads += 1;
    if (detailLoads == 1) {
      return firstDeferredFuture;
    }
    return Future.value(
      VideoDetails(
        video: video,
        sources: const [],
        categories: const ['3D'],
        tags: const ['example'],
        models: const [],
        isFavorite: false,
      ),
    );
  }

  @override
  Future<VideoDetails> refreshVideoDetails(VideoItem video) =>
      loadVideoDetails(video);

  @override
  void close() {}
}

final class _MultiVideoDeferredApi extends Rule34VideoApi {
  _MultiVideoDeferredApi(SessionStore sessionStore, {required this.futures})
    : super(sessionStore: sessionStore);

  final Map<String, Future<VideoDetails>> futures;

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) {
    return futures[video.id] ??
        Future.value(
          VideoDetails(
            video: video,
            sources: const [],
            categories: const [],
            tags: const [],
            models: const [],
            isFavorite: false,
          ),
        );
  }

  @override
  Future<VideoDetails> refreshVideoDetails(VideoItem video) =>
      loadVideoDetails(video);

  @override
  void close() {}
}
