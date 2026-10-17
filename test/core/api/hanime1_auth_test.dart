import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('表单登录：取令牌、POST、解析首页账号、记录 hanime 身份', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final captured = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _LoginAdapter(captured),
    );
    addTearDown(api.close);

    final profile = await api.login(
      email: 'user@hanime.example',
      password: 'secret',
    );

    expect(profile.displayName, 'Queen Bee');
    expect(profile.id, '366912');
    expect(profile.subscriberCount, 74192);
    expect(profile.videoCount, 160);
    expect(harness.sessionStore.isHanimeLoggedIn, isTrue);
    expect(harness.sessionStore.hanimeUserId, '366912');
    expect(harness.sessionStore.isLoggedIn, isFalse);

    // 校验 POST 表单字段与 CSRF 头。
    final post = captured.firstWhere(
      (options) => options.method == 'POST' && options.path.endsWith('/login'),
    );
    expect(post.data, {
      '_token': 'TOKEN123',
      'email': 'user@hanime.example',
      'password': 'secret',
    });
    expect(post.headers['X-CSRF-TOKEN'], 'TOKEN123');
    expect(
      post.headers['Content-Type'],
      contains('application/x-www-form-urlencoded'),
    );
  });

  test('登录成功后可读取当前账号资料', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _LoginAdapter([]),
    );
    addTearDown(api.close);
    await api.login(email: 'user@hanime.example', password: 'secret');

    final account = await api.loadHanimeAccountProfile();
    expect(account?.displayName, 'Queen Bee');
    expect(account?.id, '366912');
  });

  test('登录失败（登录页无令牌）抛出 ApiException', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _LoginAdapter([], loginPage: '<html>no token</html>'),
    );
    addTearDown(api.close);

    await expectLater(
      api.login(email: 'a@b.c', password: 'x'),
      throwsA(isA<ApiException>()),
    );
    expect(harness.sessionStore.isHanimeLoggedIn, isFalse);
  });

  test('登出清除 hanime 身份与凭据', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _LoginAdapter([]),
    );
    addTearDown(api.close);
    await api.login(email: 'user@hanime.example', password: 'secret');
    await harness.sessionStore.saveHanimeCredentials(
      email: 'user@hanime.example',
      password: 'secret',
    );

    await api.logout();

    expect(harness.sessionStore.isHanimeLoggedIn, isFalse);
    expect(harness.sessionStore.hanimeUserId, isNull);
    expect(await harness.sessionStore.loadHanimeCredentials(), isNull);
  });

  test('未登录时点赞与评论写操作抛 ApiException', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final api = Hanime1Api(sessionStore: harness.sessionStore);
    addTearDown(api.close);

    await expectLater(
      api.setLike('407598', liked: true),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      api.createComment(videoId: '407598', text: 'hello'),
      throwsA(isA<ApiException>()),
    );
  });

  test('评论写操作带 CSRF 令牌与表单字段', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('366912');

    final captured = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _CommentAdapter(captured),
    );
    addTearDown(api.close);

    await api.createComment(videoId: '407598', text: '测试评论');
    final post = captured.firstWhere(
      (options) =>
          options.method == 'POST' && options.path.endsWith('/createComment'),
    );
    expect(post.data, {
      '_token': 'TOKEN456',
      'comment-user-id': '366912',
      'comment-type': 'video',
      'comment-foreign-id': '407598',
      'comment-text': '测试评论',
      'comment-count': '1',
      'comment-is-political': '0',
    });
    expect(post.headers['X-CSRF-TOKEN'], 'TOKEN456');

    await api.replyComment(
      videoId: '407598',
      commentId: '500889',
      text: '回复内容',
    );
    final reply = captured.firstWhere(
      (options) =>
          options.method == 'POST' && options.path.endsWith('/replyComment'),
    );
    expect(reply.data, {
      '_token': 'TOKEN456',
      'reply-comment-id': '500889',
      'reply-comment-text': '回复内容',
    });

    await api.likeComment(
      videoId: '407598',
      commentId: '500889',
      positive: true,
    );
    final like = captured.firstWhere(
      (options) =>
          options.method == 'POST' && options.path.endsWith('/commentLike'),
    );
    expect(like.data, {
      '_token': 'TOKEN456',
      'foreign_type': 'comment',
      'foreign_id': '500889',
      'is_positive': '1',
      'comment-like-user-id': '366912',
      'comment-likes-count': '1',
      'comment-likes-sum': '1',
      'like-comment-status': '1',
      'unlike-comment-status': '0',
    });
  });

  test('点赞切换按目标状态发送 like-status', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('366912');

    final captured = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _CommentAdapter(captured),
    );
    addTearDown(api.close);

    await api.setLike('407598', liked: true);
    await api.setLike('407598', liked: false);

    final posts = captured
        .where((o) => o.method == 'POST' && o.path.endsWith('/like'))
        .toList();
    expect(posts, hasLength(2));
    expect(posts[0].data['like-status'], '');
    expect(posts[1].data['like-status'], '1');
    expect(posts[0].data['like-foreign-id'], '407598');
    expect(posts[0].data['like-user-id'], '366912');
    expect(posts[0].data['like-is-positive'], '1');
  });
}

/// 登录流专用 mock：按方法与路径分发登录页/POST 结果/探针/首页/用户页。
final class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this._captured, {this.loginPage});

  final List<RequestOptions> _captured;
  final String? loginPage;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _captured.add(options);
    final path = options.path;
    if (options.method == 'POST' && path.endsWith('/login')) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'set-cookie': [
            'XSRF-TOKEN=token-value; path=/',
            'hanime1_session=session-value; path=/',
          ],
        },
      );
    }
    if (path.endsWith('/login')) {
      // 探针（登录后再次访问）返回 404，登录页返回 200。
      if (_captured.where((o) => o.path.endsWith('/login')).length > 1) {
        return ResponseBody.fromString('', 404);
      }
      return ResponseBody.fromString(
        loginPage ??
            '''
            <html><head>
              <meta name="csrf-token" content="TOKEN123">
            </head><body>
              <form><input type="hidden" name="_token" value="TOKEN123">
                <input name="email"><input name="password"></form>
            </body></html>
            ''',
        200,
      );
    }
    if (path.endsWith('/user/366912')) {
      return ResponseBody.fromString('''
        <html><body>
          Queen Bee @ 366912 • 74,192 位订阅者 • 160 个视频
        </body></html>
        ''', 200);
    }
    if (path.endsWith('/')) {
      return ResponseBody.fromString('''
        <html><body>
          <div id="user-modal-dp-wrapper">
            <img src="https://cdn.example/avatar.jpg">
          </div>
          <div id="user-modal-name">Queen Bee</div>
          <a id="user-modal-trigger" href="/user/366912">menu</a>
        </body></html>
        ''', 200);
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

/// 评论/点赞写操作专用 mock：详情页返回带 CSRF 令牌的 HTML。
final class _CommentAdapter implements HttpClientAdapter {
  _CommentAdapter(this._captured);

  final List<RequestOptions> _captured;
  var _liked = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _captured.add(options);
    if (options.path.contains('/watch')) {
      return ResponseBody.fromString('''
        <html><head>
          <meta name="csrf-token" content="TOKEN456">
        </head><body><form><input type="hidden" name="_token" value="TOKEN456"></form>
          <input name="like-status" value="${_liked ? '1' : ''}">
        </body></html>
        ''', 200);
    }
    if (options.path.endsWith('/like') && options.data is Map) {
      _liked = (options.data as Map)['like-status'] == '';
    }
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
