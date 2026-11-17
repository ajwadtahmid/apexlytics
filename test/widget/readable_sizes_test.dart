import 'package:apexlytics/widgets/stat_display.dart';
import 'package:apexlytics/widgets/summary_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double width = 360}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  group('a stat tile footnote', () {
    for (final compact in [false, true]) {
      testWidgets('is at least 11 sp (compact: $compact)', (tester) async {
        await pump(
          tester,
          StatDisplay(
            label: 'Best legend',
            value: 'Mad Maggie',
            footnote: '+1,451 RP',
            compact: compact,
          ),
        );

        final text = tester.widget<Text>(find.text('+1,451 RP'));
        expect(text.style!.fontSize, greaterThanOrEqualTo(11));
      });
    }
  });

  testWidgets('a summary card subtitle wraps to a second line', (tester) async {
    await pump(
      tester,
      const SummaryCard(
        leading: Icon(Icons.person_add),
        title: 'Set up your player',
        subtitle:
            'Add your player to see your stats, matches and ranked history',
      ),
      width: 280,
    );

    final text = tester.widget<Text>(find.textContaining('Add your player'));
    expect(text.maxLines, 2);
    expect(tester.takeException(), isNull);
  });
}
