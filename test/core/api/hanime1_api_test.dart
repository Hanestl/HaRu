import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/hanime1_parser.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/hanime_library_models.dart';
import 'package:flule34/core/models/hanime_search_models.dart';
import 'package:flule34/core/services/hanime_cloudflare_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('浏览器 Cookie 按第一个等号切分并固定到 Hanime 域名', () {
    final cookies = parseBrowserCookieHeader(
      'cf_clearance=part-one==part-two; session=value; invalid',
      Uri.parse('https://hanime1.me/'),
    );

    expect(cookies, hasLength(2));
    expect(cookies.first.name, 'cf_clearance');
    expect(cookies.first.value, 'part-one==part-two');
    expect(cookies.first.domain, 'hanime1.me');
    expect(cookies.first.path, '/');
    expect(cookies.first.secure, isTrue);
  });

  test('Cookie 诊断只输出名称而不包含值', () {
    final diagnostic = cookieHeaderNamesForLog(
      'cf_clearance=secret==value; PHPSESSID=session-secret',
    );

    expect(diagnostic, 'PHPSESSID、cf_clearance');
    expect(diagnostic, isNot(contains('secret')));
    expect(diagnostic, isNot(contains('value')));
  });

  test('浏览器 Cookie 导入后能被 Hanime 请求域名读取', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = Hanime1Api(sessionStore: harness.sessionStore);
    addTearDown(api.close);

    await api.importBrowserCookieHeader(
      'cf_clearance=part-one==part-two; session=value',
    );

    final header = await api.sessionCookieHeader();
    expect(header, contains('cf_clearance=part-one==part-two'));
    expect(header, contains('session=value'));
  });

  test('Hanime 首页并发请求共用结果并在三十分钟内复用缓存', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((_) {
        requests += 1;
        return ResponseBody.fromString('''
          <h3>最新上传</h3>
          <div class="home-rows-videos-wrapper">
            <div class="video-item-container">
              <a href="/watch?v=home-1"><span class="title">Home One</span></a>
            </div>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    final results = await Future.wait([
      api.loadHomeSections(),
      api.loadHomeSections(),
    ]);
    final cached = await api.loadHomeSections();

    expect(requests, 1);
    expect(results.first.single.items.single.id, 'home-1');
    expect(cached.single.title, '最新上传');
  });

  test('Hanime 首页频道合并并发请求、复用缓存并允许强制刷新', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    final firstResponse = Completer<ResponseBody>();
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path != '/search') {
          return ResponseBody.fromString('', 200);
        }
        requests += 1;
        if (requests == 1) return firstResponse.future;
        return ResponseBody.fromString('''
          <div class="horizontal-card">
            <a href="/watch?v=release-$requests">
              <div class="title">Release $requests</div>
            </a>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);
    const filters = HanimeSearchFilters(sort: '最新上市');

    final first = api.loadHomeChannel('latest-release', 1, filters: filters);
    final second = api.loadHomeChannel('latest-release', 1, filters: filters);
    firstResponse.complete(
      ResponseBody.fromString('''
        <div class="horizontal-card">
          <a href="/watch?v=release-1">
            <div class="title">Release 1</div>
          </a>
        </div>
      ''', 200),
    );

    final concurrent = await Future.wait([first, second]);
    final cached = await api.loadHomeChannel(
      'latest-release',
      1,
      filters: filters,
    );
    final refreshed = await api.loadHomeChannel(
      'latest-release',
      1,
      filters: filters,
      force: true,
    );

    expect(concurrent.first.single.id, 'release-1');
    expect(concurrent.last.single.id, 'release-1');
    expect(cached.single.id, 'release-1');
    expect(refreshed.single.id, 'release-2');
    expect(requests, 2);
  });

  test('相同 URL 的并发请求共用同一次浏览器取页', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);
    final uri = Uri.parse('https://hanime1.me/watch?v=1');
    final first = coordinator.requestPage(uri);
    final second = coordinator.requestPage(uri);

    final request = coordinator.activeRequest!;
    coordinator.complete(requestId: request.id, html: '<html>video</html>');

    expect(await first, '<html>video</html>');
    expect(await second, '<html>video</html>');
    expect(coordinator.activeRequest, isNull);
  });

  test('后台预热请求不会申请前台人工验证', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);
    final future = coordinator.requestPage(
      Uri.parse('https://hanime1.me/'),
      false,
    );
    final request = coordinator.activeRequest!;

    coordinator.requestForeground(requestId: request.id);

    expect(request.allowForegroundVerification, isFalse);
    expect(coordinator.requiresForeground, isFalse);
    expect(coordinator.activeRequest, isNull);
    expect(await future, isNull);
  });

  test('不同 URL 的浏览器取页请求按顺序执行', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);
    final first = coordinator.requestPage(Uri.parse('https://hanime1.me/'));
    final second = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=2'),
    );

    final firstRequest = coordinator.activeRequest!;
    expect(firstRequest.targetUri.path, '/');
    coordinator.complete(requestId: firstRequest.id, html: '<html>home</html>');
    expect(await first, '<html>home</html>');

    final secondRequest = coordinator.activeRequest!;
    expect(secondRequest.targetUri.queryParameters['v'], '2');
    coordinator.complete(
      requestId: secondRequest.id,
      html: '<html>detail</html>',
    );
    expect(await second, '<html>detail</html>');
    expect(coordinator.activeRequest, isNull);
  });

  test('浏览器辅助访问仅在当前请求需要交互时转到前台', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);
    final pending = coordinator.requestPage(Uri.parse('https://hanime1.me/'));
    final request = coordinator.activeRequest!;

    expect(coordinator.requiresForeground, isFalse);
    coordinator.requestForeground(requestId: request.id + 1);
    expect(coordinator.requiresForeground, isFalse);

    coordinator.requestForeground(requestId: request.id);
    expect(coordinator.requiresForeground, isTrue);

    coordinator.complete(requestId: request.id, html: '<html>ready</html>');
    expect(await pending, '<html>ready</html>');
    expect(coordinator.requiresForeground, isFalse);
  });

  test('经历 Cloudflare 挑战后必须取得 clearance 才能完成', () {
    final common = (
      isTargetHost: true,
      isChallenge: false,
      hasDocument: true,
      progress: 100,
      readyState: 'complete',
    );

    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: common.isTargetHost,
        isChallenge: common.isChallenge,
        hasDocument: common.hasDocument,
        progress: common.progress,
        readyState: common.readyState,
        observedChallenge: true,
        hasClearance: false,
      ),
      isFalse,
    );
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: common.isTargetHost,
        isChallenge: common.isChallenge,
        hasDocument: common.hasDocument,
        progress: common.progress,
        readyState: common.readyState,
        observedChallenge: true,
        hasClearance: true,
      ),
      isTrue,
    );
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: common.isTargetHost,
        isChallenge: common.isChallenge,
        hasDocument: common.hasDocument,
        progress: common.progress,
        readyState: common.readyState,
        observedChallenge: false,
        hasClearance: false,
      ),
      isTrue,
    );
  });

  test('浏览器验证后原生请求仍被拦截时采用浏览器正文', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    Uri? browserTarget;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests += 1;
        return ResponseBody.fromString(
          '<html><title>Attention Required! | Cloudflare</title></html>',
          403,
        );
      }),
      browserPageHandler: (targetUri, _) async {
        browserTarget = targetUri;
        return '''
          <div class="horizontal-card">
            <a href="https://hanime1.me/watch?v=407610">
              <div class="title">Example</div>
            </a>
          </div>
        ''';
      },
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('example', 1);

    expect(requests, 2);
    expect(browserTarget?.path, '/search');
    expect(videos.single.id, '407610');
  });

  test('浏览器验证后原生请求重试成功时采用原生正文', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests += 1;
        if (requests == 1) {
          return ResponseBody.fromString(
            '<html><title>Attention Required! | Cloudflare</title></html>',
            403,
          );
        }
        return ResponseBody.fromString('''
          <div class="horizontal-card">
            <a href="https://hanime1.me/watch?v=407612">
              <div class="title">Cronet recovered</div>
            </a>
          </div>
        ''', 200);
      }),
      browserPageHandler: (_, _) async => '''
        <div class="horizontal-card">
          <a href="https://hanime1.me/watch?v=browser-copy">
            <div class="title">Browser copy</div>
          </a>
        </div>
      ''',
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('recovered', 1);

    expect(requests, 2);
    expect(videos.single.id, '407612');
  });

  test('取消浏览器辅助访问时保留 Cloudflare 异常且不重试', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((_) {
        requests += 1;
        return ResponseBody.fromString(
          '<html><title>Just a moment...</title></html>',
          403,
        );
      }),
      browserPageHandler: (_, _) async => null,
    );
    addTearDown(api.close);

    await expectLater(
      api.searchVideos('example', 1),
      throwsA(isA<HanimeCloudflareException>()),
    );
    expect(requests, 1);
  });

  test('浏览器仍返回挑战页时不会把挑战正文交给解析器', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter(
        (_) => ResponseBody.fromString('blocked', 403),
      ),
      browserPageHandler: (_, _) async =>
          '<html><title>Just a moment...</title></html>',
    );
    addTearDown(api.close);

    await expectLater(
      api.searchVideos('example', 1),
      throwsA(isA<HanimeCloudflareException>()),
    );
  });

  test('连接超时后自动采用浏览器返回的正文', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    Uri? browserTarget;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests += 1;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'timed out',
        );
      }),
      browserPageHandler: (targetUri, _) async {
        browserTarget = targetUri;
        return '''
          <div class="horizontal-card">
            <a href="https://hanime1.me/watch?v=407611">
              <div class="title">Recovered</div>
            </a>
          </div>
        ''';
      },
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('recovered', 1);

    expect(requests, 2);
    expect(browserTarget?.path, '/search');
    expect(browserTarget?.queryParameters['query'], 'recovered');
    expect(videos.single.id, '407611');
  });

  test('浏览器网络错误页不会被当成有效正文', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'connection refused',
        );
      }),
      browserPageHandler: (_, _) async =>
          '<html><body>net::ERR_CONNECTION_REFUSED</body></html>',
    );
    addTearDown(api.close);

    await expectLater(
      api.searchVideos('error-page', 1),
      throwsA(isA<ApiException>()),
    );
  });

  test('搜索筛选按 Hanime 协议组装 query 参数', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    Uri? captured;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        captured = options.uri;
        return ResponseBody.fromString('''
          <div class="horizontal-card">
            <a href="https://hanime1.me/watch?v=407613">
              <div class="title">Filtered</div>
            </a>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    final videos = await api.searchVideos(
      '無碼',
      2,
      filters: const HanimeSearchFilters(
        genre: '裏番',
        sort: '最新上市',
        date: HanimeDateFilter.month(year: 2026, month: 8),
        duration: '10 分鐘 +',
        tags: {'無碼', '中文字幕'},
        brands: {'Queen Bee'},
        broad: true,
      ),
    );

    final query = captured!.queryParameters;
    final queryAll = captured!.queryParametersAll;
    expect(query['query'], '無碼');
    expect(query['page'], '2');
    expect(query['genre'], '裏番');
    expect(query['sort'], '最新上市');
    expect(query['date'], '2026 年 8 月');
    expect(query['duration'], '10 分鐘 +');
    expect(query['broad'], 'on');
    expect(queryAll['tags[]'], containsAll(<String>['無碼', '中文字幕']));
    expect(queryAll['brands[]'], ['Queen Bee']);
    expect(videos.single.id, '407613');
  });

  test('空筛选不携带任何可选参数', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    Uri? captured;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        captured = options.uri;
        return ResponseBody.fromString('''
          <div class="horizontal-card">
            <a href="https://hanime1.me/watch?v=407614">
              <div class="title">Plain</div>
            </a>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    await api.searchVideos('example', 1);

    final query = captured!.queryParameters;
    expect(query['genre'], isNull);
    expect(query['sort'], isNull);
    expect(query['date'], isNull);
    expect(query['duration'], isNull);
    expect(query['broad'], isNull);
    expect(query.containsKey('tags[]'), isFalse);
    expect(query.containsKey('brands[]'), isFalse);
  });

  test('空关键词 + 非空筛选（首页频道）会发起请求并返回结果', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    Uri? captured;
    var requested = false;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requested = true;
        captured = options.uri;
        return ResponseBody.fromString('''
          <div class="home-rows-videos-wrapper">
            <div class="home-rows-videos-title">频道</div>
            <a href="https://hanime1.me/watch?v=407615">
              <div class="home-rows-videos-div">
                <div class="home-rows-videos-title">Channel Video</div>
              </div>
            </a>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    final videos = await api.searchVideos(
      '',
      1,
      filters: const HanimeSearchFilters(genre: '裏番'),
    );

    expect(requested, isTrue, reason: '首页频道必须真实发起请求');
    expect(captured!.queryParameters['query'], '');
    expect(captured!.queryParameters['genre'], '裏番');
    expect(videos, isNotEmpty);
    expect(videos.single.id, '407615');
  });

  test('空关键词且无筛选时直接返回空，不发请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requested = false;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requested = true;
        return ResponseBody.fromString('<html></html>', 200);
      }),
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('', 1);

    expect(requested, isFalse, reason: '空输入搜索页不应发请求');
    expect(videos, isEmpty);
  });

  test('账号媒体库新端点携带正确路径、分页与历史排序', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');
    final requests = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.uri.path == '/subscriptions') {
          return ResponseBody.fromString('''
            <div class="subscriptions-nav">
              <div class="subscriptions-artist-card">
                <img src="https://cdn.example/artist.jpg">
                <div class="card-mobile-title">Artist One</div>
              </div>
            </div>
            <div class="content-padding-new">
              <div class="video-item-container" title="Subscription Video">
                <a class="video-link" href="/watch?v=sub-1">
                  <img class="main-thumb" src="https://cdn.example/sub.jpg">
                </a>
              </div>
            </div>
          ''', 200);
        }
        return ResponseBody.fromString('''
          <div class="horizontal-row">
            <div class="user-tab-item-wrapper">
              <a href="/watch?v=list-1">
                <img src="https://cdn.example/list.jpg">
                <div class="title">List Video</div>
              </a>
            </div>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    final saves = await api.loadSaves(2);
    final history = await api.loadWatchHistory(
      3,
      sort: HanimeHistorySort.oldest,
    );
    final subscriptions = await api.loadSubscriptionPage(4);

    expect(saves.single.id, 'list-1');
    expect(history.single.id, 'list-1');
    expect(subscriptions.artists.single.name, 'Artist One');
    expect(subscriptions.videos.single.id, 'sub-1');
    expect(requests[0].uri.path, '/user/2002/saves');
    expect(requests[0].uri.queryParameters['page'], '2');
    expect(requests[1].uri.path, '/user/2002/histories');
    expect(requests[1].uri.queryParameters, {'sort': 'oldest', 'page': '3'});
    expect(requests[2].uri.path, '/subscriptions');
    expect(requests[2].uri.queryParameters['page'], '4');
  });

  test('稍后观看与历史删除使用站点要求的表单', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');
    final requests = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.method == 'GET' && options.uri.path == '/watch') {
          return ResponseBody.fromString(
            '<meta name="csrf-token" content="token-123">',
            200,
          );
        }
        return ResponseBody.fromString('{}', 200);
      }),
    );
    addTearDown(api.close);

    await api.setSaved('video-1', saved: true);
    await api.deleteWatchHistory('video-2');

    final save = requests.firstWhere((item) => item.uri.path == '/save');
    expect(save.method, 'POST');
    expect(save.data, containsPair('input_id', 'save'));
    expect(save.data, containsPair('video_id', 'video-1'));
    expect(save.data, containsPair('is_checked', 'true'));
    expect(save.headers['X-CSRF-TOKEN'], 'token-123');

    final deletion = requests.firstWhere(
      (item) => item.uri.path == '/user/tab-item/video-2',
    );
    expect(deletion.method, 'DELETE');
    expect(deletion.data, containsPair('tab', 'histories'));
    expect(deletion.headers['X-CSRF-TOKEN'], 'token-123');
  });

  test('播放列表、订阅、评分与举报使用 Hanime 表单契约', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');
    final requests = <RequestOptions>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.method == 'GET') {
          return ResponseBody.fromString(
            '<meta name="csrf-token" content="token-123">'
            '<input name="subscribe-artist-id" value="artist-1">'
            '<input name="like-status" value="">'
            '<input name="unlike-status" value="">'
            '<input name="likes-count" value="2">'
            '<input name="unlikes-count" value="1">',
            200,
          );
        }
        return ResponseBody.fromString('{}', 200);
      }),
    );
    addTearDown(api.close);

    await api.setPlaylistMembership('video-1', 'list-1', included: true);
    await api.createPlaylist(videoId: 'video-1', title: 'New list');
    await api.updatePlaylist('list-1', title: 'Renamed');
    await api.removePlaylistVideo('list-1', 'video-1');
    await api.setArtistSubscribed('video-1', subscribed: true);
    await api.rateVideo('video-1', positive: true);
    await api.setDislike('video-1', disliked: true);
    await api.reportComment(
      videoId: 'video-1',
      commentId: 'comment-1',
      reason: 'spam',
    );

    final membership = requests.firstWhere(
      (request) =>
          request.uri.path == '/save' && request.data['input_id'] == 'list-1',
    );
    expect(membership.data, containsPair('is_checked', 'true'));
    final create = requests.firstWhere(
      (request) => request.uri.path == '/createPlaylist',
    );
    expect(create.data, containsPair('create-playlist-video-id', 'video-1'));
    final update = requests.firstWhere(
      (request) => request.uri.path == '/playlist/list-1',
    );
    expect(update.data, containsPair('_method', 'PUT'));
    final removal = requests.firstWhere(
      (request) => request.uri.path == '/deletePlayitem',
    );
    expect(removal.data, containsPair('playlist_id', 'list-1'));
    final subscribe = requests.firstWhere(
      (request) => request.uri.path == '/subscribe',
    );
    expect(subscribe.data, containsPair('subscribe-artist-id', 'artist-1'));
    final rates = requests
        .where((request) => request.uri.path == '/like')
        .toList(growable: false);
    expect(rates, hasLength(2));
    expect(rates.first.data, containsPair('like-is-positive', '1'));
    expect(rates.last.data, containsPair('like-is-positive', '0'));
    final report = requests.firstWhere(
      (request) => request.uri.path == '/user/2002/report',
    );
    expect(report.data, containsPair('reportable-type', 'comment'));
  });

  test('createPlaylist 在服务端返回 500 时抛出 HttpStatusException(500)', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');

    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path == '/watch') {
          return ResponseBody.fromString(
            '<meta name="csrf-token" content="token-123">',
            200,
          );
        }
        if (options.uri.path == '/createPlaylist') {
          return ResponseBody.fromString('Internal Server Error', 500);
        }
        return ResponseBody.fromString('{}', 200);
      }),
    );
    addTearDown(api.close);

    expect(
      () => api.createPlaylist(videoId: 'video-1', title: 'New list'),
      throwsA(
        isA<HttpStatusException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });

  test(
    'createPlaylist 在服务端返回 302 重定向到 /login 时抛出 SessionExpiredException',
    () async {
      final harness = TestSessionHarness.create();
      addTearDown(harness.dispose);
      await harness.sessionStore.load();
      await harness.sessionStore.authenticateHanime('2002');

      final api = Hanime1Api(
        sessionStore: harness.sessionStore,
        httpClientAdapter: _TestAdapter((options) {
          if (options.uri.path == '/watch') {
            return ResponseBody.fromString(
              '<meta name="csrf-token" content="token-123">',
              200,
            );
          }
          if (options.uri.path == '/createPlaylist') {
            expect(options.followRedirects, isFalse);
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://hanime1.me/login'],
              },
            );
          }
          return ResponseBody.fromString('{}', 200);
        }),
      );
      addTearDown(api.close);

      expect(
        () => api.createPlaylist(videoId: 'video-1', title: 'New list'),
        throwsA(isA<SessionExpiredException>()),
      );
    },
  );

  test('createPlaylist 在服务端返回 302 重定向到目标内容页时判定成功', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');

    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path == '/watch') {
          return ResponseBody.fromString(
            '<meta name="csrf-token" content="token-123">',
            200,
          );
        }
        if (options.uri.path == '/createPlaylist') {
          expect(options.followRedirects, isFalse);
          return ResponseBody.fromString(
            '<div>ok</div>',
            302,
            headers: {
              'location': ['https://hanime1.me/playlist/my-list'],
            },
          );
        }
        return ResponseBody.fromString('{}', 200);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.createPlaylist(videoId: 'video-1', title: 'New list'),
      completes,
    );
  });

  test('大页面解析下放到 Isolate 后仍返回完整结果', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticateHanime('2002');
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path != '/subscriptions') {
          return ResponseBody.fromString('<html></html>', 200);
        }
        return ResponseBody.fromString('''
          <!-- ${'x' * 12000} -->
          <div class="subscriptions-nav">
            <div class="subscriptions-artist-card">
              <img src="https://cdn.example/artist.jpg">
              <div class="card-mobile-title">Artist One</div>
            </div>
          </div>
          <div class="content-padding-new">
            <div class="video-item-container" title="Subscription Video">
              <a class="video-link" href="/watch?v=sub-1">
                <img class="main-thumb" src="https://cdn.example/sub.jpg">
              </a>
            </div>
          </div>
        ''', 200);
      }),
    );
    addTearDown(api.close);

    final page = await api.loadSubscriptionPage(1);

    expect(page.artists.single.name, 'Artist One');
    expect(page.videos.single.id, 'sub-1');
  });
}

final class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
