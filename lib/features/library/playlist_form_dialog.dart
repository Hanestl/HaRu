import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';

import '../../core/models/video_models.dart';
import '../../shared/settings_controls.dart';

Future<PlaylistFormData?> showPlaylistEditor(
  BuildContext context, {
  required String title,
  required PlaylistFormData initial,
}) async {
  final titleController = TextEditingController(text: initial.title);
  final descriptionController = TextEditingController(
    text: initial.description,
  );
  var isPrivate = initial.isPrivate;
  final result = await showDialog<PlaylistFormData>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: AppText(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(labelText: context.uiText('名称')),
              ),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: context.uiText('描述（可选）'),
                ),
              ),
              SettingsSwitchField(
                title: '设为私密',
                value: isPrivate,
                onChanged: (value) => setDialogState(() => isPrivate = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = titleController.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                PlaylistFormData(
                  title: value,
                  description: descriptionController.text.trim(),
                  isPrivate: isPrivate,
                ),
              );
            },
            child: const AppText('保存'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
  return result;
}
