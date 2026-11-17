import 'package:apexlytics/screens/ranked/ranked_sessions_list_screen.dart';
import 'package:apexlytics/widgets/nav_entry_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows its title and icon and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        NavEntryCard(
          icon: Icons.timeline,
          title: 'Sessions',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.byIcon(Icons.timeline), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Sessions'));
    expect(taps, 1);
  });

  testWidgets('the Sessions entry hides itself when there are none', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(RankedSessionsEntry(sessions: const [], onRefresh: () async {})),
    );

    expect(find.text('Sessions'), findsNothing);
  });

  testWidgets('a title that fits stays beside the icon', (tester) async {
    await tester.pumpWidget(
      host(NavEntryCard(icon: Icons.history, title: 'Sessions', onTap: () {})),
    );

    expect(
      tester.getTopLeft(find.text('Sessions')).dx,
      greaterThan(tester.getTopRight(find.byIcon(Icons.history)).dx),
    );
  });

  testWidgets('a word too long for a half-width tile goes under the icon', (
    tester,
  ) async {
    // 'Performance' is about 84 dp; a half-width tile on a 360 dp screen has
    // about 82 dp beside the icon and chevron, so it would break mid-word.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 160,
          child: NavEntryCard(
            icon: Icons.history,
            title: 'Performance Trends',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Performance Trends')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byIcon(Icons.history)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
