import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/account_models.dart';
import '../models/hanime_comment_models.dart';
import '../models/hanime_library_models.dart';
import '../models/hanime_playlist_models.dart';
import '../models/video_models.dart';

final class HanimeCloudflareException implements Exception {
  const HanimeCloudflareException({this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'Hanime 页面受到 Cloudflare 限制，浏览器辅助访问未完成。';
}

/// 浏览器当前文档相对本次请求目标的关系。
enum HanimeDocumentStatus {
  /// 就是本次请求的目标文档。
  target,

  /// 仍是 Cloudflare 挑战页。
  challenge,

  /// 同域名下的另一个目标（另一个视频、另一个查询、上一页残留）。
  otherTarget,

  /// 被重定向到登录页。
  login,

  /// 无法识别、缺业务结构或无法解析。
  unknown,
}

/// Hanime 的页面类型。
enum HanimeDocumentKind {
  home,
  search,
  watch,
  playlist,
  user,
  login,
  subscriptions,
  comments,
  unknown,
}

/// 一次浏览器文档检查的结果。
final class HanimeDocumentInspection {
  const HanimeDocumentInspection({
    required this.status,
    required this.kind,
    required this.hasBusinessContent,
    this.identityUri,
    this.reason = '',
  });

  final HanimeDocumentStatus status;
  final HanimeDocumentKind kind;
  final bool hasBusinessContent;

  /// 文档自己声明的站点 URL（canonical / og:url），缺失为 null。
  final Uri? identityUri;

  /// 判定理由，仅用于日志与测试断言。
  final String reason;

  /// 该文档能否作为本次请求的响应正文。
  bool get isTarget => status == HanimeDocumentStatus.target;

  /// 是否需要用户登录（不能当成业务正文）。
  bool get requiresLogin => status == HanimeDocumentStatus.login;
}

final class HanimePageParser {
  const HanimePageParser._();

  static const _siteId = 'hanime1';

  static bool isChallenge(String source) {
    final lower = source.toLowerCase();
    if (!lower.contains('just a moment') &&
        !lower.contains('cloudflare') &&
        !lower.contains('attention required') &&
        !lower.contains('checking your browser') &&
        !lower.contains('verify you are human') &&
        !lower.contains('you have been blocked') &&
        !lower.contains('cf-turnstile-response')) {
      return false;
    }

    final document = html_parser.parse(source);
    final title = document.querySelector('title')?.text.toLowerCase() ?? '';
    final text = document.body?.text.toLowerCase() ?? '';
    return title.contains('just a moment') ||
        title.contains('cloudflare') ||
        title.contains('attention required') ||
        text.contains('checking your browser') ||
        text.contains('verify you are human') ||
        text.contains('you have been blocked') ||
        document.querySelector('input[name="cf-turnstile-response"]') != null;
  }

  /// 浏览器当前文档与本次请求目标之间的关系。
  ///
  /// 只按字符串 `contains` 判断"像 Hanime 页面"是不够的：错误页里带一句业务类名、
  /// 脚本里出现 `const selector = 'horizontal-card'`、或者停在另一个视频的详情页，
  /// 都能骗过字符串判定，把错误的正文交给解析器（日志里的 0 条结果与串号就来自这里）。
  /// 这里改成真实 DOM 判定：文档身份取 `link[rel=canonical]` / `meta[property=og:url]`，
  /// 页面类型按结构识别，再与本次请求的目标 URI 逐项比对。
  static HanimeDocumentInspection inspectBrowserDocument({
    required String source,
    required Uri targetUri,
  }) {
    if (source.trim().isEmpty) {
      return const HanimeDocumentInspection(
        status: HanimeDocumentStatus.unknown,
        kind: HanimeDocumentKind.unknown,
        hasBusinessContent: false,
        reason: '正文为空',
      );
    }
    if (isChallenge(source)) {
      return const HanimeDocumentInspection(
        status: HanimeDocumentStatus.challenge,
        kind: HanimeDocumentKind.unknown,
        hasBusinessContent: false,
        reason: 'Cloudflare 挑战页',
      );
    }
    final dom.Document document;
    try {
      document = html_parser.parse(source);
    } on Object {
      return const HanimeDocumentInspection(
        status: HanimeDocumentStatus.unknown,
        kind: HanimeDocumentKind.unknown,
        hasBusinessContent: false,
        reason: 'HTML 无法解析',
      );
    }
    final identity = _canonicalHanimeUri(document);
    final kind = _documentKind(document, identity);
    final hasBusinessContent = _hasBusinessStructure(document, kind);
    if (kind == HanimeDocumentKind.unknown) {
      return HanimeDocumentInspection(
        status: HanimeDocumentStatus.unknown,
        kind: kind,
        identityUri: identity,
        hasBusinessContent: false,
        reason: '无法识别页面类型',
      );
    }
    if (!hasBusinessContent) {
      return HanimeDocumentInspection(
        status: HanimeDocumentStatus.unknown,
        kind: kind,
        identityUri: identity,
        hasBusinessContent: false,
        reason: '缺少业务结构',
      );
    }
    final targetKind = _kindForTarget(targetUri);
    if (kind == HanimeDocumentKind.login &&
        targetKind != HanimeDocumentKind.login) {
      return HanimeDocumentInspection(
        status: HanimeDocumentStatus.login,
        kind: kind,
        identityUri: identity,
        hasBusinessContent: true,
        reason: '被重定向到登录页',
      );
    }
    if (!_matchesTarget(identity, targetUri, kind)) {
      return HanimeDocumentInspection(
        status: HanimeDocumentStatus.otherTarget,
        kind: kind,
        identityUri: identity,
        hasBusinessContent: true,
        reason: '文档身份与请求目标不一致',
      );
    }
    return HanimeDocumentInspection(
      status: HanimeDocumentStatus.target,
      kind: kind,
      identityUri: identity,
      hasBusinessContent: true,
      reason: '目标文档',
    );
  }

  /// 文档自己声明的站点 URL（canonical 优先，og:url 兜底）。
  static Uri? _canonicalHanimeUri(dom.Document document) {
    final candidates = <String?>[
      document.querySelector('link[rel="canonical"]')?.attributes['href'],
      document.querySelector('meta[property="og:url"]')?.attributes['content'],
    ];
    for (final candidate in candidates) {
      final uri = _normalizeHanimeUri(candidate);
      if (uri != null) return uri;
    }
    return null;
  }

  /// 把（可能带存档前缀的）URL 规范成站点自身的 URL。
  ///
  /// 测试夹具来自 Wayback，canonical 会写成
  /// `http://web.archive.org/web/<ts>/https://hanime1.me/watch?v=404990`，
  /// 因此这里取最后一个 `http` 起始位置，只保留 hanime1.me 自身那一段。
  static Uri? _normalizeHanimeUri(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    final marker = value.indexOf('hanime1.me');
    if (marker < 0) return null;
    final schemeStart = value.lastIndexOf('http', marker);
    if (schemeStart >= 0) value = value.substring(schemeStart);
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host != 'hanime1.me' && !host.endsWith('.hanime1.me')) return null;
    return uri;
  }

  /// 页面类型：优先用文档自己声明的 canonical 路径，缺失时退回结构判定。
  static HanimeDocumentKind _documentKind(
    dom.Document document,
    Uri? identity,
  ) {
    final path = identity?.path ?? '';
    final fromPath = _kindForPath(path);
    if (fromPath != HanimeDocumentKind.unknown) return fromPath;
    if (_hasEmailPasswordForm(document)) return HanimeDocumentKind.login;
    if (document.querySelector('video#player') != null ||
        document.querySelector('#shareBtn-title') != null) {
      return HanimeDocumentKind.watch;
    }
    if (document.querySelector('#home-rows-wrapper') != null) {
      return HanimeDocumentKind.search;
    }
    if (_hasBusinessStructure(document, HanimeDocumentKind.home)) {
      return HanimeDocumentKind.home;
    }
    return HanimeDocumentKind.unknown;
  }

  static HanimeDocumentKind _kindForTarget(Uri targetUri) =>
      _kindForPath(targetUri.path);

  static HanimeDocumentKind _kindForPath(String path) {
    if (path.startsWith('/user/')) return HanimeDocumentKind.user;
    switch (path) {
      case '':
      case '/':
        return HanimeDocumentKind.home;
      case '/login':
        return HanimeDocumentKind.login;
      case '/search':
        return HanimeDocumentKind.search;
      case '/watch':
        return HanimeDocumentKind.watch;
      case '/playlist':
        return HanimeDocumentKind.playlist;
      case '/subscriptions':
        return HanimeDocumentKind.subscriptions;
      case '/loadReplies':
        return HanimeDocumentKind.comments;
    }
    if (path.contains('comment')) return HanimeDocumentKind.comments;
    return HanimeDocumentKind.unknown;
  }

  /// 页面是否渲染出了该类页面应有的业务结构。
  ///
  /// 这里判的是"容器在不在"，不是"卡片有几张"：搜索无结果、频道为空都是合法
  /// 空态，容器仍然存在；而 403 文本页、错误页、空白壳连容器都没有。
  static bool _hasBusinessStructure(
    dom.Document document,
    HanimeDocumentKind kind,
  ) {
    switch (kind) {
      case HanimeDocumentKind.home:
      case HanimeDocumentKind.search:
        return _anyRenderable(document, const [
          '.home-rows-videos-wrapper',
          '#home-rows-wrapper',
        ]);
      case HanimeDocumentKind.watch:
        return _anyRenderable(document, const [
          'video#player',
          '#shareBtn-title',
          '.video-description-panel',
          '#video-playlist-wrapper',
        ]);
      case HanimeDocumentKind.playlist:
        return _anyRenderable(document, const [
          '#playlist-scroll',
          '.playlist-videos-wrapper',
          '.hover-video-playlist',
          '#video-playlist-wrapper',
        ]);
      case HanimeDocumentKind.user:
        return _anyRenderable(document, const [
          '#user-modal-name',
          '.user-tab-item-wrapper',
          '.content-padding-new',
        ]);
      case HanimeDocumentKind.login:
        return _hasEmailPasswordForm(document);
      case HanimeDocumentKind.subscriptions:
        return _anyRenderable(document, const [
          '.subscriptions-nav',
          '.subscriptions-artist-card',
        ]);
      case HanimeDocumentKind.comments:
        return _anyRenderable(document, const [
          '#comment-like-form-wrapper',
          '[id^="reply-start-"]',
        ]);
      case HanimeDocumentKind.unknown:
        return false;
    }
  }

  static bool _hasEmailPasswordForm(dom.Document document) =>
      document.querySelector('input[name="email"]') != null &&
      document.querySelector('input[name="password"]') != null;

  static bool _anyRenderable(dom.Document document, List<String> selectors) {
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector)) {
        if (_isRenderable(element)) return true;
      }
    }
    return false;
  }

  /// 排除藏在 `<template>`、`hidden`、`display:none` 里的模板结构。
  static bool _isRenderable(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      if (current.localName == 'template') return false;
      if (current.attributes.containsKey('hidden')) return false;
      final style = (current.attributes['style'] ?? '')
          .replaceAll(' ', '')
          .toLowerCase();
      if (style.contains('display:none') ||
          style.contains('visibility:hidden')) {
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  /// 文档身份是否就是本次请求的目标。
  ///
  /// 详情页比 `v`、播放列表比 `list`、搜索页比整组查询参数（含页码）；首页只比
  /// 路径。身份缺失（没有 canonical/og:url）一律不算命中——那正是"页面还在加载"
  /// 或"被中间层改写"的形态。
  static bool _matchesTarget(
    Uri? identity,
    Uri targetUri,
    HanimeDocumentKind kind,
  ) {
    if (identity == null) return false;
    final identityPath = identity.path.isEmpty ? '/' : identity.path;
    final targetPath = targetUri.path.isEmpty ? '/' : targetUri.path;
    if (identityPath != targetPath) return false;
    switch (kind) {
      case HanimeDocumentKind.watch:
        final target = _param(targetUri, 'v');
        return target != null &&
            target.isNotEmpty &&
            _param(identity, 'v') == target;
      case HanimeDocumentKind.playlist:
        final target = _param(targetUri, 'list');
        return target != null &&
            target.isNotEmpty &&
            _param(identity, 'list') == target;
      case HanimeDocumentKind.search:
        return _searchSignature(identity) == _searchSignature(targetUri);
      case HanimeDocumentKind.home:
      case HanimeDocumentKind.user:
      case HanimeDocumentKind.login:
      case HanimeDocumentKind.subscriptions:
      case HanimeDocumentKind.comments:
      case HanimeDocumentKind.unknown:
        return true;
    }
  }

  static String? _param(Uri uri, String name) {
    final value = uri.queryParameters[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _searchSignature(Uri uri) {
    const keys = <String>[
      'query',
      'page',
      'genre',
      'sort',
      'date',
      'duration',
      'broad',
    ];
    final signature = <String, Object>{};
    for (final key in keys) {
      final value = _param(uri, key) ?? (key == 'page' ? '1' : null);
      if (value == null) continue;
      signature[key] = value;
    }
    // PHP 数组参数可能以重复 tags[] 或 tags[0]/tags[1] 形式出现。
    // 筛选是集合：比较全部值，忽略顺序与重复项，不能只取某一个值。
    for (final name in const ['tags', 'brands']) {
      final values = <String>{};
      final indexedKey = RegExp(
        '^$name'
        r'\[\d*\]$',
      );
      for (final entry in uri.queryParametersAll.entries) {
        if (!indexedKey.hasMatch(entry.key)) continue;
        values.addAll(
          entry.value
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      signature[name] = values.toList()..sort();
    }
    // JSON 保留键值边界，避免 query 中的 '&page=' 与真正的参数碰撞。
    return jsonEncode(signature);
  }

  static final _csrfMetaRegex = RegExp(
    r'''<meta\s+[^>]*name=["']csrf-token["'][^>]*content=["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final _csrfMetaRegexAlt = RegExp(
    r'''<meta\s+[^>]*content=["']([^"']+)["'][^>]*name=["']csrf-token["']''',
    caseSensitive: false,
  );
  static final _inputTokenRegex = RegExp(
    r'''<input\s+[^>]*name=["']_token["'][^>]*value=["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final _inputTokenRegexAlt = RegExp(
    r'''<input\s+[^>]*value=["']([^"']+)["'][^>]*name=["']_token["']''',
    caseSensitive: false,
  );

  /// 提取登录表单的 CSRF 令牌：优先使用正则快速提取避免构建整棵 DOM 树，
  /// 兜底使用 DOM 解析保证完全兼容。
  static String? loginToken(String source) {
    final metaMatch =
        _csrfMetaRegex.firstMatch(source) ??
        _csrfMetaRegexAlt.firstMatch(source);
    if (metaMatch != null) {
      final token = metaMatch.group(1)?.trim();
      if (token != null && token.isNotEmpty) return token;
    }
    final inputMatch =
        _inputTokenRegex.firstMatch(source) ??
        _inputTokenRegexAlt.firstMatch(source);
    if (inputMatch != null) {
      final token = inputMatch.group(1)?.trim();
      if (token != null && token.isNotEmpty) return token;
    }

    final document = html_parser.parse(source);
    final meta = document
        .querySelector('meta[name="csrf-token"]')
        ?.attributes['content'];
    if (meta != null && meta.trim().isNotEmpty) return meta.trim();
    final input = document
        .querySelector('input[name="_token"]')
        ?.attributes['value'];
    return input?.trim();
  }

  /// 从首页解析当前登录账号（锚点与 Han1meViewer 一致）：
  /// 头像 `#user-modal-dp-wrapper img`、用户名 `#user-modal-name`、
  /// 用户 ID `#user-modal-trigger` href 的 `/user/(\d+)`。
  /// 未登录返回 null。
  static HanimeAccountProfile? accountInfo(String source) {
    final document = html_parser.parse(source);
    final avatar = document
        .querySelector('#user-modal-dp-wrapper img')
        ?.attributes['src'];
    final name = _clean(document.querySelector('#user-modal-name')?.text);
    final trigger =
        document.querySelector('#user-modal-trigger')?.attributes['href'] ?? '';
    final match = RegExp(r'/user/(\d+)').firstMatch(trigger);
    if (match == null || name == null || name.isEmpty) return null;
    return HanimeAccountProfile(
      id: match.group(1)!,
      displayName: name,
      avatarUrl: avatar,
    );
  }

  /// 从用户主页解析订阅数与视频数（如 `74,192 位订阅者 • 160 个视频`）。
  static HanimeAccountProfile? userPageStats(
    String source, {
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) {
    final document = html_parser.parse(source);
    final text = document.body?.text ?? '';
    final subscribers = RegExp(r'([\d,]+)\s*位订阅者').firstMatch(text);
    final videos = RegExp(r'•\s*([\d,]+)\s*个视频').firstMatch(text);
    return HanimeAccountProfile(
      id: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      subscriberCount: _parseCount(subscribers?.group(1)),
      videoCount: _parseCount(videos?.group(1)),
    );
  }

  static HanimeAccountEditData? accountEditData(String source) {
    final document = html_parser.parse(source);
    final token = loginToken(source);
    final name = document
        .querySelector('input[name="name"]')
        ?.attributes['value'];
    final email = document
        .querySelector('input[name="email"]')
        ?.attributes['value'];
    if (token == null || name == null || email == null) return null;
    return HanimeAccountEditData(
      token: token,
      name: name.trim(),
      email: email.trim(),
      avatarUrl: _url(
        document.querySelector('img#playlist-avatar')?.attributes['src'],
      ),
    );
  }

  static List<String> formErrors(String source) {
    final document = html_parser.parse(source);
    final result = <String>{};
    for (final element in document.querySelectorAll(
      '.alert-danger, .invalid-feedback, .help-block, .form-error',
    )) {
      final message = _clean(element.text);
      if (message != null) result.add(message);
    }
    return result.toList(growable: false);
  }

  static int? _parseCount(String? value) {
    if (value == null || value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    final parsed = int.tryParse(digits);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// 解析用户播放列表页（真实页面验证：`div.user-tab-item-wrapper` 卡片、
  /// 链接 href 含 `list=`、标题 `div.title`、封面 `img`、数量 `div.stat-item`）。
  static List<HanimePlaylist> playlists(String source) {
    final document = html_parser.parse(source);
    final result = <String, HanimePlaylist>{};
    for (final wrapper in document.querySelectorAll('.user-tab-item-wrapper')) {
      final link = wrapper.querySelector('a[href*="list="]');
      final href = link?.attributes['href'] ?? '';
      final uri = Uri.tryParse(href);
      final listCode = uri?.queryParameters['list']?.trim();
      if (listCode == null || listCode.isEmpty) continue;
      final title = _clean(wrapper.querySelector('.title')?.text);
      if (title == null || title.isEmpty) continue;
      final image = wrapper.querySelector('img');
      final cover = image?.attributes['src'];
      final stat = _clean(wrapper.querySelector('.stat-item')?.text ?? '');
      result[listCode] = HanimePlaylist(
        listCode: listCode,
        title: title,
        videoCount: _parseCount(stat),
        coverUrl: cover,
      );
    }
    return result.values.toList(growable: false);
  }

  /// 解析订阅页中的作者导航与更新视频。作者只保留展示和搜索所需字段，
  /// 避免依赖站点没有稳定公开的作者 ID。
  static HanimeSubscriptionPage subscriptionPage(String source) {
    final document = html_parser.parse(source);
    final artists = <String, HanimeSubscriptionArtist>{};
    final root = document.querySelector('.subscriptions-nav');
    for (final card
        in root?.querySelectorAll('.subscriptions-artist-card') ??
            const <dom.Element>[]) {
      final name = _clean(card.querySelector('.card-mobile-title')?.text);
      if (name == null || name.isEmpty) continue;
      final images = card.querySelectorAll('img');
      final image = images.length > 1 ? images[1] : images.firstOrNull;
      artists[name] = HanimeSubscriptionArtist(
        name: name,
        avatarUrl: _url(
          image?.attributes['data-src'] ?? image?.attributes['src'],
        ),
      );
    }
    final videosRoot = document.querySelector('.content-padding-new');
    return HanimeSubscriptionPage(
      artists: List.unmodifiable(artists.values),
      videos: videosRoot == null
          ? const []
          : List.unmodifiable(videoList(videosRoot.outerHtml)),
    );
  }

  /// 解析评论接口返回（`{"comments":"<html片段>"}` 或 `{"replies":"<html片段>"}`）。
  static List<HanimeComment> comments(String source) {
    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(source);
      if (value is Map<String, dynamic>) decoded = value;
    } on FormatException {
      decoded = null;
    }
    final fragment =
        decoded?['comments']?.toString() ?? decoded?['replies']?.toString();
    if (fragment == null || fragment.isEmpty) return const [];

    final document = html_parser.parse(fragment);
    final result = <HanimeComment>[];
    for (final wrapper in document.querySelectorAll(
      '#comment-like-form-wrapper',
    )) {
      final comment = _commentFromLikeWrapper(wrapper);
      if (comment == null) continue;
      result.add(comment);
    }
    // loadReplies 把每条回复拆成「内容区 + 操作区」两个相邻子节点，
    // 所有回复共同放在一个 reply-start 容器里。
    if (result.isEmpty) {
      for (final root in document.querySelectorAll('[id^="reply-start-"]')) {
        final children = root.children;
        for (var index = 0; index < children.length; index += 2) {
          final basic = children[index];
          final actions = index + 1 < children.length
              ? children[index + 1]
              : null;
          final comment = _commentFromReplyPair(basic, actions);
          if (comment != null) result.add(comment);
        }
      }
    }
    return result;
  }

  static HanimeComment? _commentFromLikeWrapper(dom.Element wrapper) {
    // 浏览器实测结构：每条评论 = <a>头像</a> + <div class="report-btn-wrapper">
    // （用户名/日期/内容/举报）+ <div id="comment-like-form-wrapper">（点赞/回复）。
    // 三者是同级兄弟；从点赞区取前一个兄弟容器即可，避免向上遍历
    // 误归并到第一条评论（全同名 bug 的根因）。
    dom.Element? info;
    var sibling = wrapper.previousElementSibling;
    while (sibling != null) {
      final className = sibling.className;
      if (className.contains('report-btn-wrapper')) {
        info = sibling;
        break;
      }
      sibling = sibling.previousElementSibling;
    }
    if (info == null) return null;
    final texts = info.querySelectorAll('.comment-index-text');
    final nameDate = _clean(texts.isNotEmpty ? texts.first.text : '');
    final content = _clean(texts.length > 1 ? texts[1].text : '');
    if ((nameDate == null || nameDate.isEmpty) &&
        (content == null || content.isEmpty)) {
      return null;
    }
    // 头像在信息容器的前一个兄弟（<a><img class="img-circle"></a>）。
    final avatar = info.previousElementSibling
        ?.querySelector('img')
        ?.attributes['src'];
    final dateMatch = nameDate == null
        ? null
        : RegExp(r'(\S+)$').firstMatch(nameDate);
    final replyBtn = wrapper.querySelector('.load-replies-btn');
    final commentId =
        replyBtn?.attributes['data-commentid'] ??
        wrapper.attributes['id']?.replaceFirst('reply-section-wrapper-', '');
    final likeText = _clean(
      wrapper.querySelector('span[style*="color: darkgray"]')?.text ?? '',
    );
    final formState = _commentFormState(wrapper);
    final report = info.querySelector('[data-reportable-id]');
    return HanimeComment(
      id: formState.foreignId ?? commentId ?? '',
      username: _clean(nameDate?.replaceFirst(RegExp(r'\s+.*$'), '')) ?? '',
      content: content ?? '',
      avatarUrl: avatar,
      dateLabel: dateMatch?.group(1),
      likeCount: _parseCount(likeText) ?? 0,
      replyCount: _parseReplyCount(replyBtn?.text ?? '') ?? 0,
      liked: formState.liked,
      disliked: formState.disliked,
      likesCount: formState.likesCount,
      likesSum: formState.likesSum,
      reportableType:
          report?.attributes['data-reportable-type']?.trim() ?? 'comment',
    );
  }

  static HanimeComment? _commentFromReplyPair(
    dom.Element basic,
    dom.Element? actions,
  ) {
    final texts = basic.querySelectorAll('.comment-index-text');
    final nameDate = _clean(texts.isNotEmpty ? texts.first.text : '');
    final content = _clean(texts.length > 1 ? texts[1].text : '');
    if (nameDate == null && content == null) return null;
    final avatar = basic.querySelector('img')?.attributes['src'];
    final report = basic.querySelector('[data-reportable-id]');
    final formState = _commentFormState(actions ?? basic);
    final likeText = actions
        ?.querySelectorAll('span[style]')
        .map((item) => _clean(item.text))
        .whereType<String>()
        .firstWhere((text) => int.tryParse(text) != null, orElse: () => '');
    final dateMatch = nameDate == null
        ? null
        : RegExp(r'(\S+)$').firstMatch(nameDate);
    return HanimeComment(
      id: formState.foreignId ?? report?.attributes['data-reportable-id'] ?? '',
      username: _clean(nameDate?.replaceFirst(RegExp(r'\s+.*$'), '')) ?? '',
      content: content ?? '',
      avatarUrl: avatar,
      dateLabel: dateMatch?.group(1),
      likeCount: _parseCount(likeText ?? '') ?? formState.likesSum,
      isReply: true,
      liked: formState.liked,
      disliked: formState.disliked,
      likesCount: formState.likesCount,
      likesSum: formState.likesSum,
      reportableType:
          report?.attributes['data-reportable-type']?.trim() ?? 'reply',
    );
  }

  static ({
    String? foreignId,
    bool liked,
    bool disliked,
    int likesCount,
    int likesSum,
  })
  _commentFormState(dom.Element root) => (
    foreignId: root
        .querySelector('input[name="foreign_id"], #foreign_id')
        ?.attributes['value']
        ?.trim(),
    liked: _elementCheckedValue(root, 'like-comment-status'),
    disliked: _elementCheckedValue(root, 'unlike-comment-status'),
    likesCount: _elementInputInt(root, 'comment-likes-count'),
    likesSum: _elementInputInt(root, 'comment-likes-sum'),
  );

  static bool _elementCheckedValue(dom.Element root, String name) {
    final value = root
        .querySelector('input[name="$name"]')
        ?.attributes['value']
        ?.trim()
        .toLowerCase();
    return value == '1' || value == 'true';
  }

  static int _elementInputInt(dom.Element root, String name) =>
      int.tryParse(
        root
                .querySelector('input[name="$name"]')
                ?.attributes['value']
                ?.replaceAll(',', '') ??
            '',
      ) ??
      0;

  static int? _parseReplyCount(String text) {
    final match = RegExp(r'(\d+)\s*則回覆').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static List<VideoItem> videoList(String source) {
    final document = html_parser.parse(source);
    return _videoListFromNode(document);
  }

  static List<VideoItem> _videoListFromNode(dom.Node node) {
    final result = <String, VideoItem>{};
    for (final link in _videoLinks(node)) {
      final video = _videoFromLink(link);
      if (video == null) continue;
      final existing = result[video.id];
      result[video.id] = existing == null
          ? video
          : _mergeVideoItems(existing, video);
    }
    return result.values.toList(growable: false);
  }

  static List<HanimeHomeSection> homeSections(String source) {
    final document = html_parser.parse(source);
    final sections = <HanimeHomeSection>[];
    for (final wrapper in document.querySelectorAll(
      '.home-rows-videos-wrapper',
    )) {
      final items = _videoListFromNode(wrapper);
      if (items.isEmpty) continue;
      final title = _sectionTitle(wrapper);
      if (title == null || title.isEmpty) continue;
      sections.add(
        HanimeHomeSection(title: title, items: List.unmodifiable(items)),
      );
    }
    return List.unmodifiable(sections);
  }

  static VideoDetails videoDetails({
    required String source,
    required VideoItem fallback,
  }) {
    final document = html_parser.parse(source);
    final title =
        _clean(
          document.querySelector('#shareBtn-title')?.text ??
              document.querySelector('h1')?.text ??
              document
                  .querySelector('meta[property="og:title"]')
                  ?.attributes['content'],
        ) ??
        fallback.title;
    final descriptionParts = _descriptionParts(document);
    final tags = _metadataLinks(document, 'tag');
    final tagCounts = _tagCounts(document);
    final categories = _textList(document, [
      '.video-info .category',
      '.video-info .genre',
      '[class*="category"] a',
      'a[href*="/search?genre="]',
    ]);
    final models = _metadataLinks(document, 'artist');
    final artistId = _inputValue(document, 'subscribe-artist-id');
    final metadata = <VideoMetadataItem>[
      // Hanime1 没有独立的集合页：分类走 genre 筛选，标签/艺术家走文本搜索。
      // path 仅作语义占位（详情页点击行为按 kind 走搜索页），
      // 不使用 rule34video 的 /categories/、/tags/ 等路径。
      ...categories.map(
        (value) => VideoMetadataItem(
          id: artistId ?? value,
          title: value,
          path: '/search?genre=${Uri.encodeQueryComponent(value)}',
          kind: DiscoveryKind.category,
        ),
      ),
      ...tags.map(
        (value) => VideoMetadataItem(
          id: value,
          title: value,
          path: '/search?query=${Uri.encodeQueryComponent(value)}',
          kind: DiscoveryKind.tag,
          count: tagCounts[value],
        ),
      ),
      ...models.map(
        (value) => VideoMetadataItem(
          id: value,
          title: value,
          path: '/search?query=${Uri.encodeQueryComponent(value)}',
          kind: DiscoveryKind.model,
        ),
      ),
    ];
    final likes = _inputInt(document, 'likes-count');
    final dislikes = _inputInt(document, 'unlikes-count');
    final ratingVotes = likes + dislikes;
    final playlistWrapper = document.querySelector('#video-playlist-wrapper');
    final playlistRoot =
        document.querySelector('#playlist-scroll, .hover-video-playlist') ??
        playlistWrapper;
    final seriesVideos = playlistRoot == null
        ? const <VideoItem>[]
        : videoList(playlistRoot.outerHtml).toList(growable: false);
    final seriesTitle = _clean(
      (playlistWrapper ?? playlistRoot)?.querySelector('h4')?.text,
    );
    final relatedRoot = document.querySelector('#related-tabcontent');
    final relatedSource = relatedRoot?.outerHtml ?? source;
    final seriesIds = seriesVideos.map((item) => item.id).toSet();
    final video = fallback.copyWith(
      title: title,
      thumbnailUrl:
          _url(
            document
                    .querySelector('meta[property="og:image"]')
                    ?.attributes['content'] ??
                document.querySelector('video#player')?.attributes['poster'],
          ) ??
          fallback.thumbnailUrl,
      views: descriptionParts.views ?? fallback.views,
      publishedLabel:
          descriptionParts.publishedLabel ?? fallback.publishedLabel,
      rating: ratingVotes > 0 ? ((likes * 100) / ratingVotes).round() : null,
      ratingVotes: ratingVotes > 0 ? ratingVotes : null,
      isFavorite: null,
    );
    return VideoDetails(
      video: video,
      description: descriptionParts.description,
      descriptionTitle: descriptionParts.title,
      categories: List.unmodifiable(categories),
      tags: List.unmodifiable(tags),
      models: List.unmodifiable(models),
      sources: _sources(document),
      isFavorite: false,
      isSaved: _isSaved(document),
      metadataItems: List.unmodifiable(metadata),
      relatedVideos: videoList(relatedSource)
          .where((item) => item.id != fallback.id)
          .where((item) => !seriesIds.contains(item.id))
          .toList(growable: false),
      seriesTitle: seriesTitle,
      seriesVideos: List.unmodifiable(seriesVideos),
      ratingVotes: ratingVotes > 0 ? ratingVotes : null,
      uploader: _uploader(document),
      playlistIds: _playlistIds(document),
      hanimeLiked: _checkedValue(document, 'like-status'),
      hanimeDisliked: _checkedValue(document, 'unlike-status'),
      hanimeLikes: likes,
      hanimeDislikes: dislikes,
      isUploaderSubscribed:
          _inputValue(document, 'subscribe-status')?.trim() == '1',
    );
  }

  static ({bool liked, bool disliked, int likes, int dislikes})
  videoRatingState(String source) {
    final document = html_parser.parse(source);
    return (
      liked: _checkedValue(document, 'like-status'),
      disliked: _checkedValue(document, 'unlike-status'),
      likes: _inputInt(document, 'likes-count'),
      dislikes: _inputInt(document, 'unlikes-count'),
    );
  }

  static String? subscriptionArtistId(String source) {
    final document = html_parser.parse(source);
    final value = _inputValue(document, 'subscribe-artist-id')?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Iterable<dom.Element> _videoLinks(dom.Node node) {
    final List<dom.Element> candidateLinks;
    if (node is dom.Document) {
      candidateLinks = node.querySelectorAll('a[href]');
    } else if (node is dom.Element) {
      candidateLinks = node.querySelectorAll('a[href]');
    } else {
      candidateLinks = const [];
    }
    final links = <dom.Element>[];
    for (final link in candidateLinks) {
      final href = link.attributes['href']?.trim() ?? '';
      final uri = Uri.tryParse(href);
      final videoId = uri?.queryParameters['v']?.trim();
      if (videoId == null || videoId.isEmpty || !href.contains('watch')) {
        continue;
      }
      if (!links.contains(link)) {
        links.add(link);
      }
    }
    return links;
  }

  static VideoItem? _videoFromLink(dom.Element link) {
    final href = link.attributes['href'];
    final uri = Uri.tryParse(href ?? '');
    final id = uri?.queryParameters['v']?.trim();
    if (id == null || id.isEmpty) return null;
    final card = _cardAncestor(link);
    // 标题等字段优先从链接内部取：genre 等搜索页的 `<a>` 直接平铺在
    // 公共容器 `home-rows-videos-wrapper` 下，向上爬的 card 会命中
    // 公共容器导致所有卡片取到第一个标题（全同名）。link 内部取不到
    // 时再退到 card 兜底，兼容首页 sections 等结构。
    final image = link.querySelector('img') ?? card.querySelector('img');
    final title =
        _clean(
          link.querySelector('.home-rows-videos-title')?.text ??
              link.querySelector('.title')?.text ??
              link.querySelector('.video-title')?.text ??
              card.attributes['title'] ??
              card.querySelector('.home-rows-videos-title')?.text ??
              card.querySelector('.title')?.text ??
              card.querySelector('.video-title')?.text ??
              link.attributes['title'] ??
              image?.attributes['alt'] ??
              link.text,
        ) ??
        '未命名视频';
    final stats =
        (link.querySelectorAll('.stats-container .stat-item').isNotEmpty
                ? link.querySelectorAll('.stats-container .stat-item')
                : card.querySelectorAll('.stats-container .stat-item'))
            .toList(growable: false);
    final legacyStats =
        link.querySelector('.meta-stats') ?? card.querySelector('.meta-stats');
    final meta = _videoCardMeta(link, card);
    return VideoItem(
      id: id,
      title: title,
      slug: id,
      siteId: _siteId,
      thumbnailUrl: _url(
        image?.attributes['data-src'] ?? image?.attributes['src'],
      ),
      publishedLabel: meta.published,
      duration: _clean(
        (link.querySelector('.duration') ?? card.querySelector('.duration'))
            ?.text,
      ),
      views: _number(
        stats.length > 1
            ? stats[1].text
            : (link.querySelector('.video-views') ??
                          card.querySelector('.video-views'))
                      ?.text ??
                  (legacyStats?.children.isEmpty == true
                      ? legacyStats?.text
                      : null),
      ),
      rating: _number(
        stats.isNotEmpty
            ? stats.first.text
            : RegExp(r'(\d{1,3})\s*%').firstMatch(link.text)?.group(1) ??
                  RegExp(r'(\d{1,3})\s*%').firstMatch(card.text)?.group(1),
      ),
      creatorLabel: meta.creator,
    );
  }

  static ({String? creator, String? published}) _videoCardMeta(
    dom.Element link,
    dom.Element card,
  ) {
    String? creator;
    String? published;
    for (final root in <dom.Element>[link, card]) {
      creator ??= _clean(
        root
            .querySelector(
              '.meta-author a, a.card-mobile-user, .subtitle a, '
              '.video-meta-data a',
            )
            ?.text,
      );
      published ??= _clean(
        root
            .querySelector(
              '.meta-published, .video-date, .subtitle-time, '
              '.meta-stats span, time',
            )
            ?.text,
      );
      for (final selector in const ['.subtitle', '.video-meta-data']) {
        final text = _clean(root.querySelector(selector)?.text);
        if (text == null) continue;
        final parts = text
            .split(RegExp(r'\s*[•·]\s*'))
            .map(_clean)
            .whereType<String>()
            .toList(growable: false);
        creator ??= parts.firstOrNull;
        if (parts.length > 1) published ??= parts[1];
      }
    }
    return (creator: creator, published: published);
  }

  static List<VideoSource> _sources(dom.Document document) {
    final result = <String, VideoSource>{};
    for (final source in document.querySelectorAll('video source')) {
      final url = _mediaUrl(
        source.attributes['src'] ?? source.attributes['data-src'],
      );
      if (url == null) continue;
      final label = _quality(
        source.attributes['size'] ?? source.attributes['label'] ?? url,
      );
      result[label] = VideoSource(
        label: label,
        url: url,
        isHd: label != '480p',
      );
    }
    for (final video in document.querySelectorAll(
      'video[src], video[data-src]',
    )) {
      final url = _mediaUrl(
        video.attributes['src'] ?? video.attributes['data-src'],
      );
      if (url == null) continue;
      final label = _quality(
        video.attributes['data-quality'] ??
            video.attributes['height'] ??
            video.attributes['label'] ??
            url,
      );
      result.putIfAbsent(
        label,
        () => VideoSource(label: label, url: url, isHd: label != '480p'),
      );
    }
    for (final element in document.querySelectorAll(
      '[data-url], a[href*=".mp4"]',
    )) {
      final url = _mediaUrl(
        element.attributes['data-url'] ?? element.attributes['href'],
      );
      if (url == null) continue;
      final label = _quality(
        element.attributes['data-quality'] ?? element.text,
      );
      result.putIfAbsent(
        label,
        () => VideoSource(label: label, url: url, isHd: label != '480p'),
      );
    }
    final sorted = result.values.toList()
      ..sort(
        (a, b) => _qualityNumber(b.label).compareTo(_qualityNumber(a.label)),
      );
    return List.unmodifiable(sorted);
  }

  static dom.Element _cardAncestor(dom.Element link) {
    dom.Element? current = link;
    dom.Element? fallback;
    while (current != null) {
      final classes = current.classes
          .map((value) => value.toLowerCase())
          .toSet();
      if (current.localName == 'article' ||
          classes.contains('video-item-container') ||
          classes.contains('playlist-video-card')) {
        return current;
      }
      if (fallback == null &&
          classes.any(
            (value) => value.contains('video') || value.contains('card'),
          )) {
        fallback = current;
      }
      current = current.parent;
    }
    return fallback ?? link;
  }

  static String? _sectionTitle(dom.Element wrapper) {
    dom.Element? scope = wrapper;
    while (scope != null) {
      var sibling = scope.previousElementSibling;
      for (var index = 0; index < 4 && sibling != null; index += 1) {
        final heading = sibling.localName == 'h3'
            ? sibling
            : sibling.querySelector('h3');
        if (heading != null) {
          return _clean(
            heading.text
                .replaceAll('查看更多', '')
                .replaceAll('arrow_forward_ios', ''),
          );
        }
        sibling = sibling.previousElementSibling;
      }
      scope = scope.parent;
    }
    return null;
  }

  static VideoItem _mergeVideoItems(VideoItem first, VideoItem second) {
    return VideoItem(
      id: first.id,
      title: first.title == '未命名视频' ? second.title : first.title,
      slug: first.slug,
      siteId: first.siteId,
      thumbnailUrl: first.thumbnailUrl ?? second.thumbnailUrl,
      previewUrl: first.previewUrl ?? second.previewUrl,
      duration: first.duration ?? second.duration,
      publishedLabel: first.publishedLabel ?? second.publishedLabel,
      views: first.views ?? second.views,
      rating: first.rating ?? second.rating,
      ratingVotes: first.ratingVotes ?? second.ratingVotes,
      isFavorite: first.isFavorite ?? second.isFavorite,
    );
  }

  static List<String> _metadataLinks(dom.Document document, String kind) {
    final selectors = kind == 'tag'
        ? <String>[
            'a[href*="/tags/"]',
            '.video-tags a',
            '[class*="tag"] a',
            'a[href*="tags%5B"]',
          ]
        : <String>[
            'a[href*="/artist"]',
            'a[href*="/brand"]',
            '.video-author a',
            '#video-artist-name',
          ];
    final values = _textList(document, selectors);
    if (kind != 'tag') return values;
    return values
        .map(
          // 标签链接文本形如「巨乳 (2)」，括号内是用户添加计数而非标签本体，
          // 解析时剥掉避免「NTR（7）」整个被搜索。
          (value) => value
              .replaceFirst(RegExp(r'\(\s*\d+\s*\)\s*$'), '')
              .replaceFirst(RegExp(r'^#\s*'), '')
              .trim(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// 提取 hanime 标签的用户添加计数（`<span style="color:#aaa">(N)</span>`）。
  static Map<String, int> _tagCounts(dom.Document document) {
    final result = <String, int>{};
    for (final link in document.querySelectorAll('a[href*="tags%5B"]')) {
      final title = _clean(
        link.text,
      )?.replaceFirst(RegExp(r'\(\s*\d+\s*\)\s*$'), '').trim();
      if (title == null || title.isEmpty) continue;
      final countSpan = link.querySelector(
        'span[style*="color: #aaa"], span[style*="color:#aaa"]',
      );
      final countText = _clean(countSpan?.text ?? '');
      final match = RegExp(r'(\d+)').firstMatch(countText ?? '');
      final count = match == null ? null : int.tryParse(match.group(1)!);
      if (count != null && count > 0) {
        result[title] = count;
      }
    }
    return result;
  }

  static List<String> _textList(dom.Document document, List<String> selectors) {
    final result = <String>{};
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector)) {
        // 排除站点全局导航（.main-nav/nav）里的分类链接，避免把导航栏的
        // 全部 genre（里番/泡面番/3DCG...）当成视频自身分类。
        if (_isInNavigation(element)) continue;
        if (element.attributes['href']?.trim().isEmpty ?? true) continue;
        if (element.querySelector(
              '.material-icons, .material-icons-outlined',
            ) !=
            null) {
          continue;
        }
        final value = _clean(element.text);
        if (value != null && value.length <= 120) result.add(value);
      }
    }
    return result.toList(growable: false);
  }

  /// 判断元素是否位于站点全局导航内（package:html 无 closest，手动向上遍历）。
  static bool _isInNavigation(dom.Element element) {
    var current = element.parent;
    while (current != null) {
      final className = current.className;
      if (className.contains('main-nav') || current.localName == 'nav') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  static UploaderSummary? _uploader(dom.Document document) {
    final link = document.querySelector(
      '.video-caption-text a[href*="/user/"], '
      '.video-description-panel a[href*="/user/"]',
    );
    final name = _clean(link?.text);
    if (name == null) return null;
    final href = link?.attributes['href'] ?? '';
    final userId = RegExp(r'/user/(\d+)').firstMatch(href)?.group(1);
    return UploaderSummary(id: userId ?? name, name: name);
  }

  static ({
    String? description,
    String? title,
    int? views,
    String? publishedLabel,
  })
  _descriptionParts(dom.Document document) {
    dom.Element? panel = document.querySelector('.video-description-panel');
    if (panel == null || panel.querySelector('.video-caption-text') == null) {
      for (final candidate in document.querySelectorAll(
        '.video-details-wrapper',
      )) {
        if (candidate.querySelector('.video-caption-text') != null) {
          panel = candidate;
          break;
        }
      }
    }
    final caption = panel?.querySelector('.video-caption-text');
    final uploaderName = _clean(
      caption?.querySelector('a[href*="/user/"]')?.text,
    );
    var description = _clean(caption?.text);
    if (description != null && uploaderName != null) {
      description = _clean(
        description.replaceFirst(
          RegExp(
            '^由\\s*${RegExp.escape(uploaderName)}\\s*上[傳传]\\s*'
            '(?:[·•・]\\s*)?',
          ),
          '',
        ),
      );
    }
    description ??= _clean(
      document.querySelector('.description')?.text ??
          document
              .querySelector('meta[name="description"]')
              ?.attributes['content'],
    );

    String? metadataText;
    for (final element in document.querySelectorAll('.video-details-wrapper')) {
      final text = _clean(element.text);
      if (text != null && (text.contains('觀看次數') || text.contains('观看次数'))) {
        metadataText = text;
        break;
      }
    }
    if (metadataText == null && panel != null) {
      for (final child in panel.children) {
        final text = _clean(child.text);
        if (text != null && (text.contains('觀看次數') || text.contains('观看次数'))) {
          metadataText = text;
          break;
        }
      }
    }
    final match = RegExp(
      r'(?:觀看次數|观看次数)\s*[:：]\s*([\d,.]+\s*[KMB萬万亿億]?)\s*次?\s*(\d{4}-\d{2}-\d{2})',
      caseSensitive: false,
    ).firstMatch(metadataText ?? '');

    String? title = _clean(caption?.previousElementSibling?.text);
    if (title == null && panel != null) {
      for (final child in panel.children) {
        if (identical(child, caption)) continue;
        final text = _clean(child.text);
        if (text == null || text.contains('觀看次數') || text.contains('观看次数')) {
          continue;
        }
        title = text;
        break;
      }
    }
    return (
      description: description,
      title: title,
      views: _number(match?.group(1)),
      publishedLabel: _clean(match?.group(2)),
    );
  }

  static Set<String> _playlistIds(dom.Document document) => document
      .querySelectorAll(
        '.playlist-checkbox-wrapper input[checked], #playlist-save-checkbox input[checked]',
      )
      .map((input) => input.attributes['id']?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty && id != 'save')
      .toSet();

  static String? _inputValue(dom.Document document, String name) =>
      document.querySelector('input[name="$name"]')?.attributes['value'];

  static bool _checkedValue(dom.Document document, String name) {
    final value = _inputValue(document, name)?.trim().toLowerCase();
    return value == '1' || value == 'true';
  }

  static int _inputInt(dom.Document document, String name) =>
      int.tryParse(_inputValue(document, name)?.replaceAll(',', '') ?? '') ?? 0;

  static bool _isSaved(dom.Document document) {
    final checkbox = document.querySelector(
      '#playlist-save-checkbox input, input#save',
    );
    return checkbox?.attributes.containsKey('checked') ?? false;
  }

  static bool videoSavedState(String source) =>
      _isSaved(html_parser.parse(source));

  static bool videoSubscriptionState(String source) =>
      _inputValue(html_parser.parse(source), 'subscribe-status')?.trim() == '1';

  static String? _clean(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _url(String? value) {
    final normalized = _clean(value);
    if (normalized == null || normalized.startsWith('javascript:')) return null;
    if (normalized.startsWith('//')) return 'https:$normalized';
    if (normalized.startsWith('/')) return 'https://hanime1.me$normalized';
    return normalized;
  }

  static String? _mediaUrl(String? value) {
    final normalized = _url(value);
    if (normalized == null) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return normalized;
  }

  static int? _number(String? value) {
    final match = RegExp(
      r'(\d[\d,.]*\s*[KMB萬万亿億]?)',
      caseSensitive: false,
    ).firstMatch(value ?? '');
    if (match == null) return null;
    final raw = match
        .group(1)!
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .toUpperCase();
    final suffix = raw.isEmpty ? '' : raw.substring(raw.length - 1);
    final multiplier = switch (suffix) {
      'K' => 1000,
      'M' => 1000000,
      'B' => 1000000000,
      '萬' || '万' => 10000,
      '亿' || '億' => 100000000,
      _ => 1,
    };
    final numeric = double.tryParse(raw.replaceAll(RegExp(r'[KMB萬万亿億]$'), ''));
    return numeric == null ? null : (numeric * multiplier).round();
  }

  static String _quality(String value) {
    final match = RegExp(
      r'(2160|1440|1080|720|480)p?',
      caseSensitive: false,
    ).firstMatch(value);
    return '${match?.group(1) ?? '720'}p';
  }

  static int _qualityNumber(String value) =>
      int.tryParse(value.replaceAll('p', '')) ?? 0;
}
