import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/ui_localization.dart';
import '../../shared/error_view.dart';
import 'route_names.dart';

/// 路由兜底页：跳转目标不存在时替代 go_router 内置的英文「Page Not Found」。
///
/// 只在代码里 `go`/`push` 到未注册路由时出现（本应用没有注册深链），
/// 因此这里的按钮是「回到首页」而不是「重试」。
class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, required this.location});

  /// 未能匹配的路由位置，仅用于语义标签，不直接展示给用户。
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText('页面不存在')),
      body: AppErrorView(
        icon: Icons.explore_off_outlined,
        message: '请求的内容不存在或已被删除',
        retryLabel: '返回首页',
        onRetry: () => context.goNamed(AppRouteNames.home),
      ),
    );
  }
}

/// 供 `GoRouter.errorBuilder` 使用的构造器，保持路由表定义处单行。
Widget buildRouteErrorPage(BuildContext context, GoRouterState state) {
  return RouteErrorPage(location: state.uri.toString());
}
