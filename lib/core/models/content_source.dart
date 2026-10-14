enum ContentSite {
  rule34video(
    id: 'rule34video',
    label: 'Rule34Video',
    baseUrl: 'https://rule34video.com',
    capabilities: ContentSiteCapabilities(
      accountFavorites: true,
      accountPlaylists: true,
      subscriptions: true,
      metadataCollections: true,
      uploaderProfiles: true,
      advancedFilters: true,
      videoPreviews: true,
    ),
  ),
  hanime1(
    id: 'hanime1',
    label: 'Hanime',
    baseUrl: 'https://hanime1.me',
    capabilities: ContentSiteCapabilities(videoPreviews: true),
  ),
  // 91porn 只提供匿名浏览与直接 MP4 播放，没有任何账号级能力，
  // 因此能力位全部保持 false：现有 UI 会据此隐藏收藏、播放列表、
  // 订阅、筛选和预览等入口，无需为此删除界面。
  porn91(
    id: 'porn91',
    label: '91porn',
    // 裸域 9p47q.com 不可直接列取内容（实测返回 0 条目）；
    // 91porn.com 与 w0200~w0209.9p47q.com 是同一后端的品牌域。
    baseUrl: 'https://91porn.com',
    capabilities: ContentSiteCapabilities(),
  );

  const ContentSite({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.capabilities,
  });

  final String id;
  final String label;
  final String baseUrl;
  final ContentSiteCapabilities capabilities;

  Uri get origin => Uri.parse('$baseUrl/');

  static ContentSite fromId(String? value) {
    for (final site in values) {
      if (site.id == value) return site;
    }
    return ContentSite.rule34video;
  }
}

final class ContentSiteCapabilities {
  const ContentSiteCapabilities({
    this.accountFavorites = false,
    this.accountPlaylists = false,
    this.subscriptions = false,
    this.metadataCollections = false,
    this.uploaderProfiles = false,
    this.advancedFilters = false,
    this.videoPreviews = false,
  });

  final bool accountFavorites;
  final bool accountPlaylists;
  final bool subscriptions;
  final bool metadataCollections;
  final bool uploaderProfiles;
  final bool advancedFilters;
  final bool videoPreviews;
}

extension ContentSiteHeaders on ContentSite {
  Map<String, String> mediaHeaders({String? cookie}) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      'Referer': '$baseUrl/',
      'Accept': '*/*',
    };
    if (cookie != null && cookie.trim().isNotEmpty) {
      headers['Cookie'] = cookie.trim();
    }
    return headers;
  }
}
