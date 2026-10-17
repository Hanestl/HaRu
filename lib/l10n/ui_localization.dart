import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';
import 'ui_translations.g.dart';

extension UiLocalizationBuildContext on BuildContext {
  String uiText(String source) {
    if (Localizations.of<AppLocalizations>(this, AppLocalizations) == null) {
      return source;
    }
    return localizeUiText(Localizations.localeOf(this), source);
  }
}

String localizeUiText(Locale locale, String source) {
  final language = locale.languageCode;
  if (language == 'zh' || !const {'en', 'ja', 'ko'}.contains(language)) {
    return source;
  }
  final direct = uiTranslations[source]?[language];
  if (direct != null && direct.isNotEmpty) return direct;

  for (final template in _templateTranslations) {
    final match = template.pattern.firstMatch(source);
    if (match == null) continue;
    var translated = template.translations[language] ?? source;
    for (var index = 1; index <= match.groupCount; index++) {
      final param = match.group(index)!;
      final localizedParam = localizeUiText(locale, param);
      translated = translated.replaceAll('{p${index - 1}}', localizedParam);
    }
    return translated;
  }

  var translated = source;
  for (final entry in _fragmentTranslations) {
    if (!translated.contains(entry.source)) continue;
    final replacement = entry.translations[language];
    if (replacement != null && replacement.isNotEmpty) {
      translated = translated.replaceAll(entry.source, replacement);
    }
  }
  return translated;
}

final List<_TemplateTranslation> _templateTranslations = () {
  final list = uiTranslations.entries
      .where((entry) => entry.key.contains('{p0}'))
      .map(
        (entry) => _TemplateTranslation(
          source: entry.key,
          pattern: _templatePattern(entry.key),
          translations: entry.value,
        ),
      )
      .toList();
  list.sort((left, right) {
    final literalLeft = left.source.replaceAll(RegExp(r'\{p\d+\}'), '').length;
    final literalRight = right.source
        .replaceAll(RegExp(r'\{p\d+\}'), '')
        .length;
    if (literalLeft != literalRight) {
      return literalRight.compareTo(literalLeft);
    }
    return right.source.length.compareTo(left.source.length);
  });
  return List<_TemplateTranslation>.unmodifiable(list);
}();

final List<_FragmentTranslation> _fragmentTranslations =
    uiTranslations.entries
        .where(
          (entry) => !entry.key.contains('{p') && entry.key.trim().length >= 2,
        )
        .map(
          (entry) => _FragmentTranslation(
            source: entry.key,
            translations: entry.value,
          ),
        )
        .toList(growable: false)
      ..sort(
        (left, right) => right.source.length.compareTo(left.source.length),
      );

RegExp _templatePattern(String template) {
  final placeholders = RegExp(r'\{p\d+\}').allMatches(template).toList();
  final pattern = StringBuffer('^');
  var offset = 0;
  for (final placeholder in placeholders) {
    pattern.write(RegExp.escape(template.substring(offset, placeholder.start)));
    pattern.write('(.*?)');
    offset = placeholder.end;
  }
  pattern
    ..write(RegExp.escape(template.substring(offset)))
    ..write(r'$');
  return RegExp(pattern.toString(), dotAll: true);
}

final class _TemplateTranslation {
  const _TemplateTranslation({
    required this.source,
    required this.pattern,
    required this.translations,
  });

  final String source;
  final RegExp pattern;
  final Map<String, String> translations;
}

final class _FragmentTranslation {
  const _FragmentTranslation({
    required this.source,
    required this.translations,
  });

  final String source;
  final Map<String, String> translations;
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.uiText(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : context.uiText(semanticsLabel!),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
