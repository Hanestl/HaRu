import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/logging/app_log_service.dart';
import '../../../core/services/external_link_service.dart';
import '../../../shared/error_view.dart';
import '../data/apk_installer.dart';
import '../data/app_update_downloader.dart';
import '../data/app_update_service.dart';

/// 启动时静默检查更新的最长等待时间；超时直接放弃本次检查。
const Duration appUpdateCheckTimeout = Duration(seconds: 10);

/// 等待用户从系统「安装未知应用」设置页返回的最长时间。
const Duration installPermissionWait = Duration(minutes: 2);

/// 每次启动后调用一次：静默检查更新，发现新版本时弹窗提示。
///
/// 任何失败（未配置更新源、网络超时、解析异常）都不会打扰用户。
Future<void> checkForUpdateOnStartup(
  BuildContext context,
  WidgetRef ref,
) async {
  // 未配置更新源的构建（本地调试、测试包）直接跳过，保持静默。
  final service = ref.read(appUpdateServiceProvider);
  if (service.configuredSource == null) {
    return;
  }
  final AppUpdateResult result;
  try {
    final channel = ref
        .read(appSettingsRepositoryProvider)
        .settings
        .updateChannel;
    result = await service.check(channel).timeout(appUpdateCheckTimeout);
  } on TimeoutException {
    return;
  } on Object catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '启动更新检查失败（忽略）：$error',
        component: 'app_update',
      ),
    );
    return;
  }
  final release = result.release;
  if (result.status != AppUpdateStatus.updateAvailable || release == null) {
    return;
  }
  final store = ref.read(updatePromptStoreProvider);
  try {
    if (await store.notifiedVersion() == release.version) {
      return;
    }
    await store.markNotified(release.version);
  } on Object catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '记录更新通知状态失败（忽略）：$error',
        component: 'app_update',
      ),
    );
  }
  if (!context.mounted) {
    return;
  }
  await showUpdateAvailableDialog(context, ref, release);
}

/// 展示新版本弹窗；选择「一键更新」后继续下载并调起系统安装器。
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {
  final choice = await showDialog<_UpdateChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const AppText('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText('新版本 ${release.version} 已发布，是否立即下载并安装？'),
              if (release.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                AppText(
                  '更新说明',
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  release.notes!,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(_UpdateChoice.dismiss);
            },
            child: const AppText('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(_UpdateChoice.install);
            },
            child: const AppText('一键更新'),
          ),
        ],
      );
    },
  );
  if (choice == _UpdateChoice.install && context.mounted) {
    await startAppUpdate(context, ref, release);
  }
}

/// 一键更新：下载最新安装包并调起系统安装器覆盖安装。
Future<void> startAppUpdate(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {
  if (!release.supportsOneTapUpdate) {
    await _openReleasePage(context, release);
    if (context.mounted) {
      _showMessage(context, '该版本没有可下载的安装包，已打开 GitHub 发布页。');
    }
    return;
  }
  final installer = ref.read(apkInstallerProvider);
  if (!await _ensureInstallPermission(context, installer)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final downloader = ref.read(appUpdateDownloaderProvider);
  final outcome = await showDialog<_DownloadOutcome>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return _DownloadProgressDialog(
        release: release,
        download: (onProgress, cancelToken) {
          return downloader.download(
            release: release,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        },
      );
    },
  );
  switch (outcome) {
    case _DownloadSucceeded(:final file):
      // PackageInstaller 会话安装完成后系统会回调结果；成功时进程通常已被
      // 系统终止，这里主要覆盖取消、签名冲突、存储不足等失败场景。
      // 结果流是应用级广播流，同一次安装可能回调多次：只处理第一条并立即退订。
      // 不退订的话，每次"一键更新"都会再挂一个监听，后续安装结果会重复弹提示，
      // 且监听闭包会一直持有旧页面的 context。
      late final StreamSubscription<ApkInstallOutcome> outcomeSubscription;
      outcomeSubscription = installer.outcomes.listen((result) {
        unawaited(outcomeSubscription.cancel());
        if (!result.success && context.mounted) {
          _showMessage(context, result.message);
        }
      });
      try {
        final installResult = await installer.install(file);
        if (installResult == ApkInstallResult.permissionRequired) {
          await outcomeSubscription.cancel();
          if (context.mounted) {
            _showMessage(context, '尚未开启安装权限，请稍后重试。');
          }
        }
      } on ApkInstallerException catch (error) {
        await outcomeSubscription.cancel();
        if (context.mounted) {
          _showMessage(context, error.message);
        }
      } on Object catch (error) {
        await outcomeSubscription.cancel();
        if (context.mounted) {
          _showMessage(context, '无法启动系统安装器：${friendlyErrorMessage(error)}');
        }
      }
    case _DownloadFailed(:final message):
      if (context.mounted) {
        _showMessage(context, message);
      }
    case _DownloadCancelled():
      break;
    case null:
      break;
  }
}

Future<bool> _ensureInstallPermission(
  BuildContext context,
  ApkInstaller installer,
) async {
  if (await installer.canInstallPackages()) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const AppText('需要安装权限'),
        content: const AppText('自动安装更新包需要「安装未知应用」权限。请在系统设置中允许 HaRu 安装应用后返回。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const AppText('去设置'),
          ),
        ],
      );
    },
  );
  if (openSettings != true || !context.mounted) {
    return false;
  }
  await installer.openInstallSettings();
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) {
        resumed.complete();
      }
    },
  );
  try {
    await resumed.future.timeout(installPermissionWait);
  } on TimeoutException {
    listener.dispose();
    return false;
  }
  listener.dispose();
  final granted = await installer.canInstallPackages();
  if (!granted && context.mounted) {
    _showMessage(context, '尚未开启安装权限，请稍后重试。');
  }
  return granted;
}

Future<void> _openReleasePage(BuildContext context, AppRelease release) async {
  try {
    await ExternalLinkService.open(release.pageUri);
  } on Object catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '打开更新发布页失败：$error；URI=${release.pageUri}',
        component: 'app_update',
      ),
    );
    if (context.mounted) {
      _showMessage(context, friendlyErrorMessage(error));
    }
  }
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));
}

enum _UpdateChoice { dismiss, install }

sealed class _DownloadOutcome {
  const _DownloadOutcome();
}

final class _DownloadSucceeded extends _DownloadOutcome {
  const _DownloadSucceeded(this.file);

  final File file;
}

final class _DownloadFailed extends _DownloadOutcome {
  const _DownloadFailed(this.message);

  final String message;
}

final class _DownloadCancelled extends _DownloadOutcome {
  const _DownloadCancelled();
}

typedef _DownloadCallback =
    Future<File> Function(
      AppUpdateProgressCallback onProgress,
      CancelToken cancelToken,
    );

class _DownloadProgressDialog extends StatefulWidget {
  const _DownloadProgressDialog({
    required this.release,
    required this.download,
  });

  final AppRelease release;
  final _DownloadCallback download;

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  final ValueNotifier<({int received, int? total})> _progress = ValueNotifier((
    received: 0,
    total: null,
  ));
  final CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final file = await widget.download((received, total) {
        _progress.value = (received: received, total: total);
      }, _cancelToken);
      if (mounted) {
        Navigator.of(context).pop(_DownloadSucceeded(file));
      }
    } on AppUpdateDownloadException catch (error) {
      if (!mounted) {
        return;
      }
      if (_cancelToken.isCancelled) {
        Navigator.of(context).pop(const _DownloadCancelled());
      } else {
        Navigator.of(context).pop(_DownloadFailed(error.message));
      }
    } on Object catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_DownloadFailed(friendlyErrorMessage(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const AppText('正在下载更新包'),
        content: ValueListenableBuilder<({int received, int? total})>(
          valueListenable: _progress,
          builder: (context, progress, _) {
            final total = progress.total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: total != null && total > 0
                      ? (progress.received / total).clamp(0, 1)
                      : null,
                ),
                const SizedBox(height: 12),
                AppText(
                  total != null && total > 0
                      ? '已下载 ${_formatBytes(progress.received)} / ${_formatBytes(total)}'
                      : '已下载 ${_formatBytes(progress.received)}',
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!_cancelToken.isCancelled) {
                _cancelToken.cancel('user_cancelled');
              }
            },
            child: const AppText('取消'),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  final megabytes = bytes / (1024 * 1024);
  return '${megabytes.toStringAsFixed(1)} MB';
}
