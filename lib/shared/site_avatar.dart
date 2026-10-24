import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/config/app_build_config.dart';
import '../core/models/content_source.dart';

class SiteAvatar extends StatelessWidget {
  const SiteAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person_outline,
    this.site = ContentSite.rule34video,
  });

  static const _rule34Headers = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': AppBuildConfig.appUserAgent,
  };

  // hanime 的头像/封面托管在 vdownload.hembed.com，需要 hanime1 的
  // Referer 才会返回（与媒体请求同源策略）。
  static const _hanimeHeaders = <String, String>{
    'Referer': 'https://hanime1.me/',
    'User-Agent': AppBuildConfig.appUserAgent,
  };

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final ContentSite site;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(fallbackIcon, size: radius * 1.05)),
    );
    final url = imageUrl?.trim();
    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: site == ContentSite.hanime1
                    ? _hanimeHeaders
                    : _rule34Headers,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, _) => fallback,
                errorWidget: (context, _, _) => fallback,
              ),
      ),
    );
  }
}
