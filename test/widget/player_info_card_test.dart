import 'package:apexlytics/widgets/player_info_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerInfoCard(stats: buildStats(uid: '1010712222499')),
        ),
      ),
    );
  }

  testWidgets('the copy UID icon is a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester);

    expect(find.byTooltip('Copy UID'), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Copy UID')),
      isSemantics(isButton: true, hasTapAction: true, tooltip: 'Copy UID'),
    );
    handle.dispose();
  });

  testWidgets('tapping the copy UID icon still copies the UID', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(copied, '1010712222499');
  });
  testWidgets('tapping the UID itself copies it, and the line stays short', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester);

    final line = find.ancestor(
      of: find.text('UID: 1010712222499'),
      matching: find.byType(InkWell),
    );
    // No taller than the text with its small icon padding.
    expect(tester.getSize(line).height, lessThan(30));

    await tester.tap(find.text('UID: 1010712222499'));
    await tester.pump();

    expect(copied, '1010712222499');
  });
}
