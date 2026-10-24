import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/database/app_database.dart';
import '../core/logging/app_log_service.dart';
import '../core/models/content_source.dart';
import '../core/services/hanime_cloudflare_coordinator.dart';
import '../core/services/media_volume_service.dart';
import '../core/services/network_status_service.dart';
import '../core/services/predictive_prefetch_service.dart';
import '../core/services/screen_wake_lock_service.dart';
import '../core/services/share_service.dart';
import '../core/services/source_language_detector.dart';
import '../core/services/subscription_activity_index.dart';
import '../core/services/translation_provider_repository.dart';
import '../core/services/translation_provider_router.dart';
import '../core/services/translation_service.dart';
import '../core/services/video_preview_service.dart';
import '../core/session/secret_store.dart';
import '../core/session/secure_cookie_storage.dart';
import '../core/session/session_store.dart';
import '../features/downloads/data/background_download_platform_service.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/downloads/domain/download_models.dart';
import '../features/library/data/curated_library_seeder.dart';
import '../features/library/data/local_library_repository.dart';
import '../features/playback/data/playback_repository.dart';
import '../features/search/data/search_history_repository.dart';
import '../features/settings/data/apk_installer.dart';
import '../features/settings/data/app_settings_repository.dart';
import '../features/settings/data/app_settings_store.dart';
import '../features/settings/data/app_update_downloader.dart';
import '../features/settings/data/app_update_prompt_store.dart';
import '../features/settings/data/app_update_service.dart';
import '../features/settings/domain/app_settings.dart';
import '../shared/scroll_to_top_overlay.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return SharedPreferencesAppSettingsStore();
});

final appLogServiceProvider = Provider<AppLogService>((ref) {
  return AppLogService.instance;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final repository = AppSettingsRepository(ref.watch(appSettingsStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final updatePromptStoreProvider = Provider<UpdatePromptStore>((ref) {
  return UpdatePromptStore(SharedPreferencesUpdateNotifiedVersionStore());
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.close);
  return service;
});

final appUpdateDownloaderProvider = Provider<AppUpdateDownloaderApi>((ref) {
  final downloader = AppUpdateDownloader();
  ref.onDispose(downloader.close);
  return downloader;
});

final apkInstallerProvider = Provider<ApkInstaller>((ref) {
  return ApkInstaller();
});

final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  return ConnectivityNetworkStatusService();
});

final screenWakeLockServiceProvider = Provider<ScreenWakeLockService>((ref) {
  return WakelockScreenWakeLockService();
});

final mediaVolumeServiceProvider = Provider<MediaVolumeService>((ref) {
  return const PlatformMediaVolumeService();
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return PlatformShareService();
});

final scrollToTopControllerProvider = Provider<ScrollToTopController>((ref) {
  final controller = ScrollToTopController();
  ref.onDispose(controller.dispose);
  return controller;
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return FlutterSecretStore();
});

final translationProviderRepositoryProvider =
    Provider<TranslationProviderRepository>((ref) {
      final repository = TranslationProviderRepository(
        store: ref.watch(appSettingsStoreProvider),
        secrets: ref.watch(secretStoreProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final translationProviderRouterProvider = Provider<TranslationProviderRouter>((
  ref,
) {
  return TranslationProviderRouter(
    repository: ref.watch(translationProviderRepositoryProvider),
  );
});

final sourceLanguageDetectorProvider = Provider<SourceLanguageDetector>((ref) {
  final detector = MlKitSourceLanguageDetector();
  ref.onDispose(() => unawaited(detector.dispose()));
  return detector;
});

final cookieJarProvider = Provider<PersistCookieJar>((ref) {
  return PersistCookieJar(
    persistSession: true,
    storage: SecureCookieStorage(ref.watch(secretStoreProvider)),
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService(
    settingsRepository: ref.watch(appSettingsRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
    providerRouter: ref.watch(translationProviderRouterProvider),
    sourceLanguageDetector: ref.watch(sourceLanguageDetectorProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore(
    cookieJar: ref.watch(cookieJarProvider),
    secretStore: ref.watch(secretStoreProvider),
    database: ref.watch(appDatabaseProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

final subscriptionActivityStoreProvider = Provider<SubscriptionActivityStore>((
  ref,
) {
  return _SettingsBackedSubscriptionActivityStore(
    ref.watch(appSettingsStoreProvider),
  );
});

final hanimeCloudflareCoordinatorProvider =
    Provider<HanimeCloudflareCoordinator>((ref) {
      final coordinator = HanimeCloudflareCoordinator();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

final rule34VideoApiProvider = Provider<Rule34VideoApi>((ref) {
  final api = Rule34VideoApi(
    sessionStore: ref.watch(sessionStoreProvider),
    subscriptionActivityStore: ref.watch(subscriptionActivityStoreProvider),
    hanimeBrowserPageHandler: ref
        .watch(hanimeCloudflareCoordinatorProvider)
        .requestPage,
  );
  ref.onDispose(api.close);
  return api;
});

final predictivePrefetchServiceProvider = Provider<PredictivePrefetchService>((
  ref,
) {
  final sessionStore = ref.watch(sessionStoreProvider);
  final service = PredictivePrefetchService(
    api: ref.watch(rule34VideoApiProvider),
    sessionStore: sessionStore,
    settingsRepository: ref.watch(appSettingsRepositoryProvider),
  );
  sessionStore.addListener(service.onSessionChanged);
  ref.onDispose(() {
    sessionStore.removeListener(service.onSessionChanged);
    service.dispose();
  });
  return service;
});

final downloadPlatformServiceProvider = Provider<DownloadPlatformService>((
  ref,
) {
  return BackgroundDownloadPlatformService(
    maxConcurrent: ref
        .watch(appSettingsRepositoryProvider)
        .settings
        .downloadConcurrentTasks,
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repository = DownloadRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(rule34VideoApiProvider),
    ref.watch(downloadPlatformServiceProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
});

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>((ref) {
  return DriftLocalLibraryRepository(ref.watch(appDatabaseProvider));
});

final videoPreviewResolverProvider = Provider<VideoPreviewResolver>((ref) {
  final api = ref.watch(rule34VideoApiProvider);
  final database = ref.watch(appDatabaseProvider);
  return VideoPreviewResolver(
    search: api.searchVideosForPreview,
    persist: ({required String videoId, required String? previewUrl}) =>
        database.updateLocalLibraryVideoPreviewUrl(
          videoId: videoId,
          previewUrl: previewUrl,
        ),
  );
});

final videoPreviewControllerProvider = Provider<VideoPreviewController>((ref) {
  final controller = VideoPreviewController();
  ref.onDispose(controller.dispose);
  return controller;
});

final curatedLibrarySeederProvider = Provider<CuratedLibrarySeeder>((ref) {
  return CuratedLibrarySeeder(
    ref.watch(appDatabaseProvider),
    const AssetCuratedLibraryManifestLoader(),
  );
});

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SearchHistoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  final log = ref.read(appLogServiceProvider);
  await log.initialize();
  try {
    final settingsRepo = ref.read(appSettingsRepositoryProvider);
    await settingsRepo.load();
    final initialDestination = settingsRepo.settings.navigationOrder.first;
    final initialSite = switch (initialDestination) {
      AppDestination.rule34video => ContentSite.rule34video,
      AppDestination.hanime => ContentSite.hanime1,
      _ => null,
    };
    if (initialSite != null &&
        settingsRepo.settings.activeSite != initialSite) {
      await settingsRepo.setActiveSite(initialSite);
    }
    await ref.read(translationProviderRepositoryProvider).load();
    await ref.read(translationServiceProvider).initialize();
    await ref.read(curatedLibrarySeederProvider).seedIfNeeded();
    final sessionStore = ref.read(sessionStoreProvider);
    await sessionStore.load();
    await ref.read(rule34VideoApiProvider).restoreSession();
    await ref.read(rule34VideoApiProvider).subscriptionActivity.loadStored();
    ref.read(predictivePrefetchServiceProvider).scheduleStartup();
    await ref.read(downloadRepositoryProvider).initialize();
    await log.info('应用初始化完成。', component: 'bootstrap');
  } on Object catch (error, stackTrace) {
    await log.error(error, stackTrace, component: 'bootstrap');
    Error.throwWithStackTrace(error, stackTrace);
  }
});

final class _SettingsBackedSubscriptionActivityStore
    implements SubscriptionActivityStore {
  const _SettingsBackedSubscriptionActivityStore(this._store);

  static const _keyPrefix = 'flule34.subscription_activity.';

  final AppSettingsStore _store;

  @override
  Future<String?> read(String userId) {
    return _store.readString('$_keyPrefix$userId');
  }

  @override
  Future<void> write(String userId, String value) {
    return _store.writeString('$_keyPrefix$userId', value);
  }

  @override
  Future<void> remove(String userId) {
    return _store.remove('$_keyPrefix$userId');
  }
}
