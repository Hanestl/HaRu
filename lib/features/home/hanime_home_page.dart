import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/content_source.dart';
import '../../core/models/hanime_search_models.dart';
import '../../core/models/video_models.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';

/// Hanime1 首页：顶部频道横向切换 + 竖向无限翻页视频流。
/// 频道映射到 /search 协议（与详情页/筛选一致），videoLayout 单/双列生效。
class HanimeHomePage extends ConsumerStatefulWidget {
  const HanimeHomePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<HanimeHomePage> createState() => _HanimeHomePageState();
}

class _HanimeHomePageState extends ConsumerState<HanimeHomePage> {
  var _channel = 1;
  Map<String, List<VideoItem>> _homeSeeds = const {};

  static const _channels = <_HanimeChannel>[
    _HanimeChannel.subscription(),
    _HanimeChannel(
      'latest-release',
      '最新上市',
      HanimeSearchFilters(sort: '最新上市'),
      sectionTitle: '最新上市',
    ),
    _HanimeChannel(
      'latest-upload',
      '最新上传',
      HanimeSearchFilters(sort: '最新上傳'),
      sectionTitle: '最新上傳',
    ),
    _HanimeChannel(
      'ecchi',
      '里番',
      HanimeSearchFilters(genre: '裏番'),
      sectionTitle: '裏番',
    ),
    _HanimeChannel(
      'short',
      '泡面番',
      HanimeSearchFilters(genre: '泡麵番'),
      sectionTitle: '泡麵番',
    ),
    _HanimeChannel(
      'motion-anime',
      'Motion Anime',
      HanimeSearchFilters(genre: 'Motion Anime'),
      sectionTitle: 'Motion Anime',
    ),
    _HanimeChannel(
      '3dcg',
      '3DCG',
      HanimeSearchFilters(genre: '3DCG'),
      sectionTitle: '3DCG',
    ),
    _HanimeChannel(
      '2.5d',
      '2.5D',
      HanimeSearchFilters(genre: '2.5D'),
      sectionTitle: '2.5D動畫',
    ),
    _HanimeChannel(
      '2d-animation',
      '2D动画',
      HanimeSearchFilters(genre: '2D動畫'),
      sectionTitle: '2D動畫',
    ),
    _HanimeChannel(
      'ai-generated',
      'AI生成',
      HanimeSearchFilters(genre: 'AI生成'),
      sectionTitle: 'AI生成',
    ),
    _HanimeChannel(
      'mmd',
      'MMD',
      HanimeSearchFilters(genre: 'MMD'),
      sectionTitle: 'MMD',
    ),
    _HanimeChannel(
      'cosplay',
      'Cosplay',
      HanimeSearchFilters(genre: 'Cosplay'),
      sectionTitle: 'Cosplay',
    ),
    _HanimeChannel(
      'watching-now',
      '他们在看',
      HanimeSearchFilters(sort: '他們在看'),
      sectionTitle: '他們在看',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applyHomeSections(widget.api.hanime1Api.cachedHomeSections);
    unawaited(_loadHomeSeeds());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAdjacentChannels();
    });
  }

  Future<void> _loadHomeSeeds() async {
    try {
      final sections = await widget.api.loadHanimeHomeSections();
      if (!mounted) return;
      setState(() => _applyHomeSections(sections));
    } catch (error, stackTrace) {
      unawaited(
        AppLogService.instance.error(
          error,
          stackTrace,
          component: 'hanime_home_seed',
        ),
      );
    }
  }

  void _applyHomeSections(List<HanimeHomeSection> sections) {
    if (sections.isEmpty) return;
    _homeSeeds = {
      for (final section in sections)
        _normalizeSectionTitle(section.title): section.items,
    };
  }

  static String _normalizeSectionTitle(String title) =>
      title.replaceAll('更多', '').replaceAll('arrow_forward_ios', '').trim();

  @override
  Widget build(BuildContext context) {
    final prefetch = ref.read(predictivePrefetchServiceProvider);
    return ListenableBuilder(
      listenable: widget.api.sessionStore,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              readOnly: true,
              leading: const Icon(Icons.search),
              hintText: context.uiText('搜索视频、标签、分类或艺术家'),
              onTap: () {
                ref
                    .read(predictivePrefetchServiceProvider)
                    .prioritizeForeground();
                context.pushNamed(
                  AppRouteNames.search,
                  queryParameters: {'site': ContentSite.hanime1.id},
                  extra: const HanimeSearchLaunch(),
                );
              },
            ),
          ),
          _ChannelStrip(
            labels: _channels.map((channel) => channel.label).toList(),
            selectedIndex: _channel,
            onSelected: _selectChannel,
          ),
          Expanded(
            child: IndexedStack(
              index: _channel,
              children: [
                for (var index = 0; index < _channels.length; index++)
                  _buildFeed(prefetch, index, active: index == _channel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectChannel(int index) {
    if (index == _channel) return;
    setState(() => _channel = index);
    final channel = _channels[index];
    unawaited(
      AppLogService.instance.info(
        'Hanime 首页切换频道；频道=${channel.key}；索引=$index；种子=${_seedFor(channel).length}',
        component: 'hanime_home_navigation',
      ),
    );
    _scheduleAdjacentChannels();
  }

  void _scheduleAdjacentChannels() {
    final prefetch = ref.read(predictivePrefetchServiceProvider);
    final current = _channels[_channel];
    if (!current.isSubscription) {
      prefetch.scheduleHanimeHomeChannel(
        channelKey: current.key,
        filters: current.filters,
        page: 2,
      );
    }
    for (final offset in const [-1, 1]) {
      final index = (_channel + offset + _channels.length) % _channels.length;
      final channel = _channels[index];
      if (channel.isSubscription) continue;
      prefetch.scheduleHanimeHomeChannel(
        channelKey: channel.key,
        filters: channel.filters,
      );
    }
  }

  List<VideoItem> _seedFor(_HanimeChannel channel) {
    final title = channel.sectionTitle;
    if (title == null) return const [];
    return _homeSeeds[_normalizeSectionTitle(title)] ?? const [];
  }

  Widget _buildFeed(
    PredictivePrefetchService prefetch,
    int index, {
    required bool active,
  }) {
    final channel = _channels[index];
    if (channel.isSubscription) {
      if (!widget.api.sessionStore.isHanimeLoggedIn) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_none, size: 52),
                const SizedBox(height: 16),
                AppText(
                  '登录后查看订阅内容',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => showLoginSheet(
                    context,
                    widget.api,
                    site: ContentSite.hanime1,
                  ),
                  icon: const Icon(Icons.login),
                  label: const AppText('登录'),
                ),
              ],
            ),
          ),
        );
      }
      return VideoFeed(
        key: const ValueKey('hanime-home:subscriptions'),
        active: active,
        loadPage: (page) => prefetch.runForeground(
          PredictivePrefetchKey.libraryHanimeSubscriptions(page),
          () async =>
              (await widget.api.hanime1Api.loadSubscriptionPage(page)).videos,
        ),
        onItemsLoaded: prefetch.offerLikelyVideos,
        prefetchService: prefetch,
        emptyMessage: '订阅的艺术家暂时没有新视频。',
        sortNewest: true,
      );
    }
    return VideoFeed(
      key: ValueKey('hanime-home:${channel.key}'),
      active: active,
      initialItems: _seedFor(channel),
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.hanimeHomeChannel(channel.key, page),
        () => widget.api.hanime1Api.loadHomeChannel(
          channel.key,
          page,
          filters: channel.filters,
        ),
      ),
      refreshPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.hanimeHomeChannel(channel.key, page),
        () => widget.api.hanime1Api.loadHomeChannel(
          channel.key,
          page,
          filters: channel.filters,
          force: true,
        ),
      ),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
      emptyMessage: '这个频道暂时没有视频。',
    );
  }
}

final class _HanimeChannel {
  const _HanimeChannel(this.key, this.label, this.filters, {this.sectionTitle})
    : isSubscription = false;
  const _HanimeChannel.subscription()
    : key = 'subscriptions',
      label = '订阅',
      filters = const HanimeSearchFilters(),
      sectionTitle = null,
      isSubscription = true;

  final String key;
  final String label;
  final HanimeSearchFilters filters;
  final String? sectionTitle;
  final bool isSubscription;
}

class _ChannelStrip extends StatelessWidget {
  const _ChannelStrip({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: AppText(labels[index], maxLines: 1),
                selected: index == selectedIndex,
                showCheckmark: false,
                onSelected: (_) => onSelected(index),
              ),
            ),
        ],
      ),
    ),
  );
}
