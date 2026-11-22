import 'package:material_ui/material_ui.dart';

import '../../../constants/map_constants.dart';
import '../../../constants/rank_constants.dart';
import '../../../models/ranked_match.dart';
import '../../../utils/formatting/format.dart'
    show
        formatClock,
        formatDuration,
        formatNumber,
        formatShortDate,
        formatSignedInt,
        plural;
import '../../../utils/ranked/rank_climb.dart';
import '../../../utils/theme.dart';
import '../../../widgets/legend_icon.dart';
import '../../../widgets/map_asset_image.dart';
import '../../../widgets/sheet_handle.dart';
import '../../../widgets/surface_card.dart';
import 'climb_parts.dart';
import 'match_detail_sheet.dart';

/// Every promotion and demotion of the split, newest first, as it happened,
/// under a card of the ups and downs and the best and worst runs. A change of
/// tier is the headline; a change of division inside a tier is quiet, and a
/// chip leaves those out. Tapping a move opens the games that caused it.
class ClimbMoves extends StatefulWidget {
  final RankClimb climb;

  /// Called after a game opened from a move is edited, so the page can reload.
  final VoidCallback? onEdited;
  const ClimbMoves({super.key, required this.climb, this.onEdited});

  @override
  State<ClimbMoves> createState() => _ClimbMovesState();
}

class _ClimbMovesState extends State<ClimbMoves> {
  bool _tierOnly = false;

  @override
  Widget build(BuildContext context) {
    final climb = widget.climb;
    if (climb.moves.isEmpty) {
      final d = kRankLadder[climb.currentRung];
      return SurfaceCard(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Text(
          'No rank changes yet. Still ${d.label} after '
          '${plural(climb.games.length, 'game')}.',
          style: AppTheme.captionLarge,
        ),
      );
    }

    final moves = climb.moves;
    bool visible(RankMove m) => !_tierOnly || m.crossesTier;
    final shown = [
      for (final m in moves)
        if (visible(m)) m,
    ];

    // The division moves left out after a shown move, up to the next one.
    List<RankMove> hiddenAfter(RankMove m) {
      final out = <RankMove>[];
      for (var k = moves.indexOf(m) + 1; k < moves.length; k++) {
        if (visible(moves[k])) break;
        out.add(moves[k]);
      }
      return out;
    }

    final hiddenAtStart = <RankMove>[];
    for (final m in moves) {
      if (visible(m)) break;
      hiddenAtStart.add(m);
    }

    final rows = <Widget>[];
    for (final m in shown.reversed) {
      final hidden = hiddenAfter(m);
      if (hidden.isNotEmpty) rows.add(_Between(hidden));
      rows.add(
        m.crossesTier
            ? _TierRow(
                move: m,
                onTap: () => showClimbGamesSheet(
                  context,
                  climb,
                  m,
                  onEdited: widget.onEdited,
                ),
              )
            : _DivisionRow(
                move: m,
                onTap: () => showClimbGamesSheet(
                  context,
                  climb,
                  m,
                  onEdited: widget.onEdited,
                ),
              ),
      );
    }
    if (hiddenAtStart.isNotEmpty) rows.add(_Between(hiddenAtStart));
    rows.add(_StartRow(climb: climb));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UpsAndDowns(climb: climb),
        const SizedBox(height: AppTheme.md),
        SurfaceCard(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THE TIMELINE', style: AppTheme.cardTitle),
                        Text('Newest first', style: AppTheme.captionSmall),
                      ],
                    ),
                  ),
                  // On is solid orange with dark text and a tick, off a quiet
                  // outline, as on the Recap share page.
                  FilterChip(
                    label: const Text('Tier changes only'),
                    selected: _tierOnly,
                    onSelected: (v) => setState(() => _tierOnly = v),
                    showCheckmark: true,
                    checkmarkColor: AppTheme.onAccent,
                    selectedColor: AppTheme.accent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: _tierOnly
                          ? AppTheme.accent
                          : AppTheme.muted.withAlpha(120),
                    ),
                    labelStyle: TextStyle(
                      color: _tierOnly ? AppTheme.onAccent : AppTheme.muted,
                      fontWeight: _tierOnly
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              if (shown.isEmpty) ...[
                Text(
                  'No change of tier yet, only '
                  '${plural(moves.length, 'division move')} inside '
                  '${tierOfRung(climb.currentRung)}. Turn the filter off to '
                  'see them.',
                  style: AppTheme.captionLarge,
                ),
                const SizedBox(height: AppTheme.md),
              ],
              ...rows,
            ],
          ),
        ),
      ],
    );
  }
}

/// How many ups and downs, and the best and worst runs of games.
class _UpsAndDowns extends StatelessWidget {
  final RankClimb climb;
  const _UpsAndDowns({required this.climb});

  @override
  Widget build(BuildContext context) {
    final best = climb.biggestClimb;
    final worst = climb.biggestSlide;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UPS AND DOWNS', style: AppTheme.cardTitle),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              ClimbFigure(
                '↑ ${climb.promotions}',
                climb.promotions == 1 ? 'promotion' : 'promotions',
                color: AppTheme.green,
              ),
              ClimbFigure(
                '↓ ${climb.demotions}',
                climb.demotions == 1 ? 'demotion' : 'demotions',
                color: AppTheme.red,
              ),
              ClimbFigure(
                formatSignedInt(climb.net),
                'net RP',
                color: AppTheme.signColor(climb.net >= 0),
              ),
            ],
          ),
          if (best != null) ...[
            const SizedBox(height: AppTheme.md),
            _RunLine(label: 'Biggest climb', run: best, up: true),
          ],
          if (worst != null) ...[
            const SizedBox(height: AppTheme.sm),
            _RunLine(label: 'Biggest slide', run: worst, up: false),
          ],
        ],
      ),
    );
  }
}

class _RunLine extends StatelessWidget {
  final String label;
  final ClimbRun run;
  final bool up;
  const _RunLine({required this.label, required this.run, required this.up});

  @override
  Widget build(BuildContext context) {
    final color = up ? AppTheme.green : AppTheme.red;
    return Row(
      children: [
        Icon(up ? Icons.north_east : Icons.south_east, size: 16, color: color),
        const SizedBox(width: AppTheme.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text(
                '${plural(run.games, 'game')} · ${formatShortDate(run.from)}'
                ' to ${formatShortDate(run.to)}',
                style: AppTheme.captionSmall,
              ),
            ],
          ),
        ),
        Text(
          '${formatSignedInt(run.amount)} RP',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The rail down the left of the timeline: a node, and a line to the next.
class _Rail extends StatelessWidget {
  final Widget node;
  final bool line;
  const _Rail({required this.node, this.line = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          node,
          if (line)
            Expanded(child: Container(width: 2, color: AppTheme.surface2)),
        ],
      ),
    );
  }
}

String _stretch(int games, int rp, Duration time) =>
    '${plural(games, 'game')} over ${formatDuration(time.inSeconds)} · '
    '${formatSignedInt(rp)} RP';

/// A change of tier: the headline of the timeline.
class _TierRow extends StatelessWidget {
  final RankMove move;
  final VoidCallback onTap;
  const _TierRow({required this.move, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final to = kRankLadder[move.to];
    final title = switch (move.kind) {
      MoveKind.tierFirst => 'Reached ${to.tier}',
      MoveKind.tierBack => 'Back in ${to.tier}',
      _ => 'Dropped back to ${to.tier}',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(node: ClimbArrow(up: move.up, size: 30)),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClimbBadge(move.to, 28),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: rankDisplayColor(to),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (move.kind == MoveKind.tierFirst)
                                const ClimbTag('FIRST', AppTheme.green),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${to.label} · ${formatNumber(move.total)} RP · '
                      '${formatShortDate(move.at)}, ${formatClock(move.at)} · '
                      'game ${move.game}',
                      style: AppTheme.captionSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${move.fromStart ? 'Since the start' : 'Since the last tier change'}: '
                      '${_stretch(move.stretchGames, move.stretchRp, move.stretchTime)}',
                      style: TextStyle(
                        color: AppTheme.signColor(move.stretchRp >= 0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A change of division inside a tier: small and quiet.
class _DivisionRow extends StatelessWidget {
  final RankMove move;
  final VoidCallback onTap;
  const _DivisionRow({required this.move, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = move.up ? AppTheme.green : AppTheme.red;
    final to = kRankLadder[move.to];
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(
              node: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Icon(
                  move.up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${move.up ? 'Up' : 'Down'} to ${to.label}',
                            style: TextStyle(color: color, fontSize: 13),
                          ),
                          Text(
                            '${formatShortDate(move.at)} · game ${move.game} · '
                            '${plural(move.gamesSincePrev, 'game')} after the '
                            'last move',
                            style: AppTheme.captionSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 division moves in between" where they are left out.
class _Between extends StatelessWidget {
  final List<RankMove> moves;
  const _Between(this.moves);

  @override
  Widget build(BuildContext context) {
    final up = moves.where((m) => m.up).length;
    final down = moves.length - up;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Rail(node: SizedBox(height: 2)),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sm),
              child: Text(
                '${plural(moves.length, 'division move')} in between '
                '(↑$up ↓$down)',
                style: AppTheme.captionSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the split began, at the foot of the timeline.
class _StartRow extends StatelessWidget {
  final RankClimb climb;
  const _StartRow({required this.climb});

  @override
  Widget build(BuildContext context) {
    // The division the first move left from; the climb has moves by here.
    final d = kRankLadder[climb.moves.first.from];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            line: false,
            node: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.muted, width: 2),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Text(
              'Started the split in ${d.label} · '
              '${formatNumber(climb.startRp)} RP · '
              '${formatShortDate(climb.games.first.startTime)}',
              style: AppTheme.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// The games that caused [move]: the last ten since the move before it, the
/// one that moved the player outlined.
void showClimbGamesSheet(
  BuildContext context,
  RankClimb climb,
  RankMove move, {
  VoidCallback? onEdited,
}) {
  final games = climb.gamesBetween(move.prevGame, move.game);
  final shown = games.length > 10 ? games.sublist(games.length - 10) : games;
  final to = kRankLadder[move.to];
  final color = move.up ? AppTheme.green : AppTheme.red;
  final title = move.crossesTier
      ? (move.up ? 'Reached ${to.tier}' : 'Dropped back to ${to.tier}')
      : '${move.up ? 'Up' : 'Down'} to ${to.label}';
  // What the count runs from: the move before, by where it left the player.
  final before = climb.moves.where((m) => m.game == move.prevGame).firstOrNull;
  final since = before == null
      ? 'SINCE THE SPLIT BEGAN'
      : 'SINCE ${kRankLadder[before.to].label.toUpperCase()}';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.md,
            AppTheme.md,
            AppTheme.md,
            AppTheme.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  ClimbArrow(up: move.up, size: 28),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Game ${move.game} · ${formatShortDate(move.at)}, '
                '${formatClock(move.at)} · ${formatNumber(move.total)} RP',
                style: AppTheme.caption,
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                games.length > shown.length
                    ? 'THE LAST ${shown.length} OF ${games.length} GAMES '
                          '$since'
                    : '${plural(shown.length, 'GAME')} $since',
                style: AppTheme.cardTitle,
              ),
              const SizedBox(height: AppTheme.xs),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in shown.reversed)
                      _GameLine(
                        number: climb.games.indexOf(g) + 1,
                        game: g,
                        decisive: identical(g, move.match),
                        onTap: () async {
                          final list = shown.reversed.toList();
                          final edited = await showMatchDetailSheet(
                            sheetContext,
                            matches: list,
                            index: list.indexOf(g),
                          );
                          if (edited == null) return;
                          // The list is stale now: close it and reload.
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          onEdited?.call();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GameLine extends StatelessWidget {
  final int number;
  final RankedMatch game;
  final bool decisive;
  final VoidCallback onTap;
  const _GameLine({
    required this.number,
    required this.game,
    required this.decisive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = battleRoyaleMapAsset(game.mapKey);
    final kills = game.kills;
    final damage = game.damage;
    final end = game.endTime;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sm),
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          side: BorderSide(
            color: decisive ? AppTheme.accent : AppTheme.surface2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: asset == null
                        ? const ColoredBox(color: AppTheme.surface2)
                        : MapAssetImage(asset: asset),
                  ),
                ),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LegendIcon(legendName: game.legend, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${game.legend} · ${battleRoyaleMapName(game.mapKey)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          if (decisive)
                            const ClimbTag('THIS MOVED YOU', AppTheme.accent),
                        ],
                      ),
                      Text(
                        [
                          'Game $number',
                          '${formatShortDate(end)}, ${formatClock(end)}',
                          if (kills != null) plural(kills, 'kill'),
                          if (damage != null) '${formatNumber(damage)} dmg',
                        ].join(' · '),
                        style: AppTheme.captionSmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatSignedInt(game.rpChange),
                  style: TextStyle(
                    color: AppTheme.signColor(game.rpChange >= 0),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
