import 'dart:convert';

import 'package:flule34/core/api/hanime1_parser.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('评论接口返回（JSON 包裹 HTML 片段）能解析出评论字段', () {
    final html = '''
<div id="comment-start" style="margin-bottom: -15px; padding-top: 5px;">
    <a>
  <img class="img-circle" style="width: 40px; height: auto; float:left;"
       src="https://vdownload.hembed.com/image/avatar/2055902-tsgLcU6o5uYqyzwMLEDr.jpeg?secure=x">
</a>

<div class="report-btn-wrapper" style="position: relative;">
	<div class="comment-index-text" style="font-size: 0.9em;"><a style="text-decoration: none; color: #fff;">奧特精神貝利亞&nbsp;&nbsp;<span style="color: darkgray; font-weight: 400; font-size: 0.85em;">3天前</span></a></div>
	<div class="comment-index-text" style="color: white; font-size: 1em; margin-top: 3px; font-weight: 400; word-wrap: break-word;">qb我草飼你的马</div>

	<span class="material-icons-outlined report-btn no-select" data-reportable-id="500889" data-reportable-type="comment">more_vert</span>
</div>

<div id="comment-like-form-wrapper" style="margin-top: 11px; margin-left: 56px; margin-bottom: 5px;">

	<div style="display: inline-block;">
	  <span style="vertical-align: middle; font-size: 1.12em; color: #fff; margin-top: 0px; cursor: pointer;" class="material-icons-outlined">thumb_up</span>
	  <span style="font-size: 0.90em; color: darkgray; margin-left: 5px; font-weight: 400;">131</span>
	</div>
	<div style="display: inline-block;">
	  <span style="vertical-align: middle; font-size: 1.12em; color: #fff; margin-top: 0px; margin-left: 15px; cursor: pointer;" class="material-icons-outlined">thumb_down</span>
	</div>
	<span style="color: darkgray; margin-left: 25px; font-size: 0.95em; cursor: pointer; font-weight: 400">回復</span>

	<div style="color: red; cursor: pointer; margin-top: 13px; margin-left: -5px; font-weight: 400;" class="load-replies-btn no-select" data-commentid="500889"><span class="reply-btn-text">查看</span> 8 則回覆</div>
	<div id="reply-section-wrapper-500889" class="reply-section-wrapper"></div>

</div>
</div>
''';
    final source = jsonEncode({'comments': html});

    final comments = HanimePageParser.comments(source);

    expect(comments, hasLength(1));
    final comment = comments.first;
    expect(comment.id, '500889');
    expect(comment.username, '奧特精神貝利亞');
    expect(comment.content, 'qb我草飼你的马');
    expect(comment.dateLabel, '3天前');
    expect(comment.likeCount, 131);
    expect(comment.replyCount, 8);
    expect(comment.avatarUrl, isNotNull);
    expect(comment.isReply, isFalse);
  });

  test('回复接口返回（{"replies": ...}）也能解析', () {
    final html = '''
<div id="reply-start-500889" style="margin-top: -8px;">
	<div class="report-btn-wrapper" style="padding-top: 20px; position: relative;">
	  <a><img class="img-circle" style="width: 30px; height: auto; float:left;"
	    src="https://vdownload.hembed.com/image/avatar/1383581-0YdtJ3GwfNxoZzGcazMT.jpeg?secure=y"></a>
	  <div class="comment-index-text" style="font-size: 0.9em; padding-left: 45px"><a style="text-decoration: none; color: #fff;">蕾米埃爾·丹&nbsp;&nbsp;<span style="color: darkgray; font-weight: 400; font-size: 0.85em;">3天前</span></a></div>
	  <div class="comment-index-text" style="color: white; font-size: 1em; margin-top: 3px; padding-left: 45px; font-weight: 400">这才叫奥特精神😂</div>
	  <span class="material-icons-outlined report-btn report-reply-btn no-select" data-reportable-id="250226" data-reportable-type="reply">more_vert</span>
	</div>
	<div style="padding-left: 45px; padding-top: 10px"></div>
</div>
''';
    final source = jsonEncode({'comment_id': '500889', 'replies': html});

    final replies = HanimePageParser.comments(source);

    expect(replies, hasLength(1));
    expect(replies.first.id, '250226');
    expect(replies.first.username, '蕾米埃爾·丹');
    expect(replies.first.content, '这才叫奥特精神😂');
    expect(replies.first.isReply, isTrue);
  });

  test('同一回复容器中的多条回复会全部解析', () {
    String pair(String id, String name, String content) =>
        '''
      <div class="report-btn-wrapper">
        <a><img class="img-circle" src="https://cdn.example/$id.jpg"></a>
        <div class="comment-index-text"><a>$name <span>1天前</span></a></div>
        <div class="comment-index-text">$content</div>
        <span class="report-btn" data-reportable-id="$id" data-reportable-type="reply"></span>
      </div>
      <div class="reply-like-actions"><span>thumb_up</span><span>2</span></div>
    ''';
    final source = jsonEncode({
      'replies':
          '<div id="reply-start-1">'
          '${pair('11', '甲', '第一条回复')}'
          '${pair('12', '乙', '第二条回复')}'
          '</div>',
    });

    final replies = HanimePageParser.comments(source);

    expect(replies, hasLength(2));
    expect(replies.map((item) => item.username), ['甲', '乙']);
    expect(replies.map((item) => item.reportableType), everyElement('reply'));
  });

  test('非评论内容返回空列表', () {
    expect(HanimePageParser.comments('not json'), isEmpty);
    expect(HanimePageParser.comments('{"comments": ""}'), isEmpty);
    expect(HanimePageParser.comments('{"foo": "bar"}'), isEmpty);
  });

  test('播放列表页能解析列表项（listCode/标题/封面/数量）', () {
    final html = '''
<html><body>
  <div class="horizontal-row">
    <div class="user-tab-item-wrapper">
      <a class="video-link" href="https://hanime1.me/playlist?list=883821">
        <img class="main-thumb" src="https://vdownload.hembed.com/image/thumbnail/407598l.jpg?secure=z">
      </a>
      <div class="title">ヌきヌき ずっぽしイズム</div>
      <div class="stat-item">2 部影片</div>
    </div>
    <div class="user-tab-item-wrapper">
      <a class="video-link" href="/playlist?list=801510">
        <img src="https://vdownload.hembed.com/image/thumbnail/406531l.jpg?secure=w">
      </a>
      <div class="title">痴魅悶凌 [せぶんがー]</div>
      <div class="stat-item">2 部影片</div>
    </div>
    <div class="user-tab-item-wrapper">
      <a href="/search?query=no-list">没有列表链接的项</a>
      <div class="title">被忽略</div>
    </div>
  </div>
</body></html>
''';

    final playlists = HanimePageParser.playlists(html);

    expect(playlists, hasLength(2));
    expect(playlists[0].listCode, '883821');
    expect(playlists[0].title, 'ヌきヌき ずっぽしイズム');
    expect(playlists[0].videoCount, 2);
    expect(playlists[0].coverUrl, contains('407598l.jpg'));
    expect(playlists[1].listCode, '801510');
  });

  test('订阅页同时解析作者导航与更新视频', () {
    final page = HanimePageParser.subscriptionPage('''
      <div class="subscriptions-nav">
        <div class="subscriptions-artist-card">
          <img src="https://cdn.example/decor.jpg">
          <img src="https://cdn.example/avatar.jpg">
          <div class="card-mobile-title">Artist One</div>
        </div>
      </div>
      <div class="content-padding-new">
        <div class="video-item-container" title="New Episode">
          <a class="video-link" href="/watch?v=episode-1">
            <img class="main-thumb" src="https://cdn.example/episode.jpg">
          </a>
        </div>
      </div>
    ''');

    expect(page.artists, hasLength(1));
    expect(page.artists.single.name, 'Artist One');
    expect(page.artists.single.avatarUrl, contains('avatar.jpg'));
    expect(page.videos.single.id, 'episode-1');
    expect(page.videos.single.title, 'New Episode');
  });

  test('详情页识别稍后观看勾选状态', () {
    final saved = HanimePageParser.videoDetails(
      source: '''
        <meta name="csrf-token" content="token">
        <div id="playlist-save-checkbox"><input checked></div>
      ''',
      fallback: _video('saved-video'),
    );
    final unsaved = HanimePageParser.videoDetails(
      source: '<div id="playlist-save-checkbox"><input></div>',
      fallback: _video('unsaved-video'),
    );

    expect(saved.isSaved, isTrue);
    expect(unsaved.isSaved, isFalse);
  });

  test('多条评论解析出不同用户名与内容（全同名回归）', () {
    String comment({
      required String id,
      required String name,
      required String content,
    }) =>
        '''
<div id="comment-start" style="margin-bottom: -15px; padding-top: 5px;">
    <a><img class="img-circle" src="https://cdn.example/avatar-$id.jpg"></a>
    <div class="report-btn-wrapper">
      <div class="comment-index-text"><a style="color: #fff;">$name&nbsp;&nbsp;<span style="color: darkgray; font-size: 0.85em;">3天前</span></a></div>
      <div class="comment-index-text" style="color: white; font-size: 1em;">$content</div>
      <span class="material-icons-outlined report-btn no-select" data-reportable-id="$id">more_vert</span>
    </div>
    <div id="comment-like-form-wrapper" style="margin-top: 11px; margin-left: 56px;">
      <div><span style="font-size: 1.12em; color: #fff;">thumb_up</span><span style="font-size: 0.90em; color: darkgray; margin-left: 5px;">1</span></div>
      <div class="load-replies-btn no-select" data-commentid="$id"><span class="reply-btn-text">查看</span> 2 則回覆</div>
      <div id="reply-section-wrapper-$id" class="reply-section-wrapper"></div>
    </div>
</div>
''';
    final source = jsonEncode({
      'comments':
          comment(id: '101', name: '小明', content: '第一条评论') +
          comment(id: '102', name: '小红', content: '第二条评论') +
          comment(id: '103', name: '小刚', content: '第三条评论'),
    });

    final comments = HanimePageParser.comments(source);

    expect(comments, hasLength(3));
    expect(comments[0].username, '小明');
    expect(comments[1].username, '小红');
    expect(comments[2].username, '小刚');
    expect(comments[0].content, '第一条评论');
    expect(comments[1].content, '第二条评论');
    expect(comments[2].content, '第三条评论');
  });

  test('标签链接数字剥离且计数单独提取', () {
    final html = '''
<html><body>
  <div class="video-description-panel">
    <a href="/search?tags%5B%5D=NTR&genre=裏番">NTR&nbsp;<span style="color: #aaa; font-size: 1.2rem;">(7)</span></a>
    <a href="/search?tags%5B%5D=巨乳&genre=裏番">巨乳&nbsp;<span style="color: #aaa;">(2)</span></a>
    <a href="/search?tags%5B%5D=中文字幕&genre=裏番">中文字幕</a>
  </div>
</body></html>
''';

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: _video('tag-test'),
    );

    // 标签文本不含括号数字。
    expect(details.tags, contains('NTR'));
    expect(details.tags, isNot(contains('NTR (7)')));
    expect(details.tags, contains('中文字幕'));
    // 计数独立存放。
    final ntr = details.metadataItems.firstWhere(
      (item) => item.title == 'NTR',
      orElse: () => throw StateError('NTR 未找到'),
    );
    expect(ntr.count, 7);
    // 点击路径只含纯标签。
    expect(ntr.path, '/search?query=NTR');
  });

  test('分类只取视频信息区，排除全局导航栏（分类全列回归）', () {
    final html = '''
<html><body>
  <nav class="main-nav main-nav-video-show">
    <a href="/search?genre=裏番">里番</a>
    <a href="/search?genre=泡麵番">泡面番</a>
    <a href="/search?genre=Motion Anime">Motion Anime</a>
  </nav>
  <div class="video-description-panel">
    <a href="/search?genre=裏番">里番</a>
  </div>
</body></html>
''';

    final details = HanimePageParser.videoDetails(
      source: html,
      fallback: _video('category-test'),
    );

    expect(details.categories, ['里番']);
  });
}

VideoItem _video(String id) =>
    VideoItem(id: id, slug: id, title: '测试', siteId: 'hanime1');
