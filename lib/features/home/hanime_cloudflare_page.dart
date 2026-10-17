import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/hanime1_api.dart';
import '../../core/api/hanime1_parser.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/services/hanime_cloudflare_coordinator.dart';

/// Cloudflare 辅助验证的卡片式弹窗内容。
///
/// 不再区分"后台/前台"：需要浏览器验证时，由 [HanimeCloudflareGate] 直接
/// 以模态卡片形式展示本组件，用户看到的是可以交互的验证页；验证通过后
/// cookie 导入完成即自动关闭。
final class HanimeCloudflarePage extends StatefulWidget {
  const HanimeCloudflarePage({
    super.key,
    required this.api,
    required this.targetUri,
    required this.onPageReady,
    required this.onCancel,
  });

  final Hanime1Api api;
  final Uri targetUri;
  final ValueChanged<String> onPageReady;
  final VoidCallback onCancel;

  @override
  State<HanimeCloudflarePage> createState() => _HanimeCloudflarePageState();
}

final class _HanimeCloudflarePageState extends State<HanimeCloudflarePage> {
  static const _cookieChannel = MethodChannel(
    'com.hanestl.flule34/webview_cookie',
  );
  static const _inspectionInterval = Duration(milliseconds: 500);
  // 等待提示阈值：超时后仅提示用户可手动重试，不做自动刷新（reload 会
  // 重新触发 Cloudflare 挑战，造成"等不到 cookie → 重刷 → 再挑战"死循环）。
  static const _waitingHintAfter = Duration(seconds: 10);

  late final WebViewController _controller;
  late final Stopwatch _elapsed;
  Timer? _inspectionTimer;
  Uri? _currentUri;
  var _inspectionRunning = false;
  var _completed = false;
  var _challengeLogged = false;
  var _waitingForClearanceLogged = false;
  var _waitingHintLogged = false;
  var _interactionHintLogged = false;
  Duration? _clearanceWaitStartedAt;
  var _progress = 0;
  var _navigationGeneration = 0;
  var _statusText = '正在通过浏览器连接 Hanime…';

  @override
  void initState() {
    super.initState();
    _elapsed = Stopwatch()..start();
    unawaited(
      AppLogService.instance.info(
        '浏览器辅助验证弹窗已显示；路径=${_browserLogPath(widget.targetUri)}',
        component: 'hanime_browser',
      ),
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(Hanime1Api.browserUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted || _completed) return;
            setState(() => _progress = progress);
            if (progress >= 60) {
              unawaited(_inspectPage(trigger: '进度'));
            }
          },
          onPageStarted: (url) {
            if (!mounted || _completed) return;
            _navigationGeneration += 1;
            _currentUri = Uri.tryParse(url);
            unawaited(
              AppLogService.instance.info(
                '浏览器页面开始加载；路径=${_browserLogPath(_currentUri)}',
                component: 'hanime_browser',
              ),
            );
            setState(() {
              _progress = 0;
              _statusText = '正在通过浏览器连接 Hanime…';
            });
          },
          onPageFinished: (url) {
            _currentUri = Uri.tryParse(url);
            if (mounted && !_completed) {
              setState(() => _progress = 100);
            }
            unawaited(_inspectPage(trigger: '页面完成'));
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || _completed) return;
            unawaited(
              AppLogService.instance.warning(
                '浏览器主页面加载失败；错误码=${error.errorCode}；'
                '类型=${error.errorType}；耗时=${_elapsed.elapsedMilliseconds}ms',
                component: 'hanime_browser',
              ),
            );
            if (mounted) {
              setState(() => _statusText = '页面加载失败，可以点重试。');
            }
          },
        ),
      );
    _inspectionTimer = Timer.periodic(
      _inspectionInterval,
      (_) => unawaited(_inspectPage(trigger: '轮询')),
    );
    unawaited(_controller.loadRequest(widget.targetUri));
  }

  @override
  void dispose() {
    _inspectionTimer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  Future<void> _inspectPage({required String trigger}) async {
    if (!mounted || _completed || _inspectionRunning) return;
    _inspectionRunning = true;
    final generation = _navigationGeneration;
    try {
      final currentUrl = await _controller.currentUrl();
      final completedUri = Uri.tryParse(currentUrl ?? '') ?? _currentUri;
      final cookie = await _nativeCookieHeader(widget.targetUri);
      final snapshot = await _readSnapshot();
      if (!mounted || _completed || generation != _navigationGeneration) {
        return;
      }

      final isTargetHost =
          completedUri?.host.toLowerCase() ==
          widget.targetUri.host.toLowerCase();
      final isChallenge = HanimePageParser.isChallenge(
        '<title>${snapshot.title}</title><body>${snapshot.bodyText}</body>',
      );
      final hasClearance = _hasCookie(cookie, 'cf_clearance');

      if (isChallenge && !_challengeLogged) {
        _challengeLogged = true;
        unawaited(
          AppLogService.instance.info(
            '浏览器检测到 Cloudflare 挑战；路径=${_browserLogPath(completedUri)}；'
            '进度=$_progress；交互=${snapshot.hasVisibleInteraction ? '是' : '否'}',
            component: 'hanime_browser',
          ),
        );
      }

      final canComplete = canCompleteHanimeBrowserPage(
        isTargetHost: isTargetHost,
        isChallenge: isChallenge,
        hasDocument: snapshot.hasDocument,
        progress: _progress,
        readyState: snapshot.readyState,
        observedChallenge: _challengeLogged,
        hasClearance: hasClearance,
      );
      if (_challengeLogged &&
          !isChallenge &&
          !hasClearance &&
          snapshot.hasDocument &&
          _progress >= 90 &&
          !_waitingForClearanceLogged) {
        _waitingForClearanceLogged = true;
        _clearanceWaitStartedAt = _elapsed.elapsed;
        unawaited(
          AppLogService.instance.info(
            '浏览器挑战界面已消失，正在等待 cf_clearance；'
            '路径=${_browserLogPath(completedUri)}；进度=$_progress；'
            '耗时=${_elapsed.elapsedMilliseconds}ms',
            component: 'hanime_browser',
          ),
        );
      }
      final clearanceWaitStartedAt = _clearanceWaitStartedAt;
      if (!hasClearance &&
          clearanceWaitStartedAt != null &&
          _elapsed.elapsed - clearanceWaitStartedAt >= _waitingHintAfter &&
          !_waitingHintLogged) {
        _waitingHintLogged = true;
        unawaited(
          AppLogService.instance.info(
            '等待验证结果已超 10 秒，提示用户可手动重试；'
            '耗时=${_elapsed.elapsedMilliseconds}ms',
            component: 'hanime_browser',
          ),
        );
        if (mounted) {
          setState(() => _statusText = '正在等待验证结果…如果长时间无反应，请点重试。');
        }
      }
      if (isChallenge &&
          snapshot.hasVisibleInteraction &&
          !_interactionHintLogged) {
        _interactionHintLogged = true;
        if (mounted) {
          setState(() => _statusText = '请在网页中完成验证，成功后会自动返回。');
        }
      }
      if (canComplete) {
        final result = await _controller.runJavaScriptReturningResult(
          'document.documentElement.outerHTML',
        );
        final html = _decodeJavaScriptString(result);
        if (!mounted ||
            _completed ||
            generation != _navigationGeneration ||
            html.trim().isEmpty ||
            HanimePageParser.isChallenge(html)) {
          return;
        }
        await _importCookies(completedUri ?? widget.targetUri, cookie: cookie);
        if (!mounted || _completed || generation != _navigationGeneration) {
          return;
        }
        _completed = true;
        _inspectionTimer?.cancel();
        unawaited(
          AppLogService.instance.info(
            '浏览器辅助验证完成；触发=$trigger；路径=${_browserLogPath(completedUri)}；'
            '耗时=${_elapsed.elapsedMilliseconds}ms；'
            'Cookie 名称=${cookieHeaderNamesForLog(cookie)}',
            component: 'hanime_browser',
          ),
        );
        widget.onPageReady(html);
        return;
      }
    } on Object catch (error, stackTrace) {
      unawaited(
        AppLogService.instance.error(
          error,
          stackTrace,
          component: 'hanime_browser_inspection',
        ),
      );
      if (mounted) {
        setState(() => _statusText = '无法读取网页内容，可以点重试。');
      }
    } finally {
      _inspectionRunning = false;
    }
  }

  Future<_BrowserPageSnapshot> _readSnapshot() async {
    const script = '''
      (() => {
        const visible = (element) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return rect.width > 4 && rect.height > 4 &&
              style.display !== 'none' && style.visibility !== 'hidden';
        };
        const selectors = [
          'input[type="checkbox"]',
          '[role="checkbox"]',
          'iframe[src*="turnstile"]',
          'iframe[src*="challenges.cloudflare.com"]'
        ];
        const interactive = selectors.some((selector) =>
          Array.from(document.querySelectorAll(selector)).some(visible)
        );
        return JSON.stringify({
          title: document.title || '',
          bodyText: (document.body?.innerText || '').slice(0, 4000),
          readyState: document.readyState || '',
          interactive: interactive,
        });
      })()
    ''';
    final result = await _controller.runJavaScriptReturningResult(script);
    final raw = _decodeJavaScriptString(result);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const _BrowserPageSnapshot();
    }
    return _BrowserPageSnapshot(
      title: decoded['title']?.toString() ?? '',
      bodyText: decoded['bodyText']?.toString() ?? '',
      readyState: decoded['readyState']?.toString() ?? '',
      hasVisibleInteraction: decoded['interactive'] == true,
    );
  }

  void _retryReload() {
    if (!mounted || _completed) return;
    unawaited(
      AppLogService.instance.info(
        '用户手动重试刷新验证页面；路径=${_browserLogPath(_currentUri)}；'
        '耗时=${_elapsed.elapsedMilliseconds}ms',
        component: 'hanime_browser',
      ),
    );
    _clearanceWaitStartedAt = _elapsed.elapsed;
    _waitingForClearanceLogged = false;
    _waitingHintLogged = false;
    unawaited(_controller.reload());
  }

  Future<void> _importCookies(
    Uri completedUri, {
    required String cookie,
  }) async {
    try {
      var resolvedCookie = cookie;
      if (resolvedCookie.isEmpty) {
        final result = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        resolvedCookie = _decodeJavaScriptString(result);
      }
      await widget.api.importBrowserCookieHeader(resolvedCookie);
    } on Object catch (error, stackTrace) {
      unawaited(
        AppLogService.instance.error(
          error,
          stackTrace,
          component: 'hanime_cookie',
        ),
      );
      // Cookie 同步只是后续请求的优化，当前正文仍可直接返回解析器。
    }
  }

  Future<String> _nativeCookieHeader(Uri uri) async {
    try {
      final cookieUri = Uri(scheme: uri.scheme, host: uri.host, path: '/');
      return await _cookieChannel.invokeMethod<String>('getCookies', {
            'url': cookieUri.toString(),
          }) ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.92 + 0.08 * value, child: child),
          );
        },
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 16,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth * 0.92, 420.0);
              final height = math.min(constraints.maxHeight * 0.66, 500.0);
              return SizedBox(
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppText(
                              'Hanime 验证',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: context.uiText('取消'),
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: Colors.white,
                            child: WebViewWidget(controller: _controller),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              _statusText,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _retryReload,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const AppText('重试'),
                          ),
                        ],
                      ),
                    ),
                    // hanime1.me 对日本 IP 执行地区屏蔽（防版权），提示用户换节点。
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.language,
                            size: 16,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppText(
                              '日本 IP 可能无法通过验证',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _BrowserPageSnapshot {
  const _BrowserPageSnapshot({
    this.title = '',
    this.bodyText = '',
    this.readyState = '',
    this.hasVisibleInteraction = false,
  });

  final String title;
  final String bodyText;
  final String readyState;
  final bool hasVisibleInteraction;

  bool get hasDocument =>
      title.trim().isNotEmpty ||
      bodyText.trim().isNotEmpty ||
      readyState == 'interactive' ||
      readyState == 'complete';
}

bool _hasCookie(String header, String name) {
  for (final part in header.split(';')) {
    final separator = part.indexOf('=');
    final candidate = (separator < 0 ? part : part.substring(0, separator))
        .trim();
    if (candidate == name) return true;
  }
  return false;
}

String _decodeJavaScriptString(Object value) {
  if (value is! String) return value.toString();
  final normalized = value.trim();
  if (normalized.length >= 2 &&
      normalized.startsWith('"') &&
      normalized.endsWith('"')) {
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is String) return decoded;
    } on FormatException {
      return value;
    }
  }
  return value;
}

String _browserLogPath(Uri? uri) {
  final path = uri?.path.trim();
  return path == null || path.isEmpty ? '/' : path;
}
