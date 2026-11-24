import 'package:apexlytics/utils/ranked/split_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  final t0 = 1782090000;

  /// A game [i] slots after the first, leaving the player on [after] RP.
  game(int i, int rp, int after, {bool edited = false}) {
    final m = buildMatch(start: t0 + i * 1500, rp: rp, cumulativeRp: after);
    return edited ? m.withEdits({'rp_change': rp}) : m;
  }

  group('splitCoverage', () {
    test('a chain that joins up has no gaps', () {
      final c = splitCoverage([
        game(0, 20, 1020),
        game(1, -10, 1010),
        game(2, 30, 1040),
      ]);
      expect(c.complete, isTrue);
      expect(c.missing, 0);
    });

    test('a break names the stretch and says at least one game', () {
      // 1010 -> next game started from 1040, so 30 RP came from somewhere.
      final games = [game(0, 20, 1020), game(1, -10, 1010), game(3, 30, 1070)];
      final c = splitCoverage(games);
      expect(c.gaps, hasLength(1));
      expect(c.gaps.single.from, games[1].endTime);
      expect(c.gaps.single.to, games[2].startTime);
      // The biggest swing seen is 30, and the jump was 30.
      expect(c.gaps.single.missing, 1);
    });

    test('a big jump needs more games, by the biggest swing seen', () {
      final c = splitCoverage([game(0, 20, 1020), game(5, 20, 1160)]);
      // Jump of 120 with a biggest swing of 20: at least 6 games.
      expect(c.missing, 6);
    });

    test('counts every gap', () {
      final c = splitCoverage([
        game(0, 20, 1020),
        game(2, 20, 1100),
        game(3, 20, 1120),
        game(6, 20, 1200),
      ]);
      expect(c.gaps, hasLength(2));
      expect(c.missing, greaterThanOrEqualTo(2));
    });

    test('does not depend on the order it is given', () {
      final inOrder = [game(0, 20, 1020), game(1, 20, 1040), game(3, 20, 1100)];
      final shuffled = [inOrder[2], inOrder[0], inOrder[1]];
      expect(splitCoverage(shuffled).missing, splitCoverage(inOrder).missing);
      expect(splitCoverage(shuffled).gaps, hasLength(1));
    });

    test('a hand-corrected RP change does not start a break', () {
      // The change was edited, so it no longer joins to the game before.
      final c = splitCoverage([
        game(0, 20, 1020),
        game(1, 99, 1040, edited: true),
      ]);
      expect(c.complete, isTrue);
    });

    test('a reset artifact does not start a break', () {
      final c = splitCoverage([game(0, 20, 1020), game(1, -1500, 700)]);
      expect(c.complete, isTrue);
    });

    test('a reading of 0 RP is not a score', () {
      final c = splitCoverage([game(0, 20, 1020), game(1, 20, 0)]);
      expect(c.complete, isTrue);
    });

    test('games with no RP change are not ranked and are left out', () {
      final c = splitCoverage([
        game(0, 20, 1020),
        // A pubs game: no RP change, so not part of the chain.
        buildMatch(start: t0 + 750, rp: 0, cumulativeRp: 5000),
        game(1, 20, 1040),
      ]);
      expect(c.complete, isTrue);
    });

    test('a hand-excluded game still joins the chain', () {
      final c = splitCoverage([
        game(0, 20, 1020),
        buildMatch(
          start: t0 + 1500,
          rp: 20,
          cumulativeRp: 1040,
          excluded: true,
        ),
        game(2, 20, 1060),
      ]);
      expect(c.complete, isTrue);
    });

    test('nothing or one game has no gaps', () {
      expect(splitCoverage(const []).complete, isTrue);
      expect(splitCoverage([game(0, 20, 1020)]).complete, isTrue);
    });
  });
}
