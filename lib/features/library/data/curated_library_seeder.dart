import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';

abstract interface class CuratedLibraryManifestLoader {
  Future<String> load();
}

final class AssetCuratedLibraryManifestLoader
    implements CuratedLibraryManifestLoader {
  const AssetCuratedLibraryManifestLoader();

  static const assetPath = 'assets/curated_libraries/v1.json';

  @override
  Future<String> load() => rootBundle.loadString(assetPath);
}

final class CuratedLibrarySeeder {
  const CuratedLibrarySeeder(this._database, this._loader);

  final AppDatabase _database;
  final CuratedLibraryManifestLoader _loader;

  Future<void> seedIfNeeded() async {
    final manifest = _CuratedManifest.parse(await _loader.load());
    await _database.transaction(() async {
      final existingLibraries = await _database
          .select(_database.localLibraries)
          .get();
      final existingNormalizedNames = existingLibraries
          .map((item) => item.normalizedName)
          .toSet();

      final seedKeys = manifest.libraries.map((item) => item.key).toList();
      final allSeedStates = await (_database.select(
        _database.curatedLibrarySeeds,
      )..where((item) => item.seedKey.isIn(seedKeys))).get();
      final seedStateMap = {
        for (final state in allSeedStates) state.seedKey: state,
      };

      for (final preset in manifest.libraries) {
        final existingState = seedStateMap[preset.key];
        if (existingState?.dismissed == true ||
            (existingState?.packVersion ?? 0) >= manifest.version) {
          continue;
        }

        final now = DateTime.now().toUtc();
        final existingVideoIds = await _existingVideoIds(preset);
        final missingVideos = preset.videos
            .where((video) => !existingVideoIds.contains(video.id))
            .toList(growable: false);
        if (missingVideos.isNotEmpty) {
          final preferredName = existingState == null
              ? preset.name
              : '${preset.name}（内置新增 v${manifest.version}）';
          final resolvedName = _availableLibraryName(
            preferredName,
            existingNormalizedNames,
          );
          existingNormalizedNames.add(_normalizeName(resolvedName));
          final libraryId = await _database
              .into(_database.localLibraries)
              .insert(
                LocalLibrariesCompanion.insert(
                  name: resolvedName,
                  normalizedName: _normalizeName(resolvedName),
                  seedKey: Value(existingState == null ? preset.key : null),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          await _database.batch((batch) {
            batch.insertAll(
              _database.localLibraryVideos,
              missingVideos
                  .map(
                    (video) => LocalLibraryVideosCompanion.insert(
                      libraryId: libraryId,
                      videoId: video.id,
                      title: video.title,
                      slug: video.slug,
                      thumbnailUrl: Value(video.thumbnailUrl),
                      durationLabel: Value(video.duration),
                      publishedLabel: Value(video.publishedLabel),
                      views: Value(video.views),
                      rating: Value(video.rating),
                      ratingVotes: Value(video.ratingVotes),
                      addedAt: Value(now),
                    ),
                  )
                  .toList(growable: false),
              mode: InsertMode.insertOrIgnore,
            );
          });
        }
        await _database
            .into(_database.curatedLibrarySeeds)
            .insertOnConflictUpdate(
              CuratedLibrarySeedsCompanion.insert(
                seedKey: preset.key,
                packVersion: manifest.version,
                dismissed: Value(existingState?.dismissed ?? false),
                appliedAt: Value(now),
              ),
            );
      }
    });
  }

  String _availableLibraryName(
    String preferredName,
    Set<String> existingNames,
  ) {
    final preferred = preferredName.trim();
    if (!existingNames.contains(_normalizeName(preferred))) {
      return preferred;
    }
    const suffix = '（精选）';
    final withSuffix = '$preferred$suffix';
    if (!existingNames.contains(_normalizeName(withSuffix))) {
      return withSuffix;
    }
    var index = 2;
    while (existingNames.contains(_normalizeName('$preferred（精选 $index）'))) {
      index += 1;
    }
    return '$preferred（精选 $index）';
  }

  Future<Set<String>> _existingVideoIds(_CuratedLibrary preset) async {
    final base = _normalizeName(preset.name);
    final prefix = '$base（内置新增';
    final escapedPrefix = '${_escapeLike(prefix)}%';
    final libraries =
        await (_database.select(_database.localLibraries)..where(
              (tbl) =>
                  tbl.seedKey.equals(preset.key) |
                  tbl.normalizedName.equals(base) |
                  tbl.normalizedName.like(escapedPrefix, escapeChar: r'\'),
            ))
            .get();
    if (libraries.isEmpty) return <String>{};
    // 只信任 SQL 侧判定（seedKey / 同名 / 转义后的前缀 LIKE）：这里若再做一次
    // Dart 过滤，会掩盖 LIKE 转义是否生效，令 R3-6 回归用例失去判别力。
    final matched = libraries
        .map((library) => library.id)
        .toList(growable: false);
    final videos = await (_database.select(
      _database.localLibraryVideos,
    )..where((item) => item.libraryId.isIn(matched))).get();
    return videos.map((video) => video.videoId).toSet();
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  static String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}

final class _CuratedManifest {
  const _CuratedManifest({required this.version, required this.libraries});

  factory _CuratedManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('精选库清单格式无效。');
    }
    final version = decoded['version'];
    final libraries = decoded['libraries'];
    if (version is! int || version < 1 || libraries is! List) {
      throw const FormatException('精选库清单缺少版本或库列表。');
    }
    final parsed = libraries.map(_CuratedLibrary.parse).toList(growable: false);
    final keys = parsed.map((item) => item.key).toSet();
    if (keys.length != parsed.length) {
      throw const FormatException('精选库清单包含重复标识。');
    }
    return _CuratedManifest(version: version, libraries: parsed);
  }

  final int version;
  final List<_CuratedLibrary> libraries;
}

final class _CuratedLibrary {
  const _CuratedLibrary({
    required this.key,
    required this.name,
    required this.videos,
  });

  factory _CuratedLibrary.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('精选库条目格式无效。');
    }
    final key = value['key'];
    final name = value['name'];
    final videos = value['videos'];
    if (key is! String ||
        key.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        videos is! List) {
      throw const FormatException('精选库条目缺少必要字段。');
    }
    final parsedVideos = videos
        .map(_CuratedVideo.parse)
        .toList(growable: false);
    final videoIds = parsedVideos.map((item) => item.id).toSet();
    if (videoIds.length != parsedVideos.length) {
      throw FormatException('精选库 $name 包含重复视频。');
    }
    return _CuratedLibrary(
      key: key.trim(),
      name: name.trim(),
      videos: parsedVideos,
    );
  }

  final String key;
  final String name;
  final List<_CuratedVideo> videos;
}

final class _CuratedVideo {
  const _CuratedVideo({
    required this.id,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    this.duration,
    this.publishedLabel,
    this.views,
    this.rating,
    this.ratingVotes,
  });

  factory _CuratedVideo.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('精选视频条目格式无效。');
    }
    final id = value['id'];
    final title = value['title'];
    final slug = value['slug'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        slug is! String ||
        slug.trim().isEmpty) {
      throw const FormatException('精选视频条目缺少必要字段。');
    }
    return _CuratedVideo(
      id: id.trim(),
      title: title.trim(),
      slug: slug.trim(),
      thumbnailUrl: value['thumbnailUrl'] as String?,
      duration: value['duration'] as String?,
      publishedLabel: value['publishedLabel'] as String?,
      views: value['views'] as int?,
      rating: value['rating'] as int?,
      ratingVotes: value['ratingVotes'] as int?,
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final String? duration;
  final String? publishedLabel;
  final int? views;
  final int? rating;
  final int? ratingVotes;
}
