import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/formatting/format.dart' show formatSignedInt, plural;
import '../../../utils/formatting/season_utils.dart' show WeekRange;
import '../../../utils/ranked/play_calendar.dart';
import '../../../utils/ranked/ranked_aggregates.dart';
import '../../../utils/theme.dart';
import '../../../widgets/rp_pill.dart';
import '../../../widgets/sheet_handle.dart';
import 'session_card.dart';

/// A calendar of the split: a column per week, a square per day shaded by the RP
/// the games that started that day netted. Tapping a played day lists its
/// sessions. [sessions] is the whole split's, newest first, whichever week the
/// page is showing; [selectedWeek] (an index, -1 for none) is outlined.
class PlayCalendar extends StatefulWidget {
  final List<WeekRange> weeks;
  final List<RankedSession> sessions;
  final int selectedWeek;

  /// Opens one session's games.
  final ValueChanged<RankedSession> onOpen;

  /// Stands in for the current time.
  @visibleForTesting
  final DateTime? now;

  const PlayCalendar({
    super.key,
    required this.weeks,
    required this.sessions,
    required this.onOpen,
    this.selectedWeek = -1,
    this.now,
  });

  @override
  State<PlayCalendar> createState() => _PlayCalendarState();
}

class _PlayCalendarState extends State<PlayCalendar> {
  static const _labelWidth = 30.0;
  static const _gap = 3.0;
  static const _headerHeight = 16.0;

  late Map<DateTime, DayPlay> _days = dailyPlay(widget.sessions);

  @override
  void didUpdateWidget(PlayCalendar old) {
    super.didUpdateWidget(old);
    if (!identical(old.sessions, widget.sessions)) {
      _days = dailyPlay(widget.sessions);
    }
  }

  Color _colorOf(DayPlay play, int scale) {
    final base = play.netRp == 0
        ? AppTheme.muted
        : AppTheme.signColor(play.netRp > 0);
    final strength = (play.netRp.abs() / scale).clamp(0.0, 1.0);
    // Never fainter than 30%, so a small day does not look like no day.
    return base.withValues(alpha: 0.3 + 0.7 * strength);
  }

  Widget _cell(CalendarCell c, double size, int scale) {
    final play = c.play;
    final BoxDecoration decoration;
    if (play == null) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: c.today ? AppTheme.textPrimary : AppTheme.surface2,
          width: c.today ? 1.5 : 1,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: _colorOf(play, scale),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: c.today
              ? AppTheme.textPrimary
              : (play.netRp == 0
                    ? AppTheme.muted
                    : AppTheme.signColor(play.netRp > 0)),
          width: c.today ? 1.5 : 1,
        ),
      );
    }
    final label = DateFormat('MMM d').format(c.day);
    return Semantics(
      button: play != null,
      label: play == null
          ? '$label, no games'
          : '$label, ${formatSignedInt(play.netRp)} RP, '
                '${plural(play.sessions, 'session')}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: play == null ? null : () => _showDay(play),
        child: Opacity(
          opacity: c.future ? 0.4 : 1,
          child: Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(bottom: _gap),
            decoration: decoration,
          ),
        ),
      ),
    );
  }

  void _showDay(DayPlay play) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.md,
            AppTheme.md,
            AppTheme.md,
            AppTheme.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMM d').format(play.day),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RpPill(totalRp: play.netRp),
                ],
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                '${plural(play.games, 'game')}, ${play.wins}W-${play.losses}L'
                ' · ${plural(play.sessions, 'session')}',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppTheme.md),
              for (final part in play.parts) ...[
                SessionCard(
                  session: part.part,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onOpen(part.whole);
                  },
                ),
                if (!part.isWhole)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTheme.xs),
                    child: Text(
                      'Only the games that started this day. Tap to see the '
                      'whole session.',
                      style: AppTheme.captionSmall,
                    ),
                  ),
                const SizedBox(height: AppTheme.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_days.length < kCalendarMinDays) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: Center(
          child: Text(
            'Not enough days yet. The calendar fills in as you play.',
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
        ),
      );
    }
    final columns = calendarColumns(widget.weeks, _days, now: widget.now);
    final scale = calendarScale(_days.values);
    final firstDay = calendarDay(widget.weeks.first.start);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final n = columns.length;
            final fit = (constraints.maxWidth - _labelWidth) / n - _gap - 2;
            final size = fit.clamp(16.0, 28.0);
            final grid = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: _headerHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Week', style: AppTheme.captionSmall),
                        ),
                      ),
                      for (var r = 0; r < 7; r++)
                        SizedBox(
                          height: size + _gap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              DateFormat('EEE').format(
                                DateTime(
                                  firstDay.year,
                                  firstDay.month,
                                  firstDay.day + r,
                                ),
                              ),
                              style: AppTheme.captionSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final (w, column) in columns.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: w == widget.selectedWeek
                              ? AppTheme.accent
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: _headerHeight,
                            child: Center(
                              child: Text(
                                // The split's last day, past its final week,
                                // has no week number.
                                w < widget.weeks.length ? '${w + 1}' : '',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: w == widget.selectedWeek
                                      ? AppTheme.accent
                                      : AppTheme.muted,
                                ),
                              ),
                            ),
                          ),
                          for (final cell in column) _cell(cell, size, scale),
                        ],
                      ),
                    ),
                  ),
              ],
            );
            // A very long split scrolls rather than squeezing the squares.
            final needed = _labelWidth + n * (size + _gap + 2);
            return needed > constraints.maxWidth
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: grid,
                  )
                : grid;
          },
        ),
        const SizedBox(height: AppTheme.sm),
        Row(
          children: [
            const Text('Loss', style: AppTheme.captionSmall),
            const SizedBox(width: AppTheme.xs),
            for (final (color, strength) in [
              (AppTheme.red, 1.0),
              (AppTheme.red, 0.0),
              (AppTheme.muted, 0.0),
              (AppTheme.green, 0.0),
              (AppTheme.green, 1.0),
            ])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3 + 0.7 * strength),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 2),
            const Text('Gain', style: AppTheme.captionSmall),
          ],
        ),
      ],
    );
  }
}
