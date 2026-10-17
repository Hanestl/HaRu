import 'dart:convert';
import 'dart:io';

const _catalogPath = 'tool/data/ui_localization_catalog.json';
const _l10nDirectory = 'lib/l10n';
const _generatedLookupPath = 'lib/l10n/ui_translations.g.dart';
const _languages = <String>['en', 'ja', 'ko'];

final _literalPattern = RegExp(
  r'''(?<![A-Za-z0-9_r])(['"])((?:\\.|(?!\1).)*)\1''',
);
final _interpolationPattern = RegExp(
  r'''\$\{[^}]+\}|\$[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*''',
);
final _hanPattern = RegExp(r'[\u3400-\u9fff]');

Future<void> main(List<String> arguments) async {
  final isCheck = arguments.contains('--check');
  final shouldTranslate = arguments.contains('--translate');
  final sources = await _collectSources();
  final existing = await _loadCatalog();
  final bySource = <String, Map<String, Object?>>{
    for (final item in existing) item['source']! as String: item,
  };

  final catalog = <Map<String, Object?>>[];
  for (final source in sources) {
    final item =
        bySource[source] ??
        <String, Object?>{'source': source, 'en': null, 'ja': null, 'ko': null};
    item['key'] = 'ui${_stableHash(source)}';
    catalog.add(item);
  }
  final keys = <String>{};
  for (final item in catalog) {
    final key = item['key']! as String;
    if (!keys.add(key)) throw StateError('UI 文案 key 冲突：$key');
  }
  catalog.sort((left, right) {
    return (left['source']! as String).compareTo(right['source']! as String);
  });

  if (shouldTranslate && !isCheck) {
    for (final language in _languages) {
      await _translateMissing(catalog, language);
    }
  }

  final missing = <String>[];
  for (final item in catalog) {
    for (final language in _languages) {
      final value = item[language]?.toString().trim() ?? '';
      if (value.isEmpty) {
        missing.add('${item['key']}:$language (${item['source']})');
      }
    }
  }

  if (isCheck) {
    if (missing.isNotEmpty) {
      stderr.writeln('UI 词表校验失败：仍有 ${missing.length} 个译文缺失：');
      for (final m in missing.take(10)) {
        stderr.writeln('  $m');
      }
      exitCode = 1;
      return;
    }
    final isCatalogSync = await _checkJsonSync(_catalogPath, catalog);
    final isArbSync = await _checkArbSync(catalog);
    final isLookupSync = await _checkLookupSync(catalog);
    if (!isCatalogSync || !isArbSync || !isLookupSync) {
      stderr.writeln(
        'UI 词表或生成代码与当前源码不一致，请运行 dart run tool/generate_ui_localizations.dart',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('UI 词表检查通过，${catalog.length} 条文案均已同步且完备。');
    return;
  }

  await _writeJson(_catalogPath, catalog);
  if (missing.isNotEmpty) {
    stderr.writeln('仍有 ${missing.length} 个译文缺失。使用 --translate 生成候选译文。');
    exitCode = 2;
    return;
  }

  await _writeArbFiles(catalog);
  await _writeRuntimeLookup(catalog);
  stdout.writeln('已生成 ${catalog.length} 条四语 UI 文案。');
}

Future<List<String>> _collectSources() async {
  final files = <File>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (path.endsWith('.g.dart') || path.contains('/generated/')) continue;
    if (!_isUiSource(path)) continue;
    files.add(entity);
  }

  final sources = <String>{};
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    var contents = await file.readAsString();
    // 过滤开发者日志调用，避免将内部排障日志串误识别为用户 UI 文案。
    // 这里必须用 `(?:.|\n)*?` 而不是 `[^;]*?`：日志串本身常含 ASCII 分号
    //（例如 `attempt=${attempt + 1};`），用 `[^;]` 会让整条调用匹配失败，
    // 日志串就会漏进词表。
    contents = contents
        .replaceAll(
          RegExp(
            r'AppLogService\.[a-zA-Z0-9_.]+\s*\((?:.|\n)*?\);',
            multiLine: true,
          ),
          '',
        )
        // 通过 Provider 读日志服务的写法（`ref.read(appLogServiceProvider)`）。
        .replaceAll(
          RegExp(
            r'\.\s*read\s*\(\s*appLogServiceProvider\s*\)\s*\.\s*[a-zA-Z0-9_]+\s*\((?:.|\n)*?\);',
            multiLine: true,
          ),
          '',
        )
        // 先缓存成局部变量再写日志的别名写法（`final log = ...; log.info(...)`）。
        .replaceAll(
          RegExp(
            r'\blog\s*\.\s*(?:info|warning|error|debug|trace)\s*\((?:.|\n)*?\);',
            multiLine: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'debugPrint\s*\((?:.|\n)*?\);', multiLine: true),
          '',
        )
        .replaceAll(RegExp(r'RegExp\s*\((?:[^;]|\n)*?\)', multiLine: true), '');
    // 再剥离「非 UI」的代码区段：LLM/DeepL 内部提示词、识别模型元叙述的哨兵
    // 列表等。这些字符串含中文但从不渲染到界面，不过滤会被当成待翻译文案。
    for (final pattern in _nonUiSectionPatterns[path] ?? const <RegExp>[]) {
      contents = contents.replaceAll(pattern, '');
    }
    // 先把 `${...}` 插值表达式整体折叠成占位符：表达式内部可能嵌字符串字面量
    // （例如 `'失败：${foo ?? '未知错误'}'`），否则字面量正则会提前截断，导致
    // 这类用户可见文案永远进不了词表。
    contents = _protectInterpolations(contents);
    for (final match in _literalPattern.allMatches(contents)) {
      final raw = match.group(2)!;
      if (!_hanPattern.hasMatch(raw)) continue;
      final normalized = _normalizeTemplate(_decodeLiteral(raw));
      if (normalized.trim().isNotEmpty &&
          normalized.length <= 1200 &&
          !normalized.contains(r'$')) {
        sources.add(normalized);
      }
    }
  }
  final result = sources.toList()..sort();
  return result;
}

bool _isUiSource(String path) {
  if (path.startsWith('lib/features/') || path.startsWith('lib/shared/')) {
    return true;
  }
  if (path.startsWith('lib/app/')) return true;
  if (path.startsWith('lib/core/api/') ||
      path.startsWith('lib/core/services/') ||
      path.startsWith('lib/core/session/')) {
    return true;
  }
  return const <String>{
    'lib/main.dart',
    'lib/core/config/app_build_config.dart',
    'lib/core/security/error_redaction.dart',
    'lib/core/models/video_models.dart',
    'lib/core/models/translation_models.dart',
    'lib/core/models/translation_provider_models.dart',
    'lib/features/downloads/domain/download_models.dart',
    'lib/features/settings/domain/app_settings.dart',
    'lib/features/settings/domain/quality_selection.dart',
  }.contains(path);
}

/// 按文件剥离「非 UI」的代码区段（内部提示词、模型输出校验哨兵等）。
/// 这些字面量虽然含中文，但只发给翻译服务或用于校验模型返回值，
/// 永远不会渲染到界面上，若不过滤会被误当成用户可见文案。
final _nonUiSectionPatterns = <String, List<RegExp>>{
  'lib/core/services/translation_provider_router.dart': [
    // DeepL 的上下文与指令构造方法。
    RegExp(r'static String _deepLContext\([\s\S]*?\n  \}'),
    RegExp(r'static List<String> _deepLInstructions\([\s\S]*?\n  \];'),
    // 识别「模型返回说明性文字」的哨兵列表，以及命中后抛出的内部异常。
    RegExp(r'static String _cleanAiText\([\s\S]*?\n  \}'),
  ],
};

/// 把 `${...}` 插值表达式整体替换成占位符，避免表达式内部嵌套的字符串引号
/// 截断外层字符串字面量（例如 `'失败：${foo ?? '未知错误'}'`）。
String _protectInterpolations(String contents) {
  final buffer = StringBuffer();
  var index = 0;
  var position = 0;
  while (position < contents.length) {
    final char = contents[position];
    if (char == r'$' &&
        position + 1 < contents.length &&
        contents[position + 1] == '{') {
      final end = _interpolationEnd(contents, position + 2);
      if (end != null) {
        buffer.write(r'${');
        buffer.write('__UI_EXPR_${index++}__');
        buffer.write('}');
        position = end + 1;
        continue;
      }
    }
    buffer.write(char);
    position++;
  }
  return buffer.toString();
}

/// 从 [start] 开始寻找与 `${` 配对的 `}`，跳过嵌套字符串与花括号。
int? _interpolationEnd(String contents, int start) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var position = start; position < contents.length; position++) {
    final char = contents[position];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '{') {
      depth++;
      continue;
    }
    if (char == '}' && depth == 0) return position;
    if (char == '}') depth--;
  }
  return null;
}

String _decodeLiteral(String raw) {
  return raw
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', '\\');
}

String _normalizeTemplate(String source) {
  var index = 0;
  return source.replaceAllMapped(_interpolationPattern, (_) => '{p${index++}}');
}

Future<List<Map<String, Object?>>> _loadCatalog() async {
  final file = File(_catalogPath);
  if (!await file.exists()) return <Map<String, Object?>>[];
  final raw = jsonDecode(await file.readAsString());
  if (raw is! List) throw const FormatException('UI 翻译目录格式无效');
  return raw
      .whereType<Map>()
      .map((item) => item.cast<String, Object?>())
      .toList();
}

Future<void> _translateMissing(
  List<Map<String, Object?>> catalog,
  String language,
) async {
  final missing = catalog.where((item) {
    return item[language]?.toString().trim().isNotEmpty != true;
  }).toList();
  if (missing.isEmpty) return;

  var completed = 0;
  final batches = _translationBatches(missing);
  for (final batch in batches) {
    try {
      final translated = await _googleTranslateBatch(
        batch.map((item) => item['source']! as String).toList(),
        language,
      );
      for (var index = 0; index < batch.length; index++) {
        batch[index][language] = translated[index];
      }
    } catch (error) {
      stderr.writeln('$language 批量翻译失败，回退逐条请求：$error');
      for (final item in batch) {
        item[language] = await _googleTranslate(
          item['source']! as String,
          language,
        );
      }
    }
    completed += batch.length;
    await _writeJson(_catalogPath, catalog);
    stdout.writeln('$language: $completed/${missing.length}');
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

List<List<Map<String, Object?>>> _translationBatches(
  List<Map<String, Object?>> items,
) {
  final batches = <List<Map<String, Object?>>>[];
  var batch = <Map<String, Object?>>[];
  var length = 0;
  for (final item in items) {
    final sourceLength = (item['source']! as String).length + 32;
    if (batch.isNotEmpty && length + sourceLength > 2400) {
      batches.add(batch);
      batch = <Map<String, Object?>>[];
      length = 0;
    }
    batch.add(item);
    length += sourceLength;
  }
  if (batch.isNotEmpty) batches.add(batch);
  return batches;
}

Future<List<String>> _googleTranslateBatch(
  List<String> sources,
  String target,
) async {
  final protected = <String>[];
  for (var index = 0; index < sources.length; index++) {
    protected.add(
      '[[[FLULE34_ITEM_$index]]]\n${_protectPlaceholders(sources[index])}',
    );
  }
  final translated = await _googleRequest(protected.join('\n'), target);
  final marker = RegExp(
    r'\[\[\[FLULE34_ITEM_(\d+)\]\]\]\s*',
    caseSensitive: false,
  );
  final matches = marker.allMatches(translated).toList();
  if (matches.length != sources.length) {
    throw FormatException('批量翻译条目数不匹配：${matches.length}/${sources.length}');
  }
  final result = List<String>.filled(sources.length, '');
  for (var index = 0; index < matches.length; index++) {
    final itemIndex = int.parse(matches[index].group(1)!);
    final start = matches[index].end;
    final end = index + 1 < matches.length
        ? matches[index + 1].start
        : translated.length;
    result[itemIndex] = _restorePlaceholders(
      translated.substring(start, end).trim(),
    );
  }
  if (result.any((value) => value.isEmpty)) {
    throw const FormatException('批量翻译包含空条目');
  }
  return result;
}

Future<String> _googleTranslate(String source, String target) async {
  final translated = await _googleRequest(_protectPlaceholders(source), target);
  return _restorePlaceholders(translated);
}

String _protectPlaceholders(String source) {
  return source.replaceAllMapped(
    RegExp(r'\{p(\d+)\}'),
    (match) => '__PH_${match.group(1)}__',
  );
}

String _restorePlaceholders(String translated) {
  return translated.replaceAllMapped(
    RegExp(r'__PH_(\d+)__', caseSensitive: false),
    (match) => '{p${match.group(1)}}',
  );
}

Future<String> _googleRequest(String source, String target) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      return await _googleRequestOnce(source, target);
    } catch (error) {
      lastError = error;
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
  throw StateError('翻译请求重试失败：$lastError');
}

Future<String> _googleRequestOnce(String source, String target) async {
  final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
    'client': 'gtx',
    'sl': 'zh-CN',
    'tl': target,
    'dt': 't',
    'q': source,
  });
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'HaRu l10n generator');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('翻译请求返回 ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    final segments = decoded is List && decoded.isNotEmpty ? decoded[0] : null;
    if (segments is! List) throw const FormatException('翻译响应格式无效');
    final translated = segments
        .whereType<List>()
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.first?.toString() ?? '')
        .join();
    if (translated.trim().isEmpty) throw const FormatException('翻译结果为空');
    return translated;
  } finally {
    client.close(force: true);
  }
}

Future<void> _writeArbFiles(List<Map<String, Object?>> catalog) async {
  await Directory(_l10nDirectory).create(recursive: true);
  for (final language in <String>['zh', ..._languages]) {
    final arb = <String, Object?>{'@@locale': language};
    for (final item in catalog) {
      final key = item['key']! as String;
      final source = item['source']! as String;
      final value = language == 'zh' ? source : item[language]! as String;
      arb[key] = value.replaceAll("'", "''");
      final placeholders = RegExp(
        r'\{(p\d+)\}',
      ).allMatches(source).map((match) => match.group(1)!).toSet();
      arb['@$key'] = <String, Object?>{
        'description': 'HaRu UI: $source',
        if (placeholders.isNotEmpty)
          'placeholders': <String, Object?>{
            for (final placeholder in placeholders)
              placeholder: <String, Object?>{'type': 'String'},
          },
      };
    }
    await _writeJson('$_l10nDirectory/app_$language.arb', arb);
  }
}

Future<void> _writeRuntimeLookup(List<Map<String, Object?>> catalog) async {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// dart format off')
    ..writeln()
    ..writeln('const uiTranslations = <String, Map<String, String>>{');
  for (final item in catalog) {
    final source = item['source']! as String;
    buffer
      ..writeln('  ${jsonEncode(source)}: <String, String>{')
      ..writeln("    'en': ${jsonEncode(item['en'])},")
      ..writeln("    'ja': ${jsonEncode(item['ja'])},")
      ..writeln("    'ko': ${jsonEncode(item['ko'])},")
      ..writeln('  },');
  }
  buffer
    ..writeln('};')
    ..writeln('// dart format on');
  final file = File(_generatedLookupPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(buffer.toString());
}

Future<void> _writeJson(String path, Object value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(value)}\n');
}

String _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Future<bool> _checkJsonSync(String path, Object value) async {
  final file = File(path);
  if (!await file.exists()) return false;
  const encoder = JsonEncoder.withIndent('  ');
  final expected = '${encoder.convert(value)}\n';
  final current = await file.readAsString();
  return expected == current;
}

Future<bool> _checkArbSync(List<Map<String, Object?>> catalog) async {
  for (final language in ['zh', ..._languages]) {
    final arb = <String, Object?>{'@@locale': language};
    for (final item in catalog) {
      final key = item['key']! as String;
      final source = item['source']! as String;
      final value = language == 'zh' ? source : item[language]! as String;
      arb[key] = value.replaceAll("'", "''");
      final placeholders = RegExp(
        r'\{(p\d+)\}',
      ).allMatches(source).map((match) => match.group(1)!).toSet();
      arb['@$key'] = <String, Object?>{
        'description': 'HaRu UI: $source',
        if (placeholders.isNotEmpty)
          'placeholders': <String, Object?>{
            for (final placeholder in placeholders)
              placeholder: <String, Object?>{'type': 'String'},
          },
      };
    }
    if (!await _checkJsonSync('$_l10nDirectory/app_$language.arb', arb)) {
      return false;
    }
  }
  return true;
}

Future<bool> _checkLookupSync(List<Map<String, Object?>> catalog) async {
  final file = File(_generatedLookupPath);
  if (!await file.exists()) return false;
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// dart format off')
    ..writeln()
    ..writeln('const uiTranslations = <String, Map<String, String>>{');
  for (final item in catalog) {
    final source = item['source']! as String;
    buffer
      ..writeln('  ${jsonEncode(source)}: <String, String>{')
      ..writeln("    'en': ${jsonEncode(item['en'])},")
      ..writeln("    'ja': ${jsonEncode(item['ja'])},")
      ..writeln("    'ko': ${jsonEncode(item['ko'])},")
      ..writeln('  },');
  }
  buffer
    ..writeln('};')
    ..writeln('// dart format on');
  final expected = buffer.toString();
  final current = await file.readAsString();
  return expected == current;
}
