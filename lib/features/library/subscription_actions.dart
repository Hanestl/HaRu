import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/models/video_models.dart';

Future<bool> confirmUnsubscribeSubscription(
  BuildContext context,
  SubscriptionItem subscription,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('取消订阅'),
          content: AppText('确定取消订阅“${subscription.title}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('确定'),
            ),
          ],
        ),
      ) ??
      false;
}
