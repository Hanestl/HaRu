import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/models/translation_models.dart';
import '../../../core/models/video_models.dart';
import '../../../core/services/translation_catalog_archive.dart';
import '../../../core/services/translation_service.dart';
import '../../../shared/editable_translation.dart';
import '../../../shared/error_view.dart';
import '../../../shared/transient_focus.dart';

int compareTranslationCatalogItems(
  TranslationCatalogItem left,
  TranslationCatalogItem right,
  TranslationCatalogSort sort,
) {
  return switch (sort) {
    TranslationCatalogSort.updatedDesc =>
      _compareCatalogDatesDescending(left.updatedAt, right.updatedAt) != 0
          ? _compareCatalogDatesDescending(left.updatedAt, right.updatedAt)
          : left.sourceText.compareTo(right.sourceText),
    TranslationCatalogSort.originalAsc => left.sourceText.compareTo(
      right.sourceText,
    ),
    TranslationCatalogSort.translationAsc =>
      left.effectiveTranslation.compareTo(right.effectiveTranslation),
    TranslationCatalogSort.source =>
      left.effectiveSource.index.compareTo(right.effectiveSource.index) != 0
          ? left.effectiveSource.index.compareTo(right.effectiveSource.index)
          : left.sourceText.compareTo(right.sourceText),
  };
}

int _compareCatalogDatesDescending(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}

class TranslationCatalogPage extends ConsumerStatefulWidget {
  const TranslationCatalogPage({super.key});

  @override
  ConsumerState<TranslationCatalogPage> createState() =>
      _TranslationCatalogPageState();
}

class _TranslationCatalogPageState
    extends ConsumerState<TranslationCatalogPage> {
  final _searchController = TextEditingController();
  final _selectedKeys = <String>{};
  String _query = '';
  TranslationCatalogKind? _kind;
  TranslationCatalogSource? _source;
  TranslationLanguage? _language;
  TranslationCatalogSort _sort = TranslationCatalogSort.updatedDesc;
  Timer? _searchDebounce;
  var _transferBusy = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(translationServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final items = _filteredItems(service.catalogItems());
        return Scaffold(
          appBar: AppBar(
            title: AppText(
              _selectedKeys.isEmpty ? '翻译库' : '已选择 ${_selectedKeys.length} 项',
            ),
            actions: [
              if (_selectedKeys.isEmpty)
                _transferBusy
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : PopupMenuButton<_TranslationCatalogAction>(
                        requestFocus: false,
                        onOpened: dismissInputFocus,
                        tooltip: context.uiText('导入或导出'),
                        icon: const Icon(Icons.import_export),
                        onSelected: (action) {
                          switch (action) {
                            case _TranslationCatalogAction.import:
                              unawaited(_importCatalog(service));
                            case _TranslationCatalogAction.export:
                              unawaited(_exportCatalog(service));
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _TranslationCatalogAction.import,
                            child: ListTile(
                              leading: Icon(Icons.file_open_outlined),
                              title: AppText('导入翻译库'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _TranslationCatalogAction.export,
                            child: ListTile(
                              leading: Icon(Icons.ios_share_outlined),
                              title: AppText('导出翻译库'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
              IconButton(
                tooltip: context.uiText('筛选与排序'),
                onPressed: _showFilters,
                icon: Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  child: const Icon(Icons.tune),
                ),
              ),
              if (_selectedKeys.isNotEmpty)
                IconButton(
                  tooltip: context.uiText('选择当前结果'),
                  onPressed: () => setState(() {
                    _selectedKeys.addAll(items.map(_itemKey));
                  }),
                  icon: const Icon(Icons.select_all),
                ),
              if (_selectedKeys.isNotEmpty)
                IconButton(
                  tooltip: context.uiText('取消选择'),
                  onPressed: () => setState(_selectedKeys.clear),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search),
                  hintText: context.uiText('搜索原文、译文或翻译服务'),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: context.uiText('清除'),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 180),
                      () {
                        if (mounted) setState(() => _query = value.trim());
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    '共 ${items.length} 条 · 内置 ${service.builtinTotalEntryCount} · API ${service.learnedEntryCount} · 用户 ${service.overrideEntryCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: AppText('没有符合条件的译文。'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildItem(context, service, items[index]),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: _selectedKeys.isEmpty
              ? null
              : _buildBatchBar(service, items),
        );
      },
    );
  }

  int get _activeFilterCount =>
      (_kind == null ? 0 : 1) +
      (_source == null ? 0 : 1) +
      (_language == null ? 0 : 1) +
      (_sort == TranslationCatalogSort.updatedDesc ? 0 : 1);

  Future<void> _exportCatalog(TranslationService service) async {
    setState(() => _transferBusy = true);
    try {
      final package = await PackageInfo.fromPlatform();
      const archiveService = TranslationCatalogArchiveService();
      final content = archiveService.encodeCatalog(
        service.catalogItems(),
        appVersion: '${package.version}+${package.buildNumber}',
      );
      final file = await archiveService.createExportFile(content);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'HaRu 翻译库',
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        ref
            .read(appLogServiceProvider)
            .error(error, stackTrace, component: 'translation_export'),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('导出翻译库失败。')));
      }
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _importCatalog(TranslationService service) async {
    setState(() => _transferBusy = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'HaRu 翻译库',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      final selected = await openFile(acceptedTypeGroups: [typeGroup]);
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      const archiveService = TranslationCatalogArchiveService();
      final archive = archiveService.parseBytes(bytes);
      if (!mounted) return;
      final mode = await _chooseImportMode(archive);
      if (mode == null || !mounted) return;
      final result = await service.importCatalogArchive(archive, mode: mode);
      if (!mounted) return;
      setState(_selectedKeys.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '已导入 ${result.importedTotal} 层译文'
            '（API ${result.importedLearned}、用户 ${result.importedUserOverrides}）；'
            '跳过 ${result.skippedLearned + result.skippedUserOverrides}，'
            '忽略内置 ${result.ignoredBuiltIn}。',
          ),
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        ref
            .read(appLogServiceProvider)
            .error(error, stackTrace, component: 'translation_import'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('导入失败：${friendlyErrorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<TranslationImportMode?> _chooseImportMode(
    ParsedTranslationArchive archive,
  ) {
    return showDialog<TranslationImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('导入翻译库'),
        content: AppText(
          '文件包含 API 译文 ${archive.learnedLayerCount} 条、'
          '用户译文 ${archive.userLayerCount} 条。\n\n'
          '另有 ${archive.builtInLayerCount} 条内置译文，仅用于审计，'
          '导入时会忽略。请选择冲突处理方式。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, TranslationImportMode.importedLayersWin),
            child: const AppText('导入文件优先'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, TranslationImportMode.safeMerge),
            child: const AppText('安全合并'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters() async {
    var selectedKind = _kind;
    var selectedSource = _source;
    var selectedLanguage = _language;
    var selectedSort = _sort;
    final selected = await runWithoutRestoringInputFocus(
      context,
      () =>
          showModalBottomSheet<
            ({
              TranslationCatalogKind? kind,
              TranslationCatalogSource? source,
              TranslationLanguage? language,
              TranslationCatalogSort sort,
            })
          >(
            context: context,
            requestFocus: false,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) => StatefulBuilder(
              builder: (context, setSheetState) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppText(
                        '筛选与排序',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      AppText(
                        '类型',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const AppText('全部'),
                            selected: selectedKind == null,
                            onSelected: (_) =>
                                setSheetState(() => selectedKind = null),
                          ),
                          for (final kind in TranslationCatalogKind.values)
                            ChoiceChip(
                              label: AppText(kind.label),
                              selected: selectedKind == kind,
                              onSelected: (_) =>
                                  setSheetState(() => selectedKind = kind),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppText(
                        '来源',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const AppText('全部'),
                            selected: selectedSource == null,
                            onSelected: (_) =>
                                setSheetState(() => selectedSource = null),
                          ),
                          for (final source in TranslationCatalogSource.values)
                            ChoiceChip(
                              label: AppText(source.label),
                              selected: selectedSource == source,
                              onSelected: (_) =>
                                  setSheetState(() => selectedSource = source),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppText(
                        '目标语言',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const AppText('全部'),
                            selected: selectedLanguage == null,
                            onSelected: (_) =>
                                setSheetState(() => selectedLanguage = null),
                          ),
                          for (final language in TranslationLanguage.values)
                            ChoiceChip(
                              label: Text(language.label),
                              selected: selectedLanguage == language,
                              onSelected: (_) => setSheetState(
                                () => selectedLanguage = language,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<TranslationCatalogSort>(
                        initialValue: selectedSort,
                        decoration: InputDecoration(
                          labelText: context.uiText('排序'),
                          border: OutlineInputBorder(),
                        ),
                        items: TranslationCatalogSort.values
                            .map(
                              (sort) => DropdownMenuItem(
                                value: sort,
                                child: AppText(sort.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => selectedSort = value);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setSheetState(() {
                              selectedKind = null;
                              selectedSource = null;
                              selectedLanguage = null;
                              selectedSort = TranslationCatalogSort.updatedDesc;
                            }),
                            child: const AppText('重置'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, (
                              kind: selectedKind,
                              source: selectedSource,
                              language: selectedLanguage,
                              sort: selectedSort,
                            )),
                            child: const AppText('应用'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _kind = selected.kind;
      _source = selected.source;
      _language = selected.language;
      _sort = selected.sort;
    });
  }

  Widget _buildItem(
    BuildContext context,
    TranslationService service,
    TranslationCatalogItem item,
  ) {
    final key = _itemKey(item);
    final selected = _selectedKeys.contains(key);
    return ListTile(
      selected: selected,
      leading: _selectedKeys.isEmpty
          ? Icon(_kindIcon(item.kind))
          : Checkbox(value: selected, onChanged: (_) => _toggle(item)),
      title: Text(item.sourceText),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Text(
            item.effectiveTranslation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.targetLanguage.label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              _SourceBadge(source: item.effectiveSource, effective: true),
              for (final source in item.sources)
                if (source != item.effectiveSource)
                  _SourceBadge(source: source),
              if (item.learnedProviderName?.isNotEmpty == true)
                Text(
                  item.learnedProviderName!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (item.updatedAt != null)
                Text(
                  _formatDate(item.updatedAt!),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      onLongPress: () => _toggle(item),
      onTap: () {
        if (_selectedKeys.isNotEmpty) {
          _toggle(item);
        } else {
          unawaited(_editItem(context, service, item));
        }
      },
    );
  }

  Widget _buildBatchBar(
    TranslationService service,
    List<TranslationCatalogItem> visibleItems,
  ) {
    final selected = visibleItems
        .where((item) => _selectedKeys.contains(_itemKey(item)))
        .toList(growable: false);
    final canReset = selected.any((item) => item.hasUserOverride);
    final canDeleteLearned = selected.any((item) => item.hasLearned);
    return SafeArea(
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canReset
                      ? () => _resetOverrides(service, selected)
                      : null,
                  icon: const Icon(Icons.restore),
                  label: const AppText('撤销自定义'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: canDeleteLearned
                      ? () => _deleteLearned(service, selected)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const AppText('删除 API 译文'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TranslationCatalogItem> _filteredItems(
    List<TranslationCatalogItem> source,
  ) {
    final query = _query.toLowerCase();
    final result = source
        .where((item) {
          if (_kind != null && item.kind != _kind) return false;
          if (_source != null && !item.sources.contains(_source)) return false;
          if (_language != null && item.targetLanguage != _language) {
            return false;
          }
          if (query.isEmpty) return true;
          return [
            item.sourceText,
            item.effectiveTranslation,
            item.builtInTranslation,
            item.learnedTranslation,
            item.userTranslation,
            item.learnedProviderName,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
    result.sort(
      (left, right) => compareTranslationCatalogItems(left, right, _sort),
    );
    return result;
  }

  Future<void> _editItem(
    BuildContext context,
    TranslationService service,
    TranslationCatalogItem item,
  ) async {
    if (item.kind == TranslationCatalogKind.title) {
      await showTitleTranslationEditDialog(
        context,
        translationService: service,
        videoId: item.canonicalName,
        english: item.sourceText,
        videoSlug: item.videoSlug,
        targetLanguage: item.targetLanguage,
        siteId: item.siteId,
      );
      return;
    }
    await showTranslationEditDialog(
      context,
      translationService: service,
      kind: item.kind == TranslationCatalogKind.tag
          ? DiscoveryKind.tag
          : DiscoveryKind.category,
      english: item.sourceText,
      targetLanguage: item.targetLanguage,
      siteId: item.siteId,
    );
  }

  Future<void> _resetOverrides(
    TranslationService service,
    List<TranslationCatalogItem> items,
  ) async {
    for (final item in items.where((item) => item.hasUserOverride)) {
      if (item.kind == TranslationCatalogKind.title) {
        await service.removeTitleOverride(
          item.canonicalName,
          language: item.targetLanguage,
          siteId: item.siteId,
        );
      } else {
        await service.removeOverride(
          item.kind == TranslationCatalogKind.tag
              ? DiscoveryKind.tag
              : DiscoveryKind.category,
          item.sourceText,
          language: item.targetLanguage,
          siteId: item.siteId,
        );
      }
    }
    if (mounted) setState(_selectedKeys.clear);
  }

  Future<void> _deleteLearned(
    TranslationService service,
    List<TranslationCatalogItem> items,
  ) async {
    final count = items.where((item) => item.hasLearned).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('删除所选 API 译文？'),
        content: AppText('将永久删除 $count 条 API 译文。用户手动译文和内置译文不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await service.deleteLearnedTranslations(items);
    if (mounted) setState(_selectedKeys.clear);
  }

  void _toggle(TranslationCatalogItem item) {
    final key = _itemKey(item);
    setState(() {
      if (!_selectedKeys.add(key)) _selectedKeys.remove(key);
    });
  }

  static String _itemKey(TranslationCatalogItem item) =>
      '${item.siteId}:${item.targetLanguage.code}:${item.kind.name}:${item.canonicalName}';

  static IconData _kindIcon(TranslationCatalogKind kind) => switch (kind) {
    TranslationCatalogKind.title => Icons.title,
    TranslationCatalogKind.category => Icons.category_outlined,
    TranslationCatalogKind.tag => Icons.tag,
  };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

enum _TranslationCatalogAction { import, export }

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source, this.effective = false});

  final TranslationCatalogSource source;
  final bool effective;

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      TranslationCatalogSource.userOverride => Theme.of(
        context,
      ).colorScheme.primary,
      TranslationCatalogSource.learned => Theme.of(
        context,
      ).colorScheme.tertiary,
      TranslationCatalogSource.builtIn => Theme.of(
        context,
      ).colorScheme.secondary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: effective ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: AppText(
          effective ? '${source.label} · 生效' : source.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
