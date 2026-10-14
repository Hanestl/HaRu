import 'dart:io';

import 'package:flule34/core/api/porn91_api.dart';
import 'package:flule34/core/api/porn91_parser.dart';
import 'package:flule34/core/models/porn91_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

// Opt-in only。默认跳过，避免 CI 依赖外部站点可用性。
// 需要真实联网验证时：
//   HARU_TEST_PORN91=1 flutter test --no-pub test/core/api/porn91_live_test.dart
void main() {
  final enabled = Platform.environment['HARU_TEST_PORN91'] != null;

  test(
    'live: 分类浏览、详情解析与直链可播放性',
    () async {
      final harness = TestSessionHarness.create();
      addTearDown(harness.dispose);
      final api = Porn91Api(sessionStore: harness.sessionStore);

      // 1. 分类浏览（列表请求同时预热会话）
      final items = await api.loadCategoryVideos(Porn91Category.hot, 1);
      expect(items, isNotEmpty, reason: '热门分类应返回条目');
      for (final video in items) {
        expect(video.id, isNotEmpty);
        expect(video.title, isNotEmpty);
        expect(video.siteId, Porn91Parser.siteId);
      }

      // 2. 详情：必须解析出可播放的直链，且不是全站诱饵
      final details = await api.loadVideoDetails(items.first);
      expect(details.sources, isNotEmpty, reason: '详情页应解析出播放源');
      final url = details.sources.single.url;
      expect(url, startsWith('https://'));
      expect(url, isNot(contains('358999.mp4')));
      expect(details.video.title, isNotEmpty);

      // 3. 直链真的可下载：HEAD 应有非零长度且支持 Range
      final request = await HttpClient().headUrl(Uri.parse(url));
      request.headers.set('User-Agent', Porn91Api.browserUserAgent);
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.contentLength, greaterThan(1 << 20));
      expect(response.headers.value('accept-ranges'), 'bytes');

      // 4. 同一实例再次取详情，仍应拿到同一条视频（预热只发生一次）
      final again = await api.loadVideoDetails(items.first);
      expect(again.sources.single.url, isNot(contains('358999.mp4')));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'live: 搜索返回该站结果',
    () async {
      final harness = TestSessionHarness.create();
      addTearDown(harness.dispose);
      final api = Porn91Api(sessionStore: harness.sessionStore);

      final results = await api.searchVideos('学生', 1);

      expect(results, isNotEmpty, reason: 'search_id 搜索应有结果');
      for (final video in results) {
        expect(video.id, isNotEmpty);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
