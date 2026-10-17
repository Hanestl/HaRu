import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/content_source.dart';
import '../../core/models/video_models.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/site_badge.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import '../downloads/presentation/downloads_list.dart';
import '../hanime/hanime_library_pages.dart';
import '../settings/data/app_settings_repository.dart';
import '../settings/domain/app_settings.dart';
import 'data/local_library_repository.dart';
import 'local_library_page.dart';
import 'playlists_list.dart';
import 'subscriptions_list.dart';

enum LibraryScope {
  local('local', '本机'),
  rule34video('rule34video', 'R34V'),
  hanime1('hanime1', 'Hanime');

  const LibraryScope(this.logName, this.label);

  final String logName;
  final String label;
}

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({
    super.key,
    required this.api,
    required this.localLibraryRepository,
    required this.prefetchService,
    this.downloadRepository,
  });

  final Rule34VideoApi api;
  final LocalLibraryRepository localLibraryRepository;
  final PredictivePrefetchService prefetchService;
  final DownloadRepository? downloadRepository;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late LibraryScope _scope;
  late final AppSettingsRepository _settingsRepository;
  late bool _rule34LoggedIn;
  late bool _hanimeLoggedIn;

  @override
  void initState() {
    super.initState();
    _settingsRepository = ref.read(appSettingsRepositoryProvider);
    _scope = _scopeFromPreference(
      _settingsRepository.settings.libraryScopeOrder.first,
    );
    _rule34LoggedIn = widget.api.sessionStore.isLoggedIn;
    _hanimeLoggedIn = widget.api.sessionStore.isHanimeLoggedIn;
    widget.api.sessionStore.addListener(_onSessionChanged);
    unawaited(
      AppLogService.instance.info(
        '媒体库打开；范围=${_scope.logName}；'
        'R34V登录=${_yesNo(_rule34LoggedIn)}；'
        'Hanime登录=${_yesNo(_hanimeLoggedIn)}',
        component: 'library_ui',
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.sessionStore != widget.api.sessionStore) {
      oldWidget.api.sessionStore.removeListener(_onSessionChanged);
      widget.api.sessionStore.addListener(_onSessionChanged);
      _rule34LoggedIn = widget.api.sessionStore.isLoggedIn;
      _hanimeLoggedIn = widget.api.sessionStore.isHanimeLoggedIn;
    }
  }

  @override
  void dispose() {
    widget.api.sessionStore.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final rule34LoggedIn = widget.api.sessionStore.isLoggedIn;
    final hanimeLoggedIn = widget.api.sessionStore.isHanimeLoggedIn;
    if (rule34LoggedIn != _rule34LoggedIn ||
        hanimeLoggedIn != _hanimeLoggedIn) {
      unawaited(
        AppLogService.instance.info(
          '媒体库登录状态变化；R34V=${_yesNo(rule34LoggedIn)}；'
          'Hanime=${_yesNo(hanimeLoggedIn)}；当前范围=${_scope.logName}',
          component: 'library_ui',
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _rule34LoggedIn = rule34LoggedIn;
      _hanimeLoggedIn = hanimeLoggedIn;
    });
  }

  void _selectScope(Set<LibraryScope> selection) {
    final next = selection.single;
    if (next == _scope) return;
    final previous = _scope;
    setState(() => _scope = next);
    unawaited(
      AppLogService.instance.info(
        '媒体库范围切换；from=${previous.logName}；to=${next.logName}',
        component: 'library_ui',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsRepository,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: SegmentedButton<LibraryScope>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: _settingsRepository.settings.libraryScopeOrder
                  .map((item) => _scopeSegment(_scopeFromPreference(item)))
                  .toList(growable: false),
              selected: {_scope},
              onSelectionChanged: _selectScope,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _scope.index,
              children: [
                _LocalLibraryScope(
                  repository: widget.localLibraryRepository,
                  downloadRepository: widget.downloadRepository,
                ),
                _Rule34LibraryScope(
                  api: widget.api,
                  prefetch: widget.prefetchService,
                  active: _scope == LibraryScope.rule34video,
                  loggedIn: _rule34LoggedIn,
                ),
                _HanimeLibraryScope(
                  api: widget.api,
                  prefetch: widget.prefetchService,
                  active: _scope == LibraryScope.hanime1,
                  loggedIn: _hanimeLoggedIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

LibraryScope _scopeFromPreference(LibraryScopePreference value) =>
    switch (value) {
      LibraryScopePreference.local => LibraryScope.local,
      LibraryScopePreference.rule34video => LibraryScope.rule34video,
      LibraryScopePreference.hanime => LibraryScope.hanime1,
    };

ButtonSegment<LibraryScope> _scopeSegment(LibraryScope scope) =>
    switch (scope) {
      LibraryScope.local => const ButtonSegment(
        value: LibraryScope.local,
        icon: Icon(Icons.smartphone_outlined),
        label: AppText('本机'),
      ),
      LibraryScope.rule34video => const ButtonSegment(
        value: LibraryScope.rule34video,
        icon: SiteBadge(site: ContentSite.rule34video, size: 20),
        label: AppText('R34V'),
      ),
      LibraryScope.hanime1 => const ButtonSegment(
        value: LibraryScope.hanime1,
        icon: SiteBadge(site: ContentSite.hanime1, size: 20),
        label: AppText('Hanime'),
      ),
    };

enum _LocalSection {
  libraries('libraries', '本地库'),
  downloads('downloads', '下载');

  const _LocalSection(this.logName, this.label);
  final String logName;
  final String label;
}

class _LocalLibraryScope extends StatefulWidget {
  const _LocalLibraryScope({
    required this.repository,
    required this.downloadRepository,
  });

  final LocalLibraryRepository repository;
  final DownloadRepository? downloadRepository;

  @override
  State<_LocalLibraryScope> createState() => _LocalLibraryScopeState();
}

class _LocalLibraryScopeState extends State<_LocalLibraryScope>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _LocalSection.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    final section = _LocalSection.values[_controller.index];
    unawaited(
      AppLogService.instance.info(
        '媒体库二级页切换；范围=local；section=${section.logName}',
        component: 'library_ui',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _controller,
          tabs: [
            for (final section in _LocalSection.values)
              Tab(child: AppText(section.label)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              LocalLibraryOverview(
                key: const PageStorageKey<String>('library-scope-local'),
                repository: widget.repository,
              ),
              if (widget.downloadRepository case final repository?)
                DownloadManagementPage(
                  key: const PageStorageKey<String>('library-scope-downloads'),
                  repository: repository,
                  embedded: true,
                )
              else
                const Center(child: AppText('下载服务暂不可用。')),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Rule34Section {
  history('history', '历史'),
  playlists('playlists', '播放列表'),
  subscriptions('subscriptions', '订阅'),
  favorites('favorites', '收藏');

  const _Rule34Section(this.logName, this.label);

  final String logName;
  final String label;
}

class _Rule34LibraryScope extends StatefulWidget {
  const _Rule34LibraryScope({
    required this.api,
    required this.prefetch,
    required this.active,
    required this.loggedIn,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;
  final bool loggedIn;

  @override
  State<_Rule34LibraryScope> createState() => _Rule34LibraryScopeState();
}

class _Rule34LibraryScopeState extends State<_Rule34LibraryScope>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _selected = _Rule34Section.history;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _Rule34Section.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _Rule34LibraryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        (!oldWidget.loggedIn && widget.loggedIn && widget.active)) {
      _prioritizeSelected();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final next = _Rule34Section.values[_tabController.index];
    if (next == _selected) return;
    setState(() => _selected = next);
    _prioritizeSelected();
    unawaited(
      AppLogService.instance.info(
        '媒体库二级页切换；范围=rule34video；section=${next.logName}',
        component: 'library_ui',
      ),
    );
  }

  void _prioritizeSelected() {
    if (!widget.active || !widget.loggedIn) return;
    widget.prefetch.prioritizeForeground(
      adoptKey: switch (_selected) {
        _Rule34Section.favorites => PredictivePrefetchKey.favorites(1),
        _Rule34Section.history => PredictivePrefetchKey.history(1),
        _Rule34Section.playlists => PredictivePrefetchKey.playlists,
        _Rule34Section.subscriptions => PredictivePrefetchKey.subscriptions,
      },
    );
  }

  Future<List<VideoItem>> _loadVideos(
    _Rule34Section section,
    int page, {
    bool force = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    unawaited(
      AppLogService.instance.info(
        '媒体库列表请求开始；范围=rule34video；section=${section.logName}；'
        'page=$page；refresh=${_yesNo(force)}',
        component: 'library_data',
      ),
    );
    try {
      final request = switch (section) {
        _Rule34Section.favorites => widget.api.loadFavorites(
          page,
          force: force,
        ),
        _Rule34Section.history => widget.api.loadHistory(page, force: force),
        _ => throw StateError('Unsupported video section: ${section.name}'),
      };
      final result = await request;
      unawaited(
        AppLogService.instance.info(
          '媒体库列表请求完成；范围=rule34video；section=${section.logName}；'
          'page=$page；count=${result.length}；'
          '耗时=${stopwatch.elapsedMilliseconds}ms',
          component: 'library_data',
        ),
      );
      return result;
    } catch (error, stackTrace) {
      unawaited(
        AppLogService.instance.error(
          error,
          stackTrace,
          component: 'library_data',
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentActive = widget.active && widget.loggedIn;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final section in _Rule34Section.values)
              Tab(child: AppText(section.label)),
          ],
        ),
        Expanded(
          child: widget.loggedIn
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    VideoFeed(
                      key: const PageStorageKey<String>(
                        'library-rule34-history',
                      ),
                      active:
                          contentActive && _selected == _Rule34Section.history,
                      loadPage: (page) =>
                          _loadVideos(_Rule34Section.history, page),
                      refreshPage: (page) => _loadVideos(
                        _Rule34Section.history,
                        page,
                        force: true,
                      ),
                      emptyMessage: '网站观看历史还是空的。',
                      showSearchAndFilters: true,
                      searchHint: '搜索观看历史',
                      prefetchService: widget.prefetch,
                    ),
                    PlaylistsList(
                      api: widget.api,
                      active:
                          contentActive &&
                          _selected == _Rule34Section.playlists,
                    ),
                    SubscriptionsList(
                      api: widget.api,
                      active:
                          contentActive &&
                          _selected == _Rule34Section.subscriptions,
                    ),
                    VideoFeed(
                      key: const PageStorageKey<String>(
                        'library-rule34-favorites',
                      ),
                      active:
                          contentActive &&
                          _selected == _Rule34Section.favorites,
                      loadPage: (page) =>
                          _loadVideos(_Rule34Section.favorites, page),
                      refreshPage: (page) => _loadVideos(
                        _Rule34Section.favorites,
                        page,
                        force: true,
                      ),
                      emptyMessage: '收藏夹里还没有视频。',
                      showSearchAndFilters: true,
                      searchHint: '搜索收藏的视频',
                      prefetchService: widget.prefetch,
                    ),
                  ],
                )
              : _SiteSignedOut(
                  site: ContentSite.rule34video,
                  message: '登录后即可查看收藏、历史、播放列表和订阅。',
                  onLogin: () => _showSiteLogin(ContentSite.rule34video),
                ),
        ),
      ],
    );
  }

  Future<void> _showSiteLogin(ContentSite site) async {
    unawaited(
      AppLogService.instance.info(
        '从媒体库请求登录；范围=${site.id}；section=${_selected.logName}',
        component: 'library_ui',
      ),
    );
    await showLoginSheet(context, widget.api, site: site);
  }
}

enum _HanimeSection {
  history('history', '历史'),
  playlists('playlists', '播放列表'),
  subscriptions('subscriptions', '订阅'),
  likes('likes', '点赞'),
  saves('saves', '稍后观看');

  const _HanimeSection(this.logName, this.label);

  final String logName;
  final String label;
}

class _HanimeLibraryScope extends StatefulWidget {
  const _HanimeLibraryScope({
    required this.api,
    required this.prefetch,
    required this.active,
    required this.loggedIn,
  });

  final Rule34VideoApi api;
  final PredictivePrefetchService prefetch;
  final bool active;
  final bool loggedIn;

  @override
  State<_HanimeLibraryScope> createState() => _HanimeLibraryScopeState();
}

class _HanimeLibraryScopeState extends State<_HanimeLibraryScope>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _selected = _HanimeSection.history;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _HanimeSection.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _HanimeLibraryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        (!oldWidget.loggedIn && widget.loggedIn && widget.active)) {
      _prioritizeSelected();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final next = _HanimeSection.values[_tabController.index];
    if (next == _selected) return;
    setState(() => _selected = next);
    _prioritizeSelected();
    unawaited(
      AppLogService.instance.info(
        '媒体库二级页切换；范围=hanime1；section=${next.logName}',
        component: 'library_ui',
      ),
    );
  }

  void _prioritizeSelected() {
    if (!widget.active || !widget.loggedIn) return;
    widget.prefetch.prioritizeForeground(
      adoptKey: switch (_selected) {
        _HanimeSection.likes => PredictivePrefetchKey.libraryHanimeLikes(1),
        _HanimeSection.saves => PredictivePrefetchKey.libraryHanimeSaves(1),
        _HanimeSection.history => PredictivePrefetchKey.libraryHanimeHistory(
          'latest',
          1,
        ),
        _HanimeSection.playlists => null,
        _HanimeSection.subscriptions =>
          PredictivePrefetchKey.libraryHanimeSubscriptions(1),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentActive = widget.active && widget.loggedIn;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final section in _HanimeSection.values)
              Tab(child: AppText(section.label)),
          ],
        ),
        Expanded(
          child: widget.loggedIn
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    HanimeHistoryView(
                      api: widget.api,
                      prefetch: widget.prefetch,
                      active:
                          contentActive && _selected == _HanimeSection.history,
                    ),
                    HanimePlaylistsView(
                      api: widget.api,
                      active:
                          contentActive &&
                          _selected == _HanimeSection.playlists,
                    ),
                    HanimeSubscriptionsView(
                      api: widget.api,
                      prefetch: widget.prefetch,
                      active:
                          contentActive &&
                          _selected == _HanimeSection.subscriptions,
                    ),
                    HanimeLikesView(
                      api: widget.api,
                      prefetch: widget.prefetch,
                      active:
                          contentActive && _selected == _HanimeSection.likes,
                    ),
                    HanimeSavesView(
                      api: widget.api,
                      prefetch: widget.prefetch,
                      active:
                          contentActive && _selected == _HanimeSection.saves,
                    ),
                  ],
                )
              : _SiteSignedOut(
                  site: ContentSite.hanime1,
                  message: '登录后即可查看点赞、稍后观看、历史、播放列表和订阅。',
                  onLogin: _showLogin,
                ),
        ),
      ],
    );
  }

  Future<void> _showLogin() async {
    unawaited(
      AppLogService.instance.info(
        '从媒体库请求登录；范围=hanime1；section=${_selected.logName}',
        component: 'library_ui',
      ),
    );
    await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
  }
}

class _SiteSignedOut extends StatelessWidget {
  const _SiteSignedOut({
    required this.site,
    required this.message,
    required this.onLogin,
  });

  final ContentSite site;
  final String message;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SiteBadge(site: site, size: 42),
            const SizedBox(height: 16),
            AppText(
              '登录 ${site.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            AppText(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
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

String _yesNo(bool value) => value ? '是' : '否';
