import 'dart:async';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/downloads/presentation/downloads_list.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('运行任务在首个微小数据分片阶段仍显示正在连接', () {
    final record = _record(bytesDownloaded: 707, totalBytes: 1024 * 1024);

    expect(isDownloadConnecting(record), isTrue);
    expect(
      downloadStatusText(
        record,
        validation: null,
        validating: false,
        invalid: false,
      ),
      '正在连接',
    );
  });

  test('达到有意义的数据量后显示真实下载进度', () {
    final record = _record(
      bytesDownloaded: meaningfulDownloadProgressBytes,
      totalBytes: 1024 * 1024,
    );

    expect(isDownloadConnecting(record), isFalse);
    expect(
      downloadStatusText(
        record,
        validation: null,
        validating: false,
        invalid: false,
      ),
      '正在下载 · 64.0 KB / 1.0 MB',
    );
  });

  testWidgets('DownloadsList 空列表展示占位文案，且支持加载真实下载记录', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final settings = AppSettingsRepository(_MemorySettingsStore());
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final platform = _FakeDownloadPlatformService();
    final repository = DownloadRepository(
      harness.database,
      api,
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DownloadsList(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('还没有下载任务。'), findsOneWidget);

    // 插入一条记录
    await harness.database
        .into(harness.database.downloadRecords)
        .insert(
          DownloadRecordsCompanion.insert(
            id: 'test_task_1',
            userId: '__flule34_device__',
            videoId: 'video-123',
            title: '测试下载视频',
            quality: '720p',
            state: 'failed',
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('测试下载视频'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

final class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  Future<String?> sessionCookieHeader() async => 'PHPSESSID=test-cookie';

  @override
  void close() {}
}

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  @override
  Stream<DownloadPlatformEvent> get events => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMaxConcurrent(int value) async {}

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<bool> ensureSharedStoragePermission() async => true;

  @override
  Future<bool> taskExists(String taskId) async => false;

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async =>
      const DownloadFileInspection(exists: false, readable: false);

  @override
  void setCompletionSink(
    Future<void> Function(DownloadStatusEvent event)? sink,
  ) {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DownloadRecord _record({
  required int bytesDownloaded,
  required int totalBytes,
}) {
  final now = DateTime(2026, 7, 30);
  return DownloadRecord(
    id: 'download-test',
    userId: 'device',
    videoId: 'video',
    title: '测试视频',
    quality: '1080p',
    state: 'running',
    bytesDownloaded: bytesDownloaded,
    totalBytes: totalBytes,
    createdAt: now,
    updatedAt: now,
  );
}
