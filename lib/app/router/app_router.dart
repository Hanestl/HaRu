import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/video_models.dart';
import '../../core/models/content_source.dart';
import '../../core/models/hanime_search_models.dart';
import '../../core/database/app_database.dart';
import '../../features/discover/collection_page.dart';
import '../../features/discover/discovery_directory_page.dart';
import '../../features/discover/rankings_page.dart';
import '../../features/downloads/presentation/downloads_list.dart';
import '../../features/home/home_page.dart';
import '../../features/library/library_page.dart';
import '../../features/library/local_library_page.dart';
import '../../features/library/playlist_page.dart';
import '../../features/library/playlist_playback_page.dart';
import '../../features/library/subscription_page.dart';
import '../../features/profile/account_page.dart';
import '../../features/profile/hanime_account_page.dart';
import '../../features/hanime/hanime_library_pages.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/uploader_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/presentation/settings_pages.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/settings/presentation/support_pages.dart';
import '../../features/settings/presentation/translation_catalog_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/video/video_detail_page.dart';
import '../../features/home/hanime_home_page.dart';
import '../../features/home/porn91_home_page.dart';
import '../../shared/scroll_to_top_overlay.dart';
import '../providers.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _hanimeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'hanime');
final _porn91NavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'porn91');
final _libraryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final api = ref.watch(rule34VideoApiProvider);
  final searchHistoryRepository = ref.watch(searchHistoryRepositoryProvider);
  final scrollToTopController = ref.watch(scrollToTopControllerProvider);
  final initialDestination = ref
      .read(appSettingsRepositoryProvider)
      .settings
      .navigationOrder
      .first;
  final initialSite = switch (initialDestination) {
    AppDestination.rule34video => ContentSite.rule34video,
    AppDestination.hanime => ContentSite.hanime1,
    AppDestination.porn91 => ContentSite.porn91,
    _ => null,
  };
  if (initialSite != null &&
      ref.read(appSettingsRepositoryProvider).settings.activeSite !=
          initialSite) {
    unawaited(
      ref.read(appSettingsRepositoryProvider).setActiveSite(initialSite),
    );
  }
  Widget scrollablePage(GoRouterState state, Widget child) {
    return ScrollToTopOverlay(
      key: ValueKey(state.uri.toString()),
      controller: scrollToTopController,
      child: child,
    );
  }

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _initialLocation(initialDestination),
    observers: [appRouteObserver],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                name: AppRouteNames.home,
                builder: (context, state) =>
                    scrollablePage(state, HomePage(api: api)),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _hanimeNavigatorKey,
            routes: [
              GoRoute(
                path: '/hanime',
                name: AppRouteNames.hanimeHome,
                builder: (context, state) =>
                    scrollablePage(state, HanimeHomePage(api: api)),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _porn91NavigatorKey,
            routes: [
              GoRoute(
                path: '/porn91',
                name: AppRouteNames.porn91Home,
                builder: (context, state) =>
                    scrollablePage(state, Porn91HomePage(api: api)),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _libraryNavigatorKey,
            routes: [
              GoRoute(
                path: '/library',
                name: AppRouteNames.library,
                builder: (context, state) => scrollablePage(
                  state,
                  LibraryPage(
                    api: api,
                    localLibraryRepository: ref.read(
                      localLibraryRepositoryProvider,
                    ),
                    prefetchService: ref.read(
                      predictivePrefetchServiceProvider,
                    ),
                    downloadRepository: ref.read(downloadRepositoryProvider),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'local/:id',
                    name: AppRouteNames.localLibrary,
                    builder: (context, state) {
                      final extra = state.extra;
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      return scrollablePage(
                        state,
                        LocalLibraryPage(
                          repository: ref.read(localLibraryRepositoryProvider),
                          libraryId: id ?? -1,
                          title: extra is LocalLibrary ? extra.name : '本地库',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: AppRouteNames.profile,
                builder: (context, state) =>
                    scrollablePage(state, ProfilePage(api: api)),
                routes: [
                  GoRoute(
                    path: 'account',
                    name: AppRouteNames.account,
                    builder: (context, state) =>
                        scrollablePage(state, AccountPage(api: api)),
                  ),
                  GoRoute(
                    path: 'hanime-account',
                    name: AppRouteNames.hanimeAccount,
                    builder: (context, state) =>
                        scrollablePage(state, HanimeAccountPage(api: api)),
                  ),
                  GoRoute(
                    path: 'appearance',
                    name: AppRouteNames.appearanceSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const AppearanceSettingsPage()),
                  ),
                  GoRoute(
                    path: 'playback',
                    name: AppRouteNames.playbackSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const PlaybackSettingsPage()),
                  ),
                  GoRoute(
                    path: 'content',
                    name: AppRouteNames.contentSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const ContentSettingsPage()),
                  ),
                  GoRoute(
                    path: 'translation',
                    name: AppRouteNames.translationSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const TranslationSettingsPage()),
                    routes: [
                      GoRoute(
                        path: 'catalog',
                        name: AppRouteNames.translationCatalog,
                        builder: (context, state) => scrollablePage(
                          state,
                          const TranslationCatalogPage(),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'downloads',
                    name: AppRouteNames.downloadSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const DownloadSettingsPage()),
                  ),
                  GoRoute(
                    path: 'download-management',
                    name: AppRouteNames.downloadManagement,
                    builder: (context, state) => scrollablePage(
                      state,
                      DownloadManagementPage(
                        repository: ref.read(downloadRepositoryProvider),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'privacy',
                    name: AppRouteNames.privacySettings,
                    builder: (context, state) =>
                        scrollablePage(state, PrivacySettingsPage(api: api)),
                  ),
                  GoRoute(
                    path: 'app',
                    name: AppRouteNames.appSettings,
                    builder: (context, state) =>
                        scrollablePage(state, const AppSettingsPage()),
                  ),
                  GoRoute(
                    path: 'help',
                    name: AppRouteNames.helpFeedback,
                    builder: (context, state) =>
                        scrollablePage(state, const HelpFeedbackPage()),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    name: AppRouteNames.diagnostics,
                    builder: (context, state) =>
                        scrollablePage(state, const DiagnosticsPage()),
                  ),
                  GoRoute(
                    path: 'update',
                    name: AppRouteNames.update,
                    builder: (context, state) =>
                        scrollablePage(state, const AppUpdatePage()),
                  ),
                  GoRoute(
                    path: 'about',
                    name: AppRouteNames.about,
                    builder: (context, state) =>
                        scrollablePage(state, const AboutPage()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        name: AppRouteNames.search,
        builder: (context, state) {
          final launch = state.extra;
          return scrollablePage(
            state,
            SearchPage(
              api: api,
              historyRepository: searchHistoryRepository,
              prefetchService: ref.read(predictivePrefetchServiceProvider),
              translationService: ref.read(translationServiceProvider),
              settingsRepository: ref.read(appSettingsRepositoryProvider),
              hanimeLaunch: launch is HanimeSearchLaunch ? launch : null,
              initialSite: state.uri.queryParameters['site'] == null
                  ? null
                  : ContentSite.fromId(state.uri.queryParameters['site']),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hanime/likes',
        name: AppRouteNames.hanimeLikes,
        builder: (context, state) => scrollablePage(
          state,
          HanimeLikesPage(
            api: api,
            prefetch: ref.read(predictivePrefetchServiceProvider),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hanime/playlists',
        name: AppRouteNames.hanimePlaylists,
        builder: (context, state) =>
            scrollablePage(state, HanimePlaylistsPage(api: api)),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hanime/playlist',
        name: AppRouteNames.hanimePlaylist,
        builder: (context, state) => scrollablePage(
          state,
          HanimePlaylistContentPage(
            api: api,
            prefetch: ref.read(predictivePrefetchServiceProvider),
            listCode: state.uri.queryParameters['list'] ?? '',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/directory/:kind',
        name: AppRouteNames.discoveryDirectory,
        builder: (context, state) {
          final kindName = state.pathParameters['kind'];
          final kind = DiscoveryKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => DiscoveryKind.tag,
          );
          final extra = state.extra;
          final spec = extra is DiscoveryDirectorySpec
              ? extra
              : DiscoveryDirectorySpec(
                  title: kind.label,
                  path: '/${kind.pathSegment}/',
                  kind: kind,
                );
          return scrollablePage(
            state,
            DiscoveryDirectoryPage(
              api: api,
              spec: spec,
              translationService: ref.read(translationServiceProvider),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/collection/:kind/:id',
        name: AppRouteNames.collection,
        builder: (context, state) {
          final kindName = state.pathParameters['kind'];
          final kind = DiscoveryKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => DiscoveryKind.tag,
          );
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          final collection = extra is ContentCollectionItem
              ? extra
              : ContentCollectionItem(
                  id: id,
                  title: state.uri.queryParameters['title'] ?? kind.label,
                  path:
                      state.uri.queryParameters['path'] ??
                      '/${kind.pathSegment}/$id/',
                  kind: kind,
                );
          final sortName = state.uri.queryParameters['sort'];
          final sort = VideoSort.values.firstWhere(
            (value) => value.name == sortName,
            orElse: () => VideoSort.newest,
          );
          return scrollablePage(
            state,
            CollectionPage(
              api: api,
              collection: collection,
              initialSort: sort,
              translationService: ref.read(translationServiceProvider),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rankings',
        name: AppRouteNames.rankings,
        builder: (context, state) =>
            scrollablePage(state, const RankingsPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/video/:id/:slug',
        name: AppRouteNames.video,
        builder: (context, state) {
          final extra = state.extra;
          final video = extra is VideoItem
              ? extra
              : VideoItem(
                  id: state.pathParameters['id']!,
                  slug: state.pathParameters['slug']!,
                  title: '视频 ${state.pathParameters['id']!}',
                  siteId: state.uri.queryParameters['site'] ?? 'rule34video',
                );
          return scrollablePage(state, VideoDetailPage(api: api, video: video));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/playlist/:id',
        name: AppRouteNames.playlist,
        builder: (context, state) {
          final extra = state.extra;
          final id = state.pathParameters['id']!;
          final playlist = extra is PlaylistItem
              ? extra
              : PlaylistItem(
                  id: id,
                  title: '播放列表 $id',
                  path: '/my/playlists/$id/',
                );
          return scrollablePage(
            state,
            PlaylistPage(api: api, playlist: playlist),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/playlist/:id/play',
        name: AppRouteNames.playlistPlayback,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! PlaylistPlaybackRequest) {
            return scrollablePage(
              state,
              const Scaffold(body: Center(child: AppText('播放列表播放参数无效。'))),
            );
          }
          return scrollablePage(
            state,
            PlaylistPlaybackPage(
              api: api,
              request: extra,
              translationService: ref.read(translationServiceProvider),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/subscription/:kind',
        name: AppRouteNames.subscription,
        builder: (context, state) {
          final extra = state.extra;
          final kindName = state.pathParameters['kind'];
          final kind = SubscriptionKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => SubscriptionKind.category,
          );
          final subscription = extra is SubscriptionItem
              ? extra
              : SubscriptionItem(
                  title: state.uri.queryParameters['title'] ?? kind.label,
                  path: state.uri.queryParameters['path'] ?? '/',
                  kind: kind,
                );
          return scrollablePage(
            state,
            SubscriptionPage(api: api, subscription: subscription),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/uploader/:id',
        name: AppRouteNames.uploader,
        builder: (context, state) {
          final extra = state.extra;
          final uploader = extra is UploaderSummary
              ? extra
              : UploaderSummary(
                  id: state.pathParameters['id'] ?? '',
                  name: state.uri.queryParameters['name'] ?? '上传者',
                );
          return scrollablePage(
            state,
            UploaderPage(api: api, uploader: uploader),
          );
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String _initialLocation(AppDestination destination) => switch (destination) {
  AppDestination.rule34video => '/',
  AppDestination.hanime => '/hanime',
  AppDestination.porn91 => '/porn91',
  AppDestination.library => '/library',
  AppDestination.profile => '/profile',
};
