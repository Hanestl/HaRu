import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';

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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSuppressionChanged);
    FocusManager.instance.addListener(_onFocusChanged);
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

  void _onFocusChanged() {
    if (mounted) setState(() {});
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
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final inputFocused =
        focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
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
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final inputFocused =
        focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    final show =
        _visible &&
        !widget.controller.suppressed &&
        !keyboardVisible &&
        !inputFocused;
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
