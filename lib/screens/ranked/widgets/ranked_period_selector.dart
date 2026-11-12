import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/ranked_provider.dart';
import '../../../utils/ranked/ranked_period.dart';
import '../../../utils/theme.dart';
import '../../../widgets/control_pill.dart';

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

    final pill = _HeaderPill(
      label: selected.displayName,
      dropdown: view.splits.length > 1,
    );
    if (view.splits.length <= 1) return pill;

    return PopupMenuButton<String>(
      initialValue: selected.id,
      onSelected: notifier.selectSplit,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      itemBuilder: (_) => view.splits
          .map(
            (s) => PopupMenuItem<String>(
              value: s.id,
              child: Text(
                s.displayName,
                style: TextStyle(
                  fontSize: 13,
                  color: s.id == view.effectiveSplitId
                      ? AppTheme.accent
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      child: _thumbSized(pill),
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
    final now = DateTime.now();
    final index = view.weekIndex;

    final pill = _HeaderPill(
      label: index < 0 ? 'Week: All' : 'Week: ${index + 1}',
      dropdown: true,
    );

    return PopupMenuButton<int>(
      tooltip: 'Choose week',
      initialValue: index,
      onSelected: notifier.selectWeek,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          value: -1,
          child: _item('All weeks', selected: index < 0),
        ),
        for (var i = 0; i < view.weeks.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: !view.weeks[i].start.isAfter(now),
            child: _item(
              view.weeks[i].start.isAfter(now)
                  ? 'Week ${i + 1}, starts '
                        '${DateFormat('MMM d').format(view.weeks[i].start)}'
                  : 'Week ${i + 1}',
              selected: index == i,
            ),
          ),
      ],
      child: _thumbSized(pill),
    );
  }

  static Widget _item(String text, {required bool selected}) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: selected ? AppTheme.accent : AppTheme.textPrimary,
    ),
  );
}
