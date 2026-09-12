import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/content_source.dart';
import '../../core/models/hanime_library_models.dart';
import '../../core/models/hanime_playlist_models.dart';
import '../../core/models/hanime_search_models.dart';
import '../../core/models/video_models.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/site_avatar.dart';
import '../../shared/video_feed.dart';
import '../../shared/video_list_filters.dart';
import '../../shared/transient_focus.dart';
import '../../app/providers.dart';
import '../settings/domain/app_settings.dart';

/// Hanime 点赞列表页（需登录）。
class HanimeLikesPage extends StatelessWidget {
  const HanimeLikesPage({super.key, required this.api, required this.prefetch});

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;

  @override
  Widget build(BuildContext context) {
    final loggedIn = api.sessionStore.isHanimeLoggedIn;
    return Scaffold(
      appBar: AppBar(title: const AppText('Hanime 点赞')),
      body: loggedIn
          ? HanimeLikesView(api: api, prefetch: prefetch)
          : const _HanimeSignedOut(),
    );
  }
}

class HanimeLikesView extends StatelessWidget {
  const HanimeLikesView({
    super.key,
    required this.api,
    required this.prefetch,
    this.active = true,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return VideoFeed(
      key: const PageStorageKey<String>('hanime-library-likes'),
      active: active,
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.libraryHanimeLikes(page),
        () => api.hanime1Api.loadLikes(page),
      ),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
      emptyMessage: '点赞列表暂时为空。',
      showSearchAndFilters: true,
      searchHint: '搜索点赞的视频',
      filterOptions: const VideoListFilterOptions.hanime(),
      contextActionLabel: '取消点赞',
      onContextAction: (video) async {
        await api.setHanimeLike(video, liked: false, current: true);
      },
    );
  }
}

class HanimeSavesView extends StatelessWidget {
  const HanimeSavesView({
    super.key,
    required this.api,
    required this.prefetch,
    this.active = true,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return VideoFeed(
      key: const PageStorageKey<String>('hanime-library-saves'),
      active: active,
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.libraryHanimeSaves(page),
        () => api.hanime1Api.loadSaves(page),
      ),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
      emptyMessage: '稍后观看列表暂时为空。',
      showSearchAndFilters: true,
      searchHint: '搜索稍后观看',
      filterOptions: const VideoListFilterOptions.hanime(),
      contextActionLabel: '移出稍后观看',
      onContextAction: (video) =>
          api.setHanimeSaved(video, saved: false, current: true),
    );
  }
}

class HanimeHistoryView extends StatelessWidget {
  const HanimeHistoryView({
    super.key,
    required this.api,
    required this.prefetch,
    this.active = true,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Future<List<VideoItem>> load(int page, VideoListFilters filters) {
      final sort = switch (filters.sort) {
        VideoListSort.popular => HanimeHistorySort.popular,
        VideoListSort.oldest => HanimeHistorySort.oldest,
        _ => HanimeHistorySort.latest,
      };
      return prefetch.runForeground(
        PredictivePrefetchKey.libraryHanimeHistory(sort.queryValue, page),
        () => api.hanime1Api.loadWatchHistory(page, sort: sort),
      );
    }

    return VideoFeed(
      key: const PageStorageKey<String>('hanime-library-history'),
      active: active,
      loadPage: (page) => load(page, const VideoListFilters()),
      loadFilteredPage: load,
      serverSideSorts: const {
        VideoListSort.sourceOrder,
        VideoListSort.popular,
        VideoListSort.oldest,
      },
      filterOptions: const VideoListFilterOptions.hanimeHistory(),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
      emptyMessage: '在线观看历史暂时为空。',
      showSearchAndFilters: true,
      searchHint: '搜索在线观看历史',
      contextActionLabel: '删除历史记录',
      onContextAction: (video) => api.hanime1Api.deleteWatchHistory(video.id),
    );
  }
}

class HanimeSubscriptionsView extends ConsumerStatefulWidget {
  const HanimeSubscriptionsView({
    super.key,
    required this.api,
    required this.prefetch,
    this.active = true,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;

  @override
  ConsumerState<HanimeSubscriptionsView> createState() =>
      _HanimeSubscriptionsViewState();
}

class _HanimeSubscriptionsViewState
    extends ConsumerState<HanimeSubscriptionsView>
    with AutomaticKeepAliveClientMixin {
  List<HanimeSubscriptionArtist> _artists = const [];
  final _searchController = TextEditingController();
  var _loading = false;
  var _query = '';
  var _sortByName = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HanimeSubscriptionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && _artists.isEmpty) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.prefetch.runForeground(
        PredictivePrefetchKey.libraryHanimeSubscriptions(1),
        () => widget.api.hanime1Api.loadSubscriptionPage(1),
      );
      if (mounted) setState(() => _artists = result.artists);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<HanimeSubscriptionArtist> get _visibleArtists {
    final query = _query.toLowerCase();
    final result = _artists
        .where((artist) => artist.name.toLowerCase().contains(query))
        .toList(growable: true);
    if (_sortByName) {
      result.sort((left, right) => left.name.compareTo(right.name));
    }
    return result;
  }

  void _openArtist(HanimeSubscriptionArtist artist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HanimeSubscriptionDetailPage(
          api: widget.api,
          prefetch: widget.prefetch,
          artist: artist,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _artists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _artists.isEmpty) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: AppText(_error!),
        ),
      );
    }
    final artists = _visibleArtists;
    final layout = ref
        .watch(appSettingsRepositoryProvider)
        .settings
        .subscriptionLayout;
    return Material(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey<String>(
            'hanime-library-subscription-artists',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _searchController,
                        leading: const Icon(Icons.search),
                        hintText: context.uiText('搜索订阅'),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<bool>(
                      requestFocus: false,
                      onOpened: dismissInputFocus,
                      tooltip: context.uiText('排序'),
                      initialValue: _sortByName,
                      onSelected: (value) =>
                          setState(() => _sortByName = value),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: false, child: AppText('网站顺序')),
                        PopupMenuItem(value: true, child: AppText('按名字')),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.sort),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (artists.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: AppText('没有符合条件的订阅。')),
              )
            else if (layout == ContentLayout.doubleColumn)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(7, 0, 7, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _artistCard(artists[index], compact: true),
                    childCount: artists.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverList.builder(
                  itemCount: artists.length,
                  itemBuilder: (context, index) => _artistCard(artists[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _artistCard(HanimeSubscriptionArtist artist, {bool compact = false}) {
    return Card(
      margin: compact
          ? const EdgeInsets.all(5)
          : const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openArtist(artist),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            children: [
              SiteAvatar(
                radius: compact ? 19 : 22,
                imageUrl: artist.avatarUrl,
                fallbackIcon: Icons.person_outline,
                site: ContentSite.hanime1,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  artist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class HanimeSubscriptionDetailPage extends StatefulWidget {
  const HanimeSubscriptionDetailPage({
    super.key,
    required this.api,
    required this.prefetch,
    required this.artist,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final HanimeSubscriptionArtist artist;

  @override
  State<HanimeSubscriptionDetailPage> createState() =>
      _HanimeSubscriptionDetailPageState();
}

class _HanimeSubscriptionDetailPageState
    extends State<HanimeSubscriptionDetailPage> {
  var _subscribed = true;
  var _updating = false;
  String? _referenceVideoId;

  Future<List<VideoItem>> _loadPage(int page) async {
    final videos = await widget.api.hanime1Api.searchVideos(
      widget.artist.name,
      page,
      filters: const HanimeSearchFilters(sort: '最新上傳'),
    );
    final normalizedArtist = widget.artist.name.trim().toLowerCase();
    final identified = videos
        .where((video) => video.creatorLabel?.trim().isNotEmpty == true)
        .toList(growable: false);
    final exact = identified
        .where(
          (video) =>
              video.creatorLabel!.trim().toLowerCase() == normalizedArtist,
        )
        .toList(growable: false);
    final result = identified.isEmpty ? videos : exact;
    unawaited(
      AppLogService.instance.info(
        'Hanime 订阅作者作品筛选；artist=${widget.artist.name}；page=$page；'
        'raw=${videos.length}；identified=${identified.length}；exact=${exact.length}；'
        'result=${result.length}',
        component: 'hanime_subscription',
      ),
    );
    if (_referenceVideoId == null && result.isNotEmpty && mounted) {
      setState(() => _referenceVideoId = result.first.id);
    }
    return result;
  }

  Future<void> _toggleSubscription() async {
    final videoId = _referenceVideoId;
    if (_updating || videoId == null) return;
    final previous = _subscribed;
    final next = !previous;
    setState(() {
      _updating = true;
      _subscribed = next;
    });
    try {
      await widget.api.setHanimeArtistSubscribed(
        videoId,
        artistKey: widget.artist.name,
        subscribed: next,
        current: previous,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(next ? '已订阅。' : '已取消订阅。')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _subscribed = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('同步失败，已恢复原状态：$error')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist.name),
        actions: [
          if (_updating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _referenceVideoId == null ? null : _toggleSubscription,
              child: AppText(_subscribed ? '取消订阅' : '订阅'),
            ),
        ],
      ),
      body: VideoFeed(
        loadPage: _loadPage,
        refreshPage: _loadPage,
        onItemsLoaded: widget.prefetch.offerLikelyVideos,
        prefetchService: widget.prefetch,
        emptyMessage: '这个订阅目前没有可显示的视频。',
        showSearchAndFilters: true,
        searchHint: '搜索此订阅中的视频',
        filterOptions: const VideoListFilterOptions.hanime(),
      ),
    );
  }
}

/// Hanime1 播放列表列表页（需登录）。
class HanimePlaylistsPage extends StatefulWidget {
  const HanimePlaylistsPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<HanimePlaylistsPage> createState() => _HanimePlaylistsPageState();
}

class _HanimePlaylistsPageState extends State<HanimePlaylistsPage> {
  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.api.sessionStore.isHanimeLoggedIn;
    return Scaffold(
      appBar: AppBar(title: const AppText('Hanime 播放列表')),
      body: !loggedIn
          ? const _HanimeSignedOut()
          : HanimePlaylistsView(api: widget.api),
    );
  }
}

class HanimePlaylistsView extends StatefulWidget {
  const HanimePlaylistsView({super.key, required this.api, this.active = true});

  final Rule34VideoApi api;
  final bool active;

  @override
  State<HanimePlaylistsView> createState() => _HanimePlaylistsViewState();
}

class _HanimePlaylistsViewState extends State<HanimePlaylistsView>
    with AutomaticKeepAliveClientMixin {
  Future<List<HanimePlaylist>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.active) _future = _load();
  }

  @override
  void didUpdateWidget(covariant HanimePlaylistsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && _future == null) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<List<HanimePlaylist>> _load() {
    return _loadAll();
  }

  Future<List<HanimePlaylist>> _loadAll() async {
    final result = <HanimePlaylist>[];
    final seen = <String>{};
    for (var page = 1; page <= 50; page += 1) {
      final items = await widget.api.hanime1Api.loadPlaylists(page);
      if (items.isEmpty) break;
      final added = items.where((item) => seen.add(item.listCode)).toList();
      if (added.isEmpty) break;
      result.addAll(added);
    }
    return result;
  }

  Future<void> _edit(HanimePlaylist playlist) async {
    final titleController = TextEditingController(text: playlist.title);
    final descriptionController = TextEditingController(
      text: playlist.description,
    );
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('编辑播放列表'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题'),
                maxLength: 100,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: '说明'),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('保存'),
            ),
          ],
        ),
      );
      final title = titleController.text.trim();
      if (submitted != true || title.isEmpty || !mounted) return;
      await widget.api.hanime1Api.updatePlaylist(
        playlist.listCode,
        title: title,
        description: descriptionController.text.trim(),
      );
      if (mounted) await _refresh();
    } finally {
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _delete(HanimePlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('删除播放列表？'),
        content: AppText('“${playlist.title}”及其列表关系将被删除，视频本身不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.api.hanime1Api.deletePlaylist(playlist.listCode);
    if (mounted) await _refresh();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder 展示具体错误，避免 RefreshIndicator 抛出未处理异常。
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<HanimePlaylist>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('播放列表加载失败：${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const AppText('重试'),
                ),
              ],
            ),
          );
        }
        final playlists = snapshot.data ?? const <HanimePlaylist>[];
        if (playlists.isEmpty) {
          return const Center(child: AppText('还没有播放列表。'));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            key: const PageStorageKey<String>('hanime-library-playlists'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: SiteAvatar(
                    radius: 24,
                    imageUrl: playlist.coverUrl,
                    fallbackIcon: Icons.playlist_play,
                    site: ContentSite.hanime1,
                  ),
                  title: Text(playlist.title),
                  subtitle: playlist.videoCount == null
                      ? null
                      : AppText('${playlist.videoCount} 部影片'),
                  trailing: PopupMenuButton<String>(
                    tooltip: '播放列表操作',
                    onSelected: (action) => switch (action) {
                      'edit' => _edit(playlist),
                      'delete' => _delete(playlist),
                      _ => null,
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: AppText('编辑')),
                      PopupMenuItem(value: 'delete', child: AppText('删除')),
                    ],
                  ),
                  onTap: () => context.pushNamed(
                    AppRouteNames.hanimePlaylist,
                    queryParameters: {'list': playlist.listCode},
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// 单个 Hanime1 播放列表内容页（公开可读，登录后可移除条目）。
class HanimePlaylistContentPage extends StatelessWidget {
  const HanimePlaylistContentPage({
    super.key,
    required this.api,
    required this.prefetch,
    required this.listCode,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final String listCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('播放列表')),
      body: VideoFeed(
        loadPage: (page) => prefetch.runForeground(
          PredictivePrefetchKey.libraryHanimePlaylist(listCode, page),
          () => api.hanime1Api.loadPlaylistVideos(listCode, page),
        ),
        onItemsLoaded: prefetch.offerLikelyVideos,
        prefetchService: prefetch,
        emptyMessage: '这个播放列表暂时没有视频。',
        showSearchAndFilters: true,
        searchHint: '搜索播放列表',
        filterOptions: const VideoListFilterOptions.hanime(),
        contextActionLabel: api.sessionStore.isHanimeLoggedIn
            ? '从播放列表移除'
            : null,
        onContextAction: api.sessionStore.isHanimeLoggedIn
            ? (video) => api.hanime1Api.removePlaylistVideo(listCode, video.id)
            : null,
      ),
    );
  }
}

class _HanimeSignedOut extends StatelessWidget {
  const _HanimeSignedOut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 52),
            const SizedBox(height: 16),
            AppText(
              '请先登录 Hanime',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const AppText(
              '登录后即可查看点赞、稍后观看、历史、播放列表和订阅。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
