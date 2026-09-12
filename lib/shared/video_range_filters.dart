import 'dart:async';

import 'package:flutter/material.dart';

import '../core/logging/app_log_service.dart';
import '../core/models/video_models.dart';
import '../l10n/ui_localization.dart';
import 'transient_focus.dart';

class VideoRangeFilter extends StatelessWidget {
  const VideoRangeFilter({
    super.key,
    required this.filters,
    required this.onChanged,
    this.date = false,
    this.compact = false,
  });

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;
  final bool date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = date ? '发布时间' : '视频时长';
    final active = date ? filters.hasDateFilter : filters.hasDurationFilter;
    final label = date ? filters.dateLabel : filters.durationLabel;
    return PopupMenuButton<int>(
      tooltip: context.uiText(title),
      onSelected: (index) async {
        SearchFilters? next;
        if (index == -1) {
          if (date) {
            final range = await showVideoDateRangeDialog(
              context,
              filters.customDateRange,
            );
            if (range != null) {
              next = filters.copyWith(
                uploadPeriod: UploadPeriod.anytime,
                customDateRange: range.isEmpty ? null : range,
              );
            }
          } else {
            final range = await showVideoDurationRangeDialog(
              context,
              filters.customDurationRange,
            );
            if (range != null) {
              next = filters.copyWith(
                duration: VideoDurationPreset.any,
                customDurationRange: range.isEmpty ? null : range,
              );
            }
          }
        } else {
          next = date
              ? filters.copyWith(uploadPeriod: UploadPeriod.values[index])
              : filters.copyWith(duration: VideoDurationPreset.values[index]);
        }
        if (!context.mounted || next == null) return;
        unawaited(
          AppLogService.instance.info(
            'selection kind=${date ? "date" : "duration"} ranges=${next.rangeKey}',
            component: 'r34v_filters',
          ),
        );
        onChanged(next);
      },
      itemBuilder: (context) => [
        for (
          var i = 0;
          i <
              (date
                  ? UploadPeriod.values.length
                  : VideoDurationPreset.values.length);
          i++
        )
          PopupMenuItem(
            value: i,
            child: AppText(
              date
                  ? UploadPeriod.values[i].label
                  : VideoDurationPreset.values[i].label,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: -1, child: AppText('自定义…')),
      ],
      child: compact
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: AppText(active ? label : title),
                avatar: const Icon(Icons.arrow_drop_down, size: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InputDecorator(
                decoration: InputDecoration(labelText: context.uiText(title)),
                child: Row(
                  children: [
                    Expanded(child: AppText(label)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<VideoDurationRange?> showVideoDurationRangeDialog(
  BuildContext context,
  VideoDurationRange? initial,
) => runWithoutRestoringInputFocus(
  context,
  () => showDialog<VideoDurationRange>(
    context: context,
    builder: (_) => _DurationDialog(initial: initial),
  ),
);

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({this.initial});
  final VideoDurationRange? initial;
  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  final _form = GlobalKey<FormState>();
  late final _from = TextEditingController(
    text: widget.initial?.minSeconds?.toString() ?? '',
  );
  late final _to = TextEditingController(
    text: widget.initial?.maxSeconds?.toString() ?? '',
  );

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = int.tryParse(text.trim());
    if (value == null || value < 0 || value > 36000) {
      return context.uiText('请输入 0 至 36000 的整数');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const AppText('自定义时长'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _from,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.uiText('最短时长（秒）'),
              hintText: context.uiText('不限'),
            ),
            validator: _validate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _to,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.uiText('最长时长（秒）'),
              hintText: context.uiText('不限'),
            ),
            validator: (text) {
              final error = _validate(text);
              if (error != null) return error;
              final from = int.tryParse(_from.text.trim());
              final to = int.tryParse(text?.trim() ?? '');
              return from != null && to != null && from > to
                  ? context.uiText('最长时长不能小于最短时长')
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          _from.clear();
          _to.clear();
        },
        child: const AppText('清空'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) {
            unawaited(
              AppLogService.instance.info(
                'validation_failed kind=duration',
                component: 'r34v_filters',
              ),
            );
            return;
          }
          Navigator.pop(
            context,
            VideoDurationRange(
              minSeconds: int.tryParse(_from.text.trim()),
              maxSeconds: int.tryParse(_to.text.trim()),
            ),
          );
        },
        child: const AppText('应用'),
      ),
    ],
  );
}

Future<VideoDateRange?> showVideoDateRangeDialog(
  BuildContext context,
  VideoDateRange? initial,
) => runWithoutRestoringInputFocus(
  context,
  () => showDialog<VideoDateRange>(
    context: context,
    builder: (_) => _DateDialog(initial: initial),
  ),
);

class _DateDialog extends StatefulWidget {
  const _DateDialog({this.initial});
  final VideoDateRange? initial;
  @override
  State<_DateDialog> createState() => _DateDialogState();
}

class _DateDialogState extends State<_DateDialog> {
  late DateTime? _from = widget.initial?.from;
  late DateTime? _to = widget.initial?.to;
  bool _invalid = false;

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _from = selected;
      } else {
        _to = selected;
      }
      _invalid = false;
    });
  }

  Widget _field(bool from) {
    final value = from ? _from : _to;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: AppText(from ? '开始日期' : '结束日期'),
      subtitle: AppText(
        value == null ? '不限' : VideoDateRange.formatDate(value),
      ),
      onTap: () => _pick(from),
      trailing: value == null
          ? null
          : IconButton(
              tooltip: context.uiText('清空'),
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                if (from) {
                  _from = null;
                } else {
                  _to = null;
                }
                _invalid = false;
              }),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const AppText('自定义日期'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(true),
        _field(false),
        if (_invalid)
          AppText(
            '结束日期不能早于开始日期',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() {
          _from = null;
          _to = null;
          _invalid = false;
        }),
        child: const AppText('清空'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('取消'),
      ),
      FilledButton(
        onPressed: () {
          final range = VideoDateRange(from: _from, to: _to);
          if (!range.isValid) {
            setState(() => _invalid = true);
            unawaited(
              AppLogService.instance.info(
                'validation_failed kind=date',
                component: 'r34v_filters',
              ),
            );
            return;
          }
          Navigator.pop(context, range);
        },
        child: const AppText('应用'),
      ),
    ],
  );
}
