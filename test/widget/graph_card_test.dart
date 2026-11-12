import 'package:fl_chart/fl_chart.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/utils/formatting/snapshot_types.dart';
import 'package:apexlytics/widgets/graph_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A split that began ten days ago, so the current week is its second and
  // the first week's snapshot is the baseline.
  final now = DateTime.now();
  final started = now.subtract(const Duration(days: 10));
  final season = SeasonMeta.fromApi(
    id: 'br_ranked_s30_s1',
    startSeconds: started.millisecondsSinceEpoch ~/ 1000,
    endSeconds:
        now.add(const Duration(days: 40)).millisecondsSinceEpoch ~/ 1000,
  );
  final lastWeek = StatSnapshot(
    timestamp: started.add(const Duration(hours: 2)),
    rp: 8000,
    seasonId: season.id,
  );

  Future<void> pump(
    WidgetTester tester, {
    required int? currentRp,
    List<StatSnapshot> thisWeek = const [],
  }) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GraphCard(
              snapshots: [lastWeek, ...thisWeek],
              currentSeason: season,
              allSeasons: {season.id: season},
              currentRp: currentRp,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a live reading of 0 is not reported as losing the whole '
      'week\'s RP', (tester) async {
    // `/bridge` sometimes reports rankScore 0 around a rollover.
    await pump(tester, currentRp: 0);

    expect(find.textContaining('8,000 RP'), findsNothing);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('a real live reading still counts', (tester) async {
    await pump(tester, currentRp: 8100);
    expect(find.text('+100 RP this week'), findsOneWidget);
  });

  testWidgets('a real fall to 0 on a fresh account is still shown', (
    tester,
  ) async {
    // No snapshot has scored, so there is nothing a 0 could be a glitch of.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GraphCard(
              snapshots: [
                StatSnapshot(
                  timestamp: lastWeek.timestamp,
                  rp: 0,
                  seasonId: season.id,
                ),
              ],
              currentSeason: season,
              allSeasons: {season.id: season},
              currentRp: 0,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('8,000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the chart area', () {
    double chartHeight(WidgetTester tester) =>
        tester.getSize(find.byType(LineChart)).height;

    testWidgets('is short when the week has a single point', (tester) async {
      // Only the live reading is in the current week.
      await pump(tester, currentRp: 8100);

      expect(chartHeight(tester), lessThan(60));
    });

    testWidgets('keeps its usual height once there is a line to draw', (
      tester,
    ) async {
      await pump(
        tester,
        currentRp: 8300,
        thisWeek: [
          StatSnapshot(
            timestamp: now.subtract(const Duration(hours: 5)),
            rp: 8100,
            seasonId: season.id,
          ),
        ],
      );

      expect(chartHeight(tester), 110);
    });
  });
}
