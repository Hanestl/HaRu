import 'dart:convert';
import 'dart:io';

import 'package:flule34/l10n/ui_translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('用户可见中文不得绕过 AppText 或 context.uiText', () {
    final unsafeTab = RegExp(r'''\bTab\s*\(\s*text\s*:''');
    final han = RegExp(r'[\u3400-\u9fff]');
    final kindLabel = RegExp(r'(?:\bkind|\.kind)\.label');
    final findings = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.contains('/l10n/generated/') ||
          path.endsWith('/l10n/ui_translations.g.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final invocation in _plainTextInvocations(source)) {
        final explicitlyLocalized = invocation.source.contains(
          'context.uiText(',
        );
        if (!explicitlyLocalized &&
            (han.hasMatch(invocation.source) ||
                kindLabel.hasMatch(invocation.source))) {
          findings.add(
            '$path:${_lineAt(source, invocation.offset)} '
            'unlocalized ${invocation.widget}',
          );
        }
      }
      for (final match in unsafeTab.allMatches(source)) {
        findings.add('$path:${_lineAt(source, match.start)} Tab.text');
      }
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('UI 词表与 Catalog 键集合必须严格 1:1 双向同步，且三语译文完备无缺失', () {
    final catalogFile = File('tool/data/ui_localization_catalog.json');
    expect(catalogFile.existsSync(), isTrue);
    final raw = jsonDecode(catalogFile.readAsStringSync()) as List;
    final catalogSources = <String>{};
    final missingLangs = <String>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final source = item['source'] as String;
        catalogSources.add(source);
        for (final lang in ['en', 'ja', 'ko']) {
          final translated = item[lang]?.toString().trim() ?? '';
          if (translated.isEmpty) {
            missingLangs.add('$source ($lang)');
          }
        }
      }
    }

    expect(
      missingLangs,
      isEmpty,
      reason: '发现缺失翻译条目：\n${missingLangs.take(10).join('\n')}',
    );
    expect(
      uiTranslations.length,
      catalogSources.length,
      reason: '运行时词表与 Catalog 条目数量不一致',
    );

    for (final source in catalogSources) {
      expect(
        uiTranslations.containsKey(source),
        isTrue,
        reason: '运行时词表缺失源文本: $source',
      );
      final entry = uiTranslations[source]!;
      for (final lang in ['en', 'ja', 'ko']) {
        expect(
          entry[lang]?.trim().isNotEmpty,
          isTrue,
          reason: '运行时词表 $source 的 $lang 译文为空',
        );
      }
    }
  });

  test('词表英文、韩文译文不得残留中文字符', () {
    final han = RegExp(r'[\u4e00-\u9fff]');
    final invalid = <String>[];
    for (final entry in uiTranslations.entries) {
      for (final language in const ['en', 'ko']) {
        final value = entry.value[language] ?? '';
        if (han.hasMatch(value)) {
          invalid.add('${entry.key} ($language) -> $value');
        }
      }
    }
    expect(invalid, isEmpty, reason: '发现英/韩译文中残留中文字符：\n${invalid.join('\n')}');
  });

  test('词表不得混入内部日志、提示词或模型哨兵等非 UI 文案', () {
    // 这些字面量含中文但永远不会渲染到界面：排障日志、发给翻译服务的提示词、
    // 识别「模型返回说明性文字」的哨兵等。生成器负责把它们从源码里剥离，
    // 本用例防止剥离规则失效后又被当成待翻译文案收进词表。
    final nonUiPatterns = <RegExp>[
      // 日志串：等号 + 占位符的键值形态与内部排障字段。
      RegExp(r'attempt=|耗时=|visible=|suppressed=|reason=no-alternate-source'),
      // 翻译提示词与元叙述哨兵（中文/日文）。
      RegExp(r'内容类型是|署名必须保留原文|准确保留成人内容|已有目标语言常见译名'),
      RegExp(r'翻译如下|无需翻译|已经是目标语言|译文是'),
      RegExp(r'标签关键词|视频标题|分类、作品、系列、角色或主题名称'),
      RegExp(r'翻訳します|翻訳は不要|すでに対象言語'),
      // AI 返回说明性文字时抛出的内部异常文案。
      RegExp(r'说明性文字，而不是可用译文'),
    ];
    final polluted = <String>[];
    for (final source in uiTranslations.keys) {
      for (final pattern in nonUiPatterns) {
        if (pattern.hasMatch(source)) {
          polluted.add(source);
          break;
        }
      }
    }
    expect(polluted, isEmpty, reason: '词表混入非 UI 内部文案：\n${polluted.join('\n')}');
  });
}

int _lineAt(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

Iterable<_Invocation> _plainTextInvocations(String source) sync* {
  final starts = RegExp(r'\b(Text|SelectableText)\s*\(').allMatches(source);
  for (final start in starts) {
    final open = source.indexOf('(', start.start);
    final end = _matchingParenthesis(source, open);
    if (end == null) continue;
    yield _Invocation(
      widget: start.group(1)!,
      offset: start.start,
      source: source.substring(start.start, end + 1),
    );
  }
}

int? _matchingParenthesis(String source, int open) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = open; index < source.length; index += 1) {
    final character = source[index];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (character == r'\') {
        escaped = true;
      } else if (character == quote) {
        quote = null;
      }
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
    } else if (character == '(') {
      depth += 1;
    } else if (character == ')' && --depth == 0) {
      return index;
    }
  }
  return null;
}

final class _Invocation {
  const _Invocation({
    required this.widget,
    required this.offset,
    required this.source,
  });

  final String widget;
  final int offset;
  final String source;
}
