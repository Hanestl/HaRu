import 'package:flule34/core/api/hanime1_search_options.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hanime 筛选选项数据完整性', () {
    test('分类/排序/时长/发布日期与 Han1meViewer 数据源一致', () {
      expect(hanimeGenres, hasLength(10));
      expect(hanimeSorts, hasLength(9));
      expect(hanimeDurations, hasLength(9));
      expect(hanimeReleaseDates, hasLength(7));
      expect(hanimeBrands, hasLength(65));
    });

    test('选项 searchKey 唯一', () {
      final keys = <String>{};
      for (final option in [
        ...hanimeGenres,
        ...hanimeSorts,
        ...hanimeDurations,
        ...hanimeReleaseDates,
        ...hanimeBrands,
      ]) {
        if (option.searchKey != null) {
          expect(
            keys.add(option.searchKey!),
            isTrue,
            reason: 'searchKey 重复：${option.searchKey}',
          );
        }
      }
    });

    test('标签分组与条目数符合 Han1meViewer 数据源', () {
      expect(hanimeTagGroups, hasLength(7));
      final counts = {
        for (final group in hanimeTagGroups) group.id: group.options.length,
      };
      expect(counts['video_attributes'], 9);
      expect(counts['character_relationships'], 9);
      expect(counts['characteristics'], 47);
      expect(counts['appearance_and_figure'], 47);
      expect(counts['story_location'], 24);
      expect(counts['story_plot'], 45);
      expect(counts['sex_positions'], 54);
      final total = hanimeTagGroups.fold<int>(
        0,
        (sum, group) => sum + group.options.length,
      );
      expect(total, 235);
    });

    test('标签 searchKey 全局唯一（含跨分组）', () {
      final keys = <String>{};
      for (final group in hanimeTagGroups) {
        for (final option in group.options) {
          expect(
            keys.add(option.searchKey!),
            isTrue,
            reason: '标签 searchKey 重复：${option.searchKey}',
          );
        }
      }
    });
  });

  group('Hanime 筛选选项显示名', () {
    test('按语言码选择显示名，未知语言兜底简体', () {
      final genre = hanimeGenres.firstWhere(
        (option) => option.searchKey == '裏番',
      );
      expect(genre.displayName('zh_CN'), '里番');
      expect(genre.displayName('zh-Hant-TW'), '裏番');
      expect(genre.displayName('en_US'), 'Hentai');
      expect(genre.displayName('ja_JP'), '裏番');
      expect(genre.displayName('ko_KR'), '里番');
    });

    test('标签分组显示名按语言码选择', () {
      final group = hanimeTagGroups.firstWhere(
        (group) => group.id == 'sex_positions',
      );
      expect(group.displayName('zh_CN'), '性交体位');
      expect(group.displayName('en'), 'Sex Positions');
      expect(group.displayName('ja'), '性交体位');
    });
  });
}
