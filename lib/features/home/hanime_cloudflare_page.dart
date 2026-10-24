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

  /// 完整 HTML 的探测节流间隔。
  ///
  /// 文档身份校验必须基于完整 DOM（要排除脚本/注释里的类名），而整页正文
  /// 可能有几百 KB，因此不能跟着 500ms 巡检走。
  static const _probeInterval = Duration(milliseconds: 800);

  late final WebViewController _controller;
  late final Stopwatch _elapsed;
  Timer? _inspectionTimer;
  Uri? _currentUri;
  var _inspectionRunning = false;
  var _completed = false;
  var _challengeLogged = false;
  var _challengeClearedLogged = false;
  var _mainFrameFailureLogged = false;
  var _documentMismatchLogged = false;
  var _waitingHintLogged = false;
  var _interactionHintLogged = false;
  Duration? _documentWaitStartedAt;
  Duration? _lastProbeAt;
  var _progress = 0;
  var _navigationGeneration = 0;

  /// 本次导航是否真的走到了 onPageFinished。
  ///
  /// 这是"验证已完成"的硬前提：WebView 刚创建时停在空白页，其
  /// `document.readyState` 同样是 `complete`，而 CookieManager 里还留着上一次
  /// 会话的 `cf_clearance`。若只看 cookie 或进度，巡检定时器 500ms 首拍就会
  /// 判定"验证完成"，弹窗立刻自己关掉——这就是"闪出后不等加载就消失"。
  var _navigationFinished = false;

  /// 主文档加载失败（onWebResourceError 且 isForMainFrame）。
  ///
  /// 错误页同样会触发 onPageFinished，若不单独记录，失败页会被当成"导航已完成"
  /// 继续参与完成判定。
  var _mainFrameLoadFailed = false;

  /// 当前文档与请求目标不一致时只记一次日志，避免 500ms 巡检刷屏。
  var _targetMissLogged = false;
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
            _navigationFinished = false;
            // 新导航开始：上一页的所有判定与提示状态都必须失效，否则上一页的
            // "已看到挑战""已失败""已不一致"会串到这一页。
            _mainFrameLoadFailed = false;
            _challengeLogged = false;
            _challengeClearedLogged = false;
            _mainFrameFailureLogged = false;
            _targetMissLogged = false;
            _documentMismatchLogged = false;
            _interactionHintLogged = false;
            _waitingHintLogged = false;
            _documentWaitStartedAt = null;
            _lastProbeAt = null;
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
            // onPageFinished 对错误页、空白页同样会回调，因此这里只记录
            // "本次导航已结束"，不再无条件把进度置 100 当成验证完成信号。
            _navigationFinished = true;
            if (mounted && !_completed) {
              setState(() => _progress = 100);
            }
            unawaited(_inspectPage(trigger: '页面完成'));
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || _completed) return;
            // 主文档失败必须进入明确状态：错误页也有标题、也会走 onPageFinished，
            // 只写日志会让"页面加载失败"继续被当成"验证进行中/已完成"。
            _mainFrameLoadFailed = true;
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

      // 1) 挑战页：只提示用户完成交互，绝不参与完成判定。
      if (isChallenge) {
        _challengeClearedLogged = false;
        if (!_challengeLogged) {
          _challengeLogged = true;
          unawaited(
            AppLogService.instance.info(
              '浏览器检测到 Cloudflare 挑战；路径=${_browserLogPath(completedUri)}；'
              '进度=$_progress；交互=${snapshot.hasVisibleInteraction ? '是' : '否'}',
              component: 'hanime_browser',
            ),
          );
        }
        if (snapshot.hasVisibleInteraction && !_interactionHintLogged) {
          _interactionHintLogged = true;
          if (mounted) {
            setState(() => _statusText = '请在网页中完成验证，成功后会自动返回。');
          }
        }
        return;
      }
      if (_challengeLogged && !_challengeClearedLogged) {
        _challengeClearedLogged = true;
        unawaited(
          AppLogService.instance.info(
            '浏览器挑战界面已消失，等待目标文档加载完成；'
            '路径=${_browserLogPath(completedUri)}；进度=$_progress；'
            '耗时=${_elapsed.elapsedMilliseconds}ms',
            component: 'hanime_browser',
          ),
        );
      }

      // 2) 主文档加载失败：错误页同样有标题、同样会回调 onPageFinished，
      //    必须当成明确失败，不能继续被当作"验证进行中"。
      if (_mainFrameLoadFailed) {
        if (!_mainFrameFailureLogged) {
          _mainFrameFailureLogged = true;
          unawaited(
            AppLogService.instance.warning(
              '浏览器主文档加载失败，等待用户重试；'
              '路径=${_browserLogPath(completedUri)}；'
              '耗时=${_elapsed.elapsedMilliseconds}ms',
              component: 'hanime_browser',
            ),
          );
        }
        return;
      }

      // 3) 导航尚未结束：此刻读到的 DOM 属于上一页或过渡页，判定不可信。
      if (!_navigationFinished) return;

      _documentWaitStartedAt ??= _elapsed.elapsed;
      _logWaitingHintIfNeeded();

      // 4) 目标 host 必须一致：WebView 可能被重定向到挑战域或其它站点。
      if (!isTargetHost) {
        if (!_targetMissLogged) {
          _targetMissLogged = true;
          unawaited(
            AppLogService.instance.warning(
              '浏览器当前文档不属于 Hanime，无法作为目标正文；'
              '路径=${_browserLogPath(completedUri)}',
              component: 'hanime_browser',
            ),
          );
        }
        return;
      }

      // 5) 前置条件都满足后，才取完整 HTML 做文档身份与结构校验。
      //    完整 HTML 体积可达数百 KB，因此按 [_probeInterval]（800ms）节流，
      //    避免 500ms 巡检反复搬运整页正文。
      final probe = await _probeDocument(generation);
      if (probe == null) return;
      if (!mounted || _completed || generation != _navigationGeneration) {
        return;
      }
      final inspection = probe.inspection;
      if (!inspection.isTarget) {
        if (!_documentMismatchLogged) {
          _documentMismatchLogged = true;
          unawaited(
            AppLogService.instance.warning(
              '浏览器文档与请求目标不一致，暂不采用；'
              '路径=${_browserLogPath(completedUri)}；'
              '状态=${inspection.status.name}；类型=${inspection.kind.name}；'
              '原因=${inspection.reason}',
              component: 'hanime_browser',
            ),
          );
        }
        if (inspection.requiresLogin && mounted) {
          setState(() => _statusText = 'Hanime 登录状态已失效，请在网页中重新登录后再试。');
        }
        return;
      }

      final canComplete = canCompleteHanimeBrowserPage(
        isTargetHost: isTargetHost,
        isChallenge: false,
        navigationFinished: _navigationFinished,
        hasTargetDocument: inspection.isTarget,
      );
      if (!canComplete) return;

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
      widget.onPageReady(probe.html);
      return;
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

  /// 取完整 HTML 并做文档身份校验；距上次探测不足 [_probeInterval] 时返回 null。
  Future<_DocumentProbe?> _probeDocument(int generation) async {
    final lastProbeAt = _lastProbeAt;
    if (lastProbeAt != null &&
        _elapsed.elapsed - lastProbeAt < _probeInterval) {
      return null;
    }
    _lastProbeAt = _elapsed.elapsed;
    final result = await _controller.runJavaScriptReturningResult(
      'document.documentElement.outerHTML',
    );
    final html = _decodeJavaScriptString(result);
    if (!mounted || _completed || generation != _navigationGeneration) {
      return null;
    }
    if (html.trim().isEmpty) return null;
    return _DocumentProbe(
      html: html,
      inspection: HanimePageParser.inspectBrowserDocument(
        source: html,
        targetUri: widget.targetUri,
      ),
    );
  }

  void _logWaitingHintIfNeeded() {
    final startedAt = _documentWaitStartedAt;
    if (_waitingHintLogged || startedAt == null) return;
    if (_elapsed.elapsed - startedAt < _waitingHintAfter) return;
    _waitingHintLogged = true;
    unawaited(
      AppLogService.instance.info(
        '等待目标文档加载已超 10 秒，提示用户可手动重试；'
        '耗时=${_elapsed.elapsedMilliseconds}ms',
        component: 'hanime_browser',
      ),
    );
    if (mounted) {
      setState(() => _statusText = '正在等待 Hanime 页面加载…如果长时间无反应，请点重试。');
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
        // Only take a lightweight snapshot here, for status text and challenge
        // detection. Document identity and business structure are judged by
        // HanimePageParser.inspectBrowserDocument on the full DOM instead,
        // because plain string "contains" checks can be fooled by class names,
        // comments, and hidden templates inside scripts.
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
    _documentWaitStartedAt = _elapsed.elapsed;
    _waitingHintLogged = false;
    _lastProbeAt = null;
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

/// 轻量页面快照：只用于识别挑战、判断有没有可见交互、给提示文案用。
///
/// 文档身份与业务结构不在这里判断——字符串层面的"有标题/有正文"无法区分
/// 业务页和错误页，必须交给 [HanimePageParser.inspectBrowserDocument] 在
/// 完整 DOM 上做结构校验。
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
}

/// 一次完整 DOM 探测的结果：正文与其身份校验结论必须成对传递，
/// 避免"校验的是 A 文档、交出去的是 B 文档"。
final class _DocumentProbe {
  const _DocumentProbe({required this.html, required this.inspection});

  final String html;
  final HanimeDocumentInspection inspection;
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
