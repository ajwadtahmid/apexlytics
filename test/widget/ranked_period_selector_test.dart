import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:apexlytics/providers/ranked_provider.dart';
import 'package:apexlytics/screens/ranked/widgets/ranked_period_selector.dart';
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:apexlytics/widgets/control_pill.dart';

/// The split dropdown and the week dropdown in the Stats header: a thumb-sized
/// tap area behind a small pill, and chips a screen reader can tell apart.
void main() {
  final now = DateTime.now();
  const day = Duration(days: 1);

  RankedView viewWith({int weekIndex = -1, int splitCount = 1}) => RankedView(
    splits: [
      for (var i = 0; i < splitCount; i++)
        RankedSplitBucket(id: 'split_$i', displayName: 'Split $i'),
    ],
    effectiveSplitId: 'split_0',
    weeks: [
      WeekRange(start: now.subtract(day * 14), end: now.subtract(day * 7)),
      WeekRange(start: now.subtract(day * 7), end: now.add(day * 7)),
      WeekRange(start: now.add(day * 7), end: now.add(day * 14)),
    ],
    weekIndex: weekIndex,
    filtered: const [],
    history: const [],
  );

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  Future<ProviderContainer> pumpWeeks(
    WidgetTester tester, {
    int weekIndex = -1,
  }) => pump(tester, RankedWeekDropdown(view: viewWith(weekIndex: weekIndex)));

  group('the week dropdown', () {
    testWidgets('says which week is showing', (tester) async {
      await pumpWeeks(tester);
      expect(find.text('Week: All'), findsOneWidget);

      await pumpWeeks(tester, weekIndex: 1);
      expect(find.text('Week: 2'), findsOneWidget);
    });

    testWidgets('has a tap area at least as tall as a control pill', (
      tester,
    ) async {
      await pumpWeeks(tester);

      expect(
        tester.getSize(find.byType(GestureDetector).first).height,
        greaterThanOrEqualTo(ControlPill.minHitHeight),
      );
    });

    testWidgets('lists every week, and says when a coming one starts', (
      tester,
    ) async {
      await pumpWeeks(tester);
      await tester.tap(find.text('Week: All'));
      await tester.pumpAndSettle();

      final starts = DateFormat('MMM d').format(now.add(day * 7));
      expect(find.text('All weeks'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 2'), findsOneWidget);
      expect(find.text('Week 3'), findsOneWidget);
      expect(find.text('starts $starts'), findsOneWidget);
    });

    testWidgets('only select a week that has started', (tester) async {
      final container = await pumpWeeks(tester);

      await tester.tap(find.text('Week: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week 3'));
      await tester.pumpAndSettle();
      expect(container.read(rankedPeriodProvider).weekIndex, -1);

      // The sheet stays open on an unavailable week: pick a started one.
      await tester.tap(find.text('Week 1'));
      await tester.pumpAndSettle();
      expect(container.read(rankedPeriodProvider).weekIndex, 0);
      expect(find.text('All weeks'), findsNothing);
    });

    testWidgets('is not there for a split with no weeks', (tester) async {
      await pump(
        tester,
        const RankedWeekDropdown(
          view: RankedView(
            splits: [],
            effectiveSplitId: '',
            weeks: [],
            weekIndex: -1,
            filtered: [],
            history: [],
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  testWidgets('a long split name is cut, not pushed past the row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = previous);

    await pump(
      tester,
      SizedBox(
        width: 200,
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: RankedSplitDropdown(
                  view: RankedView(
                    splits: [
                      RankedSplitBucket(
                        id: 'a',
                        displayName: 'Season 31 (Split 1) with a long name',
                      ),
                      RankedSplitBucket(id: 'b', displayName: 'Season 30'),
                    ],
                    effectiveSplitId: 'a',
                    weeks: [],
                    weekIndex: -1,
                    filtered: [],
                    history: [],
                  ),
                ),
              ),
            ),
            RankedWeekDropdown(view: viewWith()),
          ],
        ),
      ),
    );

    expect(errors.where((e) => e.contains('overflowed')), isEmpty);
    expect(find.text('Week: All'), findsOneWidget);
  });

  testWidgets('the split dropdown has a tap area at least as tall as a control '
      'pill', (tester) async {
    await pump(tester, RankedSplitDropdown(view: viewWith(splitCount: 2)));

    expect(
      tester.getSize(find.byType(GestureDetector).first).height,
      greaterThanOrEqualTo(ControlPill.minHitHeight),
    );
  });

  group('the season sheet', () {
    RankedSplitBucket split(String id, String name) =>
        RankedSplitBucket(id: id, displayName: name);

    RankedView many({String selected = 'br_ranked_s30_s2'}) => RankedView(
      splits: [
        split(kLifetimeSplitId, 'Lifetime'),
        split('br_ranked_s31_s1', 'Season 31 (Split 1)'),
        split('br_ranked_s30_s2', 'Season 30 (Split 2)'),
        split('br_ranked_s30_s1', 'Season 30 (Split 1)'),
        split('br_ranked_s29_s2', 'Season 29 (Split 2)'),
      ],
      effectiveSplitId: selected,
      weeks: const [],
      weekIndex: -1,
      filtered: const [],
      history: const [],
    );

    testWidgets('lists Lifetime, then a row per season with its splits', (
      tester,
    ) async {
      await pump(tester, RankedSplitDropdown(view: many()));
      await tester.tap(find.text('Season 30 (Split 2)'));
      await tester.pumpAndSettle();

      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('Season 31'), findsOneWidget);
      expect(find.text('Season 30'), findsOneWidget);
      expect(find.text('Season 29'), findsOneWidget);
      // Season 30 has both splits, in order.
      expect(
        tester.getTopLeft(find.text('Split 1').at(1)).dx,
        lessThan(tester.getTopLeft(find.text('Split 2').first).dx),
      );
      // Newest season first.
      expect(
        tester.getTopLeft(find.text('Season 31')).dy,
        lessThan(tester.getTopLeft(find.text('Season 30')).dy),
      );
    });

    testWidgets('keeps each split in its own column, even in a season with '
        'only one', (tester) async {
      await pump(tester, RankedSplitDropdown(view: many()));
      await tester.tap(find.text('Season 30 (Split 2)'));
      await tester.pumpAndSettle();

      // Season 30 has both; Season 29 only has Split 2, under the same one.
      final splitTwo = find.text('Split 2');
      expect(splitTwo, findsNWidgets(2));
      expect(
        tester.getCenter(splitTwo.at(0)).dx,
        closeTo(tester.getCenter(splitTwo.at(1)).dx, 0.5),
      );
    });

    testWidgets('shows Lifetime as a button, ticked when it is the one in '
        'use', (tester) async {
      await pump(tester, RankedSplitDropdown(view: many()));
      await tester.tap(find.text('Season 30 (Split 2)'));
      await tester.pumpAndSettle();
      expect(find.text('BY SEASON'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      // Start over, so the first sheet is not still open.
      await tester.pumpWidget(const SizedBox());
      await pump(
        tester,
        RankedSplitDropdown(view: many(selected: kLifetimeSplitId)),
      );
      await tester.tap(find.text('Lifetime').first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('picks a split with one tap on its chip, and closes', (
      tester,
    ) async {
      final container = await pump(tester, RankedSplitDropdown(view: many()));
      await tester.tap(find.text('Season 30 (Split 2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Split 1').at(1)); // Season 30's
      await tester.pumpAndSettle();

      expect(container.read(rankedPeriodProvider).splitId, 'br_ranked_s30_s1');
      expect(find.text('Lifetime'), findsNothing);
    });

    testWidgets('Lifetime is one tap too', (tester) async {
      final container = await pump(tester, RankedSplitDropdown(view: many()));
      await tester.tap(find.text('Season 30 (Split 2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lifetime'));
      await tester.pumpAndSettle();

      expect(container.read(rankedPeriodProvider).splitId, kLifetimeSplitId);
    });
  });
}
