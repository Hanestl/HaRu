import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../media/video_source_quality.dart';
import '../models/account_models.dart';
import '../models/rule34_comment_models.dart';
import '../models/video_models.dart';

class SiteParser {
  static const _baseUri = 'https://rule34video.com/';
  static final _videoUrlRegex = RegExp(r'/video/(\d+)/([^/]+)/?');
  static final _percentRatingRegex = RegExp(r'(\d{1,3})\s*%');
  static final _votesRegex = RegExp(
    r'\(([\d,.]+\s*[KMB]?)\)',
    caseSensitive: false,
  );
  static final _whitespaceRegex = RegExp(r'\s+');
  static final _nonDigitsRegex = RegExp(r'[^0-9]');
  static final _compactNumberRegex = RegExp(
    r'([0-9]+(?:\.[0-9]+)?)\s*([KMB])?',
  );

  /// 只在指定 id 的区块内提取视频卡片。
  ///
  /// 账号历史这类页面的正文里混着「推荐」「你可能喜欢」等其它区块，
  /// 整页解析会把推荐视频当成历史条目。区块不存在时退回整页解析，
  /// 避免模板变化后静默返回空列表。
  static List<VideoItem> videoListInBlock(String source, String blockId) {
    final document = html_parser.parse(source);
    final block = document.querySelector('#$blockId');
    if (block == null) {
      return videoList(source);
    }
    return videoList(block.outerHtml);
  }

  static List<VideoItem> videoList(String source) {
    final document = html_parser.parse(source);
    final result = <String, VideoItem>{};

    for (final card in document.querySelectorAll(
      'div.item.thumb, div.item.ma-v, div.item.ma-prow, div.item.ma-row',
    )) {
      final link =
          card.querySelector('a.th.js-open-popup') ??
          card.querySelector('a.th[href*="/video/"]') ??
          card.querySelector('a.ma-thumb') ??
          card.querySelector('a.ma-row__t') ??
          card.querySelector('a[href*="/video/"]');
      final href = link?.attributes['href'] ?? card.attributes['data-url'];
      final match = _videoUrlRegex.firstMatch(href ?? '');
      if (match == null) {
        continue;
      }

      final image =
          card.querySelector('img.thumb') ?? card.querySelector('img');
      final title =
          _clean(card.attributes['data-title']) ??
          _clean(card.querySelector('.thumb_title')?.text) ??
          _clean(card.querySelector('.ma-v__t')?.text) ??
          _clean(card.querySelector('.ma-row__t')?.text) ??
          _clean(link?.attributes['title']) ??
          _clean(image?.attributes['alt']) ??
          '未命名视频';
      final thumbnail = _imageUrl(image);
      final preview = _url(
        card.querySelector('[data-preview]')?.attributes['data-preview'] ??
            link?.attributes['data-preview'],
      );

      final metaSpans = card.querySelectorAll('.ma-v__m span, .ma-row__m span');
      String? publishedLabel = _clean(
        card.querySelector('.thumb_info .added')?.text,
      );
      int? views = _compactNumber(
        _clean(card.querySelector('.thumb_info .views')?.text) ??
            card.attributes['data-views'],
      );
      int? rating = _number(
        _percentRatingRegex
            .firstMatch(card.querySelector('.thumb_info .rating')?.text ?? '')
            ?.group(1),
      );
      int? ratingVotes = _compactNumber(
        _votesRegex
            .firstMatch(card.querySelector('.thumb_info .rating')?.text ?? '')
            ?.group(1),
      );

      if (metaSpans.isNotEmpty) {
        for (final span in metaSpans) {
          final text = _clean(span.text);
          if (text == null) continue;
          if (text.contains('views') && views == null) {
            views = _compactNumber(text.replaceFirst('views', '').trim());
          } else if (text.contains('ago') && publishedLabel == null) {
            publishedLabel = text;
          } else if (text.endsWith('%') && rating == null) {
            rating = _number(_percentRatingRegex.firstMatch(text)?.group(1));
          }
        }
      }

      if (rating == null && card.attributes['data-rating'] != null) {
        final floatRating = double.tryParse(card.attributes['data-rating']!);
        if (floatRating != null) {
          rating = (floatRating / 5.0 * 100).round();
        }
      }

      result[match.group(1)!] = VideoItem(
        id: match.group(1)!,
        slug: match.group(2)!,
        title: title,
        thumbnailUrl: thumbnail,
        previewUrl: preview,
        duration:
            _clean(card.querySelector('.ma-dur')?.text) ??
            _clean(card.querySelector('.time')?.text),
        publishedLabel: publishedLabel,
        views: views,
        rating: rating,
        ratingVotes: ratingVotes,
      );
    }

    return result.values.toList(growable: false);
  }

  static MemberProfile? memberProfile(String source, String userId) {
    final document = html_parser.parse(source);
    final header = document.querySelector('.channel_logo');
    final maHero = document.querySelector('.ma-hero');

    if (header == null && maHero == null) {
      return null;
    }

    if (maHero != null) {
      final displayName =
          _clean(document.querySelector('#rdp-name')?.text) ??
          _clean(maHero.querySelector('.ma-hero__id h1')?.text);
      if (displayName == null) {
        return null;
      }
      final details = <String, String>{};
      for (final stat in document.querySelectorAll(
        '.ma-stats a.ma-stat, .ma-stats div.ma-stat',
      )) {
        final label = _clean(stat.querySelector('span')?.text);
        final value = _clean(stat.querySelector('b')?.text);
        if (label != null && value != null) {
          details[label] = value;
        }
      }
      final subscribersCount = _clean(
        document.querySelector('[data-rdp-subs-count]')?.text,
      );
      final subscribersLabel = subscribersCount != null
          ? '$subscribersCount Subscribers'
          : null;
      return MemberProfile(
        id: userId,
        displayName: displayName,
        avatarUrl: _imageUrl(maHero.querySelector('.ma-av img')),
        subscribersLabel: subscribersLabel,
        coverUrl: _imageUrl(document.querySelector('.ma-hero__bg img')),
        verified: maHero.querySelector('.ma-verified') != null,
        details: Map.unmodifiable(details),
      );
    }

    final displayName = _clean(header?.querySelector('h2.title')?.text);
    if (displayName == null) {
      return null;
    }

    final details = <String, String>{};
    for (final item in document.querySelectorAll('.box_information li')) {
      final label = _clean(item.querySelector('span')?.text);
      final text = _clean(item.text);
      if (label == null || text == null) {
        continue;
      }
      final value = text.replaceFirst(label, '').trim();
      if (value.isNotEmpty) {
        details[label] = value;
      }
    }
    return MemberProfile(
      id: userId,
      displayName: displayName,
      avatarUrl: _imageUrl(header?.querySelector('.avatar img')),
      subscribersLabel: _clean(
        header?.querySelector('.subscribers_count')?.text,
      ),
      coverUrl: _imageUrl(document.querySelector('.channel_bg img')),
      verified: header?.querySelector('.verified-status') != null,
      details: Map.unmodifiable(details),
    );
  }

  static VideoDetails videoDetails({
    required String source,
    required VideoItem fallback,
  }) {
    final document = html_parser.parse(source);
    final schema = _videoSchema(document);
    final flashTitle = _flashValue(source, 'video_title');
    final schemaTitle = _string(schema?['name']);
    final metadataItems = _videoMetadata(document);
    final categoryTitles = metadataItems
        .where((item) => item.kind == DiscoveryKind.category)
        .map((item) => item.title)
        .toList(growable: false);
    final tagTitles = metadataItems
        .where((item) => item.kind == DiscoveryKind.tag)
        .map((item) => item.title)
        .toList(growable: false);
    final modelTitles = metadataItems
        .where((item) => item.kind == DiscoveryKind.model)
        .map((item) => item.title)
        .toList(growable: false);
    final thumbnail =
        _url(_flashValue(source, 'preview_url')) ??
        _url(_string(schema?['thumbnailUrl']));
    final favoriteButton = document.querySelector(
      '#tab_video_info a.button_fav, '
      '.video-info a.button_fav, '
      '.video-holder a.button_fav',
    );
    final favoriteButtonText = _clean(favoriteButton?.text)?.toLowerCase();
    final isFavorite =
        favoriteButton?.classes.contains('delete') == true ||
        favoriteButtonText?.contains('remove from favorites') == true ||
        favoriteButtonText?.contains('delete from favorites') == true;
    final video = fallback.copyWith(
      title: flashTitle ?? schemaTitle,
      thumbnailUrl: thumbnail,
      duration:
          _flashValue(source, 'video_duration') ??
          _isoDuration(_string(schema?['duration'])) ??
          fallback.duration,
      publishedLabel:
          _clean(_string(schema?['uploadDate'])) ?? fallback.publishedLabel,
      views: _viewsFromSchema(schema) ?? fallback.views,
      isFavorite: isFavorite,
    );

    return VideoDetails(
      video: video,
      description:
          _clean(_string(schema?['description'])) ??
          _clean(
            document
                .querySelector('meta[name="description"]')
                ?.attributes['content'],
          ),
      categories: categoryTitles.isEmpty
          ? _split(_flashValue(source, 'video_categories'))
          : categoryTitles,
      tags: tagTitles.isEmpty
          ? _split(_flashValue(source, 'video_tags'))
          : tagTitles,
      models: modelTitles.isEmpty
          ? _split(_flashValue(source, 'video_models'))
          : modelTitles,
      sources: _sources(source),
      isFavorite: isFavorite,
      metadataItems: metadataItems,
      relatedVideos: videoList(source)
          .where((item) => item.id != fallback.id)
          .take(12)
          .toList(growable: false),
      ratingVotes: _number(
        RegExp(r'\(([\d,]+)\)')
            .firstMatch(document.querySelector('.voters.count')?.text ?? '')
            ?.group(1),
      ),
      uploader: _uploader(document),
      playlistIds: _playlistIds(document),
    );
  }

  static Set<String> _playlistIds(dom.Document document) {
    final result = <String>{};
    for (final link in document.querySelectorAll(
      'a[data-fav-type="10"][data-playlist-id]',
    )) {
      if (link.classes.contains('delete') ||
          link.attributes['href'] != '#add_to_playlist') {
        continue;
      }
      dom.Element? container = link.parent;
      while (container != null && container.localName != 'li') {
        container = container.parent;
      }
      if (container?.classes.contains('hidden') != true) {
        continue;
      }
      final id = link.attributes['data-playlist-id']?.trim();
      if (id != null && id.isNotEmpty && !id.contains('%')) {
        result.add(id);
      }
    }
    return Set.unmodifiable(result);
  }

  static UploaderSummary? _uploader(dom.Document document) {
    for (final column in document.querySelectorAll('.col')) {
      final label = _clean(column.querySelector('.label')?.text)?.toLowerCase();
      if (label != 'uploaded by') {
        continue;
      }
      final link = column.querySelector('a[href*="/members/"]');
      final href = link?.attributes['href'];
      final match = RegExp(r'/members/(\d+)/?').firstMatch(href ?? '');
      final id = match?.group(1);
      if (link == null || id == null) {
        continue;
      }
      final image = link.querySelector('img');
      final name = _clean(image?.attributes['alt']) ?? _clean(link.text);
      if (name == null) {
        continue;
      }
      return UploaderSummary(
        id: id,
        name: name,
        avatarUrl: _imageUrl(image),
        verified: link.querySelector('.verified-status') != null,
      );
    }
    return null;
  }

  static List<VideoMetadataItem> _videoMetadata(dom.Document document) {
    final result = <String, VideoMetadataItem>{};
    for (final chip in document.querySelectorAll('.js-video-vote-chip')) {
      final type = chip.attributes['data-item-type'];
      final kind = switch (type) {
        'category' => DiscoveryKind.category,
        'tag' => DiscoveryKind.tag,
        'model' => DiscoveryKind.model,
        _ => null,
      };
      final id = _clean(chip.attributes['data-item-id']);
      final link = chip.querySelector('a[href]');
      final href = link?.attributes['href'];
      final title =
          _clean(link?.querySelector('span')?.text) ??
          _clean(link?.querySelector('img')?.attributes['alt']) ??
          _clean(link?.text);
      if (kind == null || id == null || href == null || title == null) {
        continue;
      }
      final resolved = Uri.parse(_baseUri).resolve(href).path;
      final path = resolved.endsWith('/') ? resolved : '$resolved/';
      result['${kind.name}:$id'] = VideoMetadataItem(
        id: id,
        title: title,
        path: path,
        kind: kind,
        thumbnailUrl: _imageUrl(link?.querySelector('img')),
        upScore: _number(chip.attributes['data-up-score']) ?? 0,
        downScore: _number(chip.attributes['data-down-score']) ?? 0,
      );
    }
    return result.values.toList(growable: false);
  }

  static List<TagSuggestion> tagSuggestions(String source) {
    return searchSuggestions(source, SearchSuggestionKind.tag)
        .map(
          (item) =>
              TagSuggestion(id: item.id, title: item.title, total: item.total),
        )
        .toList(growable: false);
  }

  static List<SearchSuggestion> searchSuggestions(
    String source,
    SearchSuggestionKind kind,
  ) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map>()
        .map((item) {
          return SearchSuggestion(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            total: _number(item['total']?.toString()) ?? 0,
            kind: kind,
          );
        })
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }

  static List<SubscriptionItem> subscriptions(String source) {
    final document = html_parser.parse(source);
    final result = <String, SubscriptionItem>{};
    for (final container in document.querySelectorAll('div.item')) {
      // 分类订阅在“我的订阅”表单中没有实体链接（href="#"），
      // 只能从名称和删除控件识别；名称 slug 与分类页面路径一致。
      final formName = _clean(container.querySelector('.name')?.text);
      if (formName != null &&
          container.querySelector('input[name="delete[]"]') != null &&
          container.querySelector('a[href="#"]') != null) {
        final slug = _categorySlug(formName);
        if (slug.isNotEmpty) {
          final path = '/categories/$slug/';
          result[path] = SubscriptionItem(
            title: formName,
            path: path,
            kind: SubscriptionKind.category,
          );
          continue;
        }
      }
      for (final link in container.querySelectorAll('a[href]')) {
        final href = link.attributes['href'];
        final kind = _subscriptionKind(href);
        if (href == null || kind == null) {
          continue;
        }
        final image =
            link.querySelector('img') ?? container.querySelector('img');
        final title =
            _clean(container.attributes['data-title']) ??
            _clean(link.attributes['title']) ??
            _clean(image?.attributes['alt']) ??
            _clean(container.querySelector('.title')?.text) ??
            _clean(container.querySelector('.ma-row__t')?.text) ??
            _clean(link.text);
        if (title == null) {
          continue;
        }
        final path = Uri.parse(_baseUri).resolve(href).path;
        final normalizedPath = path.endsWith('/') ? path : '$path/';
        result[normalizedPath] = SubscriptionItem(
          title: title,
          path: normalizedPath,
          kind: kind,
          thumbnailUrl: _imageUrl(image),
        );
        break;
      }
    }
    return result.values.toList(growable: false);
  }

  static String _categorySlug(String title) {
    return title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceFirst(RegExp(r'^-+'), '')
        .replaceFirst(RegExp(r'-+$'), '');
  }

  static String? collectionAvatar(String source) {
    final document = html_parser.parse(source);
    return _imageUrl(
      document.querySelector(
        '.brand_image_wrapper img, .brand_image img, .model-avatar img',
      ),
    );
  }

  static List<PlaylistItem> playlists(String source) {
    final document = html_parser.parse(source);
    final result = <String, PlaylistItem>{};
    for (final link in document.querySelectorAll(
      'a[href*="/playlists/"], a[href*="/my/playlists/"]',
    )) {
      final href = link.attributes['href'];
      final match = RegExp(
        r'/(?:my/)?playlists/(\d+)(?:/([^/]+))?/?',
      ).firstMatch(href ?? '');
      if (match == null) {
        continue;
      }
      final container = _closestItem(link) ?? link.parent;
      final text = container?.text.replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final image =
          container?.querySelector('img') ?? link.querySelector('img');
      final title =
          _clean(container?.attributes['data-title']) ??
          _clean(
            container
                ?.querySelector(
                  '.thumb_title, .playlist-title, .title, .headline, .ma-v__t',
                )
                ?.text,
          ) ??
          _clean(link.attributes['title']) ??
          '未命名播放列表';
      final resolved = Uri.parse(_baseUri).resolve(href!).path;
      final path = resolved.endsWith('/') ? resolved : '$resolved/';
      // 「我的播放列表」页每张卡片先给内容页链接 /playlists/<id>/<slug>/，随后
      // 再给编辑页链接 /my/playlists/<id>/。按 id 去重时后者会覆盖前者，导致后续
      // 按内容页协议翻页却请求到编辑页，第二页起拿不到数据、列表只显示开头一小段。
      // 这里始终保留更具体的内容页链接。
      final existing = result[match.group(1)!];
      if (existing != null &&
          _isPlaylistEditPath(path) &&
          !_isPlaylistEditPath(existing.path)) {
        continue;
      }
      result[match.group(1)!] = PlaylistItem(
        id: match.group(1)!,
        title: title,
        path: path,
        thumbnailUrl: _imageUrl(image),
        videoCount:
            _number(
              RegExp(
                r'([\d,]+)\s*videos?',
                caseSensitive: false,
              ).firstMatch(text)?.group(1),
            ) ??
            _compactNumber(_clean(container?.querySelector('.added')?.text)),
        views:
            _number(
              RegExp(
                r'([\d,]+)\s*views?',
                caseSensitive: false,
              ).firstMatch(text)?.group(1),
            ) ??
            _compactNumber(_clean(container?.querySelector('.views')?.text)),
      );
    }
    return result.values.toList(growable: false);
  }

  /// 编辑页链接形如 `/my/playlists/<id>/`；内容页形如 `/playlists/<id>/<slug>/`
  /// 或 `/my/playlists/<id>/<slug>/`。
  static bool _isPlaylistEditPath(String path) =>
      RegExp(r'^/my/playlists/\d+/$').hasMatch(path);

  static PlaylistFormData playlistForm(String source) {
    final document = html_parser.parse(source);
    final title = _clean(
      document.querySelector('input[name="title"]')?.attributes['value'],
    );
    if (title == null) {
      throw const FormatException('播放列表编辑页面缺少标题字段。');
    }
    final description =
        document.querySelector('textarea[name="description"]')?.text.trim() ??
        document
            .querySelector('input[name="description"]')
            ?.attributes['value']
            ?.trim() ??
        '';
    final privacyInputs = document.querySelectorAll('[name="is_private"]');
    var isPrivate = false;
    for (final input in privacyInputs) {
      final tag = input.localName;
      if (tag == 'select') {
        final selected = input.querySelector('option[selected]');
        if (selected != null) {
          isPrivate = selected.attributes['value'] == '1';
          break;
        }
      }
      final type = input.attributes['type']?.toLowerCase();
      final checked = input.attributes.containsKey('checked');
      if (type == 'radio' || type == 'checkbox') {
        if (checked) {
          isPrivate = input.attributes['value'] == '1';
          break;
        }
        continue;
      }
      if (input.attributes['value'] == '1') {
        isPrivate = true;
      }
    }
    return PlaylistFormData(
      title: title,
      description: description,
      isPrivate: isPrivate,
    );
  }

  static List<ContentCollectionItem> contentCollections(
    String source,
    DiscoveryKind kind,
  ) {
    final document = html_parser.parse(source);
    final result = <String, ContentCollectionItem>{};
    final segment = RegExp.escape(kind.pathSegment);
    final pathExpression = RegExp('/$segment/([^/]+)/?');
    for (final link in document.querySelectorAll(
      'a[href*="/${kind.pathSegment}/"]',
    )) {
      final href = link.attributes['href'];
      final match = pathExpression.firstMatch(href ?? '');
      if (match == null) {
        continue;
      }
      final id = match.group(1)!;
      if (id.isEmpty || id == 'sort') {
        continue;
      }
      final container = _closestItem(link) ?? link.parent;
      final image =
          container?.querySelector('img') ?? link.querySelector('img');
      final title =
          _clean(link.attributes['title']) ??
          _clean(image?.attributes['alt']) ??
          _clean(container?.querySelector('.title')?.text) ??
          _clean(link.text);
      if (title == null) {
        continue;
      }
      final path = Uri.parse(_baseUri).resolve(href!).path;
      final normalizedPath = path.endsWith('/') ? path : '$path/';
      final text = container?.text.replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final thumbnailUrl = _imageUrl(image);
      result[normalizedPath] = ContentCollectionItem(
        id: id,
        title: title,
        path: normalizedPath,
        kind: kind,
        filterId: _collectionFilterId(kind, id, thumbnailUrl),
        thumbnailUrl: thumbnailUrl,
        total: _number(
          RegExp(
            r'([\d,]+)\s*videos?',
            caseSensitive: false,
          ).firstMatch(text)?.group(1),
        ),
      );
    }
    return result.values.toList(growable: false);
  }

  static String? genericError(String source) {
    return _clean(
      html_parser.parse(source).querySelector('.generic-error')?.text,
    );
  }

  static String? asyncActionError(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded['status'] == 'failure') {
          final errors = decoded['errors'];
          if (errors is List && errors.isNotEmpty) {
            final first = errors.first;
            if (first is Map && first['message'] != null) {
              return first['message'].toString();
            }
          }
        }
      } catch (_) {
        // 错误体不是合法 JSON 时忽略，下面退回 HTML 里的错误文案。
      }
    }
    final document = html_parser.parse(source);
    return _clean(document.querySelector('error')?.text) ??
        _clean(document.querySelector('.generic-error')?.text) ??
        _clean(document.querySelector('.field-error')?.text);
  }

  /// 解析 Rule34Video 详情页的评论列表。
  ///
  /// 该站评论为服务端渲染在 `#video_comments_video_comments_items` 下，
  /// 每条结构（浏览器实测）：
  /// `.item.row[data-comment-id] > .comment-inner`
  ///   `.user-logo` 仅一个成员链接（无真实头像，svg 占位）
  ///   `.comment-info > .inner > a[href="/members/N/"]` 用户名 + `.date span` 日期
  ///   `.coment-text` 评论内容
  /// 无分页、无回复与赞踩结构。
  static List<Rule34VideoComment> videoComments(String source) {
    final document = html_parser.parse(source);
    final container = document.querySelector(
      '#video_comments_video_comments_items',
    );
    if (container == null) {
      return const [];
    }
    final comments = <Rule34VideoComment>[];
    for (final item in document.querySelectorAll(
      '#video_comments_video_comments_items .item.row',
    )) {
      final id = item.attributes['data-comment-id'];
      if (id == null || id.isEmpty) {
        continue;
      }
      final inner = item.querySelector('.comment-info');
      if (inner == null) {
        continue;
      }
      final username = _clean(inner.querySelector('.inner a')?.text) ?? '匿名用户';
      final dateLabel = _clean(inner.querySelector('.date span')?.text);
      final content = _clean(inner.querySelector('.coment-text')?.text);
      if (content == null) {
        continue;
      }
      comments.add(
        Rule34VideoComment(
          id: id,
          username: username,
          content: content,
          avatarUrl: _imageUrl(item.querySelector('.user-logo img')),
          dateLabel: dateLabel,
        ),
      );
    }
    return comments;
  }

  static dom.Element? _closestItem(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      if (current.localName == 'div' && current.classes.contains('item')) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  static SubscriptionKind? _subscriptionKind(String? href) {
    if (href == null) {
      return null;
    }
    if (href.contains('/categories/')) {
      return SubscriptionKind.category;
    }
    if (href.contains('/models/')) {
      return SubscriptionKind.model;
    }
    if (href.contains('/members/')) {
      return SubscriptionKind.member;
    }
    if (href.contains('/playlists/')) {
      return SubscriptionKind.playlist;
    }
    if (href.contains('/channels/')) {
      return SubscriptionKind.channel;
    }
    return null;
  }

  static String? userId(String source) {
    return RegExp(
      r'''(?:["']?userId["']?)\s*:\s*["']?(\d+)["']?''',
      caseSensitive: false,
    ).firstMatch(source)?.group(1);
  }

  static bool isVideoDetailsPage(String source, String videoId) {
    final document = html_parser.parse(source);
    final canonical = document
        .querySelector('link[rel="canonical"]')
        ?.attributes['href'];
    if (canonical != null &&
        RegExp('/video/${RegExp.escape(videoId)}/').hasMatch(canonical)) {
      return true;
    }
    return document.querySelector('[data-video-id="$videoId"]') != null ||
        _flashValue(source, 'video_id') == videoId;
  }

  static List<VideoSource> _sources(String source) {
    final fields = <String>{'video_url'};
    for (final match in RegExp(
      r'''(?:["']?)(video_alt_url\d*)(?:["']?)\s*:''',
      caseSensitive: false,
    ).allMatches(source)) {
      final field = match.group(1);
      if (field != null) {
        fields.add(field);
      }
    }
    final orderedFields = fields.toList(growable: false)
      ..sort(
        (left, right) =>
            _sourceFieldRank(left).compareTo(_sourceFieldRank(right)),
      );
    final result = <String, VideoSource>{};
    for (final field in orderedFields) {
      final url = _url(_flashValue(source, field));
      if (url == null) {
        continue;
      }
      final rawLabel =
          _flashValue(source, '${field}_text') ??
          RegExp(
            r'_(\d+p?)\.mp4',
            caseSensitive: false,
          ).firstMatch(url)?.group(1) ??
          'MP4';
      final height = parseVideoSourceHeight(rawLabel, url: url);
      final label = switch (height) {
        2160 when rawLabel.toLowerCase().contains('4k') => '2160p (4K)',
        4320 when rawLabel.toLowerCase().contains('8k') => '4320p (8K)',
        _ => rawLabel,
      };
      result[url] = VideoSource(
        label: label,
        url: url,
        isHd: (height ?? 0) >= 720,
      );
    }
    // 统一高清晰度在上：无明确高度的源（如 MP4）兜底排最后。
    final sorted = result.values.toList(growable: false)
      ..sort((a, b) {
        final heightA = parseVideoSourceHeight(a.label, url: a.url);
        final heightB = parseVideoSourceHeight(b.label, url: b.url);
        if (heightA == null && heightB == null) return 0;
        if (heightA == null) return 1;
        if (heightB == null) return -1;
        return heightB.compareTo(heightA);
      });
    return sorted;
  }

  static int _sourceFieldRank(String field) {
    if (field == 'video_url') {
      return 0;
    }
    final suffix = RegExp(r'(\d+)$').firstMatch(field)?.group(1);
    return int.tryParse(suffix ?? '') ?? 1;
  }

  static Map<String, dynamic>? _videoSchema(dom.Document document) {
    for (final element in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        final decoded = jsonDecode(element.text);
        final video = _findVideoSchema(decoded);
        if (video != null) {
          return video;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findVideoSchema(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['@type'] == 'VideoObject') {
        return decoded;
      }
      final graph = decoded['@graph'];
      if (graph is List) {
        for (final item in graph) {
          final result = _findVideoSchema(item);
          if (result != null) {
            return result;
          }
        }
      }
    }
    if (decoded is List) {
      for (final item in decoded) {
        final result = _findVideoSchema(item);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  static String? _flashValue(String source, String key) {
    final prefix = RegExp(
      "(?:[\"']?${RegExp.escape(key)}[\"']?)\\s*:\\s*([\"'])",
    ).firstMatch(source);
    if (prefix == null) return null;
    final decoded = _decodeScriptString(
      source,
      start: prefix.end,
      quote: prefix.group(1)!,
    );
    if (decoded == null) return null;
    return _clean(html_parser.parseFragment(decoded).text);
  }

  static String? _decodeScriptString(
    String source, {
    required int start,
    required String quote,
  }) {
    final result = StringBuffer();
    for (var index = start; index < source.length; index += 1) {
      final character = source[index];
      if (character == quote) return result.toString();
      if (character != r'\') {
        result.write(character);
        continue;
      }
      if (++index >= source.length) return null;
      final escaped = source[index];
      switch (escaped) {
        case 'b':
          result.write('\b');
        case 'f':
          result.write('\f');
        case 'n':
          result.write('\n');
        case 'r':
          result.write('\r');
        case 't':
          result.write('\t');
        case 'v':
          result.write('\v');
        case 'u':
          final end = index + 5;
          if (end > source.length) return null;
          final value = int.tryParse(
            source.substring(index + 1, end),
            radix: 16,
          );
          if (value == null) return null;
          result.writeCharCode(value);
          index = end - 1;
        case 'x':
          final end = index + 3;
          if (end > source.length) return null;
          final value = int.tryParse(
            source.substring(index + 1, end),
            radix: 16,
          );
          if (value == null) return null;
          result.writeCharCode(value);
          index = end - 1;
        case '\n':
          break;
        case '\r':
          if (index + 1 < source.length && source[index + 1] == '\n') {
            index += 1;
          }
        default:
          result.write(escaped);
      }
    }
    return null;
  }

  static int? _viewsFromSchema(Map<String, dynamic>? schema) {
    final statistics = schema?['interactionStatistic'];
    if (statistics is! List) {
      return null;
    }
    for (final item in statistics.whereType<Map>()) {
      final interaction = item['interactionType'];
      final type = interaction is Map ? interaction['@type']?.toString() : null;
      if (type == 'WatchAction') {
        return _number(item['userInteractionCount']?.toString());
      }
    }
    return null;
  }

  static String? _isoDuration(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static List<String> _split(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    return value
        .split(',')
        .map(_clean)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _url(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null || cleaned.startsWith('data:')) {
      return null;
    }
    final uri = Uri.tryParse(cleaned);
    if (uri == null) {
      return null;
    }
    return uri.hasScheme
        ? uri.toString()
        : Uri.parse(_baseUri).resolveUri(uri).toString();
  }

  static String? _imageUrl(dom.Element? image) {
    if (image == null) {
      return null;
    }
    // rd-src/rd-jpg/rd-webp 是站点对首屏之后卡片延迟加载时放置真实封面的属性：
    // 这些卡片初次渲染的 src 是 data: 占位图，真实地址在 data-rd-src / data-rd-jpg / data-rd-webp，
    // 移动端不执行站点脚本，必须自行读取，否则封面上全是黑屏。
    for (final attribute in const [
      'data-rd-src',
      'data-rd-jpg',
      'data-rd-webp',
      'data-webp',
      'data-original',
      'src',
    ]) {
      final value = _url(image.attributes[attribute]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String _collectionFilterId(
    DiscoveryKind kind,
    String pathId,
    String? thumbnailUrl,
  ) {
    final segment = switch (kind) {
      DiscoveryKind.model => 'models',
      DiscoveryKind.category => 'categories',
      _ => null,
    };
    if (segment != null && thumbnailUrl != null) {
      final match = RegExp(
        '/contents/$segment/(\\d+)/',
      ).firstMatch(thumbnailUrl);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return pathId;
  }

  static String? _clean(String? value) {
    final trimmed = value?.replaceAll(_whitespaceRegex, ' ').trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _string(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value?.toString();
  }

  static int? _number(String? value) {
    return int.tryParse((value ?? '').replaceAll(_nonDigitsRegex, ''));
  }

  static int? _compactNumber(String? value) {
    final normalized = _clean(value)?.replaceAll(',', '').toUpperCase();
    if (normalized == null) {
      return null;
    }
    final match = _compactNumberRegex.firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      return null;
    }
    final multiplier = switch (match.group(2)) {
      'K' => 1000,
      'M' => 1000000,
      'B' => 1000000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }
}
