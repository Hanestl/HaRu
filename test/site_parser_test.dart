import 'package:flule34/core/api/site_parser.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析列表中的视频卡片', () {
    const source = '''
      <div class="item thumb video_1">
        <a class="th js-open-popup"
           href="https://rule34video.com/video/1234567/example-video/"
           title="Example video">
          <div class="img wrap_image" data-preview="/preview.mp4">
            <img class="thumb" data-original="/thumbnail.jpg" alt="Example video">
          </div>
        </a>
        <div class="time">2:34</div>
        <div class="thumb_title">Example video</div>
        <div class="thumb_info">
          <div class="added">23 minutes ago</div>
          <div class="rating">100% (2)</div>
          <div class="views">1.2K</div>
        </div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '1234567');
    expect(videos.single.slug, 'example-video');
    expect(videos.single.title, 'Example video');
    expect(videos.single.thumbnailUrl, 'https://rule34video.com/thumbnail.jpg');
    expect(videos.single.previewUrl, 'https://rule34video.com/preview.mp4');
    expect(videos.single.duration, '2:34');
    expect(videos.single.publishedLabel, '23 minutes ago');
    expect(videos.single.rating, 100);
    expect(videos.single.ratingVotes, 2);
    expect(videos.single.views, 1200);
  });

  test('解析列表首屏之后延迟加载卡片的封面', () {
    const source = '''
      <div class="item thumb video_4665858">
        <a class="th" href="https://rule34video.com/video/4665858/lazy-video/"
           title="Lazy video">
          <div class="img wrap_image" data-preview="/preview.mp4">
            <img class="thumb rd-lz"
                 src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
                 data-rd-src="https://rule34video.com/contents/videos_screenshots/4665000/4665858/336x189/1.jpg"
                 data-rd-jpg="https://rule34video.com/contents/videos_screenshots/4665000/4665858/320x180/1.jpg"
                 alt="Lazy video" loading="lazy">
          </div>
        </a>
        <div class="thumb_title">Lazy video</div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(
      videos.single.thumbnailUrl,
      'https://rule34video.com/contents/videos_screenshots/4665000/4665858/336x189/1.jpg',
    );
  });

  test('解析播放列表编辑表单', () {
    const source = '''
      <form action="/edit-playlist/42/">
        <input name="title" value="精选列表">
        <textarea name="description">只保留高质量视频</textarea>
        <input type="hidden" name="is_private" value="0">
        <input type="checkbox" name="is_private" value="1" checked>
      </form>
    ''';

    final form = SiteParser.playlistForm(source);

    expect(form.title, '精选列表');
    expect(form.description, '只保留高质量视频');
    expect(form.isPrivate, isTrue);
  });

  test('从页面上下文解析稳定用户 ID', () {
    const source = '''
      <script>
        pageContext = { userId: '2421071', locale: 'en' };
      </script>
    ''';

    expect(SiteParser.userId(source), '2421071');
    expect(SiteParser.userId('<html>logged out</html>'), isNull);
  });

  test('解析成员资料中的名称、头像和订阅数', () {
    const source = '''
      <div class="channel_logo">
        <div class="avatar">
          <img src="data:image/gif;base64,placeholder"
               data-original="/contents/avatars/98000/98965.png"
               alt="">
        </div>
        <h2 class="title">Oppai3Dporn</h2>
        <div class="subscribers_count">25K <span>Subscribers</span></div>
      </div>
    ''';

    final profile = SiteParser.memberProfile(source, '98965');

    expect(profile, isNotNull);
    expect(profile!.id, '98965');
    expect(profile.displayName, 'Oppai3Dporn');
    expect(
      profile.avatarUrl,
      'https://rule34video.com/contents/avatars/98000/98965.png',
    );
    expect(profile.subscribersLabel, '25K Subscribers');
  });

  test('解析账号订阅实体并识别类型', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/contents/models/87/artist.jpg"
               alt="Example Artist">
        </a>
      </div>
      <div class="item">
        <a href="/categories/123/example-category/">Example Category</a>
      </div>
    ''';

    final subscriptions = SiteParser.subscriptions(source);

    expect(subscriptions, hasLength(2));
    expect(subscriptions.first.kind.name, 'model');
    expect(subscriptions.first.path, '/models/example-artist/');
    expect(
      subscriptions.first.thumbnailUrl,
      'https://rule34video.com/contents/models/87/artist.jpg',
    );
    expect(subscriptions.last.kind.name, 'category');
    expect(subscriptions.last.title, 'Example Category');
  });

  test('解析没有实体链接的分类订阅表单项', () {
    const source = '''
      <form data-block-id="list_members_subscriptions_my_subscriptions">
        <div class="item">
          <a href="#" class="title wrap-item"><span class="name">Final Fantasy</span></a>
          <input type="checkbox" name="delete[]" value="23518381">
        </div>
      </form>
    ''';

    final subscriptions = SiteParser.subscriptions(source);

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.kind, SubscriptionKind.category);
    expect(subscriptions.single.title, 'Final Fantasy');
    expect(subscriptions.single.path, '/categories/final-fantasy/');
  });

  test('解析发现目录实体并去重', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/contents/models/87/artist.jpg"
               alt="Example Artist">
        </a>
        <span>42 videos</span>
      </div>
      <a href="/models/example-artist/">重复链接</a>
    ''';

    final items = SiteParser.contentCollections(source, DiscoveryKind.model);

    expect(items, hasLength(1));
    expect(items.single.id, 'example-artist');
    expect(items.single.filterId, '87');
    expect(items.single.title, 'Example Artist');
    expect(items.single.total, 42);
    expect(items.single.path, '/models/example-artist/');
  });

  test('直接解析艺术家详情页头像', () {
    const source = '''
      <div class="brand_image">
        <div class="brand_image_wrapper">
          <img src="/contents/models/446/juicyneko.jpg" alt="Juicyneko">
        </div>
      </div>
    ''';

    expect(
      SiteParser.collectionAvatar(source),
      'https://rule34video.com/contents/models/446/juicyneko.jpg',
    );
  });

  test('动态解析4K视频源并规范化清晰度', () {
    const source = '''
      <link rel="canonical" href="/video/123/example/">
      <script>
        flashvars = {
          video_url: 'https://cdn.example.com/example_360.mp4',
          video_url_text: '360p',
          video_alt_url3: 'https://cdn.example.com/example_1080p.mp4',
          video_alt_url3_text: '1080p',
          video_alt_url4: 'https://cdn.example.com/example_2160p.mp4',
          video_alt_url4_text: '4k'
        };
      </script>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.sources.map((item) => item.label), [
      '2160p (4K)',
      '1080p',
      '360p',
    ]);
    expect(details.sources.first.isHd, isTrue);
  });

  test('视频源宽高标签使用第二个数字作为高度', () {
    const source = '''
      <link rel="canonical" href="/video/123/example/">
      <script>
        flashvars = {
          video_url: 'https://cdn.example.com/example-a.mp4',
          video_url_text: '1280x540',
          video_alt_url1: 'https://cdn.example.com/example-b.mp4',
          video_alt_url1_text: '1920×1080'
        };
      </script>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    // 高清晰度在上：1080p 排最前，540p 兜底在最后。
    expect(details.sources.map((item) => item.isHd), [isTrue, isFalse]);
  });

  test('详情脚本标题可解析转义直引号和 Unicode', () {
    const source = r'''
      <link rel="canonical" href="/video/123/tifa-cloud-gongaga/">
      <script>
        flashvars = {
          video_title: '\'Tifa \u0026 Cloud: Gongaga\'',
          video_url: 'https:\/\/cdn.example.com\/tifa.mp4',
          video_url_text: '1080p'
        };
      </script>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(
        id: '123',
        title: 'Fallback title',
        slug: 'tifa-cloud-gongaga',
      ),
    );

    expect(details.video.title, "'Tifa & Cloud: Gongaga'");
    expect(details.sources.single.url, 'https://cdn.example.com/tifa.mp4');
  });

  test('收藏状态只读取当前视频主操作区', () {
    const unrelated = '''
      <a class="delete button_fav">Delete from Favorites</a>
      <div id="tab_video_info">
        <a class="button_fav">Add to Favorites</a>
      </div>
    ''';
    const current = '''
      <div id="tab_video_info">
        <a class="delete button_fav">Delete from Favorites</a>
      </div>
    ''';
    const fallback = VideoItem(id: '123', title: 'Example', slug: 'example');

    expect(
      SiteParser.videoDetails(source: unrelated, fallback: fallback).isFavorite,
      isFalse,
    );
    expect(
      SiteParser.videoDetails(source: current, fallback: fallback).isFavorite,
      isTrue,
    );
  });

  test('视频评论解析评论者头像', () {
    const source = '''
      <div id="video_comments_video_comments_items">
        <div class="item row" data-comment-id="77">
          <div class="user-logo">
            <img data-original="/contents/avatars/77.png">
          </div>
          <div class="comment-info">
            <div class="inner"><a>Example User</a></div>
            <div class="date"><span>1 hour ago</span></div>
            <div class="coment-text">Example comment</div>
          </div>
        </div>
      </div>
    ''';

    final comments = SiteParser.videoComments(source);

    expect(comments, hasLength(1));
    expect(
      comments.single.avatarUrl,
      'https://rule34video.com/contents/avatars/77.png',
    );
  });

  test('解析账号播放列表', () {
    const source = '''
      <div class="item">
        <a href="/my/playlists/42/example/" title="Example playlist">
          <img src="/playlist.jpg" alt="Example playlist">
        </a>
        <span>12 videos</span>
        <span>345 views</span>
      </div>
    ''';

    final playlists = SiteParser.playlists(source);

    expect(playlists, hasLength(1));
    expect(playlists.single.id, '42');
    expect(playlists.single.videoCount, 12);
    expect(playlists.single.views, 345);
  });

  test('播放列表内容页链接不被其后的编辑页链接覆盖', () {
    // 真实「我的播放列表」页每张卡片先给内容页 /playlists/<id>/<slug>/，
    // 再给编辑页 /my/playlists/<id>/；按 id 去重时编辑页会覆盖内容页，
    // 导致列表内视频无法翻页。
    const source = '''
      <div class="item thumb">
        <a class="th" href="/playlists/2907071/test1104/">
          <div class="thumb_title">test1</div>
        </a>
        <div class="item-control headline_panel">
          <a class="toggle-button btn" href="/my/playlists/2907071/">Edit</a>
        </div>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.id, '2907071');
    expect(playlist.path, '/playlists/2907071/test1104/');
  });

  test('只有编辑页链接时仍按编辑页解析', () {
    const source = '''
      <div class="item thumb">
        <a class="toggle-button btn" href="/my/playlists/2907071/">Edit</a>
        <div class="thumb_title">test1</div>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.path, '/my/playlists/2907071/');
  });

  test('播放列表名称优先于封面中的首个视频名称', () {
    const source = '''
      <div class="item">
        <a class="thumb" href="/my/playlists/42/selected/" title="首个视频">
          <img src="/video.jpg" alt="首个视频">
        </a>
        <div class="title">
          <a href="/my/playlists/42/selected/">真正的播放列表名称</a>
        </div>
        <span>3 videos</span>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.title, '真正的播放列表名称');
  });

  test('播放列表卡片把标题、视频数和浏览量分别解析', () {
    const source = '''
      <div class="item thumb">
        <a class="th" href="/playlists/2744709/test1104/">
          <div class="img wrap_image">
            <img src="/video1.jpg" alt="第一个视频">
          </div>
          <div class="thumb_title">test1</div>
          <div class="thumb_info">
            <div class="added">3 videos</div>
            <div class="views">3</div>
          </div>
        </a>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.title, 'test1');
    expect(playlist.videoCount, 3);
    expect(playlist.views, 3);
  });

  test('视频详情解析已经加入的播放列表 ID', () {
    const source = '''
      <ul class="btn-favourites">
        <li id="delete_playlist_42">
          <a class="delete" data-fav-type="10" data-playlist-id="42"></a>
        </li>
        <li id="add_playlist_42" class="hidden">
          <a href="#add_to_playlist" data-fav-type="10" data-playlist-id="42"></a>
        </li>
        <li id="delete_playlist_77" class="hidden">
          <a class="delete" data-fav-type="10" data-playlist-id="77"></a>
        </li>
        <li id="add_playlist_77">
          <a href="#add_to_playlist" data-fav-type="10" data-playlist-id="77"></a>
        </li>
      </ul>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.playlistIds, {'42'});
  });

  test('解析视频元数据投票项、评分票数和评论', () {
    const source = '''
      <script type="application/ld+json">
        {"@type":"VideoObject","name":"Example","uploadDate":"2026-07-24"}
      </script>
      <div class="action_rating">
        <div class="voters count">94% (1,234)</div>
      </div>
      <div class="col">
        <div class="label">Uploaded by</div>
        <a href="/members/42/">
          <img src="/uploader.jpg" alt="Example Uploader">
          <span class="verified-status"></span>
        </a>
      </div>
      <a href="#tab_comments">Comments (2)</a>
      <span class="js-video-vote-chip"
            data-item-type="category"
            data-item-id="199"
            data-up-score="8"
            data-down-score="2">
        <a href="/categories/3d/"><span>3D</span></a>
      </span>
      <span class="js-video-vote-chip"
            data-item-type="model"
            data-item-id="639">
        <a href="/models/example-artist/">
          <img src="/contents/models/639/artist.jpg" alt="Example Artist">
        </a>
      </span>
      <div id="video_comments_video_comments_items">
        <div class="item" data-comment-id="77">
          <div class="user-logo"><img src="/avatar.jpg"></div>
          <div class="comment-info">
            <div class="inner"><a href="/members/42/">Tester</a></div>
          </div>
          <div class="date"><span>2 days ago</span></div>
          <div class="coment-text">A useful comment.</div>
        </div>
      </div>
      <div class="item thumb video_456">
        <a class="th js-open-popup" href="/video/456/related/" title="Related">
          <img class="thumb" data-original="/related.jpg" alt="Related">
        </a>
        <div class="time">1:23</div>
        <div class="thumb_title">Related</div>
      </div>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.ratingVotes, 1234);
    expect(details.metadataItems, hasLength(2));
    expect(details.metadataItems.first.id, '199');
    expect(details.metadataItems.first.upScore, 8);
    expect(details.categories, ['3D']);
    expect(details.models, ['Example Artist']);
    expect(
      details.metadataItems.last.thumbnailUrl,
      'https://rule34video.com/contents/models/639/artist.jpg',
    );
    expect(details.video.publishedLabel, '2026-07-24');
    expect(details.relatedVideos.single.id, '456');
    expect(details.uploader?.id, '42');
    expect(details.uploader?.name, 'Example Uploader');
    expect(details.uploader?.avatarUrl, 'https://rule34video.com/uploader.jpg');
    expect(details.uploader?.verified, isTrue);
    expect(
      SiteParser.isVideoDetailsPage(
        '<link rel="canonical" href="/video/123/example/">',
        '123',
      ),
      isTrue,
    );
  });

  test('识别 HTTP 200 异步操作中的服务端错误', () {
    expect(
      SiteParser.asyncActionError('<error>IP already voted</error>'),
      'IP already voted',
    );
    expect(SiteParser.asyncActionError('<success/>'), isNull);
  });

  test('解析 Rule34Video 详情页评论（真实结构）', () {
    // 来自 rule34video.com/video/3087141 的浏览器实测结构。
    const source = '''
      <div id="video_comments_video_comments_items">
        <div class="item row " data-comment-id="1116991">
          <div class="comment-inner">
            <div class="user-logo">
              <div class="wrap_image">
                <a href="https://rule34video.com/members/4270719/">
                  <svg class="custom-svg custom-brand"><use xlink:href="#custom-brand"></use></svg>
                </a>
              </div>
            </div>
            <div class="comment-info">
              <div class="inner">
                <a href="https://rule34video.com/members/4270719/">Isaxx</a>
                <div class="date"><span>7 months ago</span></div>
              </div>
              <div class="coment-text">
                I wanna be fucked like this btw
              </div>
            </div>
          </div>
        </div>
        <div class="item row " data-comment-id="1107428">
          <div class="comment-inner">
            <div class="comment-info">
              <div class="inner">
                <a href="https://rule34video.com/members/3757078/">snsnsnn</a>
                <div class="date"><span>7 months ago</span></div>
              </div>
              <div class="coment-text">
                i want fuck her
              </div>
            </div>
          </div>
        </div>
      </div>
    ''';

    final comments = SiteParser.videoComments(source);

    expect(comments, hasLength(2));
    expect(comments[0].id, '1116991');
    expect(comments[0].username, 'Isaxx');
    expect(comments[0].content, 'I wanna be fucked like this btw');
    expect(comments[0].dateLabel, '7 months ago');
    expect(comments[1].id, '1107428');
    expect(comments[1].username, 'snsnsnn');
    expect(comments[1].content, 'i want fuck her');
  });

  test('评论解析在容器缺失或缺少字段时跳过或返回空', () {
    expect(SiteParser.videoComments('<html></html>'), isEmpty);
    expect(
      SiteParser.videoComments(
        '<div id="video_comments_video_comments_items"></div>',
      ),
      isEmpty,
    );
    // 缺少 data-comment-id 或评论内容时跳过该条。
    const partial = '''
      <div id="video_comments_video_comments_items">
        <div class="item row" data-comment-id="1">
          <div class="comment-info">
            <div class="inner"><a href="/members/1/">Alice</a></div>
          </div>
        </div>
        <div class="item row" data-comment-id="2">
          <div class="comment-info">
            <div class="inner"><a href="/members/2/">Bob</a></div>
            <div class="coment-text">valid</div>
          </div>
        </div>
      </div>
    ''';
    final comments = SiteParser.videoComments(partial);
    expect(comments, hasLength(1));
    expect(comments.single.username, 'Bob');
    expect(comments.single.content, 'valid');
  });

  test('解析采用 rd-lz 懒加载属性的视频卡片封面', () {
    const source = '''
      <div class="item thumb video_6">
        <a class="th js-open-popup"
           href="https://rule34video.com/video/4665842/nurse-futa/"
           title="Nurse Futa">
          <div class="img wrap_image" data-preview="/preview.mp4">
            <img class="thumb rd-lz"
                 src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
                 data-rd-src="https://rule34video.com/contents/videos_screenshots/4665000/4665842/336x189/2.jpg"
                 data-rd-jpg="https://rule34video.com/contents/videos_screenshots/4665000/4665842/320x180/2.jpg"
                 alt="Nurse Futa">
          </div>
        </a>
        <div class="time">3:04</div>
        <div class="thumb_title">Nurse Futa</div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '4665842');
    expect(
      videos.single.thumbnailUrl,
      'https://rule34video.com/contents/videos_screenshots/4665000/4665842/336x189/2.jpg',
    );
  });

  test('解析全新 Member Area 个人中心视频卡片 (item ma-v)', () {
    const source = '''
      <div class="ma-grid" id="list_videos_favourite_videos_items">
        <div class="item ma-v video_1"
             data-video-card-id="3051501"
             data-title="Tifa x Cloud 7th Heaven POV"
             data-dur="21"
             data-views="277348"
             data-rating="4.8795"
             data-url="https://rule34video.com/video/3051501/tifa-x-cloud/">
          <a class="ma-thumb"
             href="https://rule34video.com/video/3051501/tifa-x-cloud/"
             data-preview="https://rule34video.com/preview.mp4">
            <img class="thumb rd-lz"
                 src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
                 data-rd-src="https://rule34video.com/contents/videos_screenshots/3051000/3051501/336x189/3.jpg">
            <span class="ma-dur">0:21</span>
          </a>
          <div class="ma-v__row">
            <a class="ma-v__t" href="https://rule34video.com/video/3051501/tifa-x-cloud/">Tifa x Cloud 7th Heaven POV</a>
          </div>
          <div class="ma-v__m">
            <span>277K views</span>
            <span>6 years ago</span>
            <span>97%</span>
          </div>
        </div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '3051501');
    expect(videos.single.slug, 'tifa-x-cloud');
    expect(videos.single.title, 'Tifa x Cloud 7th Heaven POV');
    expect(videos.single.duration, '0:21');
    expect(
      videos.single.thumbnailUrl,
      'https://rule34video.com/contents/videos_screenshots/3051000/3051501/336x189/3.jpg',
    );
    expect(videos.single.previewUrl, 'https://rule34video.com/preview.mp4');
    expect(videos.single.publishedLabel, '6 years ago');
    expect(videos.single.views, 277348);
    expect(videos.single.rating, 97);
  });

  test('解析全新 Member Area 个人资料 (ma-hero)', () {
    const source = '''
      <section class="ma-hero ma-hero--pub" aria-labelledby="rdp-name" data-user-id="2486813">
        <div class="ma-hero__body">
          <span class="ma-av ma-av--xl">
            <img src="https://rule34video.com/contents/avatars/2486000/2486813.jpg">
          </span>
          <div class="ma-hero__id">
            <h1 id="rdp-name">bayo987<svg class="rdm-i ma-verified"></svg></h1>
          </div>
        </div>
      </section>
      <div class="ma-stats ma-stats--pub">
        <a class="ma-stat" href="/members/2486813/videos/"><b>25</b><span>Videos</span></a>
        <a class="ma-stat" href="/members/2486813/favourites/videos/"><b>17</b><span>Favourites</span></a>
        <div class="ma-stat"><b data-rdp-subs-count="244">244</b><span>Subscribers</span></div>
      </div>
    ''';

    final profile = SiteParser.memberProfile(source, '2486813');

    expect(profile, isNotNull);
    expect(profile!.id, '2486813');
    expect(profile.displayName, 'bayo987');
    expect(
      profile.avatarUrl,
      'https://rule34video.com/contents/avatars/2486000/2486813.jpg',
    );
    expect(profile.verified, isTrue);
    expect(profile.subscribersLabel, '244 Subscribers');
    expect(profile.details['Videos'], '25');
    expect(profile.details['Favourites'], '17');
  });

  test('解析全新 Member Area 播放列表 (item ma-pl)', () {
    const source = '''
      <div class="ma-grid ma-grid--pl" id="list_playlists_created_playlists_items">
        <div class="item ma-pl" data-id="2907071" data-title="test1" data-count="15" data-views="23">
          <a class="ma-thumb" href="https://rule34video.com/playlists/2907071/test1104/" title="test1">
            <img class="thumb" src="https://rule34video.com/contents/videos_screenshots/4605000/4605223/320x180/3.jpg">
            <span class="ma-pl__n">15<small>videos</small></span>
          </a>
          <div class="ma-v__row">
            <a class="ma-v__t" href="https://rule34video.com/playlists/2907071/test1104/">test1</a>
          </div>
        </div>
      </div>
    ''';

    final playlists = SiteParser.playlists(source);

    expect(playlists, hasLength(1));
    expect(playlists.single.id, '2907071');
    expect(playlists.single.title, 'test1');
    expect(playlists.single.videoCount, 15);
  });

  test('解析全新 Member Area 播放列表内部视频 (item ma-prow)', () {
    const source = '''
      <div class="ma-grid ma-grid--rows" id="list_videos_my_favourite_videos_items">
        <div class="item ma-prow favorite_videos_video_1" data-video-card-id="4605223" data-id="4605223" data-title="AUS_OS | HMV005" data-dur="180" data-views="33578" data-rating="3.8119" data-url="https://rule34video.com/video/4605223/aus-os-hmv005/">
          <a class="ma-thumb js-open-popup" href="https://rule34video.com/video/4605223/aus-os-hmv005/" title="AUS_OS | HMV005" data-preview="https://rule34video.com/preview.mp4">
            <img class="thumb" src="https://rule34video.com/thumb.jpg" data-rd-jpg="https://rule34video.com/thumb_rd.jpg" alt="AUS_OS | HMV005">
            <span class="ma-dur">3:00</span>
          </a>
          <div class="ma-row__b">
            <a class="ma-row__t js-open-popup" href="https://rule34video.com/video/4605223/aus-os-hmv005/" title="AUS_OS | HMV005">AUS_OS | HMV005</a>
            <div class="ma-row__m"><span>34K views</span><span>76%</span></div>
          </div>
        </div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '4605223');
    expect(videos.single.title, 'AUS_OS | HMV005');
    expect(videos.single.duration, '3:00');
    expect(videos.single.views, 33578);
    expect(videos.single.rating, 76);
  });

  test('解析全新 Member Area 创作者订阅项 (item ma-row ma-subrow)', () {
    const source = '''
      <div class="ma-list ma-subs" id="list_members_subscriptions_my_subscriptions_items">
        <div class="item ma-row ma-subrow" data-id="24819735" data-rdp-sub-item="" data-title="Erovirus">
          <span class="ma-av">ER</span>
          <div class="ma-row__b">
            <a class="ma-row__t" href="https://rule34video.com/models/erovirus/" title="Erovirus">Erovirus</a>
            <div class="ma-row__m"><span class="ma-badge ma-badge--plain">Artist</span></div>
          </div>
          <span class="ma-kvs" hidden>
            <input class="checkbox" name="delete[]" type="checkbox" value="24819735">
          </span>
        </div>
      </div>
    ''';

    final subscriptions = SiteParser.subscriptions(source);

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.title, 'Erovirus');
    expect(subscriptions.single.path, '/models/erovirus/');
    expect(subscriptions.single.kind, SubscriptionKind.model);
  });

  test('账号历史只取历史区块，不把推荐视频算成历史', () {
    const source = '''
      <div class="ma-list" id="list_videos_my_watch_history_items">
        <div class="item thumb video_4100001">
          <a class="th js-open-popup"
             href="https://rule34video.com/video/4100001/watched/"
             title="Watched video"></a>
          <div class="thumb_title">Watched video</div>
        </div>
      </div>
      <div class="ma-list" id="list_videos_related_items">
        <div class="item thumb video_4200002">
          <a class="th js-open-popup"
             href="https://rule34video.com/video/4200002/recommended/"
             title="Recommended video"></a>
          <div class="thumb_title">Recommended video</div>
        </div>
      </div>
    ''';

    final videos = SiteParser.videoListInBlock(
      source,
      'list_videos_my_watch_history_items',
    );

    expect(videos.map((video) => video.id), ['4100001']);
  });

  test('历史区块缺失时退回整页解析，避免静默变成空列表', () {
    const source = '''
      <div class="item thumb video_4300003">
        <a class="th js-open-popup"
           href="https://rule34video.com/video/4300003/legacy/"
           title="Legacy video"></a>
        <div class="thumb_title">Legacy video</div>
      </div>
    ''';

    final videos = SiteParser.videoListInBlock(
      source,
      'list_videos_my_watch_history_items',
    );

    expect(videos.map((video) => video.id), ['4300003']);
  });
}
