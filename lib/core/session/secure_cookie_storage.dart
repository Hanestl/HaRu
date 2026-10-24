import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';

import '../logging/app_log_service.dart';
import 'secret_store.dart';

/// 把 Cookie 落到 flutter_secure_storage。
///
/// 这里的每个方法都**不能抛异常**：`PersistCookieJar` 的读写被
/// dio_cookie_manager 的拦截器直接 await，一旦 Keystore 报错（恢复备份后
/// 密钥失效、系统锁屏方式变更、安全存储损坏等），异常会被拦截器包装成
/// `DioException` 并拒绝整个响应——表现是"所有网络请求都失败"，而真正
/// 的原因和网络毫无关系。降级成"这次没读到/没写进 Cookie"只会让用户
/// 掉登录，重新登录即可恢复。
final class SecureCookieStorage extends Storage {
  SecureCookieStorage(this._secretStore);

  static const _prefix = 'flule34.cookie.';

  final SecretStore _secretStore;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) async {
    try {
      return await _secretStore.read(_key(key));
    } on Object catch (error, stackTrace) {
      unawaited(_report('read', key, error, stackTrace));
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _secretStore.write(_key(key), value);
    } on Object catch (error, stackTrace) {
      unawaited(_report('write', key, error, stackTrace));
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _secretStore.delete(_key(key));
    } on Object catch (error, stackTrace) {
      unawaited(_report('delete', key, error, stackTrace));
    }
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    await Future.wait(keys.map(delete));
  }

  Future<void> _report(
    String operation,
    String key,
    Object error,
    StackTrace stackTrace,
  ) {
    return AppLogService.instance.error(
      error,
      stackTrace,
      component: 'secure_cookie_storage.$operation',
    );
  }

  String _key(String key) => '$_prefix$key';
}
