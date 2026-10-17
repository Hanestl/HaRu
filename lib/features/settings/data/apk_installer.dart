import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum ApkInstallResult { started, permissionRequired }

/// 系统安装器回调的安装结果。
final class ApkInstallOutcome {
  const ApkInstallOutcome({required this.success, required this.message});

  final bool success;
  final String message;
}

final class ApkInstallerException implements Exception {
  const ApkInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 调起 Android 系统安装器安装已下载的更新包。
///
/// 安装通过 PackageInstaller 会话完成，系统直接进入安装确认页，
/// 不会出现第三方应用争夺 package-archive 的「打开方式」选择器。
final class ApkInstaller {
  ApkInstaller({this.channel = const MethodChannel(channelName)});

  static const channelName = 'com.hanestl.flule34/updater';

  final MethodChannel channel;

  StreamController<ApkInstallOutcome>? _outcomes;
  bool _listening = false;

  /// 系统安装器完成安装（或失败/取消）后的结果流。
  ///
  /// 成功安装时本进程会被系统终止，因此这里主要覆盖失败与取消场景。
  Stream<ApkInstallOutcome> get outcomes {
    _outcomes ??= StreamController<ApkInstallOutcome>.broadcast();
    if (!_listening) {
      _listening = true;
      channel.setMethodCallHandler(_handlePlatformCall);
    }
    return _outcomes!.stream;
  }

  Future<Object?> _handlePlatformCall(MethodCall call) async {
    if (call.method != 'installResult') {
      return null;
    }
    final arguments = call.arguments;
    final status = arguments is Map ? arguments['status'] : null;
    final code = status is int ? status : -1;
    _outcomes?.add(
      ApkInstallOutcome(
        success: code == _statusSuccess,
        message: describeInstallStatus(code),
      ),
    );
    return null;
  }

  /// 把 `PackageInstaller` 的状态码翻译成给用户看的提示。
  static String describeInstallStatus(int status) {
    return switch (status) {
      _statusSuccess => '更新包已安装完成。',
      2 => '系统阻止了本次安装，请检查「安装未知应用」权限。',
      3 => '已取消安装。',
      4 => '更新包无效或已损坏，请重新下载。',
      5 => '安装包签名与已安装版本不一致，无法覆盖安装，请前往 GitHub 手动下载安装。',
      6 => '设备存储空间不足，无法安装更新包。',
      7 => '更新包与当前系统不兼容。',
      8 => '安装超时，请稍后重试。',
      _ => '安装更新包失败，请稍后重试。',
    };
  }

  /// 是否已获得「安装未知应用」权限；低版本 Android 默认允许。
  Future<bool> canInstallPackages() async {
    try {
      return await channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 打开系统的「安装未知应用」授权页。
  Future<void> openInstallSettings() async {
    try {
      await channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // 设置页打开失败时由调用方在返回后重新检查权限。
    } on MissingPluginException {
      // 桌面等非 Android 平台没有系统安装器，忽略即可。
    }
  }

  Future<ApkInstallResult> install(File file) async {
    try {
      final status = await channel.invokeMethod<String>('installApk', {
        'path': file.path,
      });
      return status == 'started'
          ? ApkInstallResult.started
          : ApkInstallResult.permissionRequired;
    } on PlatformException catch (error) {
      throw ApkInstallerException(error.message ?? '无法启动系统安装器，请稍后重试。');
    } on MissingPluginException {
      throw const ApkInstallerException('当前设备不支持自动安装，请前往 GitHub 手动下载安装包。');
    }
  }

  static const _statusSuccess = 0;
}
