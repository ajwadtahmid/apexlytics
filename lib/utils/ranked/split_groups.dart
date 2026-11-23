/// Groups the splits in the picker by season, for the season sheet: one row per
/// season with its splits as chips, newest first.
library;

import '../../models/season_meta.dart';
import 'ranked_period.dart';

/// One season and the splits of it that are in the picker, in play order.
class SeasonGroup {
  final int number;
  final List<RankedSplitBucket> splits;
  const SeasonGroup({required this.number, required this.splits});
}

/// What the season sheet lists.
class SplitGroups {
  /// The synthetic "Lifetime" bucket, when it is offered.
  final RankedSplitBucket? lifetime;

  /// Seasons with a recognisable id, newest first.
  final List<SeasonGroup> seasons;

  /// Anything else ("Unknown", or an id that is not a split).
  final List<RankedSplitBucket> others;
  const SplitGroups({
    required this.lifetime,
    required this.seasons,
    required this.others,
  });
}

/// The split number of [split] (`br_ranked_s29_s2` is 2), or 0.
int splitNumberOf(RankedSplitBucket split) =>
    SeasonMeta.parseSplitId(split.id)?.split ?? 0;

SplitGroups groupSplits(List<RankedSplitBucket> splits) {
  RankedSplitBucket? lifetime;
  final bySeason = <int, List<RankedSplitBucket>>{};
  final others = <RankedSplitBucket>[];
  for (final s in splits) {
    if (isLifetimeSplit(s.id)) {
      lifetime = s;
      continue;
    }
    final parsed = SeasonMeta.parseSplitId(s.id);
    if (parsed == null) {
      others.add(s);
    } else {
      bySeason.putIfAbsent(parsed.season, () => []).add(s);
    }
  }
  final numbers = bySeason.keys.toList()..sort((a, b) => b.compareTo(a));
  return SplitGroups(
    lifetime: lifetime,
    seasons: [
      for (final n in numbers)
        SeasonGroup(
          number: n,
          splits: bySeason[n]!
            ..sort(
              (a, b) => (SeasonMeta.parseSplitId(a.id)?.split ?? 0).compareTo(
                SeasonMeta.parseSplitId(b.id)?.split ?? 0,
              ),
            ),
        ),
    ],
    others: others,
  );
}
