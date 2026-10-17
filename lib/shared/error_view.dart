import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/hanime1_parser.dart';
import '../core/api/rule34video_api.dart';
import '../core/security/error_redaction.dart';
import '../core/services/external_link_service.dart';
import '../core/services/subscription_activity_index.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/library/data/local_library_repository.dart';
import '../l10n/ui_localization.dart';

/// 将各类系统和底层异常映射为对用户友好的错误提示文本。
String friendlyErrorMessage(Object? error, {String fallback = '出错了，请稍后重试'}) {
  if (error == null) {
    return fallback;
  }

  // 1. 显式透传已知业务领域异常（由业务层主动构建的友好提示，直接脱敏后透传）
  if (error is ExternalLinkException) {
    return redactSensitiveText(error.message);
  }
  if (error is HttpStatusException) {
    final status = error.statusCode;
    if (status == 500 || status == 502 || status == 503 || status == 504) {
      return '站点服务暂时不可用，请稍后重试';
    }
    return redactSensitiveText(error.message);
  }
  if (error is ApiException) {
    return redactSensitiveText(error.message);
  }
  if (error is DownloadException) {
    return redactSensitiveText(error.message);
  }
  if (error is LocalLibraryException) {
    return redactSensitiveText(error.message);
  }
  if (error is SubscriptionActivityException) {
    return redactSensitiveText(error.message);
  }
  if (error is HanimeCloudflareException) {
    return redactSensitiveText(error.toString());
  }

  // 2. Dio 网络异常
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => '连接超时，请检查网络设置后重试',
      DioExceptionType.connectionError => '网络连接失败，请检查网络是否畅通',
      DioExceptionType.badResponse => switch (error.response?.statusCode) {
        403 => '访问受限，可能需要安全验证',
        404 => '请求的内容不存在或已被删除',
        500 || 502 || 503 || 504 => '站点服务暂时不可用，请稍后重试',
        _ => '服务器响应异常 (${error.response?.statusCode ?? '未知'})',
      },
      DioExceptionType.cancel => '请求已取消',
      DioExceptionType.badCertificate => '安全证书验证失败',
      DioExceptionType.unknown =>
        error.error is SocketException ||
                error.message?.contains('SocketException') == true
            ? '网络连接异常，请检查网络'
            : '网络请求遇到问题，请重试',
    };
  }

  // 3. 基础 I/O 及解析异常
  if (error is SocketException || error is HttpException) {
    return '网络连接异常，请检查网络后重试';
  }

  if (error is TimeoutException) {
    return '操作超时，请稍后重试';
  }

  if (error is FormatException) {
    return '数据解析失败，站点结构可能已更新';
  }

  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('Connection refused') ||
      message.contains('Failed host lookup') ||
      message.contains('Network is unreachable')) {
    return '网络连接异常，请检查网络';
  }

  if (message.contains('TimeoutException')) {
    return '请求超时，请重试';
  }

  if (message.contains('SqliteException')) {
    return '本地数据库读写异常，请重试';
  }

  if (error is Error) {
    return redactSensitiveText(fallback);
  }

  var cleanedMessage = message;
  if (cleanedMessage.startsWith('Exception: ')) {
    cleanedMessage = cleanedMessage.substring('Exception: '.length).trim();
  }

  final lower = cleanedMessage.toLowerCase();
  // 启发式过滤：排除典型技术异常堆栈、未捕获错误及裸技术串
  if (!lower.contains('exception') &&
      !lower.contains('error') &&
      !lower.contains('stack trace') &&
      !lower.contains('bad state') &&
      !lower.contains('no element') &&
      !lower.contains('not found') &&
      !lower.contains('unhandled') &&
      !lower.contains('null check') &&
      cleanedMessage.length <= 80 &&
      RegExp(r'[\u4e00-\u9fff]').hasMatch(cleanedMessage)) {
    return redactSensitiveText(cleanedMessage);
  }

  return redactSensitiveText(fallback);
}

/// 判断异常或错误提示是否属于网络相关问题。
bool isNetworkError(Object? error, [String? message]) {
  if (error is ApiException) {
    return false;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return true;
  }
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown =>
        error.error is SocketException ||
            error.error is TimeoutException ||
            error.error is HttpException,
      _ => false,
    };
  }
  final text = (message ?? error?.toString() ?? '').toLowerCase();
  return text.contains('socketexception') ||
      text.contains('connection timed out') ||
      text.contains('connection refused') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('network connection') ||
      text.contains('connection closed') ||
      text.contains('网络请求超时') ||
      text.contains('无法连接到网站');
}

/// 统一的错误占位视图组件。
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.icon,
    this.padding = const EdgeInsets.all(24),
  });

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ?? friendlyErrorMessage(error);
    final theme = Theme.of(context);
    final isNetwork = isNetworkError(error, displayMessage);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ??
                  (isNetwork ? Icons.cloud_off_outlined : Icons.error_outline),
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            AppText(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: AppText(context.uiText('重试')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
