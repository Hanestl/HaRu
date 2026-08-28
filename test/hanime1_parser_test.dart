import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/hanime1_parser.dart';
import 'package:flule34/core/models/video_models.dart';

void main() {
  test('Hanime 视频键、规范链接和能力与 Rule34Video 隔离', () {
    const rule34 = VideoItem(id: '42', title: 'Rule34', slug: 'rule34');
    const hanime = VideoItem(
      id: '42',
      title: 'Hanime',
      slug: '42',
      siteId: 'hanime1',
    );

    expect(rule34.contentKey, 'rule34video:42');
    expect(hanime.contentKey, 'hanime1:42');
    expect(hanime.canonicalUri.toString(), 'https://hanime1.me/watch?v=42');
    expect(hanime.site.capabilities.accountFavorites, isFalse);
    expect(hanime.site.capabilities.accountPlaylists, isFalse);
    expect(hanime.site.capabilities.videoPreviews, isTrue);
  });

  test('Hanime 缩略图不套用 Rule34Video 的高清升级规则', () {
    const hanime = VideoItem(
      id: '42',
      title: 'Hanime',
      slug: '42',
      siteId: 'hanime1',
      thumbnailUrl: 'https://media.example/thumbs/thumb_720.jpg',
    );
    const rule34 = VideoItem(
      id: '42',
      title: 'Rule34',
      slug: 'rule34',
      thumbnailUrl: 'https://img.example/whatever/720x540/11.jpg',
    );

    // rule34video 的路径会被升级为 preview.jpg；hanime 路径原样保留。
    expect(
      hanime.highResolutionThumbnailUrl,
      'https://media.example/thumbs/thumb_720.jpg',
    );
    expect(
      rule34.highResolutionThumbnailUrl,
      'https://img.example/whatever/preview.jpg',
    );
  });

  const listHtml = '''
    <div class="video-card">
      <a href="/watch?v=407610" title="Example Hanime">
        <img data-src="//img.example/thumb.jpg" alt="Example Hanime">
      </a>
      <div class="home-rows-videos-title">Example Hanime</div>
      <span class="meta-stats">12.5K</span>
      <span class="meta-published">2 days ago</span>
    </div>
  ''';

  test('解析 Hanime 视频卡片并保留来源标识', () {
    final items = HanimePageParser.videoList(listHtml);

    expect(items, hasLength(1));
    expect(items.single.id, '407610');
    expect(items.single.siteId, 'hanime1');
    expect(items.single.thumbnailUrl, 'https://img.example/thumb.jpg');
    expect(items.single.views, 12500);
  });

  test('视频卡片分别解析点赞率、观看次数、艺术家和上传时间', () {
    const html = '''
      <div class="video-item-container" title="Card title">
        <a class="video-link" href="/watch?v=card-meta">
          <img src="https://img.example/card.jpg">
          <div class="stats-container">
            <div class="stat-item">98%</div>
            <div class="stat-item">1.2K</div>
          </div>
        </a>
        <div class="subtitle"><a>Example Artist</a> • 3 天前</div>
      </div>
    ''';

    final video = HanimePageParser.videoList(html).single;

    expect(video.rating, 98);
    expect(video.views, 1200);
    expect(video.creatorLabel, 'Example Artist');
    expect(video.publishedLabel, '3 天前');
  });

  test('解析 Hanime 原生首页分区并清理查看更多文本', () {
    const html = '''
      <a href="/search?sort=1">
        <h3>最新上傳<div><span>查看</span>更多<span>arrow_forward_ios</span></div></h3>
      </a>
      <div>
        <div class="home-rows-videos-wrapper">
          <div class="video-item-container">
            <a class="video-link" href="/watch?v=section-1">
              <img src="https://img.example/section.jpg">
              <div class="title">Section Video</div>
            </a>
          </div>
        </div>
      </div>
    ''';

    final sections = HanimePageParser.homeSections(html);

    expect(sections, hasLength(1));
    expect(sections.single.title, '最新上傳');
    expect(sections.single.items.single.contentKey, 'hanime1:section-1');
  });

  test('相关视频标题链接不会覆盖同一卡片已经解析出的封面', () {
    const html = '''
      <div class="playlist-video-card video-item-container">
        <div class="video-thumb-container horizontal-card">
          <a href="/watch?v=407612">
            <img class="main-thumb" src="https://img.example/related.jpg">
          </a>
        </div>
        <div class="video-info-container">
          <h4 class="video-title">
            <a href="/watch?v=407612">Related Hanime</a>
          </h4>
        </div>
      </div>
    ''';

    final items = HanimePageParser.videoList(html);

    expect(items, hasLength(1));
    expect(items.single.title, 'Related Hanime');
    expect(items.single.thumbnailUrl, 'https://img.example/related.jpg');
  });

  test('解析详情页的标题、标签、作者和多清晰度源', () {
    const html = '''
      <html><head><meta property="og:image" content="https://img/x.jpg"></head>
      <body>
        <h1 id="shareBtn-title">Example Detail</h1>
        <div class="description">A short description</div>
        <div class="video-tags"><a href="/tags/3d">3D</a><a href="/tags/uncensored">Uncensored</a></div>
        <a href="/artist/example">Example Studio</a>
        <div class="video-caption-text">由 <a href="/user/123">zyt</a> 上传</div>
        <form id="video-subscribe-form">
          <input name="subscribe-artist-id" value="artist-7">
          <input name="subscribe-status" value="1">
        </form>
        <input name="like-status" value="1">
        <input name="unlike-status" value="">
        <input name="likes-count" value="42">
        <input name="unlikes-count" value="3">
        <div class="playlist-checkbox-wrapper"><input id="list-abc" checked></div>
        <video id="player">
          <source size="1080" src="https://cdn/x-1080.mp4">
          <source size="480" src="https://cdn/x-480.mp4">
        </video>
      </body></html>
    ''';
    const fallback = VideoItem(
      id: '407610',
      title: 'Fallback',
      slug: '407610',
      siteId: 'hanime1',
    );

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: fallback,
    );

    expect(details.video.title, 'Example Detail');
    expect(details.tags, containsAll(<String>['3D', 'Uncensored']));
    expect(details.models, contains('Example Studio'));
    expect(details.uploader?.id, '123');
    expect(details.uploader?.name, 'zyt');
    expect(details.isUploaderSubscribed, isTrue);
    expect(details.hanimeLiked, isTrue);
    expect(details.hanimeLikes, 42);
    expect(details.hanimeDislikes, 3);
    expect(details.playlistIds, {'list-abc'});
    expect(
      details.sources.map((source) => source.label),
      containsAll(<String>['1080p', '480p']),
    );
    // Hanime1 元数据 path 使用搜索语义而非 rule34video 集合页路径。
    final tagItem = details.metadataItems.firstWhere(
      (item) => item.kind == DiscoveryKind.tag && item.title == '3D',
    );
    expect(tagItem.path, '/search?query=3D');
    final artistItem = details.metadataItems.firstWhere(
      (item) => item.kind == DiscoveryKind.model,
    );
    // Uri.encodeQueryComponent 对空格使用 +、中文百分号编码。
    expect(artistItem.path, '/search?query=Example+Studio');
  });

  test('单集系列也保留系列播放清单', () {
    const html = '''
      <h1 id="shareBtn-title">Single Episode</h1>
      <div id="video-playlist-wrapper">
        <h4>Only Episode Series</h4>
        <div id="playlist-scroll" class="hover-video-playlist">
          <div class="video-item-container" title="Only Episode">
            <a href="/watch?v=single-series">
              <img src="https://img.example/single.jpg">
            </a>
          </div>
        </div>
      </div>
    ''';
    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: const VideoItem(
        id: 'single-series',
        title: 'Fallback',
        slug: 'single-series',
        siteId: 'hanime1',
      ),
    );

    expect(details.seriesTitle, 'Only Episode Series');
    expect(details.seriesVideos, hasLength(1));
    expect(details.seriesVideos.single.id, 'single-series');
  });

  test('详情简介按观看信息、标题、上传者和正文分层解析', () {
    const html = '''
      <div class="video-details-wrapper">
        <div><div><div>觀看次數：12,345次 2026-08-18</div></div></div>
        <div>中文副标题</div>
        <div class="video-caption-text">
          由 <a href="/user/99">zyt</a> 上傳 · 这是正文内容
        </div>
      </div>
    ''';
    const fallback = VideoItem(
      id: 'description-parts',
      title: 'Fallback',
      slug: 'description-parts',
      siteId: 'hanime1',
    );

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: fallback,
    );

    expect(details.video.views, 12345);
    expect(details.video.publishedLabel, '2026-08-18');
    expect(details.descriptionTitle, '中文副标题');
    expect(details.description, '这是正文内容');
    expect(details.uploader?.name, 'zyt');
  });

  test('Hanime 分类元数据使用 genre 搜索路径', () {
    const html = '''
      <body>
        <h1 id="shareBtn-title">Category Detail</h1>
        <div class="video-info">
          <div class="category"><a href="/search?genre=裏番">裏番</a></div>
        </div>
      </body>
    ''';
    const fallback = VideoItem(
      id: 'cat-1',
      title: 'Fallback',
      slug: 'cat-1',
      siteId: 'hanime1',
    );

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: fallback,
    );

    final categoryItems = details.metadataItems
        .where((item) => item.kind == DiscoveryKind.category)
        .toList();
    expect(categoryItems, isNotEmpty);
    expect(categoryItems.first.title, '裏番');
    expect(categoryItems.first.path, '/search?genre=%E8%A3%8F%E7%95%AA');
  });

  test('详情标签忽略站点的添加和移除控制按钮', () {
    const html = '''
      <div class="video-tags">
        <a href="/tags/ntr">NTR</a>
        <a><span class="material-icons">add</span></a>
        <a><span class="material-icons-outlined">remove</span></a>
      </div>
    ''';
    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: const VideoItem(
        id: 'tag-controls',
        title: 'Fallback',
        slug: 'tag-controls',
        siteId: 'hanime1',
      ),
    );

    expect(details.tags, ['NTR']);
  });

  test('解析脱敏后的 2026-08 Hanime 真实 DOM 结构快照', () {
    final html = File(
      'test/fixtures/hanime_watch_202608_fragment.html',
    ).readAsStringSync();
    const fallback = VideoItem(
      id: 'fixture',
      title: 'Fallback',
      slug: 'fixture',
      siteId: 'hanime1',
    );

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: fallback,
    );

    expect(details.video.title, 'Example Hanime');
    expect(details.models, contains('Example Artist'));
    expect(details.tags, containsAll(<String>['3D', 'MMD']));
    expect(details.sources.map((item) => item.label), ['1080p', '720p']);
    expect(details.relatedVideos.single.id, 'related-1');
    expect(
      details.relatedVideos.single.thumbnailUrl,
      'https://media.example/related.jpg',
    );
  });

  test('识别 Cloudflare 验证页', () {
    expect(
      HanimePageParser.isChallenge(
        '<html><title>Just a moment...</title><body>Checking your browser</body></html>',
      ),
      isTrue,
    );
    expect(
      HanimePageParser.isChallenge(
        '<html><title>Attention Required! | Cloudflare</title>'
        '<body>You have been blocked</body></html>',
      ),
      isTrue,
    );
  });

  test('解析 Hanime 表单校验错误', () {
    expect(
      HanimePageParser.formErrors(
        '<div class="invalid-feedback">邮箱格式不正确</div>',
      ),
      ['邮箱格式不正确'],
    );
  });

  test('解析 video 自身的视频地址并忽略 blob 地址', () {
    const html = '''
      <video id="player" src="https://cdn.example/video.mp4" height="720"></video>
      <video src="blob:https://hanime1.me/not-native-playable"></video>
    ''';
    const fallback = VideoItem(
      id: '407611',
      title: 'Direct source',
      slug: '407611',
      siteId: 'hanime1',
    );

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: fallback,
    );

    expect(details.sources, hasLength(1));
    expect(details.sources.single.label, '720p');
    expect(details.sources.single.url, 'https://cdn.example/video.mp4');
  });

  test('真实搜索卡片从容器 div 的 title 属性提取标题', () {
    // 搜索页卡片：标题在卡片 div 的 title 属性，链接本身为空 overlay。
    const html = '''
      <div title="[示例] 深夜探访 [中文字幕]" class="col-xs-6 search-doujin-videos">
        <a class="overlay" href="/watch?v=114377"></a>
        <div class="card-mobile-panel inner">
          <img src="https://img.example/thumb.jpg">
        </div>
      </div>
    ''';

    final items = HanimePageParser.videoList(html);

    expect(items, hasLength(1));
    expect(items.single.id, '114377');
    expect(items.single.title, '[示例] 深夜探访 [中文字幕]');
    expect(items.single.thumbnailUrl, 'https://img.example/thumb.jpg');
  });
}
