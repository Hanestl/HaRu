import 'dart:io';

import 'package:flule34/core/config/app_build_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('User-Agent 版本号与 pubspec.yaml 保持一致', () {
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: '测试应在包根目录运行。');

    final versionLine = pubspec.readAsLinesSync().firstWhere(
      (line) => line.startsWith('version:'),
    );
    final version = versionLine.split(':')[1].trim().split('+').first;

    expect(
      AppBuildConfig.appUserAgent,
      'HaRu Android/$version',
      reason:
          '改动 pubspec.yaml 的 version 后必须同步 AppBuildConfig.appUserAgent，'
          '否则站点会持续收到过期的客户端版本标识。',
    );
  });
}
