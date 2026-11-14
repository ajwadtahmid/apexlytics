import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/screens/ranked/widgets/match_detail_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RankedMatch game({int start = 1782090000}) => RankedMatch.fromJson({
    'uid': '1',
    'name': 'Tester',
    'legendPlayed': 'Axle',
    'gameMode': 'BATTLE_ROYALE',
    'gameLengthSecs': 600,
    'gameStartTimestamp': start,
    'gameEndTimestamp': start + 600,
    'gameData': [
      {'key': 'kills', 'value': 3, 'name': 'BR Kills'},
      {'key': 'damage', 'value': 1145, 'name': 'BR Damage'},
      {'key': 'dome', 'value': 486, 'name': 'Dome: Damage blocked'},
    ],
    'BRScoreChange': 10,
    'BRScore': 1000,
    'BRRankImg': 'https://x/diamond4.png',
    'isPartyFull': false,
    'map': 'olympus_rotation',
  });

  Future<void> open(WidgetTester tester, List<RankedMatch> matches) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showMatchDetailSheet(context, matches: matches, index: 0),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('kills and damage are in the tiles only, not listed again', (
    tester,
  ) async {
    await open(tester, [game()]);

    expect(find.text('Kills'), findsOneWidget);
    expect(find.text('Damage'), findsOneWidget);
    expect(find.text('BR Kills'), findsNothing);
    expect(find.text('BR Damage'), findsNothing);
    // What the tiles do not show stays in the list.
    expect(find.text('Dome: Damage blocked'), findsOneWidget);
  });

  testWidgets('the sheet has a drag handle', (tester) async {
    await open(tester, [game()]);

    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DragHandle'),
      findsOneWidget,
    );
  });

  testWidgets('the paging arrows are full-size buttons', (tester) async {
    await open(tester, [game(), game(start: 1782100000)]);

    for (final tooltip in ['Next match', 'Previous match']) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(40), reason: tooltip);
      expect(size.height, greaterThanOrEqualTo(40), reason: tooltip);
    }
  });
}
