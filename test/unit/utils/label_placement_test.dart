import 'dart:ui';

import 'package:apexlytics/utils/ranked/label_placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 300, 200);
  const label = Size(40, 12);

  List<Rect?> place(List<Offset> centers, {Rect area = bounds}) => placeLabels(
    centers: centers,
    sizes: [for (final _ in centers) label],
    bounds: area,
  );

  test('a lone dot gets its label on the right', () {
    final r = place([const Offset(100, 100)]).single!;

    expect(r.left, greaterThan(100));
    expect(r.center.dy, 100);
  });

  test('moves to the left when the right would leave the area', () {
    final r = place([const Offset(280, 100)]).single!;

    expect(r.right, lessThan(280));
    expect(r.left, greaterThanOrEqualTo(0));
  });

  test('stays inside the area at a corner', () {
    final r = place([const Offset(5, 5)]).single!;

    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.top, greaterThanOrEqualTo(0));
  });

  test('never overlaps another label or any dot', () {
    final centers = [
      for (var i = 0; i < 8; i++) Offset(100 + i * 6.0, 100 + (i % 3) * 5.0),
    ];
    final placed = place(centers).nonNulls.toList();

    expect(placed, isNotEmpty);
    for (final (i, a) in placed.indexed) {
      for (final b in placed.skip(i + 1)) {
        expect(a.overlaps(b), isFalse);
      }
      for (final c in centers) {
        expect(a.overlaps(Rect.fromCircle(center: c, radius: 7)), isFalse);
      }
    }
  });

  test('the first dot gets the spot two labels both want', () {
    // Close enough that both labels would sit on the right and overlap.
    const a = Offset(100, 100);
    const b = Offset(100, 108);

    final ab = place([a, b]);
    expect(ab[0]!.left, greaterThan(a.dx));
    expect(ab[1]!.overlaps(ab[0]!), isFalse);

    final ba = place([b, a]);
    expect(ba[0]!.left, greaterThan(b.dx));
  });

  test('a label with no room is left off, not drawn over another', () {
    const tiny = Rect.fromLTWH(80, 90, 40, 24);

    expect(place([const Offset(100, 100)], area: tiny).single, isNull);
  });

  group('placeAllLabels', () {
    List<PlacedLabel> all(List<Offset> centers) => placeAllLabels(
      centers: centers,
      sizes: [for (final _ in centers) label],
      bounds: bounds,
    );

    test('puts a label beside its dot when there is room', () {
      final r = all([const Offset(100, 100)]).single;
      expect(r.moved, isFalse);
      expect(r.rect.left, greaterThan(100));
    });

    test('names every dot of a crowd, none overlapping a dot or a label', () {
      final centers = [
        for (var i = 0; i < 14; i++) Offset(20 + (i % 4) * 5.0, 90 + i * 2.0),
      ];
      final placed = all(centers);

      expect(placed, hasLength(14));
      for (final p in placed) {
        expect(bounds.contains(p.rect.topLeft), isTrue);
        expect(bounds.contains(p.rect.bottomRight), isTrue);
        for (final c in centers) {
          expect(
            p.rect.overlaps(Rect.fromCircle(center: c, radius: 7)),
            isFalse,
          );
        }
      }
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(placed[i].rect.overlaps(placed[j].rect), isFalse);
        }
      }
      // Some had to go to free space, and say so.
      expect(placed.any((p) => p.moved), isTrue);
    });
  });

  group('dotsNear', () {
    const centers = [Offset(10, 10), Offset(18, 10), Offset(200, 100)];

    test('lists the dots within reach, nearest first', () {
      expect(dotsNear(const Offset(16, 10), centers, reach: 22), [1, 0]);
    });

    test('leaves out a dot a thumb away when the reach is tight', () {
      // The tap is on dot 0, 8 apart from dot 1 and 40 from dot 2.
      const spread = [Offset(0, 0), Offset(8, 0), Offset(40, 0)];
      expect(dotsNear(const Offset(0, 0), spread, reach: 20), [0, 1]);
    });

    test('is empty when the tap is on none', () {
      expect(dotsNear(const Offset(100, 100), centers, reach: 22), isEmpty);
    });
  });

  test('a leader line runs from the dot edge to the label', () {
    final (from, to) = leaderLine(
      const Offset(0, 0),
      const Rect.fromLTWH(40, -5, 30, 10),
      7,
    );
    expect(from, const Offset(7, 0));
    expect(to, const Offset(40, 0));
  });
}
