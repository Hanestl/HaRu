import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/content_source.dart';
import '../../shared/site_badge.dart';
import '../settings/domain/app_settings.dart';
import '../settings/presentation/app_update_flow.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _startupUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _startupUpdateChecked) {
        return;
      }
      _startupUpdateChecked = true;
      unawaited(checkForUpdateOnStartup(context, ref));
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
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
                if (destination == AppDestination.rule34video) {
                  unawaited(
                    settingsRepository.setActiveSite(ContentSite.rule34video),
                  );
                } else if (destination == AppDestination.hanime) {
                  unawaited(
                    settingsRepository.setActiveSite(ContentSite.hanime1),
                  );
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
  AppDestination.library => 2,
  AppDestination.profile => 3,
};

NavigationDestination _destination(
  BuildContext context,
  AppDestination destination,
) => switch (destination) {
  AppDestination.rule34video => const NavigationDestination(
    icon: SiteBadge(site: ContentSite.rule34video, size: 22, isSelected: false),
    selectedIcon: SiteBadge(
      site: ContentSite.rule34video,
      size: 22,
      isSelected: true,
    ),
    label: 'R34V',
  ),
  AppDestination.hanime => const NavigationDestination(
    icon: SiteBadge(site: ContentSite.hanime1, size: 22, isSelected: false),
    selectedIcon: SiteBadge(
      site: ContentSite.hanime1,
      size: 22,
      isSelected: true,
    ),
    label: 'Hanime',
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
