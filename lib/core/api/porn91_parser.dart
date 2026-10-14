import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/porn91_models.dart';
import '../models/video_models.dart';

/// 91porn 页面解析器。
///
/// 站点把真实播放源写在 `document.write(strencode2("…"))` 里，
/// 参数是一段 percent-encode 过的 `<source src='…'>`；容器内另有一条
/// **被注释掉的诱饵源** `ccm.91p52.com/358999.mp4`（全站固定、体积常常更大），
/// 必须整条丢弃，不能按体积挑选。
final class Porn91Parser {
  const Porn91Parser._();

  static const siteId = 'porn91';
  static const baseUrl = 'https://91porn.com';

  /// 全站固定的广告诱饵源文件名。
  static const _decoyFileNames = <String>{'358999.mp4'};

  static final _strencodePattern = RegExp(
    r'''strencode2\(\s*(["'])(.*?)\1\s*\)''',
    dotAll: true,
  );
  static final _sourceSrcPattern = RegExp(
    r'''src=['"]([^'"]+)['"]''',
    caseSensitive: false,
  );
  static final _titleTailPattern = RegExp(
    r'\s*[-–—|]\s*91porn\s*$',
    caseSensitive: false,
  );
  static final _mediaIdPattern = RegExp(r'/(\d+)\.mp4(?:[?#]|$)');
  static final _thumbIdPattern = RegExp(r'/thumb/(\d+)\.');
  static final _bareTitlePattern = RegExp(
    r'^(?:www\.)?(?:91porn|9p47q)(?:\.com)?$',
    caseSensitive: false,
  );

  /// 判断响应是否是站点在“会话未预热”时给出的通用/占位页。
  ///
  /// 实测：新建会话后第一次请求详情页会返回**另一个视频的详情页**
  /// （HTTP 200、海报与播放源同时换成同一个无关编号），
  /// 因此无法从内容判断，只能在请求前先预热会话。
  static bool hasPlayableSource(String source) {
    return resolveStreamCandidate(source) != null;
  }

  /// 从 `strencode2` 编码块里解出直链；解不出返回 null。
  ///
  /// 这是唯一的真源来源：页面里的裸 `<source>` 属于注释掉的诱饵。
  static Porn91StreamCandidate? resolveStreamCandidate(String source) {
    for (final match in _strencodePattern.allMatches(source)) {
      final encoded = match.group(2);
      if (encoded == null) continue;
      final String decoded;
      try {
        decoded = Uri.decodeFull(encoded);
      } on ArgumentError {
        continue;
      } on FormatException {
        continue;
      }
      for (final src in _sourceSrcPattern.allMatches(decoded)) {
        final url = _absolute(src.group(1));
        if (url == null || _isDecoy(url)) continue;
        final mediaId = _mediaIdPattern.firstMatch(url)?.group(1);
        if (mediaId == null) continue;
        return Porn91StreamCandidate(streamUrl: url, mediaId: mediaId);
      }
    }
    return null;
  }

  /// 播放器海报上的媒体编号，用于识别“这一页到底是谁”。
  static String? posterMediaId(String source) {
    final document = html_parser.parse(source);
    final poster = document.querySelector('video')?.attributes['poster'];
    if (poster == null) return null;
    return _thumbIdPattern.firstMatch(poster)?.group(1);
  }

  /// 页面标题（去掉站名尾巴）。
  ///
  /// 站点的错误页/通用页 `<title>` 就是站名本身，这类标题没有信息量，
  /// 返回 null 交给调用方回落到列表标题。
  static String? title(String source) {
    final document = html_parser.parse(source);
    final raw = document.querySelector('title')?.text;
    final cleaned = _clean(raw?.replaceFirst(_titleTailPattern, ''));
    if (cleaned == null || _bareTitlePattern.hasMatch(cleaned)) return null;
    return cleaned;
  }

  /// 列表页与详情页共用的视频卡片（`a[href*=view_video.php]`）。
  static List<VideoItem> videoList(String source) {
    final document = html_parser.parse(source);
    final result = <String, VideoItem>{};
    for (final link in document.querySelectorAll('a[href*="view_video.php"]')) {
      final video = _videoFromLink(link);
      if (video == null) continue;
      result.putIfAbsent(video.id, () => video);
    }
    return result.values.toList(growable: false);
  }

  /// 详情页信息。当前站点详情页没有可信的“相关视频”区块，
  /// 因此 `relatedVideos` 恒为空；分类/标签/作者等集合入口也不存在，
  /// 对应能力位为 false，UI 不会渲染这些区块。
  static VideoDetails videoDetails({
    required String source,
    required VideoItem fallback,
  }) {
    final candidate = resolveStreamCandidate(source);
    final sources = <VideoSource>[];
    if (candidate != null) {
      // 免费主源分辨率随机（实测同一站点出现 202x360 / 404x720 / 202x244），
      // 且没有可逆的高清入口，因此标签不声称具体清晰度。
      sources.add(
        VideoSource(label: '默认', url: candidate.streamUrl, isHd: false),
      );
    }
    final title = Porn91Parser.title(source);
    return VideoDetails(
      video: fallback.copyWith(
        title: title ?? fallback.title,
        duration: _duration(html_parser.parse(source)) ?? fallback.duration,
      ),
      sources: sources,
      categories: const [],
      tags: const [],
      models: const [],
      isFavorite: false,
    );
  }

  static String? _duration(dom.Document document) {
    for (final element in document.querySelectorAll('span.info')) {
      final text = _clean(element.text);
      if (text == null) continue;
      final match = RegExp(r'(\d{1,2}:\d{2}:\d{2})').firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static VideoItem? _videoFromLink(dom.Element link) {
    final href = link.attributes['href'];
    if (href == null) return null;
    final uri = Uri.tryParse(href);
    final viewkey = uri?.queryParameters['viewkey']?.trim();
    if (viewkey == null || viewkey.isEmpty) return null;
    // 卡片容器：站点用 `div.well.videos-text-align`。链接本身会包含
    // 缩略图与标题，因此优先在链接内部取，取不到再退回容器。
    final card = link.parent ?? link;
    final image = link.querySelector('img') ?? card.querySelector('img');
    final title =
        _clean(
          link.querySelector('.video-title')?.text ??
              card.querySelector('.video-title')?.text ??
              image?.attributes['alt'],
        ) ??
        viewkey;
    return VideoItem(
      id: viewkey,
      title: title,
      slug: viewkey,
      siteId: siteId,
      thumbnailUrl: _absoluteImage(
        image?.attributes['data-src'] ?? image?.attributes['src'],
      ),
      duration: _clean(
        (link.querySelector('.duration') ?? card.querySelector('.duration'))
            ?.text,
      ),
    );
  }

  static bool _isDecoy(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final fileName = path.split('/').last;
    return _decoyFileNames.contains(fileName);
  }

  static String? _absolute(String? value) {
    final normalized = _clean(value);
    if (normalized == null) return null;
    if (normalized.startsWith('//')) return 'https:$normalized';
    if (normalized.startsWith('http://')) {
      return 'https://${normalized.substring('http://'.length)}';
    }
    return normalized;
  }

  static String? _absoluteImage(String? value) {
    final normalized = _clean(value);
    if (normalized == null) return null;
    if (normalized.startsWith('//')) return 'https:$normalized';
    if (normalized.startsWith('/')) return '$baseUrl$normalized';
    return normalized;
  }

  static String? _clean(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
