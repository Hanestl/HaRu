import 'package:cookie_jar/cookie_jar.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('用户身份和完整 Cookie 可以从安全存储恢复并清除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final uri = Uri.parse('https://rule34video.com/');

    await harness.sessionStore.load();
    await harness.sessionStore.cookieJar.saveFromResponse(uri, [
      Cookie('PHPSESSID', 'session-value')
        ..path = '/'
        ..secure = true
        ..httpOnly = true,
    ]);
    await harness.sessionStore.authenticate('2421071');

    final restored = SessionStore(
      cookieJar: harness.newCookieJar(),
      secretStore: harness.secretStore,
      database: harness.database,
    );
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.currentUserId, '2421071');
    expect(await restored.cookieHeaderFor(uri), 'PHPSESSID=session-value');
    expect(await harness.database.findAccount('2421071'), isNotNull);

    await restored.clear();

    expect(restored.isLoggedIn, isFalse);
    expect(await restored.cookieHeaderFor(uri), isNull);
  });

  test('非法用户 ID 不会建立会话', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await expectLater(
      harness.sessionStore.authenticate('invalid-user'),
      throwsArgumentError,
    );
    expect(harness.sessionStore.isLoggedIn, isFalse);
  });

  test('按站点清理 Cookie 不会删除其他内容源的会话', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final rule34Uri = Uri.parse('https://rule34video.com/');
    final hanimeUri = Uri.parse('https://hanime1.me/');

    await harness.sessionStore.cookieJar.saveFromResponse(rule34Uri, [
      Cookie('PHPSESSID', 'rule34-session')..path = '/',
    ]);
    await harness.sessionStore.cookieJar.saveFromResponse(hanimeUri, [
      Cookie('cf_clearance', 'hanime-clearance')..path = '/',
    ]);

    await harness.sessionStore.clearCookiesFor(rule34Uri);

    expect(await harness.sessionStore.cookieHeaderFor(rule34Uri), isNull);
    expect(
      await harness.sessionStore.cookieHeaderFor(hanimeUri),
      'cf_clearance=hanime-clearance',
    );
  });

  test('账号密码会持久化，并且只有明确忘记时才删除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await harness.sessionStore.saveCredentials(
      email: 'user@example.com',
      password: 'password',
    );
    await harness.sessionStore.clear();

    final saved = await harness.sessionStore.loadCredentials();
    expect(saved?.email, 'user@example.com');
    expect(saved?.password, 'password');

    await harness.sessionStore.clear(forgetCredentials: true);
    expect(await harness.sessionStore.loadCredentials(), isNull);
  });

  test('Hanime 与 Rule34Video 双账号身份隔离共存', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await harness.sessionStore.authenticate('1001');
    await harness.sessionStore.authenticateHanime('2002');

    expect(harness.sessionStore.isLoggedIn, isTrue);
    expect(harness.sessionStore.currentUserId, '1001');
    expect(harness.sessionStore.isHanimeLoggedIn, isTrue);
    expect(harness.sessionStore.hanimeUserId, '2002');

    // 清除 hanime 身份不影响 rule34video。
    await harness.sessionStore.clearHanime();
    expect(harness.sessionStore.isHanimeLoggedIn, isFalse);
    expect(harness.sessionStore.hanimeUserId, isNull);
    expect(harness.sessionStore.isLoggedIn, isTrue);
    expect(harness.sessionStore.currentUserId, '1001');

    // 清除 rule34video 身份不影响 hanime（需先重新登录 hanime）。
    await harness.sessionStore.authenticateHanime('2003');
    await harness.sessionStore.clear();
    expect(harness.sessionStore.isLoggedIn, isFalse);
    expect(harness.sessionStore.isHanimeLoggedIn, isTrue);
    expect(harness.sessionStore.hanimeUserId, '2003');
  });

  test('Hanime 身份与凭据可从安全存储恢复', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await harness.sessionStore.authenticateHanime('424242');
    await harness.sessionStore.saveHanimeCredentials(
      email: 'hanime@example.com',
      password: 'secret',
    );

    final restored = SessionStore(
      cookieJar: harness.newCookieJar(),
      secretStore: harness.secretStore,
      database: harness.database,
    );
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.hanimeUserId, '424242');
    final credentials = await restored.loadHanimeCredentials();
    expect(credentials?.email, 'hanime@example.com');
    expect(credentials?.password, 'secret');

    await restored.clearHanime(forgetCredentials: true);
    expect(restored.isHanimeLoggedIn, isFalse);
    expect(await restored.loadHanimeCredentials(), isNull);
  });

  test('Hanime 非法用户 ID 不会建立会话', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await expectLater(
      harness.sessionStore.authenticateHanime('not-a-number'),
      throwsArgumentError,
    );
    expect(harness.sessionStore.isHanimeLoggedIn, isFalse);
  });
}
