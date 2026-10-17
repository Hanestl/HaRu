import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/video/presentation/video_detail_metadata_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemorySettingsStore implements AppSettingsStore {
  @override
  Future<bool?> readBool(String key) async => null;

  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<void> writeBool(String key, bool value) async {}

  @override
  Future<void> writeString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

void main() {
  late final TranslationService translationService;

  setUpAll(() async {
    final settingsRepo = AppSettingsRepository(_MemorySettingsStore());
    await settingsRepo.load();
    translationService = TranslationService.fromDictionary(
      settingsRepository: settingsRepo,
      dictionary: const {},
    );
  });

  tearDownAll(() {
    translationService.dispose();
  });

  testWidgets('D1: 展开时展示全量标签，消除 40 封顶截断', (tester) async {
    // 构造 45 个标签
    final tags = List.generate(
      45,
      (i) => VideoMetadataItem(
        kind: DiscoveryKind.tag,
        id: 'tag-$i',
        title: 'Tag $i',
        path: '/tags/tag-$i',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoDetailMetadataSection(
              title: '标签',
              items: tags,
              fallbackValues: const [],
              kind: DiscoveryKind.tag,
              translationService: translationService,
              siteId: 'rule34video',
              subscribedPaths: const {},
              updatingKeys: const {},
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    // 默认折叠：展示 5 个，按钮文案为“展开(40)”
    expect(find.text('Tag 0'), findsOneWidget);
    expect(find.text('Tag 4'), findsOneWidget);
    expect(find.text('Tag 5'), findsNothing);
    expect(find.text('展开(40)'), findsOneWidget);

    // 点击展开
    await tester.tap(find.text('展开(40)'));
    await tester.pumpAndSettle();

    // 展开后应该展示全部 45 个标签，包括第 44 个（索引 44），按钮变为“收起”
    expect(find.text('Tag 44'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    // 点击收起
    await tester.ensureVisible(find.text('收起'));
    await tester.tap(find.text('收起'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Tag 5'), findsNothing);
    expect(find.text('展开(40)'), findsOneWidget);
  });

  testWidgets('D2: 父级组件更新时，展开状态不会因 List 引用不相等而被抹掉', (tester) async {
    final tags1 = List.generate(
      10,
      (i) => VideoMetadataItem(
        kind: DiscoveryKind.tag,
        id: 'tag-$i',
        title: 'Tag $i',
        path: '/tags/tag-$i',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('父级重建'),
                    ),
                    VideoDetailMetadataSection(
                      title: '标签',
                      // 每次传入新的 List 实例
                      items: List.of(tags1),
                      fallbackValues: const [],
                      kind: DiscoveryKind.tag,
                      translationService: translationService,
                      siteId: 'rule34video',
                      subscribedPaths: const {},
                      updatingKeys: const {},
                      onTap: (_) {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // 点击展开
    await tester.tap(find.text('展开(5)'));
    await tester.pumpAndSettle();
    expect(find.text('Tag 9'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    // 触发父级重建（传入新的 items List 实例）
    await tester.tap(find.text('父级重建'));
    await tester.pumpAndSettle();

    // 应当保持展开状态！
    expect(find.text('Tag 9'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
  });
}
