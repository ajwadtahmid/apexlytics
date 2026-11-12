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
        tester.getSize(find.byType(PopupMenuButton<int>)).height,
        greaterThanOrEqualTo(ControlPill.minHitHeight),
      );
    });

    testWidgets('lists every week, and says when a coming one starts', (
      tester,
    ) async {
      await pumpWeeks(tester);
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();

      final starts = DateFormat('MMM d').format(now.add(day * 7));
      expect(find.text('All weeks'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 2'), findsOneWidget);
      expect(find.text('Week 3, starts $starts'), findsOneWidget);
    });

    testWidgets('only select a week that has started', (tester) async {
      final container = await pumpWeeks(tester);

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Week 3'));
      await tester.pumpAndSettle();
      expect(container.read(rankedPeriodProvider).weekIndex, -1);

      // The menu stays open on an unavailable week: pick a started one.
      await tester.tap(find.text('Week 1'));
      await tester.pumpAndSettle();
      expect(container.read(rankedPeriodProvider).weekIndex, 0);
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
      expect(find.byType(PopupMenuButton<int>), findsNothing);
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
      tester.getSize(find.byType(PopupMenuButton<String>)).height,
      greaterThanOrEqualTo(ControlPill.minHitHeight),
    );
  });
}
