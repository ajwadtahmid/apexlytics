import 'package:apexlytics/screens/ranked/ranked_recap_entry.dart'
    show recordPeriodLabel;
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
    history: const [],
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
}
