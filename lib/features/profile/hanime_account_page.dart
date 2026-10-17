import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/account_models.dart';
import '../../core/models/content_source.dart';
import '../../core/services/external_link_service.dart';
import '../../shared/error_view.dart';
import '../../shared/site_avatar.dart';

/// Hanime 账号详情页：资料卡片、站点入口与退出登录。
class HanimeAccountPage extends StatefulWidget {
  const HanimeAccountPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<HanimeAccountPage> createState() => _HanimeAccountPageState();
}

class _HanimeAccountPageState extends State<HanimeAccountPage> {
  Future<HanimeAccountProfile?>? _profile;
  String? _observedUserId;

  @override
  void initState() {
    super.initState();
    _observedUserId = widget.api.sessionStore.hanimeUserId;
    widget.api.sessionStore.addListener(_onSessionChanged);
    _reload();
  }

  @override
  void dispose() {
    widget.api.sessionStore.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final nextUserId = widget.api.sessionStore.hanimeUserId;
    if (!mounted || nextUserId == _observedUserId) {
      return;
    }
    setState(() {
      _observedUserId = nextUserId;
      _profile = nextUserId == null ? null : _loadProfile();
    });
  }

  void _reload({bool force = false}) {
    if (widget.api.sessionStore.isHanimeLoggedIn) {
      _profile = _loadProfile(force: force);
    }
  }

  Future<HanimeAccountProfile?> _loadProfile({bool force = false}) {
    return widget.api.hanime1Api.loadHanimeAccountProfile(force: force);
  }

  Future<void> _editProfile() async {
    try {
      final data = await widget.api.hanime1Api.loadAccountEditData();
      if (!mounted) return;
      final nameController = TextEditingController(text: data.name);
      final emailController = TextEditingController(text: data.email);
      try {
        final submitted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('编辑账号资料'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '显示名称'),
                ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '邮箱'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('保存'),
              ),
            ],
          ),
        );
        final name = nameController.text.trim();
        final email = emailController.text.trim();
        if (submitted != true || name.isEmpty || email.isEmpty) return;
        await widget.api.hanime1Api.updateAccountProfile(
          name: name,
          email: email,
        );
        if (mounted) {
          setState(() => _reload(force: true));
          _message('账号资料已更新。');
        }
      } finally {
        nameController.dispose();
        emailController.dispose();
      }
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '更新 Hanime 账号资料失败：$error',
          component: 'hanime_account',
        ),
      );
      if (mounted) _message('更新失败：${friendlyErrorMessage(error)}');
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('修改'),
            ),
          ],
        ),
      );
      if (submitted != true) return;
      if (newController.text.length < 8) {
        _message('新密码至少需要 8 个字符。');
        return;
      }
      if (newController.text != confirmController.text) {
        _message('两次输入的新密码不一致。');
        return;
      }
      await widget.api.hanime1Api.updateAccountPassword(
        oldPassword: oldController.text,
        newPassword: newController.text,
      );
      if (mounted) _message('密码已更新。');
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '修改 Hanime 账号密码失败：$error',
          component: 'hanime_account',
        ),
      );
      if (mounted) _message('修改失败：${friendlyErrorMessage(error)}');
    } finally {
      oldController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _changeAvatar() async {
    const group = XTypeGroup(
      label: '图片',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;
      await widget.api.hanime1Api.updateAccountAvatar(file.path);
      if (mounted) {
        setState(() => _reload(force: true));
        _message('头像已更新。');
      }
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '更新 Hanime 账号头像失败：$error',
          component: 'hanime_account',
        ),
      );
      if (mounted) _message('头像更新失败：${friendlyErrorMessage(error)}');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Hanime 账号')),
      body: AnimatedBuilder(
        animation: widget.api.sessionStore,
        builder: (context, _) {
          final userId = widget.api.sessionStore.hanimeUserId;
          if (userId == null) {
            return const _HanimeCenteredMessage(
              icon: Icons.person_off_outlined,
              title: '未登录 Hanime',
              message: '请返回“我的”页面登录 Hanime 账号。',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _reload(force: true));
              await _profile;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<HanimeAccountProfile?>(
                  future: _profile,
                  builder: (context, snapshot) => _HanimeProfileCard(
                    userId: userId,
                    profile: snapshot.data,
                    loading:
                        snapshot.connectionState == ConnectionState.waiting,
                    error: snapshot.hasError,
                    onRetry: () => setState(() => _reload(force: true)),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: const AppText('编辑账号资料'),
                    subtitle: const AppText('修改显示名称与邮箱'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editProfile,
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const AppText('更换头像'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changeAvatar,
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const AppText('修改密码'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ),
                _WebsiteTile(
                  icon: Icons.person_outline,
                  title: '网站个人主页',
                  subtitle: '查看公开资料、订阅和上传内容',
                  uri: Uri.parse('$_hanimeBase/user/$userId'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _confirmLogout(context, widget.api),
                  icon: const Icon(Icons.logout),
                  label: const AppText('退出登录'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _hanimeBase = 'https://hanime1.me';

class _HanimeProfileCard extends StatelessWidget {
  const _HanimeProfileCard({
    required this.userId,
    required this.profile,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final String userId;
  final HanimeAccountProfile? profile;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SiteAvatar(
              radius: 38,
              imageUrl: avatarUrl,
              fallbackIcon: Icons.person,
              site: ContentSite.hanime1,
            ),
            const SizedBox(height: 14),
            if (profile?.displayName case final displayName?)
              Text(displayName, style: Theme.of(context).textTheme.titleLarge)
            else
              AppText(
                'Hanime 账号',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: 6),
            SelectableText(context.uiText('用户 ID：$userId')),
            if (profile?.subscriberCount case final subscribers?) ...[
              const SizedBox(height: 4),
              AppText(
                '$subscribers 位订阅者',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (error) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const AppText('资料加载失败，重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebsiteTile extends StatelessWidget {
  const _WebsiteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uri,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: AppText(title),
        subtitle: AppText(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openExternal(context, uri),
      ),
    );
  }
}

class _HanimeCenteredMessage extends StatelessWidget {
  const _HanimeCenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 16),
            AppText(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            AppText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, Uri uri) async {
  try {
    await ExternalLinkService.open(uri);
  } catch (error) {
    unawaited(
      AppLogService.instance.warning(
        '打开外部链接失败；uri=$uri；错误=$error',
        component: 'hanime_account',
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(friendlyErrorMessage(error))));
    }
  }
}

Future<void> _confirmLogout(BuildContext context, Rule34VideoApi api) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppText('退出 Hanime 登录？'),
      content: const AppText('将删除本机保存的 Hanime 账号、密码和登录会话。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const AppText('退出'),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  Object? logoutError;
  try {
    await api.hanime1Api.logout();
  } catch (error) {
    logoutError = error;
  }
  if (!context.mounted) {
    return;
  }
  if (logoutError != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: AppText('网站退出请求失败，但本地登录状态已经清除。')));
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}
