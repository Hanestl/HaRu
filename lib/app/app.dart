import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/http_adapter_factory.dart';
import '../features/settings/domain/app_settings.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/hanime_cloudflare_gate.dart';
import '../shared/video_preview_overlay.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class Flule34App extends ConsumerStatefulWidget {
  const Flule34App({super.key});

  @override
  ConsumerState<Flule34App> createState() => _Flule34AppState();
}

class _Flule34AppState extends ConsumerState<Flule34App> {
  @override
  void dispose() {
    closeSharedHttpAdapters(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);

    return ListenableBuilder(
      listenable: settingsRepository,
      builder: (context, _) {
        final preference = settingsRepository.settings.theme;
        final language = settingsRepository.settings.language;
        return MaterialApp.router(
          title: 'HaRu',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: switch (preference) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          locale: language.languageCode == null
              ? null
              : Locale(language.languageCode!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => HanimeCloudflareGate(
            child: VideoPreviewOverlay(
              navigationListenable: router.routerDelegate,
              bottomInsetBuilder: (context) {
                final path =
                    router.routerDelegate.currentConfiguration.uri.path;
                if (!_showsBottomNavigation(path)) {
                  return 0;
                }
                return NavigationBarTheme.of(context).height ?? 80;
              },
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

bool _showsBottomNavigation(String path) {
  return path == '/' ||
      path == '/hanime' ||
      path == '/library' ||
      path.startsWith('/library/') ||
      path == '/profile' ||
      path.startsWith('/profile/');
}
