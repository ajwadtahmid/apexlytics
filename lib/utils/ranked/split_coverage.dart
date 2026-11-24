import 'dart:math' as math;

import '../../models/ranked_match.dart';

/// A stretch where the stored games do not join up: the RP before the later
/// game is not the RP after the earlier one, so at least [missing] games (or an
/// RP change that was not a game) are not in the history.
class CoverageGap {
  /// When the game before the break ended, and the game after it started.
  final DateTime from;
  final DateTime to;

  /// The fewest games that could have moved the RP that far.
  final int missing;

  const CoverageGap({
    required this.from,
    required this.to,
    required this.missing,
  });
}

/// How well the stored games of a period cover what was played.
class SplitCoverage {
  final List<CoverageGap> gaps;
  const SplitCoverage(this.gaps);

  bool get complete => gaps.isEmpty;

  /// At least this many games are missing across every gap.
  int get missing => gaps.fold(0, (a, g) => a + g.missing);
}

/// Finds the breaks in the RP chain of [matches].
///
/// Each ranked game stores the RP it left the player on and the change it made,
/// so the RP before it is known. When that is not what the game before it left
/// them on, something happened in between that the history does not hold. Only
/// that is reported: a day with no games is a day off, not a hole.
///
/// What it cannot see: a missed game worth exactly 0 RP leaves the chain whole,
/// and an RP change outside a game (a penalty) shows as a gap. A game whose RP
/// change was corrected by hand, or that was left out as a reset artifact, is
/// not taken to start a break, since its change is not what the chain was built
/// from. A reading of 0 RP is a missing reading, not a score.
SplitCoverage splitCoverage(List<RankedMatch> matches) {
  final ranked =
      [
        for (final m in matches)
          if (m.isRanked) m,
      ]..sort((a, b) {
        final byStart = a.startTime.compareTo(b.startTime);
        return byStart != 0 ? byStart : a.endTime.compareTo(b.endTime);
      });
  // The biggest swing a game made, to say the fewest games a jump needs.
  var biggest = 1;
  for (final m in ranked) {
    if (!m.isAutoExcluded) biggest = math.max(biggest, m.rpChange.abs());
  }
  final gaps = <CoverageGap>[];
  for (var i = 1; i < ranked.length; i++) {
    final before = ranked[i - 1];
    final game = ranked[i];
    if (game.editedFields.contains('rp_change') || game.isAutoExcluded) {
      continue;
    }
    if (before.cumulativeRp <= 0 || game.cumulativeRp <= 0) continue;
    final jump = (game.cumulativeRp - game.rpChange) - before.cumulativeRp;
    if (jump == 0) continue;
    gaps.add(
      CoverageGap(
        from: before.endTime,
        to: game.startTime,
        missing: math.max(1, (jump.abs() / biggest).ceil()),
      ),
    );
  }
  return SplitCoverage(gaps);
}
