import 'package:flutter/material.dart';

import '../core/models/content_source.dart';

/// 站点徽标（红底圆角字母）：底部导航 tab 图标、账号卡片、登录 sheet 通用。
class SiteBadge extends StatelessWidget {
  const SiteBadge({
    super.key,
    required this.site,
    this.size = 24,
    this.isSelected = true,
  });

  final ContentSite site;
  final double size;
  final bool isSelected;

  static const _letter = <ContentSite, String>{
    ContentSite.rule34video: 'R',
    ContentSite.hanime1: 'H',
  };

  @override
  Widget build(BuildContext context) {
    final letter = _letter[site] ?? site.label.characters.first;
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(size * 0.3);

    if (!isSelected) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontSize: size * 0.62,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: borderRadius,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.62,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
