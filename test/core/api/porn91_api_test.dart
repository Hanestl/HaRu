import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/porn91_api.dart';
import 'package:flule34/core/api/porn91_parser.dart';
import 'package:flule34/core/models/porn91_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_session_harness.dart';

/// 详情页最小可用标记：一段 strencode2 编码块 + 海报。
String _detailPage({required String mediaId}) {
  final encoded = Uri.encodeFull(
    "<source src='https://la.btc620.com//mp43/$mediaId.mp4?st=abc&e=1&f=z'>",
  );
  return '''
<html><head><title>示例标题 - 91porn</title></head><body>
<video id="player_one" poster="https://1729130453.rsc.cdn77.org/thumb/$mediaId.jpg">
  <script>document.write(strencode2("$encoded"))</script>
</video>
</body></html>
''';
}

const _listPage = '''
<html><body>
<a href="https://91porn.com/view_video.php?viewkey=1941962189">
  <img src="https://1729130453.rsc.cdn77.org/thumb/1247789.jpg" />
  <span class="video-title">示例标题</span>
</a>
</body></html>
''';

/// 记录请求顺序与完整查询串，并按时序返回不同响应——
/// 站点正是靠“第几次请求”决定返回什么。
final class _SequencedAdapter implements HttpClientAdapter {
  _SequencedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, int index) handler;
  final requestedUris = <Uri>[];
  var _index = 0;

  List<String> get requestedPaths =>
      requestedUris.map((uri) => uri.path).toList(growable: false);

  /// 第 [index] 次请求的查询参数，用于断言实际发出的参数名与取值。
  Map<String, String> queryAt(int index) =>
      requestedUris[index].queryParameters;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = _index++;
    requestedUris.add(options.uri);
    return handler(options, index);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _html(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['text/html; charset=utf-8'],
  },
);

void main() {
  late TestSessionHarness harness;

  setUp(() => harness = TestSessionHarness.create());
  tearDown(() => harness.dispose());

  test('加载详情前先预热会话，避免拿到另一个视频', () async {
    final adapter = _SequencedAdapter(
      // 站点的真实行为：会话未预热时，无论请求哪个 viewkey，
      // 第一次都返回另一个视频；预热后的请求才是正确的那条。
      (options, index) => _html(
        options.path.contains('view_video')
            ? _detailPage(mediaId: index == 0 ? '999999' : '1245148')
            : _listPage,
      ),
    );
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );

    final details = await api.loadVideoDetails(
      const VideoItem(
        id: '1941962189',
        title: '列表标题',
        slug: '1941962189',
        siteId: Porn91Parser.siteId,
      ),
    );

    // 预热请求必须排在详情请求之前，且是列表页
    expect(adapter.requestedPaths.first, '/v.php');
    expect(adapter.requestedPaths, contains('/view_video.php'));
    expect(
      adapter.requestedPaths.indexOf('/v.php'),
      lessThan(adapter.requestedPaths.indexOf('/view_video.php')),
    );

    expect(details.sources, hasLength(1));
    expect(details.sources.single.url, contains('1245148'));
    // 未预热时那条别人的视频不得出现在结果里
    expect(details.sources.single.url, isNot(contains('999999')));
  });

  test('同一会话内预热只发生一次', () async {
    final adapter = _SequencedAdapter(
      (options, index) => _html(
        options.path.contains('view_video')
            ? _detailPage(mediaId: '1')
            : _listPage,
      ),
    );
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );
    const video = VideoItem(
      id: 'a',
      title: 't',
      slug: 'a',
      siteId: Porn91Parser.siteId,
    );

    await api.loadVideoDetails(video);
    await api.loadVideoDetails(video);

    expect(
      adapter.requestedPaths.where((path) => path == '/v.php'),
      hasLength(1),
      reason: '预热结果应在实例内复用，而不是每次详情都重新预热',
    );
  });

  test('分类列表按站点参数请求并解析出视频', () async {
    final adapter = _SequencedAdapter((options, index) => _html(_listPage));
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );

    final items = await api.loadCategoryVideos(Porn91Category.topLastWeek, 1);

    expect(items, hasLength(1));
    expect(items.single.id, '1941962189');
    expect(adapter.requestedPaths.last, '/v.php');
    // 上周排行必须作为独立参数 m=-1 发送，而不是并进 category 值
    final query = adapter.queryAt(adapter.requestedUris.length - 1);
    expect(query['category'], 'top');
    expect(query['m'], '-1');
    expect(query['viewtype'], 'basic');
    // 第一页不发送 page
    expect(query.containsKey('page'), isFalse);
  });

  test('分类第二页带上 page 参数', () async {
    final adapter = _SequencedAdapter((options, index) => _html(_listPage));
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );

    await api.loadCategoryVideos(Porn91Category.hot, 3);

    expect(adapter.queryAt(0)['page'], '3');
  });

  test('搜索用 search_id 而不是 search_key', () async {
    final adapter = _SequencedAdapter((options, index) => _html(_listPage));
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );

    await api.searchVideos('学生', 1);

    expect(adapter.requestedPaths.last, '/search_result.php');
    final query = adapter.queryAt(0);
    expect(query['search_id'], '学生');
    // 站点只认 search_id；带上 search_key 实测返回 0 条
    expect(query.containsKey('search_key'), isFalse);
  });

  test('空关键词不发请求', () async {
    final adapter = _SequencedAdapter((options, index) => _html(_listPage));
    final api = Porn91Api(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );

    expect(await api.searchVideos('   ', 1), isEmpty);
    expect(adapter.requestedPaths, isEmpty);
  });
}
