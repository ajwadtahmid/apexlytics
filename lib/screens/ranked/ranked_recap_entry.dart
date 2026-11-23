import 'package:material_ui/material_ui.dart';
import '../../models/ranked_match.dart';
import '../../utils/notifications.dart';
import '../../utils/ranked/ranked_aggregates.dart' show rankedOnly;
import '../../utils/ranked/ranked_period.dart';
import '../../widgets/nav_entry_card.dart';
import 'ranked_recap_screen.dart';

/// The split (and week, when one is picked and [week] is true) on screen, for a
/// card's title.
String recapScopeLabel(RankedView view, {bool week = true}) {
  final split = view.splits
      .where((s) => s.id == view.effectiveSplitId)
      .map((s) => s.displayName)
      .firstOrNull;
  final base = split ?? 'Ranked';
  return week && view.weekIndex >= 0
      ? '$base Week ${view.weekIndex + 1}'
      : base;
}

/// Where the RP netted was made: "in Week 3" when a week is picked, otherwise
/// "this split" for the split going on now, and the split's own name for one
/// that is over ("in S30 Split 2"), or "over all seasons" for the lifetime view.
String recapPeriodPhrase(RankedView view, {bool currentSplit = true}) {
  if (view.weekIndex >= 0) return 'in Week ${view.weekIndex + 1}';
  if (isLifetimeSplit(view.effectiveSplitId)) return 'over all seasons';
  if (currentSplit) return 'this split';
  final name = recapScopeLabel(view, week: false);
  return name == 'Ranked' ? 'this split' : 'in $name';
}

/// The title over the Stats figures: "This week" or "This split" only for the
/// period going on now. A past week reads "Week 3", and a split that is over
/// (or all seasons) is named, the way the pickers above it name it.
String periodSectionLabel(
  RankedView view, {
  required bool currentSplit,
  DateTime? now,
}) {
  final named = view.periodLabel.isEmpty ? 'This split' : view.periodLabel;
  if (isLifetimeSplit(view.effectiveSplitId) || !currentSplit) return named;
  final i = view.weekIndex;
  if (i < 0 || i >= view.weeks.length) return 'This split';
  final t = now ?? DateTime.now();
  final w = view.weeks[i];
  return !t.isBefore(w.start) && t.isBefore(w.end)
      ? 'This week'
      : 'Week ${i + 1}';
}

/// What a record on the Personal Records page is the best of: "this split"
/// with all weeks, "this week" for the week going on now, otherwise "Week 3".
String recordPeriodLabel(RankedView view, {DateTime? now}) {
  final i = view.weekIndex;
  if (i < 0 || i >= view.weeks.length) return 'this split';
  final t = now ?? DateTime.now();
  final w = view.weeks[i];
  return !t.isBefore(w.start) && t.isBefore(w.end)
      ? 'this week'
      : 'Week ${i + 1}';
}

/// A tappable row that opens the recap of the period on screen as a shareable
/// card. Hidden when there are no games to recap.
class RankedRecapEntry extends StatelessWidget {
  final List<RankedMatch> matches;
  final String scope;
  final String playerName;

  /// Whether the player is Apex Predator at the end of this period. Only known
  /// for the live period; a past one can't be told from today's cutoff.
  final bool isPredator;

  /// See [recapPeriodPhrase].
  final String periodPhrase;

  const RankedRecapEntry({
    super.key,
    required this.matches,
    required this.scope,
    required this.playerName,
    this.isPredator = false,
    this.periodPhrase = 'this split',
  });

  @override
  Widget build(BuildContext context) {
    return NavEntryCard(
      icon: Icons.auto_awesome_outlined,
      title: 'Recap',
      onTap: rankedOnly(matches).isEmpty
          ? () => context.showMessage('No ranked games to recap yet.')
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RankedRecapScreen(
                  matches: matches,
                  scope: scope,
                  playerName: playerName,
                  isPredator: isPredator,
                  periodPhrase: periodPhrase,
                ),
              ),
            ),
    );
  }
}
