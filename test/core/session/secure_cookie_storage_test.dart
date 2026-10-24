import 'package:cookie_jar/cookie_jar.dart';
import 'package:flule34/core/session/secret_store.dart';
import 'package:flule34/core/session/secure_cookie_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 模拟 Keystore 不可用：恢复备份后密钥失效、系统锁屏方式变更等场景。
final class _FailingSecretStore implements SecretStore {
  int readAttempts = 0;
  int writeAttempts = 0;
  int deleteAttempts = 0;

  @override
  Future<String?> read(String key) async {
    readAttempts += 1;
    throw StateError('keystore unavailable');
  }

  @override
  Future<void> write(String key, String value) async {
    writeAttempts += 1;
    throw StateError('keystore unavailable');
  }

  @override
  Future<void> delete(String key) async {
    deleteAttempts += 1;
    throw StateError('keystore unavailable');
  }
}

void main() {
  test('安全存储读写失败时降级为无操作，不向调用方抛异常', () async {
    final store = _FailingSecretStore();
    final storage = SecureCookieStorage(store);

    expect(await storage.read('rule34video.com'), isNull);
    await storage.write('rule34video.com', '[]');
    await storage.delete('rule34video.com');
    await storage.deleteAll(['a.example', 'b.example']);

    expect(store.readAttempts, 1);
    expect(store.writeAttempts, 1);
    expect(store.deleteAttempts, 3);
  });

  test('安全存储不可用时保存 Cookie 不会让整个响应失败', () async {
    final store = _FailingSecretStore();
    final jar = PersistCookieJar(
      persistSession: true,
      storage: SecureCookieStorage(store),
    );
    final uri = Uri.parse('https://rule34video.com/');

    // dio_cookie_manager 的拦截器直接 await saveFromResponse：它一旦抛异常，
    // 整个 HTTP 响应会被包装成 DioException，表现为"所有请求都网络错误"。
    await expectLater(
      jar.saveFromResponse(uri, [Cookie('PHPSESSID', 'value')..path = '/']),
      completes,
    );

    // 本次运行仍然可用（内存里的 Cookie 还在），只是重启后无法恢复。
    expect(await jar.loadForRequest(uri), hasLength(1));

    final restarted = PersistCookieJar(
      persistSession: true,
      storage: SecureCookieStorage(store),
    );
    expect(await restarted.loadForRequest(uri), isEmpty);
  });
}
