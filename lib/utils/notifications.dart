import 'package:material_ui/material_ui.dart';

import 'theme.dart';

extension ScaffoldMessengerX on ScaffoldMessengerState {
  void showMessage(String text, {Duration duration = AppTheme.toastDefault}) {
    showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  void showError(String text) {
    showSnackBar(SnackBar(content: Text(text), backgroundColor: AppTheme.red));
  }

  /// Says what was done, with an Undo that stays long enough to reach for.
  /// [onUndo] runs when it is tapped; one that fails says so.
  void showUndoMessage(
    String text,
    Future<void> Function() onUndo, {
    Duration duration = AppTheme.toastUndo,
  }) {
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        content: Text(text),
        persist: false,
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppTheme.accent,
          onPressed: () async {
            try {
              await onUndo();
            } catch (_) {
              showError("Couldn't undo that.");
            }
          },
        ),
      ),
    );
  }
}

extension BuildContextMessengerX on BuildContext {
  void showMessage(String text, {Duration duration = AppTheme.toastDefault}) {
    ScaffoldMessenger.of(this).showMessage(text, duration: duration);
  }

  void showError(String text) {
    ScaffoldMessenger.of(this).showError(text);
  }
}
