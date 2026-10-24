import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('未登录也可将视频加入固定公共下载目录', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings(wifiOnlyDownloads: true);
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    expect(id, 'flule34_4505897_720p');
    expect(platform.sharedStoragePermissionChecks, 1);
    expect(platform.requests, hasLength(1));
    expect(platform.requests.single.requiresWiFi, isTrue);
    expect(platform.requests.single.headers['Cookie'], 'PHPSESSID=test-cookie');
    expect(platform.requests.single.filename, '测试视频_4505897_720p.mp4');
    final record = await harness.database.findDownloadRecord(id);
    expect(record?.thumbnailUrl, 'https://example.com/preview.jpg');
    expect(record?.fileName, '测试视频_4505897_720p.mp4');
    expect(record?.taskId, platform.requests.single.id);
    expect(record?.taskId, startsWith('${id}_'));
  });

  test('不同站点的同 ID 视频使用独立下载记录、任务和文件名', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final hanimeDetails = VideoDetails(
      video: _details.video.copyWith(siteId: 'hanime1'),
      sources: _details.sources,
      categories: const [],
      tags: const [],
      models: const [],
      isFavorite: false,
    );

    final rule34Id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final hanimeId = await repository.enqueueVideo(
      details: hanimeDetails,
      source: hanimeDetails.sources.single,
    );

    expect(rule34Id, 'flule34_4505897_720p');
    expect(hanimeId, 'flule34_hanime1_4505897_720p');
    expect(platform.requests, hasLength(2));
    expect(platform.requests[0].filename, '测试视频_4505897_720p.mp4');
    expect(platform.requests[1].filename, '测试视频_hanime1_4505897_720p.mp4');
    expect(
      await harness.database.findVideoDownload(
        userId: '__flule34_device__',
        videoId: 'hanime1:4505897',
        quality: '720p',
      ),
      isNotNull,
    );
  });

  test('同一视频和清晰度并发提交时只会建立一个平台任务', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    final first = repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    await first;

    expect(platform.requests, hasLength(1));
  });

  test('启动时将平台中已不存在的活动任务恢复为可重试失败状态', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.database.recordAuthenticatedAccount(
      '__flule34_device__',
      displayName: '本机下载',
    );
    final now = DateTime.now().toUtc();
    await harness.database.saveDownloadRecord(
      DownloadRecordsCompanion.insert(
        id: 'orphaned-download',
        userId: '__flule34_device__',
        videoId: '1',
        title: '中断任务',
        quality: '720p',
        state: DownloadTaskState.running.storageValue,
        taskId: const Value('missing-platform-task'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);

    await repository.initialize();

    final record = await harness.database.findDownloadRecord(
      'orphaned-download',
    );
    expect(record?.state, DownloadTaskState.failed.storageValue);
    expect(record?.errorMessage, contains('系统中断'));
  });

  test('通知权限或公共目录权限被拒绝时不会入队', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService()
      ..notificationPermissionGranted = false;
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);
    expect(platform.sharedStoragePermissionChecks, 0);

    platform.notificationPermissionGranted = true;
    platform.sharedStoragePermissionGranted = false;
    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);
    expect(platform.sharedStoragePermissionChecks, 1);
  });

  test('暂停与继续操作会传递给后台下载服务', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final taskId = (await harness.database.findDownloadRecord(id))!.taskId!;

    expect(await repository.pause(id), isTrue);
    expect(await repository.resume(id), isTrue);
    expect(platform.pausedTaskIds, [taskId]);
    expect(platform.resumedTaskIds, [taskId]);
    expect(await repository.pause('missing-task'), isFalse);
  });

  test('完成事件使用实际文件大小并保存公共文件 URI', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final taskId = (await harness.database.findDownloadRecord(id))!.taskId!;

    platform.emit(
      DownloadProgressEvent(
        taskId: taskId,
        bytesDownloaded: 512,
        totalBytes: 1024,
      ),
    );
    platform.emit(
      DownloadStatusEvent(
        taskId: taskId,
        state: DownloadTaskState.complete,
        filePath: _fileUri,
        actualBytes: 2048,
      ),
    );
    await _waitFor(() async {
      return (await harness.database.findDownloadRecord(id))?.state ==
          DownloadTaskState.complete.storageValue;
    });

    final record = await harness.database.findDownloadRecord(id);
    expect(record?.bytesDownloaded, 2048);
    expect(record?.totalBytes, 2048);
    expect(record?.filePath, _fileUri);
    expect(record?.completedAt, isNotNull);
  });

  test('完成事件刷新进度失败时仍可写入终态且不会阻断后续事件链', () async {
    final db = _FaultInjectableDatabase();
    addTearDown(db.close);
    final harness = TestSessionHarness.create(database: db);
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      db,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final taskId = (await db.findDownloadRecord(id))!.taskId!;

    // 初始进度写入
    platform.emit(
      DownloadProgressEvent(
        taskId: taskId,
        bytesDownloaded: 512,
        totalBytes: 1024,
      ),
    );
    await _waitFor(() async {
      return (await db.findDownloadRecord(id))?.bytesDownloaded == 512;
    });

    // 注入故障：进度更新异常
    db.failUpdateProgress = true;

    platform.emit(
      DownloadStatusEvent(
        taskId: taskId,
        state: DownloadTaskState.complete,
        filePath: _fileUri,
        actualBytes: 2048,
      ),
    );

    // 验证：即使刷新进度发生异常，终态依然能正确写入，任务不会卡死或状态倒退
    await _waitFor(() async {
      return (await db.findDownloadRecord(id))?.state ==
          DownloadTaskState.complete.storageValue;
    });

    final record = await db.findDownloadRecord(id);
    expect(record?.state, DownloadTaskState.complete.storageValue);
    expect(record?.filePath, _fileUri);
    expect(record?.completedAt, isNotNull);
    expect(record?.bytesDownloaded, 2048);
    expect(record?.totalBytes, 2048);

    // 验证下游文件校验可正常通过
    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record!.fileName,
      size: 2048,
    );
    final validation = await repository.validateFile(record);
    expect(validation.valid, isTrue);

    // 验证：任务已完成时，迟到的旧进度事件被过滤，不污染已落库的终态字节数
    platform.emit(
      DownloadProgressEvent(
        taskId: taskId,
        bytesDownloaded: 256,
        totalBytes: 512,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final recordAfterLateProgress = await db.findDownloadRecord(id);
    expect(recordAfterLateProgress?.bytesDownloaded, 2048);
    expect(recordAfterLateProgress?.totalBytes, 2048);

    // 故障恢复后，事件链未损坏，仍可继续处理后续任务
    db.failUpdateProgress = false;
    final details2 = _details.copyWith(
      video: const VideoItem(
        id: '4505898',
        title: '第二个测试视频',
        slug: 'test-video-2',
      ),
    );
    final id2 = await repository.enqueueVideo(
      details: details2,
      source: details2.sources.single,
    );
    final taskId2 = (await db.findDownloadRecord(id2))!.taskId!;
    platform.emit(
      DownloadStatusEvent(
        taskId: taskId2,
        state: DownloadTaskState.complete,
        filePath: _fileUri,
        actualBytes: 4096,
      ),
    );
    await _waitFor(() async {
      return (await db.findDownloadRecord(id2))?.state ==
          DownloadTaskState.complete.storageValue;
    });
    final record2 = await db.findDownloadRecord(id2);
    expect(record2?.bytesDownloaded, 4096);
    expect(record2?.totalBytes, 4096);
  });

  test('重试使用新的平台任务 ID 且忽略旧任务迟到回调', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final original = (await harness.database.findDownloadRecord(id))!;
    final originalTaskId = original.taskId!;

    expect(await repository.retry(original), isTrue);
    final retried = (await harness.database.findDownloadRecord(id))!;
    final retriedTaskId = retried.taskId!;
    expect(retriedTaskId, isNot(originalTaskId));
    expect(platform.requests.last.id, retriedTaskId);
    expect(platform.deletedUris, contains(originalTaskId));

    platform.emit(
      DownloadStatusEvent(
        taskId: originalTaskId,
        state: DownloadTaskState.failed,
        errorMessage: '旧任务失败',
      ),
    );
    platform.emit(
      DownloadProgressEvent(
        taskId: originalTaskId,
        bytesDownloaded: 999,
        totalBytes: 1000,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    var current = (await harness.database.findDownloadRecord(id))!;
    expect(current.state, DownloadTaskState.queued.storageValue);
    expect(current.bytesDownloaded, 0);

    platform.emit(
      DownloadProgressEvent(
        taskId: retriedTaskId,
        bytesDownloaded: 500,
        totalBytes: 1000,
      ),
    );
    await _waitFor(() async {
      return (await harness.database.findDownloadRecord(id))?.bytesDownloaded ==
          500;
    });
    current = (await harness.database.findDownloadRecord(id))!;
    expect(current.totalBytes, 1000);
  });

  test('系统或网络中断会使用新任务 ID 自动恢复一次', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    final originalTaskId = (await harness.database.findDownloadRecord(
      id,
    ))!.taskId!;

    platform.emit(
      DownloadStatusEvent(
        taskId: originalTaskId,
        state: DownloadTaskState.failed,
        errorMessage: '下载任务被系统中断，请重试。',
      ),
    );
    await _waitFor(() async => platform.requests.length == 2);

    final retried = (await harness.database.findDownloadRecord(id))!;
    expect(retried.taskId, platform.requests.last.id);
    expect(retried.taskId, isNot(originalTaskId));
    expect(retried.state, DownloadTaskState.queued.storageValue);
  });

  test('完成文件必须同时满足存在、可读、文件名和体积一致', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    final platform = context.platform;

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes,
    );
    expect((await context.repository.validateFile(record)).valid, isTrue);

    platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );
    var validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件已不存在。');

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: '${record.fileName}.renamed',
      size: record.totalBytes,
    );
    validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件已被改名。');

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes! + 1,
    );
    validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件大小已发生变化。');
  });

  test('失效文件不能播放，删除记录时不触碰外部文件', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    context.platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );

    expect(await context.repository.open(record), isFalse);
    expect(context.platform.openedUris, isEmpty);
    expect(await context.repository.delete(record), isTrue);
    expect(context.platform.deleteExternalFlags[record.taskId], isFalse);
    expect(
      await context.harness.database.findDownloadRecord(record.id),
      isNull,
    );
  });

  test('有效完成文件可以播放并从公共目录删除', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    context.platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes,
    );

    expect(await context.repository.open(record), isTrue);
    expect(context.platform.openedUris, [_fileUri]);
    expect(await context.repository.delete(record), isTrue);
    expect(context.platform.deletedUris[record.taskId], _fileUri);
    expect(context.platform.deleteExternalFlags[record.taskId], isTrue);
  });

  test('批量仅删除记录会保留公共目录视频', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.recordsOnly,
    );

    expect(result.matched, 1);
    expect(result.deleted, 1);
    expect(result.failed, 0);
    expect(
      context.platform.deleteExternalFlags[context.record.taskId],
      isFalse,
    );
  });

  test('批量删除失效记录只匹配校验失败的完成任务', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    context.platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.invalidRecords,
    );

    expect(result.matched, 1);
    expect(result.deleted, 1);
    expect(
      context.platform.deleteExternalFlags[context.record.taskId],
      isFalse,
    );
  });

  test('批量删除记录及视频会请求删除公共文件', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.filesAndRecords,
    );

    expect(result.deleted, 1);
    expect(context.platform.deletedUris[context.record.taskId], _fileUri);
    expect(context.platform.deleteExternalFlags[context.record.taskId], isTrue);
  });

  test('下载进度节流根据时间、字节阈值和百分比决定是否落库', () {
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    // 未达时间（< 500ms）且增量微小（< 1MB）且百分比未达 1% -> 不落库
    expect(
      shouldPersistDownloadProgress(
        lastPersistedAt: t0,
        lastPersistedBytes: 100,
        currentBytes: 150,
        totalBytes: 10000000,
        now: t0.add(const Duration(milliseconds: 100)),
      ),
      isFalse,
    );

    // 超过节流间隔（>= 500ms）-> 落库
    expect(
      shouldPersistDownloadProgress(
        lastPersistedAt: t0,
        lastPersistedBytes: 100,
        currentBytes: 150,
        totalBytes: 10000000,
        now: t0.add(const Duration(milliseconds: 550)),
      ),
      isTrue,
    );

    // 增量超过 1MB -> 落库
    expect(
      shouldPersistDownloadProgress(
        lastPersistedAt: t0,
        lastPersistedBytes: 100,
        currentBytes: 100 + 1024 * 1024 + 1,
        totalBytes: 100000000,
        now: t0.add(const Duration(milliseconds: 100)),
      ),
      isTrue,
    );

    // 百分比增长超过 1% -> 落库
    expect(
      shouldPersistDownloadProgress(
        lastPersistedAt: t0,
        lastPersistedBytes: 0,
        currentBytes: 150,
        totalBytes: 10000,
        now: t0.add(const Duration(milliseconds: 100)),
      ),
      isTrue,
    );
  });

  test('进度事件在状态流转时冲刷最新进度至数据库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.first,
    );
    final taskId = platform.requests.single.id;

    // 发送首次进度
    platform.emit(
      DownloadProgressEvent(
        taskId: taskId,
        bytesDownloaded: 1024 * 1024,
        totalBytes: 10 * 1024 * 1024,
      ),
    );
    await _waitFor(() async {
      final record = await harness.database.findDownloadRecord(id);
      return (record?.bytesDownloaded ?? 0) >= 1024 * 1024;
    });

    // 发送未达阈值的进度（不足 1MB / 不足 500ms），随后立即暂停
    platform.emit(
      DownloadProgressEvent(
        taskId: taskId,
        bytesDownloaded: 1024 * 1024 + 500,
        totalBytes: 10 * 1024 * 1024,
      ),
    );
    platform.emit(
      DownloadStatusEvent(taskId: taskId, state: DownloadTaskState.paused),
    );
    await _waitFor(() async {
      final record = await harness.database.findDownloadRecord(id);
      return record?.state == DownloadTaskState.paused.storageValue &&
          (record?.bytesDownloaded ?? 0) == 1024 * 1024 + 500;
    });

    final record = (await harness.database.findDownloadRecord(id))!;
    expect(record.bytesDownloaded, 1024 * 1024 + 500);
    expect(record.state, DownloadTaskState.paused.storageValue);
  });
}

const _fileUri = 'content://media/external/downloads/flule34_4505897_720p.mp4';

const _details = VideoDetails(
  video: VideoItem(
    id: '4505897',
    title: '测试视频',
    slug: 'test-video',
    thumbnailUrl: 'https://example.com/320x180/4505897.jpg',
  ),
  sources: [
    VideoSource(
      label: '720p',
      url: 'https://rule34video.com/get_file/video_720p.mp4?token=test',
      isHd: true,
    ),
  ],
  categories: [],
  tags: [],
  models: [],
  isFavorite: false,
);

Future<_CompletedDownloadContext> _completedDownload() async {
  final harness = TestSessionHarness.create();
  await harness.sessionStore.load();
  final platform = _FakeDownloadPlatformService();
  final settings = await _createSettings();
  final repository = DownloadRepository(
    harness.database,
    _FakeRule34VideoApi(harness.sessionStore),
    platform,
    settings,
  );
  await repository.initialize();
  final id = await repository.enqueueVideo(
    details: _details,
    source: _details.sources.single,
  );
  final taskId = (await harness.database.findDownloadRecord(id))!.taskId!;
  platform.emit(
    DownloadStatusEvent(
      taskId: taskId,
      state: DownloadTaskState.complete,
      filePath: _fileUri,
      actualBytes: 2048,
    ),
  );
  await _waitFor(() async {
    return (await harness.database.findDownloadRecord(id))?.state ==
        DownloadTaskState.complete.storageValue;
  });
  return _CompletedDownloadContext(
    harness: harness,
    settings: settings,
    platform: platform,
    repository: repository,
    record: (await harness.database.findDownloadRecord(id))!,
  );
}

final class _CompletedDownloadContext {
  const _CompletedDownloadContext({
    required this.harness,
    required this.settings,
    required this.platform,
    required this.repository,
    required this.record,
  });

  final TestSessionHarness harness;
  final AppSettingsRepository settings;
  final _FakeDownloadPlatformService platform;
  final DownloadRepository repository;
  final DownloadRecord record;

  void dispose() {
    repository.dispose();
    settings.dispose();
    harness.dispose();
  }
}

Future<void> _waitFor(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('等待异步状态更新超时。');
}

Future<AppSettingsRepository> _createSettings({
  bool wifiOnlyDownloads = false,
}) async {
  final repository = AppSettingsRepository(_MemorySettingsStore());
  await repository.load();
  if (wifiOnlyDownloads) {
    await repository.setWifiOnlyDownloads(true);
  }
  return repository;
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

final class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  var detailLoads = 0;

  @override
  Future<String?> sessionCookieHeader() async => 'PHPSESSID=test-cookie';

  @override
  Future<VideoDetails> loadVideoDetails(
    VideoItem video, {
    bool allowForegroundVerification = true,
  }) async {
    detailLoads += 1;
    return VideoDetails(
      video: video,
      sources: [
        VideoSource(
          label: '720p',
          url: 'https://rule34video.com/get_file/video.mp4?token=$detailLoads',
          isHd: true,
        ),
      ],
      categories: const [],
      tags: const [],
      models: const [],
      isFavorite: false,
    );
  }

  @override
  void close() {}
}

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
  final List<DownloadRequest> requests = [];
  final List<String> openedUris = [];
  final Map<String, String?> deletedUris = {};
  final Map<String, bool> deleteExternalFlags = {};
  final Map<String, DownloadFileInspection> inspections = {};
  final List<int> maxConcurrentValues = [];
  final List<String> pausedTaskIds = [];
  final List<String> resumedTaskIds = [];
  final Set<String> existingTaskIds = {};
  var notificationPermissionGranted = true;
  var sharedStoragePermissionGranted = true;
  var sharedStoragePermissionChecks = 0;

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  void emit(DownloadPlatformEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMaxConcurrent(int value) async {
    maxConcurrentValues.add(value);
  }

  @override
  Future<bool> ensureNotificationPermission() async =>
      notificationPermissionGranted;

  @override
  Future<bool> ensureSharedStoragePermission() async {
    sharedStoragePermissionChecks += 1;
    return sharedStoragePermissionGranted;
  }

  @override
  Future<bool> taskExists(String taskId) async =>
      existingTaskIds.contains(taskId);

  @override
  Future<bool> enqueue(DownloadRequest request) async {
    requests.add(request);
    return true;
  }

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> pause(String taskId) async {
    pausedTaskIds.add(taskId);
    return true;
  }

  @override
  Future<bool> resume(String taskId) async {
    resumedTaskIds.add(taskId);
    return true;
  }

  @override
  Future<bool> openFile(String fileUri) async {
    openedUris.add(fileUri);
    return true;
  }

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async {
    return inspections[fileUri] ??
        const DownloadFileInspection(exists: false, readable: false);
  }

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async {
    deletedUris[taskId] = fileUri;
    deleteExternalFlags[taskId] = deleteExternalFile;
    return true;
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}

final class _FaultInjectableDatabase extends AppDatabase {
  _FaultInjectableDatabase() : super(NativeDatabase.memory());

  bool failUpdateProgress = false;

  @override
  Future<void> updateDownloadProgress({
    required String id,
    required int bytesDownloaded,
    int? totalBytes,
  }) {
    if (failUpdateProgress) {
      throw StateError(
        'Simulated database error during updateDownloadProgress',
      );
    }
    return super.updateDownloadProgress(
      id: id,
      bytesDownloaded: bytesDownloaded,
      totalBytes: totalBytes,
    );
  }
}
