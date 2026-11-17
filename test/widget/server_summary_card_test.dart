import 'package:apexlytics/models/server_status.dart';
import 'package:apexlytics/widgets/server_summary_card.dart';
import 'package:apexlytics/widgets/status_dot.dart';
import 'package:apexlytics/utils/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final status = ServerStatus(services: {});

  Future<void> pump(WidgetTester tester, {DateTime? staleAt}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSummaryCard(
              status: status,
              staleAt: staleAt,
              onTap: () {},
            ),
          ),
        ),
      );

  testWidgets('a fresh reading says the state', (tester) async {
    await pump(tester);

    expect(find.text('All systems operational'), findsOneWidget);
    expect(
      tester.widget<StatusDot>(find.byType(StatusDot)).color,
      AppTheme.green,
    );
  });

  testWidgets('a saved copy says when it was checked, not that all is well', (
    tester,
  ) async {
    await pump(
      tester,
      staleAt: DateTime.now().subtract(const Duration(minutes: 7)),
    );

    expect(find.text('All systems operational'), findsNothing);
    expect(find.text('Last checked 7m ago'), findsOneWidget);
    expect(
      tester.widget<StatusDot>(find.byType(StatusDot)).color,
      AppTheme.muted,
    );
  });
}
