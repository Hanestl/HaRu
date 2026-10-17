import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/error_view.dart';
import '../../shared/video_feed.dart';
import 'subscription_actions.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({
    super.key,
    required this.api,
    required this.subscription,
  });

  final Rule34VideoApi api;
  final SubscriptionItem subscription;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  var _updatingSubscription = false;
  var _subscribed = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subscription.title),
        actions: [
          if (widget.api.canUnsubscribeSubscription(widget.subscription))
            _updatingSubscription
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _toggleSubscription,
                    icon: Icon(
                      _subscribed
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    label: AppText(_subscribed ? '取消订阅' : '订阅'),
                  ),
        ],
      ),
      body: VideoFeed(
        loadPage: (page) =>
            widget.api.loadSubscriptionVideos(widget.subscription, page),
        emptyMessage: '这个订阅目前没有可显示的视频。',
        showSearchAndFilters: true,
        searchHint: '搜索此订阅中的视频',
      ),
    );
  }

  Future<void> _toggleSubscription() async {
    if (_updatingSubscription) {
      return;
    }
    if (_subscribed &&
        (!await confirmUnsubscribeSubscription(context, widget.subscription) ||
            !mounted)) {
      return;
    }
    setState(() => _updatingSubscription = true);
    try {
      final next = !_subscribed;
      await widget.api.setSubscriptionState(
        widget.subscription,
        subscribe: next,
      );
      if (!mounted) {
        return;
      }
      setState(() => _subscribed = next);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(next ? '已订阅。' : '已取消订阅。')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSubscription = false);
      }
    }
  }
}
