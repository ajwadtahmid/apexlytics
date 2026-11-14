import 'package:apexlytics/widgets/pill_segments.dart';
import 'package:apexlytics/widgets/segmented_capsule.dart';
import 'package:apexlytics/utils/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A label on a solid orange fill is dark, not white (see AppTheme.onAccent).
void main() {
  Color? labelColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('the selected option of a capsule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentedCapsule(
            options: const ['Name', 'UID'],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(labelColor(tester, 'Name'), AppTheme.onAccent);
    expect(labelColor(tester, 'UID'), AppTheme.muted);
  });

  testWidgets('the selected segment of a pill switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PillSegments(
            options: [
              PillOption(
                label: 'PC',
                icon: (c) => Icon(Icons.computer, color: c),
              ),
              PillOption(
                label: 'PS',
                icon: (c) => Icon(Icons.gamepad, color: c),
              ),
            ],
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(labelColor(tester, 'PS'), AppTheme.onAccent);
    expect(labelColor(tester, 'PC'), AppTheme.muted);
  });
}
