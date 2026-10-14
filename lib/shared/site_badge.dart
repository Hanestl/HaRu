import 'package:flutter/material.dart';

import '../core/models/content_source.dart';

/// 站点徽标（红底圆角字母）：底部导航 tab 图标、账号卡片、登录 sheet 通用。
class SiteBadge extends StatelessWidget {
  const SiteBadge({super.key, required this.site, this.size = 24});

  final ContentSite site;
  final double size;

  static const _letter = <ContentSite, String>{
    ContentSite.rule34video: 'R',
    ContentSite.hanime1: 'H',
    // 默认回退到 label 首字符会得到 '9'，与 91porn 这个站点名对不上。
    ContentSite.porn91: '91',
  };

  @override
  Widget build(BuildContext context) {
    final letter = _letter[site] ?? site.label.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(size * 0.3),
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
