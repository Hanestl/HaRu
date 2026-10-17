import 'package:flule34/features/settings/data/app_update_prompt_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('首次读取为空，记录后可读回已通知版本', () async {
    final store = UpdatePromptStore(_MemoryStore());

    expect(await store.notifiedVersion(), isNull);

    await store.markNotified('2.5.0');
    expect(await store.notifiedVersion(), '2.5.0');

    await store.markNotified('2.6.0');
    expect(await store.notifiedVersion(), '2.6.0');
  });

  test('仅保留最近一次通知的版本号', () async {
    final backing = _MemoryStore();
    final store = UpdatePromptStore(backing);

    await store.markNotified('2.5.0');
    await store.markNotified('2.5.1');

    expect(backing.value, '2.5.1');
  });
}

final class _MemoryStore implements UpdateNotifiedVersionStore {
  String? value;

  @override
  Future<String?> readNotifiedVersion() async => value;

  @override
  Future<void> writeNotifiedVersion(String version) async {
    value = version;
  }
}
