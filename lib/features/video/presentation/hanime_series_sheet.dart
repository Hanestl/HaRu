import 'dart:math' as math;

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/models/video_models.dart';
import '../../../features/settings/domain/app_settings.dart';
import '../../../shared/video_card.dart';

/// Hanime 剧集/系列视频横条区域，支持展开全量列表 BottomSheet。
class HanimeSeriesSection extends StatelessWidget {
  const HanimeSeriesSection({
    super.key,
    required this.seriesTitle,
    required this.videos,
    required this.layout,
    required this.currentVideoId,
    required this.onTap,
  });

  final String seriesTitle;
  final List<VideoItem> videos;
  final ContentLayout layout;
  final String currentVideoId;
  final Future<void> Function(VideoItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('系列视频', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AppText(
                seriesTitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        Row(
          children: [
            AppText(
              '共${videos.length}集',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => _openSheet(context),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: const AppText('展开'),
            ),
          ],
        ),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * .63;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HanimeSeriesSheet(
        seriesTitle: seriesTitle,
        videos: videos,
        layout: layout,
        currentVideoId: currentVideoId,
        sheetHeight: sheetHeight,
        onTap: onTap,
      ),
    );
  }
}

/// Hanime 展开后的系列番剧 BottomSheet，支持自动将当前正在播放的剧集滚动至视口居中。
class _HanimeSeriesSheet extends StatefulWidget {
  const _HanimeSeriesSheet({
    required this.seriesTitle,
    required this.videos,
    required this.layout,
    required this.currentVideoId,
    required this.sheetHeight,
    required this.onTap,
  });

  final String seriesTitle;
  final List<VideoItem> videos;
  final ContentLayout layout;
  final String currentVideoId;
  final double sheetHeight;
  final Future<void> Function(VideoItem) onTap;

  @override
  State<_HanimeSeriesSheet> createState() => _HanimeSeriesSheetState();
}

class _HanimeSeriesSheetState extends State<_HanimeSeriesSheet> {
  ScrollController? _scrollController;
  final _currentItemKey = GlobalKey();
  var _initialPositionCorrected = false;
  var _initialPositionAttempts = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollController != null) return;
    final currentIndex = widget.videos.indexWhere(
      (video) => video.id == widget.currentVideoId,
    );
    final row = currentIndex < 0
        ? 0
        : widget.layout == ContentLayout.doubleColumn
        ? currentIndex ~/ 2
        : currentIndex;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = widget.layout == ContentLayout.doubleColumn
        ? (screenWidth - 32) / 2
        : screenWidth - 24;
    final estimatedItemExtent =
        cardWidth * 9 / 16 +
        (widget.layout == ContentLayout.doubleColumn ? 92.0 : 112.0);
    const estimatedHeaderExtent = 64.0;
    final initialOffset = math.max(
      0,
      estimatedHeaderExtent +
          row * estimatedItemExtent -
          (widget.sheetHeight - 48) / 2 +
          estimatedItemExtent / 2,
    );
    _scrollController = ScrollController(
      initialScrollOffset: initialOffset.toDouble(),
    );
    WidgetsBinding.instance.addPostFrameCallback(_correctInitialPosition);
  }

  void _correctInitialPosition(Duration _) {
    if (!mounted || _initialPositionCorrected) return;
    final currentContext = _currentItemKey.currentContext;
    if (currentContext == null) {
      // MasonryGridView 冷缓存及多列动态测量需要 1–2 帧完成布局。
      // 为防止当前视频项未完成挂载时无限空转重试，设定最多尝试 8 帧。
      if (++_initialPositionAttempts >= 8) return;
      WidgetsBinding.instance.addPostFrameCallback(_correctInitialPosition);
      return;
    }
    _initialPositionCorrected = true;
    Scrollable.ensureVisible(
      currentContext,
      alignment: 0.5,
      duration: Duration.zero,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: widget.sheetHeight,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppText(
                  widget.seriesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (widget.layout == ContentLayout.doubleColumn)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childCount: widget.videos.length,
                  itemBuilder: (context, index) =>
                      _buildItem(context, index, compact: true),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildItem(context, index, compact: false),
                    childCount: widget.videos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, {required bool compact}) {
    final video = widget.videos[index];
    final item = Stack(
      fit: StackFit.passthrough,
      children: [
        VideoCard(
          video: video,
          compact: compact,
          onTap: () {
            Navigator.pop(context);
            if (video.id == widget.currentVideoId) return;
            widget.onTap(video);
          },
        ),
        if (video.id == widget.currentVideoId)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: const Color(0x99000000),
                child: Center(
                  child: AppText(
                    '正在播放',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final keyed = video.id == widget.currentVideoId
        ? KeyedSubtree(key: _currentItemKey, child: item)
        : item;
    return RepaintBoundary(child: keyed);
  }
}
