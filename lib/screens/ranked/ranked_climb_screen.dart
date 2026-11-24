import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../constants/rank_constants.dart';
import '../../providers/rank_climb_provider.dart';
import '../../providers/ranked_provider.dart' show rankedSplitMatchesProvider;
import '../../utils/error_messages.dart';
import '../../utils/formatting/format.dart'
    show formatDuration, formatNumber, formatShortDate, formatSignedInt, plural;
import '../../utils/ranked/rank_climb.dart';
import '../../utils/ranked/ranked_period.dart';
import '../../utils/theme.dart';
import '../../widgets/error_card.dart';
import '../../widgets/nav_entry_card.dart';
import '../../widgets/segmented_capsule.dart';
import '../../widgets/surface_card.dart';
import 'widgets/climb_chart.dart';
import 'widgets/climb_moves.dart';
import 'widgets/climb_parts.dart';
import 'widgets/ranked_period_selector.dart';
import 'widgets/ranked_period_sheets.dart';

/// A tappable tile that opens the climb page.
class RankedClimbEntry extends StatelessWidget {
  /// The player on screen.
  final String uid;

  /// The period the Stats page is showing, which the page starts on.
  final RankedView view;
  const RankedClimbEntry({super.key, required this.uid, required this.view});

  @override
  Widget build(BuildContext context) {
    return NavEntryCard(
      icon: Icons.route_outlined,
      title: 'The Journey',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RankedClimbScreen(uid: uid, view: view),
        ),
      ),
    );
  }
}

/// A split's journey up and down the ladder: where you stand, the RP through
/// the split with every promotion and demotion marked, and then either how long
/// you spent in each division or each move as it happened.
///
/// It starts on the season the Stats page shows; changing it here leaves Stats
/// as it was. A split resets the ladder, so there is no lifetime climb.
class RankedClimbScreen extends ConsumerStatefulWidget {
  final String uid;
  final RankedView view;
  const RankedClimbScreen({super.key, required this.uid, required this.view});

  @override
  ConsumerState<RankedClimbScreen> createState() => _RankedClimbScreenState();
}

class _RankedClimbScreenState extends ConsumerState<RankedClimbScreen> {
  late final List<RankedSplitBucket> _splits = [
    for (final b in widget.view.splits)
      if (b.id != kLifetimeSplitId && b.id != kUnknownSplitId) b,
  ];
  late String _splitId = _startSplit();
  // Moves first: the page is about the ups and downs.
  int _tab = 0;

  /// The split on the Stats page, or the newest real one when that is the
  /// Lifetime scope or the games with no season.
  String _startSplit() {
    final shown = widget.view.effectiveSplitId;
    return _splits.any((b) => b.id == shown)
        ? shown
        : effectiveSplitId(_splits, null);
  }

  RankedView get _periodView => RankedView(
    splits: _splits,
    effectiveSplitId: _splitId,
    weeks: const [],
    weekIndex: -1,
    filtered: const [],
    gamesInPeriod: const [],
  );

  /// Whether the shown split is over: a newer one exists, so there is nothing
  /// left to climb in this one. It does not depend on the phone's clock.
  bool get _ended => _splitId != effectiveSplitId(_splits, null);

  String get _splitLabel {
    for (final b in _splits) {
      if (b.id == _splitId) return b.displayName;
    }
    return 'Season';
  }

  @override
  Widget build(BuildContext context) {
    final arg = (uid: widget.uid, splitId: _splitId);
    final result = ref.watch(rankClimbProvider(arg));
    return Scaffold(
      appBar: AppBar(title: const Text('The Journey')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.md),
          children: [
            Row(
              children: [
                RankedPeriodButton(
                  label: _splitLabel,
                  semanticsLabel: 'Season, $_splitLabel',
                  onTap: () => showSplitSheet(
                    context,
                    view: _periodView,
                    onSelected: (id) => setState(() => _splitId = id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sm),
            ..._body(result, arg),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    AsyncValue<RankClimb> result,
    ({String uid, String splitId}) arg,
  ) {
    if (result.hasError && !result.hasValue) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
          child: ErrorCard(
            message: friendlyError(result.error!),
            onRetry: () => ref.invalidate(rankClimbProvider(arg)),
          ),
        ),
      ];
    }
    final climb = result.value;
    if (climb == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.xl),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
      ];
    }
    if (climb.isEmpty) return const [_Empty()];
    return [
      _Header(climb: climb, ended: _ended),
      const SizedBox(height: AppTheme.md),
      if (climb.games.length > 1) ...[
        ClimbChart(climb: climb),
        const SizedBox(height: AppTheme.md),
      ],
      Center(
        child: SegmentedCapsule(
          options: const ['Timeline', 'Divisions'],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
      const SizedBox(height: AppTheme.md),
      if (_tab == 0)
        ClimbMoves(
          climb: climb,
          onEdited: () {
            ref.invalidate(rankedSplitMatchesProvider(arg));
            ref.invalidate(rankClimbProvider(arg));
          },
        )
      else
        _Divisions(climb: climb, ended: _ended),
      const SizedBox(height: AppTheme.md),
      Text(
        'Built from the games recorded on this device. A split resets the '
        'ladder, so each season is its own journey. Games you excluded from the '
        'stats still count here, as they still moved your RP.'
        '${_gapNote(climb)}',
        style: AppTheme.captionSmall,
      ),
    ];
  }
}

/// A short extra line when the games' own RP adds up to a different figure
/// than the ladder moved, which it can when a game moved RP without being
/// counted as ranked.
String _gapNote(RankClimb climb) {
  final games = climb.games.fold(0, (a, g) => a + g.rpChange);
  if (games == climb.net) return '';
  return ' The games counted add up to ${formatSignedInt(games)} RP.';
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.xl),
      child: Column(
        children: [
          Icon(Icons.route_outlined, size: 40, color: AppTheme.muted),
          SizedBox(height: AppTheme.md),
          Text(
            'No journey to show yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: AppTheme.xs),
          Text(
            'Finish a ranked game this split and your journey starts here.',
            textAlign: TextAlign.center,
            style: AppTheme.captionLarge,
          ),
        ],
      ),
    );
  }
}

/// Where you stand: the division, the RP, the way to the next one, and the
/// split in a few figures.
class _Header extends StatelessWidget {
  final RankClimb climb;
  final bool ended;
  const _Header({required this.climb, required this.ended});

  @override
  Widget build(BuildContext context) {
    final rung = climb.currentRung;
    final d = kRankLadder[rung];
    final next = rung + 1 < kRankLadder.length ? kRankLadder[rung + 1] : null;
    final span = next == null ? 1 : next.rp - d.rp;
    final progress = ((climb.currentRp - d.rp) / span).clamp(0.0, 1.0);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClimbBadge(rung, 64),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: TextStyle(
                        color: rankDisplayColor(d),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${formatNumber(climb.currentRp)} RP',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSignedInt(climb.net),
                    style: TextStyle(
                      color: AppTheme.signColor(climb.net >= 0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('this split', style: AppTheme.captionSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (ended)
            Text('Finished the split in ${d.label}', style: AppTheme.caption)
          else if (next != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.surface2,
                color: rankDisplayColor(d),
                semanticsLabel: 'Progress to ${next.label}',
                semanticsValue: '${(progress * 100).round()}%',
              ),
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              '${formatNumber(next.rp - climb.currentRp)} RP to ${next.label}',
              style: AppTheme.caption,
            ),
          ] else
            const Text('Top of the ladder', style: AppTheme.caption),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              ClimbFigure('${climb.games.length}', 'games'),
              ClimbFigure(formatDuration(climb.playSecs), 'played'),
              ClimbFigure(
                kRankLadder[climb.peakRung].label,
                'peak',
                color: rankDisplayColor(kRankLadder[climb.peakRung]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row for each division reached, the highest first.
class _Divisions extends StatelessWidget {
  final RankClimb climb;
  final bool ended;
  const _Divisions({required this.climb, required this.ended});

  @override
  Widget build(BuildContext context) {
    final rungs = climb.divisions.keys.toList()..sort((a, b) => b.compareTo(a));
    final most = climb.divisions.values.map((d) => d.games).reduce(math.max);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('TIME IN EACH DIVISION', style: AppTheme.cardTitle),
              ),
              Text(
                plural(rungs.length, 'division'),
                style: AppTheme.captionSmall,
              ),
            ],
          ),
          for (final rung in rungs)
            _DivisionRow(
              rung: rung,
              stay: climb.divisions[rung]!,
              share: most == 0 ? 0 : climb.divisions[rung]!.games / most,
              isNow: rung == climb.currentRung,
              ended: ended,
              isPeak: rung == climb.peakRung,
            ),
        ],
      ),
    );
  }
}

class _DivisionRow extends StatelessWidget {
  final int rung;
  final DivisionStay stay;
  final double share;
  final bool isNow;
  final bool isPeak;
  final bool ended;
  const _DivisionRow({
    required this.rung,
    required this.stay,
    required this.share,
    required this.isNow,
    required this.isPeak,
    required this.ended,
  });

  @override
  Widget build(BuildContext context) {
    final d = kRankLadder[rung];
    final color = rankDisplayColor(d);
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClimbBadge(rung, 30),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          d.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isNow)
                          ClimbTag(ended ? 'FINAL' : 'NOW', AppTheme.accent),
                        if (isPeak && !isNow)
                          const ClimbTag('PEAK', AppTheme.muted),
                      ],
                    ),
                    Text(
                      'First reached ${formatShortDate(stay.firstEntered!)}'
                      '${stay.visits > 1 ? ' · ${stay.visits} visits' : ''}',
                      style: AppTheme.captionSmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plural(stay.games, 'game'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'over ${formatDuration(stay.secs)}',
                    style: AppTheme.captionSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 5,
              backgroundColor: AppTheme.surface2,
              color: color,
              semanticsLabel: '${d.label}: ${plural(stay.games, 'game')}',
            ),
          ),
        ],
      ),
    );
  }
}
