import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/screens/home/widgets/map_rotation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNextMapEnd', () {
    // 14:00, a fixed local time so the clock never matters.
    final now = DateTime(2026, 10, 15, 14);

    test(
      'is the current map\'s remaining time plus the next map\'s length',
      () {
        // 30 min left, then a 60-minute map: it ends 90 minutes from now.
        expect(
          formatNextMapEnd(remainingSecs: 30 * 60, durationMins: 60, now: now),
          '3:30 PM',
        );
      },
    );

    test('names the day when the next map ends after midnight', () {
      expect(
        formatNextMapEnd(remainingSecs: 9 * 3600, durationMins: 120, now: now),
        '1:00 AM tomorrow',
      );
    });

    test('is absent when the API gave the next map no length', () {
      // A guessed time is worse than none.
      expect(
        formatNextMapEnd(remainingSecs: 1800, durationMins: 0, now: now),
        isNull,
      );
    });
  });

  group('the Up Next row', () {
    MapMode mode(String map, {int remaining = 0, int minutes = 0}) => MapMode(
      map: map,
      remainingSecs: remaining,
      durationMins: minutes,
      asset: '',
    );

    Future<void> pump(WidgetTester tester, {required int nextMinutes}) {
      final rotation = MapRotation(
        battleRoyaleCurrent: mode('Olympus', remaining: 1800, minutes: 60),
        battleRoyaleNext: mode("World's Edge", minutes: nextMinutes),
        rankedCurrent: mode('Olympus', remaining: 1800, minutes: 60),
        rankedNext: mode("World's Edge", minutes: nextMinutes),
      );
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapRotationCard(rotation: rotation)),
        ),
      );
    }

    testWidgets('shows when the next map starts and when it ends', (
      tester,
    ) async {
      await pump(tester, nextMinutes: 60);

      expect(
        find.textContaining(RegExp(r'^Starts at \d{1,2}:\d{2} [AP]M$')),
        findsOneWidget,
      );
      expect(
        find.textContaining(RegExp(r'^Ends at \d{1,2}:\d{2} [AP]M')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows only the start time when the length is unknown', (
      tester,
    ) async {
      await pump(tester, nextMinutes: 0);

      expect(find.textContaining('Starts at'), findsOneWidget);
      expect(find.textContaining('Ends at'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
  group('the alert bell', () {
    MapMode mode(String map) =>
        MapMode(map: map, remainingSecs: 1800, durationMins: 60, asset: '');

    final rotation = MapRotation(
      battleRoyaleCurrent: mode('Olympus'),
      battleRoyaleNext: mode("World's Edge"),
      rankedCurrent: mode('Kings Canyon'),
      rankedNext: mode('Olympus'),
    );

    Future<void> pump(
      WidgetTester tester, {
      bool Function(String)? active,
      DateTime? Function(String)? mutedUntil,
      ValueChanged<String>? onTap,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MapRotationCard(
                rotation: rotation,
                alertActive: active,
                alertMutedUntil: mutedUntil,
                onAlertTap: onTap,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is paused while the mode is muted, and says until when', (
      tester,
    ) async {
      final until = DateTime.now().add(const Duration(hours: 2));
      await pump(
        tester,
        active: (m) => m == 'Ranked',
        mutedUntil: (m) => m == 'Ranked' ? until : null,
        onTap: (_) {},
      );

      expect(find.byIcon(Icons.notifications_paused), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      expect(
        find.byTooltip(
          RegExp(r'Ranked alerts are muted until .*Tap to unmute'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is not paused for a mode whose alert is off', (tester) async {
      await pump(
        tester,
        active: (_) => false,
        mutedUntil: (_) => DateTime.now().add(const Duration(hours: 2)),
        onTap: (_) {},
      );

      expect(find.byIcon(Icons.notifications_paused), findsNothing);
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is not there unless the card is given something to do', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byIcon(Icons.notifications_none_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is outlined while the mode has no alert, filled once it has', (
      tester,
    ) async {
      await pump(tester, active: (m) => m == 'Pubs', onTap: (_) {});

      // Ranked is first, and has none.
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);

      await tester.tap(find.text('Pubs'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_outlined), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('names the mode on screen when tapped', (tester) async {
      final tapped = <String>[];
      await pump(tester, onTap: tapped.add);

      await tester.tap(find.byIcon(Icons.notifications_none_outlined));
      await tester.tap(find.text('Pubs'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.notifications_none_outlined));

      expect(tapped, ['Ranked', 'Pubs']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('says what it does, and its state, to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, active: (m) => m == 'Pubs', onTap: (_) {});

      expect(
        find.bySemanticsLabel('Alert me before the Ranked map changes'),
        findsOneWidget,
      );

      await tester.tap(find.text('Pubs'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.bySemanticsLabel('Pubs alerts are on. Tap to change.'),
        findsOneWidget,
      );
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('when the countdown reaches zero', () {
    MapMode mode(String map, {int remaining = 0}) => MapMode(
      map: map,
      remainingSecs: remaining,
      durationMins: 60,
      asset: '',
    );

    MapRotation rotation() => MapRotation(
      battleRoyaleCurrent: mode('Olympus'),
      battleRoyaleNext: mode("World's Edge"),
      rankedCurrent: mode('Olympus'),
      rankedNext: mode("World's Edge"),
    );

    Widget host(MapRotation r, VoidCallback onExpired) => MaterialApp(
      home: Scaffold(
        body: MapRotationCard(rotation: r, onExpired: onExpired),
      ),
    );

    testWidgets('asks again when the refetch brings back the same map', (
      tester,
    ) async {
      var asked = 0;
      await tester.pumpWidget(host(rotation(), () => asked++));
      await tester.pump(const Duration(seconds: 1));
      expect(asked, 1);

      // The proxy replayed its cached copy: a new object with the same data.
      await tester.pumpWidget(host(rotation(), () => asked++));
      await tester.pump(const Duration(seconds: 29));
      expect(asked, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(asked, 2);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not ask again for a rebuild with the same rotation', (
      tester,
    ) async {
      var asked = 0;
      final r = rotation();
      await tester.pumpWidget(host(r, () => asked++));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(r, () => asked++));
      await tester.pump(const Duration(seconds: 60));

      expect(asked, 1);
    });

    testWidgets('stops asking once the map has changed', (tester) async {
      var asked = 0;
      await tester.pumpWidget(host(rotation(), () => asked++));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(rotation(), () => asked++));
      final fresh = MapRotation(
        battleRoyaleCurrent: mode('World\'s Edge', remaining: 1800),
        battleRoyaleNext: mode('Olympus'),
        rankedCurrent: mode('World\'s Edge', remaining: 1800),
        rankedNext: mode('Olympus'),
      );
      await tester.pumpWidget(host(fresh, () => asked++));
      await tester.pump(const Duration(seconds: 60));

      expect(asked, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
