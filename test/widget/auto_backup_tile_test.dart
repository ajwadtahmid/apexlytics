import 'dart:io';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/auto_backup_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/screens/settings/widgets/auto_backup_tile.dart';
import 'package:apexlytics/utils/storage/auto_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final newer = AutoBackupFile(
    file: File('auto_newer.json.gz'),
    takenAt: DateTime(2026, 11, 4, 9, 40),
    bytes: 2 * 1024 * 1024,
  );
  final older = AutoBackupFile(
    file: File('auto_older.json.gz'),
    takenAt: DateTime(2026, 11, 1, 21, 5),
    bytes: 900 * 1024,
  );

  var exports = 0;

  Future<({SharedPreferences prefs, List<AutoBackupFile> restored})> pump(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    List<AutoBackupFile> copies = const [],
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final restored = <AutoBackupFile>[];
    exports = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          autoBackupListProvider.overrideWith((ref) async => copies),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AutoBackupTile(
                onRestore: restored.add,
                onExport: () => exports++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (prefs: prefs, restored: restored);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Automatic backups'));
    await tester.pumpAndSettle();
  }

  testWidgets('the row says on, and that there is no copy yet', (tester) async {
    await pump(tester);

    expect(find.text('Automatic backups'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('No copy yet'), findsOneWidget);
    // Everything else lives in the sheet.
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('uninstall'), findsNothing);
  });

  testWidgets('the row shows the newest copy', (tester) async {
    await pump(tester, copies: [newer, older]);
    expect(find.text('Last copy Nov 4, 9:40 AM'), findsOneWidget);
  });

  testWidgets('the row says off, twice: as its status and its state', (
    tester,
  ) async {
    await pump(tester, saved: {PrefsKeys.autoBackupEnabled: false});
    expect(find.text('Off'), findsNWidgets(2));
    expect(find.text('On'), findsNothing);
  });

  testWidgets('the sheet explains it, and is on to begin with', (tester) async {
    await pump(tester);
    await openSheet(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.textContaining('Every 3 days'), findsOneWidget);
    expect(find.textContaining('last 3 copies'), findsOneWidget);
    expect(find.textContaining('if you uninstall'), findsOneWidget);
    expect(find.textContaining('No copies yet'), findsOneWidget);
  });

  testWidgets('switching it off is saved and shown on the row', (tester) async {
    final (:prefs, restored: _) = await pump(tester);
    await openSheet(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(prefs.getBool(PrefsKeys.autoBackupEnabled), isFalse);
    expect(find.text('Off'), findsNWidgets(2)); // the row behind the sheet
  });

  testWidgets('the warning offers to export a file, and closes the sheet', (
    tester,
  ) async {
    await pump(tester);
    await openSheet(tester);

    await tester.tap(find.text('Export a file now'));
    await tester.pumpAndSettle();

    expect(exports, 1);
    expect(find.text('Export a file now'), findsNothing);
  });

  testWidgets('lists the copies, newest first, and restores the one tapped', (
    tester,
  ) async {
    final (prefs: _, :restored) = await pump(tester, copies: [newer, older]);
    await openSheet(tester);

    expect(find.text('Restore from a copy'), findsOneWidget);
    expect(find.textContaining('2 copies'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(find.text('900 KB'), findsOneWidget);
    expect(find.text('Restore'), findsNWidgets(2));
    // Newest first.
    expect(
      tester.getTopLeft(find.text('Nov 4, 9:40 AM')).dy,
      lessThan(tester.getTopLeft(find.text('Nov 1, 9:05 PM')).dy),
    );

    await tester.tap(find.text('Nov 1, 9:05 PM'));
    await tester.pumpAndSettle();

    expect(restored, [older]);
    // The sheet closed.
    expect(find.text('Restore from a copy'), findsNothing);
  });
}
