import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/models/content_source.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_feed.dart';
import '../../shared/video_range_filters.dart';
import '../../shared/transient_focus.dart';
import '../auth/login_sheet.dart';
import '../settings/data/app_settings_repository.dart';

enum _HomeChannel {
  following('订阅', null),
  newest('最新', FeedKind.newest),
  popular('热门', FeedKind.popular),
  topRated('高评分', FeedKind.topRated);

  const _HomeChannel(this.label, this.feedKind);

  final String label;
  final FeedKind? feedKind;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _channel = _HomeChannel.newest;
  late final AppSettingsRepository _settingsRepository;
  late ContentOrientation _orientation;
  var _rangeFilters = const SearchFilters();

  @override
  void initState() {
    super.initState();
    _settingsRepository = ref.read(appSettingsRepositoryProvider)
      ..addListener(_onSettingsChanged);
    _orientation = _settingsRepository.settings.defaultOrientation;
  }

  @override
  void dispose() {
    _settingsRepository.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final next = _settingsRepository.settings.defaultOrientation;
    if (mounted && next != _orientation) {
      setState(() => _orientation = next);
    }
  }

  SearchFilters get _filters =>
      _rangeFilters.copyWith(orientation: _orientation);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.api.sessionStore,
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
                  queryParameters: {'site': ContentSite.rule34video.id},
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: _HomeChannel.values
                  .map(
                    (channel) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: AppText(channel.label),
                        selected: _channel == channel,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _channel = channel),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (_channel != _HomeChannel.following &&
              ContentSite.rule34video.capabilities.advancedFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  _FilterMenu<ContentOrientation>(
                    label: _orientation == ContentOrientation.all
                        ? '内容取向'
                        : _orientation.label,
                    value: _orientation,
                    values: ContentOrientation.values,
                    labelFor: (value) => value.label,
                    onSelected: (value) => setState(() => _orientation = value),
                  ),
                  VideoRangeFilter(
                    filters: _filters,
                    compact: true,
                    onChanged: (value) => setState(() => _rangeFilters = value),
                  ),
                  VideoRangeFilter(
                    filters: _filters,
                    compact: true,
                    date: true,
                    onChanged: (value) => setState(() => _rangeFilters = value),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final prefetch = ref.read(predictivePrefetchServiceProvider);
    if (_channel == _HomeChannel.following) {
      if (!widget.api.sessionStore.isLoggedIn) {
        return _FollowingSignedOut(
          onLogin: () => showLoginSheet(context, widget.api),
        );
      }
      final activity = widget.api.subscriptionActivity;
      return ListenableBuilder(
        listenable: activity,
        builder: (context, _) => Stack(
          children: [
            VideoFeed(
              key: ValueKey(
                'following:${widget.api.sessionStore.currentUserId}',
              ),
              initialItems: activity.cachedVideos
                  .take(30)
                  .toList(growable: false),
              loadPage: (page) => prefetch.runForeground(
                PredictivePrefetchKey.following,
                () => widget.api.loadFollowingFeed(page),
              ),
              refreshPage: (page) => prefetch.runForeground(
                PredictivePrefetchKey.following,
                () => widget.api.loadFollowingFeed(page, force: true),
              ),
              emptyMessage: '订阅的分类、艺术家或用户暂时没有可展示的视频。',
              sortNewest: true,
              onItemsLoaded: prefetch.offerLikelyVideos,
              prefetchService: prefetch,
            ),
            if (activity.isScanning && activity.totalSources > 0)
              Positioned(
                left: 16,
                right: 16,
                top: 8,
                child: _FollowingProgress(
                  scanned: activity.scannedSources,
                  total: activity.totalSources,
                ),
              ),
          ],
        ),
      );
    }
    final kind = _channel.feedKind!;
    final feedKey =
        'rule34video:${kind.name}:${_orientation.name}:${_filters.rangeKey}';
    return VideoFeed(
      key: ValueKey(feedKey),
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.feed(feedKey, page),
        () => widget.api.loadFeedForSite(kind, page, filters: _filters),
      ),
      refreshPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.feed(feedKey, page),
        () => widget.api.loadFeedForSite(
          kind,
          page,
          filters: _filters,
          force: true,
        ),
      ),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
    );
  }
}

class _FollowingProgress extends StatelessWidget {
  const _FollowingProgress({required this.scanned, required this.total});

  final int scanned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '正在整理订阅内容 $scanned/$total',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: total == 0 ? null : scanned / total),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T>(
        requestFocus: false,
        initialValue: value,
        onOpened: dismissInputFocus,
        onCanceled: dismissInputFocus,
        onSelected: (value) {
          dismissInputFocus();
          onSelected(value);
        },
        itemBuilder: (context) => values
            .map(
              (item) => CheckedPopupMenuItem<T>(
                value: item,
                checked: item == value,
                child: AppText(labelFor(item)),
              ),
            )
            .toList(growable: false),
        child: Chip(
          label: AppText(label),
          avatar: const Icon(Icons.tune, size: 16),
        ),
      ),
    );
  }
}

class _FollowingSignedOut extends StatelessWidget {
  const _FollowingSignedOut({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 52),
            const SizedBox(height: 16),
            AppText('登录后查看订阅内容', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const AppText(
              '订阅频道会汇总你在网站订阅的分类、艺术家、用户和播放列表。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const AppText('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
