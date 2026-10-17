import 'package:flule34/app/providers.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/domain/app_settings.dart';
import 'package:flule34/features/settings/presentation/settings_pages.dart';
import 'package:flule34/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('显示设置在英文窄屏下完整显示语言自称', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(repository.dispose);
    await repository.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppearanceSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Display settings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byType(DropdownButtonFormField<AppLanguagePreference>),
    );
    await tester.pumpAndSettle();
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> values = {};

  @override
  Future<bool?> readBool(String key) async => values[key] as bool?;

  @override
  Future<String?> readString(String key) async => values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
