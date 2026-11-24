import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apexlytics/constants/rank_constants.dart';
import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/providers/rank_climb_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/screens/ranked/ranked_climb_screen.dart';
import 'package:apexlytics/utils/ranked/rank_climb.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';

import '../helpers.dart';

void main() {
  const current = 'br_ranked_s29_s2';
  const earlier = 'br_ranked_s29_s1';
  const base = 1782090000;

  int rp(String label) => kRankLadder.firstWhere((d) => d.label == label).rp;

  /// Ranked games ending on the given RP totals, from [start].
  List<RankedMatch> games(int start, List<int> totals, {int kills = 3}) {
    var before = start;
    final out = <RankedMatch>[];
    for (final (i, t) in totals.indexed) {
      out.add(
        buildMatch(
          uid: '1',
          start: base + i * 1200,
          length: 600,
          rp: t - before,
          cumulativeRp: t,
          legend: 'Wraith',
          kills: kills,
          damage: 500,
        ),
      );
      before = t;
    }
    return out;
  }

  // Silver I, up to Gold for the first time, back down to Silver, up again, and
  // on to Gold III.
  final gold = rp('Gold IV');
  final journey = games(rp('Silver I') + 650, [
    gold - 40,
    gold + 10,
    gold - 10,
    gold + 30,
    rp('Gold III') + 20,
  ]);

  final splits = [
    const RankedSplitBucket(id: current, displayName: 'S29 Split 2'),
    const RankedSplitBucket(id: earlier, displayName: 'S29 Split 1'),
  ];
  RankedView view({String id = current}) => RankedView(
    splits: splits,
    effectiveSplitId: id,
    weeks: const [],
    weekIndex: -1,
    filtered: const [],
    gamesInPeriod: const [],
  );

  Future<List<String>> pump(
    WidgetTester tester, {
    List<RankedMatch>? matches,
    RankedView? shown,
    Widget Function(RankedView view)? home,
    Object? error,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final asked = <String>[];
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v = shown ?? view();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rankClimbProvider.overrideWith((ref, arg) async {
            asked.add(arg.splitId);
            if (error != null) throw error;
            return RankClimb.of(matches ?? journey);
          }),
        ],
        child: MaterialApp(
          home: home != null ? home(v) : RankedClimbScreen(uid: '1', view: v),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return asked;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('the entry tile', () {
    testWidgets('is called The Journey and opens the page', (tester) async {
      await pump(
        tester,
        home: (v) => Scaffold(
          body: RankedClimbEntry(uid: '1', view: v),
        ),
      );
      expect(find.text('The Journey'), findsWidgets);
      await tester.tap(find.text('The Journey').first);
      await settle(tester);
      expect(find.text('RP THROUGH THE SPLIT'), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('shows where you stand', (tester) async {
      await pump(tester);
      expect(find.text('Gold III'), findsWidgets);
      expect(find.textContaining('RP to Gold II'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // games
    });

    testWidgets('starts on the season the Stats page shows', (tester) async {
      final asked = await pump(tester, shown: view(id: earlier));
      expect(asked, [earlier]);
      expect(find.text('S29 Split 1'), findsOneWidget);
    });

    testWidgets('falls back to the newest season from Lifetime', (
      tester,
    ) async {
      final asked = await pump(tester, shown: view(id: kLifetimeSplitId));
      expect(asked, [current]);
    });

    testWidgets('changing the season asks for that season', (tester) async {
      final asked = await pump(tester);
      await tester.tap(find.text('S29 Split 2'));
      await settle(tester);
      await tester.tap(find.text('Split 1'));
      await settle(tester);
      expect(asked.last, earlier);
    });

    testWidgets('says so when there are no ranked games', (tester) async {
      await pump(tester, matches: const []);
      expect(find.text('No journey to show yet'), findsOneWidget);
      expect(find.text('Timeline'), findsNothing);
    });

    testWidgets('shows an error with a way to retry', (tester) async {
      await pump(tester, error: Exception('boom'));
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('a split that is over', () {
    // A newer split exists, so the one shown is over.
    testWidgets('says where it finished, not what is left to climb', (
      tester,
    ) async {
      await pump(tester, shown: view(id: earlier));
      expect(find.textContaining('Finished the split in Gold III'), findsOne);
      expect(find.textContaining('RP to Gold II'), findsNothing);
    });

    testWidgets('the newest split is still climbing', (tester) async {
      await pump(tester);
      expect(find.textContaining('Finished the split'), findsNothing);
      expect(find.textContaining('RP to Gold II'), findsOneWidget);
    });
  });

  group('the games behind a move', () {
    testWidgets('open that game\'s own page when tapped', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Reached Gold'));
      await settle(tester);
      await tester.tap(find.textContaining('Game 1 ·').first);
      await settle(tester);
      // The game's own sheet (its stat tiles) is on screen, over the games list.
      expect(find.byType(BottomSheet), findsNWidgets(2));
      expect(find.text('Damage'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('open on Timeline, with Divisions second', (tester) async {
      await pump(tester);
      expect(find.text('THE TIMELINE'), findsOneWidget);
      expect(find.text('TIME IN EACH DIVISION'), findsNothing);
      final moves = tester.getTopLeft(find.text('Timeline')).dx;
      final divisions = tester.getTopLeft(find.text('Divisions')).dx;
      expect(moves, lessThan(divisions));
    });

    testWidgets('switch to the divisions', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Divisions'));
      await settle(tester);
      expect(find.text('TIME IN EACH DIVISION'), findsOneWidget);
      expect(find.text('THE TIMELINE'), findsNothing);
    });

    testWidgets('show a row for each division reached', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Divisions'));
      await settle(tester);
      // Silver I, Gold IV and Gold III.
      expect(find.text('3 divisions'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
    });
  });

  group('the moves', () {
    // The page opens on the moves.
    Future<void> openMoves(WidgetTester tester) => pump(tester);

    testWidgets('count the ups and downs', (tester) async {
      await openMoves(tester);
      expect(find.text('UPS AND DOWNS'), findsOneWidget);
      expect(find.text('↑ 3'), findsOneWidget);
      expect(find.text('↓ 1'), findsOneWidget);
    });

    testWidgets('list every move, each as it happened', (tester) async {
      await openMoves(tester);
      expect(find.text('Reached Gold'), findsOneWidget);
      expect(find.text('Dropped back to Silver'), findsOneWidget);
      expect(find.text('Back in Gold'), findsOneWidget);
      expect(find.textContaining('Up to Gold III'), findsOneWidget);
      expect(find.text('FIRST'), findsOneWidget);
    });

    testWidgets('start with the filter off, and narrow to tier changes', (
      tester,
    ) async {
      await openMoves(tester);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isFalse,
      );
      expect(find.textContaining('Up to Gold III'), findsOneWidget);

      await tester.tap(find.text('Tier changes only'));
      await settle(tester);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      expect(find.textContaining('Up to Gold III'), findsNothing);
      expect(find.textContaining('division move in between'), findsOneWidget);
      expect(find.text('Reached Gold'), findsOneWidget);
    });

    testWidgets('say what a tier change cost or gained', (tester) async {
      await openMoves(tester);
      expect(find.textContaining('Since the start:'), findsOneWidget);
      expect(find.textContaining('Since the last tier change:'), findsWidgets);
    });

    testWidgets('open the games that caused a move', (tester) async {
      await openMoves(tester);
      await tester.tap(find.text('Reached Gold'));
      await settle(tester);
      expect(find.text('THIS MOVED YOU'), findsOneWidget);
      expect(find.textContaining('SINCE THE SPLIT BEGAN'), findsOneWidget);
      // The whole heading is in capitals, the plural included.
      expect(find.textContaining('GAMEs'), findsNothing);
    });

    testWidgets('say so when nothing has moved', (tester) async {
      await pump(
        tester,
        matches: games(rp('Gold IV') + 50, [rp('Gold IV') + 80]),
      );
      expect(find.textContaining('No rank changes yet'), findsOneWidget);
    });
  });
}
