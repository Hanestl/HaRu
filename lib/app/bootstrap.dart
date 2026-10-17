import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/error_redaction.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/ui_localization.dart';
import 'app.dart';
import 'providers.dart';
import 'theme/app_theme.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(appInitializationProvider);

    return initialization.when(
      data: (_) => const Flule34App(),
      loading: () => const _BootstrapScreen(),
      error: (error, stackTrace) {
        return _BootstrapScreen(
          error: redactSensitiveText(error),
          onRetry: () => ref.invalidate(appInitializationProvider),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 52),
                      const SizedBox(height: 16),
                      AppText(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: onRetry,
                        child: const AppText('重试'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
