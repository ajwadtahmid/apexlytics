import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:apexlytics/utils/ranked/split_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RankedSplitBucket b(String id) => RankedSplitBucket(id: id, displayName: id);

  test('groups splits by season, newest season first, splits in order', () {
    final g = groupSplits([
      b(kLifetimeSplitId),
      b('br_ranked_s31_s1'),
      b('br_ranked_s30_s2'),
      b('br_ranked_s30_s1'),
      b('br_ranked_s29_s2'),
    ]);

    expect(g.lifetime?.id, kLifetimeSplitId);
    expect(g.seasons.map((s) => s.number), [31, 30, 29]);
    expect(g.seasons[1].splits.map((s) => s.id), [
      'br_ranked_s30_s1',
      'br_ranked_s30_s2',
    ]);
    expect(g.others, isEmpty);
  });

  test('keeps Unknown and non-split ids apart, and works without Lifetime', () {
    final g = groupSplits([b('br_ranked_s30_s1'), b(kUnknownSplitId)]);

    expect(g.lifetime, isNull);
    expect(g.seasons, hasLength(1));
    expect(g.others.map((s) => s.id), [kUnknownSplitId]);
  });

  test('sorts seasons by number, not by text', () {
    final g = groupSplits([b('br_ranked_s9_s1'), b('br_ranked_s10_s1')]);

    expect(g.seasons.map((s) => s.number), [10, 9]);
  });
}
