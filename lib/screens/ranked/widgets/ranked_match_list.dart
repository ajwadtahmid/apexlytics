import 'package:material_ui/material_ui.dart';
import '../../../models/ranked_match.dart';
import '../../../utils/theme.dart';
import 'games_filter.dart';
import 'match_history_items.dart';
import 'match_history_list.dart';
import '../../../widgets/control_pill.dart';

/// Games tab: every match in the selected period (ranked + casual), grouped by
/// play session with day dividers. A mode filter scopes the list; tap a row for the
/// full match detail.
class RankedMatchList extends StatefulWidget {
  final List<RankedMatch> matches; // all-in-period, newest first
  final Future<void> Function() onRefresh;

  const RankedMatchList({
    super.key,
    required this.matches,
    required this.onRefresh,
  });

  @override
  State<RankedMatchList> createState() => _RankedMatchListState();
}

class _RankedMatchListState extends State<RankedMatchList> {
  // Defaults to Ranked — it's the headline view; the rest is in the sheet.
  GamesFilter _filter = const GamesFilter();
  _GamesSort _sort = _GamesSort.date;

  List<RankedMatch> get _visible => _filter.apply(widget.matches);

  MatchGrouping? get _grouping => switch (_sort) {
    _GamesSort.date => null,
    _GamesSort.legend => MatchGrouping.byLegend,
    _GamesSort.map => MatchGrouping.byMap,
  };

  @override
  Widget build(BuildContext context) {
    return MatchHistoryList(
      matches: _visible,
      onRefresh: widget.onRefresh,
      emptyLabel: 'No games in this filter',
      selectable: true,
      grouping: _grouping,
      // The whole period, not the filtered view: a legend's average shouldn't
      // shrink because the list is filtered to one map.
      averagePool: widget.matches,
      // Sessions come from every game played, so the filter hides games
      // without reshaping them.
      sessionPool: widget.matches,
      header: _GamesControls(
        filter: _filter,
        sort: _sort,
        onFilterTap: () => showGamesFilterSheet(
          context,
          filter: _filter,
          pool: widget.matches,
          onChanged: (f) => setState(() => _filter = f),
        ),
        onSortTap: () => setState(() => _sort = _nextSort(_sort)),
      ),
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────────────────

enum _GamesSort { date, legend, map }

const _sortLabels = {
  _GamesSort.date: 'Date',
  _GamesSort.legend: 'Legend',
  _GamesSort.map: 'Map',
};

const _sortIcons = {
  _GamesSort.date: Icons.calendar_today,
  _GamesSort.legend: Icons.person_outline,
  _GamesSort.map: Icons.map_outlined,
};

_GamesSort _nextSort(_GamesSort s) => switch (s) {
  _GamesSort.date => _GamesSort.legend,
  _GamesSort.legend => _GamesSort.map,
  _GamesSort.map => _GamesSort.date,
};

/// Games control strip: filter pill pinned left, sort pill pinned right.
/// Both cycle on tap, mirroring the Legends/Maps sort control's pill styling.
class _GamesControls extends StatelessWidget {
  final GamesFilter filter;
  final _GamesSort sort;
  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;

  const _GamesControls({
    required this.filter,
    required this.sort,
    required this.onFilterTap,
    required this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.md,
        AppTheme.sm,
        AppTheme.md,
        AppTheme.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surface2)),
      ),
      child: Row(
        children: [
          ControlPill(
            icon: Icons.tune,
            label: filter.activeCount == 0
                ? 'Filter'
                : 'Filter · ${filter.activeCount}',
            onTap: onFilterTap,
          ),
          const Spacer(),
          ControlPill(
            prefix: 'Sort:',
            icon: _sortIcons[sort]!,
            label: _sortLabels[sort]!,
            onTap: onSortTap,
          ),
        ],
      ),
    );
  }
}
