import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/screens/ranked/widgets/split_changes_card.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<RankedMatch> a,
    List<RankedMatch> b,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SplitChangesCard(
              legendsA: legendBreakdowns(a),
              legendsB: legendBreakdowns(b),
              mapsA: mapBreakdowns(a),
              mapsB: mapBreakdowns(b),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the legends and maps that moved most', (tester) async {
    await pump(
      tester,
      [
        ...buildMatches('Axle', 6, 10, map: 'olympus_rotation'),
        ...buildMatches('Bangalore', 4, 10, map: 'olympus_rotation'),
      ],
      [
        ...buildMatches('Axle', 2, -5, map: 'olympus_rotation'),
        ...buildMatches('Wraith', 8, -5, map: 'olympus_rotation'),
      ],
    );

    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Wraith'), findsOneWidget);
    expect(find.text('+80 pts'), findsOneWidget);
    expect(find.text('0% → 80%'), findsOneWidget);
    expect(find.text('-40 pts'), findsNWidgets(2));
    // Olympus went from +10 a game to -5.
    expect(find.text('Olympus'), findsOneWidget);
    expect(find.text('-15.0'), findsOneWidget);
    expect(find.text('+10.0 → -5.0'), findsOneWidget);
  });

  testWidgets('leaves out the map block when no map has enough games', (
    tester,
  ) async {
    await pump(
      tester,
      [...buildMatches('Axle', 2, 10, map: 'olympus_rotation')],
      [...buildMatches('Wraith', 2, 10, map: 'storm_point_rotation')],
    );

    expect(find.text('Legends picked differently'), findsOneWidget);
    expect(find.text('RP per game by map'), findsNothing);
  });

  testWidgets('is not there at all when nothing moved', (tester) async {
    final same = [...buildMatches('Axle', 4, 10, map: 'olympus_rotation')];
    await pump(tester, same, same);

    expect(find.text('What changed'), findsNothing);
  });
}
