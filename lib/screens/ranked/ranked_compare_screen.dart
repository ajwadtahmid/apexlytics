import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ranked_match.dart';
import '../../models/season_meta.dart';
import '../../providers/ranked_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/formatting/format.dart'
    show
        formatAvgDamage,
        formatAvgKills,
        formatPercent,
        formatSigned,
        formatSignedInt,
        kNoReading;
import '../../utils/error_messages.dart';
import '../../utils/ranked/ranked_period.dart';
import '../../utils/ranked/slots.dart';
import '../../utils/theme.dart';
import '../../widgets/error_card.dart';
import '../../widgets/nav_entry_card.dart';
import '../../widgets/segmented_capsule.dart';
import '../../widgets/surface_card.dart';
import 'widgets/compare_row.dart';
import 'widgets/ranked_entity_compare.dart';
import 'widgets/ranked_slot_chart.dart';
import 'widgets/split_changes_card.dart';

/// A tappable row that opens the comparison page.
class RankedCompareEntry extends StatelessWidget {
  final String uid;
  final List<RankedSplitBucket> splits;
  final List<RankedMatch> matches;
  const RankedCompareEntry({
    super.key,
    required this.uid,
    required this.splits,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return NavEntryCard(
      icon: Icons.compare_arrows,
      title: 'Compare',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              RankedCompareScreen(uid: uid, splits: splits, matches: matches),
        ),
      ),
    );
  }
}

/// The comparison page: splits, legends or maps side by side.
class RankedCompareScreen extends StatelessWidget {
  final String uid;
  final List<RankedSplitBucket> splits;
  final List<RankedMatch> matches;
  const RankedCompareScreen({
    super.key,
    required this.uid,
    required this.splits,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.md),
          children: [
            RankedCompareBody(uid: uid, splits: splits, matches: matches),
          ],
        ),
      ),
    );
  }
}

/// The body of the Compare page: split-vs-split, legend-vs-legend and
/// map-vs-map comparison. Embedded inline (not in its own scrollable); the
/// caller supplies the surrounding `ListView`.
///
/// Only real, named splits are selectable — not Lifetime (comparing "every
/// split combined" against one split isn't a split-vs-split comparison) and
/// not Unknown (a grab-bag of unclassified matches spanning an arbitrary
/// timeframe, not a coherent period).
///
/// Net RP is the only cross-split RP figure ever shown. A split's *current*
/// RP is never compared against another split's, because the ladder resets
/// between splits, so a diff of two absolute RP values across that boundary
/// means nothing.
///
/// A selector at the top switches between comparing two splits (the default),
/// and two legends or two maps within [matches], the screen's own period.
///
/// The profile on screen is always the left side, in orange, and only its split
/// can change. The right side, in blue, is the one to change: another split, or
/// another profile. The change shown is the left minus the right, green where
/// the left leads, as on the player comparison.
class RankedCompareBody extends ConsumerStatefulWidget {
  final String uid;
  final List<RankedSplitBucket> splits;

  /// The ranked games of the period the screen is showing, for the legend and
  /// map comparisons.
  final List<RankedMatch> matches;

  const RankedCompareBody({
    super.key,
    required this.uid,
    required this.splits,
    this.matches = const [],
  });

  @override
  ConsumerState<RankedCompareBody> createState() => _RankedCompareBodyState();
}

enum _CompareMode { splits, legends, maps }

class _RankedCompareBodyState extends ConsumerState<RankedCompareBody> {
  _CompareMode _mode = _CompareMode.splits;
  String? _splitAId;
  String? _splitBId;

  /// Whose games the right side shows; null is the profile on screen. The left
  /// side is always the profile on screen.
  String? _uidB;

  /// The real, named splits [uid] has games in, newest first. The profile on
  /// screen's come from the page; another profile's are read from its history.
  List<RankedSplitBucket> _splitsFor(String uid) =>
      (uid == widget.uid
              ? widget.splits
              : ref.watch(rankedSplitsProvider(uid)).value ?? const [])
          .where((b) => b.id != kLifetimeSplitId && b.id != kUnknownSplitId)
          .toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedCapsule(
            options: const ['Splits', 'Legends', 'Maps'],
            selected: _mode.index,
            onChanged: (i) => setState(() => _mode = _CompareMode.values[i]),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        switch (_mode) {
          _CompareMode.splits => _buildSplits(),
          _CompareMode.legends => RankedEntityCompare(
            kind: CompareKind.legends,
            matches: widget.matches,
          ),
          _CompareMode.maps => RankedEntityCompare(
            kind: CompareKind.maps,
            matches: widget.matches,
          ),
        },
      ],
    );
  }

  /// The split in [real] with [id], else the one at [index] (clamped): A
  /// defaults to the current split, B to the one before it, since splits sort
  /// newest-first.
  RankedSplitBucket? _pick(
    List<RankedSplitBucket> real,
    String? id,
    int index,
  ) {
    if (real.isEmpty) return null;
    return real.firstWhere(
      (b) => b.id == id,
      orElse: () => real[index < real.length ? index : 0],
    );
  }

  Widget _buildSplits() {
    final profiles = [
      for (final p in ref.watch(
        playerSettingsProvider.select((s) => s.profiles),
      ))
        if (p.isSet) p,
    ];
    final multi = profiles.length > 1;
    final uidA = widget.uid;
    final uidB = _uidB ?? widget.uid;
    final sameProfile = uidA == uidB;
    final realA = _splitsFor(uidA);
    final realB = _splitsFor(uidB);
    final bucketA = _pick(realA, _splitAId, 0);
    final bucketB = _pick(realB, _splitBId, 1);

    // Two splits of one profile need two splits; two profiles need one each.
    final canCompare =
        bucketA != null &&
        bucketB != null &&
        (!sameProfile || realA.length >= 2);
    const needMore = Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppTheme.xl,
        horizontal: AppTheme.lg,
      ),
      child: Column(
        children: [
          Icon(Icons.compare_arrows, size: 40, color: AppTheme.muted),
          SizedBox(height: AppTheme.md),
          Text(
            'Nothing to compare yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.xs),
          Text(
            'Need at least two splits with recorded history to compare. '
            'Compare sets two splits side by side.',
            textAlign: TextAlign.center,
            style: AppTheme.captionLarge,
          ),
        ],
      ),
    );
    if (!multi && !canCompare) return needMore;

    String nameOf(String uid) => profiles
        .firstWhere((p) => p.uid == uid, orElse: () => profiles.first)
        .name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SplitPicker(
          splitsA: realA,
          splitsB: realB,
          selectedA: bucketA?.id,
          selectedB: bucketB?.id,
          onChangedA: (id) => setState(() => _splitAId = id),
          onChangedB: (id) => setState(() => _splitBId = id),
          profiles: multi ? {for (final p in profiles) p.uid: p.name} : null,
          profileB: uidB,
          nameA: multi ? nameOf(uidA) : null,
          // Another profile starts on the split you are looking at, so the
          // first thing you see is the two of you over the same split.
          onProfileB: (uid) => setState(() {
            _uidB = uid == widget.uid ? null : uid;
            _splitBId = uid == widget.uid ? null : bucketA?.id;
          }),
        ),
        const SizedBox(height: AppTheme.md),
        if (!canCompare)
          needMore
        else
          _CompareBody(
            uidA: uidA,
            uidB: uidB,
            bucketA: bucketA,
            bucketB: bucketB,
            nameA: sameProfile
                ? bucketA.displayName
                : '${nameOf(uidA)} · ${bucketA.displayName}',
            nameB: sameProfile
                ? bucketB.displayName
                : '${nameOf(uidB)} · ${bucketB.displayName}',
            note: sameProfile
                ? null
                : 'Splits can differ in length, map rotation, and legend '
                      'balance, and each profile\'s games are the ones '
                      'recorded on this device.',
          ),
      ],
    );
  }
}

class _SplitPicker extends StatelessWidget {
  final List<RankedSplitBucket> splitsA;
  final List<RankedSplitBucket> splitsB;
  final String? selectedA;
  final String? selectedB;
  final ValueChanged<String> onChangedA;
  final ValueChanged<String> onChangedB;

  /// Saved profiles by UID, or null with just one, when there is nothing to
  /// choose between and the labels stay plain.
  final Map<String, String>? profiles;
  final String profileB;

  /// The profile on screen, named on the fixed Current side; null with one.
  final String? nameA;
  final ValueChanged<String> onProfileB;

  const _SplitPicker({
    required this.splitsA,
    required this.splitsB,
    required this.selectedA,
    required this.selectedB,
    required this.onChangedA,
    required this.onChangedB,
    required this.profiles,
    required this.profileB,
    required this.nameA,
    required this.onProfileB,
  });

  @override
  Widget build(BuildContext context) {
    final left = _LabeledDropdown(
      label: nameA == null ? 'Current' : 'Current · $nameA',
      splits: splitsA,
      value: selectedA,
      onChanged: onChangedA,
      color: kCompareColorA,
    );
    final right = _LabeledDropdown(
      label: 'Comparing',
      splits: splitsB,
      value: selectedB,
      onChanged: onChangedB,
      profiles: profiles,
      profile: profileB,
      onProfile: onProfileB,
      color: kCompareColorB,
    );
    // At a larger text size two dropdowns side by side cut off the very thing
    // being chosen, so they stack.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.sm),
            child: Text('vs', style: AppTheme.captionLarge),
          ),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: left),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.sm),
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('vs', style: AppTheme.captionLarge),
          ),
        ),
        Expanded(child: right),
      ],
    );
  }
}

const _kLabelStyle = TextStyle(
  color: AppTheme.muted,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final List<RankedSplitBucket> splits;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Saved profiles by UID, to choose this side's from; null for a plain label.
  final Map<String, String>? profiles;
  final String profile;
  final ValueChanged<String>? onProfile;

  /// The side's colour, as a small key beside the label.
  final Color color;

  const _LabeledDropdown({
    required this.label,
    required this.splits,
    required this.value,
    required this.onChanged,
    required this.color,
    this.profiles,
    this.profile = '',
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final names = profiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.xs, left: 2),
          child: names == null
              ? _Keyed(
                  color: color,
                  child: Text(label.toUpperCase(), style: _kLabelStyle),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Choose profile',
                  color: AppTheme.surface,
                  onSelected: onProfile,
                  itemBuilder: (_) => [
                    for (final e in names.entries)
                      PopupMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _KeySwatch(color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${label.toUpperCase()} · '
                          '${(names[profile] ?? '').toUpperCase()}',
                          overflow: TextOverflow.ellipsis,
                          style: _kLabelStyle.copyWith(color: AppTheme.accent),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: AppTheme.accent,
                      ),
                    ],
                  ),
                ),
        ),
        _SplitDropdown(splits: splits, value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A label with its side's colour beside it.
class _Keyed extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Keyed({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _KeySwatch(color),
      const SizedBox(width: 6),
      Flexible(child: child),
    ],
  );
}

class _KeySwatch extends StatelessWidget {
  final Color color;
  const _KeySwatch(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _SplitDropdown extends StatelessWidget {
  final List<RankedSplitBucket> splits;
  final String? value;
  final ValueChanged<String> onChanged;

  const _SplitDropdown({
    required this.splits,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.surface2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          hint: const Text('No recorded games', style: AppTheme.captionLarge),
          items: [
            for (final b in splits)
              DropdownMenuItem(
                value: b.id,
                child: Text(b.displayName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

class _CompareBody extends ConsumerWidget {
  /// Whose games each side is. The same for a split against a split.
  final String uidA;
  final String uidB;
  final RankedSplitBucket bucketA;
  final RankedSplitBucket bucketB;
  final String nameA;
  final String nameB;

  /// Replaces the line about splits differing, where that is not the point.
  final String? note;

  const _CompareBody({
    required this.uidA,
    required this.uidB,
    required this.bucketA,
    required this.bucketB,
    required this.nameA,
    required this.nameB,
    this.note,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aAsync = ref.watch(
      rankedSplitDetailProvider((uid: uidA, splitId: bucketA.id)),
    );
    final bAsync = ref.watch(
      rankedSplitDetailProvider((uid: uidB, splitId: bucketB.id)),
    );

    if (aAsync.isLoading || bAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }
    final error = aAsync.error ?? bAsync.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
        child: ErrorCard(
          message: friendlyError(error),
          onRetry: () {
            ref.invalidate(
              rankedSplitDetailProvider((uid: uidA, splitId: bucketA.id)),
            );
            ref.invalidate(
              rankedSplitDetailProvider((uid: uidB, splitId: bucketB.id)),
            );
          },
        ),
      );
    }
    final a = aAsync.requireValue;
    final b = bAsync.requireValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Disclaimer(note),
        const SizedBox(height: AppTheme.md),
        _SummarySection(
          bucketA: bucketA,
          bucketB: bucketB,
          nameA: nameA,
          nameB: nameB,
          a: a,
          b: b,
        ),
        const SizedBox(height: AppTheme.md),
        // What changed from one split to the next means nothing between two
        // people.
        if (uidA == uidB) ...[
          // From the earlier split (on the right) to the one on the left.
          SplitChangesCard(
            legendsA: b.legends,
            legendsB: a.legends,
            mapsA: b.maps,
            mapsB: a.maps,
          ),
          const SizedBox(height: AppTheme.md),
        ],
        RankedSlotChart.hours(
          nameA: nameA,
          nameB: nameB,
          a: hourSlots(a.timeOfDay),
          b: hourSlots(b.timeOfDay),
          movedFromSecond: true,
        ),
        const SizedBox(height: AppTheme.md),
        RankedSlotChart.days(
          nameA: nameA,
          nameB: nameB,
          a: weekdaySlots(a.dayOfWeek),
          b: weekdaySlots(b.dayOfWeek),
          movedFromSecond: true,
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String? note;
  const _Disclaimer(this.note);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sm),
      child: Text(
        note ??
            'Splits can differ in length, map rotation, and legend balance — '
                'treat differences as a starting point, not a verdict.',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Text(text, style: AppTheme.cardTitle),
    );
  }
}

/// Elapsed days within [season] as of now, clamped to at least 1 so an
/// hours-old split doesn't divide by zero. Uses elapsed time, not the split's
/// full scheduled length, so an in-progress split isn't penalized for days it
/// hasn't reached yet.
int? _elapsedDays(SeasonMeta? season) {
  if (season == null) return null;
  final now = DateTime.now();
  final end = now.isBefore(season.end) ? now : season.end;
  final days = end.difference(season.start).inDays;
  return days < 1 ? 1 : days;
}

class _SummarySection extends StatelessWidget {
  final RankedSplitBucket bucketA;
  final RankedSplitBucket bucketB;
  final String nameA;
  final String nameB;
  final RankedSplitDetail a;
  final RankedSplitDetail b;

  const _SummarySection({
    required this.bucketA,
    required this.bucketB,
    required this.nameA,
    required this.nameB,
    required this.a,
    required this.b,
  });

  @override
  Widget build(BuildContext context) {
    final daysA = _elapsedDays(bucketA.season);
    final daysB = _elapsedDays(bucketB.season);
    final rpPerDayA = daysA == null ? null : a.summary.netRp / daysA;
    final rpPerDayB = daysB == null ? null : b.summary.netRp / daysB;
    final gamesPerDayA = daysA == null ? null : a.summary.games / daysA;
    final gamesPerDayB = daysB == null ? null : b.summary.games / daysB;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('SUMMARY'),
          CompareTable(
            nameA: nameA,
            nameB: nameB,
            rows: [
              CompareRow(
                'Games',
                '${a.summary.games}',
                '${b.summary.games}',
                delta: (a.summary.games - b.summary.games).toDouble(),
                integerDelta: true,
                deltaFromFirst: true,
                // How many games were played is a fact, not a score: no colour,
                // no leader.
                neutral: true,
              ),
              CompareRow(
                'Games/day',
                gamesPerDayA == null
                    ? kNoReading
                    : gamesPerDayA.toStringAsFixed(1),
                gamesPerDayB == null
                    ? kNoReading
                    : gamesPerDayB.toStringAsFixed(1),
                delta: (gamesPerDayA != null && gamesPerDayB != null)
                    ? gamesPerDayA - gamesPerDayB
                    : null,
                deltaFromFirst: true,
                neutral: true,
              ),
              CompareRow(
                'Net RP',
                formatSignedInt(a.summary.netRp),
                formatSignedInt(b.summary.netRp),
                delta: (a.summary.netRp - b.summary.netRp).toDouble(),
                integerDelta: true,
                deltaFromFirst: true,
              ),
              CompareRow(
                'RP/day',
                rpPerDayA == null ? kNoReading : formatSigned(rpPerDayA),
                rpPerDayB == null ? kNoReading : formatSigned(rpPerDayB),
                delta: (rpPerDayA != null && rpPerDayB != null)
                    ? rpPerDayA - rpPerDayB
                    : null,
                deltaFromFirst: true,
              ),
              CompareRow(
                'Avg RP',
                formatSigned(a.summary.avgRpPerGame),
                formatSigned(b.summary.avgRpPerGame),
                delta: a.summary.avgRpPerGame - b.summary.avgRpPerGame,
                deltaFromFirst: true,
              ),
              CompareRow(
                'Win rate',
                formatPercent(a.summary.winRate),
                formatPercent(b.summary.winRate),
                delta: (a.summary.winRate - b.summary.winRate) * 100,
                deltaFromFirst: true,
              ),
              CompareRow(
                'Avg Kills',
                formatAvgKills(a.summary.avgKills),
                formatAvgKills(b.summary.avgKills),
                delta: _diff(a.summary.avgKills, b.summary.avgKills),
                deltaFromFirst: true,
              ),
              CompareRow(
                'Avg Damage',
                formatAvgDamage(a.summary.avgDamage),
                formatAvgDamage(b.summary.avgDamage),
                delta: _diff(a.summary.avgDamage, b.summary.avgDamage),
                deltaFromFirst: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [a] minus [b], or null when either side has no reading to compare.
double? _diff(double? a, double? b) => a == null || b == null ? null : a - b;
