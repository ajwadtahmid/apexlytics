import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../constants/rank_constants.dart';
import '../../../utils/formatting/format.dart'
    show formatNumber, formatShortDate;
import '../../../utils/formatting/rank_utils.dart' show rankIndex;
import '../../../utils/ranked/rank_climb.dart';
import '../../../utils/theme.dart';
import '../../../widgets/surface_card.dart';

/// The RP through a split, a point a game, with a dashed line at the start of
/// each division in its tier's colour and a dot at every promotion and
/// demotion. The names of the divisions sit in a column beside the plot, so the
/// line never runs over them.
class ClimbChart extends StatelessWidget {
  final RankClimb climb;
  const ClimbChart({super.key, required this.climb});

  static const _height = 190.0;
  static const _labelWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    final games = climb.games;
    final totals = [climb.startRp, for (final g in games) g.cumulativeRp];
    final low = totals.reduce(math.min);
    final high = totals.reduce(math.max);
    final pad = math.max(150, ((high - low) * 0.12).round());
    final minY = math.max(0, low - pad).toDouble();
    final maxY = (high + pad).toDouble();
    final pxPerRp = _height / (maxY - minY);

    // The divisions inside the chart; a name only where there is room for it.
    final lines = <HorizontalLine>[];
    final labels = <Widget>[];
    double? lastLabelled;
    for (final d in kRankLadder.reversed) {
      if (d.rp <= minY || d.rp >= maxY) continue;
      final room =
          lastLabelled == null || (lastLabelled - d.rp) * pxPerRp >= 14;
      if (room) lastLabelled = d.rp.toDouble();
      final color = rankDisplayColor(d);
      lines.add(
        HorizontalLine(
          y: d.rp.toDouble(),
          color: color.withValues(alpha: 0.45),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      );
      if (room) {
        labels.add(
          Positioned(
            top: (maxY - d.rp) / (maxY - minY) * _height - 7,
            left: 6,
            right: 0,
            child: Text(
              d.label,
              maxLines: 1,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
        );
      }
    }

    final moveAt = {for (final m in climb.moves) m.game: m};
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RP THROUGH THE SPLIT', style: AppTheme.cardTitle),
          const SizedBox(height: 2),
          const Text(
            'Drag across it for a game. Dots are promotions and demotions.',
            style: AppTheme.captionSmall,
          ),
          const SizedBox(height: AppTheme.md),
          Semantics(
            label:
                'RP through the split, from ${formatNumber(climb.startRp)} to '
                '${formatNumber(climb.currentRp)}, '
                '${climb.promotions} promotions and ${climb.demotions} '
                'demotions',
            child: SizedBox(
              height: _height,
              child: Row(
                children: [
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: games.length.toDouble(),
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        extraLinesData: ExtraLinesData(horizontalLines: lines),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => AppTheme.surface2,
                            getTooltipItems: (touched) => [
                              for (final t in touched)
                                LineTooltipItem(
                                  t.x == 0
                                      ? 'Start\n${formatNumber(climb.startRp)} RP'
                                      : 'Game ${t.x.toInt()}\n'
                                            '${formatNumber(t.y.round())} RP · '
                                            '${kRankLadder[rankIndex(t.y.round())].label}',
                                  const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (final (i, v) in totals.indexed)
                                FlSpot(i.toDouble(), v.toDouble()),
                            ],
                            color: AppTheme.accent,
                            barWidth: 2.2,
                            isCurved: false,
                            dotData: FlDotData(
                              checkToShowDot: (spot, _) =>
                                  moveAt.containsKey(spot.x.toInt()),
                              getDotPainter: (spot, _, _, _) =>
                                  FlDotCirclePainter(
                                    radius: 4.5,
                                    color: moveAt[spot.x.toInt()]!.up
                                        ? AppTheme.green
                                        : AppTheme.red,
                                    strokeColor: AppTheme.surface,
                                    strokeWidth: 1.5,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.accent.withValues(alpha: 0.07),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _labelWidth,
                    child: ExcludeSemantics(child: Stack(children: labels)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Row(
            children: [
              Text(
                formatShortDate(games.first.startTime),
                style: AppTheme.captionSmall,
              ),
              const Spacer(),
              Text(
                formatShortDate(games.last.endTime),
                style: AppTheme.captionSmall,
              ),
              const SizedBox(width: _labelWidth),
            ],
          ),
        ],
      ),
    );
  }
}
