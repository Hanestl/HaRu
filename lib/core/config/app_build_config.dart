abstract final class AppBuildConfig {
  /// 站点请求统一使用的 User-Agent。
  ///
  /// 版本号必须与 pubspec.yaml 的 version 保持一致。这里不读运行时版本号，
  /// 因为 HTTP 适配器需要在同步的构造阶段就拿到它；漂移由
  /// test/core/config/app_build_config_test.dart 在 CI 中拦截。
  static const appUserAgent = 'HaRu Android/2.6.1';

  static const updateApiUrl = String.fromEnvironment('FLULE34_UPDATE_API_URL');
  static const repositoryUrl = String.fromEnvironment('FLULE34_REPOSITORY_URL');
  static const flutterVersion = String.fromEnvironment(
    'FLULE34_FLUTTER_VERSION',
    defaultValue: '未注入',
  );
  static const gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: '未注入',
  );
  static const buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: '未注入',
  );

  static Uri? get updateApiUri => _httpsUri(updateApiUrl);
  static Uri? get repositoryUri => _httpsUri(repositoryUrl);

  static Uri? _httpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
