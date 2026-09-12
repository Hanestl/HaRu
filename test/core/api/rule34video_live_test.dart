import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/shared/video_list_filters.dart';

import '../../helpers/test_session_harness.dart';

// Opt-in only. Credentials remain in environment variables and memory.
void main() {
  final email = Platform.environment['HARU_TEST_EMAIL'];
  final password = Platform.environment['HARU_TEST_PASSWORD'];
  test(
    'live: account playlists and custom duration request',
    () async {
      final harness = TestSessionHarness.create();
      addTearDown(harness.dispose);
      await harness.sessionStore.load();
      final api = Rule34VideoApi(sessionStore: harness.sessionStore);
      addTearDown(api.close);
      await api.login(
        email: email!,
        password: password!,
        rememberCredentials: false,
      );
      final playlists = await api.loadMyPlaylists(force: true);
      final expected = int.tryParse(
        Platform.environment['HARU_TEST_PLAYLIST_COUNT'] ?? '',
      );
      if (expected != null) expect(playlists.length, expected);
      expect(playlists.map((p) => p.id).toSet().length, playlists.length);
      final first = await api.loadMyPlaylistsPage(1);
      final second = await api.loadMyPlaylistsPage(2);
      expect(playlists.length, greaterThan(first.length));
      expect(second, isNotEmpty);
      expect(playlists.map((p) => p.id), containsAll(second.map((p) => p.id)));
      final videos = await api.loadFeed(
        FeedKind.newest,
        1,
        filters: const SearchFilters(
          customDurationRange: VideoDurationRange(
            minSeconds: 60,
            maxSeconds: 180,
          ),
        ),
        force: true,
      );
      expect(videos, isNotEmpty);
      for (final video in videos) {
        expect(videoDurationSeconds(video.duration), inInclusiveRange(60, 180));
      }
    },
    skip: email == null || password == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
