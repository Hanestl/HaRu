import 'package:flule34/core/models/hanime_search_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HanimeSearchFilters', () {
    test('默认全部为空', () {
      const filters = HanimeSearchFilters();
      expect(filters.isEmpty, isTrue);
      expect(filters.activeCount, 0);
    });

    test('各维度计入 activeCount', () {
      const filters = HanimeSearchFilters(
        genre: '裏番',
        sort: '最新上市',
        duration: '10 分鐘 +',
        date: HanimeDateFilter.preset('過去 24 小時'),
        tags: {'無碼', '中文字幕'},
        brands: {'Queen Bee'},
        broad: true,
      );
      expect(filters.isEmpty, isFalse);
      expect(filters.activeCount, 8);
    });

    test('copyWith 只修改指定字段并复制集合', () {
      const filters = HanimeSearchFilters(tags: {'無碼'});
      final updated = filters.copyWith(genre: '3DCG', tags: const {'中文字幕'});
      expect(updated.genre, '3DCG');
      expect(updated.tags, {'中文字幕'});
      expect(filters.genre, isNull);
      expect(filters.tags, {'無碼'});
    });

    test('copyWith 可清空可空字段', () {
      const filters = HanimeSearchFilters(genre: '裏番', broad: true);
      final cleared = filters.copyWith(genre: null);
      expect(cleared.genre, isNull);
      expect(cleared.broad, isTrue);
      expect(cleared.copyWith(broad: false).isEmpty, isTrue);
    });
  });

  group('HanimeDateFilter', () {
    test('预设时间直接作为 searchKey', () {
      const filter = HanimeDateFilter.preset('過去 1 個月');
      expect(filter.searchKey, '過去 1 個月');
      expect(filter.year, isNull);
    });

    test('指定月份拼装为“YYYY 年 M 月”', () {
      const filter = HanimeDateFilter.month(year: 2026, month: 8);
      expect(filter.searchKey, '2026 年 8 月');
    });

    test('等值比较基于内容而非引用', () {
      const preset = HanimeDateFilter.preset('過去 24 小時');
      const presetAgain = HanimeDateFilter.preset('過去 24 小時');
      const month = HanimeDateFilter.month(year: 2026, month: 8);
      const monthAgain = HanimeDateFilter.month(year: 2026, month: 8);

      expect(preset, presetAgain);
      expect(month, monthAgain);
      expect(preset == month, isFalse);
    });
  });

  group('HanimeSearchLaunch', () {
    test('空参数时无内容', () {
      expect(const HanimeSearchLaunch().hasContent, isFalse);
    });

    test('有查询或筛选时有内容', () {
      expect(const HanimeSearchLaunch(query: '無碼').hasContent, isTrue);
      expect(
        const HanimeSearchLaunch(
          filters: HanimeSearchFilters(genre: '裏番'),
        ).hasContent,
        isTrue,
      );
    });
  });
}
