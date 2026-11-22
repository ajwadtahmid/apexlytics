/// How a split's ranked games moved a player up and down the ladder: every
/// promotion and demotion, the time spent in each division, and the best and
/// worst runs of games.
///
/// A move is counted when the RP after a game lands in a different division
/// from the RP before it. Games the player hid from the stats still count, as
/// they still moved the RP; games with an implausible RP change do not.
library;

import 'dart:math' as math;

import '../../constants/rank_constants.dart';
import '../../models/ranked_match.dart';
import '../formatting/rank_utils.dart' show rankIndex;

/// The tier a [rung] of [kRankLadder] belongs to ("Gold").
String tierOfRung(int rung) => kRankLadder[rung].tier;

/// What kind of move it was. A change of tier is the headline: the first time
/// into a tier this split, back into one already visited, or a drop to a lower
/// one. A change of division inside a tier is the quiet kind.
enum MoveKind { tierFirst, tierBack, tierDrop, division }

/// One promotion or demotion.
class RankMove {
  /// The game that caused it, counted from 1 among the split's ranked games.
  final int game;

  /// The game of the move before it, of any kind, or 0.
  final int prevGame;
  final RankedMatch match;

  /// Ladder indexes of the division left and the one reached.
  final int from;
  final int to;
  final MoveKind kind;

  /// For a change of tier: what the stretch since the last change of tier (or
  /// since the start, when [fromStart]) cost or gained.
  final bool fromStart;
  final int stretchGames;
  final int stretchRp;
  final Duration stretchTime;

  const RankMove({
    required this.game,
    required this.prevGame,
    required this.match,
    required this.from,
    required this.to,
    required this.kind,
    this.fromStart = false,
    this.stretchGames = 0,
    this.stretchRp = 0,
    this.stretchTime = Duration.zero,
  });

  bool get up => to > from;
  bool get crossesTier => kind != MoveKind.division;
  DateTime get at => match.endTime;

  /// The RP after the game that moved the player.
  int get total => match.cumulativeRp;
  int get gamesSincePrev => game - prevGame;
}

/// What a division looked like over the split.
class DivisionStay {
  final int rung;
  int games = 0;
  int secs = 0;
  int visits = 0;
  DateTime? firstEntered;
  DivisionStay(this.rung);
}

/// The best run of games up, or the worst run down: games [fromGame] + 1
/// through [toGame].
class ClimbRun {
  final int fromGame;
  final int toGame;

  /// The RP gained over the run, negative for a slide.
  final int amount;
  final DateTime from;
  final DateTime to;
  const ClimbRun(this.fromGame, this.toGame, this.amount, this.from, this.to);
  int get games => toGame - fromGame;
}

class RankClimb {
  /// The RP before the first game.
  final int startRp;

  /// The split's ranked games, oldest first.
  final List<RankedMatch> games;
  final List<RankMove> moves;

  /// By ladder index.
  final Map<int, DivisionStay> divisions;

  const RankClimb._(this.startRp, this.games, this.moves, this.divisions);

  static const empty = RankClimb._(0, [], [], {});

  /// The climb through [matches]: the ranked ones, any order.
  factory RankClimb.of(Iterable<RankedMatch> matches) {
    final games = [
      for (final m in matches)
        if (m.isRanked && !m.isAutoExcluded) m,
    ]..sort(_oldestFirst);
    if (games.isEmpty) return empty;

    final startRp = games.first.cumulativeRp - games.first.rpChange;
    var rung = rankIndex(startRp);
    var stayStart = games.first.startTime;
    var prevGame = 0;
    var prevTierGame = 0;
    final visited = {tierOfRung(rung)};
    final stays = <int, DivisionStay>{
      rung: DivisionStay(rung)
        ..visits = 1
        ..firstEntered = stayStart,
    };
    final moves = <RankMove>[];

    int totalAt(int game) => game == 0 ? startRp : games[game - 1].cumulativeRp;
    DateTime timeAt(int game) =>
        game == 0 ? games.first.startTime : games[game - 1].endTime;

    for (final (i, g) in games.indexed) {
      // A game belongs to the division it was queued in.
      stays[rung]!.games++;
      final after = rankIndex(g.cumulativeRp);
      if (after == rung) continue;

      stays[rung]!.secs += g.endTime.difference(stayStart).inSeconds;
      final number = i + 1;
      final crosses = tierOfRung(rung) != tierOfRung(after);
      final kind = !crosses
          ? MoveKind.division
          : after < rung
          ? MoveKind.tierDrop
          : visited.contains(tierOfRung(after))
          ? MoveKind.tierBack
          : MoveKind.tierFirst;
      if (crosses && after > rung) visited.add(tierOfRung(after));
      moves.add(
        RankMove(
          game: number,
          prevGame: prevGame,
          match: g,
          from: rung,
          to: after,
          kind: kind,
          fromStart: crosses && prevTierGame == 0,
          stretchGames: crosses ? number - prevTierGame : 0,
          stretchRp: crosses ? g.cumulativeRp - totalAt(prevTierGame) : 0,
          stretchTime: crosses
              ? g.endTime.difference(timeAt(prevTierGame))
              : Duration.zero,
        ),
      );
      if (crosses) prevTierGame = number;
      prevGame = number;
      rung = after;
      stayStart = g.endTime;
      final stay = stays.putIfAbsent(rung, () => DivisionStay(rung));
      stay.firstEntered ??= g.endTime;
      stay.visits++;
    }
    stays[rung]!.secs += games.last.endTime.difference(stayStart).inSeconds;
    return RankClimb._(startRp, games, moves, stays);
  }

  bool get isEmpty => games.isEmpty;
  int get currentRp => games.isEmpty ? startRp : games.last.cumulativeRp;
  int get currentRung => rankIndex(currentRp);
  int get peakRung =>
      divisions.isEmpty ? currentRung : divisions.keys.reduce(math.max);
  int get net => currentRp - startRp;
  int get promotions => moves.where((m) => m.up).length;
  int get demotions => moves.length - promotions;
  int get playSecs => games.fold(0, (a, g) => a + g.lengthSecs);

  int totalAt(int game) => game == 0 ? startRp : games[game - 1].cumulativeRp;
  DateTime timeAt(int game) =>
      game == 0 ? games.first.startTime : games[game - 1].endTime;

  /// The biggest gain over a run of games, or null with none.
  ClimbRun? get biggestClimb {
    ClimbRun? best;
    var low = 0;
    for (var j = 1; j <= games.length; j++) {
      if (totalAt(j) < totalAt(low)) low = j;
      final gain = totalAt(j) - totalAt(low);
      if (gain > 0 && (best == null || gain > best.amount)) {
        best = ClimbRun(low, j, gain, timeAt(low), timeAt(j));
      }
    }
    return best;
  }

  /// The biggest fall over a run of games, or null with none.
  ClimbRun? get biggestSlide {
    ClimbRun? worst;
    var high = 0;
    for (var j = 1; j <= games.length; j++) {
      if (totalAt(j) > totalAt(high)) high = j;
      final drop = totalAt(j) - totalAt(high);
      if (drop < 0 && (worst == null || drop < worst.amount)) {
        worst = ClimbRun(high, j, drop, timeAt(high), timeAt(j));
      }
    }
    return worst;
  }

  /// The games after game [prevGame] up to and including game [game].
  List<RankedMatch> gamesBetween(int prevGame, int game) =>
      games.sublist(prevGame, game);
}

int _oldestFirst(RankedMatch a, RankedMatch b) {
  final d = a.endTime.compareTo(b.endTime);
  return d != 0 ? d : a.id.compareTo(b.id);
}
