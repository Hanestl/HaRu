import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_build_config.dart';
import '../domain/app_settings.dart';

enum AppUpdateStatus { unconfigured, upToDate, updateAvailable, failed }

final class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.pageUri,
    required this.prerelease,
    this.publishedAt,
    this.apkUri,
    this.apkSha256,
    this.apkSizeBytes,
    this.notes,
  });

  final String version;
  final String title;
  final Uri pageUri;
  final bool prerelease;
  final DateTime? publishedAt;
  final Uri? apkUri;
  final String? apkSha256;
  final int? apkSizeBytes;
  final String? notes;

  /// 是否具备「一键更新」所需的安装包信息。
  bool get supportsOneTapUpdate => apkUri != null;
}

final class AppUpdateResult {
  const AppUpdateResult({
    required this.status,
    required this.currentVersion,
    this.release,
    this.message,
  });

  final AppUpdateStatus status;
  final String currentVersion;
  final AppRelease? release;
  final String? message;
}

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef AbiLoader = Future<List<String>> Function();

final class AppUpdateService {
  AppUpdateService({
    Dio? client,
    PackageInfoLoader? packageInfoLoader,
    AbiLoader? abiLoader,
    Uri? updateApiUri,
    Uri? releaseFeedUri,
  }) : _client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: const {
                 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'HaRu Android update checker',
               },
             ),
           ),
       _ownsClient = client == null,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _abiLoader = abiLoader ?? _loadSupportedAbis,
       _updateApiUri = updateApiUri ?? AppBuildConfig.updateApiUri,
       _releaseFeedUri = releaseFeedUri ?? _defaultReleaseFeedUri();

  final Dio _client;
  final bool _ownsClient;
  final PackageInfoLoader _packageInfoLoader;
  final AbiLoader _abiLoader;
  final Uri? _updateApiUri;
  final Uri? _releaseFeedUri;

  Uri? get configuredSource => _updateApiUri;

  void close() {
    if (_ownsClient) {
      _client.close(force: true);
    }
  }

  Future<AppUpdateResult> check(UpdateChannel channel) async {
    final packageInfo = await _packageInfoLoader();
    final currentVersion = packageInfo.version;
    final source = _updateApiUri;
    if (source == null) {
      return AppUpdateResult(
        status: AppUpdateStatus.unconfigured,
        currentVersion: currentVersion,
        message: '此构建未配置 GitHub Releases 更新源。',
      );
    }

    List<String> supportedAbis;
    try {
      supportedAbis = await _abiLoader();
    } catch (_) {
      supportedAbis = const [];
    }

    try {
      final response = await _client.getUri<Object?>(
        source,
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      );
      final release = _selectRelease(response.data, channel, supportedAbis);
      if (release == null) {
        return AppUpdateResult(
          status: AppUpdateStatus.failed,
          currentVersion: currentVersion,
          message: '更新源没有可用的 Android Release。',
        );
      }
      final resolved = await _attachApkFromSums(release, supportedAbis);
      final available = compareVersions(resolved.version, currentVersion) > 0;
      return AppUpdateResult(
        status: available
            ? AppUpdateStatus.updateAvailable
            : AppUpdateStatus.upToDate,
        currentVersion: currentVersion,
        release: resolved,
        message: available ? '发现新版本 ${resolved.version}。' : '当前已是最新版本。',
      );
    } catch (error) {
      final feed = _releaseFeedUri;
      if (feed != null) {
        try {
          final feedRelease = await _checkReleaseFeed(feed, channel);
          if (feedRelease != null) {
            final release = await _attachApkFromSums(
              feedRelease,
              supportedAbis,
            );
            final available =
                compareVersions(release.version, currentVersion) > 0;
            return AppUpdateResult(
              status: available
                  ? AppUpdateStatus.updateAvailable
                  : AppUpdateStatus.upToDate,
              currentVersion: currentVersion,
              release: release,
              message: available ? '发现新版本 ${release.version}。' : '当前已是最新版本。',
            );
          }
        } catch (_) {
          // GitHub API 与 Releases Feed 都失败时统一返回原始检查错误。
        }
      }
      return AppUpdateResult(
        status: AppUpdateStatus.failed,
        currentVersion: currentVersion,
        message: _failureMessage(error),
      );
    }
  }

  Future<AppRelease?> _checkReleaseFeed(
    Uri source,
    UpdateChannel channel,
  ) async {
    final response = await _client.getUri<String>(
      source,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'Accept': 'application/atom+xml,application/xml'},
      ),
    );
    final body = response.data ?? '';
    for (final match in RegExp(
      r'<entry\b[^>]*>(.*?)</entry>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(body)) {
      final entry = match.group(1) ?? '';
      final pageValue = RegExp(
        r'''<link\b[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(entry)?.group(1);
      final pageUri = _httpsUri(pageValue);
      if (pageUri == null) {
        continue;
      }
      final rawVersion = pageUri.pathSegments.isEmpty
          ? null
          : pageUri.pathSegments.last;
      if (rawVersion == null || rawVersion.isEmpty) {
        continue;
      }
      final version = rawVersion.replaceFirst(RegExp(r'^[vV]'), '');
      final title = _xmlText(entry, 'title') ?? rawVersion;
      final prerelease =
          version.contains('-') ||
          RegExp(
            r'\b(?:alpha|beta|preview|rc|pre-release)\b',
            caseSensitive: false,
          ).hasMatch(title);
      if (channel == UpdateChannel.stable && prerelease) {
        continue;
      }
      return AppRelease(
        version: version,
        title: title,
        pageUri: pageUri,
        prerelease: prerelease,
        publishedAt: DateTime.tryParse(_xmlText(entry, 'updated') ?? ''),
      );
    }
    return null;
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index++) {
      final difference = leftParts[index] - rightParts[index];
      if (difference != 0) {
        return difference.sign;
      }
    }
    return 0;
  }

  AppRelease? _selectRelease(
    Object? data,
    UpdateChannel channel,
    List<String> supportedAbis,
  ) {
    final candidates = switch (data) {
      List<Object?> values => values,
      Map<Object?, Object?> value => <Object?>[value],
      _ => const <Object?>[],
    };
    for (final candidate in candidates) {
      if (candidate is! Map) {
        continue;
      }
      final release = _parseRelease(candidate, supportedAbis);
      if (release == null || candidate['draft'] == true) {
        continue;
      }
      if (channel == UpdateChannel.stable && release.prerelease) {
        continue;
      }
      return release;
    }
    return null;
  }

  AppRelease? _parseRelease(
    Map<Object?, Object?> data,
    List<String> supportedAbis,
  ) {
    final rawVersion = data['tag_name']?.toString().trim();
    final pageUri = _httpsUri(data['html_url']);
    if (rawVersion == null || rawVersion.isEmpty || pageUri == null) {
      return null;
    }
    final apkAssets = <({String name, Uri uri, String? sha256, int? size})>[];
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map>()) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final candidate = _httpsUri(asset['browser_download_url']);
        if (name.endsWith('.apk') && candidate != null) {
          apkAssets.add((
            name: name,
            uri: candidate,
            sha256: _assetSha256(asset['digest']),
            size: _assetSize(asset['size']),
          ));
        }
      }
    }
    final apk = _selectApk(apkAssets, supportedAbis);
    return AppRelease(
      version: rawVersion.replaceFirst(RegExp(r'^[vV]'), ''),
      title: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : rawVersion,
      pageUri: pageUri,
      prerelease: data['prerelease'] == true,
      publishedAt: DateTime.tryParse(data['published_at']?.toString() ?? ''),
      apkUri: apk?.uri,
      apkSha256: apk?.sha256,
      apkSizeBytes: apk?.size,
      notes: data['body']?.toString().trim(),
    );
  }

  /// GitHub API 被限流时，从 Release 页的 `SHA256SUMS.txt` 补全安装包直链。
  ///
  /// 该文件与 APK 放在同一个 `releases/download/<tag>/` 目录下，
  /// 走 github.com 静态资源域名，不受未认证 API 每小时 60 次的限制。
  Future<AppRelease> _attachApkFromSums(
    AppRelease release,
    List<String> supportedAbis,
  ) async {
    if (release.apkUri != null) {
      return release;
    }
    final base = _downloadsBaseUri(release);
    if (base == null) {
      return release;
    }
    try {
      final response = await _client.getUri<String>(
        base.resolve('SHA256SUMS.txt'),
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'text/plain'},
        ),
      );
      final apk = _selectApk(
        _parseSums(response.data ?? '', base),
        supportedAbis,
      );
      if (apk == null) {
        return release;
      }
      return AppRelease(
        version: release.version,
        title: release.title,
        pageUri: release.pageUri,
        prerelease: release.prerelease,
        publishedAt: release.publishedAt,
        apkUri: apk.uri,
        apkSha256: apk.sha256,
        apkSizeBytes: apk.size,
        notes: release.notes,
      );
    } on Object {
      // 缺少校验文件时保持「打开发布页」的回退行为。
      return release;
    }
  }

  /// 把 `releases/tag/<tag>` 改写成 `releases/download/<tag>/`。
  static Uri? _downloadsBaseUri(AppRelease release) {
    final path = release.pageUri.path;
    const marker = '/tag/';
    final index = path.lastIndexOf(marker);
    if (index < 0) {
      return null;
    }
    final tag = path.substring(index + marker.length);
    final basePath = '${path.substring(0, index)}/download/$tag';
    return release.pageUri.replace(
      path: basePath.endsWith('/') ? basePath : '$basePath/',
    );
  }

  /// 解析 `sha256sum` 格式的输出：`<64 位十六进制>  ./文件名.apk`。
  List<({String name, Uri uri, String? sha256, int? size})> _parseSums(
    String body,
    Uri base,
  ) {
    final assets = <({String name, Uri uri, String? sha256, int? size})>[];
    final pattern = RegExp(
      r'^([0-9a-fA-F]{64})\s+\*?(.+\.apk)$',
      caseSensitive: false,
    );
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) {
        continue;
      }
      final name = match.group(2)!.trim().replaceFirst(RegExp(r'^\./'), '');
      final uri = _httpsUri(base.resolve(name).toString());
      if (uri == null) {
        continue;
      }
      assets.add((
        name: name,
        uri: uri,
        sha256: match.group(1)!.toLowerCase(),
        size: null,
      ));
    }
    return assets;
  }

  ({String name, Uri uri, String? sha256, int? size})? _selectApk(
    List<({String name, Uri uri, String? sha256, int? size})> assets,
    List<String> supportedAbis,
  ) {
    for (final abi in supportedAbis) {
      final normalized = abi.toLowerCase();
      for (final asset in assets) {
        if (asset.name.toLowerCase().contains(normalized)) {
          return asset;
        }
      }
    }
    for (final asset in assets) {
      if (asset.name.toLowerCase().contains('universal')) {
        return asset;
      }
    }
    return assets.firstOrNull;
  }

  /// 解析 GitHub Release asset 的 `digest` 字段（形如 `sha256:<hex>`）。
  static String? _assetSha256(Object? value) {
    final digest = value?.toString().trim().toLowerCase() ?? '';
    const prefix = 'sha256:';
    if (!digest.startsWith(prefix)) {
      return null;
    }
    final hash = digest.substring(prefix.length);
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ? hash : null;
  }

  static int? _assetSize(Object? value) {
    final size = value is num ? value.toInt() : int.tryParse('$value');
    return size != null && size > 0 ? size : null;
  }

  static Future<List<String>> _loadSupportedAbis() async {
    return (await DeviceInfoPlugin().androidInfo).supportedAbis;
  }

  static Uri? _defaultReleaseFeedUri() {
    final repository = AppBuildConfig.repositoryUri;
    if (repository == null) {
      return null;
    }
    final path = repository.path.endsWith('/')
        ? '${repository.path}releases.atom'
        : '${repository.path}/releases.atom';
    return repository.replace(path: path, query: null, fragment: null);
  }

  static String _failureMessage(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 429) {
        return 'GitHub 暂时拒绝了更新请求，请稍后重试或更换网络。';
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '检查更新超时，请稍后重试。',
        DioExceptionType.connectionError => '无法连接 GitHub，请检查网络后重试。',
        _ => '暂时无法检查更新，请稍后重试。',
      };
    }
    return '暂时无法检查更新，请稍后重试。';
  }

  static String? _xmlText(String source, String tag) {
    final value = RegExp(
      '<${RegExp.escape(tag)}\\b[^>]*>(.*?)</${RegExp.escape(tag)}>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source)?.group(1);
    if (value == null) {
      return null;
    }
    final cleaned = value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static List<int> _versionParts(String version) {
    final core = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[-+]'))
        .first;
    final values = core.split('.').take(3).map((part) {
      return int.tryParse(RegExp(r'^\d+').firstMatch(part)?.group(0) ?? '') ??
          0;
    }).toList();
    return List<int>.generate(
      3,
      (index) => index < values.length ? values[index] : 0,
    );
  }

  Uri? _httpsUri(Object? value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }
}
