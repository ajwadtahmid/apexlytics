import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/ranked_provider.dart';
import '../../../utils/ranked/ranked_period.dart';
import '../../../utils/theme.dart';
import '../../../widgets/control_pill.dart';
import 'ranked_period_sheets.dart';

/// The small rounded label both header dropdowns share. A long [label] is cut
/// with an ellipsis rather than pushing the other dropdown off the row.
class _HeaderPill extends StatelessWidget {
  final String label;
  final bool dropdown;
  const _HeaderPill({required this.label, required this.dropdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      // The arrow icon has space of its own beside its drawn shape, so the
      // right edge takes less padding for the pill to look even.
      padding: EdgeInsets.fromLTRB(10, 6, dropdown ? 4 : 10, 6),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (dropdown) ...[
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.accent),
          ],
        ],
      ),
    );
  }
}

/// The pill is short; this gives a thumb a taller area to hit without changing
/// how it looks.
Widget _thumbSized(Widget pill) => ConstrainedBox(
  constraints: const BoxConstraints(minHeight: ControlPill.minHitHeight),
  child: Center(widthFactor: 1, heightFactor: 1, child: pill),
);

/// A pill that opens a sheet on tap, announced as a button.
Widget _pillButton({
  required Widget pill,
  required String label,
  required VoidCallback onTap,
}) => Semantics(
  button: true,
  label: label,
  excludeSemantics: true,
  onTap: onTap,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: _thumbSized(pill),
  ),
);

/// The header pill as a button, for a page that offers the same season or week
/// choice without driving the Stats page's own selection.
class RankedPeriodButton extends StatelessWidget {
  final String label;

  /// What a screen reader says, which may say more than [label] does.
  final String semanticsLabel;
  final VoidCallback onTap;
  const RankedPeriodButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _pillButton(
    pill: _HeaderPill(label: label, dropdown: true),
    label: semanticsLabel,
    onTap: onTap,
  );
}

/// "Season 31 (Split 1)" as "S31 Split 1", the short form older splits already
/// use. Any other name is returned as it is.
String shortSplitName(String name) {
  final m = RegExp(r'^Season (\d+) \(Split (\d+)\)$').firstMatch(name);
  return m == null ? name : 'S${m[1]} Split ${m[2]}';
}

/// Split selector: a compact pill that opens the list of available splits.
/// Drives [rankedPeriodProvider].
class RankedSplitDropdown extends ConsumerWidget {
  final RankedView view;
  const RankedSplitDropdown({super.key, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view.splits.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(rankedPeriodProvider.notifier);
    final selected = view.splits.firstWhere(
      (s) => s.id == view.effectiveSplitId,
      orElse: () => view.splits.first,
    );

    // The full name does not fit beside the week pill at a larger text size,
    // and the end of it is the part that tells the splits apart.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final pill = _HeaderPill(
      label: large ? shortSplitName(selected.displayName) : selected.displayName,
      dropdown: view.splits.length > 1,
    );
    if (view.splits.length <= 1) return pill;

    return _pillButton(
      pill: pill,
      label: 'Season, ${selected.displayName}',
      onTap: () =>
          showSplitSheet(context, view: view, onSelected: notifier.selectSplit),
    );
  }
}

/// Week selector, the other half of the Stats header: "Week: All", "Week: 1"
/// and so on. A week that has not started is listed but cannot be picked, and
/// says when it starts. Hidden for splits with no week metadata (the "Unknown"
/// bucket), so callers gate on `weeks`.
class RankedWeekDropdown extends ConsumerWidget {
  final RankedView view;
  const RankedWeekDropdown({super.key, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view.weeks.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(rankedPeriodProvider.notifier);
    final index = view.weekIndex;

    final pill = _HeaderPill(
      label: index < 0 ? 'Week: All' : 'Week: ${index + 1}',
      dropdown: true,
    );

    return _pillButton(
      pill: pill,
      label: index < 0 ? 'Week, all' : 'Week ${index + 1}',
      onTap: () =>
          showWeekSheet(context, view: view, onSelected: notifier.selectWeek),
    );
  }
}
