import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/logging/app_log_service.dart';
import 'core/maintenance/legacy_debug_data_cleanup.dart';

/// 应用入口。
///
/// 绑定初始化、日志初始化与 runApp 全部运行在同一个 [runZonedGuarded] 子 Zone
/// 内，这样启动阶段（绑定初始化、日志目录创建等）抛出的未捕获异步异常也会
/// 被 zone 处理器记录，而不是落到 root zone 里无人接收。
///
/// 注意：[AppLogService.instance.error] 在 [AppLogService.initialize] 完成前
/// 也可以安全调用——[_append] 会按需自行创建日志目录。
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await clearLegacyDebugLoggingData();
      await AppLogService.instance.initialize();

      FlutterError.onError = (details) {
        if (!kReleaseMode) {
          FlutterError.presentError(details);
        }
        unawaited(
          AppLogService.instance.error(
            details.exception,
            details.stack ?? StackTrace.current,
            component: 'flutter',
          ),
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        if (!kReleaseMode) {
          debugPrint('未捕获异步异常：$error\n$stackTrace');
        }
        unawaited(
          AppLogService.instance.error(error, stackTrace, component: 'async'),
        );
        return true;
      };

      runApp(const ProviderScope(child: AppBootstrap()));
    },
    (error, stackTrace) {
      if (!kReleaseMode) {
        debugPrint('未捕获的 Zone 异常：$error\n$stackTrace');
      }
      unawaited(
        AppLogService.instance.error(error, stackTrace, component: 'zone'),
      );
    },
  );
}
