import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/content_source.dart';
import '../../core/models/hanime_search_models.dart';
import '../../core/models/hanime_playlist_models.dart';
import '../../core/models/video_models.dart';
import '../../core/services/share_service.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_card.dart';
import '../../shared/video_collection_layout.dart';
import '../../shared/scroll_to_top_overlay.dart';
import '../../shared/editable_translation.dart';
import '../../shared/localized_translation_text.dart';
import '../../shared/site_avatar.dart';
import '../../shared/transient_focus.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import 'hanime_comments_section.dart';
import 'rule34_comments_section.dart';
import '../library/data/local_library_repository.dart';
import '../library/local_library_picker.dart';
import '../library/playlist_picker.dart';
import '../settings/data/app_settings_repository.dart';
import '../settings/domain/quality_selection.dart';
import '../settings/domain/app_settings.dart';
import 'video_player_page.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.api,
    required this.video,
    this.playerHandle,
  });

  final Rule34VideoApi api;
  final VideoItem video;
  final VideoPlayerHandle? playerHandle;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage>
    with RouteAware {
  late Future<VideoDetails> _detailsFuture;
  late final VideoPlayerHandle _playerHandle;
  late final bool _ownsPlayerHandle;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _ownsPlayerHandle = widget.playerHandle == null;
    _playerHandle = widget.playerHandle ?? VideoPlayerHandle();
    _detailsFuture = _loadDetails();
  }

  @override
  void didUpdateWidget(covariant VideoDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.video.id != widget.video.id) {
      _detailsFuture = _loadDetails();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (shouldPauseVideoForRoutePush(_playerHandle.isFullScreen)) {
      _playerHandle.pause();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    if (_ownsPlayerHandle) _playerHandle.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _detailsFuture = _loadDetails(force: true);
    });
  }

  Future<VideoDetails> _loadDetails({bool force = false}) async {
    try {
      final details = await ref
          .read(predictivePrefetchServiceProvider)
          .runForeground(
            PredictivePrefetchKey.video(
              widget.video.id,
              siteId: widget.video.siteId,
            ),
            () => force
                ? widget.api.refreshVideoDetails(widget.video)
                : widget.api.loadVideoDetails(widget.video),
            resumeDelay: const Duration(seconds: 3),
          );
      return details;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: FutureBuilder<VideoDetails>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _DetailLoading(video: widget.video);
            }
            if (snapshot.hasError) {
              return _DetailLoadError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            return _VideoDetailsBody(
              api: widget.api,
              details: snapshot.requireData,
              downloads: ref.watch(downloadRepositoryProvider),
              settings: ref.watch(appSettingsRepositoryProvider),
              shareService: ref.watch(shareServiceProvider),
              translationService: ref.read(translationServiceProvider),
              playerHandle: _playerHandle,
              localLibraryRepository: ref.watch(localLibraryRepositoryProvider),
              scrollToTopController: ref.watch(scrollToTopControllerProvider),
            );
          },
        ),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = video.thumbnailUrl;
    return Align(
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  // 按站点使用正确的 Referer，避免 hanime 缩略图被拒。
                  httpHeaders: video.site.mediaHeaders(),
                  fit: BoxFit.cover,
                  errorWidget: (context, _, _) => const SizedBox.shrink(),
                ),
              const ColoredBox(color: Colors.black38),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool shouldPauseVideoForRoutePush(bool isFullScreen) => !isFullScreen;

class _DetailLoadError extends StatelessWidget {
  const _DetailLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            AppText(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const AppText('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailsBody extends StatefulWidget {
  const _VideoDetailsBody({
    required this.api,
    required this.details,
    required this.downloads,
    required this.settings,
    required this.shareService,
    required this.translationService,
    required this.playerHandle,
    required this.localLibraryRepository,
    required this.scrollToTopController,
  });

  final Rule34VideoApi api;
  final VideoDetails details;
  final DownloadRepository downloads;
  final AppSettingsRepository settings;
  final ShareService shareService;
  final TranslationService translationService;
  final VideoPlayerHandle playerHandle;
  final LocalLibraryRepository localLibraryRepository;
  final ScrollToTopController scrollToTopController;

  @override
  State<_VideoDetailsBody> createState() => _VideoDetailsBodyState();
}

class _VideoDetailsBodyState extends State<_VideoDetailsBody>
    with TickerProviderStateMixin {
  late VideoDetails _details;
  late final TabController _tabController;
  late final AnimationController _playerExpandController;
  final GlobalKey<NestedScrollViewState> _detailScrollKey =
      GlobalKey<NestedScrollViewState>();
  final ScrollController _detailScrollController = ScrollController();
  final GlobalKey<SelectionAreaState> _descriptionSelectionKey =
      GlobalKey<SelectionAreaState>();
  late bool _favorite;
  late bool _hanimeLiked;
  late bool _hanimeSaved;
  late bool _hanimeRatedNegative;
  late int _hanimeLikes;
  late int _hanimeDislikes;
  late bool _hanimeUploaderSubscribed;
  final Set<String> _subscriptionPaths = {};
  final Set<String> _updatingMetadata = {};
  var _updatingFavorite = false;
  var _updatingHanimeLike = false;
  var _updatingHanimeSaved = false;
  var _addingDownload = false;
  var _addingPlaylist = false;
  var _updatingHanimeRating = false;
  var _updatingHanimeSubscription = false;
  var _loadingSubscriptions = false;
  var _subscriptionsLoaded = false;
  var _playerRegionCollapsed = false;
  var _playerAutoExpanding = false;
  var _playerExpandGeneration = 0;
  var _lastCanCollapse = false;
  AnimationController? _scrollToTopAnimation;
  DateTime? _lastLockedOverscrollLogAt;
  double _lockedOverscrollDistance = 0;
  ScrollHoldController? _playerExpandHold;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _playerExpandController = AnimationController.unbounded(vsync: this);
    _detailScrollController.addListener(_onDetailScroll);
    widget.scrollToTopController.addListener(_onScrollToTopControllerChanged);
    widget.playerHandle.canCollapseDetailsListenable.addListener(
      _onPlayerCollapsePermissionChanged,
    );
    _details = widget.details;
    widget.scrollToTopController.setHandler(_scrollDetailsToTop);
    _lastCanCollapse = widget.playerHandle.canCollapseDetails;
    _favorite = widget.details.isFavorite;
    _hanimeLiked = widget.details.hanimeLiked;
    _hanimeSaved = widget.details.isSaved;
    _syncHanimeDetails(widget.details);
    if (_details.video.site.capabilities.subscriptions &&
        widget.api.sessionStore.isLoggedIn) {
      _loadSubscriptions();
    }
  }

  @override
  void dispose() {
    _playerExpandGeneration += 1;
    _playerExpandController.dispose();
    _scrollToTopAnimation?.dispose();
    _scrollToTopAnimation = null;
    _playerExpandHold?.cancel();
    _playerExpandHold = null;
    widget.playerHandle.canCollapseDetailsListenable.removeListener(
      _onPlayerCollapsePermissionChanged,
    );
    _detailScrollController
      ..removeListener(_onDetailScroll)
      ..dispose();
    widget.scrollToTopController.removeListener(
      _onScrollToTopControllerChanged,
    );
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    widget.scrollToTopController.setHandler(null);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _VideoDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerHandle != widget.playerHandle) {
      oldWidget.playerHandle.canCollapseDetailsListenable.removeListener(
        _onPlayerCollapsePermissionChanged,
      );
      widget.playerHandle.canCollapseDetailsListenable.addListener(
        _onPlayerCollapsePermissionChanged,
      );
    }
    if (oldWidget.details != widget.details) {
      _details = widget.details;
      if (!_updatingFavorite) {
        _favorite = widget.details.isFavorite;
      }
      if (!_updatingHanimeLike) {
        _hanimeLiked = widget.details.hanimeLiked;
      }
      if (!_updatingHanimeSaved) {
        _hanimeSaved = widget.details.isSaved;
      }
      if (!_updatingHanimeRating && !_updatingHanimeSubscription) {
        _syncHanimeDetails(widget.details);
      }
    }
    if (oldWidget.scrollToTopController != widget.scrollToTopController) {
      oldWidget.scrollToTopController.setHandler(null);
      oldWidget.scrollToTopController.removeListener(
        _onScrollToTopControllerChanged,
      );
      widget.scrollToTopController.addListener(_onScrollToTopControllerChanged);
      widget.scrollToTopController.setHandler(_scrollDetailsToTop);
    }
  }

  void _syncHanimeDetails(VideoDetails details) {
    _hanimeLiked = details.hanimeLiked;
    _hanimeRatedNegative = details.hanimeDisliked;
    _hanimeLikes = details.hanimeLikes;
    _hanimeDislikes = details.hanimeDislikes;
    _hanimeUploaderSubscribed = details.isUploaderSubscribed;
  }

  Future<void> _scrollDetailsToTop() async {
    unawaited(
      AppLogService.instance.info(
        '置顶处理开始；video=${_details.video.id}；'
        'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}；'
        'playing=${widget.playerHandle.isPlaying}；'
        'canCollapse=${widget.playerHandle.canCollapseDetails}',
        component: 'video_detail_scroll',
      ),
    );
    _stopPlayerAutoExpand();
    if (!_detailScrollController.hasClients) return;
    final outer = _detailScrollController.position;
    final outerStart = outer.pixels - outer.minScrollExtent;
    final innerPosition = _activeInnerPosition();
    final innerStart = innerPosition == null
        ? 0.0
        : innerPosition.pixels - innerPosition.minScrollExtent;

    // While the player is active the header is deliberately locked. Animating
    // both nested positions here makes NestedScrollView transfer deltas back
    // and forth, producing the collapse/expand oscillation seen in diagnostics.
    // Keep the header at its current unlocked position and animate only the
    // visible tab's content.
    if (widget.playerHandle.isPlaying || widget.playerHandle.isBuffering) {
      if (outerStart > 0.5) {
        outer.jumpTo(outer.minScrollExtent);
      }
      if (innerPosition != null && innerStart > 0.5) {
        await innerPosition.animateTo(
          innerPosition.minScrollExtent,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
      unawaited(
        AppLogService.instance.info(
          '置顶处理完成；video=${_details.video.id}；'
          'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}；'
          'playing=${widget.playerHandle.isPlaying}；'
          'canCollapse=${widget.playerHandle.canCollapseDetails}',
          component: 'video_detail_scroll',
        ),
      );
      return;
    }

    final innerDistance = innerStart;
    final totalDistance = innerDistance + outerStart;
    if (totalDistance > 0.5) {
      final oldAnimation = _scrollToTopAnimation;
      final animation = AnimationController.unbounded(vsync: this);
      _scrollToTopAnimation = animation;
      oldAnimation?.dispose();
      void applyOffsets() {
        final travelled = animation.value;
        if (innerPosition != null && innerPosition.hasPixels) {
          final target = innerPosition.minScrollExtent +
              math.max(0, innerStart - travelled);
          if ((innerPosition.pixels - target).abs() >
              precisionErrorTolerance) {
            innerPosition.jumpTo(target);
          }
        }
        if (!outer.hasPixels) return;
        final outerTravelled = math.max(0, travelled - innerDistance);
        final target =
            outer.minScrollExtent + math.max(0, outerStart - outerTravelled);
        if ((outer.pixels - target).abs() > precisionErrorTolerance) {
          outer.jumpTo(target);
        }
      }

      animation.addListener(applyOffsets);
      final durationMs = (280 + totalDistance * 0.18).round().clamp(320, 650);
      try {
        await animation.animateTo(
          totalDistance,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOutCubic,
        );
        applyOffsets();
      } on TickerCanceled {
        return;
      } finally {
        animation.removeListener(applyOffsets);
        if (identical(_scrollToTopAnimation, animation)) {
          _scrollToTopAnimation = null;
          animation.dispose();
        }
      }
    }
    unawaited(
      AppLogService.instance.info(
        '置顶处理完成；video=${_details.video.id}；'
        'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}；'
        'playing=${widget.playerHandle.isPlaying}；'
        'canCollapse=${widget.playerHandle.canCollapseDetails}',
        component: 'video_detail_scroll',
      ),
    );
  }

  ScrollPosition? _activeInnerPosition() {
    final controller = _detailScrollKey.currentState?.innerController;
    if (controller == null || !controller.hasClients) return null;
    final positions = controller.positions.toList(growable: false);
    if (positions.isEmpty) return null;
    final index = _tabController.index;
    return index < positions.length ? positions[index] : positions.first;
  }

  void _onPlayerCollapsePermissionChanged() {
    final canCollapse = widget.playerHandle.canCollapseDetails;
    final wasCollapsible = _lastCanCollapse;
    _lastCanCollapse = canCollapse;
    unawaited(
      AppLogService.instance.info(
        '播放器折叠权限更新；video=${_details.video.id}；'
        'canCollapse=$canCollapse；'
        'playing=${widget.playerHandle.isPlaying}；'
        'buffering=${widget.playerHandle.isBuffering}；'
        'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}',
        component: 'video_detail_scroll',
      ),
    );
    if (canCollapse) {
      _stopPlayerAutoExpand();
      return;
    }
    if (!widget.playerHandle.isPlaying && !widget.playerHandle.isBuffering) {
      return;
    }
    if (!wasCollapsible) return;
    if (_detailScrollController.hasClients) {
      _startPlayerAutoExpand();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.playerHandle.canCollapseDetails) {
        _startPlayerAutoExpand();
      }
    });
  }

  String _outerOffsetLabel() => _detailScrollController.hasClients
      ? _detailScrollController.offset.toStringAsFixed(1)
      : '未挂载';

  String _innerOffsetLabel() {
    final state = _detailScrollKey.currentState;
    if (state == null || !state.innerController.hasClients) return '未挂载';
    return state.innerController.positions
        .map((position) => position.pixels.toStringAsFixed(1))
        .join(',');
  }

  void _startPlayerAutoExpand() {
    if (!_detailScrollController.hasClients || _playerAutoExpanding) return;
    final position = _detailScrollController.position;
    final start = position.pixels.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (start <= 0.5) return;

    final generation = ++_playerExpandGeneration;
    final innerBefore = _innerOffsetLabel();
    _playerExpandHold = position.hold(() {
      _playerExpandHold = null;
    });
    _playerExpandController.value = start;
    setState(() => _playerAutoExpanding = true);
    unawaited(
      AppLogService.instance.info(
        '恢复播放，开始自动展开播放器；video=${_details.video.id}；'
        'outer=${start.toStringAsFixed(1)}；inner=$innerBefore',
        component: 'video_detail_scroll',
      ),
    );

    unawaited(
      _playerExpandController
          .animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .then((_) async {
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted || generation != _playerExpandGeneration) return;
            setState(() => _playerAutoExpanding = false);
            _releasePlayerExpandHold();
            unawaited(
              AppLogService.instance.info(
                '播放器自动展开完成；video=${_details.video.id}；'
                'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}；'
                'innerBefore=$innerBefore',
                component: 'video_detail_scroll',
              ),
            );
          }),
    );
  }

  void _stopPlayerAutoExpand() {
    if (!_playerAutoExpanding) return;
    _playerExpandGeneration += 1;
    _playerExpandController.stop();
    setState(() => _playerAutoExpanding = false);
    _releasePlayerExpandHold();
  }

  void _releasePlayerExpandHold() {
    final hold = _playerExpandHold;
    _playerExpandHold = null;
    hold?.cancel();
  }

  void _onDetailScroll() {
    if (!_detailScrollController.hasClients) return;
    if (widget.scrollToTopController.suppressed) {
      // Focus/keyboard changes must not change the player's current folded state.
      // NestedScrollView may emit a metrics update while the composer is opening;
      // treating it as a real user scroll would expand the header unexpectedly.
      _stopPlayerAutoExpand();
      return;
    }
    final collapsed = _detailScrollController.offset > 96;
    if (collapsed == _playerRegionCollapsed) return;
    _playerRegionCollapsed = collapsed;
    unawaited(
      AppLogService.instance.info(
        '播放器区域${collapsed ? '开始折叠' : '已展开'}；'
        'video=${_details.video.id}；'
        'canCollapse=${widget.playerHandle.canCollapseDetails}；'
        'playing=${widget.playerHandle.isPlaying}；'
        'buffering=${widget.playerHandle.isBuffering}；'
        'outer=${_outerOffsetLabel()}；inner=${_innerOffsetLabel()}；'
        'autoExpanding=$_playerAutoExpanding',
        component: 'video_detail_scroll',
      ),
    );
  }

  void _onScrollToTopControllerChanged() {
    if (!mounted) return;
    if (widget.scrollToTopController.suppressed) {
      _stopPlayerAutoExpand();
    }
  }

  bool _onDetailScrollNotification(ScrollNotification notification) {
    if (notification is! OverscrollNotification ||
        widget.playerHandle.canCollapseDetails) {
      return false;
    }
    _lockedOverscrollDistance += notification.overscroll.abs();
    final now = DateTime.now();
    final lastLogAt = _lastLockedOverscrollLogAt;
    if (lastLogAt == null ||
        now.difference(lastLogAt) >= const Duration(milliseconds: 700)) {
      _lastLockedOverscrollLogAt = now;
      final distance = _lockedOverscrollDistance;
      _lockedOverscrollDistance = 0;
      unawaited(
        AppLogService.instance.info(
          '播放态详情滚动触发边界反馈，已禁用视觉拉伸；video=${_details.video.id}；'
          'distance=${distance.toStringAsFixed(1)}；outer=${_outerOffsetLabel()}；'
          'inner=${_innerOffsetLabel()}',
          component: 'video_detail_overscroll',
        ),
      );
    }
    return false;
  }

  Future<bool> _ensureLogin() async {
    if (widget.api.sessionStore.isLoggedIn) {
      return true;
    }
    return showLoginSheet(context, widget.api);
  }

  Future<bool> _loadSubscriptions({bool showError = false}) async {
    if (!_details.video.site.capabilities.subscriptions ||
        !widget.api.sessionStore.isLoggedIn ||
        _loadingSubscriptions) {
      return _subscriptionsLoaded;
    }
    setState(() => _loadingSubscriptions = true);
    try {
      final subscriptions = await widget.api.loadSubscriptions();
      if (!mounted) {
        return false;
      }
      setState(() {
        _subscriptionPaths
          ..clear()
          ..addAll(subscriptions.map((item) => item.path));
        _subscriptionsLoaded = true;
      });
      return true;
    } catch (error) {
      if (mounted && showError) {
        _showMessage(error.toString());
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _loadingSubscriptions = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_updatingFavorite) {
      return;
    }
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    final previous = _favorite;
    final next = !previous;
    setState(() {
      _updatingFavorite = true;
      _favorite = next;
    });
    try {
      await widget.api.toggleFavorite(video: _details.video, add: next);
    } catch (error) {
      if (mounted) {
        setState(() => _favorite = previous);
        _showMessage('同步失败，已恢复原状态：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingFavorite = false);
      }
    }
  }

  /// Hanime 点赞/取消点赞（需登录 Hanime；未登录先弹登录页）。
  Future<void> _toggleHanimeLike() async {
    if (_updatingHanimeLike) {
      return;
    }
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
      return;
    }
    final previousLiked = _hanimeLiked;
    final previousDisliked = _hanimeRatedNegative;
    final previousLikes = _hanimeLikes;
    final previousDislikes = _hanimeDislikes;
    final next = !previousLiked;
    setState(() {
      _updatingHanimeLike = true;
      _hanimeLiked = next;
      if (next && _hanimeRatedNegative) {
        _hanimeRatedNegative = false;
        _hanimeDislikes = (_hanimeDislikes - 1).clamp(0, 1 << 31);
      }
      _hanimeLikes = (_hanimeLikes + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    try {
      await widget.api.setHanimeLike(
        _details.video,
        liked: next,
        current: previousLiked,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _hanimeLiked = previousLiked;
          _hanimeRatedNegative = previousDisliked;
          _hanimeLikes = previousLikes;
          _hanimeDislikes = previousDislikes;
        });
        _showMessage('同步失败，已恢复原状态：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingHanimeLike = false);
      }
    }
  }

  Future<void> _toggleHanimeSaved() async {
    if (_updatingHanimeSaved) return;
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
      return;
    }
    final previous = _hanimeSaved;
    final next = !previous;
    setState(() {
      _updatingHanimeSaved = true;
      _hanimeSaved = next;
    });
    try {
      await widget.api.setHanimeSaved(
        _details.video,
        saved: next,
        current: previous,
      );
      if (mounted) {
        _showMessage(_hanimeSaved ? '已加入稍后观看。' : '已移出稍后观看。');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _hanimeSaved = previous);
        _showMessage('同步失败，已恢复原状态：$error');
      }
    } finally {
      if (mounted) setState(() => _updatingHanimeSaved = false);
    }
  }

  Future<void> _rateHanime(bool positive) async {
    if (_updatingHanimeRating) return;
    if (positive) {
      await _toggleHanimeLike();
      return;
    }
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
      return;
    }
    final previousLiked = _hanimeLiked;
    final previousDisliked = _hanimeRatedNegative;
    final previousLikes = _hanimeLikes;
    final previousDislikes = _hanimeDislikes;
    final next = !previousDisliked;
    setState(() {
      _updatingHanimeRating = true;
      _hanimeRatedNegative = next;
      _hanimeDislikes = (_hanimeDislikes + (next ? 1 : -1)).clamp(0, 1 << 31);
      if (next && _hanimeLiked) {
        _hanimeLiked = false;
        _hanimeLikes = (_hanimeLikes - 1).clamp(0, 1 << 31);
      }
    });
    try {
      await widget.api.setHanimeDislike(
        _details.video,
        disliked: next,
        current: previousDisliked,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _hanimeLiked = previousLiked;
          _hanimeRatedNegative = previousDisliked;
          _hanimeLikes = previousLikes;
          _hanimeDislikes = previousDislikes;
        });
        _showMessage('同步失败，已恢复原状态：$error');
      }
    } finally {
      if (mounted) setState(() => _updatingHanimeRating = false);
    }
  }

  Future<void> _toggleHanimeArtistSubscription() async {
    if (_updatingHanimeSubscription) return;
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
      return;
    }
    final previous = _hanimeUploaderSubscribed;
    final next = !previous;
    setState(() {
      _updatingHanimeSubscription = true;
      _hanimeUploaderSubscribed = next;
    });
    try {
      final artist = _details.metadataItems
          .where((item) => item.kind == DiscoveryKind.model)
          .firstOrNull;
      await widget.api.setHanimeArtistSubscribed(
        _details.video.id,
        artistKey: artist?.id ?? artist?.title ?? _details.video.id,
        subscribed: next,
        current: previous,
      );
      if (mounted) {
        _showMessage(next ? '已订阅艺术家。' : '已取消订阅艺术家。');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _hanimeUploaderSubscribed = previous);
        _showMessage('同步失败，已恢复原状态：$error');
      }
    } finally {
      if (mounted) setState(() => _updatingHanimeSubscription = false);
    }
  }

  Future<void> _manageHanimePlaylists() async {
    if (_addingPlaylist) return;
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
      return;
    }
    setState(() => _addingPlaylist = true);
    try {
      final playlists = <HanimePlaylist>[];
      final seenPlaylists = <String>{};
      for (var page = 1; page <= 50; page += 1) {
        final items = await widget.api.hanime1Api.loadPlaylists(page);
        if (items.isEmpty) break;
        final added = items
            .where((item) => seenPlaylists.add(item.listCode))
            .toList();
        if (added.isEmpty) break;
        playlists.addAll(added);
      }
      if (!mounted) return;
      final original = Set<String>.of(_details.playlistIds);
      final selected = Set<String>.of(original);
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('管理播放列表'),
            content: SizedBox(
              width: double.maxFinite,
              child: playlists.isEmpty
                  ? const AppText('还没有播放列表，可先新建一个。')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final playlist in playlists)
                          CheckboxListTile(
                            value: selected.contains(playlist.listCode),
                            title: Text(playlist.title),
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                selected.add(playlist.listCode);
                              } else {
                                selected.remove(playlist.listCode);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, const {'__create__'}),
                child: const AppText('新建'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const AppText('保存'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || result == null) return;
      if (result.contains('__create__')) {
        await _createHanimePlaylist();
        return;
      }
      for (final playlist in playlists) {
        final wasIncluded = original.contains(playlist.listCode);
        final included = result.contains(playlist.listCode);
        if (wasIncluded != included) {
          await widget.api.hanime1Api.setPlaylistMembership(
            _details.video.id,
            playlist.listCode,
            included: included,
          );
        }
      }
      if (mounted) {
        setState(() => _details = _details.copyWith(playlistIds: result));
        _showMessage('播放列表已更新。');
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _addingPlaylist = false);
    }
  }

  Future<void> _createHanimePlaylist() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('新建播放列表'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '说明'),
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
              child: const AppText('创建'),
            ),
          ],
        ),
      );
      final title = titleController.text.trim();
      if (submitted != true || title.isEmpty) return;
      await widget.api.hanime1Api.createPlaylist(
        videoId: _details.video.id,
        title: title,
        description: descriptionController.text.trim(),
      );
      if (mounted) _showMessage('播放列表已创建并加入当前视频。');
    } finally {
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _download() async {
    if (_addingDownload) {
      return;
    }
    final preferences = widget.settings.settings;
    final source = preferences.askDownloadQuality
        ? await runWithoutRestoringInputFocus(
            context,
            () => showModalBottomSheet<VideoSource>(
              context: context,
              requestFocus: false,
              useSafeArea: true,
              builder: (context) {
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: AppText(
                        '选择下载清晰度',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    // 源列表已统一为高清晰度在上，直接展示。
                    for (final item in _details.sources)
                      ListTile(
                        leading: Icon(item.isHd ? Icons.hd : Icons.sd),
                        title: AppText(item.label),
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                  ],
                );
              },
            ),
          )
        : selectVideoSource(_details.sources, preferences.downloadQuality);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _addingDownload = true);
    try {
      await widget.downloads.enqueueVideo(details: _details, source: source);
      if (mounted) {
        _showMessage('${source.label} 已加入下载队列。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _addingDownload = false);
      }
    }
  }

  Future<void> _share() async {
    try {
      await widget.shareService.shareVideo(_details.video);
    } catch (error) {
      if (mounted) {
        _showMessage('无法打开分享面板：$error');
      }
    }
  }

  Future<void> _addToLocalLibrary() async {
    try {
      final message = await manageVideoLocalLibraries(
        context: context,
        repository: widget.localLibraryRepository,
        video: _details.video,
      );
      if (message != null && mounted) {
        _showMessage(message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _addToPlaylist() async {
    if (_addingPlaylist || !await _ensureLogin() || !mounted) {
      return;
    }
    setState(() => _addingPlaylist = true);
    try {
      final message = await manageVideoAccountPlaylists(
        context: context,
        api: widget.api,
        video: _details.video,
      );
      if (message != null && mounted) {
        _showMessage(message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _addingPlaylist = false);
      }
    }
  }

  Future<void> _openMetadataActions(VideoMetadataItem item) async {
    final capabilities = _details.video.site.capabilities;
    if (!capabilities.metadataCollections && !capabilities.subscriptions) {
      return;
    }
    final subscribed = _subscriptionPaths.contains(item.path);
    final action = await runWithoutRestoringInputFocus(
      context,
      () => showModalBottomSheet<_MetadataAction>(
        context: context,
        requestFocus: false,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              if (capabilities.metadataCollections)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: AppText('打开${item.kind.label}集合'),
                  onTap: () => Navigator.pop(context, _MetadataAction.open),
                ),
              if (capabilities.subscriptions && item.canSubscribe)
                ListTile(
                  leading: Icon(
                    subscribed
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  title: AppText(subscribed ? '取消订阅' : '订阅'),
                  onTap: () =>
                      Navigator.pop(context, _MetadataAction.subscription),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MetadataAction.open:
        final collection = item.collection;
        context.pushNamed(
          AppRouteNames.collection,
          pathParameters: {'kind': collection.kind.name, 'id': collection.id},
          extra: collection,
        );
      case _MetadataAction.subscription:
        await _toggleSubscription(item);
    }
  }

  /// Hanime 站点：元数据直接跳转 hanime 搜索页（标签/艺术家按文本搜索，
  /// 分类作为 genre 筛选条件），与 rule34video 的集合页语义区分。
  void _openHanimeMetadata(VideoMetadataItem item) {
    unawaited(
      AppLogService.instance.info(
        'Hanime 详情页元数据点击；kind=${item.kind.name}；'
        'valueLength=${item.title.length}',
        component: 'hanime_metadata',
      ),
    );
    final isCategory = item.kind == DiscoveryKind.category;
    final isArtist = item.kind == DiscoveryKind.model;
    context.pushNamed(
      AppRouteNames.search,
      extra: HanimeSearchLaunch(
        query: isCategory || isArtist ? '' : item.title,
        filters: isCategory
            ? HanimeSearchFilters(genre: item.title)
            : isArtist
            ? HanimeSearchFilters(brands: {item.title})
            : const HanimeSearchFilters(),
      ),
    );
  }

  Future<void> _openHanimeMetadataActions(VideoMetadataItem item) async {
    if (item.kind != DiscoveryKind.model) {
      _openHanimeMetadata(item);
      return;
    }
    final action = await runWithoutRestoringInputFocus(
      context,
      () => showModalBottomSheet<_MetadataAction>(
        context: context,
        requestFocus: false,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const AppText('打开艺术家视频'),
                onTap: () => Navigator.pop(context, _MetadataAction.open),
              ),
              ListTile(
                leading: Icon(
                  _hanimeUploaderSubscribed
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                ),
                title: AppText(_hanimeUploaderSubscribed ? '取消订阅' : '订阅'),
                onTap: () =>
                    Navigator.pop(context, _MetadataAction.subscription),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _MetadataAction.open:
        _openHanimeMetadata(item);
      case _MetadataAction.subscription:
        await _toggleHanimeArtistSubscription();
    }
  }

  /// 按站点分发元数据点击行为：hanime 跳转搜索页，其余走集合/订阅菜单。
  ValueChanged<VideoMetadataItem>? _metadataOnTap(VideoDetails details) {
    if (details.video.site == ContentSite.hanime1) {
      return _openHanimeMetadataActions;
    }
    final capabilities = details.video.site.capabilities;
    if (!capabilities.metadataCollections && !capabilities.subscriptions) {
      return null;
    }
    return _openMetadataActions;
  }

  Future<void> _toggleSubscription(VideoMetadataItem item) async {
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    if (!_subscriptionsLoaded && !await _loadSubscriptions(showError: true)) {
      return;
    }
    final key = 'subscribe:${item.kind.name}:${item.id}';
    if (_updatingMetadata.contains(key)) {
      return;
    }
    final subscribed = _subscriptionPaths.contains(item.path);
    setState(() => _updatingMetadata.add(key));
    try {
      await widget.api.toggleSubscription(
        video: _details.video,
        item: item,
        subscribe: !subscribed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (subscribed) {
          _subscriptionPaths.remove(item.path);
        } else {
          _subscriptionPaths.add(item.path);
        }
      });
      _showMessage(subscribed ? '已取消订阅。' : '已订阅。');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _updatingMetadata.remove(key));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message)));
  }

  void _clearDescriptionSelection() {
    _descriptionSelectionKey.currentState?.selectableRegion.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (widget.translationService.shouldAutoTranslateTitle(
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
    final metadata = details.metadataItems;
    final player = details.sources.isNotEmpty
        ? VideoPlayerPage(
            api: widget.api,
            video: details.video,
            sources: details.sources,
            embedded: true,
            autoplay: true,
            handle: widget.playerHandle,
          )
        : const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: AppText(
                  '此视频未提供可直接播放的 MP4 源。',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
    final tabs = Material(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        labelStyle: Theme.of(context).textTheme.labelLarge,
        tabs: const [
          Tab(
            height: _VideoDetailHeaderDelegate.tabsHeight,
            child: AppText('简介'),
          ),
          Tab(
            height: _VideoDetailHeaderDelegate.tabsHeight,
            child: AppText('评论'),
          ),
        ],
      ),
    );
    final nestedScrollView = NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onDetailScrollNotification,
        child: NestedScrollView(
          key: _detailScrollKey,
          controller: _detailScrollController,
          physics: _PlayerHeaderGatePhysics(
            playing: widget.playerHandle.playingListenable,
            buffering: widget.playerHandle.bufferingListenable,
            scrollToTopController: widget.scrollToTopController,
            parent: const ClampingScrollPhysics(),
          ),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverPersistentHeader(
              pinned: true,
              delegate: _VideoDetailHeaderDelegate(
                player: KeyedSubtree(
                  key: const ValueKey('video-detail-player-region'),
                  child: player,
                ),
                tabs: tabs,
                playerHeight: MediaQuery.sizeOf(context).width * 9 / 16,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _clearDescriptionSelection,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              key: const ValueKey(
                                'video-detail-title-translation-region',
                              ),
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => showTitleTranslationEditDialog(
                                context,
                                translationService: widget.translationService,
                                videoId: details.video.id,
                                english: details.video.title,
                                videoSlug: details.video.slug,
                                siteId: details.video.siteId,
                              ),
                              child: ListenableBuilder(
                                listenable: widget.translationService,
                                builder: (context, _) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: LocalizedTranslationText(
                                    value: widget.translationService.resolveTitle(
                                      details.video.id,
                                      details.video.title,
                                      siteId: details.video.siteId,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (details.video.duration != null)
                                _StatChip(
                                  icon: Icons.schedule,
                                  label: details.video.duration!,
                                ),
                              if (details.video.site != ContentSite.hanime1 &&
                                  details.video.views != null)
                                _StatChip(
                                  icon: Icons.visibility_outlined,
                                  label: '${details.video.views} 次观看',
                                ),
                              if (details.video.rating != null)
                                _StatChip(
                                  icon: Icons.thumb_up_alt_outlined,
                                  label: details.ratingVotes == null
                                      ? '${details.video.rating}%'
                                      : '${details.video.rating}% · ${details.ratingVotes} 票',
                                ),
                              if (details.video.site != ContentSite.hanime1 &&
                                  details.video.publishedLabel != null)
                                _StatChip(
                                  icon: Icons.calendar_today_outlined,
                                  label: details.video.publishedLabel!,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (details.video.site == ContentSite.hanime1)
                                _ActionButton(
                                  icon: _hanimeLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  label:
                                      '${_hanimeLiked ? '已点赞' : '点赞'} · $_hanimeLikes',
                                  busy: _updatingHanimeLike,
                                  onPressed: _toggleHanimeLike,
                                ),
                              if (details.video.site == ContentSite.hanime1)
                                _ActionButton(
                                  icon: _hanimeRatedNegative
                                      ? Icons.thumb_down
                                      : Icons.thumb_down_outlined,
                                  label: '$_hanimeDislikes',
                                  busy: _updatingHanimeRating,
                                  onPressed: () => _rateHanime(false),
                                ),
                              if (details.video.site == ContentSite.hanime1)
                                _ActionButton(
                                  icon: Icons.playlist_add,
                                  label: '播放列表',
                                  busy: _addingPlaylist,
                                  onPressed: _manageHanimePlaylists,
                                ),
                              if (details.video.site == ContentSite.hanime1)
                                _ActionButton(
                                  icon: _hanimeSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  label: _hanimeSaved ? '已稍后观看' : '稍后观看',
                                  busy: _updatingHanimeSaved,
                                  onPressed: _toggleHanimeSaved,
                                ),
                              if (details
                                  .video
                                  .site
                                  .capabilities
                                  .accountFavorites)
                                _ActionButton(
                                  icon: _favorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: _favorite ? '已收藏' : '收藏',
                                  busy: _updatingFavorite,
                                  onPressed: _toggleFavorite,
                                ),
                              _ActionButton(
                                icon: Icons.download,
                                label: '下载',
                                busy: _addingDownload,
                                onPressed: details.sources.isEmpty
                                    ? null
                                    : _download,
                              ),
                              _ActionButton(
                                icon: Icons.library_add_outlined,
                                label: '本地分类库',
                                busy: false,
                                onPressed: _addToLocalLibrary,
                              ),
                              if (details
                                  .video
                                  .site
                                  .capabilities
                                  .accountPlaylists)
                                _ActionButton(
                                  icon: Icons.playlist_add,
                                  label: '播放列表',
                                  busy: _addingPlaylist,
                                  onPressed: _addToPlaylist,
                                ),
                              _ActionButton(
                                icon: Icons.share_outlined,
                                label: '分享',
                                busy: false,
                                onPressed: _share,
                              ),
                            ],
                          ),
                          if (details.video.site == ContentSite.hanime1 &&
                              (details.description != null ||
                                  details.descriptionTitle != null ||
                                  details.video.views != null ||
                                  details.video.publishedLabel != null)) ...[
                            const SizedBox(height: 24),
                            SelectionArea(
                              key: _descriptionSelectionKey,
                              child: _HanimeDescriptionCard(details: details),
                            ),
                          ] else if (details.description != null) ...[
                            const SizedBox(height: 24),
                            SelectionArea(
                              key: _descriptionSelectionKey,
                              child: _CollapsibleDescription(
                                text: details.description!,
                              ),
                            ),
                          ],
                          if (details.video.site == ContentSite.hanime1 &&
                              details.seriesVideos.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _HanimeSeriesSection(
                              seriesTitle: details.seriesTitle ?? '未命名系列',
                              videos: details.seriesVideos,
                              layout: widget.settings.settings.videoLayout,
                              currentVideoId: details.video.id,
                              onTap: (video) async {
                                await widget.playerHandle.pause();
                                if (!context.mounted) return;
                                context.pushNamed(
                                  AppRouteNames.video,
                                  pathParameters: {
                                    'id': video.id,
                                    'slug': video.slug,
                                  },
                                  queryParameters: {'site': video.siteId},
                                  extra: video,
                                );
                              },
                            ),
                          ],
                          _MetadataSection(
                            title: '分类',
                            items: metadata
                                .where(
                                  (item) => item.kind == DiscoveryKind.category,
                                )
                                .toList(growable: false),
                            fallbackValues: details.categories,
                            kind: DiscoveryKind.category,
                            translationService: widget.translationService,
                            siteId: details.video.siteId,
                            subscribedPaths: _subscriptionPaths,
                            updatingKeys: _updatingMetadata,
                            onTap: _metadataOnTap(details),
                          ),
                          _MetadataSection(
                            title: '标签',
                            items: metadata
                                .where((item) => item.kind == DiscoveryKind.tag)
                                .toList(growable: false),
                            fallbackValues: details.tags,
                            kind: DiscoveryKind.tag,
                            translationService: widget.translationService,
                            siteId: details.video.siteId,
                            subscribedPaths: _subscriptionPaths,
                            updatingKeys: _updatingMetadata,
                            onTap: _metadataOnTap(details),
                          ),
                          _MetadataSection(
                            title: '艺术家',
                            items: metadata
                                .where(
                                  (item) => item.kind == DiscoveryKind.model,
                                )
                                .toList(growable: false),
                            fallbackValues: details.models,
                            kind: DiscoveryKind.model,
                            translationService: widget.translationService,
                            siteId: details.video.siteId,
                            subscribedPaths: _subscriptionPaths,
                            updatingKeys: _updatingMetadata,
                            onTap: _metadataOnTap(details),
                          ),
                          if (details.uploader case final uploader?) ...[
                            const SizedBox(height: 24),
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
                                trailing:
                                    details
                                        .video
                                        .site
                                        .capabilities
                                        .uploaderProfiles
                                    ? const Icon(Icons.chevron_right)
                                    : null,
                                onTap:
                                    details
                                        .video
                                        .site
                                        .capabilities
                                        .uploaderProfiles
                                    ? () => context.pushNamed(
                                        AppRouteNames.uploader,
                                        pathParameters: {'id': uploader.id},
                                        queryParameters: {
                                          'name': uploader.name,
                                        },
                                        extra: uploader,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                          if (details.relatedVideos.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            AppText(
                              '相关视频',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ListenableBuilder(
                              listenable: widget.settings,
                              builder: (context, _) => VideoCollectionBox(
                                layout: widget.settings.settings.videoLayout,
                                itemCount: details.relatedVideos.length,
                                itemBuilder: (context, index, compact) {
                                  final video = details.relatedVideos[index];
                                  return VideoCard(
                                    video: video,
                                    compact: compact,
                                    onTap: () async {
                                      await widget.playerHandle.pause();
                                      if (!context.mounted) {
                                        return;
                                      }
                                      context.pushNamed(
                                        AppRouteNames.video,
                                        pathParameters: {
                                          'id': video.id,
                                          'slug': video.slug,
                                        },
                                        queryParameters: {'site': video.siteId},
                                        extra: video,
                                      );
                                    },
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
              ),
              if (details.video.site == ContentSite.hanime1)
                HanimeCommentsSection(
                  api: widget.api,
                  videoId: details.video.id,
                  scrollToTopController: widget.scrollToTopController,
                  active: _tabController.index == 1,
                )
              else
                Rule34CommentsSection(
                  api: widget.api,
                  video: details.video,
                  scrollToTopController: widget.scrollToTopController,
                  active: _tabController.index == 1,
                ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _playerExpandController,
      child: nestedScrollView,
      builder: (context, child) => _OuterScrollOffsetCorrector(
        position: _detailScrollController.hasClients
            ? _detailScrollController.position
            : null,
        targetOffset: _playerAutoExpanding
            ? _playerExpandController.value
            : null,
        child: child!,
      ),
    );
  }
}

class _HanimeSeriesSection extends StatelessWidget {
  const _HanimeSeriesSection({
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
  void initState() {
    super.initState();
  }

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
      // Masonry layouts can defer the target child by one or two frames when
      // opening a sheet from a cold cache. Retry without animating the sheet.
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
                  itemBuilder: (context, index) => _buildItem(
                    context,
                    index,
                    compact: true,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItem(
                      context,
                      index,
                      compact: false,
                    ),
                    childCount: widget.videos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index, {
    required bool compact,
  }) {
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
                color: Color(0x99000000),
                child: Center(
                  child: AppText(
                    '正在播放',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
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

class _VideoDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _VideoDetailHeaderDelegate({
    required this.player,
    required this.tabs,
    required this.playerHeight,
  });

  static const tabsHeight = 36.0;
  final Widget player;
  final Widget tabs;
  final double playerHeight;

  @override
  double get minExtent => tabsHeight;

  @override
  double get maxExtent => playerHeight + tabsHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final hiddenPlayerHeight = shrinkOffset.clamp(0.0, maxExtent - minExtent);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -hiddenPlayerHeight,
            height: playerHeight,
            child: player,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: playerHeight - hiddenPlayerHeight,
            height: tabsHeight,
            child: tabs,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _VideoDetailHeaderDelegate oldDelegate) =>
      oldDelegate.player != player ||
      oldDelegate.tabs != tabs ||
      oldDelegate.playerHeight != playerHeight;
}

class _PlayerHeaderGatePhysics extends ScrollPhysics {
  const _PlayerHeaderGatePhysics({
    required this.playing,
    required this.buffering,
    required this.scrollToTopController,
    super.parent,
  });

  final ValueListenable<bool> playing;
  final ValueListenable<bool> buffering;
  final ScrollToTopController scrollToTopController;

  bool get _locked =>
      playing.value || buffering.value || scrollToTopController.suppressed;

  @override
  bool get allowImplicitScrolling => !_locked && super.allowImplicitScrolling;

  @override
  _PlayerHeaderGatePhysics applyTo(ScrollPhysics? ancestor) {
    return _PlayerHeaderGatePhysics(
      playing: playing,
      buffering: buffering,
      scrollToTopController: scrollToTopController,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (_locked && value != position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (_locked) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}

class _OuterScrollOffsetCorrector extends SingleChildRenderObjectWidget {
  const _OuterScrollOffsetCorrector({
    required this.position,
    required this.targetOffset,
    required super.child,
  });

  final ScrollPosition? position;
  final double? targetOffset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOuterScrollOffsetCorrector(
      position: position,
      targetOffset: targetOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOuterScrollOffsetCorrector renderObject,
  ) {
    renderObject.update(position: position, targetOffset: targetOffset);
  }
}

class _RenderOuterScrollOffsetCorrector extends RenderProxyBox {
  _RenderOuterScrollOffsetCorrector({
    required this.position,
    required this.targetOffset,
  });

  ScrollPosition? position;
  double? targetOffset;

  void update({
    required ScrollPosition? position,
    required double? targetOffset,
  }) {
    if (identical(this.position, position) &&
        this.targetOffset == targetOffset) {
      return;
    }
    this.position = position;
    this.targetOffset = targetOffset;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final scrollPosition = position;
    final target = targetOffset;
    if (scrollPosition != null && target != null && scrollPosition.hasPixels) {
      final correction = target - scrollPosition.pixels;
      if (correction.abs() > precisionErrorTolerance) {
        scrollPosition.correctBy(correction);
      }
    }
    super.performLayout();
  }
}

enum _MetadataAction { open, subscription }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      onPressed: busy ? null : onPressed,
      icon: Icon(icon),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: AppText(label));
  }
}

class _HanimeDescriptionCard extends StatelessWidget {
  const _HanimeDescriptionCard({required this.details});

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
              _CollapsibleDescription(
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

class _CollapsibleDescription extends StatefulWidget {
  const _CollapsibleDescription({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_CollapsibleDescription> createState() =>
      _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<_CollapsibleDescription> {
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

class _AdaptiveMetadataChip extends StatelessWidget {
  const _AdaptiveMetadataChip({
    this.avatar,
    required this.label,
    this.onPressed,
  });

  final Widget? avatar;
  final Widget label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipTheme = ChipTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
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
          color:
              chipTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerHighest,
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

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
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
  Widget build(BuildContext context) {
    if (items.isEmpty && fallbackValues.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: translationService,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.isEmpty
                ? fallbackValues
                      .take(40)
                      .map(
                        (value) => EditableTranslationRegion(
                          translationService: translationService,
                          kind: kind,
                          english: value,
                          siteId: siteId,
                          child: _AdaptiveMetadataChip(
                            label: LocalizedTranslationText(
                              value: translationService.resolveMetadata(
                                kind,
                                value,
                                siteId: siteId,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false)
                : items
                      .take(40)
                      .map((item) {
                        final subscribed = subscribedPaths.contains(item.path);
                        final busy = updatingKeys.any(
                          (key) => key.endsWith('${item.kind.name}:${item.id}'),
                        );
                        return EditableTranslationRegion(
                          translationService: translationService,
                          kind: item.kind,
                          english: item.title,
                          siteId: siteId,
                          child: _AdaptiveMetadataChip(
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
                                    value: translationService.resolveMetadata(
                                      item.kind,
                                      item.title,
                                      siteId: siteId,
                                    ),
                                    suffix:
                                        item.upScore == 0 && item.downScore == 0
                                        ? ''
                                        : ' · ↑${item.upScore} ↓${item.downScore}',
                                  ),
                                ),
                                // 标签热度数字：仿 UI 的浅色括号，位于标签末尾
                                // （如 “NTR（7）”），点击搜索时只使用纯标签文本。
                                if (item.count != null) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    '（${item.count}）',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                            onPressed: busy || onTap == null
                                ? null
                                : () => onTap!(item),
                          ),
                        );
                      })
                      .toList(growable: false),
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
