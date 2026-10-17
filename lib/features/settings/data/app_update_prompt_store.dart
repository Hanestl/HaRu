import 'package:shared_preferences/shared_preferences.dart';

/// 「已通知过的版本号」存储接口；便于测试注入内存实现。
abstract interface class UpdateNotifiedVersionStore {
  Future<String?> readNotifiedVersion();

  Future<void> writeNotifiedVersion(String version);
}

final class SharedPreferencesUpdateNotifiedVersionStore
    implements UpdateNotifiedVersionStore {
  SharedPreferencesUpdateNotifiedVersionStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _notifiedVersionKey = 'flule34.update.notified_version';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readNotifiedVersion() {
    return _preferences.getString(_notifiedVersionKey);
  }

  @override
  Future<void> writeNotifiedVersion(String version) {
    return _preferences.setString(_notifiedVersionKey, version);
  }
}

/// 记录已弹窗提示过的更新版本，保证每个新版本只通知一次。
final class UpdatePromptStore {
  const UpdatePromptStore(this._store);

  final UpdateNotifiedVersionStore _store;

  /// 返回上次已通知的版本号；未通知过时返回 null。
  Future<String?> notifiedVersion() => _store.readNotifiedVersion();

  /// 记录已通知版本；弹窗展示时即写入，避免用户忽略后每次启动重复打扰。
  Future<void> markNotified(String version) {
    return _store.writeNotifiedVersion(version);
  }
}
