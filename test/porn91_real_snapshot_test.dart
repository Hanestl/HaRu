import 'dart:io';

import 'package:flule34/core/api/porn91_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用真实 91porn 页面快照验证解析兼容性。
///
/// 站点把播放源放在 `document.write(strencode2("…"))` 的编码块里，容器里
/// 还有一条注释掉的诱饵源；列表页的 class 名也不是语义化的。用内联的理想化
/// 标记做单元测试会与线上漂移，快照锁定真实结构，改版即失败。
void main() {
  test('真实列表页每张卡片都能解析出 viewkey、标题与封面', () {
    final source = File(
      'test/fixtures/porn91_list_snapshot.html',
    ).readAsStringSync();
    final videos = Porn91Parser.videoList(source);

    expect(videos, isNotEmpty);
    final missing = videos
        .where(
          (video) =>
              video.id.isEmpty ||
              video.title.isEmpty ||
              video.thumbnailUrl == null,
        )
        .map((video) => '${video.id} ${video.title}')
        .toList(growable: false);
    expect(missing, isEmpty, reason: '以下卡片字段缺失：$missing');
    for (final video in videos) {
      expect(video.siteId, Porn91Parser.siteId);
      expect(video.thumbnailUrl, startsWith('https://'));
    }
  });

  test('真实详情页快照能解出主源、丢弃诱饵并读出标题', () {
    final source = File(
      'test/fixtures/porn91_watch_snapshot.html',
    ).readAsStringSync();

    final candidate = Porn91Parser.resolveStreamCandidate(source);

    expect(candidate, isNotNull, reason: '详情页快照里应能解出 strencode2 主源');
    expect(candidate!.streamUrl, isNot(contains('358999.mp4')));
    expect(candidate.mediaId, isNotEmpty);
    // 海报编号与主源编号指向同一条视频
    expect(Porn91Parser.posterMediaId(source), candidate.mediaId);
    expect(Porn91Parser.title(source), '示例中文标题');
  });
}
