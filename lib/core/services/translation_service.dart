import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/settings/data/app_settings_repository.dart';
import '../database/app_database.dart';
import '../logging/app_log_service.dart';
import '../models/translation_models.dart';
import '../models/translation_provider_models.dart';
import '../models/video_models.dart';
import 'source_language_detector.dart';
import 'translation_catalog_archive.dart';
import 'translation_provider_router.dart';

final class TranslationService extends ChangeNotifier {
  TranslationService({
    required this.settingsRepository,
    this.database,
    this.providerRouter,
    this.sourceLanguageDetector,
    this.builtInPackVersion = _builtInPackVersion,
    AssetBundle? assetBundle,
  }) : _assetBundle = assetBundle ?? rootBundle;

  TranslationService.fromDictionary({
    required this.settingsRepository,
    required Map<String, String> dictionary,
    Map<String, String> categoryDictionary = const {},
    this.database,
    this.providerRouter,
    this.sourceLanguageDetector,
    this.builtInPackVersion = _builtInPackVersion,
  }) : _assetBundle = rootBundle,
       _builtinTagEnglishToChinese = _normalizeDictionary(dictionary),
       _builtinCategoryEnglishToChinese = _normalizeDictionary(
         categoryDictionary,
       ),
       _assetLoaded = true,
       _initialized = database == null {
    _buildBuiltinTagEntries();
  }

  static const _tagAssetPath = 'assets/translations/rule34video_tags_zh.json';
  static const _categoryAssetPath =
      'assets/translations/rule34video_categories_zh.json';
  static const _builtInPackKey = 'rule34video_zh';
  static const _builtInPackVersion = 1;
  static const _siteId = 'rule34video';
  static const _hanimeSiteId = 'hanime1';

  String get _activeSiteId => settingsRepository.settings.activeSite.id;

  final AppSettingsRepository settingsRepository;
  final AppDatabase? database;
  final TranslationProviderRouter? providerRouter;
  final SourceLanguageDetector? sourceLanguageDetector;
  final int builtInPackVersion;
  final AssetBundle _assetBundle;
  Map<String, String> _builtinTagEnglishToChinese = const {};
  Map<String, String> _builtinCategoryEnglishToChinese = const {};
  List<_BuiltinTagEntry> _builtinTagEntries = const [];
  final Map<String, String> _overrides = {};
  final Map<String, String?> _overrideSourceTexts = {};
  final Map<String, String?> _overrideVideoSlugs = {};
  final Map<String, String> _overrideSourceLanguages = {};
  final Map<String, DateTime?> _overrideUpdatedAts = {};
  final Map<String, _LearnedValue> _learned = {};
  final Set<String> _protectedLearnedKeys = {};
  final Map<String, Future<void>> _automaticInFlight = {};
  final Map<String, DateTime> _automaticFailures = {};
  final Set<String> _sameLanguageTexts = {};
  bool _assetLoaded = false;
  bool _initialized = false;
  Future<void>? _initialization;

  bool get isInitialized => _initialized;
  int get builtinEntryCount => _builtinTagEnglishToChinese.length;
  int get builtinCategoryEntryCount => _builtinCategoryEnglishToChinese.length;
  int get builtinTotalEntryCount =>
      _builtinTagEnglishToChinese.length +
      _builtinCategoryEnglishToChinese.length;
  int get overrideEntryCount => _overrides.length;
  int get catalogEntryCount => catalogItems().length;
  int get learnedEntryCount => _learned.length;
  int get learnedTitleCount =>
      _learned.values.where((item) => item.kind == 'title').length;
  int get learnedTagCount =>
      _learned.values.where((item) => item.kind == 'tag').length;
  int get learnedCategoryCount =>
      _learned.values.where((item) => item.kind == 'category').length;
  bool get hasEnabledProvider => providerRouter?.hasEnabledProvider ?? false;

  TranslationLanguage get targetLanguage {
    final preference = settingsRepository.settings.translationTarget;
    final fixed = preference.fixedLanguage;
    if (fixed != null) return fixed;
    final interfaceLanguage = settingsRepository.settings.language.languageCode;
    return TranslationLanguage.fromCode(
      interfaceLanguage ?? PlatformDispatcher.instance.locale.languageCode,
      fallback: TranslationLanguage.simplifiedChinese,
    );
  }

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initialization ??= _doInitialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _doInitialize() async {
    if (!_assetLoaded) {
      _builtinTagEnglishToChinese = await _loadAssetDictionaryOrEmpty(
        _tagAssetPath,
      );
      _builtinCategoryEnglishToChinese = await _loadAssetDictionaryOrEmpty(
        _categoryAssetPath,
      );
      _buildBuiltinTagEntries();
      _assetLoaded = true;
    }

    final overrideDatabase = database;
    if (overrideDatabase != null) {
      try {
        final rows = [
          ...await overrideDatabase.loadAllTranslationOverrides(),
          ...await overrideDatabase.loadAllTranslationOverrides(
            siteId: _hanimeSiteId,
          ),
        ];
        _overrides
          ..clear()
          ..addEntries(
            rows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                row.translation,
              ),
            ),
          );
        _overrideSourceTexts
          ..clear()
          ..addEntries(
            rows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                row.sourceText,
              ),
            ),
          );
        _overrideVideoSlugs
          ..clear()
          ..addEntries(
            rows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                row.videoSlug,
              ),
            ),
          );
        _overrideSourceLanguages
          ..clear()
          ..addEntries(
            rows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                row.sourceLanguage,
              ),
            ),
          );
        _overrideUpdatedAts
          ..clear()
          ..addEntries(
            rows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                row.updatedAt,
              ),
            ),
          );

        final learnedRows = [
          ...await overrideDatabase.loadAllLearnedTranslations(),
          ...await overrideDatabase.loadAllLearnedTranslations(
            siteId: _hanimeSiteId,
          ),
        ];
        _learned
          ..clear()
          ..addEntries(
            learnedRows.map(
              (row) => MapEntry(
                _recordKey(
                  row.targetLanguage,
                  row.kind,
                  row.canonicalName,
                  siteId: row.siteId,
                ),
                _LearnedValue(
                  siteId: row.siteId,
                  sourceLanguage: row.sourceLanguage,
                  targetLanguage: row.targetLanguage,
                  kind: row.kind,
                  canonicalName: row.canonicalName,
                  sourceText: row.sourceText,
                  translation: row.translation,
                  providerId: row.providerId,
                  providerName: row.providerName,
                  videoSlug: row.videoSlug,
                  createdAt: row.createdAt,
                  updatedAt: row.updatedAt,
                ),
              ),
            ),
          );
        await overrideDatabase.applyBuiltInTranslationPack(
          packKey: _builtInPackKey,
          packVersion: builtInPackVersion,
          entries: [
            for (final key in _builtinTagEnglishToChinese.keys)
              (kind: DiscoveryKind.tag.name, canonicalName: key),
            for (final key in _builtinCategoryEnglishToChinese.keys)
              (kind: DiscoveryKind.category.name, canonicalName: key),
          ],
        );
        final builtInStates = await overrideDatabase
            .loadAllBuiltInTranslationStates();
        _protectedLearnedKeys
          ..clear()
          ..addAll(
            builtInStates
                .where((state) => state.protectExistingLearned)
                .map(
                  (state) => _recordKey(
                    state.targetLanguage,
                    state.kind,
                    state.canonicalName,
                    siteId: state.siteId,
                  ),
                ),
          );
      } on Object catch (error, stackTrace) {
        _overrides.clear();
        _overrideSourceTexts.clear();
        _overrideVideoSlugs.clear();
        _overrideSourceLanguages.clear();
        _overrideUpdatedAts.clear();
        _learned.clear();
        _protectedLearnedKeys.clear();
        unawaited(
          AppLogService.instance.error(
            error,
            stackTrace,
            component: 'translation_init',
          ),
        );
        rethrow;
      }
    }
    _initialized = true;
  }

  String renderMetadata(DiscoveryKind kind, String raw, {String? siteId}) {
    return resolveMetadata(kind, raw, siteId: siteId).plainText;
  }

  LocalizedTranslation resolveMetadata(
    DiscoveryKind kind,
    String raw, {
    String? siteId,
  }) {
    final value = raw.trim();
    if (value.isEmpty ||
        kind == DiscoveryKind.model ||
        kind == DiscoveryKind.channel) {
      return LocalizedTranslation(
        original: raw,
        translation: null,
        mode: TranslationDisplayMode.originalOnly,
      );
    }

    final settings = settingsRepository.settings;
    final chinese = lookupChinese(value, kind: kind, siteId: siteId);
    return LocalizedTranslation(
      original: raw,
      translation: chinese,
      mode: switch (kind) {
        DiscoveryKind.category => settings.categoryTranslationDisplayMode,
        DiscoveryKind.tag => settings.tagTranslationDisplayMode,
        DiscoveryKind.model ||
        DiscoveryKind.channel => TranslationDisplayMode.originalOnly,
      },
    );
  }

  String? lookupChinese(
    String raw, {
    DiscoveryKind kind = DiscoveryKind.tag,
    TranslationLanguage? language,
    String? siteId,
  }) {
    final canonical = _normalize(raw);
    final key = _learnedKey(
      kind.name,
      canonical,
      language: language,
      siteId: siteId,
    );
    return _overrides[_overrideKey(
          kind.name,
          canonical,
          language: language,
          siteId: siteId,
        )] ??
        (_protectedLearnedKeys.contains(key)
            ? _learned[key]?.translation
            : null) ??
        _builtInDictionary(
          kind,
          language: language,
          siteId: siteId,
        )[canonical] ??
        _learned[key]?.translation;
  }

  String? lookupBuiltInChinese(
    String raw, {
    DiscoveryKind kind = DiscoveryKind.tag,
    TranslationLanguage? language,
  }) {
    return _builtInDictionary(kind, language: language)[_normalize(raw)];
  }

  String? lookupLearnedChinese(
    String raw, {
    DiscoveryKind kind = DiscoveryKind.tag,
    TranslationLanguage? language,
    String? siteId,
  }) {
    return _learned[_learnedKey(
          kind.name,
          _normalize(raw),
          language: language,
          siteId: siteId,
        )]
        ?.translation;
  }

  bool hasOverride(
    DiscoveryKind kind,
    String raw, {
    TranslationLanguage? language,
    String? siteId,
  }) {
    return _overrides.containsKey(
      _overrideKey(
        kind.name,
        _normalize(raw),
        language: language,
        siteId: siteId,
      ),
    );
  }

  bool hasLearnedTranslation(
    DiscoveryKind kind,
    String raw, {
    TranslationLanguage? language,
    String? siteId,
  }) {
    return _learned.containsKey(
      _learnedKey(
        kind.name,
        _normalize(raw),
        language: language,
        siteId: siteId,
      ),
    );
  }

  bool hasLearnedTitle(
    String videoId, {
    String? raw,
    TranslationLanguage? language,
    String? siteId,
  }) {
    final value =
        _learned[_learnedKey(
          'title',
          videoId.trim(),
          language: language,
          siteId: siteId,
        )];
    return value != null &&
        _titleSourceMatches(value.sourceText, raw, siteId: siteId);
  }

  bool hasTitleOverride(
    String videoId, {
    String? raw,
    TranslationLanguage? language,
    String? siteId,
  }) {
    final key = _overrideKey(
      'title',
      videoId.trim(),
      language: language,
      siteId: siteId,
    );
    return _overrides.containsKey(key) &&
        _titleSourceMatches(_overrideSourceTexts[key], raw, siteId: siteId);
  }

  bool canEditDisplayedTranslation(DiscoveryKind kind, String raw) {
    if (!_isEditableKind(kind)) return false;
    return raw.trim().isNotEmpty;
  }

  bool shouldAutoTranslateMetadata(
    DiscoveryKind kind,
    String raw, {
    String? siteId,
  }) {
    final settings = settingsRepository.settings;
    return _isEditableKind(kind) &&
        settings.automaticTranslationTargets.contains(
          kind == DiscoveryKind.tag
              ? AutomaticTranslationTarget.tag
              : AutomaticTranslationTarget.category,
        ) &&
        hasEnabledProvider &&
        raw.trim().isNotEmpty &&
        lookupChinese(raw, kind: kind, siteId: siteId) == null;
  }

  bool shouldAutoTranslateTitle(String videoId, String raw, {String? siteId}) {
    final settings = settingsRepository.settings;
    return settings.automaticTranslationTargets.contains(
          AutomaticTranslationTarget.title,
        ) &&
        hasEnabledProvider &&
        videoId.trim().isNotEmpty &&
        raw.trim().isNotEmpty &&
        lookupTitleChinese(videoId, raw: raw, siteId: siteId) == null;
  }

  Future<void> requestAutomaticMetadataTranslation(
    DiscoveryKind kind,
    String raw, {
    String? siteId,
  }) {
    if (!shouldAutoTranslateMetadata(kind, raw, siteId: siteId)) {
      return Future.value();
    }
    final canonical = _normalize(raw);
    return _requestAutomatic(
      _learnedKey(kind.name, canonical, siteId: siteId),
      () => _translateAndLearn(
        kind: kind.name,
        canonicalName: canonical,
        sourceText: raw.trim(),
        siteId: siteId,
      ),
    );
  }

  Future<void> requestAutomaticTitle({
    required String videoId,
    required String raw,
    String? videoSlug,
    String? siteId,
  }) {
    if (!shouldAutoTranslateTitle(videoId, raw, siteId: siteId)) {
      return Future.value();
    }
    final canonical = videoId.trim();
    return _requestAutomatic(
      _learnedKey('title', canonical, siteId: siteId),
      () => _translateAndLearn(
        kind: 'title',
        canonicalName: canonical,
        sourceText: raw.trim(),
        videoSlug: videoSlug,
        siteId: siteId,
      ),
    );
  }

  Future<TranslationProviderResult> translateWithProvider(
    DiscoveryKind kind,
    String raw, {
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final contentKind = _contentKind(kind);
    final result = await _translateOnline(contentKind, raw, language: language);
    await _saveLearned(
      kind: kind.name,
      canonicalName: _normalize(raw),
      sourceText: raw.trim(),
      result: result,
      language: language,
      siteId: siteId,
    );
    return result;
  }

  String? lookupTitleChinese(
    String videoId, {
    String? raw,
    TranslationLanguage? language,
    String? siteId,
  }) {
    final key = _overrideKey(
      'title',
      videoId.trim(),
      language: language,
      siteId: siteId,
    );
    final override = _overrides[key];
    if (override != null &&
        _titleSourceMatches(_overrideSourceTexts[key], raw, siteId: siteId)) {
      return override;
    }
    final learned =
        _learned[_learnedKey(
          'title',
          videoId.trim(),
          language: language,
          siteId: siteId,
        )];
    if (learned != null &&
        _titleSourceMatches(learned.sourceText, raw, siteId: siteId)) {
      return learned.translation;
    }
    return null;
  }

  String renderTitle(String videoId, String raw, {String? siteId}) {
    return resolveTitle(videoId, raw, siteId: siteId).plainText;
  }

  LocalizedTranslation resolveTitle(
    String videoId,
    String raw, {
    String? siteId,
  }) {
    final settings = settingsRepository.settings;
    final chinese = lookupTitleChinese(videoId, raw: raw, siteId: siteId);
    return LocalizedTranslation(
      original: raw,
      translation: chinese,
      mode: settings.titleTranslationDisplayMode,
    );
  }

  Future<void> setTitleOverride(
    String videoId,
    String translation, {
    String? sourceText,
    String? videoSlug,
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final target = language ?? targetLanguage;
    final recordSiteId = siteId ?? _activeSiteId;
    final key = videoId.trim();
    final chinese = translation.trim();
    if (key.isEmpty || chinese.isEmpty) {
      throw ArgumentError.value(translation, 'translation', '翻译不能为空');
    }
    final learned =
        _learned[_learnedKey(
          'title',
          key,
          language: target,
          siteId: recordSiteId,
        )];
    if (learned != null &&
        (sourceText == null ||
            _sourceMatches(learned.sourceText, sourceText)) &&
        chinese == learned.translation) {
      await removeTitleOverride(key, language: target, siteId: recordSiteId);
      return;
    }
    await database?.upsertTranslationOverride(
      siteId: recordSiteId,
      kind: 'title',
      canonicalName: key,
      sourceLanguage: _inferSourceLanguage(sourceText ?? ''),
      targetLanguage: target.code,
      sourceText: sourceText,
      videoSlug: videoSlug,
      translation: chinese,
    );
    final recordKey = _overrideKey(
      'title',
      key,
      language: target,
      siteId: recordSiteId,
    );
    _overrides[recordKey] = chinese;
    _overrideSourceLanguages[recordKey] = _inferSourceLanguage(
      sourceText ?? '',
    );
    _overrideSourceTexts[recordKey] = sourceText;
    _overrideVideoSlugs[recordKey] = videoSlug;
    _overrideUpdatedAts[recordKey] = DateTime.now().toUtc();
    notifyListeners();
  }

  Future<void> removeTitleOverride(
    String videoId, {
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final target = language ?? targetLanguage;
    final recordSiteId = siteId ?? _activeSiteId;
    final key = videoId.trim();
    await database?.deleteTranslationOverride(
      siteId: recordSiteId,
      kind: 'title',
      canonicalName: key,
      targetLanguage: target.code,
    );
    final overrideKey = _overrideKey(
      'title',
      key,
      language: target,
      siteId: recordSiteId,
    );
    final removed = _overrides.remove(overrideKey) != null;
    _overrideSourceTexts.remove(overrideKey);
    _overrideVideoSlugs.remove(overrideKey);
    _overrideSourceLanguages.remove(overrideKey);
    _overrideUpdatedAts.remove(overrideKey);
    if (removed) notifyListeners();
  }

  Future<TranslationProviderResult> translateTitleWithProvider(
    String raw, {
    String? videoId,
    String? videoSlug,
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final result = await _translateOnline(
      TranslationContentKind.title,
      raw,
      language: language,
    );
    final key = videoId?.trim() ?? '';
    if (key.isNotEmpty) {
      await _saveLearned(
        kind: 'title',
        canonicalName: key,
        sourceText: raw.trim(),
        videoSlug: videoSlug,
        result: result,
        language: language,
        siteId: siteId,
      );
    }
    return result;
  }

  Future<void> setOverride(
    DiscoveryKind kind,
    String raw,
    String translation, {
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final target = language ?? targetLanguage;
    final recordSiteId = siteId ?? _activeSiteId;
    if (!_isEditableKind(kind)) return;
    final canonical = _normalize(raw);
    final chinese = translation.trim();
    if (canonical.isEmpty || chinese.isEmpty) {
      throw ArgumentError.value(translation, 'translation', '翻译不能为空');
    }
    if (chinese == lookupBuiltInChinese(raw, kind: kind, language: target) ||
        chinese ==
            lookupLearnedChinese(
              raw,
              kind: kind,
              language: target,
              siteId: recordSiteId,
            )) {
      await removeOverride(kind, raw, language: target, siteId: recordSiteId);
      return;
    }
    await database?.upsertTranslationOverride(
      siteId: recordSiteId,
      kind: kind.name,
      canonicalName: canonical,
      sourceLanguage: _inferSourceLanguage(raw),
      targetLanguage: target.code,
      sourceText: raw.trim(),
      translation: chinese,
    );
    final key = _overrideKey(
      kind.name,
      canonical,
      language: target,
      siteId: recordSiteId,
    );
    _overrides[key] = chinese;
    _overrideSourceLanguages[key] = _inferSourceLanguage(raw);
    _overrideSourceTexts[key] = raw.trim();
    _overrideUpdatedAts[key] = DateTime.now().toUtc();
    notifyListeners();
  }

  Future<void> removeOverride(
    DiscoveryKind kind,
    String raw, {
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final target = language ?? targetLanguage;
    final recordSiteId = siteId ?? _activeSiteId;
    if (!_isEditableKind(kind)) return;
    final canonical = _normalize(raw);
    await database?.deleteTranslationOverride(
      siteId: recordSiteId,
      kind: kind.name,
      canonicalName: canonical,
      targetLanguage: target.code,
    );
    final key = _overrideKey(
      kind.name,
      canonical,
      language: target,
      siteId: recordSiteId,
    );
    final removed = _overrides.remove(key) != null;
    _overrideSourceTexts.remove(key);
    _overrideSourceLanguages.remove(key);
    _overrideUpdatedAts.remove(key);
    if (removed) notifyListeners();
  }

  Future<void> clearLearnedTranslations() async {
    final language = targetLanguage.code;
    await database?.clearLearnedTranslations(
      siteId: _activeSiteId,
      targetLanguage: language,
    );
    final keys = _learned.keys
        .where(
          (key) => _keyMatchesSiteAndLanguage(
            key,
            siteId: _activeSiteId,
            targetLanguage: language,
          ),
        )
        .toList(growable: false);
    if (keys.isNotEmpty) {
      for (final key in keys) {
        _learned.remove(key);
        _protectedLearnedKeys.remove(key);
      }
      notifyListeners();
    }
  }

  Future<void> deleteLearnedTranslation(TranslationCatalogItem item) async {
    await deleteLearnedTranslations([item]);
  }

  Future<void> deleteLearnedTranslations(
    Iterable<TranslationCatalogItem> items,
  ) async {
    final targets = items
        .where((item) => item.hasLearned)
        .map(
          (item) => (
            siteId: item.siteId,
            targetLanguage: item.targetLanguage.code,
            kind: item.kind.name,
            canonicalName: item.canonicalName,
          ),
        )
        .toList(growable: false);
    if (targets.isEmpty) return;

    await database?.deleteLearnedTranslations(targets);
    var removed = false;
    for (final target in targets) {
      final key = _recordKey(
        target.targetLanguage,
        target.kind,
        target.canonicalName,
        siteId: target.siteId,
      );
      removed = _learned.remove(key) != null || removed;
      _protectedLearnedKeys.remove(key);
    }
    if (removed) notifyListeners();
  }

  Future<TranslationImportResult> importCatalogArchive(
    ParsedTranslationArchive archive, {
    required TranslationImportMode mode,
  }) async {
    final overrideDatabase = database;
    if (overrideDatabase == null) {
      throw StateError('当前环境没有可写入的翻译数据库');
    }
    final importedLearned =
        <({TranslationArchiveEntry entry, TranslationArchiveLayer layer})>[];
    final importedOverrides =
        <({TranslationArchiveEntry entry, TranslationArchiveLayer layer})>[];
    final learnedKeys = {..._learned.keys};
    final overrideKeys = {..._overrides.keys};
    var skippedLearned = 0;
    var skippedOverrides = 0;

    await overrideDatabase.transaction(() async {
      for (final entry in archive.entries) {
        final kind = entry.kind.name;
        final key = _recordKey(
          entry.targetLanguage.code,
          kind,
          entry.canonicalName,
          siteId: entry.siteId,
        );
        final learned = entry.learned;
        if (learned != null) {
          if (mode == TranslationImportMode.safeMerge &&
              learnedKeys.contains(key)) {
            skippedLearned += 1;
          } else {
            await overrideDatabase.upsertLearnedTranslation(
              siteId: entry.siteId,
              sourceLanguage: entry.sourceLanguageCode,
              targetLanguage: entry.targetLanguage.code,
              kind: kind,
              canonicalName: entry.canonicalName,
              sourceText: entry.sourceText,
              translation: learned.translation,
              providerId: learned.providerId,
              providerName: learned.providerName,
              videoSlug: entry.videoSlug,
              createdAt: learned.createdAt,
              updatedAt: learned.updatedAt,
            );
            await overrideDatabase.setBuiltInLearnedProtection(
              siteId: entry.siteId,
              targetLanguage: entry.targetLanguage.code,
              kind: kind,
              canonicalName: entry.canonicalName,
              protect: learned.preferOverBuiltIn,
            );
            learnedKeys.add(key);
            importedLearned.add((entry: entry, layer: learned));
          }
        }

        final user = entry.userOverride;
        if (user != null) {
          if (mode == TranslationImportMode.safeMerge &&
              overrideKeys.contains(key)) {
            skippedOverrides += 1;
          } else {
            await overrideDatabase.upsertTranslationOverride(
              siteId: entry.siteId,
              sourceLanguage: entry.sourceLanguageCode,
              targetLanguage: entry.targetLanguage.code,
              kind: kind,
              canonicalName: entry.canonicalName,
              sourceText: entry.sourceText,
              videoSlug: entry.videoSlug,
              translation: user.translation,
              updatedAt: user.updatedAt,
            );
            overrideKeys.add(key);
            importedOverrides.add((entry: entry, layer: user));
          }
        }
      }
    });

    for (final imported in importedLearned) {
      final entry = imported.entry;
      final layer = imported.layer;
      final key = _recordKey(
        entry.targetLanguage.code,
        entry.kind.name,
        entry.canonicalName,
        siteId: entry.siteId,
      );
      final existing = _learned[key];
      final now = DateTime.now().toUtc();
      _learned[key] = _LearnedValue(
        siteId: entry.siteId,
        sourceLanguage: entry.sourceLanguageCode,
        targetLanguage: entry.targetLanguage.code,
        kind: entry.kind.name,
        canonicalName: entry.canonicalName,
        sourceText: entry.sourceText,
        translation: layer.translation,
        providerId: layer.providerId,
        providerName: layer.providerName,
        videoSlug: entry.videoSlug,
        createdAt: existing?.createdAt ?? layer.createdAt ?? now,
        updatedAt: layer.updatedAt ?? now,
      );
      if (layer.preferOverBuiltIn) {
        _protectedLearnedKeys.add(key);
      } else {
        _protectedLearnedKeys.remove(key);
      }
    }
    for (final imported in importedOverrides) {
      final entry = imported.entry;
      final layer = imported.layer;
      final key = _recordKey(
        entry.targetLanguage.code,
        entry.kind.name,
        entry.canonicalName,
        siteId: entry.siteId,
      );
      _overrides[key] = layer.translation;
      _overrideSourceLanguages[key] = entry.sourceLanguageCode;
      _overrideSourceTexts[key] = entry.sourceText;
      _overrideVideoSlugs[key] = entry.videoSlug;
      _overrideUpdatedAts[key] = layer.updatedAt ?? DateTime.now().toUtc();
    }
    if (importedLearned.isNotEmpty || importedOverrides.isNotEmpty) {
      notifyListeners();
    }
    return TranslationImportResult(
      importedLearned: importedLearned.length,
      importedUserOverrides: importedOverrides.length,
      skippedLearned: skippedLearned,
      skippedUserOverrides: skippedOverrides,
      ignoredBuiltIn: archive.builtInLayerCount,
    );
  }

  List<TranslationCatalogItem> catalogItems() {
    final keys = <String>{
      for (final key in _builtinTagEnglishToChinese.keys)
        _recordKey(
          TranslationLanguage.simplifiedChinese.code,
          'tag',
          key,
          siteId: _siteId,
        ),
      for (final key in _builtinCategoryEnglishToChinese.keys)
        _recordKey(
          TranslationLanguage.simplifiedChinese.code,
          'category',
          key,
          siteId: _siteId,
        ),
      ..._learned.keys,
      ..._overrides.keys,
    };
    final items = <TranslationCatalogItem>[];
    for (final key in keys) {
      final parts = key.split('\u0000');
      if (parts.length != 4) continue;
      final siteId = parts[0];
      final target = TranslationLanguage.fromCode(
        parts[1],
        fallback: TranslationLanguage.simplifiedChinese,
      );
      final kindName = parts[2];
      final canonical = parts[3];
      final kind = switch (kindName) {
        'title' => TranslationCatalogKind.title,
        'category' => TranslationCatalogKind.category,
        'tag' => TranslationCatalogKind.tag,
        _ => null,
      };
      if (kind == null) continue;
      final learned = _learned[key];
      final sourceText = _overrideSourceTexts[key]?.trim().isNotEmpty == true
          ? _overrideSourceTexts[key]!.trim()
          : learned?.sourceText.trim().isNotEmpty == true
          ? learned!.sourceText.trim()
          : canonical;
      final builtIn =
          siteId == _siteId && target == TranslationLanguage.simplifiedChinese
          ? switch (kind) {
              TranslationCatalogKind.tag =>
                _builtinTagEnglishToChinese[canonical],
              TranslationCatalogKind.category =>
                _builtinCategoryEnglishToChinese[canonical],
              TranslationCatalogKind.title => null,
            }
          : null;
      items.add(
        TranslationCatalogItem(
          siteId: siteId,
          sourceLanguageCode:
              _overrideSourceLanguages[key] ??
              learned?.sourceLanguage ??
              (builtIn == null ? 'und' : TranslationLanguage.english.code),
          targetLanguage: target,
          kind: kind,
          canonicalName: canonical,
          sourceText: sourceText,
          videoSlug: _overrideVideoSlugs[key] ?? learned?.videoSlug,
          builtInTranslation: builtIn,
          learnedTranslation: learned?.translation,
          userTranslation: _overrides[key],
          learnedProviderName: learned?.providerName,
          learnedCreatedAt: learned?.createdAt,
          learnedUpdatedAt: learned?.updatedAt,
          userUpdatedAt: _overrideUpdatedAts[key],
          protectLearnedFromBuiltIn: _protectedLearnedKeys.contains(key),
        ),
      );
    }
    return items;
  }

  List<String> suggestEnglish(String chineseFragment, {int limit = 8}) {
    return searchTagAliases(
      chineseFragment,
      limit: limit,
    ).map((item) => item.english).toList(growable: false);
  }

  List<TranslatedTagSuggestion> searchTagAliases(
    String chineseFragment, {
    int limit = 8,
  }) {
    final query = _normalizeAlias(chineseFragment);
    if (query.isEmpty) return const [];

    final candidates = <String, TranslatedTagSuggestion>{};

    void considerNormalized(
      String english,
      String alias,
      String normalizedAlias,
      TranslationAliasSource source,
    ) {
      final matchKind = _matchKind(normalizedAlias, query);
      if (matchKind == null) return;
      final candidate = TranslatedTagSuggestion(
        english: english,
        displayChinese:
            lookupChinese(english, kind: DiscoveryKind.tag) ?? alias,
        matchedAlias: alias,
        aliasSource: source,
        matchKind: matchKind,
      );
      final existing = candidates[english];
      if (existing == null || _compareTagSuggestions(candidate, existing) < 0) {
        candidates[english] = candidate;
      }
    }

    void consider(String english, String alias, TranslationAliasSource source) {
      considerNormalized(english, alias, _normalizeAlias(alias), source);
    }

    if (targetLanguage == TranslationLanguage.simplifiedChinese) {
      for (final entry in _builtinTagEntries) {
        considerNormalized(
          entry.english,
          entry.chinese,
          entry.normalizedChinese,
          TranslationAliasSource.builtIn,
        );
      }
    }
    for (final entry in _learned.entries) {
      final value = entry.value;
      if (value.targetLanguage == targetLanguage.code &&
          value.kind == DiscoveryKind.tag.name) {
        consider(
          value.sourceText,
          value.translation,
          TranslationAliasSource.learned,
        );
      }
    }
    for (final entry in _overrides.entries) {
      final parts = entry.key.split('\u0000');
      if (parts.length == 4 &&
          parts[1] == targetLanguage.code &&
          parts[2] == DiscoveryKind.tag.name) {
        consider(parts[3], entry.value, TranslationAliasSource.userOverride);
      }
    }

    final result = candidates.values.toList(growable: false)
      ..sort(_compareTagSuggestions);
    return result.take(limit).toList(growable: false);
  }

  List<TranslatedTitleSuggestion> searchTitleTranslations(
    String chineseFragment, {
    int limit = 8,
  }) {
    final query = _normalizeAlias(chineseFragment);
    if (query.isEmpty) return const [];
    final candidates = <String, TranslatedTitleSuggestion>{};

    void consider(
      String videoId,
      String? slug,
      String? english,
      String chinese,
      TranslationAliasSource source,
    ) {
      if (videoId.trim().isEmpty || slug == null || slug.trim().isEmpty) return;
      final matchKind = _matchKind(_normalizeAlias(chinese), query);
      if (matchKind == null) return;
      final candidate = TranslatedTitleSuggestion(
        videoId: videoId,
        slug: slug,
        siteId: _activeSiteId,
        english: english?.trim().isNotEmpty == true ? english!.trim() : videoId,
        displayChinese: chinese,
        aliasSource: source,
        matchKind: matchKind,
      );
      final existing = candidates[videoId];
      if (existing == null ||
          _compareTitleSuggestions(candidate, existing) < 0) {
        candidates[videoId] = candidate;
      }
    }

    for (final value in _learned.values) {
      if (value.targetLanguage == targetLanguage.code &&
          value.kind == 'title') {
        consider(
          value.canonicalName,
          value.videoSlug,
          value.sourceText,
          value.translation,
          TranslationAliasSource.learned,
        );
      }
    }
    for (final entry in _overrides.entries) {
      final parts = entry.key.split('\u0000');
      if (parts.length == 4 &&
          parts[1] == targetLanguage.code &&
          parts[2] == 'title') {
        consider(
          parts[3],
          _overrideVideoSlugs[entry.key],
          _overrideSourceTexts[entry.key],
          entry.value,
          TranslationAliasSource.userOverride,
        );
      }
    }

    final result = candidates.values.toList(growable: false)
      ..sort(_compareTitleSuggestions);
    return result.take(limit).toList(growable: false);
  }

  Future<void> _requestAutomatic(String key, Future<void> Function() action) {
    final existing = _automaticInFlight[key];
    if (existing != null) return existing;
    final failedUntil = _automaticFailures[key];
    if (failedUntil != null && failedUntil.isAfter(DateTime.now())) {
      return Future.value();
    }
    final future = () async {
      try {
        await action();
        _automaticFailures.remove(key);
      } on Object {
        _automaticFailures[key] = DateTime.now().add(
          const Duration(minutes: 5),
        );
      } finally {
        _automaticInFlight.remove(key);
      }
    }();
    _automaticInFlight[key] = future;
    return future;
  }

  Future<void> _translateAndLearn({
    required String kind,
    required String canonicalName,
    required String sourceText,
    String? videoSlug,
    String? siteId,
  }) async {
    final result = await _translateOnline(
      _contentKindFromName(kind),
      sourceText,
    );
    await _saveLearned(
      kind: kind,
      canonicalName: canonicalName,
      sourceText: sourceText,
      videoSlug: videoSlug,
      result: result,
      siteId: siteId,
    );
  }

  Future<TranslationProviderResult> _translateOnline(
    TranslationContentKind kind,
    String raw, {
    TranslationLanguage? language,
  }) async {
    final target = language ?? targetLanguage;
    final text = raw.trim();
    final cacheKey = '${target.code}\u0000$text';
    // 只有目标语言为英语时，才跳过已经是英语或语言中性的原文。
    if (target == TranslationLanguage.english) {
      if (_sameLanguageTexts.contains(cacheKey) || _isLanguageNeutral(text)) {
        _sameLanguageTexts.add(cacheKey);
        return TranslationProviderResult(
          providerId: 'local-language-detection',
          providerName: '本地语言识别',
          translation: text,
          detectedSourceLanguage: target,
          shouldPersist: false,
        );
      }
      final detector = sourceLanguageDetector;
      if (detector != null) {
        try {
          final detected = await detector.detect(text);
          if (detected == target) {
            _sameLanguageTexts.add(cacheKey);
            return TranslationProviderResult(
              providerId: 'local-language-detection',
              providerName: '本地语言识别',
              translation: text,
              detectedSourceLanguage: detected,
              shouldPersist: false,
            );
          }
        } on Object {
          // 本地识别失败不应阻断用户配置的在线翻译服务。
        }
      }
    }
    final router = providerRouter;
    if (router == null) throw StateError('翻译服务尚未配置');
    return router.translate(
      TranslationRequest(kind: kind, text: raw, targetLanguage: target),
    );
  }

  Future<void> _saveLearned({
    required String kind,
    required String canonicalName,
    required String sourceText,
    required TranslationProviderResult result,
    String? videoSlug,
    TranslationLanguage? language,
    String? siteId,
  }) async {
    final target = language ?? targetLanguage;
    final recordSiteId = siteId ?? _activeSiteId;
    if (!result.shouldPersist ||
        (target == TranslationLanguage.english &&
            result.translation.trim() == sourceText.trim())) {
      _sameLanguageTexts.add('${target.code}\u0000${sourceText.trim()}');
      return;
    }
    final recordKey = _learnedKey(
      kind,
      canonicalName,
      language: target,
      siteId: recordSiteId,
    );
    await database?.upsertLearnedTranslation(
      siteId: recordSiteId,
      kind: kind,
      canonicalName: canonicalName,
      sourceLanguage:
          result.detectedSourceLanguage?.code ??
          _inferSourceLanguage(sourceText),
      targetLanguage: target.code,
      sourceText: sourceText,
      translation: result.translation,
      providerId: result.providerId,
      providerName: result.providerName,
      videoSlug: videoSlug,
    );
    _learned[recordKey] = _LearnedValue(
      siteId: recordSiteId,
      sourceLanguage:
          result.detectedSourceLanguage?.code ??
          _inferSourceLanguage(sourceText),
      targetLanguage: target.code,
      kind: kind,
      canonicalName: canonicalName,
      sourceText: sourceText,
      translation: result.translation,
      providerId: result.providerId,
      providerName: result.providerName,
      videoSlug: videoSlug,
      createdAt: _learned[recordKey]?.createdAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  TranslationContentKind _contentKind(DiscoveryKind kind) => switch (kind) {
    DiscoveryKind.tag => TranslationContentKind.tag,
    DiscoveryKind.category => TranslationContentKind.category,
    DiscoveryKind.model || DiscoveryKind.channel => throw ArgumentError.value(
      kind,
      'kind',
      '该类型不允许翻译',
    ),
  };

  TranslationContentKind _contentKindFromName(String kind) => switch (kind) {
    'tag' => TranslationContentKind.tag,
    'category' => TranslationContentKind.category,
    'title' => TranslationContentKind.title,
    _ => throw ArgumentError.value(kind, 'kind', '未知翻译类型'),
  };

  static Map<String, String> _normalizeDictionary(Map<String, String> source) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final english = _normalize(entry.key);
      final chinese = entry.value.trim();
      if (english.isEmpty ||
          chinese.isEmpty ||
          english == _normalize(chinese)) {
        continue;
      }
      result.putIfAbsent(english, () => chinese);
    }
    return Map.unmodifiable(result);
  }

  Future<Map<String, String>> _loadAssetDictionary(String path) async {
    final source = await _assetBundle.loadString(path);
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('翻译资产不是 JSON 对象：$path');
    }
    return _normalizeDictionary(
      decoded.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Future<Map<String, String>> _loadAssetDictionaryOrEmpty(String path) async {
    try {
      return await _loadAssetDictionary(path);
    } on Object {
      return const {};
    }
  }

  Map<String, String> _builtInDictionary(
    DiscoveryKind kind, {
    TranslationLanguage? language,
    String? siteId,
  }) {
    final effectiveSiteId = siteId ?? _activeSiteId;
    if (effectiveSiteId != _siteId ||
        (language ?? targetLanguage) != TranslationLanguage.simplifiedChinese) {
      return const {};
    }
    return switch (kind) {
      DiscoveryKind.tag => _builtinTagEnglishToChinese,
      DiscoveryKind.category => _builtinCategoryEnglishToChinese,
      DiscoveryKind.model || DiscoveryKind.channel => const {},
    };
  }

  static bool _sourceMatches(String? saved, String? current) {
    if (saved == null || saved.trim().isEmpty || current == null) return true;
    return _normalize(saved) == _normalize(current);
  }

  /// hanime1 的列表卡片标题与详情页标题文本可能不同（同一 videoId 下），
  /// 若强行校验源文本，同一视频的译文会在列表/详情间互相失效并反复触发
  /// 自动翻译（译文消失又出现）。因此 hanime1 的标题翻译按 videoId 直接
  /// 生效，不做源文本一致性校验。
  static bool _titleSourceMatches(
    String? saved,
    String? current, {
    String? siteId,
  }) {
    if (siteId == _hanimeSiteId) return true;
    return _sourceMatches(saved, current);
  }

  static final _whitespaceRegex = RegExp(r'\s+');

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(_whitespaceRegex, ' ');

  static String _normalizeAlias(String value) =>
      value.trim().toLowerCase().replaceAll(_whitespaceRegex, ' ');

  void _buildBuiltinTagEntries() {
    _builtinTagEntries = _builtinTagEnglishToChinese.entries
        .map(
          (entry) => _BuiltinTagEntry(
            english: entry.key,
            chinese: entry.value,
            normalizedChinese: _normalizeAlias(entry.value),
          ),
        )
        .toList(growable: false);
  }

  static TranslationMatchKind? _matchKind(String alias, String query) {
    if (alias == query) return TranslationMatchKind.exact;
    if (alias.startsWith(query)) return TranslationMatchKind.prefix;
    if (alias.contains(query)) return TranslationMatchKind.contains;
    return null;
  }

  static int _compareTagSuggestions(
    TranslatedTagSuggestion left,
    TranslatedTagSuggestion right,
  ) {
    final match = left.matchKind.index.compareTo(right.matchKind.index);
    if (match != 0) return match;
    final source = left.aliasSource.index.compareTo(right.aliasSource.index);
    if (source != 0) return source;
    final aliasLength = left.matchedAlias.length.compareTo(
      right.matchedAlias.length,
    );
    if (aliasLength != 0) return aliasLength;
    return left.english.compareTo(right.english);
  }

  static int _compareTitleSuggestions(
    TranslatedTitleSuggestion left,
    TranslatedTitleSuggestion right,
  ) {
    final match = left.matchKind.index.compareTo(right.matchKind.index);
    if (match != 0) return match;
    final source = left.aliasSource.index.compareTo(right.aliasSource.index);
    if (source != 0) return source;
    return left.videoId.compareTo(right.videoId);
  }

  static bool _isEditableKind(DiscoveryKind kind) =>
      kind == DiscoveryKind.tag || kind == DiscoveryKind.category;

  String _overrideKey(
    String kind,
    String canonical, {
    TranslationLanguage? language,
    String? siteId,
  }) => _recordKey(
    (language ?? targetLanguage).code,
    kind,
    canonical,
    siteId: siteId,
  );

  String _learnedKey(
    String kind,
    String canonical, {
    TranslationLanguage? language,
    String? siteId,
  }) => _recordKey(
    (language ?? targetLanguage).code,
    kind,
    canonical,
    siteId: siteId,
  );

  String _recordKey(
    String targetLanguage,
    String kind,
    String canonical, {
    String? siteId,
  }) =>
      '${siteId ?? _activeSiteId}\u0000$targetLanguage\u0000$kind\u0000$canonical';

  static bool _keyMatchesSiteAndLanguage(
    String key, {
    required String siteId,
    required String targetLanguage,
  }) {
    final parts = key.split('\u0000');
    return parts.length == 4 &&
        parts[0] == siteId &&
        parts[1] == targetLanguage;
  }

  static String _inferSourceLanguage(String text) {
    final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(text);
    final hasHangul = RegExp(r'[\uac00-\ud7af]').hasMatch(text);
    final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(text);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(text);
    final detected = [
      hasKana,
      hasHangul,
      hasHan,
      hasLatin,
    ].where((value) => value).length;
    if (detected != 1) return 'und';
    if (hasKana) return TranslationLanguage.japanese.code;
    if (hasHangul) return TranslationLanguage.korean.code;
    if (hasHan) return TranslationLanguage.simplifiedChinese.code;
    return TranslationLanguage.english.code;
  }

  static bool _isLanguageNeutral(String text) {
    if (text.isEmpty || text.length > 16) return false;
    return RegExp(
      r'^(?:\d+[A-Z]|[A-Z]{2,6}|[A-Z0-9][A-Z0-9._+\-/#]{1,15})$',
    ).hasMatch(text);
  }
}

final class _LearnedValue {
  const _LearnedValue({
    required this.siteId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.kind,
    required this.canonicalName,
    required this.sourceText,
    required this.translation,
    required this.providerId,
    required this.providerName,
    required this.videoSlug,
    required this.createdAt,
    required this.updatedAt,
  });

  final String siteId;
  final String sourceLanguage;
  final String targetLanguage;
  final String kind;
  final String canonicalName;
  final String sourceText;
  final String translation;
  final String? providerId;
  final String? providerName;
  final String? videoSlug;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class _BuiltinTagEntry {
  const _BuiltinTagEntry({
    required this.english,
    required this.chinese,
    required this.normalizedChinese,
  });

  final String english;
  final String chinese;
  final String normalizedChinese;
}
