import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/models/video_models.dart';
import '../../../core/services/translation_service.dart';
import '../../../shared/editable_translation.dart';
import '../../../shared/localized_translation_text.dart';
import '../../../shared/site_avatar.dart';

/// 详情页顶部/操作栏中的胶囊按钮（如点赞、稍后观看、下载、分享等）。
class VideoDetailActionButton extends StatelessWidget {
  const VideoDetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: busy ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(label),
          if (busy) ...[
            const SizedBox(width: 8),
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

/// 播放次数、发布日期等短统计 Chip。
class VideoDetailStatChip extends StatelessWidget {
  const VideoDetailStatChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: AppText(label));
  }
}

/// Hanime 视频详情折叠简介卡片。
class HanimeDescriptionCard extends StatelessWidget {
  const HanimeDescriptionCard({super.key, required this.details});

  final VideoDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploader = details.uploader;
    final artistNames = details.models
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final showUploader =
        uploader != null &&
        !artistNames.contains(uploader.name.trim().toLowerCase());
    final metadata = <String>[
      if (details.video.views case final views?) '${_groupDigits(views)} 次观看',
      ?details.video.publishedLabel,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showUploader) ...[
              AppText(
                '上传者：${uploader.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (metadata.isNotEmpty) ...[
              Text(
                metadata.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
            ],
            if (details.descriptionTitle case final title?) ...[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 5),
            ],
            if (details.description case final description?)
              CollapsibleDescription(
                text: description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _groupDigits(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

/// 支持超过最大行数时折叠/展开的简介文本。
class CollapsibleDescription extends StatefulWidget {
  const CollapsibleDescription({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<CollapsibleDescription> createState() => _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<CollapsibleDescription> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final probe = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final collapsible = probe.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: collapsible && !_expanded ? 3 : null,
              overflow: collapsible && !_expanded
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
            ),
            if (collapsible) ...[
              const SizedBox(height: 2),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: AppText(_expanded ? '收起' : '展开'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 自适应元数据标签（带可选头像和圆角交互高亮）。
class _AdaptiveMetadataChip extends StatelessWidget {
  const _AdaptiveMetadataChip({
    this.avatar,
    required this.label,
    this.onPressed,
    this.kind,
  });

  final Widget? avatar;
  final Widget label;
  final VoidCallback? onPressed;
  final DiscoveryKind? kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipTheme = ChipTheme.of(context);

    final (backgroundColor, borderColor) = switch (kind) {
      DiscoveryKind.model => (
        colorScheme.primaryContainer.withValues(alpha: 0.35),
        colorScheme.primary.withValues(alpha: 0.4),
      ),
      DiscoveryKind.category => (
        colorScheme.secondaryContainer.withValues(alpha: 0.35),
        colorScheme.secondary.withValues(alpha: 0.4),
      ),
      _ => (
        chipTheme.backgroundColor ?? colorScheme.surfaceContainerHighest,
        colorScheme.outlineVariant,
      ),
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: borderColor),
    );
    final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      160.0,
      560.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        button: onPressed != null,
        child: Material(
          color: backgroundColor,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (avatar != null) ...[
                    SizedBox.square(
                      dimension: 24,
                      child: Center(child: avatar),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    fit: FlexFit.loose,
                    child: DefaultTextStyle(
                      style:
                          chipTheme.labelStyle ?? theme.textTheme.labelLarge!,
                      child: label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 详情页元数据分类面板（标签、艺术家、分类等带有翻译支持的分组）。
class VideoDetailMetadataSection extends StatefulWidget {
  const VideoDetailMetadataSection({
    super.key,
    required this.title,
    required this.items,
    required this.fallbackValues,
    required this.kind,
    required this.translationService,
    required this.siteId,
    required this.subscribedPaths,
    required this.updatingKeys,
    required this.onTap,
  });

  final String title;
  final List<VideoMetadataItem> items;
  final List<String> fallbackValues;
  final DiscoveryKind kind;
  final TranslationService translationService;
  final String siteId;
  final Set<String> subscribedPaths;
  final Set<String> updatingKeys;
  final ValueChanged<VideoMetadataItem>? onTap;

  @override
  State<VideoDetailMetadataSection> createState() =>
      _VideoDetailMetadataSectionState();
}

class _VideoDetailMetadataSectionState
    extends State<VideoDetailMetadataSection> {
  var _expanded = false;
  static const _collapseThreshold = 5;

  @override
  void didUpdateWidget(covariant VideoDetailMetadataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteId != widget.siteId || oldWidget.kind != widget.kind) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final fallbackValues = widget.fallbackValues;
    if (items.isEmpty && fallbackValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = items.isNotEmpty ? items.length : fallbackValues.length;
    final shouldCollapse = totalCount > _collapseThreshold;
    final remainingCount = totalCount - _collapseThreshold;
    final displayCount = shouldCollapse && !_expanded
        ? _collapseThreshold
        : totalCount;

    return ListenableBuilder(
      listenable: widget.translationService,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (items.isEmpty)
                  ...fallbackValues
                      .take(displayCount)
                      .map(
                        (value) => EditableTranslationRegion(
                          translationService: widget.translationService,
                          kind: widget.kind,
                          english: value,
                          siteId: widget.siteId,
                          child: _AdaptiveMetadataChip(
                            kind: widget.kind,
                            label: LocalizedTranslationText(
                              value: widget.translationService.resolveMetadata(
                                widget.kind,
                                value,
                                siteId: widget.siteId,
                              ),
                            ),
                          ),
                        ),
                      )
                else
                  ...items.take(displayCount).map((item) {
                    final subscribed = widget.subscribedPaths.contains(
                      item.path,
                    );
                    final busy = widget.updatingKeys.any(
                      (key) => key.endsWith('${item.kind.name}:${item.id}'),
                    );
                    return EditableTranslationRegion(
                      translationService: widget.translationService,
                      kind: item.kind,
                      english: item.title,
                      siteId: widget.siteId,
                      child: _AdaptiveMetadataChip(
                        kind: item.kind,
                        avatar: _metadataAvatar(
                          context,
                          item: item,
                          subscribed: subscribed,
                          busy: busy,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: LocalizedTranslationText(
                                value: widget.translationService
                                    .resolveMetadata(
                                      item.kind,
                                      item.title,
                                      siteId: widget.siteId,
                                    ),
                                suffix: item.upScore == 0 && item.downScore == 0
                                    ? ''
                                    : ' · ↑${item.upScore} ↓${item.downScore}',
                              ),
                            ),
                            if (item.count != null) ...[
                              const SizedBox(width: 2),
                              Text(
                                '（${item.count}）',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        onPressed: busy || widget.onTap == null
                            ? null
                            : () => widget.onTap!(item),
                      ),
                    );
                  }),
                if (shouldCollapse)
                  ActionChip(
                    avatar: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                    label: AppText(_expanded ? '收起' : '展开($remainingCount)'),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(DiscoveryKind kind) => switch (kind) {
    DiscoveryKind.tag => Icons.tag,
    DiscoveryKind.category => Icons.category_outlined,
    DiscoveryKind.model => Icons.brush_outlined,
    DiscoveryKind.channel => Icons.live_tv_outlined,
  };

  Widget _metadataAvatar(
    BuildContext context, {
    required VideoMetadataItem item,
    required bool subscribed,
    required bool busy,
  }) {
    if (busy) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final avatar = item.thumbnailUrl == null
        ? Icon(_kindIcon(item.kind), size: 18)
        : SiteAvatar(
            imageUrl: item.thumbnailUrl,
            radius: 9,
            fallbackIcon: _kindIcon(item.kind),
          );
    if (!subscribed) {
      return avatar;
    }
    return SizedBox.square(
      dimension: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -3,
            bottom: -3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.notifications, size: 8, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
