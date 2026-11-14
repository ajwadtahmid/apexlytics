import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/prefs_keys.dart';
import '../../../providers/backup_status_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/backup_reminder.dart';
import '../../../utils/ranked/ranked_period.dart';
import '../../../utils/theme.dart';
import '../../settings/widgets/cache_settings_section.dart' show exportData;

/// Once a split ends, a card at the top of Overview asking for an export, for
/// as long as none was made since and until it is dismissed. A split's games
/// are the ones most worth keeping, and nothing here interrupts: it is a line
/// in the page, not a dialog.
class SplitEndBackupNudge extends ConsumerStatefulWidget {
  /// The splits in the picker, newest first.
  final List<RankedSplitBucket> splits;

  /// For tests; defaults to now.
  @visibleForTesting
  final DateTime? now;

  const SplitEndBackupNudge({super.key, required this.splits, this.now});

  @override
  ConsumerState<SplitEndBackupNudge> createState() =>
      _SplitEndBackupNudgeState();
}

class _SplitEndBackupNudgeState extends ConsumerState<SplitEndBackupNudge> {
  bool _dismissed = false;

  Future<void> _dismiss(String splitId) async {
    setState(() => _dismissed = true);
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefsKeys.backupSplitNudgeDismissed, splitId);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final split = splitToBackUp(
      widget.splits,
      ref.watch(lastBackupProvider),
      widget.now ?? DateTime.now(),
    );
    if (split == null) return const SizedBox.shrink();
    final dismissedId = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefsKeys.backupSplitNudgeDismissed);
    if (dismissedId == split.id) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.only(left: AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.accent.withAlpha(30),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.accent.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.backup_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
              child: Text(
                '${split.displayName} has ended. Export a copy of your '
                'history to keep it safe.',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => exportData(context, ref),
            child: const Text(
              'Export',
              style: TextStyle(color: AppTheme.accent),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.muted),
            tooltip: 'Dismiss',
            onPressed: () => _dismiss(split.id),
          ),
        ],
      ),
    );
  }
}
