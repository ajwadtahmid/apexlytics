import 'package:flutter_test/flutter_test.dart';

import 'package:apexlytics/constants/rank_constants.dart';
import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/utils/formatting/rank_utils.dart' show rankIndex;
import 'package:apexlytics/utils/ranked/rank_climb.dart';

import '../../helpers.dart';

void main() {
  const base = 1782090000;

  /// The ladder index of the division named [label] ("Gold IV").
  int rung(String label) => kRankLadder.indexWhere((d) => d.label == label);

  /// The RP at the start of the division named [label].
  int rp(String label) => kRankLadder[rung(label)].rp;

  /// A ranked game number [n], ending with [total] RP after a change of
  /// [change]. Games are 20 minutes apart and last 10.
  RankedMatch game(
    int n,
    int total, {
    int change = 10,
    bool excluded = false,
    String gameMode = 'BATTLE_ROYALE',
  }) => buildMatch(
    uid: '1',
    start: base + n * 1200,
    length: 600,
    rp: change,
    cumulativeRp: total,
    excluded: excluded,
    gameMode: gameMode,
  );

  /// Games with the given RP totals, in order, the first starting from
  /// [start].
  List<RankedMatch> climb(int start, List<int> totals) {
    var before = start;
    final out = <RankedMatch>[];
    for (final (i, t) in totals.indexed) {
      out.add(game(i + 1, t, change: t - before));
      before = t;
    }
    return out;
  }

  group('with nothing to read', () {
    test('there is no climb', () {
      expect(RankClimb.of(const []).isEmpty, isTrue);
      expect(RankClimb.of(const []).moves, isEmpty);
    });

    test('games that are not ranked are left out', () {
      final c = RankClimb.of([
        game(1, 5000, change: 0),
        game(2, 5000, gameMode: 'UNKNOWN'),
      ]);
      expect(c.isEmpty, isTrue);
    });

    test('a game with an implausible RP change is left out', () {
      final c = RankClimb.of([game(1, 5000, change: 5000)]);
      expect(c.isEmpty, isTrue);
    });
  });

  group('the start and the end', () {
    test('start from the RP before the first game', () {
      final c = RankClimb.of([game(1, 5010, change: 10), game(2, 5030)]);
      expect(c.startRp, 5000);
      expect(c.currentRp, 5030);
      expect(c.net, 30);
    });

    test('take the games in the order they ended', () {
      final games = climb(5000, [5010, 5020, 5030]);
      final c = RankClimb.of(games.reversed);
      expect(c.games.map((g) => g.cumulativeRp), [5010, 5020, 5030]);
    });

    test('a game hidden from the stats still moved the RP, so it counts', () {
      final c = RankClimb.of([
        game(1, 5010),
        game(2, 5020, excluded: true),
        game(3, 5030),
      ]);
      expect(c.games, hasLength(3));
    });
  });

  group('a change inside a tier', () {
    test('is a division move, not a change of tier', () {
      // Silver III to Silver II.
      final c = RankClimb.of(
        climb(rp('Silver III') + 400, [rp('Silver II') + 10]),
      );
      expect(c.moves, hasLength(1));
      final m = c.moves.single;
      expect(m.kind, MoveKind.division);
      expect(m.crossesTier, isFalse);
      expect(m.up, isTrue);
      expect(kRankLadder[m.to].label, 'Silver II');
    });
  });

  group('a change of tier', () {
    test('the first time up into a tier is marked as the first', () {
      final c = RankClimb.of(climb(rp('Silver I') + 700, [rp('Gold IV') + 20]));
      final m = c.moves.single;
      expect(m.kind, MoveKind.tierFirst);
      expect(m.up, isTrue);
      expect(m.fromStart, isTrue);
      expect(m.stretchGames, 1);
    });

    test('a fall to a lower tier is a drop', () {
      final c = RankClimb.of(climb(rp('Gold IV') + 20, [rp('Gold IV') - 20]));
      final m = c.moves.single;
      expect(m.kind, MoveKind.tierDrop);
      expect(m.up, isFalse);
      expect(kRankLadder[m.to].tier, 'Silver');
    });

    test('going up into a tier already visited is back in it', () {
      final gold = rp('Gold IV');
      final c = RankClimb.of(
        climb(gold + 100, [gold - 50, gold - 20, gold + 30]),
      );
      expect(c.moves.map((m) => m.kind), [
        MoveKind.tierDrop,
        MoveKind.tierBack,
      ]);
    });

    test('the tier you started in is not a first when you come back', () {
      final silver = rp('Silver III');
      final c = RankClimb.of(climb(silver + 100, [silver - 50, silver + 20]));
      expect(c.moves.last.kind, MoveKind.division);
      final gold = rp('Gold IV');
      final d = RankClimb.of(climb(gold + 100, [gold - 50, gold + 20]));
      expect(d.moves.last.kind, MoveKind.tierBack);
    });

    test('says what the stretch since the last change of tier cost', () {
      final gold = rp('Gold IV');
      // Start in Silver, up to Gold (3 games), then down again (2 games).
      final c = RankClimb.of(
        climb(gold - 100, [
          gold - 60,
          gold - 20,
          gold + 10,
          gold + 5,
          gold - 30,
        ]),
      );
      final up = c.moves.first;
      expect(up.kind, MoveKind.tierFirst);
      expect(up.stretchGames, 3);
      expect(up.stretchRp, 110);
      final down = c.moves.last;
      expect(down.kind, MoveKind.tierDrop);
      expect(down.fromStart, isFalse);
      expect(down.stretchGames, 2);
      expect(down.stretchRp, -40);
    });
  });

  group('every move is listed as it happened', () {
    test('crossing one line again and again gives a move each time', () {
      final line = rp('Platinum IV');
      final totals = [
        line + 20,
        line - 20,
        line + 15,
        line - 10,
        line + 5,
        line - 30,
      ];
      final c = RankClimb.of(climb(line - 40, totals));
      expect(c.moves, hasLength(6));
      expect(c.moves.map((m) => m.up), [true, false, true, false, true, false]);
      expect(c.promotions, 3);
      expect(c.demotions, 3);
    });

    test('knows the game of the move before each', () {
      final gold = rp('Gold IV');
      final c = RankClimb.of(
        climb(gold - 100, [gold - 50, gold + 10, gold + 20, gold - 10]),
      );
      expect(c.moves.map((m) => m.game), [2, 4]);
      expect(c.moves.map((m) => m.prevGame), [0, 2]);
      expect(c.moves.last.gamesSincePrev, 2);
    });

    test('a jump over several divisions is one move', () {
      // Rookie IV to Rookie II in one game.
      final c = RankClimb.of(climb(10, [rp('Rookie II') + 10]));
      expect(c.moves, hasLength(1));
      expect(kRankLadder[c.moves.single.to].label, 'Rookie II');
    });
  });

  group('the divisions', () {
    test('count the games played in each, by the division queued in', () {
      final gold = rp('Gold IV');
      final c = RankClimb.of(
        climb(gold - 100, [gold - 60, gold - 20, gold + 10, gold + 40]),
      );
      final silver = c.divisions[rankIndex(gold - 60)]!;
      final goldStay = c.divisions[rankIndex(gold)]!;
      // Games 1-3 were queued in Silver; game 3 took the player to Gold.
      expect(silver.games, 3);
      expect(goldStay.games, 1);
      expect(c.currentRung, rankIndex(gold));
    });

    test('count visits', () {
      final gold = rp('Gold IV');
      final c = RankClimb.of(
        climb(gold + 100, [gold - 50, gold + 50, gold - 50, gold + 50]),
      );
      expect(c.divisions[rankIndex(gold)]!.visits, 3);
      expect(c.divisions[rankIndex(gold - 50)]!.visits, 2);
    });

    test('add up the time spent in each', () {
      final c = RankClimb.of(
        climb(rp('Silver IV') + 10, [
          rp('Silver IV') + 20,
          rp('Silver III') + 10,
        ]),
      );
      final total = c.divisions.values.fold<int>(0, (a, d) => a + d.secs);
      // From the first game's start to the last game's end.
      expect(
        total,
        c.games.last.endTime.difference(c.games.first.startTime).inSeconds,
      );
    });

    test('the peak is the highest division reached', () {
      final c = RankClimb.of(
        climb(rp('Silver I') + 100, [rp('Gold IV') + 10, rp('Gold IV') - 10]),
      );
      expect(kRankLadder[c.peakRung].tier, 'Gold');
      expect(kRankLadder[c.currentRung].tier, 'Silver');
    });
  });

  group('the best and worst runs', () {
    test('find the biggest gain and the biggest fall', () {
      final c = RankClimb.of(climb(5000, [5100, 5300, 5200, 5000, 4850, 4800]));
      final up = c.biggestClimb!;
      expect(up.amount, 300);
      expect(up.games, 2);
      final down = c.biggestSlide!;
      expect(down.amount, -500);
      expect(down.games, 4);
    });

    test('a run that only goes one way has no fall', () {
      final c = RankClimb.of(climb(5000, [5010, 5020, 5030]));
      expect(c.biggestClimb!.amount, 30);
      expect(c.biggestSlide, isNull);
    });
  });

  test('lists the games that led up to a move', () {
    final gold = rp('Gold IV');
    final c = RankClimb.of(
      climb(gold - 100, [gold - 80, gold - 60, gold - 40, gold + 5]),
    );
    final move = c.moves.single;
    final games = c.gamesBetween(move.prevGame, move.game);
    expect(games, hasLength(4));
    expect(games.last.cumulativeRp, gold + 5);
  });
}
