import 'package:apexlytics/widgets/phone_orientation_lock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<List<List<DeviceOrientation>>> run(
    WidgetTester tester,
    Size size,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final applied = <List<DeviceOrientation>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneOrientationLock(
          onApply: (o) async => applied.add(o),
          child: const SizedBox(),
        ),
      ),
    );
    return applied;
  }

  testWidgets('a phone is held upright', (tester) async {
    final applied = await run(
      tester,
      const Size(411, 890),
      TargetPlatform.android,
    );

    expect(applied, [
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    ]);
  });

  testWidgets('a phone turned sideways is still a phone', (tester) async {
    final applied = await run(
      tester,
      const Size(890, 411),
      TargetPlatform.android,
    );

    expect(applied.single, hasLength(2));
  });

  testWidgets('a tablet may turn', (tester) async {
    final applied = await run(
      tester,
      const Size(800, 1280),
      TargetPlatform.android,
    );

    expect(applied.single, DeviceOrientation.values);
  });

  testWidgets('a desktop window is left alone', (tester) async {
    final applied = await run(
      tester,
      const Size(400, 700),
      TargetPlatform.windows,
    );

    expect(applied, isEmpty);
  });
}
