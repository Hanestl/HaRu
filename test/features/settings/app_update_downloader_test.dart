import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flule34/features/settings/data/app_update_downloader.dart';
import 'package:flule34/features/settings/data/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('haru_update_download_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  AppUpdateDownloader downloaderFor(Uint8List payload, {int? declaredLength}) {
    final dio = Dio()
      ..httpClientAdapter = _BytesAdapter(
        payload,
        declaredLength: declaredLength,
      );
    return AppUpdateDownloader(
      client: dio,
      updatesDirectoryProvider: () async => _updatesDirectory(tempDir),
    );
  }

  AppRelease release({String? sha256Value, int? sizeBytes, Uri? apkUri}) {
    return AppRelease(
      version: '2.5.0',
      title: 'HaRu 2.5.0',
      pageUri: Uri.parse('https://github.com/example/releases/tag/v2.5.0'),
      prerelease: false,
      apkUri:
          apkUri ??
          Uri.parse(
            'https://github.com/example/releases/download/v2.5.0/'
            'HaRu-2.5.0-arm64-v8a.apk',
          ),
      apkSha256: sha256Value,
      apkSizeBytes: sizeBytes,
    );
  }

  test('下载成功时校验 SHA-256 并写入 updates 目录', () async {
    final payload = Uint8List.fromList(
      List<int>.generate(2048, (index) => index % 251),
    );
    final received = <int>[];
    final file = await downloaderFor(payload).download(
      release: release(
        sha256Value: sha256.convert(payload).toString(),
        sizeBytes: payload.length,
      ),
      onProgress: (bytes, total) {
        received.add(bytes);
        expect(total, payload.length);
      },
    );

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('HaRu-2.5.0-arm64-v8a.apk'));
    expect(file.parent.path, endsWith('updates'));
    expect(await file.readAsBytes(), payload);
    expect(received, isNotEmpty);
    expect(received.last, payload.length);
    expect(
      await _updatesDirectory(
        tempDir,
      ).list().where((entity) => entity.path.endsWith('.part')).length,
      0,
    );
  });

  test('哈希不匹配时报错且不留下安装包', () async {
    final payload = Uint8List.fromList([1, 2, 3, 4]);

    await expectLater(
      downloaderFor(payload).download(release: release(sha256Value: 'a' * 64)),
      throwsA(
        isA<AppUpdateDownloadException>().having(
          (error) => error.message,
          'message',
          contains('校验失败'),
        ),
      ),
    );

    final leftovers = await _updatesDirectory(tempDir).list().toList();
    expect(leftovers.where((entity) => entity.path.endsWith('.apk')), isEmpty);
    expect(leftovers.where((entity) => entity.path.endsWith('.part')), isEmpty);
  });

  test('声明大小与实际不符时给出可读错误', () async {
    final payload = Uint8List.fromList(List<int>.filled(32, 7));

    await expectLater(
      downloaderFor(
        payload,
      ).download(release: release(sizeBytes: payload.length + 1)),
      throwsA(
        isA<AppUpdateDownloadException>().having(
          (error) => error.message,
          'message',
          contains('大小校验失败'),
        ),
      ),
    );
  });

  test('缺少 APK 地址时给出可读错误', () async {
    final downloader = downloaderFor(Uint8List.fromList([1]));

    await expectLater(
      downloader.download(
        release: AppRelease(
          version: '2.5.0',
          title: 'HaRu 2.5.0',
          pageUri: Uri.parse('https://github.com/example/releases/tag/v2.5.0'),
          prerelease: false,
        ),
      ),
      throwsA(
        isA<AppUpdateDownloadException>().having(
          (error) => error.message,
          'message',
          contains('没有可下载的安装包'),
        ),
      ),
    );
  });

  test('取消下载时抛出已取消错误', () async {
    final payload = Uint8List.fromList(List<int>.filled(64, 1));
    final cancelToken = CancelToken();

    final future = downloaderFor(
      payload,
    ).download(release: release(), cancelToken: cancelToken);
    cancelToken.cancel('user_cancelled');

    await expectLater(
      future,
      throwsA(
        isA<AppUpdateDownloadException>().having(
          (error) => error.message,
          'message',
          contains('取消'),
        ),
      ),
    );
  });

  test('下载前清理旧版本安装包但保留无关文件', () async {
    final directory = _updatesDirectory(tempDir);
    await directory.create(recursive: true);
    final stale = File(
      '${directory.path}${Platform.pathSeparator}HaRu-2.4.0-arm64-v8a.apk',
    );
    await stale.writeAsBytes([9, 9]);
    final unrelated = File(
      '${directory.path}${Platform.pathSeparator}keep.txt',
    );
    await unrelated.writeAsBytes([1]);

    final payload = Uint8List.fromList([5, 5, 5]);
    final file = await downloaderFor(payload).download(release: release());

    expect(await stale.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    expect(await file.exists(), isTrue);
  });
}

Directory _updatesDirectory(Directory root) {
  return Directory('${root.path}${Platform.pathSeparator}updates');
}

final class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.payload, {this.declaredLength});

  final Uint8List payload;
  final int? declaredLength;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final head = payload.sublist(0, payload.length ~/ 2);
    final tail = payload.sublist(payload.length ~/ 2);
    return ResponseBody(
      Stream<Uint8List>.fromIterable([head, tail]),
      200,
      headers: {
        Headers.contentLengthHeader: ['${declaredLength ?? payload.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
