import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../core/logging/app_log_service.dart';

final class ScrollToTopController extends ChangeNotifier {
  bool _suppressed = false;
  Future<void> Function()? _handler;

  bool get suppressed => _suppressed;

  void setHandler(Future<void> Function()? handler) {
    _handler = handler;
  }

  Future<bool> invokeHandler() async {
    final handler = _handler;
    if (handler == null) {
      return false;
    }
    await handler();
    return true;
  }

  void setSuppressed(bool value) {
    if (_suppressed == value) {
      return;
    }
    _suppressed = value;
    notifyListeners();
  }
}

class ScrollToTopOverlay extends StatefulWidget {
  const ScrollToTopOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final ScrollToTopController controller;

  @override
  State<ScrollToTopOverlay> createState() => _ScrollToTopOverlayState();
}

class _ScrollToTopOverlayState extends State<ScrollToTopOverlay> {
  ScrollPosition? _position;
  var _visible = false;
  var _textFieldFocused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSuppressionChanged);
    FocusManager.instance.addListener(_onFocusChanged);
    _textFieldFocused = _queryTextFieldFocused();
  }

  @override
  void didUpdateWidget(covariant ScrollToTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSuppressionChanged);
      widget.controller.addListener(_onSuppressionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSuppressionChanged);
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onSuppressionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖变化（路由切换、主题变更等）后焦点状态可能已不同。
    // 这里静默刷新缓存，避免在 build 中对其它 Element 查询祖先。
    _textFieldFocused = _queryTextFieldFocused();
  }

  void _onFocusChanged() {
    if (!mounted) {
      return;
    }
    final focused = _queryTextFieldFocused();
    if (focused == _textFieldFocused) {
      return;
    }
    setState(() => _textFieldFocused = focused);
  }

  /// 判断当前主焦点是否落在文本输入框上。
  ///
  /// 焦点节点的 Element 可能处于 deactivated 状态（例如所在路由正在退场），
  /// 此时查询祖先会抛 FlutterError（"Looking up a deactivated widget's
  /// ancestor is unsafe."）。这里按“不是输入框”处理：debug 下不再红屏，
  /// release 下断言本就不存在，行为与之前一致。
  bool _queryTextFieldFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    try {
      return context.widget is EditableText ||
          context.findAncestorWidgetOfExactType<EditableText>() != null;
    } on FlutterError {
      return false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    _updateFromMetrics(notification.metrics, notification.context);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    _updateFromMetrics(notification.metrics, notification.context);
    return false;
  }

  void _updateFromMetrics(ScrollMetrics metrics, BuildContext? sourceContext) {
    if (metrics.axis != Axis.vertical || sourceContext == null) {
      return;
    }
    final route = ModalRoute.of(sourceContext);
    if (route is! PageRoute || !route.isCurrent) {
      return;
    }
    final scrollable = Scrollable.maybeOf(sourceContext);
    final position = scrollable?.position;
    if (position == null || !position.hasPixels) {
      return;
    }
    final visible =
        metrics.viewportDimension > 0 &&
        metrics.pixels > metrics.minScrollExtent + metrics.viewportDimension;
    if (identical(_position, position) && visible == _visible) {
      return;
    }
    setState(() {
      _position = position;
      _visible = visible;
    });
  }

  Future<void> _scrollToTop() async {
    final inputFocused = _textFieldFocused;
    unawaited(
      AppLogService.instance.info(
        '置顶按钮点击；visible=$_visible；suppressed=${widget.controller.suppressed};'
        'inputFocused=$inputFocused；keyboard=${MediaQuery.viewInsetsOf(context).bottom};'
        'position=${_position?.runtimeType}',
        component: 'scroll_to_top',
      ),
    );
    if (inputFocused) {
      return;
    }
    if (await widget.controller.invokeHandler()) {
      return;
    }
    final position = _position;
    if (position == null || !position.hasPixels) {
      return;
    }
    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final show =
        _visible &&
        !widget.controller.suppressed &&
        !keyboardVisible &&
        !_textFieldFocused;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              right: 14,
              // 避开详情页评论编辑器底部的发送按钮。
              bottom: 136,
              child: SafeArea(
                minimum: const EdgeInsets.all(2),
                child: IgnorePointer(
                  ignoring: !show,
                  child: AnimatedScale(
                    scale: show ? 1 : 0.82,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: FloatingActionButton.small(
                        heroTag: null,
                        tooltip: context.uiText('回到顶部'),
                        elevation: 0,
                        onPressed: _scrollToTop,
                        child: const Icon(Icons.keyboard_arrow_up),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
