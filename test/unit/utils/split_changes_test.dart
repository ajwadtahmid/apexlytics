import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:apexlytics/utils/ranked/split_changes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

List<LegendBreakdown> _legends(List<RankedMatch> m) => legendBreakdowns(m);
List<MapBreakdown> _maps(List<RankedMatch> m) => mapBreakdowns(m);

void main() {
  group('pickRateShifts', () {
    // Axle 60% and Bangalore 40%, then Axle 20% and Wraith 80%.
    final before = _legends([
      ...buildMatches('Axle', 6, 10, map: 'olympus_rotation'),
      ...buildMatches('Bangalore', 4, 10, map: 'olympus_rotation'),
    ]);
    final after = _legends([
      ...buildMatches('Axle', 2, 10, map: 'olympus_rotation'),
      ...buildMatches('Wraith', 8, 10, map: 'olympus_rotation'),
    ]);

    test('orders the legends by how far their share moved', () {
      final shifts = pickRateShifts(before, after);

      expect(shifts.map((s) => s.legend), ['Wraith', 'Axle', 'Bangalore']);
      expect(shifts.map(pointsMoved), [80, -40, -40]);
    });

    test('counts a legend missing from one split as zero there', () {
      final wraith = pickRateShifts(before, after).first;
      expect(wraith.before, 0);
      expect(wraith.after, closeTo(0.8, 1e-9));
    });

    test('keeps only the biggest few', () {
      expect(pickRateShifts(before, after, limit: 1), hasLength(1));
    });

    test('leaves out a share that moved by less than a point', () {
      final same = _legends([
        ...buildMatches('Axle', 4, 10, map: 'olympus_rotation'),
      ]);
      expect(pickRateShifts(same, same), isEmpty);
    });

    test('says nothing when either split has no games', () {
      expect(pickRateShifts(const [], after), isEmpty);
      expect(pickRateShifts(before, const []), isEmpty);
    });
  });

  group('mapRpShifts', () {
    final before = _maps([
      ...buildMatches('Axle', 4, 10, map: 'olympus_rotation'),
      ...buildMatches('Axle', 4, 5, map: 'storm_point_rotation'),
      ...buildMatches('Axle', 4, 5, map: 'kings_canyon_rotation'),
    ]);
    final after = _maps([
      ...buildMatches('Axle', 4, -5, map: 'olympus_rotation'),
      // Too few games here to read anything into.
      ...buildMatches('Axle', 2, -20, map: 'storm_point_rotation'),
      // Not played before.
      ...buildMatches('Axle', 5, 20, map: 'worlds_edge_rotation'),
    ]);

    test('compares the maps played enough in both, and only those', () {
      final shifts = mapRpShifts(before, after);

      expect(shifts, hasLength(1));
      expect(shifts.single.map, 'Olympus');
      expect(shifts.single.before, 10);
      expect(shifts.single.after, -5);
    });

    test('pairs a map across periods that spell its key differently', () {
      final earlier = _maps(buildMatches('Axle', 4, 10, map: 'edistrict'));
      final later = _maps(
        buildMatches('Axle', 4, -10, map: 'edistrict_rotation'),
      );

      final shifts = mapRpShifts(earlier, later);

      expect(shifts, hasLength(1));
      expect(shifts.single.before, 10);
      expect(shifts.single.after, -10);
    });

    test('pairs a map across a difference in case', () {
      final earlier = _maps(
        buildMatches('Axle', 4, 10, map: 'OLYMPUS_ROTATION'),
      );
      final later = _maps(buildMatches('Axle', 4, -5, map: 'olympus_rotation'));

      expect(mapRpShifts(earlier, later), hasLength(1));
    });

    test('puts the biggest swing first, up or down', () {
      final flat = _maps([
        ...buildMatches('Axle', 3, 0, map: 'olympus_rotation'),
        ...buildMatches('Axle', 3, 0, map: 'storm_point_rotation'),
      ]);
      final moved = _maps([
        ...buildMatches('Axle', 3, 4, map: 'olympus_rotation'),
        ...buildMatches('Axle', 3, -12, map: 'storm_point_rotation'),
      ]);

      expect(mapRpShifts(flat, moved).map((s) => s.map), [
        'Storm Point',
        'Olympus',
      ]);
    });

    test('leaves out a map that did not move', () {
      expect(mapRpShifts(before, before), isEmpty);
    });
  });
}
