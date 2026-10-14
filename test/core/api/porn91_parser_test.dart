import 'package:flule34/core/api/porn91_parser.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 站点把真实播放源写在 `document.write(strencode2("…"))` 里，
/// 容器内另有一条注释掉的诱饵源。下面用与真实标记同形的内联片段锁定解析行为。
String _page({
  required String streamUrl,
  String? posterId = '1248022',
  String? title = '示例中文标题 - 91porn',
  String decoy = 'https://ccm.91p52.com/358999.mp4?st=6dX3e0ya0njWeGIALSBPrA',
  bool commentedDecoy = true,
}) {
  final encoded = Uri.encodeFull("<source src='$streamUrl' type='video/mp4'>");
  return '''
<html><head><title>$title</title></head><body>
<div class="video-container">
  <video id="player_one" poster="https://1729130453.rsc.cdn77.org/thumb/$posterId.jpg">
    ${commentedDecoy ? '<!-- <source src="$decoy" type=\'video/mp4\'> -->' : ''}
    <script>
      document.write(strencode2("$encoded"))
    </script>
  </video>
</div>
</body></html>
''';
}

const _realStream =
    'https://la.btc620.com//mp43/1248022.mp4?st=ZU9CCJLFW2w9mKqH6kvtSA&e=1791970729&f=ecb0Hipy';

void main() {
  group('resolveStreamCandidate', () {
    test('解出 strencode2 编码块里的真实主源', () {
      final candidate = Porn91Parser.resolveStreamCandidate(
        _page(streamUrl: _realStream),
      );

      expect(candidate, isNotNull);
      expect(candidate!.streamUrl, _realStream);
      expect(candidate.mediaId, '1248022');
    });

    test('丢弃注释里的全站固定诱饵源', () {
      final candidate = Porn91Parser.resolveStreamCandidate(
        _page(streamUrl: _realStream),
      );

      expect(candidate!.streamUrl, isNot(contains('358999.mp4')));
      expect(candidate.streamUrl, isNot(contains('ccm.91p52.com')));
    });

    test('只有诱饵、没有编码块时返回 null，而不是退而取诱饵', () {
      final encoded = Uri.encodeFull(
        "<source src='https://ccm.91p52.com/358999.mp4?st=x' type='video/mp4'>",
      );
      final source = _page(streamUrl: _realStream, commentedDecoy: false)
          .replaceFirst(
            RegExp(r'document\.write\(strencode2\(".*?"\)\)'),
            'document.write(strencode2("$encoded"))',
          );

      expect(Porn91Parser.resolveStreamCandidate(source), isNull);
    });

    test('编码块里是未转义单引号时也能完整解码', () {
      // encodeURIComponent 不转义单引号，历史上正则用 [^"']+ 会在此截断。
      final candidate = Porn91Parser.resolveStreamCandidate(
        _page(streamUrl: _realStream),
      );

      expect(candidate!.streamUrl, contains('e=1791970729'));
      expect(candidate.streamUrl, contains('f=ecb0Hipy'));
    });

    test('没有播放器的页面返回 null', () {
      expect(Porn91Parser.resolveStreamCandidate('<html></html>'), isNull);
      expect(Porn91Parser.hasPlayableSource('<html></html>'), isFalse);
    });

    test('http 源被规范化为 https', () {
      final candidate = Porn91Parser.resolveStreamCandidate(
        _page(streamUrl: 'http://la.btc620.com//mp43/555.mp4?st=a'),
      );

      expect(candidate!.streamUrl, startsWith('https://la.btc620.com//mp43/'));
      expect(candidate.mediaId, '555');
    });
  });

  group('posterMediaId / title', () {
    test('取出海报上的媒体编号，用于识别拿到的是哪个视频', () {
      expect(
        Porn91Parser.posterMediaId(_page(streamUrl: _realStream)),
        '1248022',
      );
    });

    test('标题去掉站名尾巴', () {
      expect(Porn91Parser.title(_page(streamUrl: _realStream)), '示例中文标题');
      expect(
        Porn91Parser.title(_page(streamUrl: _realStream, title: '无尾巴标题')),
        '无尾巴标题',
      );
    });
  });

  group('videoList', () {
    test('解析卡片的 viewkey、标题、封面与时长，并按 viewkey 去重', () {
      const source = '''
<html><body>
<div class="col-sm-4">
  <div class="well well-sm videos-text-align">
    <a href="https://w0202.9p47q.com/view_video.php?viewkey=1941962189&page=1&c=auflma&viewtype=basic&category=top">
      <div class="thumb-overlay" id="playvthumb_1245148">
        <img class="img-responsive" src="https://1729130453.rsc.cdn77.org/thumb/1247789.jpg" />
        <div class="hd-text-icon">HD</div>
        <span class="duration">00:22:15</span>
      </div>
      <span class="video-title title-truncate m-t-5">示例中文标题甲</span>
    </a>
  </div>
</div>
<div class="col-sm-4">
  <div class="well well-sm videos-text-align">
    <a href="https://w0202.9p47q.com/view_video.php?viewkey=1716989600&viewtype=basic">
      <div class="thumb-overlay" id="playvthumb_1245148">
        <img class="img-responsive" src="/thumb/1245148.jpg" />
        <span class="duration">00:04:13</span>
      </div>
      <span class="video-title title-truncate m-t-5">示例中文标题乙</span>
    </a>
  </div>
</div>
<a href="https://w0202.9p47q.com/view_video.php?viewkey=1941962189&viewtype=basic">重复条目</a>
</body></html>
''';

      final videos = Porn91Parser.videoList(source);

      expect(videos, hasLength(2));
      expect(videos.map((v) => v.id), ['1941962189', '1716989600']);
      expect(videos.first.siteId, Porn91Parser.siteId);
      expect(videos.first.title, '示例中文标题甲');
      expect(
        videos.first.thumbnailUrl,
        'https://1729130453.rsc.cdn77.org/thumb/1247789.jpg',
      );
      expect(videos.first.duration, '00:22:15');
      // 相对路径封面按站点补全
      expect(videos.last.thumbnailUrl, 'https://91porn.com/thumb/1245148.jpg');
    });

    test('没有 viewkey 的播放页链接被忽略', () {
      const source = '''
<html><body>
<a href="https://w0202.9p47q.com/view_video.php">无 viewkey</a>
</body></html>
''';

      expect(Porn91Parser.videoList(source), isEmpty);
    });
  });

  group('videoDetails', () {
    test('产出单个默认源，不声称具体清晰度', () {
      final details = Porn91Parser.videoDetails(
        source: _page(streamUrl: _realStream),
        fallback: const VideoItem(
          id: '1941962189',
          title: '列表里的标题',
          slug: '1941962189',
          siteId: Porn91Parser.siteId,
        ),
      );

      expect(details.sources, hasLength(1));
      expect(details.sources.single.url, _realStream);
      expect(details.sources.single.isHd, isFalse);
      expect(details.video.title, '示例中文标题');
      expect(details.relatedVideos, isEmpty);
      expect(details.isFavorite, isFalse);
    });

    test('没有直链时 title 回落为列表标题且源为空', () {
      final details = Porn91Parser.videoDetails(
        source: '<html><head><title>91porn</title></head><body></body></html>',
        fallback: const VideoItem(
          id: 'x',
          title: '列表里的标题',
          slug: 'x',
          siteId: Porn91Parser.siteId,
        ),
      );

      expect(details.sources, isEmpty);
      expect(details.video.title, '列表里的标题');
    });
  });

  group('VideoItem 路由到 91porn', () {
    const porn91 = VideoItem(
      id: '1248022',
      title: '示例',
      slug: '1248022',
      siteId: 'porn91',
    );
    const rule34 = VideoItem(id: '1248022', title: 'R34', slug: 'r34');

    test('视频键按站点前缀隔离，不会与 rule34video 撞车', () {
      expect(porn91.contentKey, 'porn91:1248022');
      expect(rule34.contentKey, 'rule34video:1248022');
      expect(porn91.legacyCompatibleStorageId, 'porn91:1248022');
    });

    test('详情路径与规范链接使用 viewkey 查询参数', () {
      expect(porn91.detailPath, '/view_video.php?viewkey=1248022');
      expect(
        porn91.canonicalUri.toString(),
        'https://91porn.com/view_video.php?viewkey=1248022',
      );
    });

    test('detailPath 对 viewkey 做转义，特殊字符不会被拼成第二个参数', () {
      const tricky = VideoItem(
        id: 'a&b=c',
        title: 'x',
        slug: 'x',
        siteId: 'porn91',
      );

      expect(tricky.detailPath, '/view_video.php?viewkey=a%26b%3Dc');
      expect(tricky.canonicalUri.queryParameters['viewkey'], 'a&b=c');
    });

    test('无账号能力，且缩略图不套用 rule34video 的高清升级规则', () {
      expect(porn91.site.capabilities.accountFavorites, isFalse);
      expect(porn91.site.capabilities.accountPlaylists, isFalse);
      expect(porn91.site.capabilities.subscriptions, isFalse);
      expect(porn91.site.capabilities.videoPreviews, isFalse);

      const thumb = VideoItem(
        id: '1',
        title: 'x',
        slug: 'x',
        siteId: 'porn91',
        thumbnailUrl: 'https://cdn.example/thumb/720x540/11.jpg',
      );

      expect(
        thumb.highResolutionThumbnailUrl,
        'https://cdn.example/thumb/720x540/11.jpg',
      );
    });
  });
}
