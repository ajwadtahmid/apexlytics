import 'package:material_ui/material_ui.dart';

import '../../../utils/formatting/format.dart' show plural;
import '../../../utils/theme.dart';

/// A line at the top of Overview when the season in use is the one for games
/// the app could not place in a season: what that means and what still holds.
/// The games are all on the Games tab.
class UnknownSeasonNote extends StatelessWidget {
  /// How many ranked games are in this group, as the season sheet counts them.
  final int games;
  const UnknownSeasonNote({super.key, required this.games});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline, size: 18, color: AppTheme.muted),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Text(
              '${plural(games, 'ranked game')} could not be matched to a season, '
              'usually because the date falls outside the seasons the app '
              'knows. They still count in Lifetime. The Games tab lists them.',
              style: AppTheme.captionLarge,
            ),
          ),
        ],
      ),
    );
  }
}
