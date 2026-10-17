import 'dart:async';
import 'dart:convert';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/hanime1_api.dart';
import '../../core/api/hanime1_parser.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';

/// Hanime 独立网页登录窗口：
/// 直接内嵌 Hanime1 官网登录页，原生支持 Google 一键登录、官网账号密码登录与 Cloudflare 验证。
/// 登录成功后自动截获 Cookie 并同步客户端账号状态。
class HanimeWebLoginPage extends StatefulWidget {
  const HanimeWebLoginPage({super.key, required this.api});

  final Rule34VideoApi api;

  static Future<bool?> show(
    BuildContext context, {
    required Rule34VideoApi api,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => HanimeWebLoginPage(api: api),
      ),
    );
  }

  @override
  State<HanimeWebLoginPage> createState() => _HanimeWebLoginPageState();
}

class _HanimeWebLoginPageState extends State<HanimeWebLoginPage> {
  static const _cookieChannel = MethodChannel(
    'com.hanestl.flule34/webview_cookie',
  );

  late final WebViewController _controller;
  var _progress = 0;
  var _loading = true;
  var _completed = false;
  Timer? _inspectTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(Hanime1Api.browserUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _loading = true;
                _progress = 10;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loading = false;
                _progress = 100;
              });
            }
            unawaited(_inspectLoginSuccess());
          },
        ),
      );

    _inspectTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => unawaited(_inspectLoginSuccess()),
    );

    unawaited(_controller.loadRequest(Uri.parse('https://hanime1.me/login')));
  }

  @override
  void dispose() {
    _inspectTimer?.cancel();
    super.dispose();
  }

  Future<void> _inspectLoginSuccess() async {
    if (!mounted || _completed) return;
    try {
      final currentUrl = await _controller.currentUrl();
      if (currentUrl == null) return;
      final uri = Uri.tryParse(currentUrl);
      if (uri == null || !uri.host.contains('hanime1.me')) return;

      // 读取当前网页 Cookie
      final cookie = await _getNativeCookies(uri);

      // 读取网页 HTML 判断是否已登录
      final htmlRaw = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final html = _decodeJsString(htmlRaw);
      if (html.isEmpty) return;

      final account = HanimePageParser.accountInfo(html);
      if (account != null && account.id.isNotEmpty) {
        _completed = true;
        _inspectTimer?.cancel();

        // 导入会话 Cookie
        if (cookie.isNotEmpty) {
          await widget.api.hanime1Api.importBrowserCookieHeader(cookie);
        } else {
          final jsCookieRaw = await _controller.runJavaScriptReturningResult(
            'document.cookie',
          );
          final jsCookie = _decodeJsString(jsCookieRaw);
          if (jsCookie.isNotEmpty) {
            await widget.api.hanime1Api.importBrowserCookieHeader(jsCookie);
          }
        }

        // 完成客户端认证
        await widget.api.sessionStore.authenticateHanime(account.id);
        unawaited(
          AppLogService.instance.info(
            'Hanime 网页登录成功；用户=${account.displayName}；id=${account.id}',
            component: 'hanime_auth',
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText('欢迎回来，${account.displayName}！已成功登录 Hanime。'),
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // 忽略检查中的瞬时异常
    }
  }

  Future<String> _getNativeCookies(Uri uri) async {
    try {
      final cookieUri = Uri(scheme: uri.scheme, host: uri.host, path: '/');
      return await _cookieChannel.invokeMethod<String>('getCookies', {
            'url': cookieUri.toString(),
          }) ??
          '';
    } catch (_) {
      return '';
    }
  }

  String _decodeJsString(Object? raw) {
    if (raw == null) return '';
    final text = raw.toString();
    if (text.startsWith('"') && text.endsWith('"') && text.length >= 2) {
      try {
        return jsonDecode(text) as String;
      } catch (_) {
        return text.substring(1, text.length - 1);
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Hanime 官网登录'),
        actions: [
          IconButton(
            tooltip: context.uiText('刷新'),
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _loading && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100.0),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: AppText(
                      '支持 Google 一键登入或官网邮箱密码登录，登录完成后会自动返回。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
