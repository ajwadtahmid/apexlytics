import 'package:apexlytics/utils/bug_report.dart';
import 'package:apexlytics/widgets/bug_report_player_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    BugReportChannel channel = BugReportChannel.email,
    String name = 'Aceu',
  }) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showBugReportPlayerDialog(
                context,
                channel: channel,
                uid: '1006838015507',
                platform: 'PS4',
                name: name,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const label = 'Include my player ID, platform and name';

  testWidgets('it is unticked to begin with, and Continue shares nothing', (
    tester,
  ) async {
    await open(tester);

    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('it shows what would be shared', (tester) async {
    await open(tester);

    expect(find.text('Aceu · 1006838015507 · PS4'), findsOneWidget);
  });

  testWidgets('ticking it shares the player', (tester) async {
    await open(tester);

    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('ticking it twice leaves it off', (tester) async {
    await open(tester);

    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('Cancel backs out of the report', (tester) async {
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('a GitHub report is warned to be public, an email is not', (
    tester,
  ) async {
    await open(tester, channel: BugReportChannel.github);
    expect(find.textContaining('public issue'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await open(tester, channel: BugReportChannel.email);
    expect(find.textContaining('public issue'), findsNothing);
    expect(find.textContaining('only to the developer'), findsOneWidget);
  });

  testWidgets('a profile with no name shows just the ID and platform', (
    tester,
  ) async {
    await open(tester, name: '');

    expect(find.text('1006838015507 · PS4'), findsOneWidget);
  });
}
