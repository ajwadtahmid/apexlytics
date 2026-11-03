import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/screens/settings/widgets/quiet_hours_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> pump(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: QuietHoursTile())),
        ),
      ),
    );
    return prefs;
  }

  testWidgets('is off to begin with, and shows no times', (tester) async {
    await pump(tester);

    expect(find.text('Quiet hours'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('From'), findsNothing);
    expect(find.text('To'), findsNothing);
  });

  testWidgets('switching it on offers 11 PM to 7 AM and saves the choice', (
    tester,
  ) async {
    final prefs = await pump(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.textContaining('11:00'), findsOneWidget);
    expect(find.textContaining('7:00'), findsOneWidget);
    expect(prefs.getBool(PrefsKeys.alertQuietEnabled), isTrue);
  });

  testWidgets('shows the window that was saved', (tester) async {
    await pump(
      tester,
      saved: {
        PrefsKeys.alertQuietEnabled: true,
        PrefsKeys.alertQuietStartMinute: 22 * 60 + 30,
        PrefsKeys.alertQuietEndMinute: 6 * 60,
      },
    );

    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('6:00'), findsOneWidget);
  });

  testWidgets('switching it off hides the times and keeps the window', (
    tester,
  ) async {
    final prefs = await pump(
      tester,
      saved: {
        PrefsKeys.alertQuietEnabled: true,
        PrefsKeys.alertQuietStartMinute: 21 * 60,
      },
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('From'), findsNothing);
    expect(prefs.getBool(PrefsKeys.alertQuietEnabled), isFalse);
    expect(prefs.getInt(PrefsKeys.alertQuietStartMinute), 21 * 60);
  });
}
