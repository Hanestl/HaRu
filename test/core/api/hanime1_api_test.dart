import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/hanime1_api.dart';
import 'package:flule34/core/api/hanime1_parser.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/hanime_library_models.dart';
import 'package:flule34/core/models/hanime_search_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/hanime_cloudflare_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('后台请求之间保留最小间隔', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final clock = Stopwatch()..start();
    final starts = <Duration>[];
    const interval = Duration(milliseconds: 60);
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      backgroundRequestInterval: interval,
      httpClientAdapter: _TestAdapter((options) {
        starts.add(clock.elapsed);
        return ResponseBody.fromString(
          '<div id="home-rows-wrapper"></div>',
          200,
        );
      }),
    );
    addTearDown(api.close);
    await api.searchVideos('first', 1, allowForegroundVerification: false);
    final second = api.searchVideos(
      'second',
      1,
      allowForegroundVerification: false,
    );
    await second;
    expect(starts, hasLength(2));
    expect(starts.last - starts.first, greaterThanOrEqualTo(interval));
  });

  test('在途后台请求取消后队列会继续，预先取消的请求不会入队', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final calls = <String>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      backgroundRequestInterval: Duration.zero,
      httpClientAdapter: _TestAdapter((options) {
        final query = options.queryParameters['query'] as String;
        calls.add(query);
        if (query == 'active') {
          started.complete();
          return response.future;
        }
        return ResponseBody.fromString(
          '<div id="home-rows-wrapper"></div>',
          200,
        );
      }),
    );
    addTearDown(api.close);
    final token = CancelToken();
    final active = expectLater(
      api.searchVideos(
        'active',
        1,
        cancelToken: token,
        allowForegroundVerification: false,
      ),
      throwsA(isA<RequestCancelledException>()),
    );
    await started.future;
    final next = api.searchVideos(
      'next',
      1,
      allowForegroundVerification: false,
    );
    token.cancel();
    await active;
    await next.timeout(const Duration(seconds: 1));
    await expectLater(
      api.searchVideos(
        'already-cancelled',
        1,
        cancelToken: token,
        allowForegroundVerification: false,
      ),
      throwsA(isA<RequestCancelledException>()),
    );
    expect(calls, ['active', 'next']);
    response.complete(ResponseBody.fromString('', 200));
  });

  test('后台首页、频道与详情共用串行队列，前台不等待后台', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final firstStarted = Completer<void>();
    final firstResponse = Completer<ResponseBody>();
    final calls = <String>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      backgroundRequestInterval: Duration.zero,
      httpClientAdapter: _TestAdapter((options) {
        final key =
            options.queryParameters['query']?.toString() ?? options.path;
        calls.add(key);
        if (key == 'background') {
          firstStarted.complete();
          return firstResponse.future;
        }
        return ResponseBody.fromString(
          options.path == '/watch'
              ? '<video id="player"><source src="https://cdn.example/a.mp4"></video>'
              : '<div id="home-rows-wrapper"></div>',
          200,
        );
      }),
    );
    addTearDown(api.close);

    final first = api.searchVideos(
      'background',
      1,
      allowForegroundVerification: false,
    );
    await firstStarted.future;
    final home = api.loadHomeSections(allowForegroundVerification: false);
    final details = api.loadVideoDetails(
      const VideoItem(
        id: 'queue-test',
        title: 'Queue',
        slug: 'queue',
        siteId: 'hanime1',
      ),
      allowForegroundVerification: false,
    );
    await api.searchVideos('foreground', 1);
    expect(calls, ['background', 'foreground']);

    firstResponse.complete(
      ResponseBody.fromString('<div id="home-rows-wrapper"></div>', 200),
    );
    await Future.wait<Object>([first, home, details]);
    expect(calls, ['background', 'foreground', '/', '/watch']);
  });

  test('后台请求失败后仍会推进下一项，且不启用前台验证', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final flags = <bool>[];
    final calls = <String>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      backgroundRequestInterval: Duration.zero,
      browserPageHandler: (_, foreground) async {
        flags.add(foreground);
        return null;
      },
      httpClientAdapter: _TestAdapter((options) {
        final query = options.queryParameters['query'] as String;
        calls.add(query);
        return ResponseBody.fromString(
          '<div id="home-rows-wrapper"></div>',
          query == 'blocked' ? 403 : 200,
        );
      }),
    );
    addTearDown(api.close);

    final failed = expectLater(
      api.searchVideos('blocked', 1, allowForegroundVerification: false),
      throwsA(isA<HanimeCloudflareException>()),
    );
    final next = api.searchVideos(
      'next',
      1,
      allowForegroundVerification: false,
    );
    await failed;
    expect(await next, isEmpty);
    expect(calls, ['blocked', 'next']);
    expect(flags, [false]);
  });

  test('排队中的后台请求取消后立即结束，且不发送网络请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final calls = <String>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      backgroundRequestInterval: Duration.zero,
      httpClientAdapter: _TestAdapter((options) {
        calls.add(options.queryParameters['query'] as String);
        started.complete();
        return response.future;
      }),
    );
    addTearDown(api.close);
    final first = api.searchVideos(
      'active',
      1,
      allowForegroundVerification: false,
    );
    await started.future;
    final token = CancelToken();
    final cancelled = expectLater(
      api.searchVideos(
        'queued',
        1,
        cancelToken: token,
        allowForegroundVerification: false,
      ),
      throwsA(isA<RequestCancelledException>()),
    );
    token.cancel();
    await cancelled.timeout(const Duration(seconds: 1));
    expect(calls, ['active']);
    response.complete(
      ResponseBody.fromString('<div id="home-rows-wrapper"></div>', 200),
    );
    await first;
  });

  test('关闭 API 会结束在途和排队后台请求，关闭后不再发请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final calls = <String>[];
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        calls.add(options.queryParameters['query'] as String);
        started.complete();
        return response.future;
      }),
    );
    addTearDown(api.close);
    final active = expectLater(
      api.searchVideos('active', 1, allowForegroundVerification: false),
      throwsA(isA<RequestCancelledException>()),
    );
    await started.future;
    final queued = expectLater(
      api.searchVideos('queued', 1, allowForegroundVerification: false),
      throwsA(isA<RequestCancelledException>()),
    );
    api.close();
    await Future.wait([active, queued]);
    await expectLater(
      api.searchVideos('after-close', 1),
      throwsA(isA<RequestCancelledException>()),
    );
    response.complete(ResponseBody.fromString('', 200));
    expect(calls, ['active']);
  });

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

  test('频道刷新得到合法空结果时不再复用旧的非空缓存', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path != '/search') {
          return ResponseBody.fromString('', 200);
        }
        requests += 1;
        if (requests == 1) {
          return ResponseBody.fromString('''
            <div class="horizontal-card">
              <a href="/watch?v=old-1">
                <div class="title">Old 1</div>
              </a>
            </div>
          ''', 200);
        }
        // 第二轮是站点正常返回的空列表：没有卡片，也没有挑战特征。
        return ResponseBody.fromString(
          '<div id="home-rows-wrapper"></div>',
          200,
        );
      }),
    );
    addTearDown(api.close);
    const filters = HanimeSearchFilters(sort: '最新上市');

    final initial = await api.loadHomeChannel(
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
    final afterEmptyRefresh = await api.loadHomeChannel(
      'latest-release',
      1,
      filters: filters,
    );

    expect(initial.single.id, 'old-1');
    expect(refreshed, isEmpty);
    // 合法空态必须覆盖旧数据：否则用户会一直看到已被站点清空的旧列表。
    expect(afterEmptyRefresh, isEmpty);
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

  test('后台预热请求不会排队也不会弹前台验证', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);

    expect(
      await coordinator.requestPage(Uri.parse('https://hanime1.me/'), false),
      isNull,
    );
    expect(coordinator.activeRequest, isNull);
    expect(coordinator.requiresForeground, isFalse);
  });

  test('第一个请求失败时已排队的同 host 请求被丢弃且不会连闪', () async {
    final clock = _MutableClock();
    final coordinator = HanimeCloudflareCoordinator(clock: clock.now);
    addTearDown(coordinator.dispose);

    final first = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=1'),
    );
    final second = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=2'),
    );
    final third = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=3'),
    );

    final request = coordinator.activeRequest!;
    expect(request.targetUri.queryParameters['v'], '1');

    // 失败（没有正文）：同一轮请求风暴里排队的同 host 请求必须一起结束，
    // 否则它们会逐个弹卡片，就是 issue 里的"连闪"。
    coordinator.complete(requestId: request.id);

    expect(await first, isNull);
    expect(await second, isNull);
    expect(await third, isNull);
    expect(coordinator.activeRequest, isNull);
    expect(coordinator.isCoolingDown(Uri.parse('https://hanime1.me/')), isTrue);

    // 冷却期内新请求直接放弃，不会再闪一次。
    expect(
      await coordinator.requestPage(Uri.parse('https://hanime1.me/watch?v=4')),
      isNull,
    );
    expect(coordinator.activeRequest, isNull);

    // 冷却结束后同一个 URL 仍能重新申请：去重映射必须被清干净。
    clock.advance(
      HanimeCloudflareCoordinator.verificationCooldown +
          const Duration(seconds: 1),
    );
    final retry = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=2'),
    );
    final retryRequest = coordinator.activeRequest!;
    expect(retryRequest.targetUri.queryParameters['v'], '2');
    coordinator.complete(requestId: retryRequest.id, html: '<html>ok</html>');
    expect(await retry, '<html>ok</html>');
  });

  test('验证成功后同一 host 的其它 URL 不被冷却拦住', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);

    final home = coordinator.requestPage(Uri.parse('https://hanime1.me/'));
    coordinator.complete(
      requestId: coordinator.activeRequest!.id,
      html: '<html>home</html>',
    );
    expect(await home, '<html>home</html>');
    expect(
      coordinator.isCoolingDown(Uri.parse('https://hanime1.me/')),
      isFalse,
    );

    // 刚验证成功就点开视频，必须能各自取自己的正文。
    final detail = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=9'),
    );
    final detailRequest = coordinator.activeRequest!;
    expect(detailRequest.targetUri.queryParameters['v'], '9');
    coordinator.complete(
      requestId: detailRequest.id,
      html: '<html>detail</html>',
    );
    expect(await detail, '<html>detail</html>');
  });

  test('不同 host 的排队请求不会被同 host 失败清理误伤', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);

    final hanime = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=1'),
    );
    final other = coordinator.requestPage(
      Uri.parse('https://rule34video.com/watch?v=2'),
    );

    final first = coordinator.activeRequest!;
    expect(first.targetUri.host, 'hanime1.me');
    coordinator.complete(requestId: first.id);

    expect(await hanime, isNull);
    expect(
      coordinator.remainingCooldown(Uri.parse('https://hanime1.me/')),
      isNotNull,
    );
    expect(
      coordinator.remainingCooldown(Uri.parse('https://rule34video.com/')),
      isNull,
    );

    final second = coordinator.activeRequest!;
    expect(second.targetUri.host, 'rule34video.com');
    coordinator.complete(requestId: second.id, html: '<html>other</html>');
    expect(await other, '<html>other</html>');
  });

  test('用户取消不写冷却，但同 host 排队请求一起结束', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);

    final first = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=1'),
    );
    final queued = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=2'),
    );

    coordinator.complete(
      requestId: coordinator.activeRequest!.id,
      outcome: HanimeBrowserVerificationOutcome.cancelled,
    );

    expect(await first, isNull);
    expect(await queued, isNull);
    expect(coordinator.activeRequest, isNull);
    expect(
      coordinator.isCoolingDown(Uri.parse('https://hanime1.me/')),
      isFalse,
    );

    // 用户关掉卡片后主动再点一次，必须还能弹出验证。
    final retry = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=1'),
    );
    expect(coordinator.activeRequest, isNotNull);
    coordinator.complete(
      requestId: coordinator.activeRequest!.id,
      html: '<html>ok</html>',
    );
    expect(await retry, '<html>ok</html>');
  });

  test('不同 URL 的验证结果不会互相串用', () async {
    final coordinator = HanimeCloudflareCoordinator();
    addTearDown(coordinator.dispose);
    final uriA = Uri.parse('https://hanime1.me/watch?v=A');
    final uriB = Uri.parse('https://hanime1.me/watch?v=B');
    final first = coordinator.requestPage(uriA);
    final second = coordinator.requestPage(uriB);
    final a = coordinator.activeRequest!;
    expect(a.targetUri, uriA);

    coordinator.complete(
      requestId: a.id,
      html: '<html><body>A</body></html>',
      outcome: HanimeBrowserVerificationOutcome.success,
    );
    final b = coordinator.activeRequest!;
    expect(b.targetUri, uriB);
    // A 的正文已经交出去了，B 还在等自己的正文。
    expect(await first, '<html><body>A</body></html>');
    coordinator.complete(
      requestId: b.id,
      html: '<html><body>B</body></html>',
      outcome: HanimeBrowserVerificationOutcome.success,
    );

    expect(await second, '<html><body>B</body></html>');
  });

  test('dispose 时排队中的验证请求不会永久挂起', () async {
    final coordinator = HanimeCloudflareCoordinator();
    final first = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=1'),
    );
    final second = coordinator.requestPage(
      Uri.parse('https://hanime1.me/watch?v=2'),
    );
    expect(coordinator.activeRequest?.targetUri.queryParameters['v'], '1');

    coordinator.dispose();

    expect(await first, isNull);
    expect(await second, isNull);
  });

  test('必须完成导航且拿到目标文档才算验证完成', () {
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: true,
        isChallenge: false,
        navigationFinished: true,
        hasTargetDocument: true,
      ),
      isTrue,
    );
    // 关键回归：WebView 刚创建时停在空白页（或上一页的旧文档），此时不能
    // 判完成，否则巡检首拍就把弹窗关掉，页面根本没机会加载。
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: true,
        isChallenge: false,
        navigationFinished: false,
        hasTargetDocument: true,
      ),
      isFalse,
    );
    // 旧的 cf_clearance、有标题的普通错误页都不再算数：必须由调用方给出
    // 通过真实 DOM 结构 + 目标 URI 身份校验过的目标文档。
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: true,
        isChallenge: false,
        navigationFinished: true,
        hasTargetDocument: false,
      ),
      isFalse,
    );
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: true,
        isChallenge: true,
        navigationFinished: true,
        hasTargetDocument: true,
      ),
      isFalse,
    );
    expect(
      canCompleteHanimeBrowserPage(
        isTargetHost: false,
        isChallenge: false,
        navigationFinished: true,
        hasTargetDocument: true,
      ),
      isFalse,
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
        return _hanimeSearchHtml(query: 'example', videoIds: const ['407610']);
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
        return ResponseBody.fromString(
          _hanimeSearchHtml(query: 'recovered', videoIds: const ['407612']),
          200,
        );
      }),
      browserPageHandler: (_, _) async => _hanimeSearchHtml(
        query: 'recovered',
        videoIds: const ['browser-copy'],
      ),
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('recovered', 1);

    expect(requests, 2);
    expect(videos.single.id, '407612');
  });

  test('原生重试返回 200 登录页时不覆盖已验证的浏览器正文', () async {
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
        // 跟随重定向后拿到 200，但正文是被踢回登录页的 HTML。
        return ResponseBody.fromString(
          '<html><head>'
          '<link rel="canonical" href="https://hanime1.me/login">'
          '<title>登入 - Hanime1.me</title></head>'
          '<body><form method="post" action="/login">'
          '<input name="email" type="email">'
          '<input name="password" type="password">'
          '</form></body></html>',
          200,
        );
      }),
      browserPageHandler: (_, _) async => _hanimeSearchHtml(
        query: 'recovered',
        videoIds: const ['browser-copy'],
      ),
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('recovered', 1);

    // 登录页不能当搜索正文：必须回退到已经校验过身份的浏览器正文。
    expect(requests, 2);
    expect(videos.single.id, 'browser-copy');
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

  test('连接超时不再弹浏览器验证，直接按网络错误上抛', () async {
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
        return '<div class="horizontal-card"></div>';
      },
    );
    addTearDown(api.close);

    await expectLater(
      api.searchVideos('timeout', 1),
      throwsA(isA<ApiException>()),
    );
    expect(requests, 1);
    expect(browserTarget, isNull);
  });

  test('连接被重置时采用浏览器返回的业务正文', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    var requests = 0;
    Uri? browserTarget;
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests += 1;
        if (requests == 1) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'connection reset',
          );
        }
        // 重试仍被拦截：此时才轮到浏览器兜底正文被采用。
        return ResponseBody.fromString(
          '<html><title>Attention Required! | Cloudflare</title></html>',
          403,
        );
      }),
      browserPageHandler: (targetUri, _) async {
        browserTarget = targetUri;
        return _hanimeSearchHtml(
          query: 'recovered',
          videoIds: const ['407611'],
        );
      },
    );
    addTearDown(api.close);

    final videos = await api.searchVideos('recovered', 1);

    expect(requests, 2);
    expect(browserTarget?.path, '/search');
    expect(browserTarget?.queryParameters['query'], 'recovered');
    expect(videos.single.id, '407611');
  });

  test('浏览器兜底正文不是业务页面时按 Cloudflare 受限上抛', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = Hanime1Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter(
        (_) => ResponseBody.fromString('blocked', 403),
      ),
      browserPageHandler: (_, _) async =>
          '<html><body>Access denied. Please try again later.</body></html>',
    );
    addTearDown(api.close);

    await expectLater(
      api.searchVideos('example', 1),
      throwsA(isA<HanimeCloudflareException>()),
    );
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

/// 可变时钟：让冷却测试不必真的 sleep 30 秒。
class _MutableClock {
  DateTime current = DateTime(2026, 10, 24, 12);

  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

/// 构造一份"能被身份校验接受"的 Hanime 搜索页文档。
///
/// 必须有 canonical 身份、搜索页容器和真实渲染出来的卡片：只堆几个业务类名
/// 的字符串（`_adoptBrowserBody` 以前的做法）会被 `inspectBrowserDocument`
/// 判成缺少业务结构或身份不一致。
String _hanimeSearchHtml({
  required String query,
  int page = 1,
  List<String> videoIds = const ['407610'],
  String? identity,
}) {
  final canonical =
      identity ??
      'https://hanime1.me/search?query=${Uri.encodeQueryComponent(query)}'
          '&page=$page';
  final cards = videoIds
      .map(
        (id) =>
            '<div class="horizontal-card">'
            '<a href="https://hanime1.me/watch?v=$id">'
            '<div class="title">Video $id</div></a></div>',
      )
      .join();
  return '<html><head><title>搜尋 - Hanime1.me</title>'
      '<link rel="canonical" href="$canonical"></head><body>'
      '<div id="home-rows-wrapper" class="search-rows-wrapper">'
      '<div class="home-rows-videos-wrapper">$cards</div>'
      '</div></body></html>';
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
