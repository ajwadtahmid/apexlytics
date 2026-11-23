import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../utils/theme.dart';

/// One profile's column in a [SquadTable]: its name and its colour.
class SquadColumn {
  final String name;
  final Color color;
  const SquadColumn(this.name, this.color);
}

/// One row of a [SquadTable]: a label and a value for each column.
class SquadStatRow {
  final String label;

  /// A value per column; null for a profile with no reading.
  final List<num?> values;
  final String Function(num) format;

  /// True for a row that is a fact, not a score (games played): no leader.
  final bool neutral;

  /// True to colour each value green or red by its sign (RP).
  final bool signed;
  const SquadStatRow(
    this.label,
    this.values,
    this.format, {
    this.neutral = false,
    this.signed = false,
  });
}

/// Profiles side by side: a column each, a row per stat. The highest value of a
/// row is outlined in its profile's colour (a tie leaves it plain). The values
/// keep their own colour, so a gain or a loss still reads as one.
class SquadTable extends StatelessWidget {
  final List<SquadColumn> columns;
  final List<SquadStatRow> rows;

  /// Drawn under a column's name, such as the legend that profile played.
  final Widget Function(int column)? headerExtra;
  const SquadTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headerExtra,
  });

  static const _labelFlex = 5;
  static const _valueFlex = 6;

  @override
  Widget build(BuildContext context) {
    // At a larger text size a label no longer fits its narrow column without
    // breaking mid-word, so it takes a line to itself and the columns share
    // the whole width.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!large) const Expanded(flex: _labelFlex, child: SizedBox()),
            for (final (i, c) in columns.indexed)
              Expanded(
                flex: _valueFlex,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: ShapeDecoration(
                            color: c.color,
                            shape: switch (i) {
                              0 => RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                              ),
                              1 => const CircleBorder(),
                              _ => const StarBorder.polygon(
                                sides: 4,
                                pointRounding: 0.15,
                              ),
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          // Shrunk to its column at a larger text size, not cut
                          // to a few letters.
                          child: large
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(c.name, style: AppTheme.caption),
                                )
                              : Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.caption,
                                ),
                        ),
                      ],
                    ),
                    if (headerExtra != null) headerExtra!(i),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        for (final r in rows) _row(r, large),
      ],
    );
  }

  Widget _row(SquadStatRow r, bool large) {
    final present = r.values.whereType<num>().toList();
    final best = present.isEmpty ? null : present.reduce(math.max);
    final leads = !r.neutral && present.length > 1
        ? present.where((v) => v == best).length == 1
        : false;
    final cells = [
      for (final (i, v) in r.values.indexed)
        Expanded(
          flex: _valueFlex,
          child: Center(
            child: v == null
                ? const Text('–', style: AppTheme.caption)
                : _Value(
                    r.format(v),
                    tint: columns[i].color,
                    leads: leads && v == best,
                    color: r.signed
                        ? AppTheme.signColor(v >= 0)
                        : AppTheme.textPrimary,
                  ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label, style: AppTheme.caption),
                const SizedBox(height: 2),
                Row(children: cells),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: _labelFlex,
                  child: Text(r.label, style: AppTheme.caption),
                ),
                ...cells,
              ],
            ),
    );
  }
}

class _Value extends StatelessWidget {
  final String text;
  final Color tint;
  final bool leads;
  final Color color;
  const _Value(
    this.text, {
    required this.tint,
    required this.leads,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Scales down rather than overflowing at large text sizes.
    return Semantics(
      label: leads ? '$text, highest' : text,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          // An outline over a faint fill: a solid tint under green or red text
          // made the leading value hard to read.
          decoration: BoxDecoration(
            color: leads ? tint.withValues(alpha: 0.08) : null,
            border: Border.all(
              color: leads ? tint : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: leads ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
