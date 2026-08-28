import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/hanime1_parser.dart';
import 'package:flule34/core/models/video_models.dart';

/// 用 Wayback Machine 抓取的 hanime1.me 真实页面快照验证解析器兼容性。
///
/// 这些快照来自真实站点的搜索/详情页（归档时间 2025-08 ~ 2026-04），
/// 快照内的超链接带有 web.archive.org 前缀，但卡片结构与真实页面一致，
/// 可用于防止解析器回归。文件较大，勿放入常规 commit 的 fixture 之外。
void main() {
  group('真实搜索页快照', () {
    test('tags[]=中文字幕 结果可解析且标题完整', () {
      final html = File(
        'test/fixtures/hanime_search_snapshot.html',
      ).readAsStringSync();
      final items = HanimePageParser.videoList(html);

      expect(items, isNotEmpty);
      expect(items.first.id, '114377');
      // 真实卡片标题来自容器 div 的 title 属性。
      expect(items.first.title, contains('中文字幕'));
      expect(items.first.title, isNot('未命名视频'));
    });

    test('genre=裏番 结果可解析且无未命名视频', () {
      final html = File(
        'test/fixtures/hanime_genre_snapshot.html',
      ).readAsStringSync();
      final items = HanimePageParser.videoList(html);

      expect(items, isNotEmpty);
      final unnamed = items.where((item) => item.title == '未命名视频').length;
      expect(unnamed, 0);
      expect(items.every((item) => item.thumbnailUrl != null), isTrue);
    });
  });

  group('真实详情页快照', () {
    test('标题、标签可解析', () {
      final html = File(
        'test/fixtures/hanime_watch_snapshot.html',
      ).readAsStringSync();
      const fallback = VideoItem(
        id: '404990',
        title: 'Fallback',
        slug: '404990',
        siteId: 'hanime1',
      );
      final details = HanimePageParser.videoDetails(
        source: html,
        fallback: fallback,
      );

      expect(details.video.title, isNot('Fallback'));
      expect(details.video.title, isNotEmpty);
      expect(details.tags, isNotEmpty);
      expect(details.video.siteId, 'hanime1');
      // 该快照中的网站系列恰好包含 4 集；这不是解析器对系列长度的要求。
      expect(
        details.seriesVideos.map((item) => item.id),
        containsAll(<String>['404990', '404989', '157878', '157877']),
      );
      expect(details.seriesVideos, hasLength(4));
      expect(details.relatedVideos, isNotEmpty);
      expect(
        details.relatedVideos.map((item) => item.id),
        isNot(contains('404989')),
      );
    });
  });
}
