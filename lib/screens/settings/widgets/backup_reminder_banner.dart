import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/backup_status_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../utils/backup_reminder.dart';
import '../../../utils/theme.dart';
import '../../../widgets/surface_card.dart';
import 'cache_settings_section.dart' show exportData;

/// The backup card at the top of Settings, about one thing: whether the match
/// history is safe from losing the phone. Match history lives only on the
/// device and the app cannot rebuild it, so it asks for an export when none was
/// ever made, or when [kBackupReminderAfter] or [kBackupReminderGames] have
/// passed since the last one, and is not there otherwise. Automatic copies are
/// not mentioned here; they have their own row.
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  /// The line under the title.
  @visibleForTesting
  static String message(BackupStatus status) => status.lastBackup == null
      ? 'Export a copy to keep it safe.'
      : '${kBackupReminderAfter.inDays}+ days or $kBackupReminderGames+ games '
            'since last backup.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Games are recorded while this page is out of view, so count afresh each
    // time it is opened.
    ref.listen(currentTabProvider, (_, tab) {
      if (tab == AppTab.settings) ref.invalidate(backupStatusProvider);
    });
    final status = ref.watch(backupStatusProvider).asData?.value;
    if (status == null) return const SizedBox.shrink();
    final nudge = status.nudge(DateTime.now());
    if (nudge == BackupNudge.none) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.md,
          AppTheme.sm,
          AppTheme.sm,
          AppTheme.sm,
        ),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nudge == BackupNudge.never
                        ? 'Your history lives only on this phone'
                        : 'Time for a fresh backup',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message(status), style: AppTheme.caption),
                ],
              ),
            ),
            TextButton(
              onPressed: () => exportData(context, ref),
              child: const Text(
                'Export',
                style: TextStyle(color: AppTheme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
