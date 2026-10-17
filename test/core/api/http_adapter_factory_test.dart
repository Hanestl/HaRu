import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flule34/core/api/http_adapter_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    closeSharedHttpAdapters(force: true);
  });

  test('createHttpAdapter 在当前环境返回有效适配器且可安全关闭', () {
    final adapter = createHttpAdapter(
      userAgent: 'TestUserAgent/1.0',
      component: 'test_component',
    );

    if (!Platform.isAndroid) {
      expect(adapter, isA<IOHttpClientAdapter>());
    }
    expect(adapter, isNotNull);
    adapter.close(force: true);
  });

  test('getOrCreateSharedHttpAdapter 对相同配置复用底层适配器', () {
    final adapter1 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'auth_client',
            )
            as SharedHttpClientAdapter;

    final adapter2 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'public_client',
            )
            as SharedHttpClientAdapter;

    expect(activeSharedAdaptersCount, equals(1));
    expect(identical(adapter1.delegate, adapter2.delegate), isTrue);
    expect(identical(adapter1, adapter2), isFalse);
  });

  test('getOrCreateSharedHttpAdapter 对不同配置创建不同底层实例', () {
    final adapter1 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'client1',
            )
            as SharedHttpClientAdapter;

    final adapter2 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/2.0',
              component: 'client2',
            )
            as SharedHttpClientAdapter;

    expect(activeSharedAdaptersCount, equals(2));
    expect(identical(adapter1.delegate, adapter2.delegate), isFalse);
  });

  test('SharedHttpClientAdapter 隔离单个客户端的 close 调用，不影响其他共享客户端', () {
    final adapter1 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'client1',
            )
            as SharedHttpClientAdapter;

    final adapter2 =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'client2',
            )
            as SharedHttpClientAdapter;

    // 关闭 client1 的门面
    adapter1.close();
    expect(adapter1.isClosed, isTrue);
    expect(adapter2.isClosed, isFalse);

    // 已关闭的门面发起 fetch 会被安全拦截，且异常类型绝不是 cancel（避免误导用户或错误视图）
    expect(
      () => adapter1.fetch(RequestOptions(path: '/'), null, null),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          equals(DioExceptionType.unknown),
        ),
      ),
    );

    // 底层实例依然保留在缓存映射中，没有被误杀
    expect(activeSharedAdaptersCount, equals(1));
  });

  test('closeSharedHttpAdapters 完全释放底层适配器并清空缓存', () {
    getOrCreateSharedHttpAdapter(
      userAgent: 'HaRuTest/1.0',
      component: 'client',
    );
    expect(activeSharedAdaptersCount, equals(1));

    closeSharedHttpAdapters(force: true);
    expect(activeSharedAdaptersCount, equals(0));
  });

  test('closeSharedHttpAdapters 之后先前分发的门面标记为 shutdown 且请求失败不伪装成用户取消', () {
    final adapter =
        getOrCreateSharedHttpAdapter(
              userAgent: 'HaRuTest/1.0',
              component: 'client',
            )
            as SharedHttpClientAdapter;

    expect(adapter.isShutdown, isFalse);

    closeSharedHttpAdapters(force: true);

    expect(adapter.isShutdown, isTrue);
    expect(
      () => adapter.fetch(RequestOptions(path: '/'), null, null),
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', equals(DioExceptionType.unknown))
            .having((e) => e.error.toString(), 'error', contains('底座网络适配器已释放')),
      ),
    );
  });
}
