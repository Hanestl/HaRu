import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flule34/app/providers.dart';
import 'package:flule34/features/settings/data/apk_installer.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/data/app_update_downloader.dart';
import 'package:flule34/features/settings/data/app_update_prompt_store.dart';
import 'package:flule34/features/settings/data/app_update_service.dart';
import 'package:flule34/features/settings/presentation/app_update_flow.dart';
import 'package:flule34/features/settings/presentation/support_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ApkInstaller.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Widget probeApp({
    required List<Override> overrides,
    required void Function(BuildContext context, WidgetRef ref) onReady,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => onReady(context, ref),
                  child: const Text('run'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('启动检查发现新版本时弹窗，同一版本只提醒一次', (tester) async {
    final store = _MemoryVersionStore();
    final overrides = _overrides(service: _buildService(), store: store);

    await tester.pumpWidget(
      probeApp(
        overrides: overrides,
        onReady: (context, ref) => checkForUpdateOnStartup(context, ref),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('一键更新'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(store.value, '2.5.0');

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本'), findsNothing);

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('一键更新下载安装包并调起系统安装器', (tester) async {
    final installs = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'canInstallPackages':
          return true;
        case 'installApk':
          installs.add(call.arguments);
          return 'started';
      }
      return null;
    });
    final downloader = _FakeDownloader(payloadLength: 32);

    final release = _release(sizeBytes: 32);
    final overrides = _overrides(
      service: _buildService(),
      store: _MemoryVersionStore(),
      downloader: downloader,
    );

    await tester.pumpWidget(
      probeApp(
        overrides: overrides,
        onReady: (context, ref) =>
            showUpdateAvailableDialog(context, ref, release),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一键更新'));
    await tester.pumpAndSettle();

    expect(find.text('正在下载更新包'), findsNothing);
    expect(downloader.requests, hasLength(1));
    expect(installs, hasLength(1));
    final installedPath = (installs.single as Map)['path'] as String;
    expect(installedPath, endsWith('HaRu-2.5.0-arm64-v8a.apk'));
  });

  testWidgets('下载校验失败时提示错误', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canInstallPackages') {
        return true;
      }
      return null;
    });
    final downloader = _FakeDownloader(
      failure: const AppUpdateDownloadException('更新包校验失败，请重试。'),
    );

    final release = _release(sizeBytes: 8);
    final overrides = _overrides(
      service: _buildService(),
      store: _MemoryVersionStore(),
      downloader: downloader,
    );

    await tester.pumpWidget(
      probeApp(
        overrides: overrides,
        onReady: (context, ref) =>
            showUpdateAvailableDialog(context, ref, release),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一键更新'));
    await tester.pumpAndSettle();

    expect(find.text('更新包校验失败，请重试。'), findsOneWidget);
  });

  testWidgets('没有安装权限时先引导授权，取消后不下载', (tester) async {
    var installRequested = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'canInstallPackages':
          return false;
        case 'installApk':
          installRequested = true;
          return 'started';
      }
      return null;
    });
    final downloader = _FakeDownloader();

    final release = _release();
    final overrides = _overrides(
      service: _buildService(),
      store: _MemoryVersionStore(),
      downloader: downloader,
    );

    await tester.pumpWidget(
      probeApp(
        overrides: overrides,
        onReady: (context, ref) =>
            showUpdateAvailableDialog(context, ref, release),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一键更新'));
    await tester.pumpAndSettle();

    expect(find.text('需要安装权限'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('需要安装权限'), findsNothing);
    expect(installRequested, isFalse);
    expect(downloader.requests, isEmpty);
  });

  testWidgets('检查更新页在发现新版本时提供一键更新按钮', (tester) async {
    final overrides = _overrides(
      service: _buildService(),
      store: _MemoryVersionStore(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: AppUpdatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 2.5.0。'), findsOneWidget);
    expect(find.text('一键更新'), findsOneWidget);
    expect(find.text('打开 GitHub 发布页'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });
}

List<Override> _overrides({
  required AppUpdateService service,
  required _MemoryVersionStore store,
  AppUpdateDownloaderApi? downloader,
}) {
  return [
    appUpdateServiceProvider.overrideWithValue(service),
    appSettingsRepositoryProvider.overrideWithValue(
      AppSettingsRepository(_MemorySettingsStore()),
    ),
    updatePromptStoreProvider.overrideWithValue(UpdatePromptStore(store)),
    apkInstallerProvider.overrideWithValue(ApkInstaller()),
    if (downloader != null)
      appUpdateDownloaderProvider.overrideWithValue(downloader),
  ];
}

AppRelease _release({int? sizeBytes, Uri? apkUri}) {
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
    apkSizeBytes: sizeBytes,
  );
}

AppUpdateService _buildService() {
  final dio = Dio()
    ..httpClientAdapter = _JsonAdapter([
      {
        'tag_name': 'v2.5.0',
        'name': 'HaRu 2.5.0',
        'html_url': 'https://github.com/example/releases/tag/v2.5.0',
        'prerelease': false,
        'draft': false,
        'body': '修复若干问题',
        'assets': [
          {
            'name': 'HaRu-2.5.0-arm64-v8a.apk',
            'browser_download_url':
                'https://github.com/example/releases/download/v2.5.0/HaRu.apk',
          },
        ],
      },
    ]);
  return AppUpdateService(
    client: dio,
    updateApiUri: Uri.parse('https://api.github.com/repos/example/releases'),
    packageInfoLoader: () async => PackageInfo(
      appName: 'HaRu',
      packageName: 'com.hanestl.flule34',
      version: '2.4.0',
      buildNumber: '47',
    ),
    abiLoader: () async => const ['arm64-v8a'],
  );
}

/// 测试用下载器：不做真实网络/文件 IO，按需返回文件或抛出错误。
final class _FakeDownloader implements AppUpdateDownloaderApi {
  _FakeDownloader({this.payloadLength = 0, this.failure});

  final int payloadLength;
  final Object? failure;
  final List<AppRelease> requests = [];

  @override
  Future<File> download({
    required AppRelease release,
    AppUpdateProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    requests.add(release);
    final error = failure;
    if (error != null) {
      throw error;
    }
    onProgress?.call(payloadLength, payloadLength);
    return File(
      'updates${Platform.pathSeparator}HaRu-${release.version}-arm64-v8a.apk',
    );
  }

  @override
  void close() {}
}

final class _MemoryVersionStore implements UpdateNotifiedVersionStore {
  String? value;

  @override
  Future<String?> readNotifiedVersion() async => value;

  @override
  Future<void> writeNotifiedVersion(String version) async {
    value = version;
  }
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

final class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.value);

  final Object value;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
