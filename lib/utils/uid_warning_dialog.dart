import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/prefs_keys.dart';
import '../constants/ui_strings.dart';
import '../providers/settings_provider.dart';

/// Shows the UID search warning dialog the first time a user enables UID search.
/// Marks the pref after the dialog is dismissed so it only ever shows once.
Future<void> showUidWarningIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.getBool(PrefsKeys.uidSearchWarningShown) ?? false) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Finding Your UID'),
      content: const Text(uidWarningMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  await prefs.setBool(PrefsKeys.uidSearchWarningShown, true);
}
