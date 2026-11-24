import 'package:apexlytics/screens/ranked/widgets/ranked_period_sheets.dart';
import 'package:apexlytics/screens/ranked/widgets/unknown_season_note.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  RankedView view({
    int unknownGames = 12,
    String selected = 'br_ranked_s30_s2',
  }) {
    final splits = buildSplitBuckets({
      'br_ranked_s30_s2': 40,
      'br_ranked_s30_s1': 30,
      kUnknownSplitId: unknownGames,
    }, {});
    return RankedView(
      splits: splits,
      effectiveSplitId: selected,
      weeks: const [],
      weekIndex: -1,
      filtered: const [],
      gamesInPeriod: const [],
    );
  }

  Future<List<String>> openSheet(WidgetTester tester, RankedView v) async {
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showSplitSheet(context, view: v, onSelected: picked.add),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  group('the season sheet', () {
    testWidgets('lists games with no season as a quiet line with a count', (
      tester,
    ) async {
      await openSheet(tester, view());

      expect(find.text('Games with no season · 12'), findsOneWidget);
      // Not a row like the seasons.
      expect(find.text('Unknown'), findsNothing);
      final text = tester.widget<Text>(find.text('Games with no season · 12'));
      expect(text.style!.fontSize, lessThan(15));
    });

    testWidgets('keeps the line a full-height target', (tester) async {
      await openSheet(tester, view());

      final link = find.ancestor(
        of: find.text('Games with no season · 12'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(link.first).height, greaterThanOrEqualTo(44));
    });

    testWidgets('opens the unknown group when tapped', (tester) async {
      final picked = await openSheet(tester, view());

      await tester.tap(find.text('Games with no season · 12'));
      await tester.pumpAndSettle();

      expect(picked, [kUnknownSplitId]);
    });

    testWidgets('is not there when no game lacks a season', (tester) async {
      await openSheet(tester, view(unknownGames: 0));

      expect(find.textContaining('no season'), findsNothing);
    });

    testWidgets('shows a tick when it is the one in use', (tester) async {
      await openSheet(tester, view(selected: kUnknownSplitId));

      expect(find.byIcon(Icons.check), findsWidgets);
    });
  });

  test('the picker counts the games with no season', () {
    final unknown = buildSplitBuckets({
      'br_ranked_s30_s1': 3,
      kUnknownSplitId: 7,
    }, {}).firstWhere((b) => b.id == kUnknownSplitId);

    expect(unknown.games, 7);
  });

  testWidgets('the note says what the group is and where its games are', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UnknownSeasonNote(games: 12))),
    );

    expect(
      find.textContaining('12 ranked games could not be matched'),
      findsOneWidget,
    );
    expect(find.textContaining('Lifetime'), findsOneWidget);
    expect(find.textContaining('Games tab'), findsOneWidget);
  });
}
