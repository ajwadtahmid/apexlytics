import 'ranked/ranked_period.dart' show RankedSplitBucket;

/// How long the recorded history can go without a backup before Settings says
/// so (when games were recorded in that time).
const kBackupReminderAfter = Duration(days: 14);

/// How many games can pile up without a backup before Settings says so, however
/// recent the last backup is.
const kBackupReminderGames = 500;

/// What the backup card at the top of Settings says.
enum BackupNudge {
  /// Nothing to protect yet, or not due: no card.
  none,

  /// Games recorded and never exported.
  never,

  /// [kBackupReminderAfter] or [kBackupReminderGames] since the last export.
  stale,
}

/// Where the match history stands against the last backup.
class BackupStatus {
  /// When history was last exported, or null if it never was.
  final DateTime? lastBackup;

  /// Games recorded since [lastBackup], or every recorded game if never.
  final int newGames;

  /// When the oldest recorded game started; the clock to measure from while
  /// there is no backup. Null with no games.
  final DateTime? oldestGame;

  const BackupStatus({
    required this.lastBackup,
    required this.newGames,
    required this.oldestGame,
  });

  /// How long the unsaved games have gone without a backup, or null with
  /// nothing to measure from.
  Duration? gap(DateTime now) {
    final from = lastBackup ?? oldestGame;
    return from == null ? null : now.difference(from);
  }

  /// Whether Settings should nudge: games a backup does not hold, and either
  /// [kBackupReminderAfter] has passed or [kBackupReminderGames] have piled up,
  /// whichever comes first.
  bool isDue(DateTime now) {
    if (newGames <= 0) return false;
    final gap = this.gap(now);
    return newGames >= kBackupReminderGames ||
        (gap != null && gap >= kBackupReminderAfter);
  }

  /// Which card Settings shows.
  BackupNudge nudge(DateTime now) {
    if (!isDue(now)) return BackupNudge.none;
    return lastBackup == null ? BackupNudge.never : BackupNudge.stale;
  }
}

/// "Last backup: 12 days ago" style wording for [at] as seen from [now].
String backupAgeLabel(DateTime at, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 60) return '$days days ago';
  final months = days ~/ 30;
  return '$months months ago';
}

/// The split that has just ended, whose games no backup holds yet: the newest
/// split that ended within [kBackupReminderAfter] and after the last export.
/// Null when there is none. [splits] is newest first, as the picker lists them.
RankedSplitBucket? splitToBackUp(
  List<RankedSplitBucket> splits,
  DateTime? lastBackup,
  DateTime now,
) {
  for (final split in splits) {
    final end = split.season?.end;
    if (end == null || end.isAfter(now)) continue;
    if (now.difference(end) > kBackupReminderAfter) return null;
    return lastBackup != null && !lastBackup.isBefore(end) ? null : split;
  }
  return null;
}
