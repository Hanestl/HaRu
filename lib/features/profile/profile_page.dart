import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/account_models.dart';
import '../../core/models/content_source.dart';
import '../../shared/site_avatar.dart';
import '../../shared/site_badge.dart';
import '../auth/login_sheet.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) {
        final loggedIn = api.sessionStore.isLoggedIn;
        final hanimeLoggedIn = api.sessionStore.isHanimeLoggedIn;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          children: [
            _AccountCard(
              key: ValueKey(api.sessionStore.currentUserId),
              api: api,
              loggedIn: loggedIn,
            ),
            const SizedBox(height: 12),
            _HanimeAccountCard(
              key: ValueKey(api.sessionStore.hanimeUserId),
              api: api,
              loggedIn: hanimeLoggedIn,
            ),
            const SizedBox(height: 28),
            _SettingsTile(
              icon: Icons.downloading_outlined,
              title: '下载',
              onTap: () => context.pushNamed(AppRouteNames.downloadManagement),
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: '显示设置',
              onTap: () => context.pushNamed(AppRouteNames.appearanceSettings),
            ),
            _SettingsTile(
              icon: Icons.play_circle_outline,
              title: '播放设置',
              onTap: () => context.pushNamed(AppRouteNames.playbackSettings),
            ),
            _SettingsTile(
              icon: Icons.tune,
              title: '内容设置',
              onTap: () => context.pushNamed(AppRouteNames.contentSettings),
            ),
            _SettingsTile(
              icon: Icons.translate_outlined,
              title: '翻译设置',
              onTap: () => context.pushNamed(AppRouteNames.translationSettings),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私与数据',
              onTap: () => context.pushNamed(AppRouteNames.privacySettings),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: '关于 HaRu',
              onTap: () => context.pushNamed(AppRouteNames.about),
            ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard({super.key, required this.api, required this.loggedIn});

  final Rule34VideoApi api;
  final bool loggedIn;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  MemberProfile? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      unawaited(_loadProfile());
    }
  }

  Future<void> _loadProfile() async {
    final userId = widget.api.sessionStore.currentUserId;
    if (userId == null) {
      return;
    }
    final cached = await widget.api.loadCachedCurrentUserProfile();
    if (mounted && widget.api.sessionStore.currentUserId == userId) {
      setState(() => _profile = cached);
    }
    try {
      final fresh = await widget.api.loadCurrentUserProfile();
      if (mounted && widget.api.sessionStore.currentUserId == userId) {
        setState(() => _profile = fresh);
      }
    } on Object {
      // 缓存资料可继续展示，网络刷新失败不打断“我的”页面。
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final avatarUrl = profile?.avatarUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.loggedIn
            ? () => context.pushNamed(AppRouteNames.account)
            : () => showLoginSheet(context, widget.api),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              SiteAvatar(
                radius: 36,
                imageUrl: avatarUrl,
                fallbackIcon: widget.loggedIn
                    ? Icons.person
                    : Icons.person_outline,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.loggedIn && profile?.displayName != null)
                      Text(
                        profile!.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    else
                      AppText(
                        widget.loggedIn ? 'Rule34Video 账号' : '尚未登录',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    const SizedBox(height: 4),
                    AppText(
                      widget.loggedIn
                          ? '用户 ID：${widget.api.sessionStore.currentUserId}'
                          : '登录后同步网站收藏、历史记录和订阅。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SiteBadge(site: ContentSite.rule34video, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _HanimeAccountCard extends StatefulWidget {
  const _HanimeAccountCard({
    super.key,
    required this.api,
    required this.loggedIn,
  });

  final Rule34VideoApi api;
  final bool loggedIn;

  @override
  State<_HanimeAccountCard> createState() => _HanimeAccountCardState();
}

class _HanimeAccountCardState extends State<_HanimeAccountCard> {
  HanimeAccountProfile? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      unawaited(_loadProfile());
    }
  }

  Future<void> _loadProfile() async {
    final userId = widget.api.sessionStore.hanimeUserId;
    if (userId == null) {
      return;
    }
    try {
      final profile = await widget.api.hanime1Api.loadHanimeAccountProfile();
      if (mounted && widget.api.sessionStore.hanimeUserId == userId) {
        setState(() => _profile = profile);
      }
    } on Object {
      // 登录后资料加载失败不打断“我的”页面，卡片保留已读到的信息。
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final avatarUrl = profile?.avatarUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.loggedIn
            ? () => context.pushNamed(AppRouteNames.hanimeAccount)
            : () => showLoginSheet(
                context,
                widget.api,
                site: ContentSite.hanime1,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              SiteAvatar(
                radius: 36,
                imageUrl: avatarUrl,
                fallbackIcon: widget.loggedIn
                    ? Icons.person
                    : Icons.person_outline,
                site: ContentSite.hanime1,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.loggedIn && profile?.displayName != null)
                      Text(
                        profile!.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    else
                      AppText(
                        widget.loggedIn ? 'Hanime 账号' : '尚未登录',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    const SizedBox(height: 4),
                    AppText(
                      widget.loggedIn
                          ? '用户 ID：${widget.api.sessionStore.hanimeUserId}'
                          : '登录后同步网站点赞、稍后观看、播放列表和评论。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SiteBadge(site: ContentSite.hanime1, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: AppText(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
