import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/shared/video_range_filters.dart';
import 'package:flule34/shared/video_list_filters.dart';

void main() {
  test('范围状态计数、切换预设、局部更新及本地边界筛选', () {
    final filters = SearchFilters(
      customDateRange: VideoDateRange(to: DateTime(2026, 1, 1)),
      customDurationRange: const VideoDurationRange(
        minSeconds: 60,
        maxSeconds: 120,
      ),
    );
    expect(filters.isEmpty, false);
    expect(filters.hasServerFilters, true);
    expect(filters.activeCount, 2);
    expect(
      filters.copyWith(verifiedOnly: true).customDateRange,
      same(filters.customDateRange),
    );
    final reset = filters.copyWith(
      uploadPeriod: UploadPeriod.anytime,
      duration: VideoDurationPreset.any,
    );
    expect(reset.isEmpty, true);
    expect(reset.rangeKey, isNot(filters.rangeKey));
    expect(const VideoDurationRange(minSeconds: -1).isValid, false);
    expect(const VideoDurationRange(maxSeconds: 36001).isValid, false);
    expect(
      const VideoDurationRange(minSeconds: 120, maxSeconds: 60).isValid,
      false,
    );
    expect(
      filterAndSortVideos(
        const [
          VideoItem(id: '1', title: 'A', slug: 'a', duration: '0:59'),
          VideoItem(id: '2', title: 'B', slug: 'b', duration: '1:00'),
          VideoItem(id: '3', title: 'C', slug: 'c', duration: '2:00'),
          VideoItem(id: '4', title: 'D', slug: 'd', duration: '2:01'),
        ],
        filters: const VideoListFilters(
          customDurationRange: VideoDurationRange(
            minSeconds: 60,
            maxSeconds: 120,
          ),
        ),
      ).map((video) => video.id),
      ['2', '3'],
    );
  });

  testWidgets('时长弹窗校验范围并保留取消前条件，清空后回到不限', (tester) async {
    var filters = const SearchFilters();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => VideoRangeFilter(
              filters: filters,
              onChanged: (next) => setState(() => filters = next),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.byType(VideoRangeFilter));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义…'));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.enterText(find.byType(TextFormField).first, '120');
    await tester.enterText(find.byType(TextFormField).last, '60');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('最长时长不能小于最短时长'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(filters.customDurationRange?.minSeconds, 120);
    expect(filters.customDurationRange?.maxSeconds, null);
    await open();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '120',
    );
    await tester.enterText(find.byType(TextFormField).first, '300');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(filters.customDurationRange?.minSeconds, 120);
    await open();
    await tester.tap(find.text('清空'));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(filters.isEmpty, true);
  });

  testWidgets('日期弹窗支持单边界、逆序校验及取消', (tester) async {
    VideoDateRange? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showVideoDateRangeDialog(
                  context,
                  VideoDateRange(
                    from: DateTime(2026, 2, 1),
                    to: DateTime(2026, 1, 1),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('结束日期不能早于开始日期'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(result?.from, null);
    expect(result?.to, DateTime(2026, 1, 1));
  });
}
