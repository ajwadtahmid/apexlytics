import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/api_constants.dart';
import '../constants/ui_constants.dart';
import '../models/player_stats.dart';
import '../utils/formatting/format.dart';
import '../utils/formatting/platform_utils.dart';
import '../utils/formatting/rank_utils.dart' show rankAssetPath;
import '../utils/notifications.dart';
import '../utils/theme.dart';
import 'legend_icon.dart';
import 'presence_dot.dart';
import 'surface_card.dart';
import 'rank_badge.dart';

class PlayerInfoCard extends StatelessWidget {
  final PlayerStats stats;
  const PlayerInfoCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // At a larger text size the level, rank and score line and the UID and
    // platform line no longer fit side by side, so they wrap onto a second line.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final copyUid = Semantics(
      button: true,
      child: Tooltip(
        message: 'Copy UID',
        child: GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: stats.uid));
            if (context.mounted) {
              context.showMessage('UID copied', duration: AppTheme.toastShort);
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(AppTheme.xs),
            child: Icon(Icons.copy, size: 12, color: AppTheme.muted),
          ),
        ),
      ),
    );
    final rankLine = <Widget>[
      Text.rich(
        TextSpan(
          style: AppTheme.captionLarge,
          children: [
            TextSpan(text: 'Level ${stats.level}'),
            separatorDot,
          ],
        ),
      ),
      RankBadge(assetPath: rankAssetPath(stats), size: 14),
      const SizedBox(width: AppTheme.xs),
      Text.rich(
        TextSpan(
          style: AppTheme.captionLarge,
          children: [
            TextSpan(text: stats.rank),
            separatorDot,
            TextSpan(text: '${formatNumber(stats.rankScore)} RP'),
          ],
        ),
      ),
    ];
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      radius: AppTheme.radiusLg,
      border: Border.all(color: AppTheme.accent.withAlpha(50)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PresenceDot(presence: presenceOf(stats), decorative: true),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  stats.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Text(stats.presence, style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 6),
          if (large)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                rankLine.first,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: rankLine.sublist(1),
                ),
              ],
            )
          else
            Row(children: rankLine),
          const SizedBox(height: 2),
          if (stats.uid.isNotEmpty) ...[
            if (large)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppTheme.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('UID: ${stats.uid}', style: AppTheme.caption),
                      const SizedBox(width: 2),
                      copyUid,
                    ],
                  ),
                  _PlatformBadge(platform: stats.platform),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('UID: ${stats.uid}', style: AppTheme.caption),
                        const SizedBox(width: 2),
                        copyUid,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  _PlatformBadge(platform: stats.platform),
                ],
              ),
            const SizedBox(height: 2),
          ],
          Row(
            children: [
              LegendIcon(legendName: stats.currentLegend, size: 14),
              const SizedBox(width: AppTheme.xs),
              Expanded(
                child: Text(
                  'Currently Tracking: ${stats.currentLegend}',
                  style: const TextStyle(color: AppTheme.accent2, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (stats.trackers.isNotEmpty)
            ...stats.trackers
                .take(3)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: AppTheme.captionLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppTheme.sm),
                        Text(
                          formatNumber(t.value),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
          else
            const Text('No trackers equipped', style: AppTheme.captionLarge),
        ],
      ),
    );
  }
}

/// Small pill showing which platform [platform] (an `ApiConstants.platforms`
/// code) the player is on. PC can't be split into Steam/Origin — the API
/// this app reads from doesn't report a storefront, only the console/PC
/// code itself.
class _PlatformBadge extends StatelessWidget {
  final String platform;
  const _PlatformBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final p = platformIconFor(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.tint(p.color),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(p.icon, color: p.color, size: 11),
          const SizedBox(width: AppTheme.xs),
          Text(
            ApiConstants.labelFor(platform),
            style: TextStyle(
              color: p.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
