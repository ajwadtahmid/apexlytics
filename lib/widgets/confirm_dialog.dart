import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// A cancel-or-confirm dialog: a [title], a muted [body], a muted Cancel and a
/// [confirmLabel] button in [confirmColor]. Completes with `true` only when
/// the user confirms; dismissing the dialog or tapping Cancel gives `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  Color confirmColor = AppTheme.red,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(title),
      content: Text(body, style: const TextStyle(color: AppTheme.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
