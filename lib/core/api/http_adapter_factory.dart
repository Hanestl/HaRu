import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:native_dio_adapter/native_dio_adapter.dart';

import '../logging/app_log_service.dart';

/// 统一创建独立的 HTTP 客户端适配器。
///
/// 在 Android 平台下优先采用基于 Cronet 的 [NativeAdapter]，以利用 HTTP/2 多路复用和连接池；
/// 若底层 Provider 全部不可用或在非 Android 平台上，安全降级至 [IOHttpClientAdapter]。
///
/// 注意边界（与依赖实现对齐）：
/// 1. [NativeAdapter.createFallbackAdapter] 仅在底层识别为全部 Cronet Provider 不可用时触发降级；
/// 2. 请求执行期间的 TLS 握手异常、连接超时、取消或业务错误不会触发降级至 IO 适配器；
/// 3. 单个适配器一旦确定使用 Cronet 或降级路径，在其实例生命周期内该选择为粘性固定。
HttpClientAdapter createHttpAdapter({
  required String userAgent,
  required String component,
  bool enableHttp2 = true,
  bool enableQuic = false,
}) {
  if (Platform.isAndroid) {
    return NativeAdapter(
      createCronetEngine: () => CronetEngine.build(
        userAgent: userAgent,
        enableHttp2: enableHttp2,
        enableQuic: enableQuic,
      ),
      createFallbackAdapter: (error, stackTrace) {
        unawaited(
          AppLogService.instance.warning(
            'Cronet 全部 Provider 不可用，已自动降级至 IOHttpClientAdapter: $error',
            component: component,
          ),
        );
        return IOHttpClientAdapter();
      },
    );
  }
  return IOHttpClientAdapter();
}

/// 基于相同网络配置共享的底层适配器缓存映射。
final Map<_AdapterKey, HttpClientAdapter> _sharedAdapters = {};

/// 记录所有通过工厂分发的活跃共享门面弱引用。
final List<WeakReference<SharedHttpClientAdapter>> _activeFacades = [];

void _cleanDeadFacades() {
  _activeFacades.removeWhere((ref) => ref.target == null);
}

/// 获取或创建具有安全生命周期隔离的共享 HTTP 适配器门面。
///
/// 在 Android 平台下，原生适配器默认由适配器自身关闭底层 Cronet 引擎。
/// 通过 [SharedHttpClientAdapter] 包装，各个 Dio 客户端调用 [HttpClientAdapter.close] 时
/// 仅释放各自的请求监听，绝不意外关闭底层共享的 Cronet 引擎与连接池。
HttpClientAdapter getOrCreateSharedHttpAdapter({
  required String userAgent,
  required String component,
  bool enableHttp2 = true,
  bool enableQuic = false,
}) {
  final key = _AdapterKey(
    userAgent: userAgent,
    enableHttp2: enableHttp2,
    enableQuic: enableQuic,
  );

  final underlying = _sharedAdapters.putIfAbsent(
    key,
    () => createHttpAdapter(
      userAgent: userAgent,
      component: component,
      enableHttp2: enableHttp2,
      enableQuic: enableQuic,
    ),
  );

  final facade = SharedHttpClientAdapter(underlying);
  _activeFacades.add(WeakReference(facade));
  _cleanDeadFacades();
  return facade;
}

/// 关闭并释放所有全局共享的底层 HTTP 适配器（应用生命周期终止或测试清理时调用）。
void closeSharedHttpAdapters({bool force = false}) {
  for (final adapter in _sharedAdapters.values) {
    try {
      adapter.close(force: force);
    } catch (_) {
      // 单个适配器关闭失败不应影响其余适配器；底层句柄会随进程退出释放。
    }
  }
  _sharedAdapters.clear();

  for (final ref in _activeFacades) {
    ref.target?.markShutdown();
  }
  _activeFacades.clear();
}

@visibleForTesting
int get activeSharedAdaptersCount => _sharedAdapters.length;

final class _AdapterKey {
  const _AdapterKey({
    required this.userAgent,
    required this.enableHttp2,
    required this.enableQuic,
  });

  final String userAgent;
  final bool enableHttp2;
  final bool enableQuic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdapterKey &&
          other.userAgent == userAgent &&
          other.enableHttp2 == enableHttp2 &&
          other.enableQuic == enableQuic;

  @override
  int get hashCode => Object.hash(userAgent, enableHttp2, enableQuic);
}

/// 共享适配器门面：代理 [fetch] 请求，但拦截单个 Dio 客户端的 [close] 操作，
/// 确保多个业务客户端共享同一个底层网络引擎时，不会因某一方客户端 close() 导致共享引擎被销毁。
class SharedHttpClientAdapter implements HttpClientAdapter {
  SharedHttpClientAdapter(this._delegate);

  final HttpClientAdapter _delegate;
  var _closed = false;
  var _shutdown = false;

  /// 底层代理的适配器实例。
  @visibleForTesting
  HttpClientAdapter get delegate => _delegate;

  /// 该门面是否已被客户端单独关闭。
  bool get isClosed => _closed;

  /// 底层共享引擎是否已被全局释放。
  bool get isShutdown => _shutdown;

  /// 标记底层共享引擎已被全局释放。
  void markShutdown() {
    _shutdown = true;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (_closed || _shutdown) {
      throw DioException(
        requestOptions: options,
        error: _shutdown ? '底座网络适配器已释放，无法发起请求。' : '该客户端已被关闭，无法发起请求。',
        type: DioExceptionType.unknown,
      );
    }
    return _delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    // 故意不关闭 _delegate：底层适配器由应用级生命周期管理器掌控
  }
}
