import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flule34/l10n/ui_localization.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/content_source.dart';
import '../../core/models/hanime_comment_models.dart';
import '../../shared/site_avatar.dart';
import '../../shared/scroll_to_top_overlay.dart';
import '../auth/login_sheet.dart';

class HanimeCommentsSection extends StatefulWidget {
  const HanimeCommentsSection({
    super.key,
    required this.api,
    required this.videoId,
    required this.scrollToTopController,
    required this.active,
  });

  final Rule34VideoApi api;
  final String videoId;
  final ScrollToTopController scrollToTopController;
  final bool active;

  @override
  State<HanimeCommentsSection> createState() => _HanimeCommentsSectionState();
}

class _HanimeCommentsSectionState extends State<HanimeCommentsSection> {
  static const _reportReasons = <(String, String)>[
    ('煽动仇恨或恶意内容', '煽動仇恨或惡意內容'),
    ('暴力或令人反感的内容', '暴力或令人反感的內容'),
    ('广告内容或垃圾内容', '廣告內容或垃圾內容'),
    ('其他举报理由', '其他檢舉理由'),
  ];

  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  ScrollPosition? _commentsPosition;
  final Map<String, List<HanimeComment>> _replies = {};
  final Set<String> _expandedReplies = {};
  final Set<String> _loadingReplies = {};
  Future<List<HanimeComment>>? _future;
  HanimeComment? _replyTarget;
  HanimeComment? _replyRoot;
  var _submitting = false;
  double? _commentsOffsetBeforeKeyboard;

  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(_onComposerFocusChanged);
  }

  @override
  void didUpdateWidget(covariant HanimeCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active && _composerFocus.hasFocus) {
      _composerFocus.unfocus();
    }
    if (widget.active && !oldWidget.active && _future == null) {
      setState(() => _future = _load());
    }
  }

  @override
  void dispose() {
    if (_composerFocus.hasFocus) {
      widget.scrollToTopController.setSuppressed(false);
    }
    _composerFocus.removeListener(_onComposerFocusChanged);
    _composerFocus.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _onComposerFocusChanged() {
    widget.scrollToTopController.setSuppressed(_composerFocus.hasFocus);
    unawaited(
      AppLogService.instance.info(
        '评论输入焦点变化；site=hanime1；video=${widget.videoId}；'
        'focused=${_composerFocus.hasFocus}；'
        'suppressed=${widget.scrollToTopController.suppressed}',
        component: 'scroll_to_top',
      ),
    );
    if (mounted) setState(() {});
    if (_composerFocus.hasFocus) {
      _restoreCommentsOffsetAfterKeyboard();
    }
  }

  void _restoreCommentsOffsetAfterKeyboard() {
    final savedOffset = _commentsOffsetBeforeKeyboard;
    if (savedOffset == null) return;
    void restore() {
      if (!mounted || !_composerFocus.hasFocus || _commentsPosition == null) {
        return;
      }
      final position = _commentsPosition!;
      final target = savedOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        position.jumpTo(target);
        unawaited(
          AppLogService.instance.info(
            '评论列表位置恢复；site=hanime1；video=${widget.videoId}；saved=${savedOffset.toStringAsFixed(1)}；actual=${position.pixels.toStringAsFixed(1)}',
            component: 'scroll_to_top',
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
    Future<void>.delayed(const Duration(milliseconds: 450), restore);
  }

  Future<List<HanimeComment>> _load() =>
      widget.api.hanime1Api.loadComments(widget.videoId);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<bool> _ensureLogin() async {
    if (!widget.api.sessionStore.isHanimeLoggedIn) {
      await showLoginSheet(context, widget.api, site: ContentSite.hanime1);
    }
    return widget.api.sessionStore.isHanimeLoggedIn;
  }

  void _startReply(HanimeComment target, HanimeComment root) {
    setState(() {
      _replyTarget = target;
      _replyRoot = root;
    });
    _composerFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyTarget = null;
      _replyRoot = null;
    });
  }

  Future<void> _submit() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _submitting || !await _ensureLogin()) return;
    final target = _replyTarget;
    final root = _replyRoot;
    setState(() => _submitting = true);
    try {
      if (target == null) {
        await widget.api.hanime1Api.createComment(
          videoId: widget.videoId,
          text: text,
        );
        await _refresh();
      } else {
        await widget.api.hanime1Api.replyComment(
          videoId: widget.videoId,
          commentId: target.id,
          text: text,
        );
        if (root != null) await _loadReplies(root, force: true);
      }
      _composerController.clear();
      _composerFocus.unfocus();
      if (mounted) {
        _cancelReply();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(target == null ? '评论已发表。' : '回复已发表。')),
        );
      }
      unawaited(
        AppLogService.instance.info(
          'Hanime 评论提交成功；video=${widget.videoId}；reply=${target != null}',
          component: 'hanime_comment',
        ),
      );
    } catch (error, stackTrace) {
      final action = target == null ? '发表' : '回复';
      unawaited(
        AppLogService.instance.error(
          error,
          stackTrace,
          component: 'hanime_comment',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('$action失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleReplies(HanimeComment comment) async {
    if (_expandedReplies.contains(comment.id)) {
      setState(() => _expandedReplies.remove(comment.id));
      return;
    }
    await _loadReplies(comment);
  }

  Future<void> _loadReplies(HanimeComment comment, {bool force = false}) async {
    if (_loadingReplies.contains(comment.id)) return;
    if (!force && _replies.containsKey(comment.id)) {
      setState(() => _expandedReplies.add(comment.id));
      return;
    }
    setState(() {
      _expandedReplies.add(comment.id);
      _loadingReplies.add(comment.id);
    });
    try {
      final replies = await widget.api.hanime1Api.loadReplies(comment.id);
      if (mounted) setState(() => _replies[comment.id] = replies);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('回复加载失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingReplies.remove(comment.id));
    }
  }

  Future<void> _likeComment(
    HanimeComment comment,
    bool positive, {
    HanimeComment? root,
  }) async {
    if (!await _ensureLogin()) return;
    try {
      await widget.api.hanime1Api.likeComment(
        videoId: widget.videoId,
        commentId: comment.id,
        positive: positive,
        liked: comment.liked,
        disliked: comment.disliked,
        likesCount: comment.likesCount,
        likesSum: comment.likesSum,
      );
      if (root == null) {
        await _refresh();
      } else {
        await _loadReplies(root, force: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('操作失败：$error')));
      }
    }
  }

  Future<void> _reportComment(HanimeComment comment) async {
    if (!await _ensureLogin() || !mounted) return;
    var selected = _reportReasons.first.$2;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('举报评论'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reason in _reportReasons)
                  RadioListTile<String>(
                    value: reason.$2,
                    title: AppText(reason.$1),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('提交'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await widget.api.hanime1Api.reportComment(
        videoId: widget.videoId,
        commentId: comment.id,
        reason: selected,
        reportableType: comment.reportableType,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('举报已提交。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('举报失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.expand();
    final loggedIn = widget.api.sessionStore.isHanimeLoggedIn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Expanded(child: _buildList()),
          const SizedBox(height: 6),
          if (loggedIn) _buildComposer() else _buildSignedOutPrompt(),
        ],
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<HanimeComment>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const AppText('评论加载失败，点击重试'),
            ),
          );
        }
        final comments = snapshot.data ?? const <HanimeComment>[];
        if (comments.isEmpty) return const Center(child: AppText('还没有评论。'));
        return RefreshIndicator(
          onRefresh: _refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final context = notification.context;
              if (context != null) {
                _commentsPosition = Scrollable.maybeOf(context)?.position;
              }
              return false;
            },
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: comments.length,
              itemBuilder: (context, index) => _buildComment(comments[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    final target = _replyTarget;
    final expanded = _composerFocus.hasFocus || target != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (target != null)
          Row(
            children: [
              Expanded(child: AppText('回复 ${target.username}')),
              IconButton(
                tooltip: '取消回复',
                visualDensity: VisualDensity.compact,
                onPressed: _cancelReply,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composerController,
                focusNode: _composerFocus,
                onTap: () {
                  final position = _commentsPosition;
                  if (position != null && position.hasPixels) {
                    _commentsOffsetBeforeKeyboard = position.pixels;
                  }
                  unawaited(
                    AppLogService.instance.info(
                      '评论输入框点击；site=hanime1；video=${widget.videoId}；'
                      'focusBefore=${_composerFocus.hasFocus}；'
                      'suppressed=${widget.scrollToTopController.suppressed}',
                      component: 'scroll_to_top',
                    ),
                  );
                },
                onTapOutside: (_) {
                  unawaited(
                    AppLogService.instance.info(
                      '评论输入框点击外部，主动释放焦点；site=hanime1；'
                      'video=${widget.videoId}',
                      component: 'scroll_to_top',
                    ),
                  );
                  FocusScope.of(context).unfocus();
                },
                minLines: 1,
                maxLines: expanded ? 4 : 1,
                scrollPadding: EdgeInsets.zero,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.uiText(
                    target == null ? '发一条评论...' : '回复...',
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedOutPrompt() {
    return OutlinedButton.icon(
      onPressed: _ensureLogin,
      icon: const Icon(Icons.login),
      label: const AppText('登录 Hanime 后参与评论'),
    );
  }

  Widget _buildComment(HanimeComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          _commentBody(comment, root: comment),
          if (_expandedReplies.contains(comment.id)) _buildReplies(comment),
        ],
      ),
    );
  }

  Widget _buildReplies(HanimeComment root) {
    if (_loadingReplies.contains(root.id)) {
      return const Padding(
        padding: EdgeInsets.only(left: 42),
        child: LinearProgressIndicator(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        children: [
          for (final reply in _replies[root.id] ?? const <HanimeComment>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _commentBody(reply, root: root),
            ),
        ],
      ),
    );
  }

  Widget _commentBody(HanimeComment comment, {required HanimeComment root}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SiteAvatar(
          radius: 16,
          imageUrl: comment.avatarUrl,
          fallbackIcon: Icons.person,
          site: ContentSite.hanime1,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.username,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (comment.dateLabel != null)
                    AppText(
                      comment.dateLabel!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  IconButton(
                    tooltip: '举报',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: () => _reportComment(comment),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                  ),
                ],
              ),
              AppText(comment.content),
              const SizedBox(height: 2),
              Row(
                children: [
                  _action(
                    icon: comment.liked
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    count: comment.likeCount,
                    onTap: () => _likeComment(
                      comment,
                      true,
                      root: comment.isReply ? root : null,
                    ),
                  ),
                  _action(
                    icon: comment.disliked
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    onTap: () => _likeComment(
                      comment,
                      false,
                      root: comment.isReply ? root : null,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _startReply(comment, root),
                    child: const AppText('回复'),
                  ),
                  if (!comment.isReply && comment.replyCount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _toggleReplies(comment),
                      child: AppText(
                        _expandedReplies.contains(comment.id)
                            ? '收起回复'
                            : '查看 ${comment.replyCount} 则回复',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required VoidCallback onTap,
    int count = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            if (count > 0) ...[const SizedBox(width: 3), AppText('$count')],
          ],
        ),
      ),
    );
  }
}
