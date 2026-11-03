import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/ranked/play_calendar.dart';
import 'package:apexlytics/utils/ranked/ranked_aggregates.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  /// A ranked game starting at a local clock time, so the test means the same
  /// in any time zone.
  RankedMatch game(DateTime start, {int rp = 10}) => buildMatch(
    start: start.millisecondsSinceEpoch ~/ 1000,
    rp: rp,
    length: 600,
  );

  group('dailyPlay', () {
    test('a game counts on the day it started', () {
      // 11:30 PM on the 3rd and 12:10 AM on the 4th are one session (under two
      // hours apart), but each game belongs to the day it started.
      final sessions = sessionize([
        game(DateTime(2026, 11, 3, 23, 30), rp: 20),
        game(DateTime(2026, 11, 4, 0, 10), rp: -8),
      ]);
      expect(sessions, hasLength(1));

      final days = dailyPlay(sessions);
      expect(
        days.keys,
        unorderedEquals([DateTime(2026, 11, 3), DateTime(2026, 11, 4)]),
      );
      expect(days[DateTime(2026, 11, 3)]!.netRp, 20);
      expect(days[DateTime(2026, 11, 4)]!.netRp, -8);
      // Both days are a part of the one session, and say so.
      for (final day in days.values) {
        expect(day.parts.single.isWhole, isFalse);
        expect(day.parts.single.whole, same(sessions.single));
      }
    });

    test('a session inside one day is that day, whole', () {
      final sessions = sessionize([
        game(DateTime(2026, 11, 3, 20, 0), rp: 20),
        game(DateTime(2026, 11, 3, 20, 20), rp: 20),
      ]);
      final day = dailyPlay(sessions)[DateTime(2026, 11, 3)]!;
      expect(day.parts.single.isWhole, isTrue);
      expect(day.parts.single.part, same(sessions.single));
    });

    test('adds up a day with two sessions, newest first', () {
      final sessions = sessionize([
        game(DateTime(2026, 11, 3, 9, 0), rp: 20),
        game(DateTime(2026, 11, 3, 9, 20), rp: -10),
        game(DateTime(2026, 11, 3, 21, 0), rp: 30),
      ]);
      final day = dailyPlay(sessions)[DateTime(2026, 11, 3)]!;

      expect(day.sessions, 2);
      expect(day.games, 3);
      expect(day.netRp, 40);
      expect(day.wins, 2);
      expect(day.losses, 1);
      expect(
        day.parts.first.part.start.isAfter(day.parts.last.part.start),
        isTrue,
      );
    });

    test('a day with no games has no entry, and none means none', () {
      expect(dailyPlay(const []), isEmpty);
      final days = dailyPlay(sessionize([game(DateTime(2026, 11, 3, 20, 0))]));
      expect(days.containsKey(DateTime(2026, 11, 4)), isFalse);
    });
  });

  group('calendarColumns', () {
    // A split that begins on a Tuesday at 10:00 and runs ten days: one full week
    // and a short second one.
    final season = SeasonMeta(
      id: 'br_ranked_s99_s1',
      displayName: 'S99',
      start: DateTime(2026, 11, 3, 10),
      end: DateTime(2026, 11, 13, 10),
    );
    final weeks = computeWeeks(season);

    test('a column per week, from the day the split began', () {
      final columns = calendarColumns(
        weeks,
        const {},
        now: DateTime(2026, 11, 5),
      );

      expect(columns, hasLength(2));
      expect(columns[0], hasLength(7));
      expect(columns[0].first.day, DateTime(2026, 11, 3));
      expect(columns[0].first.day.weekday, DateTime.tuesday);
      expect(columns[0].last.day, DateTime(2026, 11, 9));
      expect(columns[1].first.day, DateTime(2026, 11, 10));
    });

    test('the last week stops at the split\'s last day', () {
      final columns = calendarColumns(
        weeks,
        const {},
        now: DateTime(2026, 11, 5),
      );
      // The split ends on the 13th at 10:00, so the 13th is its last day.
      expect(columns[1].map((c) => c.day.day), [10, 11, 12, 13]);
    });

    test('a split that ends at midnight does not include the next day', () {
      final ends = SeasonMeta(
        id: 'br_ranked_s99_s1',
        displayName: 'S99',
        start: DateTime(2026, 11, 3),
        end: DateTime(2026, 11, 10),
      );
      final columns = calendarColumns(computeWeeks(ends), const {});
      expect(columns, hasLength(1));
      expect(columns.single.last.day, DateTime(2026, 11, 9));
    });

    test('marks today and the days after it', () {
      final columns = calendarColumns(
        weeks,
        const {},
        now: DateTime(2026, 11, 5, 15),
      );
      final cells = columns.expand((c) => c).toList();

      expect(cells.where((c) => c.today).single.day, DateTime(2026, 11, 5));
      expect(cells.where((c) => c.future).first.day, DateTime(2026, 11, 6));
      expect(cells.where((c) => c.future && c.today), isEmpty);
    });

    test('carries each day\'s games to its cell', () {
      final days = dailyPlay(
        sessionize([game(DateTime(2026, 11, 4, 20, 0), rp: 25)]),
      );
      final cells = calendarColumns(
        weeks,
        days,
        now: DateTime(2026, 11, 12),
      ).expand((c) => c).toList();

      expect(
        cells.where((c) => c.play != null).single.day,
        DateTime(2026, 11, 4),
      );
      expect(cells.first.play, isNull);
    });

    // It ends at the time it began, 28 days on: that Tuesday is past the fourth
    // week's last day but still holds the split's last games.
    final real = SeasonMeta(
      id: 'br_ranked_s99_s1',
      displayName: 'S99',
      start: DateTime(2026, 10, 27, 10),
      end: DateTime(2026, 11, 24, 10),
    );

    test('a split\'s last morning gets a cell of its own while it runs', () {
      final columns = calendarColumns(
        computeWeeks(real),
        const {},
        now: DateTime(2026, 11, 20),
      );

      expect(columns, hasLength(5));
      expect(columns.last.map((c) => c.day), [DateTime(2026, 11, 24)]);
      expect(columns.last.single.week, 4);
    });

    test('once the split is over, an empty last morning is left out', () {
      final columns = calendarColumns(
        computeWeeks(real),
        const {},
        now: DateTime(2026, 11, 25),
      );

      expect(columns, hasLength(4));
      expect(columns.last.last.day, DateTime(2026, 11, 23));
    });

    test('but kept once the split is over if a game was played in it', () {
      final days = dailyPlay(
        sessionize([game(DateTime(2026, 11, 24, 8, 0), rp: 15)]),
      );
      final columns = calendarColumns(
        computeWeeks(real),
        days,
        now: DateTime(2026, 11, 25),
      );

      expect(columns, hasLength(5));
      expect(columns.last.single.play?.netRp, 15);
    });

    test('a week with no games in the middle is never left out', () {
      final columns = calendarColumns(
        computeWeeks(real),
        const {},
        now: DateTime(2026, 12, 20),
      );
      expect(columns.take(4).every((c) => c.isNotEmpty), isTrue);
      expect(columns, hasLength(4));
    });

    test('a clock change does not move a week\'s first day', () {
      // US clocks go back on Nov 1, 2026. Weeks are built from the date of the
      // first day, not by adding 168 hours, which would land an hour early and,
      // under a US time zone, add a week of one hour to the split.
      final across = SeasonMeta(
        id: 'br_ranked_s99_s1',
        displayName: 'S99',
        start: DateTime(2026, 10, 27, 10),
        end: DateTime(2026, 11, 24, 10),
      );
      final columns = calendarColumns(
        computeWeeks(across),
        const {},
        now: DateTime(2026, 11, 20),
      );

      expect(columns.map((c) => c.first.day), [
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 17),
        DateTime(2026, 11, 24),
      ]);
      for (final column in columns) {
        expect(column.first.day.weekday, DateTime.tuesday);
      }
    });

    test('an empty list of weeks is no calendar', () {
      expect(calendarColumns(const [], const {}), isEmpty);
    });
  });

  group('calendarScale', () {
    DayPlay day(int rp) {
      final session = sessionize([
        game(DateTime(2026, 11, 3, 20), rp: rp),
      ]).single;
      return DayPlay(
        day: DateTime(2026, 11, 3),
        parts: [DayPart(part: session, whole: session)],
      );
    }

    test('ignores one huge day', () {
      final days = [for (var i = 1; i <= 40; i++) day(10 + i), day(900)];
      expect(calendarScale(days), lessThan(100));
    });

    test('is at least one, even with nothing', () {
      expect(calendarScale(const []), 1);
    });
  });
}
