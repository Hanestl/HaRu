import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_service.dart';

typedef UpdatesDirectoryProvider = Future<Directory> Function();
typedef AppUpdateProgressCallback =
    void Function(int receivedBytes, int? totalBytes);

final class AppUpdateDownloadException implements Exception {
  const AppUpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 更新包下载能力；抽成接口便于测试替换。
abstract interface class AppUpdateDownloaderApi {
  Future<File> download({
    required AppRelease release,
    AppUpdateProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  void close();
}

/// 下载 GitHub Release 中的 arm64 APK，边下边算 SHA-256。
///
/// 下载到应用缓存目录，安装完成后由系统安装器读取；无需存储权限。
final class AppUpdateDownloader implements AppUpdateDownloaderApi {
  AppUpdateDownloader({
    Dio? client,
    UpdatesDirectoryProvider? updatesDirectoryProvider,
    this.idleTimeout = const Duration(seconds: 60),
  }) : _client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               followRedirects: true,
               maxRedirects: 5,
               headers: const {
                 'Accept': 'application/octet-stream',
                 'User-Agent': 'HaRu Android updater',
               },
             ),
           ),
       _ownsClient = client == null,
       _updatesDirectoryProvider =
           updatesDirectoryProvider ?? _defaultUpdatesDirectory;

  static const _maxRedirects = 5;

  final Dio _client;
  final bool _ownsClient;
  final UpdatesDirectoryProvider _updatesDirectoryProvider;

  /// 连续多久没有收到数据就判定为超时。
  final Duration idleTimeout;

  @override
  void close() {
    if (_ownsClient) {
      _client.close(force: true);
    }
  }

  @override
  Future<File> download({
    required AppRelease release,
    AppUpdateProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final apkUri = release.apkUri;
    if (apkUri == null) {
      throw const AppUpdateDownloadException('该版本没有可下载的安装包。');
    }
    final directory = await _updatesDirectoryProvider();
    await directory.create(recursive: true);
    final file = File(_targetPath(directory, release.version));
    await _cleanup(directory, keep: file);
    final partial = File('${file.path}.part');
    IOSink? sink;
    try {
      final response = await _client.getUri<ResponseBody>(
        apkUri,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: _maxRedirects,
          headers: const {'Accept': 'application/octet-stream'},
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const AppUpdateDownloadException('更新包下载失败，请稍后重试。');
      }
      final declaredTotal =
          release.apkSizeBytes ??
          _parseLength(response.headers.value(Headers.contentLengthHeader));
      final collector = _DigestCollector();
      final digestInput = sha256.startChunkedConversion(collector);
      var received = 0;
      sink = partial.openWrite();
      try {
        final stream = body.stream.timeout(
          idleTimeout,
          onTimeout: (eventSink) {
            eventSink.addError(
              const AppUpdateDownloadException('下载更新包超时，请检查网络后重试。'),
            );
            eventSink.close();
          },
        );
        await for (final chunk in stream) {
          if (cancelToken != null && cancelToken.isCancelled) {
            throw const AppUpdateDownloadException('已取消下载更新包。');
          }
          received += chunk.length;
          digestInput.add(chunk);
          sink.add(chunk);
          onProgress?.call(received, declaredTotal);
        }
        await sink.flush();
        await sink.close();
        sink = null;
        digestInput.close();
      } finally {
        if (sink != null) {
          await sink.close();
          sink = null;
        }
      }
      if (cancelToken != null && cancelToken.isCancelled) {
        throw const AppUpdateDownloadException('已取消下载更新包。');
      }
      final actualSize = await partial.length();
      if (actualSize != received) {
        throw const AppUpdateDownloadException('更新包保存不完整，请重试。');
      }
      if (declaredTotal != null && received != declaredTotal) {
        throw const AppUpdateDownloadException('更新包大小校验失败，请重试。');
      }
      final digest = collector.value;
      if (digest == null) {
        throw const AppUpdateDownloadException('更新包校验失败，请重试。');
      }
      final expectedSha256 = release.apkSha256;
      if (expectedSha256 != null &&
          digest.toString().toLowerCase() != expectedSha256.toLowerCase()) {
        throw const AppUpdateDownloadException('更新包校验失败，请重试。');
      }
      await _replaceWithPartial(partial, file);
      return file;
    } on AppUpdateDownloadException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) ||
          (cancelToken != null && cancelToken.isCancelled)) {
        throw const AppUpdateDownloadException('已取消下载更新包。');
      }
      throw AppUpdateDownloadException(_dioMessage(error));
    } on FileSystemException {
      throw const AppUpdateDownloadException('写入更新包失败，请检查设备存储空间后重试。');
    } finally {
      if (sink != null) {
        await sink.close();
      }
      await _deleteIfExists(partial);
    }
  }

  static Future<Directory> _defaultUpdatesDirectory() async {
    final cache = await getApplicationCacheDirectory();
    return Directory('${cache.path}${Platform.pathSeparator}updates');
  }

  static String _targetPath(Directory directory, String version) {
    final safeVersion = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${directory.path}${Platform.pathSeparator}HaRu-$safeVersion-arm64-v8a.apk';
  }

  static Future<void> _cleanup(
    Directory directory, {
    required File keep,
  }) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is! File || entity.path == keep.path) {
          continue;
        }
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('HaRu-') &&
            (name.endsWith('.apk') || name.endsWith('.part'))) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // 清理旧安装包失败不影响本次更新。
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 删除临时文件失败不会阻塞下载，下次更新会再次清理。
    }
  }

  /// 把 `.part` 临时文件替换成正式安装包。
  ///
  /// Windows 上杀毒软件/索引器可能短暂占用刚写完的临时文件，
  /// 导致重命名报“拒绝访问”，这里做少量重试。
  static Future<void> _replaceWithPartial(File partial, File target) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _deleteIfExists(target);
        await partial.rename(target.path);
        return;
      } on FileSystemException catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    throw lastError!;
  }

  static int? _parseLength(String? value) {
    final length = int.tryParse(value?.trim() ?? '');
    return length != null && length > 0 ? length : null;
  }

  static String _dioMessage(DioException error) {
    if (error.response?.statusCode case final status? when status >= 400) {
      return '下载更新包失败（HTTP $status），请稍后重试。';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => '下载更新包超时，请检查网络后重试。',
      DioExceptionType.connectionError => '无法连接 GitHub，请检查网络后重试。',
      _ => '下载更新包失败，请稍后重试。',
    };
  }
}

final class _DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
