import 'package:material_ui/material_ui.dart';

import '../../constants/map_constants.dart';
import '../../utils/formatting/format.dart'
    show
        formatClock,
        formatDuration,
        formatNumber,
        formatShortDate,
        formatSignedInt,
        formatTotalOrNone;
import '../../utils/ranked/shared_matches.dart';
import '../../utils/theme.dart';
import '../../widgets/legend_icon.dart';
import '../../widgets/map_asset_image.dart';
import '../../widgets/surface_card.dart';
import 'widgets/squad_table.dart';

/// One game the saved profiles played together: the map, and each profile's
/// legend, kills, damage, RP and time in the game side by side.
class SquadGameDetailScreen extends StatelessWidget {
  final SharedMatch match;

  /// The profiles the list was showing, in its order: the first is the player
  /// on screen. A column is drawn for each one that was in this game.
  final List<String> slots;

  /// Each profile's name, by uid.
  final Map<String, String> names;

  const SquadGameDetailScreen({
    super.key,
    required this.match,
    required this.slots,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final members = [
      for (final s in slots)
        if (match.includes(s)) s,
    ];
    final games = [for (final s in members) match.games[s]!];
    final columns = [
      for (final s in members)
        SquadColumn(
          names[s] ?? '',
          AppTheme.profileColors[slots.indexOf(s) %
              AppTheme.profileColors.length],
        ),
    ];
    final others = [
      for (final u in match.uids)
        if (!slots.contains(u)) names[u] ?? '',
    ];
    final kills = games.fold<int>(0, (a, g) => a + (g.kills ?? 0));
    final damage = games.fold<int>(0, (a, g) => a + (g.damage ?? 0));
    final killsReported = games.where((g) => g.kills != null).length;
    final damageReported = games.where((g) => g.damage != null).length;
    final mapAsset = battleRoyaleMapAsset(match.mapKey);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              match.squadSize == 3 ? 'Trio game' : 'Duo game',
              style: const TextStyle(fontSize: 17),
            ),
            Text(
              '${formatShortDate(match.start)}, ${formatClock(match.start)}',
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.md),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SizedBox(
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mapAsset != null)
                      MapAssetImage(asset: mapAsset)
                    else
                      const ColoredBox(color: AppTheme.surface2),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.cardScrimTop,
                            AppTheme.cardScrimBottom,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppTheme.md,
                      right: AppTheme.md,
                      bottom: AppTheme.md,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              battleRoyaleMapName(match.mapKey),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            formatDuration(match.lengthSecs),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.md),
            SurfaceCard(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SQUAD', style: AppTheme.cardTitle),
                  const SizedBox(height: AppTheme.md),
                  SquadTable(
                    columns: columns,
                    headerExtra: (i) => Padding(
                      padding: const EdgeInsets.only(top: AppTheme.sm),
                      child: Column(
                        children: [
                          LegendIcon(legendName: games[i].legend, size: 26),
                          const SizedBox(height: 2),
                          Text(
                            games[i].legend,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    rows: [
                      SquadStatRow('Kills', [
                        for (final g in games) g.kills,
                      ], (v) => '$v'),
                      SquadStatRow('Damage', [
                        for (final g in games) g.damage,
                      ], (v) => formatNumber(v.toInt())),
                      SquadStatRow(
                        'RP',
                        [for (final g in games) g.rpChange],
                        (v) => formatSignedInt(v.toInt()),
                        signed: true,
                      ),
                      SquadStatRow('Time in game', [
                        for (final g in games) g.lengthSecs,
                      ], (v) => formatDuration(v.toInt())),
                    ],
                  ),
                  const Divider(height: AppTheme.lg, color: AppTheme.surface2),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Squad total', style: AppTheme.caption),
                      ),
                      Text(
                        '${formatTotalOrNone(kills, killsReported)} kills · '
                        '${formatTotalOrNone(damage, damageReported)} damage',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.md),
            _HowMatched(match: match, others: others),
          ],
        ),
      ),
    );
  }
}

/// How sure the match is: how far apart the profiles' times were, and whether
/// that was close enough on its own.
class _HowMatched extends StatelessWidget {
  final SharedMatch match;
  final List<String> others;
  const _HowMatched({required this.match, required this.others});

  static String _gap(int secs) =>
      secs < 60 ? '${secs}s' : '${secs ~/ 60}m ${secs % 60}s';

  @override
  Widget build(BuildContext context) {
    final close = match.isClose;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HOW IT WAS MATCHED', style: AppTheme.cardTitle),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              Icon(
                close ? Icons.verified_outlined : Icons.link,
                size: 18,
                color: close ? AppTheme.muted : AppTheme.orange,
              ),
              const SizedBox(width: AppTheme.sm),
              Text(
                close ? 'Close match' : 'Looser match',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Starts ${_gap(match.startSpreadSecs)} apart, ends '
            '${_gap(match.endSpreadSecs)} apart. '
            '${close ? 'Close enough to count on its own.' : 'Counted because the games before and after also line up.'}',
            style: AppTheme.captionLarge,
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sm),
            Text(
              'Also in this game: ${others.join(', ')}',
              style: AppTheme.captionLarge,
            ),
          ],
        ],
      ),
    );
  }
}
