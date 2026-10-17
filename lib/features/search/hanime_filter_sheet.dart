import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api/hanime1_search_options.g.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/hanime_search_models.dart';
import '../../shared/settings_controls.dart';
import '../../shared/transient_focus.dart';

/// 下拉框哨兵值：表示“全部/不筛选”。DropdownButtonFormField 不允许
/// 把 null 作为可选 value，因此用哨兵字符串占位，选中时再映射回 null。
const _allKey = '__hanime_filter_all__';

/// 日期下拉的“指定月份”选项。
const _monthKey = '__hanime_filter_month__';

Future<HanimeSearchFilters?> showHanimeFilterSheet({
  required BuildContext context,
  required HanimeSearchFilters initialFilters,
}) {
  return runWithoutRestoringInputFocus(
    context,
    () => showModalBottomSheet<HanimeSearchFilters>(
      context: context,
      requestFocus: false,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      builder: (context) => _HanimeFilterSheet(initialFilters: initialFilters),
    ),
  );
}

class _HanimeFilterSheet extends StatefulWidget {
  const _HanimeFilterSheet({required this.initialFilters});

  final HanimeSearchFilters initialFilters;

  @override
  State<_HanimeFilterSheet> createState() => _HanimeFilterSheetState();
}

class _HanimeFilterSheetState extends State<_HanimeFilterSheet> {
  static const _minYear = 1990;

  late HanimeSearchFilters _draft = widget.initialFilters;
  final _tagFilterController = TextEditingController();
  final _brandFilterController = TextEditingController();

  /// Hanime 筛选选项显示固定用简体：hanime1 官网无论用户系统语言都返回
  /// 简体中文（里番/泡面番），app 侧与其保持一致，不跟随系统 locale。
  String get _localeCode => 'zh';

  /// 指定月份下拉的默认值：进入“指定月份”时若未选，落到当前年月。
  late int _monthYear = DateTime.now().year;
  late int _monthMonth = DateTime.now().month;

  @override
  void dispose() {
    _tagFilterController.dispose();
    _brandFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    'Hanime 筛选与排序',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = const HanimeSearchFilters()),
                  child: const AppText('全部清除'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _title(context, '分类'),
                _selectorField(
                  title: '分类',
                  value: _draft.genre ?? _allKey,
                  items: [
                    const DropdownMenuItem(
                      value: _allKey,
                      child: AppText('全部'),
                    ),
                    for (final option in hanimeGenres)
                      if (_usableSearchKey(option.searchKey) != null)
                        DropdownMenuItem(
                          value: option.searchKey,
                          child: Text(option.displayName(_localeCode)),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(genre: _selectedOrNull(value));
                    });
                  },
                ),
                const SizedBox(height: 18),
                _title(context, '排序'),
                _selectorField(
                  title: '排序',
                  value: _draft.sort ?? _allKey,
                  items: [
                    const DropdownMenuItem(
                      value: _allKey,
                      child: AppText('默认排序'),
                    ),
                    for (final option in hanimeSorts)
                      if (_usableSearchKey(option.searchKey) != null)
                        DropdownMenuItem(
                          value: option.searchKey,
                          child: Text(option.displayName(_localeCode)),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(sort: _selectedOrNull(value));
                    });
                  },
                ),
                const SizedBox(height: 18),
                _title(context, '时长'),
                _durationSection(),
                const SizedBox(height: 18),
                _title(context, '发布日期'),
                _dateSection(),
                const SizedBox(height: 18),
                SettingsSwitchField(
                  title: '宽泛搜索',
                  description: '放宽匹配规则，可能返回标题仅部分匹配的结果。',
                  value: _draft.broad,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(broad: value)),
                ),
                const SizedBox(height: 18),
                _title(context, '标签'),
                _filterableMultiSelect(
                  controller: _tagFilterController,
                  hintText: '过滤标签…',
                  groups: hanimeTagGroups,
                ),
                const SizedBox(height: 18),
                _title(context, '品牌'),
                _brandsSection(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    AppLogService.instance.info(
                      'Hanime 筛选 sheet 应用；摘要=${hanimeFiltersSummary(_draft)}',
                      component: 'hanime_filter',
                    ),
                  );
                  Navigator.of(context).pop(_draft);
                },
                child: AppText(
                  _draft.activeCount == 0
                      ? '应用（不限）'
                      : '应用 ${_draft.activeCount} 个条件',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: const AppText('全部'),
          selected: _draft.duration == null,
          onSelected: (_) =>
              setState(() => _draft = _draft.copyWith(duration: null)),
        ),
        for (final option in hanimeDurations)
          if (_usableSearchKey(option.searchKey) != null)
            ChoiceChip(
              label: Text(option.displayName(_localeCode)),
              selected: _draft.duration == option.searchKey,
              onSelected: (selected) => setState(() {
                _draft = _draft.copyWith(
                  duration: selected ? option.searchKey : null,
                );
              }),
            ),
      ],
    );
  }

  Widget _dateSection() {
    final date = _draft.date;
    final dropdownValue = switch (date) {
      null => _allKey,
      HanimeDateFilter(:final presetSearchKey?) => presetSearchKey,
      HanimeDateFilter() => _monthKey,
    };
    final isMonthMode =
        date is HanimeDateFilter && date.presetSearchKey == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectorField(
          title: '发布日期',
          value: dropdownValue,
          items: [
            const DropdownMenuItem(value: _allKey, child: AppText('全部')),
            for (final option in hanimeReleaseDates)
              if (_usableSearchKey(option.searchKey) != null)
                DropdownMenuItem(
                  value: option.searchKey,
                  child: Text(option.displayName(_localeCode)),
                ),
            const DropdownMenuItem(value: _monthKey, child: AppText('指定月份…')),
          ],
          onChanged: (value) {
            setState(() {
              _draft = switch (value) {
                _allKey || null => _draft.copyWith(date: null),
                _monthKey => _draft.copyWith(
                  date: HanimeDateFilter.month(
                    year: _monthYear,
                    month: _monthMonth,
                  ),
                ),
                final String key => _draft.copyWith(
                  date: HanimeDateFilter.preset(key),
                ),
              };
            });
          },
        ),
        if (isMonthMode) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _selectorField(
                  title: '年份',
                  value: '$_monthYear',
                  items: [
                    for (
                      var year = DateTime.now().year;
                      year >= _minYear;
                      year -= 1
                    )
                      DropdownMenuItem(
                        value: '$year',
                        child: AppText('$year 年'),
                      ),
                  ],
                  onChanged: (value) {
                    final year = int.tryParse(value ?? '');
                    if (year == null) return;
                    setState(() {
                      _monthYear = year;
                      final existing = _draft.date;
                      _draft = _draft.copyWith(
                        date: HanimeDateFilter.month(
                          year: year,
                          month:
                              existing is HanimeDateFilter &&
                                  existing.month != null
                              ? existing.month!
                              : _monthMonth,
                        ),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectorField(
                  title: '月份',
                  value: '$_monthMonth',
                  items: [
                    for (var month = 1; month <= 12; month += 1)
                      DropdownMenuItem(
                        value: '$month',
                        child: AppText('$month 月'),
                      ),
                  ],
                  onChanged: (value) {
                    final month = int.tryParse(value ?? '');
                    if (month == null) return;
                    setState(() {
                      _monthMonth = month;
                      final existing = _draft.date;
                      _draft = _draft.copyWith(
                        date: HanimeDateFilter.month(
                          year:
                              existing is HanimeDateFilter &&
                                  existing.year != null
                              ? existing.year!
                              : _monthYear,
                          month: month,
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _brandsSection() {
    final query = _brandFilterController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? hanimeBrands
        : hanimeBrands
              .where(
                (option) =>
                    option.searchKey != null &&
                    (option.searchKey!.toLowerCase().contains(query) ||
                        option
                            .displayName(_localeCode)
                            .toLowerCase()
                            .contains(query)),
              )
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _brandFilterController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '过滤品牌…',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const AppText('没有匹配的品牌。', style: TextStyle(fontSize: 13))
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final option in visible)
                if (option.searchKey != null)
                  FilterChip(
                    label: Text(
                      option.displayName(_localeCode),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _draft.brands.contains(option.searchKey),
                    onSelected: (selected) => setState(() {
                      final brands = _draft.brands.toSet();
                      if (selected) {
                        brands.add(option.searchKey!);
                      } else {
                        brands.remove(option.searchKey);
                      }
                      _draft = _draft.copyWith(brands: brands);
                    }),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _filterableMultiSelect({
    required TextEditingController controller,
    required String hintText,
    required List<HanimeTagGroup> groups,
  }) {
    final query = controller.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        if (query.isNotEmpty)
          _flattenedTagChips(query)
        else
          for (final group in groups) _tagGroupSection(group),
      ],
    );
  }

  Widget _flattenedTagChips(String query) {
    final matches = <HanimeSearchOption>[];
    for (final group in hanimeTagGroups) {
      for (final option in group.options) {
        final key = option.searchKey;
        if (key != null &&
            (key.toLowerCase().contains(query) ||
                option
                    .displayName(_localeCode)
                    .toLowerCase()
                    .contains(query))) {
          matches.add(option);
        }
      }
    }
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AppText('没有匹配的标签。', style: TextStyle(fontSize: 13)),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final option in matches)
          FilterChip(
            label: Text(
              option.displayName(_localeCode),
              style: const TextStyle(fontSize: 12),
            ),
            selected: _draft.tags.contains(option.searchKey),
            onSelected: (selected) => setState(() {
              final tags = _draft.tags.toSet();
              if (selected) {
                tags.add(option.searchKey!);
              } else {
                tags.remove(option.searchKey);
              }
              _draft = _draft.copyWith(tags: tags);
            }),
          ),
      ],
    );
  }

  Widget _tagGroupSection(HanimeTagGroup group) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(group.displayName(_localeCode)),
      subtitle: AppText('已选 ${_selectedInGroup(group)} 个'),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final option in group.options)
              if (option.searchKey != null)
                FilterChip(
                  label: Text(
                    option.displayName(_localeCode),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _draft.tags.contains(option.searchKey),
                  onSelected: (selected) => setState(() {
                    final tags = _draft.tags.toSet();
                    if (selected) {
                      tags.add(option.searchKey!);
                    } else {
                      tags.remove(option.searchKey);
                    }
                    _draft = _draft.copyWith(tags: tags);
                  }),
                ),
          ],
        ),
      ],
    );
  }

  int _selectedInGroup(HanimeTagGroup group) {
    return group.options.where((option) {
      final key = option.searchKey;
      return key != null && _draft.tags.contains(key);
    }).length;
  }

  Widget _selectorField({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SettingsDropdownField<String>(
      title: title,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _title(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppText(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  /// 选项的 searchKey 若为 null 或“全部”，由 UI 的统一“全部”入口代替。
  String? _usableSearchKey(String? searchKey) {
    if (searchKey == null || searchKey.isEmpty || searchKey == '全部') {
      return null;
    }
    return searchKey;
  }

  String? _selectedOrNull(String? value) {
    if (value == null || value == _allKey) return null;
    return value;
  }
}
