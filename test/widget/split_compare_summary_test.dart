import 'package:apexlytics/providers/ranked_provider.dart';
import 'package:apexlytics/screens/ranked/ranked_compare_screen.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Summary table of the Splits comparison: Net RP is how far the ladder
/// moved, and the games' own sum is shown beside it when it is not the same.
void main() {
  RankedSplitDetail detail({required int netRp, int? ladderRp}) => (
    summary: RankedSummary(
      games: 10,
      netRp: netRp,
      ladderRp: ladderRp,
      currentRp: 1000,
      latestRankImg: '',
      totalKills: 20,
      totalDamage: 5000,
      killsGames: 10,
      damageGames: 10,
      totalLengthSecs: 6000,
      wins: 5,
      losses: 5,
    ),
    legends: const [],
    maps: const [],
    legendMap: const [],
    timeOfDay: const [],
    dayOfWeek: const [],
  );

  const bucketA = RankedSplitBucket(id: 'a', displayName: 'S31 Split 1');
  const bucketB = RankedSplitBucket(id: 'b', displayName: 'S30 Split 2');

  Future<void> pump(
    WidgetTester tester,
    RankedSplitDetail a,
    RankedSplitDetail b,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SplitCompareSummary(
              bucketA: bucketA,
              bucketB: bucketB,
              nameA: 'S31 Split 1',
              nameB: 'S30 Split 2',
              a: a,
              b: b,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the ladder gain as Net RP and the games sum as Games RP '
      'when they differ', (tester) async {
    await pump(
      tester,
      detail(netRp: 90, ladderRp: 120),
      detail(netRp: 40, ladderRp: 40),
    );

    expect(find.text('Net RP'), findsOneWidget);
    expect(find.text('+120'), findsOneWidget);
    expect(find.text('Games RP'), findsOneWidget);
    expect(find.text('+90'), findsOneWidget);
    expect(find.textContaining('left out of the count'), findsOneWidget);
    // Avg RP stays the average of the counted games: 90 over 10.
    expect(find.text('+9.0'), findsOneWidget);
  });

  testWidgets('says nothing more when the two figures are the same', (
    tester,
  ) async {
    await pump(tester, detail(netRp: 90, ladderRp: 90), detail(netRp: 40));

    expect(find.text('Net RP'), findsOneWidget);
    expect(find.text('Games RP'), findsNothing);
    expect(find.textContaining('left out of the count'), findsNothing);
  });
}
