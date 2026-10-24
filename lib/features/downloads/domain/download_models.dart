enum DownloadTaskState {
  queued,
  running,
  complete,
  notFound,
  failed,
  canceled,
  waitingToRetry,
  paused;

  String get storageValue => switch (this) {
    DownloadTaskState.queued => 'queued',
    DownloadTaskState.running => 'running',
    DownloadTaskState.complete => 'complete',
    DownloadTaskState.notFound => 'not_found',
    DownloadTaskState.failed => 'failed',
    DownloadTaskState.canceled => 'canceled',
    DownloadTaskState.waitingToRetry => 'waiting_to_retry',
    DownloadTaskState.paused => 'paused',
  };

  bool get isActive => switch (this) {
    DownloadTaskState.queued ||
    DownloadTaskState.running ||
    DownloadTaskState.waitingToRetry ||
    DownloadTaskState.paused => true,
    _ => false,
  };
}

final class DownloadRequest {
  const DownloadRequest({
    required this.id,
    required this.url,
    required this.filename,
    required this.displayName,
    required this.metadata,
    required this.headers,
    this.requiresWiFi = false,
  });

  final String id;
  final String url;
  final String filename;
  final String displayName;
  final String metadata;
  final Map<String, String> headers;
  final bool requiresWiFi;
}

final class DownloadFileInspection {
  const DownloadFileInspection({
    required this.exists,
    required this.readable,
    this.name,
    this.size,
  });

  final bool exists;
  final bool readable;
  final String? name;
  final int? size;
}

final class DownloadFileValidation {
  const DownloadFileValidation({
    required this.valid,
    required this.exists,
    required this.readable,
    this.actualName,
    this.actualBytes,
    this.reason,
  });

  const DownloadFileValidation.notApplicable()
    : valid = true,
      exists = false,
      readable = false,
      actualName = null,
      actualBytes = null,
      reason = null;

  final bool valid;
  final bool exists;
  final bool readable;
  final String? actualName;
  final int? actualBytes;
  final String? reason;
}

enum DownloadBulkDeleteMode { recordsOnly, invalidRecords, filesAndRecords }

final class DownloadBulkDeleteResult {
  const DownloadBulkDeleteResult({
    required this.matched,
    required this.deleted,
    required this.failed,
  });

  final int matched;
  final int deleted;
  final int failed;
}

sealed class DownloadPlatformEvent {
  const DownloadPlatformEvent({required this.taskId});

  final String taskId;
}

final class DownloadStatusEvent extends DownloadPlatformEvent {
  const DownloadStatusEvent({
    required super.taskId,
    required this.state,
    this.filePath,
    this.actualBytes,
    this.errorMessage,
  });

  final DownloadTaskState state;
  final String? filePath;
  final int? actualBytes;
  final String? errorMessage;
}

final class DownloadProgressEvent extends DownloadPlatformEvent {
  const DownloadProgressEvent({
    required super.taskId,
    required this.bytesDownloaded,
    this.totalBytes,
  });

  final int bytesDownloaded;
  final int? totalBytes;
}

abstract interface class DownloadPlatformService {
  Stream<DownloadPlatformEvent> get events;

  Future<void> initialize();

  Future<void> setMaxConcurrent(int value);

  Future<bool> ensureNotificationPermission();

  Future<bool> ensureSharedStoragePermission();

  Future<bool> enqueue(DownloadRequest request);

  Future<bool> taskExists(String taskId);

  Future<bool> pause(String taskId);

  Future<bool> resume(String taskId);

  Future<bool> cancel(String taskId);

  Future<bool> openFile(String fileUri);

  Future<DownloadFileInspection> inspectFile(String fileUri);

  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  });

  /// 注册"完成事件已落库"的回调。
  ///
  /// 平台服务把下载结果移入公共目录后会先调用它，等 App 侧把完成态写进
  /// 数据库，再删除插件侧的任务记录。这样即使进程在这两步之间被系统杀死，
  /// 也不会出现"文件已在 Download/Flule34，App 里却仍显示下载中"的错位。
  ///
  /// 传 null 表示取消注册，此时完成事件改走 [events] 普通投递。
  void setCompletionSink(
    Future<void> Function(DownloadStatusEvent event)? sink,
  );

  /// 停止投递事件并释放底层资源。
  ///
  /// 返回的 Future 完成时，在途的收尾工作（移入公共目录、落库）已经结束，
  /// 事件流也已关闭。调用方应先 await 它，再取消自己的事件订阅。
  Future<void> dispose();
}
