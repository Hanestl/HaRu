import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/content_source.dart';
import '../../core/models/porn91_models.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_feed.dart';

/// 91porn 首页。
///
/// 与 Rule34Video / Hanime 不同，本站没有统一的“最新/热门/高评分”feed，
/// 只有各自独立的分类导航，因此这里直接以分类作为频道。
/// 站点没有账号级能力，页面上不出现登录、收藏、订阅等入口。
class Porn91HomePage extends ConsumerStatefulWidget {
  const Porn91HomePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<Porn91HomePage> createState() => _Porn91HomePageState();
}

class _Porn91HomePageState extends ConsumerState<Porn91HomePage> {
  var _category = Porn91Category.hot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            readOnly: true,
            leading: const Icon(Icons.search),
            hintText: context.uiText('搜索视频'),
            onTap: () {
              ref
                  .read(predictivePrefetchServiceProvider)
                  .prioritizeForeground();
              context.pushNamed(
                AppRouteNames.search,
                queryParameters: {'site': ContentSite.porn91.id},
              );
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: Porn91Category.values
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: AppText(category.label),
                      selected: _category == category,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        Expanded(child: _buildFeed()),
      ],
    );
  }

  Widget _buildFeed() {
    final prefetch = ref.read(predictivePrefetchServiceProvider);
    final category = _category;
    final feedKey = 'porn91:${category.name}';
    return VideoFeed(
      key: ValueKey(feedKey),
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.feed(feedKey, page),
        () => widget.api.loadPorn91Category(category, page),
      ),
      refreshPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.feed(feedKey, page),
        () => widget.api.loadPorn91Category(category, page),
      ),
      emptyMessage: '该分类暂时没有可展示的视频。',
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
    );
  }
}
