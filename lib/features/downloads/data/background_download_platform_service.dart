import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/logging/app_log_service.dart';
import '../../../core/security/error_redaction.dart';
import '../domain/download_models.dart';

final class BackgroundDownloadPlatformService
    implements DownloadPlatformService {
  factory BackgroundDownloadPlatformService({int maxConcurrent = 2}) {
    return BackgroundDownloadPlatformService._(maxConcurrent);
  }

  BackgroundDownloadPlatformService._(this._maxConcurrent);

  static const _group = 'flule34-downloads';
  static const notificationGroupId = 'flule34-background-tasks';
  static const requestTimeout = Duration(seconds: 15);
  static const runningNotification = TaskNotification('后台任务进行中', '正在处理');
  static const _privateDirectory = 'downloads';
  static const _publicDirectory = 'Flule34';
  static const _mediaStoreInspectionDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 120),
    Duration(milliseconds: 350),
    Duration(milliseconds: 800),
  ];
  static const _storageChannel = MethodChannel(
    'com.hanestl.flule34/storage_access',
  );

  final FileDownloader _downloader = FileDownloader();
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
  final Set<String> _finalizing = {};
  final Set<Future<void>> _pendingWork = <Future<void>>{};
  Future<void> Function(DownloadStatusEvent event)? _completionSink;
  Timer? _rescheduleTimer;
  int _maxConcurrent;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  @override
  void setCompletionSink(
    Future<void> Function(DownloadStatusEvent event)? sink,
  ) {
    _completionSink = sink;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _downloader.configure(
      globalConfig: (Config.requestTimeout, requestTimeout),
      androidConfig: (Config.runInForeground, Config.always),
    );
    await setMaxConcurrent(_maxConcurrent);
    _downloader
        .registerCallbacks(
          group: _group,
          taskStatusCallback: _onStatus,
          taskProgressCallback: _onProgress,
        )
        .configureNotificationForGroup(
          _group,
          running: runningNotification,
          progressBar: true,
          tapOpensFile: false,
          groupNotificationId: notificationGroupId,
        );
    await _downloader.trackTasksInGroup(_group);
    await _downloader.resumeFromBackground();
    _rescheduleTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_rescheduleKilledTasks());
    });
    _initialized = true;
  }

  @override
  Future<void> setMaxConcurrent(int value) async {
    _maxConcurrent = value.clamp(1, 4);
    await _downloader.configure(
      globalConfig: (
        Config.holdingQueue,
        (_maxConcurrent, _maxConcurrent, _maxConcurrent),
      ),
    );
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    final permissions = _downloader.permissions;
    final current = await permissions.status(PermissionType.notifications);
    if (current == PermissionStatus.granted) {
      return true;
    }
    return await permissions.request(PermissionType.notifications) ==
        PermissionStatus.granted;
  }

  @override
  Future<bool> ensureSharedStoragePermission() async {
    final permissions = _downloader.permissions;
    final current = await permissions.status(
      PermissionType.androidSharedStorage,
    );
    if (current == PermissionStatus.granted) {
      return true;
    }
    return await permissions.request(PermissionType.androidSharedStorage) ==
        PermissionStatus.granted;
  }

  @override
  Future<bool> enqueue(DownloadRequest request) async {
    final accepted = await _downloader.enqueue(
      DownloadTask(
        taskId: request.id,
        url: request.url,
        filename: request.filename,
        headers: request.headers,
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _privateDirectory,
        group: _group,
        updates: Updates.statusAndProgress,
        requiresWiFi: request.requiresWiFi,
        retries: 4,
        allowPause: true,
        priority: 0,
        metaData: request.metadata,
        displayName: request.displayName,
      ),
    );
    return accepted;
  }

  @override
  Future<bool> taskExists(String taskId) async {
    if (await _downloader.taskForId(taskId) != null) {
      return true;
    }
    return await _downloader.database.recordForId(taskId) != null;
  }

  Future<void> _rescheduleKilledTasks() async {
    try {
      await _downloader.rescheduleKilledTasks();
    } on Object catch (error, stackTrace) {
      await AppLogService.instance.error(
        error,
        stackTrace,
        component: 'download_reschedule',
      );
    }
  }

  @override
  Future<bool> cancel(String taskId) {
    return _downloader.cancelTaskWithId(taskId);
  }

  @override
  Future<bool> pause(String taskId) async {
    final task = await _downloadTask(taskId);
    return task == null ? false : _downloader.pause(task);
  }

  @override
  Future<bool> resume(String taskId) async {
    final task = await _downloadTask(taskId);
    return task == null ? false : _downloader.resume(task);
  }

  Future<DownloadTask?> _downloadTask(String taskId) async {
    final activeTask = await _downloader.taskForId(taskId);
    if (activeTask is DownloadTask) {
      return activeTask;
    }
    final storedTask = (await _downloader.database.recordForId(taskId))?.task;
    return storedTask is DownloadTask ? storedTask : null;
  }

  @override
  Future<bool> openFile(String fileUri) {
    return _downloader.uri.openFile(Uri.parse(fileUri), mimeType: 'video/mp4');
  }

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async {
    try {
      final result = await _storageChannel.invokeMapMethod<String, Object?>(
        'inspectFile',
        {'uri': fileUri},
      );
      return DownloadFileInspection(
        exists: result?['exists'] == true,
        readable: result?['readable'] == true,
        name: result?['name'] as String?,
        size: switch (result?['size']) {
          final int value => value,
          final num value => value.toInt(),
          _ => null,
        },
      );
    } on PlatformException {
      return const DownloadFileInspection(exists: false, readable: false);
    }
  }

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    await _downloader.cancelTaskWithId(taskId);
    if (deleteExternalFile && fileUri != null) {
      final inspection = await inspectFile(fileUri);
      if (inspection.exists) {
        if (!await _deleteSharedFile(fileUri)) {
          return false;
        }
      }
    }
    if (task is DownloadTask) {
      try {
        final file = File(await task.filePath());
        if (await file.exists()) {
          await file.delete();
        }
      } on FileSystemException {
        return false;
      }
    }
    await _downloader.database.deleteRecordWithId(taskId);
    return true;
  }

  Future<bool> _deleteSharedFile(String fileUri) async {
    try {
      return await _storageChannel.invokeMethod<bool>('deleteFile', {
            'uri': fileUri,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  void _onStatus(TaskStatusUpdate update) {
    _track(_emitStatus(update));
  }

  /// 记录在途事件处理的 Future，供 [dispose] 等待其收尾。
  void _track(Future<void> future) {
    _pendingWork.add(future);
    unawaited(
      future.then<void>(
        (_) {
          _pendingWork.remove(future);
        },
        onError: (Object error, StackTrace stackTrace) {
          _pendingWork.remove(future);
          unawaited(
            AppLogService.instance.error(
              error,
              stackTrace,
              component: 'download_event',
            ),
          );
        },
      ),
    );
  }

  /// 投递事件；事件流已关闭时静默丢弃，避免 "Cannot add new events after
  /// calling close" 从后台回调里冒出来。
  void _emit(DownloadPlatformEvent event) {
    if (_events.isClosed) {
      return;
    }
    _events.add(event);
  }

  Future<void> _emitStatus(TaskStatusUpdate update) async {
    final taskId = update.task.taskId;
    final state = _mapStatus(update.status);
    if (state == DownloadTaskState.complete) {
      if (!_finalizing.add(taskId)) {
        return;
      }
      try {
        await _finalizeCompletedTask(update.task);
      } finally {
        _finalizing.remove(taskId);
      }
      return;
    }
    final exception = update.exception;
    _emit(
      DownloadStatusEvent(
        taskId: taskId,
        state: state,
        errorMessage: exception == null ? null : displayErrorFor(exception),
      ),
    );
  }

  Future<void> _finalizeCompletedTask(Task task) async {
    final taskId = task.taskId;
    try {
      final Uri? finalUri;
      int? sourceBytes;
      if (task is UriDownloadTask) {
        finalUri = task.fileUri;
      } else if (task is DownloadTask) {
        if (!await ensureSharedStoragePermission()) {
          throw StateError('系统未授予公共下载目录写入权限。');
        }
        final sourceFile = File(await task.filePath());
        if (!await sourceFile.exists()) {
          // 私有目录里已经没有源文件：通常是上一次收尾已把文件移入公共目录，
          // 进程在删除插件记录之前被系统杀掉。此时无法再拿到公共目录的
          // content URI（DownloadTask 不保存它），只能如实告知用户去文件
          // 管理器确认，并清理残留记录，避免插件把它当成"被杀任务"重新下载
          // 一遍，在 Download/Flule34 里留下重复文件。
          await AppLogService.instance.warning(
            '下载收尾重入：私有目录已无源文件，清理残留记录；任务=$taskId',
            component: 'download_finalize',
          );
          await _downloader.database.deleteRecordWithId(taskId);
          _emit(
            DownloadStatusEvent(
              taskId: taskId,
              state: DownloadTaskState.failed,
              errorMessage:
                  '视频可能已保存到 Download/Flule34，但应用未能确认其位置，请在系统文件管理器中查看。',
            ),
          );
          return;
        }
        sourceBytes = await sourceFile.length();
        finalUri = await _downloader.uri.moveToSharedStorage(
          task,
          SharedStorage.downloads,
          directory: _publicDirectory,
          mimeType: 'video/mp4',
        );
      } else {
        finalUri = null;
      }
      if (finalUri == null) {
        throw StateError('无法将视频保存到 Download/Flule34。');
      }
      final inspection = await _inspectFinalizedFile(finalUri);
      await _publishCompleted(
        DownloadStatusEvent(
          taskId: taskId,
          state: DownloadTaskState.complete,
          filePath: finalUri.toString(),
          actualBytes: inspection.size ?? sourceBytes,
        ),
      );
      // 先让 App 侧落库，再删插件记录：顺序反过来会留下
      // "文件已在公共目录、App 里仍显示下载中" 的错位记录。
      await _downloader.database.deleteRecordWithId(taskId);
    } catch (error) {
      _emit(
        DownloadStatusEvent(
          taskId: taskId,
          state: DownloadTaskState.failed,
          errorMessage: redactSensitiveText(error),
        ),
      );
    }
  }

  /// 投递完成事件。注册了 [setCompletionSink] 时先等 App 侧落库；
  /// 落库失败则退回普通事件投递并记录原因，避免任务卡在插件数据库里。
  Future<void> _publishCompleted(DownloadStatusEvent event) async {
    final sink = _completionSink;
    if (sink == null) {
      _emit(event);
      return;
    }
    try {
      await sink(event);
    } on Object catch (error, stackTrace) {
      await AppLogService.instance.error(
        error,
        stackTrace,
        component: 'download_completion',
      );
      _emit(event);
    }
  }

  Future<DownloadFileInspection> _inspectFinalizedFile(Uri uri) async {
    var inspection = const DownloadFileInspection(
      exists: false,
      readable: false,
    );
    for (final delay in _mediaStoreInspectionDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      inspection = await inspectFile(uri.toString());
      if (inspection.exists && inspection.readable) {
        return inspection;
      }
    }
    return inspection;
  }

  void _onProgress(TaskProgressUpdate update) {
    final event = progressEventForUpdate(update);
    if (event != null) {
      _emit(event);
    }
  }

  @visibleForTesting
  static DownloadProgressEvent? progressEventForUpdate(
    TaskProgressUpdate update,
  ) {
    if (update.progress < 0) {
      return null;
    }
    final hasTotal = update.hasExpectedFileSize && update.expectedFileSize > 0;
    if (!hasTotal) {
      return null;
    }
    final progress = update.progress.clamp(0.0, 1.0);
    return DownloadProgressEvent(
      taskId: update.task.taskId,
      bytesDownloaded: (update.expectedFileSize * progress).round(),
      totalBytes: update.expectedFileSize,
    );
  }

  @visibleForTesting
  static String displayErrorFor(Object error) {
    final message = redactSensitiveText(error);
    if (RegExp(
      r'\b(?:job)?cancel(?:l)?(?:ed|ing|ation)\b|\{cancelling\}',
      caseSensitive: false,
    ).hasMatch(message)) {
      return '下载任务被系统中断，请重试。';
    }
    if (RegExp(
      r'connection reset|socketexception|timed?\s*out|network is unreachable|broken pipe',
      caseSensitive: false,
    ).hasMatch(message)) {
      return '网络连接中断，请检查网络后重试。';
    }
    return message;
  }

  DownloadTaskState _mapStatus(TaskStatus status) => switch (status) {
    TaskStatus.enqueued => DownloadTaskState.queued,
    TaskStatus.running => DownloadTaskState.running,
    TaskStatus.complete => DownloadTaskState.complete,
    TaskStatus.notFound => DownloadTaskState.notFound,
    TaskStatus.failed => DownloadTaskState.failed,
    TaskStatus.canceled => DownloadTaskState.canceled,
    TaskStatus.waitingToRetry => DownloadTaskState.waitingToRetry,
    TaskStatus.paused => DownloadTaskState.paused,
  };

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _completionSink = null;
    _rescheduleTimer?.cancel();
    _downloader.unregisterCallbacks(group: _group);
    // 先等在途的收尾跑完（移入公共目录、落库、删记录），再关流；
    // 否则后台回调可能在 close 之后继续 add，抛
    // "Bad state: Cannot add new events after calling close"。
    if (_pendingWork.isNotEmpty) {
      try {
        await Future.wait(
          List<Future<void>>.of(_pendingWork),
        ).timeout(const Duration(seconds: 10));
      } on Object {
        // 收尾超时或失败都不能阻止释放。
      }
    }
    await _events.close();
  }
}
