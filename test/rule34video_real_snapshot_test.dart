import 'dart:io';

import 'package:flule34/core/api/site_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用真实 rule34video.com 列表页快照验证列表解析兼容性。
///
/// 站点对首屏之后的卡片使用延迟加载：`src` 是 data: 占位图，真实封面在
/// `data-rd-src`。此前只按内联的理想化标记（`data-original`）做单元测试，
/// 真实标记一变就漏检，导致第 5 个卡片起全部黑屏。该快照锁定真实结构，
/// 防止这类「测试与线上标记漂移」的回归。
void main() {
  test('真实列表页每张卡片都能解析出封面地址', () {
    final source = File(
      'test/fixtures/rule34_latest_snapshot.html',
    ).readAsStringSync();
    final videos = SiteParser.videoList(source);

    expect(videos, isNotEmpty);
    final missing = videos
        .where((v) => v.thumbnailUrl == null)
        .map((v) => '${v.id} ${v.title}')
        .toList(growable: false);
    expect(missing, isEmpty, reason: '以下卡片没有解析出封面：$missing');
    for (final video in videos) {
      expect(video.thumbnailUrl, startsWith('https://rule34video.com/'));
    }
  });
}
