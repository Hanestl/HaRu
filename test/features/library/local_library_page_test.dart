import 'dart:async';
import 'dart:io';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flule34/features/library/local_library_page.dart';
import 'package:flule34/shared/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('新增本地库后弹窗可完整退出且列表刷新', (tester) async {
    final repository = _InteractiveLocalLibraryRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalLibraryOverview(repository: repository)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('新建本地库'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '测试分类',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('测试分类'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('LocalLibraryOverview 在加载失败时展示 AppErrorView 并支持点击重试', (
    tester,
  ) async {
    final repository = _InteractiveLocalLibraryRepository();
    addTearDown(repository.dispose);
    repository.shouldFailSummaries = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalLibraryOverview(repository: repository)),
      ),
    );
    await tester.pump();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(repository.watchSummariesCallCount, 1);

    repository.shouldFailSummaries = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(repository.watchSummariesCallCount, 2);
    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('LocalLibraryPage 在加载失败时展示 AppErrorView 并支持点击重试', (tester) async {
    final repository = _InteractiveLocalLibraryRepository();
    addTearDown(repository.dispose);
    repository.shouldFailVideos = true;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LocalLibraryPage(
              libraryId: 1,
              title: '测试库',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(repository.watchVideosCallCount, 1);

    repository.shouldFailVideos = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(repository.watchVideosCallCount, 2);
    expect(find.byType(AppErrorView), findsNothing);
  });
}

final class _InteractiveLocalLibraryRepository
    implements LocalLibraryRepository {
  final StreamController<List<LocalLibrary>> _libraries =
      StreamController<List<LocalLibrary>>.broadcast();
  List<LocalLibrary> _current = const [];

  @override
  Stream<List<LocalLibrary>> watchLibraries() async* {
    yield _current;
    yield* _libraries.stream;
  }

  var shouldFailSummaries = false;
  var watchSummariesCallCount = 0;

  @override
  Stream<List<LocalLibrarySummary>> watchLibrarySummaries() async* {
    watchSummariesCallCount++;
    if (shouldFailSummaries) {
      throw const SocketException('failed to load summaries');
    }
    yield* watchLibraries().map(
      (libraries) => libraries
          .map(
            (library) => LocalLibrarySummary(library: library, videoCount: 0),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<int> createLibrary(String name) async {
    final library = LocalLibrary(
      id: 1,
      name: name,
      normalizedName: name.toLowerCase(),
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
    );
    _current = [library];
    _libraries.add(_current);
    return library.id;
  }

  @override
  Future<void> addVideo({required int libraryId, required VideoItem video}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLibrary(int id) => throw UnimplementedError();

  @override
  Future<Set<int>> libraryIdsForVideo(String videoId) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeVideo({required int libraryId, required String videoId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> renameLibrary(int id, String name) => throw UnimplementedError();

  var shouldFailVideos = false;
  var watchVideosCallCount = 0;

  @override
  Stream<List<VideoItem>> watchVideos(int libraryId) {
    watchVideosCallCount++;
    if (shouldFailVideos) {
      return Stream.error(const SocketException('failed to load videos'));
    }
    return Stream.value(const <VideoItem>[]);
  }

  Future<void> dispose() => _libraries.close();
}
