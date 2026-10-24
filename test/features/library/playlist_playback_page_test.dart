import 'dart:async';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/network_status_service.dart';
import 'package:flule34/core/services/screen_wake_lock_service.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/library/playlist_playback_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/test_session_harness.dart';

class _FakeApi extends Rule34VideoApi {
  _FakeApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    return VideoDetails(
      video: video,
      sources: const [
        VideoSource(
          label: '720p',
          url: 'https://example.com/video.mp4',
          isHd: true,
        ),
      ],
      isFavorite: false,
      ratingVotes: 100,
      categories: const ['3D', 'Animation'],
      tags: const ['Overwatch', 'Action'],
      models: const ['BlenderArtist'],
      metadataItems: const [
        VideoMetadataItem(
          id: '1',
          title: '3D',
          path: '/categories/3d/',
          kind: DiscoveryKind.category,
        ),
        VideoMetadataItem(
          id: '2',
          title: 'Overwatch',
          path: '/tags/overwatch/',
          kind: DiscoveryKind.tag,
        ),
        VideoMetadataItem(
          id: '3',
          title: 'BlenderArtist',
          path: '/models/blenderartist/',
          kind: DiscoveryKind.model,
        ),
      ],
      uploader: const UploaderSummary(
        id: '999',
        name: 'CoolCreator',
        verified: true,
      ),
      description: '这是一段测试视频描述。',
    );
  }
}

void main() {
  testWidgets('PlaylistPlaybackPage 渲染分类、标签云、统计与上传者元数据', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await platform.close();
    });

    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _FakeApi(harness.sessionStore);
    final settingsStore = _MemorySettingsStore();
    final settings = AppSettingsRepository(settingsStore);
    addTearDown(settings.dispose);
    final translationService = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {},
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    const video = VideoItem(
      id: '101',
      slug: 'test-video',
      title: 'Test Video',
      duration: '03:45',
      views: 12000,
      rating: 95,
      ratingVotes: 100,
      publishedLabel: '3 days ago',
    );

    const playlist = PlaylistItem(
      id: '1',
      title: '我的播放列表',
      path: '/playlists/1/',
      videoCount: 1,
    );

    final request = PlaylistPlaybackRequest(
      playlist: playlist,
      videos: const [video],
      initialIndex: 0,
      nextPage: 1,
      hasMore: false,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlaylistPlaybackPage(
            api: api,
            request: request,
            translationService: translationService,
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // 等待加载详情与首帧
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 验证标题与集数
    expect(find.text('Test Video'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);

    // 验证统计指标
    expect(find.text('03:45'), findsOneWidget);
    expect(find.text('12000 次观看'), findsOneWidget);
    expect(find.text('95% · 100 票'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);

    // 验证描述
    expect(find.text('这是一段测试视频描述。'), findsOneWidget);

    // 验证分类与标签与艺术家标题
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);

    expect(find.text('标签'), findsOneWidget);
    expect(find.text('Overwatch'), findsOneWidget);

    expect(find.text('艺术家'), findsOneWidget);
    expect(find.text('BlenderArtist'), findsOneWidget);

    // 验证上传者
    expect(find.text('上传者'), findsOneWidget);
    expect(find.text('CoolCreator'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });
  testWidgets('R34V 播放列表只加载当前条目，不预取后续条目的认证详情', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await platform.close();
    });

    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _RecordingApi(harness.sessionStore);
    final settingsStore = _MemorySettingsStore();
    final settings = AppSettingsRepository(settingsStore);
    addTearDown(settings.dispose);
    final translationService = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {},
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    const playlist = PlaylistItem(
      id: '9',
      title: '混合列表',
      path: '/playlists/9/',
      videoCount: 3,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlaylistPlaybackPage(
            api: api,
            request: const PlaylistPlaybackRequest(
              playlist: playlist,
              videos: [
                VideoItem(
                  id: 'a1',
                  slug: 'a1',
                  title: 'First',
                  siteId: 'hanime1',
                ),
                VideoItem(id: 'b2', slug: 'b2', title: 'Second'),
                VideoItem(id: 'c3', slug: 'c3', title: 'Third'),
              ],
              initialIndex: 0,
              nextPage: 1,
              hasMore: false,
            ),
            translationService: translationService,
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
    await tester.pump(const Duration(milliseconds: 300));

    // 只请求当前条目；rule34video 的认证详情 GET 会被服务端记进观看历史，
    // 后台预取必须一条都不发。
    expect(api.requestedIds, ['a1']);

    // 用户真正切到下一条时才允许请求。
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.requestedIds, ['a1', 'b2']);
  });

  testWidgets('播放列表后台预取下一条 Hanime 视频时不允许拉起前台验证', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await platform.close();
    });

    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _RecordingApi(harness.sessionStore);
    final settingsStore = _MemorySettingsStore();
    final settings = AppSettingsRepository(settingsStore);
    addTearDown(settings.dispose);
    final translationService = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {},
    );

    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    const playlist = PlaylistItem(
      id: '11',
      title: 'Hanime 列表',
      path: '/playlists/11/',
      videoCount: 2,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlaylistPlaybackPage(
            api: api,
            request: const PlaylistPlaybackRequest(
              playlist: playlist,
              videos: [
                VideoItem(
                  id: 'h1',
                  slug: 'h1',
                  title: 'First',
                  siteId: 'hanime1',
                ),
                VideoItem(
                  id: 'h2',
                  slug: 'h2',
                  title: 'Second',
                  siteId: 'hanime1',
                ),
              ],
              initialIndex: 0,
              nextPage: 1,
              hasMore: false,
            ),
            translationService: translationService,
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
    await tester.pump(const Duration(milliseconds: 300));

    // 当前条目是用户主动打开（允许前台验证），下一条是后台预取（不允许）。
    expect(api.requestedIds, ['h1', 'h2']);
    expect(api.foregroundFlags, [true, false]);
  });
}

/// 记录"到底请求了哪些详情"，用来断言不该发生的预取确实没有发生。
final class _RecordingApi extends Rule34VideoApi {
  _RecordingApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  final List<String> requestedIds = [];
  final List<bool> foregroundFlags = [];

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    requestedIds.add(video.id);
    foregroundFlags.add(allowForegroundVerification);
    return VideoDetails(
      video: video,
      sources: const [
        VideoSource(
          label: '720p',
          url: 'https://example.com/video.mp4',
          isHd: true,
        ),
      ],
      categories: const [],
      tags: const [],
      models: const [],
      isFavorite: false,
    );
  }

  @override
  Future<void> reportWatchHistory(VideoItem video) async {}
}

final class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast();

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
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

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

final class _FakeNetworkStatusService implements NetworkStatusService {
  @override
  Future<NetworkClass> current() async => NetworkClass.wifi;

  @override
  Stream<NetworkClass> get onStatusChanged => const Stream.empty();
}

final class _FakeScreenWakeLockService implements ScreenWakeLockService {
  @override
  Future<void> setEnabled(bool enabled) async {}
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async =>
      key == 'flule34.settings.language'
      ? 'simplifiedChinese'
      : _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
