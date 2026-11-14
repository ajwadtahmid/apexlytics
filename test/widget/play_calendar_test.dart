import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/screens/ranked/widgets/play_calendar_grid.dart';
import 'package:apexlytics/screens/ranked/widgets/session_card.dart';
import 'package:apexlytics/screens/ranked/widgets/sessions_overview.dart';
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  RankedMatch game(DateTime start, {int rp = 10}) => buildMatch(
    start: start.millisecondsSinceEpoch ~/ 1000,
    rp: rp,
    length: 600,
  );

  // A split that begins on a Tuesday at 10:00 and runs two weeks.
  final weeks = computeWeeks(
    SeasonMeta(
      id: 'br_ranked_s99_s1',
      displayName: 'S99',
      start: DateTime(2026, 11, 3, 10),
      end: DateTime(2026, 11, 17, 10),
    ),
  );

  // Four days with games, one session of which (the 5th) runs on past midnight
  // into the 6th.
  final all = sessionize([
    game(DateTime(2026, 11, 3, 20, 0), rp: 25),
    game(DateTime(2026, 11, 3, 20, 20), rp: 20),
    game(DateTime(2026, 11, 4, 19, 0), rp: -15),
    game(DateTime(2026, 11, 4, 19, 20), rp: -5),
    game(DateTime(2026, 11, 5, 23, 30), rp: 30),
    game(DateTime(2026, 11, 6, 0, 10), rp: 12),
  ]);

  Future<List<RankedSession>> pump(
    WidgetTester tester, {
    List<WeekRange>? weeksShown,
    List<RankedSession>? sessions,
    List<RankedSession>? splitSessions,
    int selectedWeek = -1,
  }) async {
    final opened = <RankedSession>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [await prefsOverride()],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionsOverview(
                sessions: sessions ?? all,
                onOpen: opened.add,
                weeks: weeksShown ?? weeks,
                splitSessions: splitSessions ?? all,
                selectedWeek: selectedWeek,
              ),
            ),
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('is a card of its own under the bars', (tester) async {
    await pump(tester);

    expect(find.text('RP PER SESSION'), findsOneWidget);
    expect(find.text('PLAY CALENDAR'), findsOneWidget);
    // Two cards, not a switch between views.
    expect(find.text('Calendar'), findsNothing);
    expect(
      tester.getTopLeft(find.text('PLAY CALENDAR')).dy,
      greaterThan(tester.getTopLeft(find.text('RP PER SESSION')).dy),
    );
  });

  testWidgets('has no calendar card without the split\'s weeks', (
    tester,
  ) async {
    await pump(tester, weeksShown: const []);

    expect(find.text('RP PER SESSION'), findsOneWidget);
    expect(find.text('PLAY CALENDAR'), findsNothing);
  });

  testWidgets('labels the weeks and starts the rows on the split\'s weekday', (
    tester,
  ) async {
    await pump(tester);

    // Weeks 1 and 2, and a Tuesday-first week.
    Finder inCalendar(Finder f) =>
        find.descendant(of: find.byType(PlayCalendar), matching: f);
    expect(inCalendar(find.text('1')), findsOneWidget);
    expect(inCalendar(find.text('2')), findsOneWidget);
    expect(inCalendar(find.text('3')), findsNothing);
    final texts = tester
        .widgetList<Text>(inCalendar(find.byType(Text)))
        .map((t) => t.data)
        .toList();
    final first = texts.indexOf('Tue');
    expect(texts.sublist(first, first + 7), [
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
      'Mon',
    ]);
    expect(inCalendar(find.text('Week')), findsOneWidget);
  });

  testWidgets('a played day opens its sessions, and a card opens the session', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final opened = await pump(tester);

    await tester.tap(find.bySemanticsLabel('Nov 3, +45 RP, 1 session'));
    await tester.pumpAndSettle();

    expect(find.text('Tuesday, Nov 3'), findsOneWidget);
    expect(find.text('2 games, 2W-0L · 1 session'), findsOneWidget);
    expect(find.textContaining('Only the games that started'), findsNothing);

    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.games, 2);
    // The sheet closed.
    expect(find.text('Tuesday, Nov 3'), findsNothing);
    handle.dispose();
  });

  testWidgets('a session past midnight shows each day its own games', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final opened = await pump(tester);

    await tester.tap(find.bySemanticsLabel('Nov 5, +30 RP, 1 session'));
    await tester.pumpAndSettle();

    expect(find.text('1 game, 1W-0L · 1 session'), findsOneWidget);
    expect(find.textContaining('Only the games that started'), findsOneWidget);

    // The card opens the whole session, both of its games.
    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();
    expect(opened.single.games, 2);
    handle.dispose();
  });

  testWidgets('a day with no games does nothing when tapped', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Nov 9, no games'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    handle.dispose();
  });

  testWidgets('draws the whole split whichever week the page shows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // The page's own sessions are two of the three; the calendar still has
    // every day of the split and outlines the chosen week.
    await pump(
      tester,
      sessions: all.take(2).toList(),
      splitSessions: all,
      selectedWeek: 1,
    );

    expect(find.bySemanticsLabel('Nov 3, +45 RP, 1 session'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('says so when there are too few days to show', (tester) async {
    // One session over two days: not enough to say anything.
    await pump(tester, splitSessions: all.take(1).toList());

    expect(find.textContaining('Not enough days yet'), findsOneWidget);
  });
}
