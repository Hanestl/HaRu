import 'dart:io';

import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/library/data/curated_library_seeder.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('正式精选清单可完整导入', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _FileManifestLoader(AssetCuratedLibraryManifestLoader.assetPath),
    );

    await seeder.seedIfNeeded();

    final libraries = await harness.database
        .select(harness.database.localLibraries)
        .get();
    final videos = await harness.database
        .select(harness.database.localLibraryVideos)
        .get();
    expect(libraries, hasLength(5));
    expect(videos, hasLength(289));
    expect(libraries.map((item) => item.name).toSet(), {
      '作者：hydrafxx',
      '作者：nagoonimation',
      '作者：bamhor',
      '作者：JuicyNeko',
      '作者：Drills3D',
    });
  });

  test('精选库只导入一次，同名用户库不会被覆盖', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final userLibraryId = await repository.createLibrary('作者：hydrafxx');
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifest),
    );

    await seeder.seedIfNeeded();
    await seeder.seedIfNeeded();

    final libraries = await harness.database
        .select(harness.database.localLibraries)
        .get();
    expect(libraries, hasLength(2));
    expect(
      libraries.singleWhere((item) => item.id == userLibraryId).seedKey,
      isNull,
    );
    final seeded = libraries.singleWhere((item) => item.seedKey != null);
    expect(seeded.name, '作者：hydrafxx（精选）');
    expect(seeded.seedKey, 'author_hydrafxx');

    final videos = await harness.database
        .select(harness.database.localLibraryVideos)
        .get();
    expect(videos, hasLength(2));
    expect(videos.map((item) => item.libraryId).toSet(), {seeded.id});
    expect(
      await harness.database.select(harness.database.curatedLibrarySeeds).get(),
      hasLength(1),
    );
  });

  test('用户删除精选库后再次初始化不会恢复', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifest),
    );
    await seeder.seedIfNeeded();
    final seeded =
        (await harness.database.select(harness.database.localLibraries).get())
            .single;

    await repository.deleteLibrary(seeded.id);
    await seeder.seedIfNeeded();

    expect(
      await harness.database.select(harness.database.localLibraries).get(),
      isEmpty,
    );
    final state =
        (await harness.database
                .select(harness.database.curatedLibrarySeeds)
                .get())
            .single;
    expect(state.dismissed, isTrue);
  });

  test('精选清单升级只把新增视频放入增量库，不修改原库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final seederV1 = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifest),
    );
    await seederV1.seedIfNeeded();

    final original =
        (await harness.database.select(harness.database.localLibraries).get())
            .single;
    final seederV2 = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifestV2),
    );
    await seederV2.seedIfNeeded();

    final libraries = await harness.database
        .select(harness.database.localLibraries)
        .get();
    expect(libraries, hasLength(2));
    expect(
      libraries.firstWhere((item) => item.id == original.id).name,
      original.name,
    );
    final delta = libraries.firstWhere((item) => item.id != original.id);
    expect(delta.name, contains('内置新增 v2'));
    final deltaVideos = await (harness.database.select(
      harness.database.localLibraryVideos,
    )..where((item) => item.libraryId.equals(delta.id))).get();
    expect(deltaVideos.map((item) => item.videoId), ['new-video']);
  });

  test('R3-6: 库名包含 % 和 _ 特殊字符时 LIKE 转义生效，增量包正确识别已有库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);

    const specialManifestV1 = '''
{
  "version": 1,
  "libraries": [
    {
      "key": "special_lib",
      "name": "100%_Special_Collection",
      "videos": [
        {"id": "v1", "title": "Video 1", "slug": "video-1"}
      ]
    }
  ]
}''';

    const specialManifestV2 = '''
{
  "version": 2,
  "libraries": [
    {
      "key": "special_lib",
      "name": "100%_Special_Collection",
      "videos": [
        {"id": "v1", "title": "Video 1", "slug": "video-1"},
        {"id": "v2", "title": "Video 2", "slug": "video-2"}
      ]
    }
  ]
}''';

    final seederV1 = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(specialManifestV1),
    );
    await seederV1.seedIfNeeded();

    // 插入诱饵库：其名字能被「未转义」的 LIKE 模式
    // '100%_special_collection（内置新增%' 命中（_ 通配单字符、% 通配任意串），
    // 但既不是同名库，也不以「内置新增」为前缀。诱饵里刻意放了 v2：
    // 一旦 _escapeLike 被删掉，_existingVideoIds 会把 v2 误判为已存在，
    // 从而不再创建「内置新增 v2」库 —— 这样本用例才对转义有判别力。
    final repository = DriftLocalLibraryRepository(harness.database);
    final decoyId = await repository.createLibrary(
      '1000ASpecialXCollection（内置新增 999）',
    );
    await repository.addVideo(
      libraryId: decoyId,
      video: const VideoItem(
        id: 'v2',
        title: 'Decoy Video',
        slug: 'decoy-video',
      ),
    );

    final seederV2 = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(specialManifestV2),
    );
    await seederV2.seedIfNeeded();

    final libraries = await harness.database
        .select(harness.database.localLibraries)
        .get();
    expect(libraries, hasLength(3));
    final decoy = libraries.firstWhere((item) => item.id == decoyId);
    expect(decoy.name, '1000ASpecialXCollection（内置新增 999）');
    final decoyVideos = await (harness.database.select(
      harness.database.localLibraryVideos,
    )..where((item) => item.libraryId.equals(decoyId))).get();
    expect(decoyVideos.map((item) => item.videoId), ['v2']);

    final delta = libraries.firstWhere((item) => item.name.contains('内置新增 v2'));
    expect(delta.name, '100%_Special_Collection（内置新增 v2）');

    final deltaVideos = await (harness.database.select(
      harness.database.localLibraryVideos,
    )..where((item) => item.libraryId.equals(delta.id))).get();
    expect(deltaVideos.map((item) => item.videoId), ['v2']);
  });
}

final class _StringManifestLoader implements CuratedLibraryManifestLoader {
  const _StringManifestLoader(this.source);

  final String source;

  @override
  Future<String> load() async => source;
}

final class _FileManifestLoader implements CuratedLibraryManifestLoader {
  const _FileManifestLoader(this.path);

  final String path;

  @override
  Future<String> load() => File(path).readAsString();
}

const _manifest = '''
{
  "version": 1,
  "libraries": [
    {
      "key": "author_hydrafxx",
      "name": "作者：hydrafxx",
      "videos": [
        {
          "id": "3160398",
          "title": "Ingrid Hunnigan [HydraFXX][NO WM]",
          "slug": "4k-ingrid-hunnigan-hydrafxx-no-wm",
          "thumbnailUrl": "https://example.com/1.jpg",
          "duration": "0:47",
          "publishedLabel": "3 years ago",
          "views": 1000,
          "rating": 97,
          "ratingVotes": 798
        },
        {
          "id": "3116871",
          "title": "D.va Vibrator",
          "slug": "d-va-vibrator",
          "thumbnailUrl": null,
          "duration": "0:17",
          "publishedLabel": null,
          "views": null,
          "rating": 98,
          "ratingVotes": 165
        }
      ]
    }
  ]
}
''';

const _manifestV2 = '''
{
  "version": 2,
  "libraries": [
    {
      "key": "author_hydrafxx",
      "name": "作者：hydrafxx",
      "videos": [
        {
          "id": "3160398",
          "title": "Ingrid Hunnigan [HydraFXX][NO WM]",
          "slug": "4k-ingrid-hunnigan-hydrafxx-no-wm"
        },
        {
          "id": "3116871",
          "title": "D.va Vibrator",
          "slug": "d-va-vibrator"
        },
        {
          "id": "new-video",
          "title": "New Video",
          "slug": "new-video"
        }
      ]
    }
  ]
}
''';
