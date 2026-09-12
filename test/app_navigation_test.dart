import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/app/router/app_router.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import 'helpers/test_session_harness.dart';

void main() {
  testWidgets('底部导航使用四栏结构且搜索不占一级入口', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('R34V'), findsOneWidget);
    expect(find.text('Hanime'), findsOneWidget);
    expect(find.text('媒体库'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '搜索'), findsNothing);
    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('内容取向'), findsOneWidget);
    expect(find.text('视频时长'), findsOneWidget);
    expect(find.text('发布时间'), findsOneWidget);
    expect(find.text('HaRu'), findsNothing);
    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);

    // Hanime 底部 tab 显示 hanime 首页（频道切换 + 竖向视频流）。
    await tester.tap(find.text('Hanime'));
    await tester.pumpAndSettle();
    expect(find.text('最新上市'), findsOneWidget);
    expect(find.text('里番'), findsOneWidget);
    expect(find.text('泡面番'), findsOneWidget);
    expect(find.text('他们在看'), findsOneWidget);
    final latestRelease = find.widgetWithText(ChoiceChip, '最新上市');
    final ecchi = find.widgetWithText(ChoiceChip, '里番');
    expect(
      tester.getSize(latestRelease).width,
      greaterThan(tester.getSize(ecchi).width),
    );

    // 切回 R34V 首页。
    await tester.tap(find.text('R34V'));
    await tester.pumpAndSettle();
    expect(find.text('订阅'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('播放设置'), findsOneWidget);
    await tester.tap(find.text('播放设置'));
    await tester.pumpAndSettle();
    expect(find.text('默认播放清晰度'), findsOneWidget);
    expect(find.text('网络播放策略'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('内容设置'), 300);
    // 双账号卡片让列表更长，滚动后内容设置中心仍可能被底部导航遮挡，
    // 再多滚一段确保可点击。
    await tester.drag(find.byType(ListView), const Offset(0, -140));
    await tester.pumpAndSettle();
    await tester.tap(find.text('内容设置'));
    await tester.pumpAndSettle();
    expect(find.text('隐藏标题关键词'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('关于 HaRu'), 300);
    expect(find.text('关于 HaRu'), findsOneWidget);
    expect(find.text('调试日志'), findsNothing);
  });
}

class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(
        sessionStore: sessionStore,
        // hanime 首页频道现在会真实发起 search 请求（空 query + 筛选），
        // 测试环境没有网络，注入空 adapter 让其立即返回空列表。
        hanimeApi: Hanime1Api(
          sessionStore: sessionStore,
          httpClientAdapter: _EmptyAdapter(),
        ),
      );

  @override
  Future<List<VideoItem>> loadFeed(
    FeedKind kind,
    int page, {
    SearchFilters filters = const SearchFilters(),
    bool force = false,
  }) async {
    return const [];
  }

  @override
  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec, {
    int page = 1,
  }) async {
    return const [];
  }

  @override
  void close() {}
}

final class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '<html><body></body></html>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
