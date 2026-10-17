import 'package:flule34/core/models/hanime_search_models.dart';
import 'package:flule34/features/search/hanime_filter_sheet.dart';
import 'package:flule34/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<HanimeFilterSheetHarness> _openSheet(WidgetTester tester) async {
  // 放大测试视口，避免底部弹出层内 ListView 懒回收导致元素消失。
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  HanimeSearchFilters? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                result = await showHanimeFilterSheet(
                  context: context,
                  initialFilters: const HanimeSearchFilters(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return HanimeFilterSheetHarness(resultGetter: () => result);
}

final class HanimeFilterSheetHarness {
  HanimeFilterSheetHarness({required this.resultGetter});

  final HanimeSearchFilters? Function() resultGetter;

  HanimeSearchFilters? get result => resultGetter();
}

void main() {
  testWidgets('hanime 筛选 sheet 可选择分类并返回筛选结果', (tester) async {
    final harness = await _openSheet(tester);

    expect(find.text('Hanime 筛选与排序'), findsOneWidget);

    // 打开第一个下拉（分类）并选择“里番”。
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('里番').last);
    await tester.pumpAndSettle();

    // 应用。
    await tester.tap(find.text('应用 1 个条件'));
    await tester.pumpAndSettle();

    expect(harness.result, isNotNull);
    expect(harness.result!.genre, '裏番');
  });

  testWidgets('hanime 筛选 sheet 可多选标签并清空全部', (tester) async {
    final harness = await _openSheet(tester);

    // 滚动到标签分组区，展开“影片属性”，勾选“无码”与“中文字幕”。
    final tagGroup = find.text('影片属性');
    await tester.scrollUntilVisible(
      tagGroup,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tagGroup);
    await tester.pumpAndSettle();
    await tester.tap(find.text('无码').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文字幕').first);
    await tester.pumpAndSettle();
    expect(find.text('应用 2 个条件'), findsOneWidget);

    // 全部清除。
    await tester.ensureVisible(find.text('全部清除'));
    await tester.tap(find.text('全部清除'));
    await tester.pumpAndSettle();
    expect(find.text('应用（不限）'), findsOneWidget);

    // 应用空筛选。
    await tester.ensureVisible(find.text('应用（不限）'));
    await tester.tap(find.text('应用（不限）'));
    await tester.pumpAndSettle();

    expect(harness.result, isNotNull);
    expect(harness.result!.isEmpty, isTrue);
  });

  testWidgets('hanime 筛选 sheet 支持指定月份发布日期', (tester) async {
    final harness = await _openSheet(tester);

    // 日期下拉是第 3 个下拉（分类、排序、发布日期）。
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指定月份…').last);
    await tester.pumpAndSettle();

    // 年份下拉（“指定月份”展开后第 4 个下拉）选 2025（菜单内可见）。
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025 年').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('应用 1 个条件'));
    await tester.tap(find.text('应用 1 个条件'));
    await tester.pumpAndSettle();

    final date = harness.result!.date;
    expect(date, isNotNull);
    expect(date!.presetSearchKey, isNull);
    expect(date.year, 2025);
    expect(date.month, isNotNull);
  });
}
