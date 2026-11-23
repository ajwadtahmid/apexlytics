import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/providers/squad_games_provider.dart';
import 'package:apexlytics/screens/ranked/squad_game_detail_screen.dart';
import 'package:apexlytics/screens/ranked/squad_games_screen.dart';
import 'package:apexlytics/screens/ranked/widgets/squad_table.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:apexlytics/utils/ranked/squad_games.dart';

import '../helpers.dart';

void main() {
  const splitId = 'br_ranked_s29_s2';
  final season = SeasonMeta(
    id: splitId,
    displayName: 'S29 Split 2',
    start: DateTime.utc(2026, 9, 1),
    end: DateTime.utc(2026, 11, 1),
  );
  final view = RankedView(
    splits: [
      RankedSplitBucket(
        id: splitId,
        displayName: 'S29 Split 2',
        season: season,
      ),
    ],
    effectiveSplitId: splitId,
    weeks: const [],
    weekIndex: -1,
    filtered: const [],
    history: const [],
  );

  const base = 1782090000;

  /// [uid]'s ranked game [at] seconds after the base time.
  RankedMatch game(
    String uid,
    int at, {
    String legend = 'Wraith',
    int rp = 20,
    int? kills,
    int? damage,
    String map = 'olympus_rotation',
  }) => buildMatch(
    uid: uid,
    start: base + at,
    legend: legend,
    rp: rp,
    kills: kills,
    damage: damage,
    map: map,
  );

  /// Lets a route or sheet finish sliding in or out, a few frames at a time:
  /// the page has no spinner once its games are in, but a fixed count of frames
  /// keeps this from ever waiting on one.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  const names = {'1': 'Alpha', '2': 'Bravo', '3': 'Charlie', '4': 'Delta'};

  Future<List<String>> pump(
    WidgetTester tester, {
    required List<SquadGame> shared,
    List<String> saved = const ['1', '2', '3'],
    Widget Function(RankedView view)? home,
    String uid = '1',
  }) async {
    SharedPreferences.setMockInitialValues({
      'player_profiles': jsonEncode([
        for (final id in saved)
          {'name': names[id], 'uid': id, 'platform': 'PC'},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final asked = <String>[];
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          squadGamesProvider.overrideWith((ref, id) async {
            asked.add(id);
            return shared;
          }),
        ],
        child: MaterialApp(
          home: home != null
              ? home(view)
              : SquadGamesScreen(uid: uid, view: view),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return asked;
  }

  group('the entry tile', () {
    Future<void> pumpEntry(
      WidgetTester tester,
      List<String> saved, {
      String uid = '1',
    }) => pump(
      tester,
      shared: const [],
      saved: saved,
      home: (v) => Scaffold(
        body: SquadGamesEntry(uid: uid, view: v),
      ),
    );

    testWidgets('is hidden with one saved profile', (tester) async {
      await pumpEntry(tester, ['1']);
      expect(find.text('Squad Games'), findsNothing);
    });

    testWidgets('shows with two saved profiles', (tester) async {
      await pumpEntry(tester, ['1', '2']);
      expect(find.text('Squad Games'), findsOneWidget);
    });

    testWidgets('is hidden for a player who is not a saved profile', (
      tester,
    ) async {
      await pumpEntry(tester, ['1', '2'], uid: '9');
      expect(find.text('Squad Games'), findsNothing);
    });

    testWidgets('opens the page', (tester) async {
      await pumpEntry(tester, ['1', '2']);
      await tester.tap(find.text('Squad Games'));
      await settle(tester);
      expect(find.text('No games together'), findsOneWidget);
    });
  });

  group('the page with two profiles', () {
    testWidgets('lists a game they played together', (tester) async {
      await pump(
        tester,
        saved: const ['1', '2'],
        shared: [
          SquadGame({
            '1': game('1', 0, legend: 'Wraith', rp: 25, kills: 3),
            '2': game('2', 10, legend: 'Octane', rp: -12, kills: 1),
          }),
        ],
      );
      expect(find.text('Olympus'), findsOneWidget);
      expect(find.text('GAMES · 1'), findsOneWidget);
      expect(find.text('+25'), findsWidgets);
      expect(find.text('-12'), findsWidgets);
      // Two profiles: no mode switch and no duo or trio tags.
      expect(find.text('3 profiles'), findsNothing);
      expect(find.text('TRIO'), findsNothing);
    });

    testWidgets('summarises each profile over the games on show', (
      tester,
    ) async {
      await pump(
        tester,
        saved: const ['1', '2'],
        shared: [
          SquadGame({
            '1': game('1', 0, rp: 30, kills: 4, damage: 1000),
            '2': game('2', 10, rp: -10, kills: 2, damage: 500),
          }),
          SquadGame({
            '1': game('1', 5000, rp: 10, kills: 2, damage: 600),
            '2': game('2', 5010, rp: -20, kills: 0, damage: 300),
          }),
        ],
      );
      expect(find.text('TOGETHER'), findsOneWidget);
      expect(find.text('2 games'), findsOneWidget);
      // Net RP, then average kills: 40 and -30, 3.0 and 1.0.
      expect(find.text('+40'), findsOneWidget);
      expect(find.text('-30'), findsOneWidget);
      expect(find.text('3.0'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
    });

    testWidgets('says so when none of the games line up', (tester) async {
      await pump(tester, saved: const ['1', '2'], shared: const []);
      expect(find.text('No games together'), findsOneWidget);
    });

    testWidgets('only shows games both profiles were in', (tester) async {
      await pump(
        tester,
        saved: const ['1', '2', '3'],
        shared: [
          SquadGame({'1': game('1', 0), '3': game('3', 5)}),
          SquadGame({'1': game('1', 5000), '2': game('2', 5005)}),
        ],
      );
      // Alpha and Bravo: only the second game.
      expect(find.text('GAMES · 1'), findsOneWidget);
    });

    testWidgets('says who else was in the game with a short count', (
      tester,
    ) async {
      await pump(
        tester,
        saved: const ['1', '2', '3'],
        shared: [
          SquadGame({'1': game('1', 0), '2': game('2', 5), '3': game('3', 8)}),
        ],
      );
      expect(find.text('+1 more'), findsOneWidget);
      // The name is not on the row.
      expect(find.text('Charlie'), findsNothing);
    });

    testWidgets('starts on the period the Stats page shows', (tester) async {
      final asked = await pump(
        tester,
        saved: const ['1', '2'],
        shared: const [],
      );
      expect(asked, [splitId]);
      expect(find.text('S29 Split 2'), findsWidgets);
    });
  });

  group('the info button', () {
    testWidgets('opens a sheet with a warning that it may not be accurate', (
      tester,
    ) async {
      await pump(tester, saved: const ['1', '2'], shared: const []);
      await tester.tap(find.byIcon(Icons.info_outline));
      await settle(tester);

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('may not be fully accurate'), findsOneWidget);
      expect(find.textContaining('start and end times'), findsOneWidget);
    });

    testWidgets('is on the page, labelled for a screen reader', (tester) async {
      await pump(tester, saved: const ['1', '2'], shared: const []);
      expect(find.byTooltip('How to read this'), findsOneWidget);
    });
  });

  group('the profile slots', () {
    testWidgets('the first is the player on screen and cannot be changed', (
      tester,
    ) async {
      await pump(tester, saved: const ['1', '2'], shared: const []);
      await tester.tap(find.text('Alpha'));
      await settle(tester);
      expect(find.text('Profile 1'), findsNothing);
      // Only the second slot has a drop-down arrow.
      Finder arrowIn(String name) => find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)),
        matching: find.byIcon(Icons.arrow_drop_down),
      );
      expect(arrowIn('Alpha'), findsNothing);
      expect(arrowIn('Bravo'), findsOneWidget);
    });

    testWidgets('the second opens a list without the first', (tester) async {
      await pump(tester, saved: const ['1', '2', '3'], shared: const []);
      await tester.tap(find.text('Bravo').first);
      await settle(tester);
      expect(find.text('Profile 2'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      // Alpha is on screen already, so it is not on offer: only the slot bar
      // shows it.
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('choosing another profile changes the games shown', (
      tester,
    ) async {
      await pump(
        tester,
        saved: const ['1', '2', '3'],
        shared: [
          SquadGame({'1': game('1', 0), '2': game('2', 5)}),
          SquadGame({'1': game('1', 5000), '3': game('3', 5005)}),
          SquadGame({'1': game('1', 9000), '3': game('3', 9005)}),
        ],
      );
      expect(find.text('GAMES · 1'), findsOneWidget);
      await tester.tap(find.text('Bravo').first);
      await settle(tester);
      await tester.tap(find.text('Charlie').last);
      await settle(tester);
      expect(find.text('GAMES · 2'), findsOneWidget);
    });
  });

  group('the page with three profiles', () {
    final shared = [
      SquadGame({'1': game('1', 0), '2': game('2', 5), '3': game('3', 8)}),
      SquadGame({'1': game('1', 5000), '2': game('2', 5005)}),
    ];

    Future<void> three(WidgetTester tester) async {
      await pump(tester, saved: const ['1', '2', '3'], shared: shared);
      await tester.tap(find.text('3 profiles'));
      await settle(tester);
    }

    testWidgets('a profile\'s full name is on its slot, and the diamond '
        'carries no letter', (tester) async {
      await three(tester);
      expect(find.byTooltip('Charlie'), findsOneWidget);
      // The square and the circle keep their letters; the diamond has no room.
      expect(find.text('A'), findsWidgets);
      expect(find.text('B'), findsWidgets);
      expect(find.text('C'), findsNothing);
    });

    testWidgets('lists trios and duos and tags each', (tester) async {
      await three(tester);
      expect(find.text('GAMES · 2'), findsOneWidget);
      expect(find.text('TRIO'), findsOneWidget);
      expect(find.text('DUO'), findsOneWidget);
      expect(find.text('2 games · 1 trio · 1 duo'), findsOneWidget);
    });

    testWidgets('a profile that was not in a game is left out of its row', (
      tester,
    ) async {
      await three(tester);
      expect(find.textContaining('not in this game'), findsNothing);
    });

    testWidgets('"Trios only" keeps the trios, and can be turned off', (
      tester,
    ) async {
      await three(tester);
      await tester.tap(find.text('Trios only'));
      await settle(tester);
      expect(find.text('GAMES · 1'), findsOneWidget);
      expect(find.text('DUO'), findsNothing);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      await tester.tap(find.text('Trios only'));
      await settle(tester);
      expect(find.text('GAMES · 2'), findsOneWidget);
    });

    testWidgets(
      '"Trios only" with no trio says so, not that nothing lined up',
      (tester) async {
        await pump(
          tester,
          saved: const ['1', '2', '3'],
          shared: [
            SquadGame({'1': game('1', 0), '2': game('2', 5)}),
          ],
        );
        await tester.tap(find.text('3 profiles'));
        await settle(tester);
        await tester.tap(find.text('Trios only'));
        await settle(tester);
        expect(find.text('No trios in this period'), findsOneWidget);
        expect(find.text('No games together'), findsNothing);
      },
    );

    testWidgets('a profile with no games shows no reading, not a zero gain, and '
        'the average keeps its decimal', (tester) async {
      await pump(
        tester,
        saved: const ['1', '2', '3'],
        shared: [
          SquadGame({'1': game('1', 0, rp: 10), '2': game('2', 5, rp: 0)}),
          SquadGame({'1': game('1', 5000, rp: 5), '2': game('2', 5005, rp: 0)}),
        ],
      );
      await tester.tap(find.text('3 profiles'));
      await settle(tester);

      // In the table: Net RP is +15, +0 for the one that played and a dash for
      // the third; Avg RP is 7.5, not 8.
      Finder inTable(String text) => find.descendant(
        of: find.byType(SquadTable),
        matching: find.text(text),
      );
      expect(inTable('+15'), findsOneWidget);
      expect(inTable('+0'), findsOneWidget);
      expect(inTable('+7.5'), findsOneWidget);
      expect(inTable('+8'), findsNothing);
    });

    testWidgets('a total is only outlined when the game counts match', (
      tester,
    ) async {
      await three(tester);
      // Alpha and Bravo played two games each, Charlie one: an average RP row
      // stands in for the total's lead.
      expect(find.text('Avg RP'), findsOneWidget);
    });

    testWidgets('picking the profile in the other slot swaps them', (
      tester,
    ) async {
      await three(tester);
      // Slots: Alpha, Bravo, Charlie. Put Charlie second.
      await tester.tap(find.text('Bravo').first);
      await settle(tester);
      await tester.tap(find.text('Charlie').last);
      await settle(tester);
      final bravo = tester.getTopLeft(find.text('Bravo').first).dx;
      final charlie = tester.getTopLeft(find.text('Charlie').first).dx;
      expect(charlie, lessThan(bravo));
    });

    testWidgets('is not offered with only two saved profiles', (tester) async {
      await pump(tester, saved: const ['1', '2'], shared: shared);
      expect(find.text('3 profiles'), findsNothing);
      expect(find.text('Trios only'), findsNothing);
    });
  });

  group('a game\'s page', () {
    testWidgets('opens from the list and shows each profile\'s figures', (
      tester,
    ) async {
      await pump(
        tester,
        saved: const ['1', '2'],
        shared: [
          SquadGame({
            '1': game('1', 0, legend: 'Wraith', rp: 30, kills: 5, damage: 1500),
            '2': game('2', 20, legend: 'Octane', rp: -8, kills: 1, damage: 200),
          }),
        ],
      );
      await tester.tap(find.text('Olympus'));
      await tester.pump();
      await settle(tester);
      // The list stays under the page, so look only inside the page itself.
      Finder onPage(String text) => find.descendant(
        of: find.byType(SquadGameDetailScreen),
        matching: find.text(text),
      );
      expect(onPage('Duo game'), findsOneWidget);
      expect(onPage('SQUAD'), findsOneWidget);
      expect(onPage('Wraith'), findsOneWidget);
      expect(onPage('Octane'), findsOneWidget);
      expect(onPage('1,500'), findsOneWidget);
      expect(onPage('+30'), findsOneWidget);
      expect(onPage('-8'), findsOneWidget);
      expect(onPage('6 kills · 1,700 damage'), findsOneWidget);
    });

    testWidgets('says how the match was made', (tester) async {
      await pump(
        tester,
        saved: const ['1', '2'],
        shared: [
          SquadGame({'1': game('1', 0), '2': game('2', 20)}),
        ],
      );
      await tester.tap(find.text('Olympus'));
      await tester.pump();
      await settle(tester);
      expect(find.text('Close match'), findsOneWidget);
      expect(find.textContaining('Starts 20s apart'), findsOneWidget);
    });

    testWidgets('a game with no tracker reading shows a dash', (tester) async {
      await pump(
        tester,
        saved: const ['1', '2'],
        shared: [
          SquadGame({'1': game('1', 0), '2': game('2', 20)}),
        ],
      );
      await tester.tap(find.text('Olympus'));
      await tester.pump();
      await settle(tester);
      expect(find.text('–'), findsWidgets);
    });

    testWidgets('names a saved profile that was in it too', (tester) async {
      final match = SquadGame({
        '1': game('1', 0),
        '2': game('2', 5),
        '3': game('3', 8),
      });
      await pump(
        tester,
        saved: const ['1', '2', '3'],
        shared: const [],
        home: (_) => SquadGameDetailScreen(
          match: match,
          slots: const ['1', '2'],
          names: names,
        ),
      );
      expect(find.text('Trio game'), findsOneWidget);
      expect(find.text('Also in this game: Charlie'), findsOneWidget);
    });
  });
}
