import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/translation_service.dart';
import '../../shared/localized_translation_text.dart';
import '../../shared/site_avatar.dart';
import '../video/video_player_page.dart';

enum PlaylistPlaybackMode {
  sequence('顺序播放'),
  repeatOne('单集循环'),
  repeatAll('列表循环');

  const PlaylistPlaybackMode(this.label);

  final String label;
}

class PlaylistPlaybackRequest {
  const PlaylistPlaybackRequest({
    required this.playlist,
    required this.videos,
    required this.initialIndex,
    required this.nextPage,
    required this.hasMore,
  });

  final PlaylistItem playlist;
  final List<VideoItem> videos;
  final int initialIndex;
  final int nextPage;
  final bool hasMore;
}

class PlaylistPlaybackPage extends StatefulWidget {
  const PlaylistPlaybackPage({
    super.key,
    required this.api,
    required this.request,
    required this.translationService,
  });

  final Rule34VideoApi api;
  final PlaylistPlaybackRequest request;
  final TranslationService translationService;

  @override
  State<PlaylistPlaybackPage> createState() => _PlaylistPlaybackPageState();
}

class _PlaylistPlaybackPageState extends State<PlaylistPlaybackPage> {
  late final List<VideoItem> _videos;
  late int _index;
  late int _nextPage;
  late bool _hasMore;
  var _loadingMore = false;
  var _mode = PlaylistPlaybackMode.sequence;
  final Map<String, VideoDetails> _detailsCache = {};
  VideoDetails? _details;
  Object? _detailsError;
  var _loadingInitial = true;
  var _switchingVideo = false;
  final VideoPlayerHandle _playerHandle = VideoPlayerHandle();
  var _preloadOperation = 0;
  var _switchOperation = 0;

  VideoItem get _video => _videos[_index];

  @override
  void initState() {
    super.initState();
    _videos = List.of(widget.request.videos);
    _index = widget.request.initialIndex.clamp(0, _videos.length - 1);
    _nextPage = widget.request.nextPage;
    _hasMore = widget.request.hasMore;
    widget.translationService.addListener(_onTranslationChanged);
    unawaited(_loadInitial());
  }

  @override
  void didUpdateWidget(covariant PlaylistPlaybackPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translationService != widget.translationService) {
      oldWidget.translationService.removeListener(_onTranslationChanged);
      widget.translationService.addListener(_onTranslationChanged);
    }
  }

  void _onTranslationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitial() async {
    try {
      final details = await widget.api.loadVideoDetails(_video);
      if (!mounted) {
        return;
      }
      _detailsCache[_video.contentKey] = details;
      setState(() {
        _details = details;
        _detailsError = null;
        _loadingInitial = false;
      });
      unawaited(_preloadNext());
    } catch (error) {
      if (mounted) {
        setState(() {
          _detailsError = error;
          _loadingInitial = false;
        });
      }
    }
  }

  Future<void> _preloadNext() async {
    final operation = ++_preloadOperation;
    try {
      var next = _index + 1;
      if (next >= _videos.length && await _ensureNextLoaded()) {
        next = _index + 1;
      }
      if (next >= _videos.length &&
          _mode != PlaylistPlaybackMode.sequence &&
          _videos.length > 1) {
        next = 0;
      }
      if (next >= _videos.length || next == _index) {
        await _playerHandle.stopPreCache();
        return;
      }
      final details = await widget.api.loadVideoDetails(_videos[next]);
      if (!mounted || operation != _preloadOperation) {
        return;
      }
      _detailsCache[_videos[next].contentKey] = details;
      unawaited(_preloadLookAheadDetails(next, operation));
      await _playerHandle.preCache(details, aggressive: true);
    } on Object {
      // 预加载失败不影响当前视频，切换时仍会正常重试。
    }
  }

  Future<void> _preloadLookAheadDetails(int current, int operation) async {
    var lookAhead = current + 1;
    if (lookAhead >= _videos.length &&
        _mode != PlaylistPlaybackMode.sequence &&
        _videos.length > 2) {
      lookAhead = 0;
    }
    if (lookAhead >= _videos.length ||
        lookAhead == _index ||
        _detailsCache.containsKey(_videos[lookAhead].contentKey)) {
      return;
    }
    try {
      final details = await widget.api.loadVideoDetails(_videos[lookAhead]);
      if (mounted && operation == _preloadOperation) {
        _detailsCache[_videos[lookAhead].contentKey] = details;
      }
    } on Object {
      // 再下一条只预取详情，失败不影响播放。
    }
  }

  @override
  void dispose() {
    _preloadOperation += 1;
    widget.translationService.removeListener(_onTranslationChanged);
    unawaited(_playerHandle.stopPreCache());
    super.dispose();
  }

  Future<bool> _ensureNextLoaded() async {
    if (_index + 1 < _videos.length) {
      return true;
    }
    if (!_hasMore || _loadingMore) {
      return false;
    }
    _loadingMore = true;
    try {
      final page = await widget.api.loadPlaylistVideos(
        widget.request.playlist,
        _nextPage,
      );
      final newItems = page
          .where((item) => !_videos.any((saved) => saved.id == item.id))
          .toList(growable: false);
      if (!mounted) {
        return false;
      }
      setState(() {
        _videos.addAll(newItems);
        _nextPage += 1;
        _hasMore = page.isNotEmpty && newItems.isNotEmpty;
      });
      return _index + 1 < _videos.length;
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _next({bool automatic = false}) async {
    bool nextLoaded;
    try {
      nextLoaded = await _ensureNextLoaded();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('加载下一视频失败：$error')));
      }
      return;
    }
    if (nextLoaded) {
      await _setIndex(_index + 1);
      return;
    }
    if (_mode == PlaylistPlaybackMode.repeatAll && _videos.isNotEmpty) {
      await _setIndex(0);
      return;
    }
    if (!automatic && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('已经是播放列表最后一个视频。')));
    }
  }

  void _previous() {
    if (_index > 0) {
      unawaited(_setIndex(_index - 1));
    }
  }

  Future<void> _setIndex(int value) async {
    if (value == _index || _switchingVideo) {
      return;
    }
    final operation = ++_switchOperation;
    _preloadOperation += 1;
    unawaited(_playerHandle.stopPreCache());
    setState(() => _switchingVideo = true);
    try {
      final target = _videos[value];
      final details =
          _detailsCache[target.contentKey] ??
          await widget.api.loadVideoDetails(target);
      if (!mounted || operation != _switchOperation) {
        return;
      }
      _detailsCache[target.contentKey] = details;
      setState(() {
        _index = value;
        _details = details;
        _switchingVideo = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && operation == _switchOperation) {
          unawaited(_preloadNext());
        }
      });
    } catch (error) {
      if (mounted && operation == _switchOperation) {
        setState(() => _switchingVideo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('加载下一视频失败：$error')));
      }
    }
  }

  void _onFinished() {
    if (_mode != PlaylistPlaybackMode.repeatOne) {
      unawaited(_next(automatic: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details != null &&
        widget.translationService.shouldAutoTranslateTitle(
          details.video.id,
          details.video.title,
          siteId: details.video.siteId,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          widget.translationService.requestAutomaticTitle(
            videoId: details.video.id,
            raw: details.video.title,
            videoSlug: details.video.slug,
            siteId: details.video.siteId,
          ),
        );
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.playlist.title)),
      body: details == null
          ? _InitialPlaylistPlayerState(
              loading: _loadingInitial,
              error: _detailsError,
              onRetry: () {
                setState(() {
                  _loadingInitial = true;
                  _detailsError = null;
                });
                unawaited(_loadInitial());
              },
            )
          : Column(
              children: [
                Stack(
                  children: [
                    VideoPlayerPage(
                      api: widget.api,
                      video: details.video,
                      sources: details.sources,
                      embedded: true,
                      autoplay: true,
                      looping: _mode == PlaylistPlaybackMode.repeatOne,
                      resumePlayback: false,
                      onFinished: _onFinished,
                      handle: _playerHandle,
                    ),
                    if (_switchingVideo)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black26,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LocalizedTranslationText(
                              value: widget.translationService.resolveTitle(
                                details.video.id,
                                details.video.title,
                                siteId: details.video.siteId,
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_index + 1}/${_videos.length}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PlaylistPlaybackMode>(
                        segments: PlaylistPlaybackMode.values
                            .map(
                              (mode) => ButtonSegment(
                                value: mode,
                                label: AppText(mode.label),
                              ),
                            )
                            .toList(growable: false),
                        selected: {_mode},
                        onSelectionChanged: (selection) {
                          setState(() => _mode = selection.single);
                          unawaited(_preloadNext());
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: context.uiText('上一个'),
                            onPressed: _index > 0 ? _previous : null,
                            icon: const Icon(Icons.skip_previous),
                          ),
                          const SizedBox(width: 24),
                          IconButton.filledTonal(
                            tooltip: context.uiText('下一个'),
                            onPressed: _next,
                            icon: const Icon(Icons.skip_next),
                          ),
                        ],
                      ),
                      if (details.video.duration != null ||
                          details.video.views != null ||
                          details.video.rating != null ||
                          details.video.publishedLabel != null) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (details.video.duration != null)
                              _PlaylistStatChip(
                                icon: Icons.schedule,
                                label: details.video.duration!,
                              ),
                            if (details.video.views != null)
                              _PlaylistStatChip(
                                icon: Icons.visibility_outlined,
                                label: '${details.video.views} 次观看',
                              ),
                            if (details.video.rating != null)
                              _PlaylistStatChip(
                                icon: Icons.thumb_up_alt_outlined,
                                label: details.ratingVotes == null
                                    ? '${details.video.rating}%'
                                    : '${details.video.rating}% · ${details.ratingVotes} 票',
                              ),
                            if (details.video.publishedLabel != null)
                              _PlaylistStatChip(
                                icon: Icons.calendar_today_outlined,
                                label: details.video.publishedLabel!,
                              ),
                          ],
                        ),
                      ],
                      if (details.description != null &&
                          details.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          details.description!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (_metadataOf(
                        details,
                        DiscoveryKind.category,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PlaylistMetadataSection(
                          title: '分类',
                          items: _metadataOf(details, DiscoveryKind.category),
                          translationService: widget.translationService,
                          siteId: details.video.siteId,
                          onTap: _openMetadata,
                        ),
                      ],
                      if (_metadataOf(
                        details,
                        DiscoveryKind.tag,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PlaylistMetadataSection(
                          title: '标签',
                          items: _metadataOf(details, DiscoveryKind.tag),
                          translationService: widget.translationService,
                          siteId: details.video.siteId,
                          onTap: _openMetadata,
                        ),
                      ],
                      if (_metadataOf(
                        details,
                        DiscoveryKind.model,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PlaylistMetadataSection(
                          title: '艺术家',
                          items: _metadataOf(details, DiscoveryKind.model),
                          translationService: widget.translationService,
                          siteId: details.video.siteId,
                          onTap: _openMetadata,
                        ),
                      ],
                      if (details.uploader case final uploader?) ...[
                        const SizedBox(height: 16),
                        AppText(
                          '上传者',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: SiteAvatar(
                              imageUrl: uploader.avatarUrl,
                              fallbackIcon: Icons.person_outline,
                            ),
                            title: Row(
                              children: [
                                Flexible(child: Text(uploader.name)),
                                if (uploader.verified) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              context.pushNamed(
                                AppRouteNames.collection,
                                pathParameters: {
                                  'kind': DiscoveryKind.channel.name,
                                  'id': uploader.id,
                                },
                                extra: ContentCollectionItem(
                                  id: uploader.id,
                                  title: uploader.name,
                                  path: uploader.videosPath,
                                  kind: DiscoveryKind.channel,
                                  thumbnailUrl: uploader.avatarUrl,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<VideoMetadataItem> _metadataOf(
    VideoDetails details,
    DiscoveryKind kind,
  ) {
    return details.metadataItems
        .where((item) => item.kind == kind)
        .toList(growable: false);
  }

  void _openMetadata(VideoMetadataItem item) {
    final collection = item.collection;
    context.pushNamed(
      AppRouteNames.collection,
      pathParameters: {'kind': collection.kind.name, 'id': collection.id},
      extra: collection,
    );
  }
}

class _PlaylistStatChip extends StatelessWidget {
  const _PlaylistStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PlaylistMetadataSection extends StatelessWidget {
  const _PlaylistMetadataSection({
    required this.title,
    required this.items,
    required this.translationService,
    required this.siteId,
    required this.onTap,
  });

  final String title;
  final List<VideoMetadataItem> items;
  final TranslationService translationService;
  final String siteId;
  final ValueChanged<VideoMetadataItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) {
                final translated = translationService.resolveMetadata(
                  item.kind,
                  item.title,
                  siteId: siteId,
                );
                return ActionChip(
                  avatar: item.kind == DiscoveryKind.tag
                      ? const Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                  label: LocalizedTranslationText(
                    value: translated,
                    style: theme.textTheme.bodyMedium,
                  ),
                  onPressed: () => onTap(item),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _InitialPlaylistPlayerState extends StatelessWidget {
  const _InitialPlaylistPlayerState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              error?.toString() ?? '加载视频失败。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const AppText('重试')),
          ],
        ),
      ),
    );
  }
}
