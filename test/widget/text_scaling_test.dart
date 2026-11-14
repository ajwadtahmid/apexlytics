import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/screens/home/widgets/map_rotation_card.dart';
import 'package:apexlytics/screens/ranked/widgets/sessions_overview.dart';
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:apexlytics/widgets/nav_entry_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Things that sit in a fixed space (a column, a half-width tile, a four-way
/// row) and have to give way when the system text size is raised.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, double scale) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [await prefsOverride()],
        child: MaterialApp(
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: app!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  group('a half-width tile', () {
    Widget tile() => Row(
      children: [
        Expanded(
          child: NavEntryCard(
            icon: Icons.schedule,
            title: 'Performance Trends',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox()),
      ],
    );

    testWidgets('keeps its title beside the icon at the normal size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, tile(), 1);

      expect(
        tester.getTopLeft(find.text('Performance Trends')).dy,
        closeTo(tester.getTopLeft(find.byIcon(Icons.schedule)).dy, 25),
      );
      expect(
        tester.getTopLeft(find.text('Performance Trends')).dx,
        greaterThan(tester.getTopRight(find.byIcon(Icons.schedule)).dx),
      );
    });

    testWidgets('puts its title under the icon at a large size, so a word '
        'is not broken', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, tile(), 1.5);

      expect(
        tester.getTopLeft(find.text('Performance Trends')).dy,
        greaterThan(tester.getBottomLeft(find.byIcon(Icons.schedule)).dy),
      );
    });
  });

  group('the Home mode pill', () {
    MapMode mode(String map, {int remaining = 0}) => MapMode(
      map: map,
      remainingSecs: remaining,
      durationMins: 60,
      asset: '',
    );

    final rotation = MapRotation(
      battleRoyaleCurrent: mode('Olympus', remaining: 60),
      battleRoyaleNext: mode('Storm Point'),
      rankedCurrent: mode('Olympus', remaining: 60),
      rankedNext: mode('Storm Point'),
      wildcardCurrent: mode('Olympus', remaining: 60),
      wildcardNext: mode('Storm Point'),
      ltmCurrent: mode('Olympus', remaining: 60),
      ltmNext: mode('Storm Point'),
    );

    double labelScale(WidgetTester tester) =>
        MediaQuery.textScalerOf(
          tester.element(find.text('Wildcards')),
        ).scale(10) /
        10;

    testWidgets('follows the text size up to 1.3x, then stops', (tester) async {
      await pump(tester, MapRotationCard(rotation: rotation), 1.15);
      expect(labelScale(tester), closeTo(1.15, 0.001));

      await pump(tester, MapRotationCard(rotation: rotation), 1.5);
      expect(labelScale(tester), closeTo(1.3, 0.001));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the Sessions summary strip and calendar', () {
    final weeks = computeWeeks(
      SeasonMeta(
        id: 'br_ranked_s99_s1',
        displayName: 'S99',
        start: DateTime(2026, 11, 3, 10),
        end: DateTime(2026, 11, 17, 10),
      ),
    );
    final played = sessionize([
      for (var d = 0; d < 4; d++)
        for (var g = 0; g < 2; g++)
          buildMatch(
            rp: g.isEven ? 25 : -12,
            start:
                DateTime(2026, 11, 3 + d, 20, g * 20).millisecondsSinceEpoch ~/
                1000,
            length: 600,
          ),
    ]);

    Widget overview() => SessionsOverview(
      sessions: played,
      onOpen: (_) {},
      weeks: weeks,
      splitSessions: played,
    );

    testWidgets('let a stat label take two lines', (tester) async {
      await pump(tester, overview(), 1.5);

      expect(tester.widget<Text>(find.text('games each')).maxLines, 2);
    });

    testWidgets('give the day names a column that grows with the text', (
      tester,
    ) async {
      double columnWidth() => tester
          .widget<SizedBox>(
            find.ancestor(
              of: find.text('Week'),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width != null,
              ),
            ),
          )
          .width!;

      await pump(tester, overview(), 1);
      expect(columnWidth(), 30);

      await pump(tester, overview(), 1.5);
      expect(columnWidth(), 45);
    });
  });
}
