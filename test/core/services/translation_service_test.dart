import 'package:drift/native.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/content_source.dart';
import 'package:flule34/core/models/translation_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内置词表资产可以加载', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService(settingsRepository: settings);

    await service.initialize();

    expect(service.isInitialized, isTrue);
    expect(service.builtinEntryCount, 8090);
    expect(service.builtinCategoryEntryCount, 1898);
    expect(service.lookupChinese('footjob'), '足交');
    expect(
      service.lookupChinese(
        '13 sentinels aegis rim',
        kind: DiscoveryKind.category,
      ),
      '十三机兵防卫圈',
    );
    expect(
      service.lookupChinese('Hi-Fi Rush', kind: DiscoveryKind.category),
      '完美音浪',
    );
  });

  test('显式 Rule34Video 内容不受当前 Hanime 首页站点影响', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );

    await settings.setActiveSite(ContentSite.hanime1);

    expect(
      service.renderMetadata(
        DiscoveryKind.tag,
        'footjob',
        siteId: ContentSite.rule34video.id,
      ),
      'footjob | 足交',
    );
    expect(
      service.lookupChinese('footjob', siteId: ContentSite.hanime1.id),
      isNull,
    );
  });

  test('本地词表支持归一化和模特原文回退', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交', 'some_tag': '示例标签'},
    );

    expect(
      service.renderMetadata(DiscoveryKind.tag, 'footjob'),
      'footjob | 足交',
    );
    expect(
      service.renderMetadata(DiscoveryKind.tag, 'some tag'),
      'some tag | 示例标签',
    );
    expect(service.renderMetadata(DiscoveryKind.model, 'footjob'), 'footjob');
    expect(service.suggestEnglish('足交'), contains('footjob'));
  });

  test('显示模式生效且原文模式仍保留翻译能力', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );

    await settings.setTranslationDisplayMode(
      TranslationDisplayMode.chineseOnly,
    );
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), '足交');
    await settings.setTranslationDisplayMode(
      TranslationDisplayMode.originalOnly,
    );
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), 'footjob');
  });

  test('分类和标签使用各自的语言显示模式', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'anime': '动画'},
    );

    await settings.setTranslationDisplayModeFor(
      TranslationDisplayTarget.category,
      TranslationDisplayMode.chineseOnly,
    );
    await settings.setTranslationDisplayModeFor(
      TranslationDisplayTarget.tag,
      TranslationDisplayMode.originalOnly,
    );

    expect(service.renderMetadata(DiscoveryKind.category, 'anime'), '动画');
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), 'footjob');
  });

  test('用户覆盖优先于内置词表并可跨服务实例恢复', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'footjob': '分类译文'},
    );
    await service.initialize();

    await service.setOverride(DiscoveryKind.tag, 'footjob', '足部服务');

    expect(
      service.renderMetadata(DiscoveryKind.tag, 'footjob'),
      'footjob | 足部服务',
    );
    expect(
      service.renderMetadata(DiscoveryKind.category, 'footjob'),
      'footjob | 分类译文',
    );

    final restored = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'footjob': '分类译文'},
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.lookupChinese('footjob'), '足部服务');

    await restored.removeOverride(DiscoveryKind.tag, 'footjob');
    expect(restored.lookupChinese('footjob'), '足交');
    expect(await database.loadTranslationOverrides(), isEmpty);
  });

  test('相同视频 ID 和元数据原文的译文按站点隔离', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {},
    );
    addTearDown(service.dispose);
    await service.initialize();

    await service.setTitleOverride(
      'same-id',
      'Rule34 标题',
      sourceText: 'Same title',
      siteId: 'rule34video',
    );
    await service.setTitleOverride(
      'same-id',
      'Hanime 标题',
      sourceText: 'Same title',
      siteId: 'hanime1',
    );
    await service.setOverride(
      DiscoveryKind.tag,
      'shared tag',
      'Rule34 标签',
      siteId: 'rule34video',
    );
    await service.setOverride(
      DiscoveryKind.tag,
      'shared tag',
      'Hanime 标签',
      siteId: 'hanime1',
    );

    expect(
      service.lookupTitleChinese(
        'same-id',
        raw: 'Same title',
        siteId: 'rule34video',
      ),
      'Rule34 标题',
    );
    expect(
      service.lookupTitleChinese(
        'same-id',
        raw: 'Same title',
        siteId: 'hanime1',
      ),
      'Hanime 标题',
    );
    expect(
      service.lookupChinese(
        'shared tag',
        kind: DiscoveryKind.tag,
        siteId: 'rule34video',
      ),
      'Rule34 标签',
    );
    expect(
      service.lookupChinese(
        'shared tag',
        kind: DiscoveryKind.tag,
        siteId: 'hanime1',
      ),
      'Hanime 标签',
    );
  });

  test('hanime1 标题翻译按视频 ID 生效，不受列表与详情标题文本差异影响', () async {
    // hanime1 列表卡片标题与详情页标题文本可能不同（同一 videoId），
    // 译文必须继续生效，否则会在列表/详情间反复触发自动翻译。
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {},
    );
    addTearDown(service.dispose);
    await service.initialize();

    await service.setTitleOverride(
      '407591',
      '小女拉姆内 第7话',
      sourceText: '列表卡片标题文本',
      siteId: 'hanime1',
    );

    // 详情页标题与列表标题不同，hanime1 下仍应命中同一译文。
    expect(
      service.lookupTitleChinese(
        '407591',
        raw: '小女ラムネ 第7話 コマコとエッチなお約束 [中字後補]',
        siteId: 'hanime1',
      ),
      '小女拉姆内 第7话',
    );
    expect(
      service.hasLearnedTitle('407591', raw: '详情页标题文本', siteId: 'hanime1'),
      isFalse,
    );
    // rule34video 仍按源文本校验，不一致时不命中。
    await service.setTitleOverride(
      '407591',
      'Rule34 标题',
      sourceText: '原始标题',
      siteId: 'rule34video',
    );
    expect(
      service.lookupTitleChinese('407591', raw: '另一个标题', siteId: 'rule34video'),
      isNull,
    );
  });

  test('反查同时支持内置译名和用户译名', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );

    await service.setOverride(DiscoveryKind.tag, 'footjob', '足部服务');

    final builtInMatch = service.searchTagAliases('足交').single;
    expect(builtInMatch.english, 'footjob');
    expect(builtInMatch.displayChinese, '足部服务');
    expect(builtInMatch.aliasSource, TranslationAliasSource.builtIn);

    final overrideMatch = service.searchTagAliases('足部服务').single;
    expect(overrideMatch.aliasSource, TranslationAliasSource.userOverride);
    expect(overrideMatch.matchKind, TranslationMatchKind.exact);
  });

  test('已学习译文仅次于用户和内置译文并支持中文标题反查', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'footjob',
      sourceText: 'footjob',
      translation: '接口足交',
    );
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'new tag',
      sourceText: 'new tag',
      translation: '新标签',
    );
    await database.upsertLearnedTranslation(
      kind: 'title',
      canonicalName: 'video-1',
      sourceText: 'MOM BREAKER',
      translation: '母亲终结者',
      videoSlug: 'mom-breaker',
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
    );
    addTearDown(service.dispose);
    await service.initialize();

    expect(service.lookupChinese('footjob'), '足交');
    expect(service.lookupChinese('new tag'), '新标签');
    expect(
      service.searchTagAliases('新标签').single.aliasSource,
      TranslationAliasSource.learned,
    );
    expect(service.searchTitleTranslations('母亲').single.videoId, 'video-1');

    await service.setOverride(DiscoveryKind.tag, 'new tag', '用户新标签');
    expect(service.lookupChinese('new tag'), '用户新标签');
    await service.removeOverride(DiscoveryKind.tag, 'new tag');
    expect(service.lookupChinese('new tag'), '新标签');

    await service.setTitleOverride(
      'video-1',
      '用户标题',
      sourceText: 'MOM BREAKER',
      videoSlug: 'mom-breaker',
    );
    final userTitle = service.searchTitleTranslations('用户标题').single;
    expect(userTitle.aliasSource, TranslationAliasSource.userOverride);
  });

  test('新加入内置词表不会覆盖此前已经学到的 API 译文', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();

    final first = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'old tag': '旧内置'},
      builtInPackVersion: 1,
    );
    await first.initialize();
    first.dispose();
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'new tag',
      sourceText: 'new tag',
      translation: 'API 译文',
    );

    final second = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'old tag': '新版内置', 'new tag': '新增内置'},
      builtInPackVersion: 2,
    );
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.lookupChinese('old tag'), '新版内置');
    expect(second.lookupChinese('new tag'), 'API 译文');
  });

  test('批量删除 API 译文只通知一次且不会删除用户译文', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    for (var index = 0; index < 120; index++) {
      await database.upsertLearnedTranslation(
        kind: index.isEven ? 'tag' : 'category',
        canonicalName: 'learned-$index',
        sourceText: 'learned-$index',
        translation: 'API-$index',
      );
    }
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'keep': '内置'},
    );
    addTearDown(service.dispose);
    await service.initialize();
    await service.setOverride(DiscoveryKind.tag, 'keep', '用户译文');

    var notifications = 0;
    service.addListener(() => notifications++);
    final selected = service
        .catalogItems()
        .where((item) => item.canonicalName.startsWith('learned-'))
        .toList(growable: false);

    await service.deleteLearnedTranslations(selected);

    expect(notifications, 1);
    expect(service.learnedEntryCount, 0);
    expect(service.lookupChinese('keep'), '用户译文');
    expect(await database.loadLearnedTranslations(), isEmpty);
    expect(await database.loadTranslationOverrides(), hasLength(1));
  });

  test('不同目标语言的译文独立保存且内置词表只用于简体中文', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
    );
    addTearDown(service.dispose);
    await service.initialize();

    await service.setOverride(
      DiscoveryKind.tag,
      'example',
      '示例',
      language: TranslationLanguage.simplifiedChinese,
    );
    await service.setOverride(
      DiscoveryKind.tag,
      'example',
      '例',
      language: TranslationLanguage.japanese,
    );

    expect(
      service.lookupChinese(
        'example',
        language: TranslationLanguage.simplifiedChinese,
      ),
      '示例',
    );
    expect(
      service.lookupChinese('example', language: TranslationLanguage.japanese),
      '例',
    );
    expect(
      service.lookupChinese('footjob', language: TranslationLanguage.japanese),
      isNull,
    );
    expect(
      service.catalogItems().where((item) => item.canonicalName == 'example'),
      hasLength(2),
    );

    await settings.setTranslationTarget(TranslationTargetPreference.japanese);
    expect(service.renderMetadata(DiscoveryKind.tag, 'example'), 'example | 例');
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), 'footjob');
    expect(service.searchTagAliases('例').single.english, 'example');
  });

  test('译文与原文相同时仍保留并显示双语结果', () {
    const value = LocalizedTranslation(
      original: '3D',
      translation: '3D',
      mode: TranslationDisplayMode.bilingual,
    );

    expect(value.hasTranslation, isFalse);
    expect(value.hasResult, isTrue);
    expect(value.plainText, '3D | 3D');
  });

  test('searchTagAliases 支持预归一化前缀与包含匹配且按匹配度排序', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    await settings.load();
    await settings.setTranslationTarget(
      TranslationTargetPreference.simplifiedChinese,
    );
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {
        'blowjob': ' 口交 ',
        'deepthroat': '深喉口交',
        'paizuri': '乳交',
      },
    );
    addTearDown(service.dispose);
    await service.initialize();

    // 空输入或纯空白输入返回空
    expect(service.searchTagAliases(''), isEmpty);
    expect(service.searchTagAliases('   '), isEmpty);

    // 完全匹配优先于包含匹配
    final suggestions = service.searchTagAliases('口交');
    expect(suggestions, hasLength(2));
    expect(suggestions.first.english, 'blowjob');
    expect(suggestions.first.matchKind, TranslationMatchKind.exact);
    expect(suggestions.last.english, 'deepthroat');
    expect(suggestions.last.matchKind, TranslationMatchKind.contains);

    // 多余空白字符自动归一化
    final normalizedSearch = service.searchTagAliases('  口交  ');
    expect(normalizedSearch.first.english, 'blowjob');
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async =>
      key == 'flule34.settings.language'
      ? 'simplifiedChinese'
      : _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
