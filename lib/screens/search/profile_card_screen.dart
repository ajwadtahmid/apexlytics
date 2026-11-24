import 'package:material_ui/material_ui.dart';

import '../../constants/legend_constants.dart' show kLegends;
import '../../models/player_stats.dart';
import '../../utils/theme.dart';
import '../../widgets/legend_icon.dart';
import '../../widgets/pill_segments.dart';
import '../../widgets/profile_share_card.dart';
import '../../widgets/share_card.dart';

/// A player's profile as a card to share, with the choice of what goes on it.
/// The choices are asked afresh each visit, so a UID is never on a card by
/// habit. [mine] is whether the profile is the user's own, which only changes
/// the wording.
class ProfileCardScreen extends StatefulWidget {
  final PlayerStats stats;
  final bool mine;
  const ProfileCardScreen({super.key, required this.stats, this.mine = false});

  @override
  State<ProfileCardScreen> createState() => _ProfileCardScreenState();
}

class _ProfileCardScreenState extends State<ProfileCardScreen> {
  var _options = const ProfileCardOptions();

  void _toggle(ProfileCardStat stat) {
    final next = {..._options.stats};
    next.contains(stat) ? next.remove(stat) : next.add(stat);
    setState(() => _options = _options.copyWith(stats: next));
  }

  Future<void> _pickLegend() async {
    final current = profileCardLegend(widget.stats, _options);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final l in kLegends)
                ListTile(
                  leading: LegendIcon(legendName: l.name, size: 28),
                  title: Text(l.name),
                  selected: l.name == current,
                  selectedColor: AppTheme.accent,
                  trailing: l.name == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheet, l.name),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _options = _options.copyWith(favoriteLegend: () => picked),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final favorite = _options.favoriteLegend != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile card')),
      body: SafeArea(
        child: ShareCardPanel(
          pinShare: true,
          nameToggleTitle: widget.mine ? 'Show my name' : 'Show their name',
          nameToggleSubtitle: 'At the top of the card.',
          cardBuilder: (showName) => ProfileShareCard(
            stats: stats,
            playerName: showName ? stats.name : null,
            options: _options,
          ),
          belowName: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show UID'),
            subtitle: const Text(
              'Anyone with the card can look the player up by it.',
              style: AppTheme.caption,
            ),
            value: _options.showUid,
            onChanged: stats.uid.isEmpty
                ? null
                : (v) =>
                      setState(() => _options = _options.copyWith(showUid: v)),
          ),
          controls: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Show on the card',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Level and platform always show.',
                style: AppTheme.caption,
              ),
              const SizedBox(height: AppTheme.sm),
              Wrap(
                spacing: AppTheme.sm,
                runSpacing: AppTheme.xs,
                children: [
                  for (final stat in ProfileCardStat.values)
                    _StatChip(
                      label: stat.label,
                      on: _options.stats.contains(stat),
                      onTap: () => _toggle(stat),
                    ),
                ],
              ),
              if (_options.stats.contains(ProfileCardStat.legend) ||
                  _options.stats.contains(ProfileCardStat.kills) ||
                  _options.stats.contains(ProfileCardStat.damage)) ...[
                const SizedBox(height: AppTheme.md),
                const Text(
                  'Legend',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.sm),
                PillSegments(
                  selected: favorite ? 1 : 0,
                  onChanged: (i) {
                    if (i == 0) {
                      setState(
                        () => _options = _options.copyWith(
                          favoriteLegend: () => null,
                        ),
                      );
                    } else {
                      _pickLegend();
                    }
                  },
                  options: [
                    PillOption(
                      label: 'Top legend',
                      semanticLabel: 'The legend with the most kills',
                      icon: (c) =>
                          Icon(Icons.emoji_events_outlined, size: 16, color: c),
                    ),
                    PillOption(
                      label: 'Favorite',
                      semanticLabel: 'A legend you pick',
                      icon: (c) =>
                          Icon(Icons.favorite_border, size: 16, color: c),
                    ),
                  ],
                ),
                if (favorite)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: LegendIcon(
                      legendName: profileCardLegend(stats, _options),
                      size: 28,
                    ),
                    title: Text(profileCardLegend(stats, _options)),
                    subtitle: const Text(
                      'Tap to pick another',
                      style: AppTheme.caption,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickLegend,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip for a box the card can show: lit when it is on the card, a quiet
/// outline when off.
class _StatChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _StatChip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: on,
      showCheckmark: true,
      checkmarkColor: AppTheme.onAccent,
      selectedColor: AppTheme.accent,
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: on ? AppTheme.accent : AppTheme.muted.withAlpha(120),
      ),
      labelStyle: TextStyle(
        color: on ? AppTheme.onAccent : AppTheme.muted,
        fontWeight: on ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
