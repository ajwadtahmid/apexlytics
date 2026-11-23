import 'package:material_ui/material_ui.dart';
import 'theme.dart';

extension ScaffoldMessengerX on ScaffoldMessengerState {
  void showMessage(String text, {Duration duration = AppTheme.toastDefault}) {
    showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  void showError(String text) {
    showSnackBar(SnackBar(content: Text(text), backgroundColor: AppTheme.red));
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
