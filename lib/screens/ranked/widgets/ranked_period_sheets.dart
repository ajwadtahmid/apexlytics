import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../utils/ranked/ranked_period.dart';
import '../../../utils/ranked/split_groups.dart';
import '../../../utils/theme.dart';
import '../../../widgets/sheet_handle.dart';

/// The sheet that picks a season and split: Lifetime on top, then one row per
/// season, newest first, with its splits as chips. It opens scrolled to the
/// split in use.
Future<void> showSplitSheet(
  BuildContext context, {
  required RankedView view,
  required ValueChanged<String> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _SheetFrame(
      title: 'Season',
      child: _SplitList(
        groups: groupSplits(view.splits),
        selectedId: view.effectiveSplitId,
        onSelected: (id) {
          onSelected(id);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );
}

/// The sheet that picks a week: All weeks, then each week with its dates. A
/// week that has not started is listed but cannot be picked.
Future<void> showWeekSheet(
  BuildContext context, {
  required RankedView view,
  required ValueChanged<int> onSelected,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final day = DateFormat('MMM d');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      void choose(int i) {
        onSelected(i);
        Navigator.of(sheetContext).pop();
      }

      return _SheetFrame(
        title: 'Week',
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppTheme.sm),
          children: [
            _Row(
              title: 'All weeks',
              selected: view.weekIndex < 0,
              onTap: () => choose(-1),
            ),
            for (var i = 0; i < view.weeks.length; i++)
              _Row(
                title: 'Week ${i + 1}',
                subtitle: view.weeks[i].start.isAfter(t)
                    ? 'starts ${day.format(view.weeks[i].start)}'
                    : '${day.format(view.weeks[i].start)} – '
                          '${day.format(view.weeks[i].end.subtract(const Duration(days: 1)))}',
                selected: view.weekIndex == i,
                enabled: !view.weeks[i].start.isAfter(t),
                onTap: () => choose(i),
              ),
          ],
        ),
      );
    },
  );
}

/// A handle, a title and a list that scrolls, no taller than most of the
/// screen.
class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.sm),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// One full-width choice: a title, an optional line under it, and a tick when
/// it is the one in use.
class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _Row({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppTheme.muted.withValues(alpha: 0.5)
        : selected
        ? AppTheme.accent
        : AppTheme.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sm,
              vertical: AppTheme.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: AppTheme.caption),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, size: 20, color: AppTheme.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitList extends StatefulWidget {
  final SplitGroups groups;
  final String selectedId;
  final ValueChanged<String> onSelected;
  const _SplitList({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_SplitList> createState() => _SplitListState();
}

class _SplitListState extends State<_SplitList> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Open on the season in use, however far down it is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _selectedKey.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.groups;
    final now = DateTime.now();
    // Splits sit in fixed columns (Split 1, Split 2), so a season that only has
    // the second one still lines up under the others.
    final columns = g.seasons
        .expand((s) => s.splits)
        .map(splitNumberOf)
        .fold<int>(2, (a, b) => a > b ? a : b);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      children: [
        if (g.lifetime != null) ...[
          _LifetimeTile(
            selected: widget.selectedId == g.lifetime!.id,
            onTap: () => widget.onSelected(g.lifetime!.id),
          ),
          const SizedBox(height: AppTheme.md),
        ],
        if (g.seasons.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.sm,
              0,
              AppTheme.sm,
              AppTheme.xs,
            ),
            child: Text('BY SEASON', style: AppTheme.cardTitle),
          ),
        for (final season in g.seasons)
          _SeasonRow(
            columns: columns,
            key: season.splits.any((s) => s.id == widget.selectedId)
                ? _selectedKey
                : null,
            season: season,
            selectedId: widget.selectedId,
            now: now,
            onSelected: widget.onSelected,
          ),
        for (final other in g.others)
          _Row(
            title: other.displayName,
            selected: widget.selectedId == other.id,
            onTap: () => widget.onSelected(other.id),
          ),
      ],
    );
  }
}

/// "Season 31" with a chip for each of its splits, in a column of its number.
class _SeasonRow extends StatelessWidget {
  final int columns;
  final SeasonGroup season;
  final String selectedId;
  final DateTime now;
  final ValueChanged<String> onSelected;
  const _SeasonRow({
    super.key,
    required this.columns,
    required this.season,
    required this.selectedId,
    required this.now,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final byNumber = {for (final s in season.splits) splitNumberOf(s): s};
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sm,
        vertical: AppTheme.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              'Season ${season.number}',
              style: const TextStyle(fontSize: 15),
            ),
          ),
          for (var n = 1; n <= columns; n++) ...[
            if (n > 1) const SizedBox(width: AppTheme.sm),
            Expanded(
              child: byNumber[n] == null
                  ? const SizedBox()
                  : _SplitChip(
                      label: 'Split $n',
                      live: _isLive(byNumber[n]!),
                      selected: byNumber[n]!.id == selectedId,
                      onTap: () => onSelected(byNumber[n]!.id),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isLive(RankedSplitBucket split) {
    final s = split.season;
    return s != null && !now.isBefore(s.start) && now.isBefore(s.end);
  }
}

class _SplitChip extends StatelessWidget {
  final String label;
  final bool live;
  final bool selected;
  final VoidCallback onTap;
  const _SplitChip({
    required this.label,
    required this.live,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: live ? '$label, in progress' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            heightFactor: 1,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sm,
                vertical: AppTheme.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : AppTheme.surface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                live ? '$label · now' : label,
                style: TextStyle(
                  color: selected ? AppTheme.onAccent : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Lifetime" as a button of its own, set apart from the seasons below it.
class _LifetimeTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _LifetimeTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Lifetime, every split together',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppTheme.accent.withAlpha(25) : AppTheme.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: selected
              ? const BorderSide(color: AppTheme.accent, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md,
              vertical: AppTheme.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.all_inclusive,
                  size: 22,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lifetime',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Every split together',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check : Icons.chevron_right,
                  size: 20,
                  color: selected ? AppTheme.accent : AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
