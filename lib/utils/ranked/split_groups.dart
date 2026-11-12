/// Groups the splits in the picker by season, for the season sheet: one row per
/// season with its splits as chips, newest first.
library;

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

final _splitId = RegExp(r's(\d+)_s(\d+)$');

/// The split number in an id (`br_ranked_s29_s2` is 2), or 0.
int _splitNumber(String id) {
  final m = _splitId.firstMatch(id);
  return m == null ? 0 : int.parse(m.group(2)!);
}

/// The split number of [split] (`br_ranked_s29_s2` is 2), or 0.
int splitNumberOf(RankedSplitBucket split) => _splitNumber(split.id);

SplitGroups groupSplits(List<RankedSplitBucket> splits) {
  RankedSplitBucket? lifetime;
  final bySeason = <int, List<RankedSplitBucket>>{};
  final others = <RankedSplitBucket>[];
  for (final s in splits) {
    if (isLifetimeSplit(s.id)) {
      lifetime = s;
      continue;
    }
    final m = _splitId.firstMatch(s.id);
    if (m == null) {
      others.add(s);
    } else {
      bySeason.putIfAbsent(int.parse(m.group(1)!), () => []).add(s);
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
            ..sort((a, b) => _splitNumber(a.id).compareTo(_splitNumber(b.id))),
        ),
    ],
    others: others,
  );
}
