import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flule34/features/library/library_page.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('媒体库三大范围按需加载并保留状态', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    await harness.sessionStore.authenticateHanime('2002');
    final hanimeRequests = <String, int>{};
    final hanimeUris = <Uri>[];
    final hanimeApi = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        final path = options.uri.path;
        hanimeUris.add(options.uri);
        hanimeRequests[path] = (hanimeRequests[path] ?? 0) + 1;
        return ResponseBody.fromString('<html><body></body></html>', 200);
      }),
    );
    addTearDown(hanimeApi.close);
    final api = _LibraryApi(harness.sessionStore, hanimeApi: hanimeApi);
    final prefetch = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
    );
    addTearDown(prefetch.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
        child: MaterialApp(
          home: LibraryPage(
            api: api,
            localLibraryRepository: _FakeLocalLibraryRepository(),
            prefetchService: prefetch,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('媒体库'), findsNothing);
    expect(find.text('本机'), findsOneWidget);
    expect(find.text('R34V'), findsOneWidget);
    expect(find.text('Hanime'), findsOneWidget);
    expect(find.text('本地库'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('新建本地库'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);
    expect(api.favoriteLoads, 0);
    expect(hanimeRequests, isEmpty);

    await tester.tap(find.text('R34V'));
    await tester.pumpAndSettle();
    expect(api.historyLoads, 1);
    expect(api.favoriteLoads, 0);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(api.favoriteLoads, 1);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(api.historyLoads, 1);

    await tester.tap(find.text('Hanime'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/histories'], 1);
    expect(find.text('点赞'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('稍后观看'), findsOneWidget);

    await tester.tap(find.text('点赞'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/likes'], 1);

    await tester.tap(find.text('稍后观看'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/saves'], 1);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/histories'], 1);
    expect(
      hanimeUris
          .lastWhere((uri) => uri.path.endsWith('/histories'))
          .queryParameters['sort'],
      'latest',
    );

    expect(find.text('热门'), findsNothing);
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近观看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最热').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/histories'], 2);
    expect(
      hanimeUris
          .lastWhere((uri) => uri.path.endsWith('/histories'))
          .queryParameters['sort'],
      'popular',
    );

    await tester.tap(find.text('播放列表'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/user/2002/playlists'], 1);

    await tester.tap(find.text('订阅'));
    await tester.pumpAndSettle();
    expect(hanimeRequests['/subscriptions'], 1);

    await tester.tap(find.text('R34V'));
    await tester.pumpAndSettle();
    expect(api.favoriteLoads, 1);
    expect(api.historyLoads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('窄屏下未登录仍保留站点导航结构', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _LibraryApi(harness.sessionStore);
    final prefetch = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
    );
    addTearDown(prefetch.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
        child: MaterialApp(
          home: LibraryPage(
            api: api,
            localLibraryRepository: _FakeLocalLibraryRepository(),
            prefetchService: prefetch,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('R34V'));
    await tester.pumpAndSettle();
    expect(find.text('登录 Rule34Video'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);

    await tester.tap(find.text('Hanime'));
    await tester.pumpAndSettle();
    expect(find.text('登录 Hanime'), findsOneWidget);
    expect(find.text('点赞'), findsOneWidget);
    expect(find.text('稍后观看'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeLocalLibraryRepository implements LocalLibraryRepository {
  @override
  Stream<List<LocalLibrary>> watchLibraries() => Stream.value(const []);

  @override
  Stream<List<LocalLibrarySummary>> watchLibrarySummaries() =>
      Stream.value(const []);

  @override
  Stream<List<VideoItem>> watchVideos(int libraryId) => Stream.value(const []);

  @override
  Future<Set<int>> libraryIdsForVideo(String videoId) async => const {};

  @override
  Future<int> createLibrary(String name) => throw UnimplementedError();

  @override
  Future<void> renameLibrary(int id, String name) => throw UnimplementedError();

  @override
  Future<void> deleteLibrary(int id) => throw UnimplementedError();

  @override
  Future<void> addVideo({required int libraryId, required VideoItem video}) =>
      throw UnimplementedError();

  @override
  Future<void> removeVideo({required int libraryId, required String videoId}) =>
      throw UnimplementedError();
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

final class _LibraryApi extends Rule34VideoApi {
  _LibraryApi(SessionStore sessionStore, {super.hanimeApi})
    : super(sessionStore: sessionStore);

  var favoriteLoads = 0;
  var historyLoads = 0;

  @override
  Future<List<VideoItem>> loadFavorites(int page, {bool force = false}) async {
    favoriteLoads += 1;
    return const [];
  }

  @override
  Future<List<VideoItem>> loadHistory(int page, {bool force = false}) async {
    historyLoads += 1;
    return const [];
  }

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}

final class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);

  @override
  void close({bool force = false}) {}
}
