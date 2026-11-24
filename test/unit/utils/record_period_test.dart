import 'package:apexlytics/screens/ranked/ranked_recap_entry.dart'
    show periodSectionLabel, recapPeriodPhrase, recordPeriodLabel;
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();
  const day = Duration(days: 1);

  // Three weeks: one over, the one going on now, and one to come.
  RankedView view(int weekIndex) => RankedView(
    splits: const [],
    effectiveSplitId: '',
    weeks: [
      WeekRange(start: now.subtract(day * 14), end: now.subtract(day * 7)),
      WeekRange(start: now.subtract(day * 7), end: now.add(day * 7)),
      WeekRange(start: now.add(day * 7), end: now.add(day * 14)),
    ],
    weekIndex: weekIndex,
    filtered: const [],
    gamesInPeriod: const [],
  );

  group('what a record is the best of', () {
    test('this split with all weeks', () {
      expect(recordPeriodLabel(view(-1)), 'this split');
    });

    test('this week for the week going on now, otherwise its number', () {
      expect(recordPeriodLabel(view(1)), 'this week');
      expect(recordPeriodLabel(view(0)), 'Week 1');
    });
  });

  // The same three weeks, in a split with a name.
  RankedView named(int weekIndex, {String id = 'br_ranked_s31_s1'}) =>
      RankedView(
        splits: [
          RankedSplitBucket(id: id, displayName: 'S30 Split 2'),
          const RankedSplitBucket(id: kLifetimeSplitId, displayName: 'Lifetime'),
        ],
        effectiveSplitId: id,
        weeks: view(weekIndex).weeks,
        weekIndex: weekIndex,
        filtered: const [],
        gamesInPeriod: const [],
      );

  group('the title over the Stats figures', () {
    test('says this split and this week for the period going on now', () {
      expect(periodSectionLabel(named(-1), currentSplit: true), 'This split');
      expect(periodSectionLabel(named(1), currentSplit: true), 'This week');
    });

    test('numbers a past week of the current split', () {
      expect(periodSectionLabel(named(0), currentSplit: true), 'Week 1');
    });

    test('names a split that is over instead of calling it this one', () {
      expect(
        periodSectionLabel(named(-1), currentSplit: false),
        'S30 Split 2 · All weeks',
      );
      expect(
        periodSectionLabel(named(1), currentSplit: false),
        'S30 Split 2 · Week 2',
      );
    });

    test('names all seasons', () {
      expect(
        periodSectionLabel(
          named(-1, id: kLifetimeSplitId),
          currentSplit: false,
        ),
        startsWith('Lifetime'),
      );
    });
  });

  group('where the RP on a recap was made', () {
    test('this split for the one going on now', () {
      expect(recapPeriodPhrase(named(-1)), 'this split');
    });

    test('the split by name once it is over', () {
      expect(recapPeriodPhrase(named(-1), currentSplit: false), 'in S30 Split 2');
    });

    test('a picked week, and all seasons', () {
      expect(recapPeriodPhrase(named(2)), 'in Week 3');
      expect(
        recapPeriodPhrase(named(-1, id: kLifetimeSplitId), currentSplit: false),
        'over all seasons',
      );
    });
  });
}
