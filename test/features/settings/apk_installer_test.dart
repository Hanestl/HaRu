import 'dart:io';

import 'package:flule34/features/settings/data/apk_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(ApkInstaller.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('查询安装权限时透传原生结果', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'canInstallPackages');
      return true;
    });
    expect(await ApkInstaller().canInstallPackages(), isTrue);

    messenger.setMockMethodCallHandler(channel, (call) async => false);
    expect(await ApkInstaller().canInstallPackages(), isFalse);
  });

  test('原生层异常时按无权限处理', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });

    expect(await ApkInstaller().canInstallPackages(), isFalse);
  });

  test('安装时把安装包路径透传给原生层', () async {
    String? method;
    Object? arguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      method = call.method;
      arguments = call.arguments;
      return 'started';
    });

    final result = await ApkInstaller().install(
      File('cache/updates/HaRu-2.5.0-arm64-v8a.apk'),
    );

    expect(result, ApkInstallResult.started);
    expect(method, 'installApk');
    expect(arguments, isA<Map<Object?, Object?>>());
    expect((arguments as Map)['path'], endsWith('HaRu-2.5.0-arm64-v8a.apk'));
  });

  test('原生层提示需要授权时返回 permissionRequired', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => 'permissionRequired',
    );

    final result = await ApkInstaller().install(File('a.apk'));

    expect(result, ApkInstallResult.permissionRequired);
  });

  test('原生层报错时抛出带消息的 ApkInstallerException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'INVALID_PATH', message: '安装包路径不合法或文件不存在');
    });

    await expectLater(
      ApkInstaller().install(File('a.apk')),
      throwsA(
        isA<ApkInstallerException>().having(
          (error) => error.message,
          'message',
          '安装包路径不合法或文件不存在',
        ),
      ),
    );
  });

  test('系统设置入口打开失败时不抛出异常', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });

    await expectLater(ApkInstaller().openInstallSettings(), completes);
  });

  test('把系统安装状态码翻译成可读提示', () {
    expect(ApkInstaller.describeInstallStatus(0), '更新包已安装完成。');
    expect(ApkInstaller.describeInstallStatus(3), '已取消安装。');
    expect(ApkInstaller.describeInstallStatus(5), contains('签名'));
    expect(ApkInstaller.describeInstallStatus(6), contains('存储'));
    expect(ApkInstaller.describeInstallStatus(42), '安装更新包失败，请稍后重试。');
  });

  test('PackageInstaller 回调失败状态时通过 outcomes 广播结果', () async {
    final installer = ApkInstaller();
    final expectation = expectLater(
      installer.outcomes,
      emits(
        isA<ApkInstallOutcome>()
            .having((outcome) => outcome.success, 'success', isFalse)
            .having((outcome) => outcome.message, 'message', contains('签名')),
      ),
    );

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('installResult', {
          'status': 5,
          'message': 'INSTALL_FAILED_CONFLICTING_PROVIDER',
        }),
      ),
      (_) {},
    );

    await expectation;
  });
}
