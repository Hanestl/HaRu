import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/shared/video_list_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('本地视频筛选支持最新排序及多条件取交集', () {
    const videos = [
      VideoItem(
        id: '1',
        title: '较旧高分',
        slug: 'older',
        duration: '4:30',
        publishedLabel: '3 days ago',
        rating: 98,
        ratingVotes: 20,
      ),
      VideoItem(
        id: '2',
        title: '最新高分',
        slug: 'newest',
        duration: '3:00',
        publishedLabel: '2 hours ago',
        rating: 95,
        ratingVotes: 10,
      ),
      VideoItem(
        id: '3',
        title: '最新低分',
        slug: 'low-rating',
        duration: '2:00',
        publishedLabel: '1 hour ago',
        rating: 70,
        ratingVotes: 100,
      ),
    ];

    final result = filterAndSortVideos(
      videos,
      filters: const VideoListFilters(
        sort: VideoListSort.newest,
        duration: VideoDurationPreset.short,
        minRating: 90,
        minVotes: 5,
      ),
    );

    expect(result.map((item) => item.id), ['2', '1']);
  });

  test('发布时间解析兼容 Hanime 中文相对时间', () {
    expect(publishedAgeSeconds('2 小時前'), 7200);
    expect(publishedAgeSeconds('3 天前'), 259200);
    expect(publishedAgeSeconds('昨天'), 86400);
  });

  test('最热与最早排序分别使用观看量和发布时间', () {
    const videos = [
      VideoItem(
        id: '1',
        title: 'A',
        slug: 'a',
        views: 10,
        publishedLabel: '1 天前',
      ),
      VideoItem(
        id: '2',
        title: 'B',
        slug: 'b',
        views: 30,
        publishedLabel: '3 天前',
      ),
    ];
    expect(
      filterAndSortVideos(
        videos,
        filters: const VideoListFilters(sort: VideoListSort.popular),
      ).map((video) => video.id),
      ['2', '1'],
    );
    expect(
      filterAndSortVideos(
        videos,
        filters: const VideoListFilters(sort: VideoListSort.oldest),
      ).map((video) => video.id),
      ['2', '1'],
    );
  });
}
