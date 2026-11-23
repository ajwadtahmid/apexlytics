import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apexlytics/utils/theme.dart';
import 'package:apexlytics/widgets/presence_dot.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

void main() {
  const size = 60.0;

  /// The dot drawn at [size] logical pixels, as an RGBA image.
  Future<ByteData> render(WidgetTester tester, Presence presence) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: PresenceDot(presence: presence, size: size),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    return bytes!;
  }

  Color pixel(ByteData data, int x, int y) {
    final i = (y * size.toInt() + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  bool isClear(Color c) => c.a == 0;

  // The dot is 60 px wide, so its centre is (30, 30), its left half is x < 30,
  // and a ring is 8 px thick at the edge.
  testWidgets('in game is a solid orange dot', (tester) async {
    final data = await render(tester, Presence.inGame);
    expect(pixel(data, 30, 30), AppTheme.orange);
    expect(pixel(data, 12, 30), AppTheme.orange);
    expect(pixel(data, 48, 30), AppTheme.orange);
  });

  testWidgets('online is a solid green dot', (tester) async {
    final data = await render(tester, Presence.online);
    expect(pixel(data, 30, 30), AppTheme.green);
    expect(pixel(data, 12, 30), AppTheme.green);
    expect(pixel(data, 48, 30), AppTheme.green);
  });

  testWidgets('offline is a solid grey dot', (tester) async {
    final data = await render(tester, Presence.offline);
    expect(pixel(data, 30, 30), AppTheme.muted);
    expect(pixel(data, 48, 30), AppTheme.muted);
  });

  testWidgets('unknown is a hollow grey ring', (tester) async {
    final data = await render(tester, Presence.unknown);
    expect(isClear(pixel(data, 30, 30)), isTrue);
    expect(pixel(data, 4, 30), AppTheme.muted);
    expect(pixel(data, 56, 30), AppTheme.muted);
  });

  testWidgets('failed is a solid red dot', (tester) async {
    final data = await render(tester, Presence.failed);
    expect(pixel(data, 30, 30), AppTheme.red);
    expect(pixel(data, 12, 30), AppTheme.red);
    expect(pixel(data, 48, 30), AppTheme.red);
  });

  group('presenceOf', () {
    test('a player in a match is in game, even when also online', () {
      expect(
        presenceOf(buildStats(isInGame: true, isOnline: true)),
        Presence.inGame,
      );
    });

    test('online and offline', () {
      expect(presenceOf(buildStats(isOnline: true)), Presence.online);
      expect(presenceOf(buildStats()), Presence.offline);
    });
  });

  group('for a screen reader', () {
    testWidgets('each state says what it is', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (presence, words) in [
        (Presence.inGame, 'In game'),
        (Presence.online, 'Online'),
        (Presence.offline, 'Offline'),
        (Presence.unknown, 'Status not known yet'),
        (Presence.failed, 'Failed to load'),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: PresenceDot(presence: presence),
          ),
        );
        expect(find.bySemanticsLabel(words), findsOneWidget, reason: words);
      }
      handle.dispose();
    });

    testWidgets('a dot beside the same words says nothing itself', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PresenceDot(presence: Presence.online, decorative: true),
        ),
      );
      expect(find.bySemanticsLabel('Online'), findsNothing);
      handle.dispose();
    });
  });
}
