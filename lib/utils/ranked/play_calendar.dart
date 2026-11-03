import '../../models/ranked_match.dart';
import '../formatting/season_utils.dart' show WeekRange;
import 'ranked_aggregates.dart';

/// The local calendar date of [t], with no time.
DateTime calendarDay(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The games of one session that started on one day. A session that runs past
/// midnight has a part on each day; [part] is only that day's games, and
/// [whole] is the session it came from, which is what a tap opens.
class DayPart {
  final RankedSession part;
  final RankedSession whole;
  const DayPart({required this.part, required this.whole});

  /// Whether the session began and ended within the day.
  bool get isWhole => identical(part, whole) || part.games == whole.games;
}

/// What was played on one day. A game counts on the day it started.
class DayPlay {
  final DateTime day;

  /// The day's sessions, newest first.
  final List<DayPart> parts;

  const DayPlay({required this.day, required this.parts});

  int get netRp => parts.fold(0, (n, p) => n + p.part.netRp);
  int get games => parts.fold(0, (n, p) => n + p.part.games);
  int get wins => parts.fold(0, (n, p) => n + p.part.wins);
  int get losses => parts.fold(0, (n, p) => n + p.part.losses);
  int get sessions => parts.length;
}

/// [sessions] cut by the day each game started, keyed by local date. A day with
/// no games has no entry.
Map<DateTime, DayPlay> dailyPlay(List<RankedSession> sessions) {
  final byDay = <DateTime, List<DayPart>>{};
  for (final session in sessions) {
    final games = <DateTime, List<RankedMatch>>{};
    for (final m in session.matches) {
      games.putIfAbsent(calendarDay(m.startTime), () => []).add(m);
    }
    for (final MapEntry(key: day, value: onDay) in games.entries) {
      final part = onDay.length == session.matches.length
          ? session
          : sessionFromGames(onDay);
      if (part == null) continue;
      byDay.putIfAbsent(day, () => []).add(DayPart(part: part, whole: session));
    }
  }
  return {
    for (final MapEntry(key: day, value: parts) in byDay.entries)
      day: DayPlay(
        day: day,
        parts: parts..sort((a, b) => b.part.start.compareTo(a.part.start)),
      ),
  };
}

/// One square of the calendar.
class CalendarCell {
  final DateTime day;

  /// Which of the split's weeks (0 for the first) and which row of it.
  final int week;
  final int row;

  /// The day's games, or null when none were played.
  final DayPlay? play;

  /// Whether the day is after today.
  final bool future;
  final bool today;

  const CalendarCell({
    required this.day,
    required this.week,
    required this.row,
    required this.play,
    required this.future,
    required this.today,
  });
}

/// The calendar as a column per week of the split, each a run of seven days from
/// the date the split's first week began, so the rows are the weekdays that
/// split started on. Days are built with the date constructor, never by adding
/// 24 hours, so a clock change cannot move one.
///
/// A split ends at the time of day it began, so its last day is usually the
/// first day of a week that has no hours left in it: that day still holds the
/// split's last games, so it gets a column of its own (one cell). The columns
/// are counted from the dates, not from [weeks], so no day of the split is left
/// out. Days after the split's last day are not drawn.
///
/// Once the split is over, a trailing column past the last week that holds no
/// games is left out: nothing more can happen in it, and an empty square with no
/// week number only looks like a mistake. It stays while the split runs, and
/// whenever a game was played in it.
///
/// A week starts when the split does (a time of day, not midnight), so a day
/// holding a week boundary sits in the column of its date; no column adds the
/// days up.
List<List<CalendarCell>> calendarColumns(
  List<WeekRange> weeks,
  Map<DateTime, DayPlay> days, {
  DateTime? now,
}) {
  if (weeks.isEmpty) return const [];
  final today = calendarDay(now ?? DateTime.now());
  final first = calendarDay(weeks.first.start);
  // The end is exclusive, so a split that ends at midnight ends the day before.
  final last = calendarDay(
    weeks.last.end.subtract(const Duration(milliseconds: 1)),
  );
  // Whole days by their dates, which a clock change cannot shorten.
  final span =
      DateTime.utc(
        last.year,
        last.month,
        last.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays +
      1;
  final count = span < 1 ? 1 : (span + 6) ~/ 7;
  final columns = [
    for (var w = 0; w < count; w++)
      [
        for (var r = 0; r < 7; r++)
          if (!DateTime(
            first.year,
            first.month,
            first.day + 7 * w + r,
          ).isAfter(last))
            () {
              final day = DateTime(
                first.year,
                first.month,
                first.day + 7 * w + r,
              );
              return CalendarCell(
                day: day,
                week: w,
                row: r,
                play: days[day],
                future: day.isAfter(today),
                today: day == today,
              );
            }(),
      ],
  ];
  final over = !(now ?? DateTime.now()).isBefore(weeks.last.end);
  while (over &&
      columns.length > weeks.length &&
      columns.last.every((c) => c.play == null)) {
    columns.removeLast();
  }
  return columns;
}

/// The RP a day has to net, up or down, to be drawn at full strength: the 95th
/// percentile of the days' absolute RP, so one huge day does not wash the rest
/// out. At least 1.
int calendarScale(Iterable<DayPlay> days) {
  final values = [for (final d in days) d.netRp.abs()]..sort();
  if (values.isEmpty) return 1;
  final i = ((values.length - 1) * 0.95).round();
  return values[i] < 1 ? 1 : values[i];
}

/// Fewer than this many played days is not enough for a calendar to say anything.
const kCalendarMinDays = 3;
