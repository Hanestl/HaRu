import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/services/hanime_cloudflare_coordinator.dart';
import '../features/home/hanime_cloudflare_page.dart';

/// 全局 Cloudflare 验证弹窗。
///
/// 需要浏览器辅助验证时（[HanimeCloudflareCoordinator.activeRequest] 非空），
/// 在整屏上方叠加半透明遮罩 + 居中卡片式验证弹窗；验证完成或取消后自动
/// 移除，主界面恢复。
final class HanimeCloudflareGate extends ConsumerWidget {
  const HanimeCloudflareGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.watch(hanimeCloudflareCoordinatorProvider);
    final api = ref.watch(rule34VideoApiProvider).hanime1Api;
    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final request = coordinator.activeRequest;
        // 只有允许前台交互的请求才渲染验证卡片：后台预取绝不能被弹到
        // 前台，否则冷启动/后台刷新时会出现无规律的验证卡片闪现。
        final showVerification =
            request != null && request.allowForegroundVerification;
        return PopScope(
          canPop: !showVerification,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && showVerification) {
              // 用户主动返回 = 取消，不能当成"验证失败"：失败会给整个 host
              // 打上冷却，导致用户刚放弃一次验证就连正常请求都进不来。
              coordinator.complete(
                requestId: request.id,
                outcome: HanimeBrowserVerificationOutcome.cancelled,
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (showVerification) ...[
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(color: Colors.black45),
                  ),
                ),
                HanimeCloudflarePage(
                  key: ValueKey(request.id),
                  api: api,
                  targetUri: request.targetUri,
                  onPageReady: (html) =>
                      coordinator.complete(requestId: request.id, html: html),
                  onCancel: () => coordinator.complete(
                    requestId: request.id,
                    outcome: HanimeBrowserVerificationOutcome.cancelled,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
