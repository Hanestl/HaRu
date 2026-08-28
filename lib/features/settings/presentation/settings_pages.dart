import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/api/rule34video_api.dart';
import '../../../core/logging/app_log_service.dart';
import '../../../core/models/video_models.dart';
import '../../playback/data/playback_repository.dart';
import '../../search/data/search_history_repository.dart';
import '../data/app_settings_repository.dart';
import '../data/app_diagnostics_service.dart';
import '../domain/app_settings.dart';
import '../../../core/models/translation_models.dart';
import 'translation_provider_section.dart';
import '../../../shared/settings_controls.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '显示设置',
      repository: repository,
      builder: (context, settings) => [
        const AppText('界面语言'),
        const SizedBox(height: 10),
        DropdownButtonFormField<AppLanguagePreference>(
          initialValue: settings.language,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: AppLanguagePreference.values
              .map(
                (language) => DropdownMenuItem(
                  value: language,
                  child: language == AppLanguagePreference.system
                      ? AppText(language.label)
                      : Text(language.label),
                ),
              )
              .toList(growable: false),
          onChanged: (language) {
            if (language != null) {
              unawaited(_save(context, repository.setLanguage(language)));
            }
          },
        ),
        const SizedBox(height: 8),
        SettingsField(
          title: '主题模式',
          child: SegmentedButton<AppThemePreference>(
            expandedInsets: EdgeInsets.zero,
            segments: AppThemePreference.values
                .map(
                  (value) => ButtonSegment<AppThemePreference>(
                    value: value,
                    label: AppText(value.label),
                  ),
                )
                .toList(growable: false),
            selected: {settings.theme},
            onSelectionChanged: (selection) {
              unawaited(_save(context, repository.setTheme(selection.single)));
            },
          ),
        ),
        SettingsField(
          title: '标准视频列表布局',
          child: SegmentedButton<ContentLayout>(
            expandedInsets: EdgeInsets.zero,
            segments: ContentLayout.values
                .map(
                  (value) => ButtonSegment<ContentLayout>(
                    value: value,
                    label: AppText(value.label),
                  ),
                )
                .toList(growable: false),
            selected: {settings.videoLayout},
            onSelectionChanged: (selection) {
              unawaited(
                _save(context, repository.setVideoLayout(selection.single)),
              );
            },
          ),
        ),
        SettingsField(
          title: '订阅页布局',
          child: SegmentedButton<ContentLayout>(
            expandedInsets: EdgeInsets.zero,
            segments: ContentLayout.values
                .map(
                  (value) => ButtonSegment<ContentLayout>(
                    value: value,
                    label: AppText(value.label),
                  ),
                )
                .toList(growable: false),
            selected: {settings.subscriptionLayout},
            onSelectionChanged: (selection) {
              unawaited(
                _save(
                  context,
                  repository.setSubscriptionLayout(selection.single),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AppText('底部导航顺序', style: Theme.of(context).textTheme.titleMedium),
        _OrderEditor<AppDestination>(
          values: settings.navigationOrder,
          labelFor: _destinationLabel,
          iconFor: _destinationIcon,
          onReorder: (values) =>
              unawaited(_save(context, repository.setNavigationOrder(values))),
        ),
        const SizedBox(height: 12),
        AppText('媒体库范围顺序', style: Theme.of(context).textTheme.titleMedium),
        _OrderEditor<LibraryScopePreference>(
          values: settings.libraryScopeOrder,
          labelFor: _libraryScopeLabel,
          iconFor: _libraryScopeIcon,
          onReorder: (values) => unawaited(
            _save(context, repository.setLibraryScopeOrder(values)),
          ),
        ),
      ],
    );
  }
}

class _OrderEditor<T> extends StatelessWidget {
  const _OrderEditor({
    required this.values,
    required this.labelFor,
    required this.iconFor,
    required this.onReorder,
  });

  final List<T> values;
  final String Function(T value) labelFor;
  final IconData Function(T value) iconFor;
  final ValueChanged<List<T>> onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: values.length,
      onReorderItem: (oldIndex, newIndex) {
        final reordered = values.toList(growable: true);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        onReorder(reordered);
      },
      itemBuilder: (context, index) {
        final value = values[index];
        return ListTile(
          key: ValueKey<T>(value),
          contentPadding: EdgeInsets.zero,
          leading: Icon(iconFor(value)),
          title: AppText(labelFor(value)),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.drag_handle),
            ),
          ),
        );
      },
    );
  }
}

String _destinationLabel(AppDestination value) => switch (value) {
  AppDestination.rule34video => 'R34V',
  AppDestination.hanime => 'Hanime',
  AppDestination.library => '媒体库',
  AppDestination.profile => '我的',
};

IconData _destinationIcon(AppDestination value) => switch (value) {
  AppDestination.rule34video => Icons.play_circle_outline,
  AppDestination.hanime => Icons.movie_outlined,
  AppDestination.library => Icons.video_library_outlined,
  AppDestination.profile => Icons.person_outline,
};

String _libraryScopeLabel(LibraryScopePreference value) => switch (value) {
  LibraryScopePreference.local => '本机',
  LibraryScopePreference.rule34video => 'R34V',
  LibraryScopePreference.hanime => 'Hanime',
};

IconData _libraryScopeIcon(LibraryScopePreference value) => switch (value) {
  LibraryScopePreference.local => Icons.smartphone_outlined,
  LibraryScopePreference.rule34video => Icons.play_circle_outline,
  LibraryScopePreference.hanime => Icons.movie_outlined,
};

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    final playback = ref.read(playbackRepositoryProvider);
    return _SettingsScaffold(
      title: '播放设置',
      repository: repository,
      builder: (context, settings) => [
        _QualityTile(
          title: '默认播放清晰度',
          value: settings.playbackQuality,
          onChanged: (value) =>
              _save(context, repository.setPlaybackQuality(value)),
        ),
        SettingsDropdownField<NetworkPlaybackPolicy>(
          title: '网络播放策略',
          description: settings.networkPlaybackPolicy.description,
          value: settings.networkPlaybackPolicy,
          items: NetworkPlaybackPolicy.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: AppText(value.label)),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              unawaited(
                _save(context, repository.setNetworkPlaybackPolicy(value)),
              );
            }
          },
        ),
        SettingsSwitchField(
          title: '循环播放',
          value: settings.loopPlayback,
          onChanged: (value) {
            unawaited(_save(context, repository.setLoopPlayback(value)));
          },
        ),
        SettingsSwitchField(
          title: '视频预览',
          description: '长按视频封面预览',
          value: settings.videoPreviewEnabled,
          onChanged: (value) {
            unawaited(_save(context, repository.setVideoPreviewEnabled(value)));
          },
        ),
        SettingsSwitchField(
          title: '播放时保持屏幕常亮',
          description: '仅在视频正在播放时生效，暂停或离开页面后自动恢复。',
          value: settings.keepScreenAwake,
          onChanged: (value) {
            unawaited(_save(context, repository.setKeepScreenAwake(value)));
          },
        ),
        SettingsSwitchField(
          title: '后台播放',
          description: '开启后，切换应用或关闭屏幕时继续播放声音。',
          value: settings.backgroundPlayback,
          onChanged: (value) {
            unawaited(_save(context, repository.setBackgroundPlayback(value)));
          },
        ),
        SettingsDropdownField<FullscreenOrientationPreference>(
          title: '全屏方向',
          value: settings.fullscreenOrientation,
          items: FullscreenOrientationPreference.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: AppText(value.label)),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              unawaited(
                _save(context, repository.setFullscreenOrientation(value)),
              );
            }
          },
        ),
        SettingsSwitchField(
          title: '记忆播放进度',
          description: '在本机保存，与登录账号无关',
          value: settings.rememberPlaybackProgress,
          onChanged: (value) {
            unawaited(
              _changePlaybackProgressSetting(
                context,
                settingsRepository: repository,
                playbackRepository: playback,
                enabled: value,
              ),
            );
          },
        ),
      ],
    );
  }
}

class ContentSettingsPage extends ConsumerWidget {
  const ContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '内容设置',
      repository: repository,
      builder: (context, settings) => [
        SettingsDropdownField<ContentOrientation>(
          title: '首页默认内容取向',
          value: settings.defaultOrientation,
          items: ContentOrientation.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: AppText(value.label)),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              unawaited(
                _save(context, repository.setDefaultOrientation(value)),
              );
            }
          },
        ),
        SettingsSwitchField(
          title: '模糊视频封面',
          description: '首页、搜索和媒体库的视频卡片会模糊显示封面。',
          value: settings.blurThumbnails,
          onChanged: (value) {
            unawaited(_save(context, repository.setBlurThumbnails(value)));
          },
        ),
      ],
    );
  }
}

class TranslationSettingsPage extends ConsumerWidget {
  const TranslationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    final translationService = ref.watch(translationServiceProvider);
    return _SettingsScaffold(
      title: '翻译设置',
      repository: repository,
      builder: (context, settings) {
        TranslationDisplayMode modeFor(TranslationDisplayTarget target) =>
            switch (target) {
              TranslationDisplayTarget.title =>
                settings.titleTranslationDisplayMode,
              TranslationDisplayTarget.category =>
                settings.categoryTranslationDisplayMode,
              TranslationDisplayTarget.tag =>
                settings.tagTranslationDisplayMode,
            };
        return [
          const AppText('翻译目标语言'),
          const SizedBox(height: 4),
          AppText(
            '可跟随界面语言，也可单独指定；不同目标语言的译文会分别保存。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<TranslationTargetPreference>(
            initialValue: settings.translationTarget,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: TranslationTargetPreference.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: value == TranslationTargetPreference.followInterface
                        ? AppText(value.label)
                        : Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  _save(context, repository.setTranslationTarget(value)),
                );
              }
            },
          ),
          const Divider(height: 32),
          AppText('语言显示模式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const AppText('标题、分类和标签可以分别选择显示原文、译文或双语。'),
          const SizedBox(height: 4),
          AppText(
            '提示：长按标题、分类或标签，可以手动添加或修改译文。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final target in TranslationDisplayTarget.values) ...[
            SettingsField(
              title: target.label,
              padding: EdgeInsets.zero,
              child: SegmentedButton<TranslationDisplayMode>(
                expandedInsets: EdgeInsets.zero,
                segments: TranslationDisplayMode.values
                    .map(
                      (mode) => ButtonSegment<TranslationDisplayMode>(
                        value: mode,
                        label: AppText(mode.label),
                      ),
                    )
                    .toList(growable: false),
                selected: {modeFor(target)},
                onSelectionChanged: (selection) => unawaited(
                  _save(
                    context,
                    repository.setTranslationDisplayModeFor(
                      target,
                      selection.single,
                    ),
                  ),
                ),
              ),
            ),
            if (target != TranslationDisplayTarget.values.last)
              const SizedBox(height: 8),
          ],
          const Divider(height: 32),
          AppText('自动翻译', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const AppText('勾选需要自动翻译的内容类型；仅在缺少本地译文且已配置可用翻译服务时请求。默认全部关闭。'),
          const SizedBox(height: 4),
          for (final target in AutomaticTranslationTarget.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: AppText(target.label),
              value: settings.automaticTranslationTargets.contains(target),
              onChanged: (selected) {
                final next = {...settings.automaticTranslationTargets};
                if (selected == true) {
                  next.add(target);
                } else {
                  next.remove(target);
                }
                unawaited(
                  _save(
                    context,
                    repository.setAutomaticTranslationTargets(next),
                  ),
                );
              },
            ),
          ListenableBuilder(
            listenable: translationService,
            builder: (context, _) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_stories_outlined),
              title: const AppText('翻译库'),
              subtitle: AppText(
                '共 ${translationService.catalogEntryCount} 条 · 内置 ${translationService.builtinTotalEntryCount} · API ${translationService.learnedEntryCount} · 用户 ${translationService.overrideEntryCount}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(AppRouteNames.translationCatalog),
            ),
          ),
          const TranslationProviderSection(),
        ];
      },
    );
  }
}

class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '下载设置',
      repository: repository,
      builder: (context, settings) => [
        _DownloadQualityTile(
          value: _DownloadQualityChoice.fromSettings(settings),
          onChanged: (value) => _save(
            context,
            repository.setDownloadQualityPreference(
              askEveryTime: value == _DownloadQualityChoice.ask,
              quality: value.quality ?? settings.downloadQuality,
            ),
          ),
        ),
        SettingsSwitchField(
          title: '仅使用 Wi-Fi 下载',
          description: '新建任务会等待符合条件的网络；已存在任务不被追溯修改。',
          value: settings.wifiOnlyDownloads,
          onChanged: (value) {
            unawaited(_save(context, repository.setWifiOnlyDownloads(value)));
          },
        ),
        SettingsDropdownField<int>(
          title: '同时下载任务数',
          value: settings.downloadConcurrentTasks,
          items: [1, 2, 3, 4]
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value')),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              unawaited(
                _save(context, repository.setDownloadConcurrentTasks(value)),
              );
            }
          },
        ),
        const _InfoCard(
          icon: Icons.folder_outlined,
          text: '视频保存路径：Download/Flule34',
        ),
      ],
    );
  }
}

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  var _clearing = false;
  var _logBusy = false;
  Future<LogStorageInfo>? _logInfo;

  @override
  void initState() {
    super.initState();
    _reloadLogInfo();
  }

  void _reloadLogInfo() {
    _logInfo = ref.read(appLogServiceProvider).storageInfo();
  }

  @override
  Widget build(BuildContext context) {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    final searchHistory = ref.watch(searchHistoryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('隐私与数据')),
      body: ListenableBuilder(
        listenable: settingsRepository,
        builder: (context, _) => AnimatedBuilder(
          animation: widget.api.sessionStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SettingsSwitchField(
                title: '保存搜索历史',
                description: '仅登录后按账号保存；关闭后不再记录新搜索。',
                value: settingsRepository.settings.saveSearchHistory,
                onChanged: (value) => unawaited(
                  _save(
                    context,
                    settingsRepository.setSaveSearchHistory(value),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: const AppText('清除当前账号搜索历史'),
                  enabled: widget.api.sessionStore.isLoggedIn && !_clearing,
                  onTap: widget.api.sessionStore.isLoggedIn && !_clearing
                      ? () => _clearSearchHistory(searchHistory)
                      : null,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const AppText('清除图片缓存'),
                  subtitle: const AppText('不会删除下载的视频或账号数据。'),
                  onTap: _clearing ? null : _clearImageCache,
                ),
              ),
              const SizedBox(height: 12),
              AppText('应用日志', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    FutureBuilder<LogStorageInfo>(
                      future: _logInfo,
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        final status = info == null
                            ? '正在读取日志信息…'
                            : info.formattedSize;
                        return ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: const AppText('本地诊断日志'),
                          subtitle: AppText('仅保存在本机，自动脱敏，保留最近 7 天。\n$status'),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.ios_share_outlined),
                      title: const AppText('导出日志'),
                      subtitle: const AppText('生成包含诊断信息和最近日志的文本文件。'),
                      enabled: !_logBusy,
                      onTap: _logBusy ? null : _exportLogs,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined),
                      title: const AppText('清除日志'),
                      subtitle: const AppText('删除这台设备上的全部应用日志。'),
                      enabled: !_logBusy,
                      onTap: _logBusy ? null : _clearLogs,
                    ),
                  ],
                ),
              ),
              if (widget.api.sessionStore.isLoggedIn) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearing
                      ? null
                      : () => _confirmLogout(context, widget.api),
                  icon: const Icon(Icons.logout),
                  label: const AppText('退出当前账号'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    setState(() => _logBusy = true);
    try {
      final diagnostics = await AppDiagnosticsService(
        ref.read(appDatabaseProvider),
        ref.read(sessionStoreProvider),
        ref.read(appSettingsRepositoryProvider).settings,
      ).collect();
      final logs = await ref.read(appLogServiceProvider).readAll();
      final now = DateTime.now();
      final content = StringBuffer()
        ..writeln('HaRu 本地诊断日志')
        ..writeln('导出时间：${now.toIso8601String()}')
        ..writeln('隐私说明：日志已自动脱敏，发送前仍建议自行检查。')
        ..writeln()
        ..writeln('===== 诊断信息 =====')
        ..writeln(diagnostics.toPlainText())
        ..writeln()
        ..writeln('===== 最近 7 天日志 =====')
        ..write(logs.isEmpty ? '没有可导出的日志。\n' : logs);
      final fileName = logExportFileName(now);
      final export = await ref
          .read(appLogServiceProvider)
          .createExportFile(content.toString(), fileName: fileName);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(export.path, mimeType: 'text/plain')],
          subject: 'HaRu 本地诊断日志',
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        ref
            .read(appLogServiceProvider)
            .error(error, stackTrace, component: 'log_export'),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('导出日志失败，请稍后重试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _logBusy = false);
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('清除应用日志？'),
        content: const AppText('将删除这台设备上的全部诊断日志，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _logBusy = true);
    try {
      await ref.read(appLogServiceProvider).clear();
      if (!mounted) {
        return;
      }
      setState(_reloadLogInfo);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('应用日志已清除。')));
    } catch (error, stackTrace) {
      unawaited(
        ref
            .read(appLogServiceProvider)
            .error(error, stackTrace, component: 'log_clear'),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('清除日志失败，请稍后重试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _logBusy = false);
      }
    }
  }

  Future<void> _clearImageCache() async {
    setState(() => _clearing = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await DefaultCacheManager().emptyCache();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('图片缓存已清除。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('清除图片缓存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _clearSearchHistory(
    SearchHistoryRepository searchHistory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('清除搜索历史？'),
        content: const AppText('只会删除当前账号在这台设备上的搜索记录。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await searchHistory.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('搜索历史已清除。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('清除搜索历史失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.repository,
    required this.builder,
  });

  final String title;
  final AppSettingsRepository repository;
  final List<Widget> Function(BuildContext context, AppSettings settings)
  builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText(title)),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: builder(context, repository.settings),
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final VideoQualityPreference value;
  final Future<void> Function(VideoQualityPreference value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsDropdownField<VideoQualityPreference>(
      title: title,
      value: value,
      items: VideoQualityPreference.values
          .map(
            (quality) =>
                DropdownMenuItem(value: quality, child: AppText(quality.label)),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) {
          unawaited(onChanged(next));
        }
      },
    );
  }
}

enum _DownloadQualityChoice {
  ask(null),
  highest(VideoQualityPreference.highest),
  p2160(VideoQualityPreference.p2160),
  p1080(VideoQualityPreference.p1080),
  p720(VideoQualityPreference.p720),
  p480(VideoQualityPreference.p480),
  p360(VideoQualityPreference.p360);

  const _DownloadQualityChoice(this.quality);

  final VideoQualityPreference? quality;

  String get label => quality?.label ?? '每次询问';

  static _DownloadQualityChoice fromSettings(AppSettings settings) {
    if (settings.askDownloadQuality) {
      return ask;
    }
    return values.firstWhere(
      (choice) => choice.quality == settings.downloadQuality,
      orElse: () => highest,
    );
  }
}

class _DownloadQualityTile extends StatelessWidget {
  const _DownloadQualityTile({required this.value, required this.onChanged});

  final _DownloadQualityChoice value;
  final Future<void> Function(_DownloadQualityChoice value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsDropdownField<_DownloadQualityChoice>(
      title: '下载清晰度',
      value: value,
      items: _DownloadQualityChoice.values
          .map(
            (choice) =>
                DropdownMenuItem(value: choice, child: AppText(choice.label)),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) {
          unawaited(onChanged(next));
        }
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: AppText(text)),
          ],
        ),
      ),
    );
  }
}

Future<void> _save(BuildContext context, Future<void> operation) async {
  try {
    await operation;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText('保存设置失败：$error')));
    }
  }
}

Future<void> _changePlaybackProgressSetting(
  BuildContext context, {
  required AppSettingsRepository settingsRepository,
  required PlaybackRepository playbackRepository,
  required bool enabled,
}) async {
  if (enabled) {
    await _save(context, settingsRepository.setRememberPlaybackProgress(true));
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppText('关闭记忆播放进度？'),
      content: const AppText('关闭后将清除全部本地播放进度。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const AppText('关闭并清除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  var disabled = false;
  try {
    await settingsRepository.setRememberPlaybackProgress(false);
    disabled = true;
    await playbackRepository.clearAll();
  } catch (error) {
    if (disabled) {
      await settingsRepository.setRememberPlaybackProgress(true);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText('清除播放进度失败：$error')));
    }
  }
}

Future<void> _confirmLogout(BuildContext context, Rule34VideoApi api) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppText('退出登录？'),
      content: const AppText('下载属于本机功能，退出登录不会取消下载或删除公共目录中的文件。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const AppText('退出'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    Object? logoutError;
    try {
      await api.logout();
    } catch (error) {
      logoutError = error;
    }
    final messenger = context.mounted
        ? ScaffoldMessenger.maybeOf(context)
        : null;
    if (logoutError != null) {
      messenger?.showSnackBar(
        const SnackBar(content: AppText('网站退出请求失败，但本地登录状态已经清除。')),
      );
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
