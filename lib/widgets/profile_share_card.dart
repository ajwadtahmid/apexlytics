import 'package:material_ui/material_ui.dart';

import '../constants/api_constants.dart';
import '../constants/legend_constants.dart'
    show canonicalLegendName, kCareerLegendName;
import '../constants/rank_constants.dart' show kRankLadder;
import '../constants/stat_icons.dart';
import '../models/player_stats.dart';
import '../utils/formatting/format.dart' show formatNumber, kNoReading;
import '../utils/formatting/rank_utils.dart' show rankIndex;
import '../utils/theme.dart';
import 'share_card.dart';

/// The boxes on a profile card that the player may take off. Level and
/// platform are always there.
enum ProfileCardStat {
  rank('Rank'),
  legend('Legend'),
  kills('Kills'),
  damage('Damage');

  final String label;
  const ProfileCardStat(this.label);
}

/// What goes on a profile card, as the player chose it.
class ProfileCardOptions {
  /// The boxes shown besides level and platform.
  final Set<ProfileCardStat> stats;

  /// Whether the UID is printed at the bottom left. Off unless asked for.
  final bool showUid;

  /// The legend the player picked as a favourite, or null for the one with the
  /// most kills.
  final String? favoriteLegend;

  const ProfileCardOptions({
    this.stats = const {...ProfileCardStat.values},
    this.showUid = false,
    this.favoriteLegend,
  });

  ProfileCardOptions copyWith({
    Set<ProfileCardStat>? stats,
    bool? showUid,
    String? Function()? favoriteLegend,
  }) => ProfileCardOptions(
    stats: stats ?? this.stats,
    showUid: showUid ?? this.showUid,
    favoriteLegend: favoriteLegend != null
        ? favoriteLegend()
        : this.favoriteLegend,
  );
}

/// The legend [stats] shows the most kills with, or null when none has any.
/// The career entry adds up every legend, so it is not one.
LegendStat? topLegendByKills(PlayerStats stats) {
  LegendStat? best;
  for (final l in stats.legendStats) {
    if (l.name != kCareerLegendName &&
        l.killCount > 0 &&
        (best == null || l.killCount > best.killCount)) {
      best = l;
    }
  }
  return best;
}

/// The legend the card is about under [options]: the favourite when one is
/// picked, else the one with the most kills, else the one being played.
String profileCardLegend(PlayerStats stats, ProfileCardOptions options) =>
    canonicalLegendName(
      options.favoriteLegend ??
          topLegendByKills(stats)?.name ??
          stats.currentLegend,
    );

/// The rank with its division ("Platinum II") when the RP says which, else as
/// the profile gives it.
String profileRankLabel(PlayerStats stats) {
  final division = kRankLadder[rankIndex(stats.rankScore)].label;
  return division.startsWith(stats.rank) ? division : stats.rank;
}

/// A looked-up player as a card, with what [options] asks for. No match
/// history, and the UID only when asked. The name appears only when
/// [playerName] is given.
class ProfileShareCard extends StatelessWidget {
  final PlayerStats stats;
  final String? playerName;
  final ProfileCardOptions options;
  const ProfileShareCard({
    super.key,
    required this.stats,
    this.playerName,
    this.options = const ProfileCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final legendName = profileCardLegend(stats, options);
    final picked = options.favoriteLegend != null;
    // The legend's own figures; none when it has not been played.
    final legend = stats.legendStats
        .where((l) => canonicalLegendName(l.name) == legendName)
        .firstOrNull;
    final on = options.stats;
    final tiles = [
      ShareTile(
        icon: Icons.stairs_outlined,
        label: 'Level',
        value: formatNumber(stats.level),
      ),
      ShareTile(
        icon: Icons.sports_esports_outlined,
        label: 'Platform',
        value: ApiConstants.labelFor(stats.platform),
      ),
      if (on.contains(ProfileCardStat.rank))
        ShareTile(
          icon: Icons.workspace_premium_outlined,
          label: 'Rank',
          value: profileRankLabel(stats),
          wide: true,
        ),
      if (on.contains(ProfileCardStat.legend))
        ShareTile(
          icon: Icons.person_outline,
          label: picked ? 'Favorite legend' : 'Top legend',
          value: legendName,
          wide: true,
        ),
      if (on.contains(ProfileCardStat.kills))
        ShareTile(
          icon: StatIcons.totalKills,
          label: 'Kills with $legendName',
          value: legend == null ? kNoReading : formatNumber(legend.killCount),
        ),
      if (on.contains(ProfileCardStat.damage))
        ShareTile(
          icon: StatIcons.totalDamage,
          label: 'Damage with $legendName',
          value: legend == null ? kNoReading : formatNumber(legend.damageDealt),
        ),
    ];
    final uid = stats.uid;
    return ShareCardFrame(
      // The name leads when it is shown; without it this stands in its place.
      label: playerName == null ? 'Apex profile' : '',
      name: playerName,
      // Without the legend box the portrait goes too, so the card is not
      // about a legend it does not name.
      legend: on.contains(ProfileCardStat.legend) ? legendName : null,
      footer: options.showUid && uid.isNotEmpty
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('UID: $uid', style: AppTheme.captionSmall),
            )
          : null,
      split: ShareCardSplit(title: 'Profile', stats: tiles),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Wrap(spacing: AppTheme.sm, runSpacing: AppTheme.sm, children: tiles),
        ],
      ),
    );
  }
}
