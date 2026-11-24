import 'package:apexlytics/providers/ranked_provider.dart';
import 'package:apexlytics/screens/ranked/widgets/games_list.dart';
import 'package:apexlytics/utils/notifications.dart';
import 'package:apexlytics/utils/storage/ranked_history_store.dart';
import 'package:apexlytics/utils/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

/// Records the exclusions asked of it instead of touching a database.
class _RecordingStore extends RankedHistoryStore {
  _RecordingStore() : super(overridePath: inMemoryDatabasePath);
  final calls = <(Set<String>, bool)>[];

  @override
  Future<int> setExcludedFor(Iterable<String> ids, bool excluded) async {
    calls.add((ids.toSet(), excluded));
    return ids.toSet().length;
  }
}

void main() {
  group('showUndoMessage', () {
    Future<ScaffoldMessengerState> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      return ScaffoldMessenger.of(tester.element(find.byType(Scaffold)));
    }

    testWidgets('says what happened and runs the undo when tapped', (
      tester,
    ) async {
      final messenger = await pump(tester);
      var undone = 0;
      messenger.showUndoMessage('Excluded 2 games', () async => undone++);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Excluded 2 games'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(undone, 1);
    });

    // One second at a time, so the message gets frames to animate out in.
    Future<void> wait(WidgetTester tester, int seconds) async {
      for (var i = 0; i < seconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('stays 8 seconds, or as long as it is told to', (tester) async {
      final messenger = await pump(tester);
      messenger.showUndoMessage('Excluded', () async {});
      await tester.pump();
      await wait(tester, 7);
      expect(find.text('Excluded'), findsOneWidget);
      await wait(tester, 3);
      expect(find.text('Excluded'), findsNothing);

      messenger.showUndoMessage(
        'Correction saved',
        () async {},
        duration: AppTheme.toastUndoEdit,
      );
      await tester.pump();
      await wait(tester, 11);
      expect(find.text('Correction saved'), findsOneWidget);
      await wait(tester, 3);
      expect(find.text('Correction saved'), findsNothing);
    });

    testWidgets('says so when the undo fails', (tester) async {
      final messenger = await pump(tester);
      messenger.showUndoMessage('Done', () async => throw StateError('x'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text("Couldn't undo that."), findsOneWidget);
    });
  });

  group('excluding games from the list', () {
    final t0 = 1782090000;
    final matches = [
      for (var i = 0; i < 3; i++)
        buildMatch(
          start: t0 + i * 1500,
          rp: 20,
          cumulativeRp: 1020 + i * 20,
          // The newest is already left out.
          excluded: i == 2,
        ),
    ];

    Future<_RecordingStore> pumpList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = _RecordingStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rankedHistoryStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Scaffold(
              body: GamesList(
                matches: matches,
                onRefresh: () async {},
                averagePool: matches,
                selectable: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return store;
    }

    testWidgets('Undo puts back only the games the exclusion changed', (
      tester,
    ) async {
      final store = await pumpList(tester);
      // Select everything, the already-excluded game included.
      await tester.longPress(find.text('Axle').first);
      await tester.pump();
      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.tap(find.text('Exclude'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.calls.single.$2, isTrue);
      expect(store.calls.single.$1, hasLength(3));
      expect(find.text('Excluded 3 games'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();

      final undo = store.calls.last;
      expect(undo.$2, isFalse, reason: 'the reverse of the exclusion');
      expect(undo.$1, hasLength(2), reason: 'not the one already excluded');
      expect(undo.$1, isNot(contains(matches[2].id)));
    });
  });
}
