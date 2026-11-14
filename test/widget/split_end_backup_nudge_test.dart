import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/providers/backup_status_provider.dart';
import 'package:apexlytics/screens/ranked/widgets/split_end_backup_nudge.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// The card on Overview that asks for an export once a split has ended.
void main() {
  late SharedPreferences prefs;
  final now = DateTime(2026, 11, 20, 12);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  List<RankedSplitBucket> splits({required int endedDaysAgo}) {
    final end = daysAgo(endedDaysAgo);
    return [
      RankedSplitBucket(
        id: 's30_s2',
        displayName: 'Season 30 (Split 2)',
        season: SeasonMeta(
          id: 's30_s2',
          displayName: 'Season 30 (Split 2)',
          start: end.subtract(const Duration(days: 60)),
          end: end,
        ),
      ),
    ];
  }

  Future<ProviderContainer> pump(
    WidgetTester t, {
    required List<RankedSplitBucket> shown,
    int? backupDaysAgo,
    String? dismissed,
  }) async {
    final (container, stored) = await prefsContainer(
      values: {
        if (backupDaysAgo != null)
          PrefsKeys.lastBackupAt: daysAgo(backupDaysAgo).millisecondsSinceEpoch,
        PrefsKeys.backupSplitNudgeDismissed: ?dismissed,
      },
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SplitEndBackupNudge(splits: shown, now: now),
          ),
        ),
      ),
    );
    prefs = stored;
    return container;
  }

  Finder card() => find.text(
    'Season 30 (Split 2) has ended. Export a copy of your history '
    'to keep it safe.',
  );

  testWidgets('asks for an export once a split has ended', (t) async {
    await pump(t, shown: splits(endedDaysAgo: 3));

    expect(card(), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });

  testWidgets('is not there while the split is still running', (t) async {
    await pump(t, shown: splits(endedDaysAgo: -10));

    expect(card(), findsNothing);
  });

  testWidgets('is not there once an export was made after the split ended', (
    t,
  ) async {
    await pump(t, shown: splits(endedDaysAgo: 5), backupDaysAgo: 1);

    expect(card(), findsNothing);
  });

  testWidgets('goes when a backup is made', (t) async {
    final container = await pump(t, shown: splits(endedDaysAgo: 5));
    expect(card(), findsOneWidget);

    // A real clock: the export date is "now" for the app, after the split end.
    await t.runAsync(
      () => container.read(lastBackupProvider.notifier).markBackedUp(now),
    );
    await t.pump();

    expect(card(), findsNothing);
  });

  testWidgets('dismissing it hides it and remembers, for that split', (
    t,
  ) async {
    await pump(t, shown: splits(endedDaysAgo: 3));

    await t.tap(find.byTooltip('Dismiss'));
    await t.pump();

    expect(card(), findsNothing);
    expect(prefs.getString(PrefsKeys.backupSplitNudgeDismissed), 's30_s2');
  });

  testWidgets('stays hidden after it was dismissed for this split', (t) async {
    await pump(t, shown: splits(endedDaysAgo: 3), dismissed: 's30_s2');

    expect(card(), findsNothing);
  });
}
