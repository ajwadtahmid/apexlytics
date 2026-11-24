import 'package:apexlytics/screens/ranked/widgets/coverage_pill.dart';
import 'package:apexlytics/utils/ranked/split_coverage.dart';
import 'package:apexlytics/widgets/control_pill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final from = DateTime.utc(2026, 11, 6, 23, 0);
  final to = DateTime.utc(2026, 11, 7, 1, 0);

  Future<void> pump(WidgetTester tester, SplitCoverage coverage) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('This split')),
              CoveragePill(coverage: coverage, recorded: 214),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows nothing when the record is whole', (tester) async {
    await pump(tester, const SplitCoverage([]));
    expect(find.textContaining('missing'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('says how many are missing at least, and opens the gaps', (
    tester,
  ) async {
    await pump(
      tester,
      SplitCoverage([
        CoverageGap(from: from, to: to, missing: 4),
        CoverageGap(from: to, to: to.add(const Duration(hours: 2)), missing: 1),
      ]),
    );
    expect(find.text('5+ missing'), findsOneWidget);

    await tester.tap(find.text('5+ missing'));
    await tester.pumpAndSettle();

    expect(find.text('At least 5 games are missing'), findsOneWidget);
    expect(find.textContaining('214 games'), findsOneWidget);
    expect(find.text('at least 4 games'), findsOneWidget);
    expect(find.text('at least 1 game'), findsOneWidget);
    expect(find.textContaining('exactly 0 RP'), findsOneWidget);
  });

  testWidgets('a single missing game is said in the singular', (tester) async {
    await pump(
      tester,
      SplitCoverage([CoverageGap(from: from, to: to, missing: 1)]),
    );
    await tester.tap(find.text('1+ missing'));
    await tester.pumpAndSettle();
    expect(find.text('At least 1 game is missing'), findsOneWidget);
  });

  testWidgets(
    'the pill is small and its tap area is 32, so a heading does not grow',
    (tester) async {
      await pump(
        tester,
        SplitCoverage([CoverageGap(from: from, to: to, missing: 3)]),
      );
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(ControlPill.compactHitHeight),
      );
      expect(tester.getSize(find.text('3+ missing')).height, lessThan(20));
    },
  );

  testWidgets('a screen reader hears a button with the count', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      SplitCoverage([CoverageGap(from: from, to: to, missing: 3)]),
    );
    expect(
      tester.getSemantics(find.byType(CoveragePill)),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'At least 3 games missing. Show where.',
      ),
    );
    handle.dispose();
  });
}
