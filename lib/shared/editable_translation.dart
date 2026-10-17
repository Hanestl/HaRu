import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../core/logging/app_log_service.dart';
import '../core/models/translation_models.dart';
import '../core/models/translation_provider_models.dart';
import '../core/models/video_models.dart';
import '../core/services/translation_service.dart';
import 'error_view.dart';

class EditableTranslationRegion extends StatelessWidget {
  const EditableTranslationRegion({
    super.key,
    required this.translationService,
    required this.kind,
    required this.english,
    required this.child,
    this.siteId,
  });

  final TranslationService translationService;
  final DiscoveryKind kind;
  final String english;
  final Widget child;
  final String? siteId;

  @override
  Widget build(BuildContext context) {
    if (translationService.shouldAutoTranslateMetadata(
      kind,
      english,
      siteId: siteId,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          translationService.requestAutomaticMetadataTranslation(
            kind,
            english,
            siteId: siteId,
          ),
        );
      });
    }
    final editable = translationService.canEditDisplayedTranslation(
      kind,
      english,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: editable
          ? () => showTranslationEditDialog(
              context,
              translationService: translationService,
              kind: kind,
              english: english,
              siteId: siteId,
            )
          : null,
      child: child,
    );
  }
}

Future<void> showTranslationEditDialog(
  BuildContext context, {
  required TranslationService translationService,
  required DiscoveryKind kind,
  required String english,
  TranslationLanguage? targetLanguage,
  String? siteId,
}) async {
  final language = targetLanguage ?? translationService.targetLanguage;
  final current = translationService.lookupChinese(
    english,
    kind: kind,
    language: language,
    siteId: siteId,
  );
  final builtIn = translationService.lookupBuiltInChinese(
    english,
    kind: kind,
    language: language,
  );
  final result = await showDialog<_TranslationEditResult>(
    context: context,
    builder: (context) => _TranslationEditDialog(
      english: english,
      currentTranslation: current ?? '',
      targetLanguage: language,
      hasOverride: translationService.hasOverride(
        kind,
        english,
        language: language,
        siteId: siteId,
      ),
      hasBuiltIn: builtIn != null,
      hasLearned: translationService.hasLearnedTranslation(
        kind,
        english,
        language: language,
        siteId: siteId,
      ),
      translate: translationService.hasEnabledProvider
          ? () => translationService.translateWithProvider(
              kind,
              english,
              language: language,
              siteId: siteId,
            )
          : null,
    ),
  );
  if (result == null || !context.mounted) {
    return;
  }

  try {
    if (result.restoreBuiltIn) {
      await translationService.removeOverride(
        kind,
        english,
        language: language,
        siteId: siteId,
      );
    } else {
      await translationService.setOverride(
        kind,
        english,
        result.translation!,
        language: language,
        siteId: siteId,
      );
    }
  } catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '保存词条翻译失败：$error',
        component: 'translation_service',
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('保存翻译失败：${friendlyErrorMessage(error)}')),
      );
    }
  }
}

final class _TranslationEditResult {
  const _TranslationEditResult.save(this.translation) : restoreBuiltIn = false;

  const _TranslationEditResult.restore()
    : translation = null,
      restoreBuiltIn = true;

  final String? translation;
  final bool restoreBuiltIn;
}

class _TranslationEditDialog extends StatefulWidget {
  const _TranslationEditDialog({
    required this.english,
    required this.currentTranslation,
    required this.targetLanguage,
    required this.hasOverride,
    required this.hasBuiltIn,
    required this.hasLearned,
    required this.translate,
  });

  final String english;
  final String currentTranslation;
  final TranslationLanguage targetLanguage;
  final bool hasOverride;
  final bool hasBuiltIn;
  final bool hasLearned;
  final Future<TranslationProviderResult> Function()? translate;

  @override
  State<_TranslationEditDialog> createState() => _TranslationEditDialogState();
}

class _TranslationEditDialogState extends State<_TranslationEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTranslation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText('编辑译文'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('原文', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(widget.english),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    '${context.uiText('译文')} · ${widget.targetLanguage.label}',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AppText('取消'),
        ),
        if (widget.hasOverride)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _TranslationEditResult.restore()),
            child: AppText(
              widget.hasBuiltIn
                  ? '恢复内置翻译'
                  : widget.hasLearned
                  ? '恢复已学习翻译'
                  : '删除自定义翻译',
            ),
          ),
        if (widget.translate != null)
          TextButton(
            onPressed: _translating ? null : _translate,
            child: _translating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppText('使用翻译服务'),
          ),
        FilledButton(
          onPressed: _translating ? null : _save,
          child: const AppText('保存'),
        ),
      ],
    );
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '译文不能为空');
      return;
    }
    Navigator.of(context).pop(_TranslationEditResult.save(value));
  }

  Future<void> _translate() async {
    setState(() {
      _translating = true;
      _errorText = null;
    });
    try {
      final result = await widget.translate!();
      _controller.text = result.translation;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '执行实时翻译失败：$error',
          component: 'translation_service',
        ),
      );
      if (mounted) {
        setState(() => _errorText = '翻译失败：${friendlyErrorMessage(error)}');
      }
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }
}

Future<void> showTitleTranslationEditDialog(
  BuildContext context, {
  required TranslationService translationService,
  required String videoId,
  required String english,
  String? videoSlug,
  TranslationLanguage? targetLanguage,
  String? siteId,
}) async {
  final language = targetLanguage ?? translationService.targetLanguage;
  final current =
      translationService.lookupTitleChinese(
        videoId,
        raw: english,
        language: language,
        siteId: siteId,
      ) ??
      '';
  final result = await showDialog<_TranslationEditResult>(
    context: context,
    builder: (context) => _TranslationEditDialog(
      english: english,
      currentTranslation: current,
      targetLanguage: language,
      hasOverride: translationService.hasTitleOverride(
        videoId,
        raw: english,
        language: language,
        siteId: siteId,
      ),
      hasBuiltIn: false,
      hasLearned: translationService.hasLearnedTitle(
        videoId,
        raw: english,
        language: language,
        siteId: siteId,
      ),
      translate: translationService.hasEnabledProvider
          ? () => translationService.translateTitleWithProvider(
              english,
              videoId: videoId,
              videoSlug: videoSlug,
              language: language,
              siteId: siteId,
            )
          : null,
    ),
  );
  if (result == null || !context.mounted) return;
  try {
    if (result.restoreBuiltIn) {
      await translationService.removeTitleOverride(
        videoId,
        language: language,
        siteId: siteId,
      );
    } else {
      await translationService.setTitleOverride(
        videoId,
        result.translation!,
        sourceText: english,
        videoSlug: videoSlug,
        language: language,
        siteId: siteId,
      );
    }
  } catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '保存标题翻译失败：$error；videoId=$videoId',
        component: 'translation_service',
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('保存翻译失败：${friendlyErrorMessage(error)}')),
      );
    }
  }
}
