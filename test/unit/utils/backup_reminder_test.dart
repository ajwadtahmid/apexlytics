import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/utils/backup_reminder.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  group('when a backup is due', () {
    test('not until 14 days have passed since the last one', () {
      BackupStatus last(int days) => BackupStatus(
        lastBackup: daysAgo(days),
        newGames: 5,
        oldestGame: daysAgo(200),
      );

      expect(last(13).isDue(now), isFalse);
      expect(last(14).isDue(now), isTrue);
      expect(last(40).isDue(now), isTrue);
    });

    test('or once 500 games have piled up, however recent the backup', () {
      BackupStatus games(int n) => BackupStatus(
        lastBackup: daysAgo(2),
        newGames: n,
        oldestGame: daysAgo(200),
      );

      expect(games(499).isDue(now), isFalse);
      expect(games(500).isDue(now), isTrue);
    });

    test('not when no games were recorded since', () {
      final status = BackupStatus(
        lastBackup: daysAgo(90),
        newGames: 0,
        oldestGame: daysAgo(200),
      );

      expect(status.isDue(now), isFalse);
    });

    test('with no backup yet, measures from the oldest recorded game', () {
      BackupStatus first(int days) => BackupStatus(
        lastBackup: null,
        newGames: 30,
        oldestGame: daysAgo(days),
      );

      expect(first(10).isDue(now), isFalse);
      expect(first(14).isDue(now), isTrue);
    });

    test('with nothing recorded and no backup, never', () {
      const status = BackupStatus(
        lastBackup: null,
        newGames: 0,
        oldestGame: null,
      );

      expect(status.gap(now), isNull);
      expect(status.isDue(now), isFalse);
    });

    test('a backup made today is not due, however many games came after', () {
      final status = BackupStatus(
        lastBackup: now,
        newGames: 12,
        oldestGame: daysAgo(100),
      );

      expect(status.isDue(now), isFalse);
    });
  });

  group('which card Settings shows', () {
    BackupStatus status({int? backupDays, int games = 5, int oldest = 100}) =>
        BackupStatus(
          lastBackup: backupDays == null ? null : daysAgo(backupDays),
          newGames: games,
          oldestGame: daysAgo(oldest),
        );

    test('none while there is nothing to protect, or not yet due', () {
      expect(status(games: 0).nudge(now), BackupNudge.none);
      expect(status(oldest: 3).nudge(now), BackupNudge.none);
    });

    test('never exported, once due', () {
      expect(status().nudge(now), BackupNudge.never);
      expect(status(games: 500, oldest: 3).nudge(now), BackupNudge.never);
    });

    test('none after an export that is not due again', () {
      expect(status(backupDays: 3).nudge(now), BackupNudge.none);
      expect(status(backupDays: 90, games: 0).nudge(now), BackupNudge.none);
    });

    test('stale after 14 days or 500 games since the export', () {
      expect(status(backupDays: 14).nudge(now), BackupNudge.stale);
      expect(status(backupDays: 2, games: 500).nudge(now), BackupNudge.stale);
    });
  });

  group('the split to ask a backup for', () {
    RankedSplitBucket split(String id, {required int endedDaysAgo}) {
      final end = daysAgo(endedDaysAgo);
      return RankedSplitBucket(
        id: id,
        displayName: id,
        season: SeasonMeta(
          id: id,
          displayName: id,
          start: end.subtract(const Duration(days: 60)),
          end: end,
        ),
      );
    }

    test('a split that just ended, with no export since', () {
      final splits = [
        split('new', endedDaysAgo: 2),
        split('old', endedDaysAgo: 70),
      ];

      expect(splitToBackUp(splits, null, now)?.id, 'new');
      expect(splitToBackUp(splits, daysAgo(5), now)?.id, 'new');
    });

    test('not once an export was made after it ended', () {
      final splits = [split('new', endedDaysAgo: 5)];

      expect(splitToBackUp(splits, daysAgo(1), now), isNull);
    });

    test('not for a split still running, or one that ended long ago', () {
      expect(
        splitToBackUp([split('now', endedDaysAgo: -10)], null, now),
        isNull,
      );
      expect(
        splitToBackUp([split('old', endedDaysAgo: 15)], null, now),
        isNull,
      );
    });

    test('skips a running split to find the one that just ended', () {
      final splits = [
        split('now', endedDaysAgo: -10),
        split('last', endedDaysAgo: 4),
      ];

      expect(splitToBackUp(splits, null, now)?.id, 'last');
    });

    test('not for the bucket with no season dates', () {
      const unknown = RankedSplitBucket(id: 'unknown', displayName: 'Unknown');

      expect(splitToBackUp([unknown], null, now), isNull);
    });
  });

  group('backupAgeLabel', () {
    test('says today and yesterday by the calendar day', () {
      expect(backupAgeLabel(DateTime(2026, 10, 20, 1), now), 'today');
      expect(backupAgeLabel(DateTime(2026, 10, 19, 23), now), 'yesterday');
    });

    test('counts days, then months', () {
      expect(backupAgeLabel(daysAgo(12), now), '12 days ago');
      expect(backupAgeLabel(daysAgo(59), now), '59 days ago');
      expect(backupAgeLabel(daysAgo(60), now), '2 months ago');
      expect(backupAgeLabel(daysAgo(400), now), '13 months ago');
    });
  });
}
