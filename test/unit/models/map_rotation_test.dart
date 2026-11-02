import 'package:flutter_test/flutter_test.dart';
import 'package:apexlytics/models/map_rotation.dart';

void main() {
  Map<String, dynamic> block(String map, int secs) => {
    'current': {'map': map, 'remainingSecs': secs},
    'next': {'map': '$map next', 'remainingSecs': 0},
  };

  group('MapRotation.fromJson', () {
    test('reads every mode when the payload is well formed', () {
      final r = MapRotation.fromJson({
        'battle_royale': block('Olympus', 600),
        'ranked': block('Storm Point', 1200),
        'ltm': block('Control', 300),
        'wildcard': block('Wildcard', 900),
      });

      expect(r.battleRoyaleCurrent.map, 'Olympus');
      expect(r.rankedCurrent.remainingSecs, 1200);
      expect(r.ltmCurrent?.map, 'Control');
      expect(r.wildcardNext?.map, 'Wildcard next');
    });

    test('an empty block sent as a list is absent, and the rest still parse',
        () {
      // A PHP-style empty block arrives as [] rather than {} or nothing.
      final r = MapRotation.fromJson({
        'battle_royale': block('Olympus', 600),
        'ranked': block('Storm Point', 1200),
        'ltm': <Object?>[],
        'wildcard': <Object?>[],
      });

      expect(r.battleRoyaleCurrent.map, 'Olympus');
      expect(r.rankedCurrent.map, 'Storm Point');
      expect(r.ltmCurrent, isNull);
      expect(r.ltmNext, isNull);
      expect(r.wildcardCurrent, isNull);
    });

    test('a mode sent as a list parses as an empty one', () {
      final r = MapRotation.fromJson({
        'battle_royale': <Object?>[],
        'ranked': {'current': <Object?>[], 'next': 'soon'},
      });

      expect(r.battleRoyaleCurrent.map, 'Unknown');
      expect(r.rankedCurrent.remainingSecs, 0);
      expect(r.rankedNext.map, 'Unknown');
    });
  });

  group('countdowns', () {
    MapRotation rotationAt(DateTime fetchedAt, {int ranked = 3600}) {
      MapMode mode(int secs) => MapMode(
        map: 'Olympus',
        remainingSecs: secs,
        durationMins: 60,
        asset: '',
      );
      return MapRotation(
        battleRoyaleCurrent: mode(3600),
        battleRoyaleNext: mode(0),
        rankedCurrent: mode(ranked),
        rankedNext: mode(0),
        ltmCurrent: mode(600),
        fetchedAt: fetchedAt,
      );
    }

    test('a negative remaining time reads as already over', () {
      final m = MapMode.fromJson({'map': 'Olympus', 'remainingSecs': -3});
      expect(m.remainingSecs, 0);
      expect(MapMode.fromJson({'remainingMins': -2}).remainingSecs, 0);
    });

    test('agedTo takes the time since the fetch off every countdown', () {
      final at = DateTime(2026, 11, 1, 14);
      final aged = rotationAt(at).agedTo(at.add(const Duration(minutes: 40)));

      expect(aged.battleRoyaleCurrent.remainingSecs, 3600 - 40 * 60);
      expect(aged.rankedCurrent.remainingSecs, 3600 - 40 * 60);
      expect(aged.ltmCurrent?.remainingSecs, 0);
      expect(aged.wildcardCurrent, isNull);
    });

    test(
      'aging is measured from the fetch, so aging twice does not double it',
      () {
        final at = DateTime(2026, 11, 1, 14);
        final once = rotationAt(at).agedTo(at.add(const Duration(minutes: 10)));
        final twice = once.agedTo(at.add(const Duration(minutes: 20)));

        expect(twice.rankedCurrent.remainingSecs, 3600 - 20 * 60);
      },
    );

    test('a rotation is not aged by a clock that is behind its fetch', () {
      final at = DateTime(2026, 11, 1, 14);
      final r = rotationAt(at);
      expect(r.agedTo(at.subtract(const Duration(minutes: 5))), same(r));
    });
  });
}
