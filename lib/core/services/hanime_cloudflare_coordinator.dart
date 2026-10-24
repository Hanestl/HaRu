import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../logging/app_log_service.dart';

/// 一次待完成的浏览器辅助验证请求。
final class HanimeCloudflareRequest {
  const HanimeCloudflareRequest({
    required this.id,
    required this.targetUri,
    required this.allowForegroundVerification,
  });

  final int id;
  final Uri targetUri;

  /// 是否允许把验证界面弹到前台。
  ///
  /// 后台预取（启动预热、相邻频道、频道后台刷新、列表下一条）传 `false`：
  /// 它们只做尽力而为的缓存填充，失败交给真正的用户操作去验证，绝不打断用户。
  final bool allowForegroundVerification;
}

/// 一次浏览器验证弹窗的结局。
///
/// 三种结局的冷却策略不同（见 [HanimeCloudflareCoordinator.complete]）：
/// 成功不冷却，失败按 host 退避，用户取消只丢弃同一批排队请求。
enum HanimeBrowserVerificationOutcome {
  /// 拿到了通过身份校验的目标文档。
  success,

  /// 页面是挑战页、错误页、身份不匹配或加载失败。
  failed,

  /// 用户主动关闭卡片（关闭按钮 / 返回键）。
  cancelled,
}

/// Cloudflare 辅助验证的唯一完成判据。
///
/// 必须同时满足：
/// 1. 当前文档仍在本次请求的目标域名下（[isTargetHost]）；
/// 2. 当前文档不是 Cloudflare 挑战页（[isChallenge]）；
/// 3. 本次弹窗内真实完成过一次导航（[navigationFinished]）；
/// 4. 当前文档就是**本次请求的目标文档**（[hasTargetDocument]）。
///
/// 第 3 条是关键：CookieManager 会保留上一次会话的 `cf_clearance`，而弹窗
/// 刚打开时 WebView 还停在空白页（`readyState` 同样是 `complete`），只看
/// cookie 或进度会把"还没开始加载"误判成"验证已完成"，弹窗就会在 500ms
/// 巡检首拍自己关闭——这正是"闪出后立刻消失、不给加载时间"的成因。
///
/// 第 4 条不再接受"旧的 cf_clearance"或"任意有标题的文档"：旧的 clearance
/// 不代表本次请求已经通过，普通错误页同样有标题和 onPageFinished。目标
/// 文档由 [hasTargetDocument] 传入，调用方必须用真实 DOM 结构 + 目标 URI
/// 身份共同判定（见 `HanimePageParser.inspectBrowserDocument`）。
bool canCompleteHanimeBrowserPage({
  required bool isTargetHost,
  required bool isChallenge,
  required bool navigationFinished,
  required bool hasTargetDocument,
}) {
  if (!isTargetHost || isChallenge) return false;
  if (!navigationFinished) return false;
  return hasTargetDocument;
}

final class HanimeCloudflareCoordinator extends ChangeNotifier {
  HanimeCloudflareCoordinator({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// 一次验证失败后的同 host 冷却时间。
  ///
  /// Cloudflare 的封锁通常按 IP/会话持续一段时间，短时间内反复弹窗既救不回
  /// 请求，又会连续闪现卡片。冷却期内 [requestPage] 直接返回 null，由调用方
  /// 按 Cloudflare 受限处理（保留缓存或提示重试）。
  static const verificationCooldown = Duration(seconds: 30);

  final DateTime Function() _clock;

  HanimeCloudflareRequest? _activeRequest;
  final ListQueue<_PendingBrowserPage> _queue = ListQueue();
  final Map<String, _PendingBrowserPage> _pendingByUrl = {};
  final Map<String, DateTime> _cooldownUntil = {};
  var _nextId = 0;

  HanimeCloudflareRequest? get activeRequest => _activeRequest;

  /// 当前激活的请求是否允许弹出前台验证卡片。
  bool get requiresForeground =>
      _activeRequest?.allowForegroundVerification ?? false;

  /// 该 host 是否处于验证冷却期。
  bool isCoolingDown(Uri targetUri) => remainingCooldown(targetUri) != null;

  /// 该 host 剩余的冷却时间，未冷却返回 null。
  Duration? remainingCooldown(Uri targetUri) {
    final host = targetUri.host.toLowerCase();
    final until = _cooldownUntil[host];
    if (until == null) return null;
    final remaining = until.difference(_clock());
    if (remaining <= Duration.zero) {
      _cooldownUntil.remove(host);
      return null;
    }
    return remaining;
  }

  Future<String?> requestPage(
    Uri targetUri, [
    bool allowForegroundVerification = true,
  ]) {
    // 后台预取（启动预热、相邻频道、后台刷新、列表下一条）绝不弹前台卡片：
    // 直接返回 null，由调用方按 Cloudflare 受限处理，避免后台操作打断用户。
    if (!allowForegroundVerification) {
      return Future<String?>.value();
    }
    final remaining = remainingCooldown(targetUri);
    if (remaining != null) {
      unawaited(
        AppLogService.instance.info(
          '浏览器验证处于退避期，跳过本次请求；路径=${_logPath(targetUri)}；'
          '剩余秒=${remaining.inSeconds}',
          component: 'hanime_browser',
        ),
      );
      return Future<String?>.value();
    }

    final key = _keyOf(targetUri, allowForegroundVerification);
    final existing = _pendingByUrl[key];
    if (existing != null) return existing.completer.future;

    final pending = _PendingBrowserPage(
      key: key,
      request: HanimeCloudflareRequest(
        id: ++_nextId,
        targetUri: targetUri,
        allowForegroundVerification: allowForegroundVerification,
      ),
      completer: Completer<String?>(),
    );
    _pendingByUrl[key] = pending;
    _queue.add(pending);
    _activateNext();
    return pending.completer.future;
  }

  /// 结束当前激活的请求。
  ///
  /// [outcome] 决定冷却策略：
  /// - [HanimeBrowserVerificationOutcome.success]：不写冷却。同一 host 的其它
  ///   请求可以继续各自验证，否则"首页刚验证成功、点开视频又被冷却拦住"。
  /// - [HanimeBrowserVerificationOutcome.failed]：按 host 退避
  ///   [verificationCooldown]，并丢弃已经排队的同 host 请求——它们本来就是在
  ///   同一轮请求风暴里排进来的，逐个弹窗只会连闪。
  /// - [HanimeBrowserVerificationOutcome.cancelled]：不写冷却（用户随时可以
  ///   显式重试），但同样丢弃已排队的同 host 请求，避免关掉卡片后立刻又弹出。
  void complete({
    required int requestId,
    String? html,
    HanimeBrowserVerificationOutcome? outcome,
  }) {
    final request = _activeRequest;
    if (request == null || request.id != requestId || _queue.isEmpty) {
      return;
    }
    final pending = _queue.removeFirst();
    if (pending.request.id != requestId) return;

    _pendingByUrl.remove(pending.key);
    _activeRequest = null;

    final hasBody = html != null && html.trim().isNotEmpty;
    final resolved =
        outcome ??
        (hasBody
            ? HanimeBrowserVerificationOutcome.success
            : HanimeBrowserVerificationOutcome.failed);
    final effective =
        resolved == HanimeBrowserVerificationOutcome.success && !hasBody
        ? HanimeBrowserVerificationOutcome.failed
        : resolved;

    if (effective == HanimeBrowserVerificationOutcome.failed) {
      _cooldownUntil[pending.request.targetUri.host.toLowerCase()] = _clock()
          .add(verificationCooldown);
    }
    if (effective != HanimeBrowserVerificationOutcome.success) {
      _dropQueuedForHost(pending.request.targetUri.host);
    }

    if (!pending.completer.isCompleted) pending.completer.complete(html);
    _activateNext(notify: false);
    notifyListeners();
  }

  /// 丢弃队列里同一 host 的请求。
  ///
  /// 必须逐个 [Completer.complete] 并清掉 [_pendingByUrl]，否则调用方的
  /// `await` 会永久挂起，去重映射也会泄漏（同一个 URL 以后再也拿不到新卡片）。
  void _dropQueuedForHost(String host) {
    if (_queue.isEmpty) return;
    final normalized = host.toLowerCase();
    final kept = <_PendingBrowserPage>[];
    var dropped = 0;
    for (final pending in _queue) {
      if (pending.request.targetUri.host.toLowerCase() == normalized) {
        dropped++;
        _pendingByUrl.remove(pending.key);
        if (!pending.completer.isCompleted) pending.completer.complete(null);
        continue;
      }
      kept.add(pending);
    }
    if (dropped == 0) return;
    _queue
      ..clear()
      ..addAll(kept);
    unawaited(
      AppLogService.instance.info(
        '浏览器验证队列已清理；host=$host；丢弃=$dropped',
        component: 'hanime_browser',
      ),
    );
  }

  void _activateNext({bool notify = true}) {
    if (_activeRequest != null) return;
    while (_queue.isNotEmpty) {
      final pending = _queue.first;
      // 队首可能是在冷却写入之前就排进来的：这里必须重新执行与
      // [requestPage] 完全一致的 host 策略，否则冷却对已排队请求无效。
      final remaining = remainingCooldown(pending.request.targetUri);
      if (remaining != null) {
        _queue.removeFirst();
        _pendingByUrl.remove(pending.key);
        if (!pending.completer.isCompleted) pending.completer.complete(null);
        unawaited(
          AppLogService.instance.info(
            '已排队的浏览器验证请求被退避跳过；路径='
            '${_logPath(pending.request.targetUri)}；'
            '剩余秒=${remaining.inSeconds}',
            component: 'hanime_browser',
          ),
        );
        continue;
      }
      _activeRequest = pending.request;
      if (notify) notifyListeners();
      return;
    }
  }

  String _keyOf(Uri targetUri, bool allowForegroundVerification) =>
      '${targetUri.toString()}#$allowForegroundVerification';

  String _logPath(Uri uri) => uri.path.isEmpty ? '/' : uri.path;

  @override
  void dispose() {
    for (final pending in _queue) {
      if (!pending.completer.isCompleted) pending.completer.complete(null);
    }
    _queue.clear();
    _pendingByUrl.clear();
    _cooldownUntil.clear();
    _activeRequest = null;
    super.dispose();
  }
}

final class _PendingBrowserPage {
  const _PendingBrowserPage({
    required this.key,
    required this.request,
    required this.completer,
  });

  final String key;
  final HanimeCloudflareRequest request;
  final Completer<String?> completer;
}
