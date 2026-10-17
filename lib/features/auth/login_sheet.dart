import 'dart:async';

import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/content_source.dart';
import '../../core/services/external_link_service.dart';
import '../../shared/error_view.dart';
import '../../shared/site_badge.dart';
import 'hanime_web_login_page.dart';

Future<bool> showLoginSheet(
  BuildContext context,
  Rule34VideoApi api, {
  ContentSite site = ContentSite.rule34video,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LoginSheet(api: api, site: site),
  );
  return result ?? false;
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet({required this.api, required this.site});

  final Rule34VideoApi api;
  final ContentSite site;

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _submitting = false;
  var _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  bool get _isHanime => widget.site == ContentSite.hanime1;

  Future<void> _loadSavedCredentials() async {
    final credentials = _isHanime
        ? await widget.api.sessionStore.loadHanimeCredentials()
        : await widget.api.sessionStore.loadCredentials();
    if (!mounted || credentials == null) {
      return;
    }
    if (_emailController.text.isEmpty) {
      _emailController.text = credentials.email;
    }
    if (_passwordController.text.isEmpty) {
      _passwordController.text = credentials.password;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      if (_isHanime) {
        await widget.api.hanime1Api.login(email: email, password: password);
      } else {
        await widget.api.login(email: email, password: password);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '账号登录提交失败；site=${widget.site.name}；错误=$error',
          component: 'auth',
        ),
      );
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SiteBadge(site: widget.site, size: 28),
                  const SizedBox(width: 10),
                  AppText(
                    _isHanime ? '登录 Hanime' : '登录 Rule34Video',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(labelText: context.uiText('注册邮箱')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.uiText('请输入注册邮箱。')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: context.uiText('密码'),
                  suffixIcon: IconButton(
                    tooltip: context.uiText(_obscurePassword ? '显示密码' : '隐藏密码'),
                    onPressed: _submitting
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.isEmpty
                    ? context.uiText('请输入密码。')
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('登录'),
              ),
              if (_isHanime) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _openHanimeWebLogin,
                  icon: const Icon(Icons.language, size: 20),
                  label: const AppText('网页 / Google 账号登入'),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => _openWebsite(
                            _isHanime
                                ? Uri.parse('${widget.site.baseUrl}/register')
                                : Uri.parse('https://rule34video.com/signup/'),
                          ),
                    child: const AppText('注册账号'),
                  ),
                  if (!_isHanime)
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => _openWebsite(
                              Uri.parse(
                                'https://rule34video.com/reset-password/',
                              ),
                            ),
                      child: const AppText('忘记密码'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHanimeWebLogin() async {
    final success = await HanimeWebLoginPage.show(context, api: widget.api);
    if (success == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openWebsite(Uri uri) async {
    try {
      await ExternalLinkService.open(uri);
    } catch (error) {
      unawaited(
        AppLogService.instance.warning(
          '打开网站失败；uri=$uri；错误=$error',
          component: 'auth',
        ),
      );
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    }
  }
}
