# ADR-0020：共享 Cronet/Native 网络适配器与应用生命周期闭环

- 状态：已接受
- 日期：2026-10-16
- 相关：ADR-0002, ADR-0014

## 背景

应用在高并发场景下频繁请求双站 API 与媒体资源，在移动端（特别是 Android）使用基于 Cronet 的原生适配器（`NativeAdapter`）可以获得 HTTP/2、连接复用及 QUIC 协议带来的显著延迟降低与吞吐提升。

但在以往实现中，每次构建 Dio 实例可能重复创建底层适配器，造成 Native 资源泄露与底层网络线程膨胀；同时单个 Dio 客户端若调用 `close()`，不应误杀其他业务模块共用的底层连接底座。此外，在应用切后台或活动重建时若粗暴关闭网络底座，会造成持有已销毁引擎的门面发生悬挂调用；若错误地抛出取消异常（`cancel`），还会导致上层误报为“用户已取消操作”并阻断重试自愈机制。

针对“双站共享单一底层 Cronet 引擎”的构想，经过深入研判：Hanime1 部署了严格的 Cloudflare 防火墙审查，而 Chromium Native 层是否存在引擎级 UA 缓存覆盖属于黑盒行为。如果贸然让 Hanime1 与其他模块共享同一个底座引擎，极易引起 UA 指纹污染和反爬 WAF 拦截风控。

## 决策

1. **共享适配器门面管理**：
   - 在 `lib/core/api/http_adapter_factory.dart` 中提供 `getOrCreateSharedHttpAdapter(...)`，基于 `_AdapterKey(userAgent, enableHttp2, enableQuic)` 缓存底层适配器，并以 `SharedHttpClientAdapter` 门面包裹分发。
   - `SharedHttpClientAdapter.close()` 仅将门面标记为 `isClosed = true`，绝对不调用底层代理的 `close()`，从而隔离各个客户端的生命周期。
2. **状态感知与诚实的异常语义**：
   - 全局通过 `closeSharedHttpAdapters({bool force = false})` 释放底座时，通过弱引用同步标记所有分发的活跃门面为 `isShutdown = true`。
   - 处于关闭或释放状态的门面在发起请求时抛出 `DioExceptionType.unknown`（附带明确文案），严禁使用 `DioExceptionType.cancel`，避免误导用户或被错误视图及重试策略当成用户取消行为。
3. **审慎的生命周期收敛**：
   - 生命周期收敛于 Riverpod 依赖注入容器的 `ref.onDispose(api.close)` 以及根组件销毁阶段，避免在 Android `onDetach` 时过早摧毁活动引擎。
4. **双站点网络底座安全隔离**：
   - 维持 Rule34Video 与 Hanime1 独立的 Cronet 引擎底座（Hanime1 专用 `createHttpAdapter`），在 Native 层保持网络栈沙盒隔离，从根源规避 UA 指纹污染与 Cloudflare WAF 封禁风险。

## 结果

- 杜绝了 Native 网络底座泄露与后台线程膨胀风险；
- 避免了底层引擎关闭后上层报“用户已取消”的语义失真；
- 规避了第三方高防站点的 WAF 封锁隐患；
- 应用在退出与测试重置时网络资源均能干净释放。
