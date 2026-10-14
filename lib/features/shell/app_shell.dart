import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/content_source.dart';
import '../settings/domain/app_settings.dart';
import '../../shared/site_badge.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: theme.scaffoldBackgroundColor,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ListenableBuilder(
        listenable: settingsRepository,
        builder: (context, _) {
          final order = settingsRepository.settings.navigationOrder;
          final selected = order.indexWhere(
            (item) => _branchIndex(item) == navigationShell.currentIndex,
          );
          return Scaffold(
            body: SafeArea(bottom: false, child: navigationShell),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (displayIndex) {
                final destination = order[displayIndex];
                final branchIndex = _branchIndex(destination);
                ref
                    .read(predictivePrefetchServiceProvider)
                    .prioritizeForeground();
                final destinationSite = switch (destination) {
                  AppDestination.rule34video => ContentSite.rule34video,
                  AppDestination.hanime => ContentSite.hanime1,
                  AppDestination.porn91 => ContentSite.porn91,
                  AppDestination.library || AppDestination.profile => null,
                };
                if (destinationSite != null) {
                  unawaited(settingsRepository.setActiveSite(destinationSite));
                }
                navigationShell.goBranch(
                  branchIndex,
                  initialLocation: branchIndex == navigationShell.currentIndex,
                );
              },
              destinations: order
                  .map((item) => _destination(context, item))
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}

int _branchIndex(AppDestination destination) => switch (destination) {
  AppDestination.rule34video => 0,
  AppDestination.hanime => 1,
  AppDestination.porn91 => 2,
  AppDestination.library => 3,
  AppDestination.profile => 4,
};

NavigationDestination _destination(
  BuildContext context,
  AppDestination destination,
) => switch (destination) {
  AppDestination.rule34video => const NavigationDestination(
    icon: SiteBadge(site: ContentSite.rule34video, size: 22),
    selectedIcon: SiteBadge(site: ContentSite.rule34video, size: 22),
    label: 'R34V',
  ),
  AppDestination.hanime => const NavigationDestination(
    icon: SiteBadge(site: ContentSite.hanime1, size: 22),
    selectedIcon: SiteBadge(site: ContentSite.hanime1, size: 22),
    label: 'Hanime',
  ),
  AppDestination.porn91 => const NavigationDestination(
    icon: SiteBadge(site: ContentSite.porn91, size: 22),
    selectedIcon: SiteBadge(site: ContentSite.porn91, size: 22),
    label: '91porn',
  ),
  AppDestination.library => NavigationDestination(
    icon: const Icon(Icons.video_library_outlined),
    selectedIcon: const Icon(Icons.video_library),
    label: context.uiText('媒体库'),
  ),
  AppDestination.profile => NavigationDestination(
    icon: const Icon(Icons.person_outline),
    selectedIcon: const Icon(Icons.person),
    label: context.uiText('我的'),
  ),
};
