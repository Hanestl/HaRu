import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/scroll_to_top_overlay.dart';

/// 详情页 SliverPersistentHeader 委托，负责在折叠滚动时隐藏播放器并保持 TabBar 吸顶。
class VideoDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  const VideoDetailHeaderDelegate({
    required this.player,
    required this.tabs,
    required this.playerHeight,
  });

  static const tabsHeight = 36.0;
  final Widget player;
  final Widget tabs;
  final double playerHeight;

  @override
  double get minExtent => tabsHeight;

  @override
  double get maxExtent => playerHeight + tabsHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final hiddenPlayerHeight = shrinkOffset.clamp(0.0, maxExtent - minExtent);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -hiddenPlayerHeight,
            height: playerHeight,
            child: player,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: playerHeight - hiddenPlayerHeight,
            height: tabsHeight,
            child: tabs,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant VideoDetailHeaderDelegate oldDelegate) =>
      oldDelegate.player != player ||
      oldDelegate.tabs != tabs ||
      oldDelegate.playerHeight != playerHeight;
}

/// 播放器在播放中或置顶中时限制滚动行为的自定义 ScrollPhysics。
class PlayerHeaderGatePhysics extends ScrollPhysics {
  const PlayerHeaderGatePhysics({
    required this.playing,
    required this.buffering,
    required this.scrollToTopController,
    super.parent,
  });

  final ValueListenable<bool> playing;
  final ValueListenable<bool> buffering;
  final ScrollToTopController scrollToTopController;

  bool get _locked =>
      playing.value || buffering.value || scrollToTopController.suppressed;

  @override
  bool get allowImplicitScrolling => !_locked && super.allowImplicitScrolling;

  @override
  PlayerHeaderGatePhysics applyTo(ScrollPhysics? ancestor) {
    return PlayerHeaderGatePhysics(
      playing: playing,
      buffering: buffering,
      scrollToTopController: scrollToTopController,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (_locked && value != position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (_locked) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}

/// 用于在外部嵌套滚动视图中校正滚动偏移的 SingleChildRenderObjectWidget。
class OuterScrollOffsetCorrector extends SingleChildRenderObjectWidget {
  const OuterScrollOffsetCorrector({
    super.key,
    required this.position,
    required this.targetOffset,
    required super.child,
  });

  final ScrollPosition? position;
  final double? targetOffset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOuterScrollOffsetCorrector(
      position: position,
      targetOffset: targetOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    if (renderObject is _RenderOuterScrollOffsetCorrector) {
      renderObject.update(position: position, targetOffset: targetOffset);
    }
  }
}

/// 底层 RenderProxyBox 实现，校正布局中的滚动偏移。
class _RenderOuterScrollOffsetCorrector extends RenderProxyBox {
  _RenderOuterScrollOffsetCorrector({
    required this.position,
    required this.targetOffset,
  });

  ScrollPosition? position;
  double? targetOffset;

  void update({
    required ScrollPosition? position,
    required double? targetOffset,
  }) {
    if (identical(this.position, position) &&
        this.targetOffset == targetOffset) {
      return;
    }
    this.position = position;
    this.targetOffset = targetOffset;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final scrollPosition = position;
    final target = targetOffset;
    if (scrollPosition != null && target != null && scrollPosition.hasPixels) {
      final correction = target - scrollPosition.pixels;
      if (correction.abs() > precisionErrorTolerance) {
        scrollPosition.correctBy(correction);
      }
    }
    super.performLayout();
  }
}
