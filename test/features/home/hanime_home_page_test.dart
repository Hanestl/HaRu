import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/home/hanime_home_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('快速连续切换频道只加载停留满 300ms 的最后一项', (tester) async {
    final fixture = await _HomeFixture.create(tester);
    await tester.pumpAndSettle();
    fixture.searches.clear();

    await tester.tap(find.widgetWithText(ChoiceChip, '最新上传'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '最新上传'))
          .selected,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(fixture.searches, isEmpty);

    await tester.tap(find.widgetWithText(ChoiceChip, '里番'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(fixture.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(fixture.searches, hasLength(1));
    expect(fixture.searches.single['genre'], '裏番');
    await fixture.dispose(tester);
  });

  testWidgets('防抖期间离开首页会取消定时器且不继续请求', (tester) async {
    final fixture = await _HomeFixture.create(tester);
    await tester.pumpAndSettle();
    fixture.searches.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, '最新上传'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.searches, isEmpty);
    expect(tester.takeException(), isNull);
    await fixture.dispose(tester);
  });

  testWidgets('防抖期间返回已加载频道不会再次请求', (tester) async {
    final fixture = await _HomeFixture.create(tester);
    await tester.pumpAndSettle();
    fixture.searches.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, '最新上传'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(ChoiceChip, '最新上市'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(fixture.searches, isEmpty);
    await fixture.dispose(tester);
  });
}

final class _HomeFixture {
  _HomeFixture(this.api, this.prefetch, this.container, this.searches);

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final ProviderContainer container;
  final List<Map<String, dynamic>> searches;

  static Future<_HomeFixture> create(WidgetTester tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final searches = <Map<String, dynamic>>[];
    final hanime = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _EmptyAdapter(searches),
    );
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      hanimeApi: hanime,
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    await settings.load();
    addTearDown(settings.dispose);
    final prefetch = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(hours: 1),
    );
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appSettingsRepositoryProvider.overrideWithValue(settings),
        predictivePrefetchServiceProvider.overrideWithValue(prefetch),
        translationServiceProvider.overrideWith((ref) {
          final service = TranslationService.fromDictionary(
            settingsRepository: settings,
            dictionary: const {},
          );
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
    );
    // 出错时也释放所有调度器，避免一个断言失败掩盖成 pending timer 错误。
    addTearDown(prefetch.dispose);
    addTearDown(api.close);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: HanimeHomePage(api: api)),
        ),
      ),
    );
    return _HomeFixture(api, prefetch, container, searches);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    prefetch.dispose();
  }
}

final class _EmptyAdapter implements HttpClientAdapter {
  _EmptyAdapter(this.searches);
  final List<Map<String, dynamic>> searches;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/search') {
      searches.add(Map.of(options.queryParameters));
    }
    return ResponseBody.fromString('<div id="home-rows-wrapper"></div>', 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, String> _strings = {};
  final Map<String, bool> _bools = {};
  @override
  Future<bool?> readBool(String key) async => _bools[key];
  @override
  Future<String?> readString(String key) async => _strings[key];
  @override
  Future<void> writeBool(String key, bool value) async {
    _bools[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _strings[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _strings.remove(key);
    _bools.remove(key);
  }
}
