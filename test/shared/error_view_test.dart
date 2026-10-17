import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/services/external_link_service.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flule34/shared/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('null 异常返回 fallback', () {
      expect(friendlyErrorMessage(null), '出错了，请稍后重试');
      expect(friendlyErrorMessage(null, fallback: '默认提示'), '默认提示');
    });

    test('DioException 超时映射', () {
      final req = RequestOptions(path: '/');
      expect(
        friendlyErrorMessage(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        '连接超时，请检查网络设置后重试',
      );
      expect(
        friendlyErrorMessage(
          DioException(requestOptions: req, type: DioExceptionType.sendTimeout),
        ),
        '连接超时，请检查网络设置后重试',
      );
      expect(
        friendlyErrorMessage(
          DioException(
            requestOptions: req,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        '连接超时，请检查网络设置后重试',
      );
    });

    test('DioException 常见 HTTP 状态码映射', () {
      final req = RequestOptions(path: '/');
      expect(
        friendlyErrorMessage(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 403),
          ),
        ),
        '访问受限，可能需要安全验证',
      );
      expect(
        friendlyErrorMessage(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 404),
          ),
        ),
        '请求的内容不存在或已被删除',
      );
      expect(
        friendlyErrorMessage(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 502),
          ),
        ),
        '站点服务暂时不可用，请稍后重试',
      );
      expect(
        friendlyErrorMessage(const HttpStatusException(502)),
        '站点服务暂时不可用，请稍后重试',
      );
      expect(
        friendlyErrorMessage(const HttpStatusException(503)),
        '站点服务暂时不可用，请稍后重试',
      );
      expect(
        friendlyErrorMessage(const HttpStatusException(504)),
        '站点服务暂时不可用，请稍后重试',
      );
    });

    test('常见系统异常映射', () {
      expect(
        friendlyErrorMessage(const SocketException('Failed host lookup')),
        '网络连接异常，请检查网络后重试',
      );
      expect(friendlyErrorMessage(TimeoutException('timed out')), '操作超时，请稍后重试');
      expect(
        friendlyErrorMessage(const FormatException('bad format')),
        '数据解析失败，站点结构可能已更新',
      );
    });

    test('技术性复杂异常与短提示处理', () {
      expect(
        friendlyErrorMessage('SqliteException(1): no such table'),
        '本地数据库读写异常，请重试',
      );
      expect(friendlyErrorMessage('账号中还没有播放列表。'), '账号中还没有播放列表。');
      expect(friendlyErrorMessage(StateError('No element')), '出错了，请稍后重试');
      expect(friendlyErrorMessage('404 Not Found'), '出错了，请稍后重试');
    });

    test('短中文 Exception 消息按历史行为透传，长文本与技术词回落 fallback', () {
      // 已知限制：透传文本不在词表内时，非中文界面会显示中文原文；业务层应优先
      // 使用带类型的领域异常，此分支服务于底层直接抛出短中文提示的历史调用。
      expect(friendlyErrorMessage(Exception('账号已失效，请重新登录。')), '账号已失效，请重新登录。');
      expect(
        friendlyErrorMessage(Exception('账号已失效，请重新登录。'), fallback: '自定义兜底文案'),
        '账号已失效，请重新登录。',
        reason: '短中文消息优先于 fallback',
      );
      expect(
        friendlyErrorMessage(Exception('很长的中文提示' * 20)),
        '出错了，请稍后重试',
        reason: '超过 80 字的中文消息不透视',
      );
      expect(
        friendlyErrorMessage(Exception('中文里混入 error 技术词')),
        '出错了，请稍后重试',
        reason: '含技术词的文本不透视',
      );
      expect(
        friendlyErrorMessage(Exception('账号已失效 token=secret-value')),
        '账号已失效 token=<redacted>',
        reason: '透传前仍做敏感信息脱敏',
      );
    });
  });

  group('AppErrorView', () {
    testWidgets('展示友好错误信息并支持重试点击', (tester) async {
      var retryClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              error: const SocketException('Connection reset'),
              onRetry: () => retryClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('网络连接异常，请检查网络后重试'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(retryClicked, isTrue);
    });

    testWidgets('无重试回调时仅展示错误信息且不渲染重试按钮', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppErrorView(message: '普通错误提示')),
        ),
      );

      expect(find.text('普通错误提示'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('非网络业务异常下渲染 error_outline 图标且点击重试回调被调用', (tester) async {
      var retryClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              error: const ApiException('播放列表不存在'),
              onRetry: () => retryClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('播放列表不存在'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(retryClicked, isTrue);
    });

    test('领域业务异常显式透传并安全脱敏', () {
      expect(
        friendlyErrorMessage(
          const ExternalLinkException(
            '无法打开链接：https://example.com/test?token=secret123',
          ),
        ),
        '无法打开链接：https://example.com/test?token=<redacted>',
      );
      expect(
        friendlyErrorMessage(
          const ApiException('这是一条超过40个字符的详细业务错误提示，用于确认长文本不会被启发式规则误降级为默认错误。'),
        ),
        '这是一条超过40个字符的详细业务错误提示，用于确认长文本不会被启发式规则误降级为默认错误。',
      );
      expect(
        friendlyErrorMessage(
          const DownloadException('下载任务保存失败：user_id: 12345'),
        ),
        '下载任务保存失败：user_id: <redacted>',
      );
      expect(
        friendlyErrorMessage(const LocalLibraryException('已经存在同名的本地库。')),
        '已经存在同名的本地库。',
      );
    });

    test('短错误文本中包含 token 或 user_id 会被安全脱敏', () {
      expect(
        friendlyErrorMessage('登录失败: token=secret123'),
        '登录失败: token=<redacted>',
      );
      expect(
        friendlyErrorMessage('验证失败: user_id: 998877'),
        '验证失败: user_id: <redacted>',
      );
    });

    test('错误文案在各语言下具备整句全量翻译，绝不出现夹生子串混排', () {
      final defaultMsg = friendlyErrorMessage(null);
      final enDefault = localizeUiText(const Locale('en'), defaultMsg);
      final jaDefault = localizeUiText(const Locale('ja'), defaultMsg);
      final koDefault = localizeUiText(const Locale('ko'), defaultMsg);

      expect(enDefault, isNot(contains('出错了')));
      expect(enDefault, isNot(contains('重试')));
      expect(enDefault, 'Something went wrong. Please try again later.');

      expect(jaDefault, isNot(contains('出错了')));
      expect(jaDefault, isNot(contains('Retry')));
      expect(jaDefault, 'エラーが発生しました。しばらくしてから再試行してください。');

      expect(koDefault, isNot(contains('出错了')));
      expect(koDefault, isNot(contains('Retry')));
      expect(koDefault, '오류가 발생했습니다. 잠시 후 다시 시도하세요.');
    });

    test('X1 & X4: 拼接模板递归本地化内嵌参数，且设置页空态文案完整翻译', () {
      final defaultMsg = friendlyErrorMessage(null);
      final rawDiag = '无法生成诊断信息：$defaultMsg';
      final enDiag = localizeUiText(const Locale('en'), rawDiag);
      expect(enDiag, isNot(contains('无法生成诊断信息')));
      expect(enDiag, isNot(contains('出错了')));
      expect(
        enDiag,
        'Unable to generate diagnostic information: Something went wrong. Please try again later.',
      );

      final emptyDiag = localizeUiText(const Locale('en'), '暂无诊断信息。');
      expect(emptyDiag, 'No diagnostic information available.');
      expect(localizeUiText(const Locale('ja'), '暂无诊断信息。'), '診断情報はありません。');
      expect(localizeUiText(const Locale('ko'), '暂无诊断信息。'), '진단 정보가 없습니다.');

      final emptyUpdate = localizeUiText(const Locale('en'), '未获取到更新信息。');
      expect(emptyUpdate, 'No update information obtained.');
      expect(
        localizeUiText(const Locale('ja'), '未获取到更新信息。'),
        '更新情報は取得できませんでした。',
      );
      expect(
        localizeUiText(const Locale('ko'), '未获取到更新信息。'),
        '업데이트 정보를 가져오지 못했습니다.',
      );

      // Y3: 专用模板优先于宽泛模板 {p0}失败：{p1} 匹配
      const channelFail = '保存更新通道失败：网络连接失败，请检查网络是否畅通';
      final enChannelFail = localizeUiText(const Locale('en'), channelFail);
      expect(enChannelFail, startsWith('Failed to save update channel:'));
      expect(enChannelFail, isNot(contains('SaveUpdate')));

      final jaChannelFail = localizeUiText(const Locale('ja'), channelFail);
      expect(jaChannelFail, startsWith('更新チャンネルを保存できませんでした：'));
      expect(jaChannelFail, isNot(contains('は失敗しました')));

      final koChannelFail = localizeUiText(const Locale('ko'), channelFail);
      expect(koChannelFail, startsWith('업데이트 채널을 저장하지 못했습니다:'));
      expect(koChannelFail, isNot(contains('실패:')));
    });

    test('X6: isNetworkError 支持强类型异常与技术错误串识别', () {
      final req = RequestOptions(path: '/');
      expect(
        isNetworkError(const SocketException('failed host lookup')),
        isTrue,
      );
      expect(isNetworkError(TimeoutException('timed out')), isTrue);
      expect(isNetworkError(const HttpException('connection closed')), isTrue);
      expect(
        isNetworkError(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionError,
          ),
        ),
        isTrue,
      );
      expect(
        isNetworkError(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 500),
          ),
        ),
        isFalse,
      );
      expect(isNetworkError(const ApiException('业务错误，参数不合法')), isFalse);
      expect(isNetworkError(const ApiException('连接已失效，请重新登录')), isFalse);
    });

    test('R3-4: ApiException 支持可选 statusCode，HttpStatusException 非空继承', () {
      const apiEx = ApiException('custom message', statusCode: 400);
      expect(apiEx.statusCode, 400);

      const httpEx = HttpStatusException(404);
      expect(httpEx.statusCode, 404);
      expect(httpEx.message, '服务器返回了 HTTP 404。');
    });
  });
}
