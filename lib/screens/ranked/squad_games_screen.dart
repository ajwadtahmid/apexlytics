import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../constants/map_constants.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shared_matches_provider.dart';
import '../../utils/error_messages.dart';
import '../../utils/formatting/format.dart'
    show
        formatAvgDamage,
        formatAvgKills,
        formatClock,
        formatDuration,
        formatShortDate,
        formatSigned,
        formatSignedInt,
        plural;
import '../../utils/ranked/ranked_period.dart';
import '../../utils/ranked/shared_matches.dart';
import '../../utils/formatting/season_utils.dart' show WeekRange;
import '../../utils/theme.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/error_card.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/legend_icon.dart';
import '../../widgets/map_asset_image.dart';
import '../../widgets/nav_entry_card.dart';
import '../../widgets/segmented_capsule.dart';
import '../../widgets/surface_card.dart';
import 'squad_game_detail_screen.dart';
import 'widgets/ranked_period_selector.dart';
import 'widgets/ranked_period_sheets.dart';
import 'widgets/squad_table.dart';

/// The saved profiles with a player set, each once, in saved order.
List<PlayerProfile> savedProfilesOf(List<PlayerProfile> profiles) {
  final seen = <String>{};
  return [
    for (final p in profiles)
      if (p.isSet && seen.add(p.uid)) p,
  ];
}

/// Whether the squad games tile applies: the player on screen is one of at
/// least two saved profiles. With one there is no one to have played with.
bool canShowSquadGames(List<PlayerProfile> profiles, String uid) {
  final saved = savedProfilesOf(profiles);
  return saved.length >= 2 && saved.any((p) => p.uid == uid);
}

/// A tappable tile that opens the squad games page, shown only when
/// [canShowSquadGames].
class SquadGamesEntry extends ConsumerWidget {
  /// The player on screen: the first profile of the page.
  final String uid;

  /// The period the Stats page is showing, which the page starts on.
  final RankedView view;
  const SquadGamesEntry({super.key, required this.uid, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(
      playerSettingsProvider.select((s) => s.profiles),
    );
    if (!canShowSquadGames(profiles, uid)) return const SizedBox.shrink();
    return NavEntryCard(
      icon: Icons.groups_outlined,
      title: 'Squad Games',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SquadGamesScreen(uid: uid, view: view),
        ),
      ),
    );
  }
}

/// The ranked games two or three of the saved profiles played together, with
/// each profile's results side by side.
///
/// The first profile is always the player on screen. It starts on the season
/// and week the Stats page shows; changing them here leaves Stats as it was.
class SquadGamesScreen extends ConsumerStatefulWidget {
  final String uid;
  final RankedView view;
  const SquadGamesScreen({super.key, required this.uid, required this.view});

  @override
  ConsumerState<SquadGamesScreen> createState() => _SquadGamesScreenState();
}

class _SquadGamesScreenState extends ConsumerState<SquadGamesScreen> {
  bool _three = false;
  bool _triosOnly = false;
  late String _splitId = widget.view.effectiveSplitId;
  late int _week = widget.view.weekIndex;
  late List<String> _slots = [widget.uid];

  /// Keeps the slots to saved profiles, each once, with the player on screen
  /// first and no more than the view needs.
  void _sanitize(List<String> saved) {
    if (saved.length < 3) _three = false;
    final want = _three ? 3 : 2;
    final kept = <String>{
      widget.uid,
      for (final s in _slots)
        if (saved.contains(s)) s,
    }.toList();
    for (final id in saved) {
      if (kept.length >= want) break;
      if (!kept.contains(id)) kept.add(id);
    }
    _slots = kept.take(want).toList();
  }

  List<WeekRange> get _weeks {
    for (final b in widget.view.splits) {
      if (b.id == _splitId) return weeksForBucket(b);
    }
    return const [];
  }

  RankedView get _periodView {
    final weeks = _weeks;
    return RankedView(
      splits: widget.view.splits,
      effectiveSplitId: _splitId,
      weeks: weeks,
      weekIndex: _week < weeks.length ? _week : -1,
      filtered: const [],
      history: const [],
    );
  }

  String get _splitLabel {
    for (final b in widget.view.splits) {
      if (b.id == _splitId) return b.displayName;
    }
    return 'Season';
  }

  bool _inPeriod(SharedMatch m) {
    final weeks = _weeks;
    if (_week < 0 || _week >= weeks.length) return true;
    final w = weeks[_week];
    return !m.end.isBefore(w.start) && m.end.isBefore(w.end);
  }

  bool _isShown(SharedMatch m) {
    if (!_inPeriod(m)) return false;
    if (!_three) return _slots.every(m.includes);
    final n = _slots.where(m.includes).length;
    return _triosOnly ? n == 3 : n >= 2;
  }

  Future<void> _pick(int slot, List<PlayerProfile> saved) {
    return showChoiceSheet<String>(
      context,
      title: 'Profile ${slot + 1}',
      selected: _slots[slot],
      options: [
        for (final p in saved)
          if (p.uid != widget.uid)
            ChoiceOption(
              value: p.uid,
              icon: Icons.person_outline,
              label: p.name,
            ),
      ],
      footnote: _three
          ? 'A profile that is already in the other slot swaps places with '
                'this one.'
          : null,
      onChosen: (uid) => setState(() {
        final slots = [..._slots];
        final other = slots.indexOf(uid);
        if (other >= 0) slots[other] = slots[slot];
        slots[slot] = uid;
        _slots = slots;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = savedProfilesOf(
      ref.watch(playerSettingsProvider.select((s) => s.profiles)),
    );
    final names = {for (final p in saved) p.uid: p.name};
    _sanitize([for (final p in saved) p.uid]);
    final result = ref.watch(sharedMatchesProvider(_splitId));
    final shown = [
      for (final m in result.value ?? const <SharedMatch>[])
        if (_isShown(m)) m,
    ];
    final weeks = _weeks;

    final top = <Widget>[
      if (saved.length >= 3) ...[
        Center(
          child: SegmentedCapsule(
            options: const ['2 profiles', '3 profiles'],
            selected: _three ? 1 : 0,
            onChanged: (i) => setState(() {
              _three = i == 1;
              if (!_three) _triosOnly = false;
            }),
          ),
        ),
        const SizedBox(height: AppTheme.md),
      ],
      _SlotBar(slots: _slots, names: names, onTap: (i) => _pick(i, saved)),
      const SizedBox(height: AppTheme.sm),
      // Season on the left and week on the right, as on the Stats page.
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Shortens its label before the week pill is pushed off the screen.
          Flexible(
            child: RankedPeriodButton(
              label: _splitLabel,
              semanticsLabel: 'Season, $_splitLabel',
              onTap: () => showSplitSheet(
                context,
                view: _periodView,
                // A new season starts on all its weeks, as on Stats.
                onSelected: (id) => setState(() {
                  _splitId = id;
                  _week = -1;
                }),
              ),
            ),
          ),
          if (weeks.isNotEmpty)
            RankedPeriodButton(
              label: _week < 0 || _week >= weeks.length
                  ? 'Week: All'
                  : 'Week: ${_week + 1}',
              semanticsLabel: _week < 0 ? 'Week, all' : 'Week ${_week + 1}',
              onTap: () => showWeekSheet(
                context,
                view: _periodView,
                onSelected: (i) => setState(() => _week = i),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppTheme.sm),
    ];

    final body = <Widget>[];
    if (result.hasError && !result.hasValue) {
      body.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
          child: ErrorCard(
            message: friendlyError(result.error!),
            onRetry: () => ref.invalidate(sharedMatchesProvider(_splitId)),
          ),
        ),
      );
    } else if (!result.hasValue) {
      body.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.xl),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
      );
    } else {
      if (shown.isNotEmpty) {
        body.add(_Summary(slots: _slots, names: names, games: shown));
        body.add(const SizedBox(height: AppTheme.lg));
      }
      // Shown with no games too, so "Trios only" can be turned off.
      if (shown.isNotEmpty || _three) {
        body.add(
          _GamesHeader(
            count: shown.length,
            trailing: _three
                ? FilterChip(
                    label: const Text('Trios only'),
                    selected: _triosOnly,
                    onSelected: (v) => setState(() => _triosOnly = v),
                    // On is solid orange with dark text and a tick, off a quiet
                    // outline, as on the Recap share page.
                    showCheckmark: true,
                    checkmarkColor: AppTheme.onAccent,
                    selectedColor: AppTheme.accent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: _triosOnly
                          ? AppTheme.accent
                          : AppTheme.muted.withAlpha(120),
                    ),
                    labelStyle: TextStyle(
                      color: _triosOnly ? AppTheme.onAccent : AppTheme.muted,
                      fontWeight: _triosOnly
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  )
                : null,
          ),
        );
      }
      if (shown.isEmpty) {
        body.add(_Empty(triosOnly: _triosOnly));
      } else {
        String? day;
        for (final m in shown) {
          final d = formatShortDate(m.start);
          if (d != day) {
            day = d;
            body.add(
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.md,
                  bottom: AppTheme.sm,
                ),
                child: Text(d.toUpperCase(), style: AppTheme.captionSmall),
              ),
            );
          }
          body.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sm),
              child: _GameRow(
                match: m,
                slots: _slots,
                names: names,
                showSquadTag: _three,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SquadGameDetailScreen(
                      match: m,
                      slots: List.of(_slots),
                      names: names,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        body.add(const SizedBox(height: AppTheme.md));
        body.add(
          const Text(
            'Games are matched by their start and end times, as no match ID '
            'is shared between players. A rare game may be paired by chance.',
            style: AppTheme.captionSmall,
          ),
        );
      }
    }

    final items = [...top, ...body];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How to read this',
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(AppTheme.md),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        ),
      ),
    );
  }
}

/// The profiles on show, one button each. The first is the player on screen and
/// is locked; the others open a list of the saved profiles.
class _SlotBar extends StatelessWidget {
  final List<String> slots;
  final Map<String, String> names;
  final ValueChanged<int> onTap;
  const _SlotBar({
    required this.slots,
    required this.names,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, uid) in slots.indexed) ...[
          if (i > 0) const SizedBox(width: AppTheme.xs),
          Expanded(
            child: Semantics(
              button: i > 0,
              label: i == 0
                  ? '${names[uid] ?? ''}, the player on screen'
                  : 'Profile ${i + 1}, ${names[uid] ?? ''}',
              excludeSemantics: true,
              onTap: i == 0 ? null : () => onTap(i),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: i == 0 ? null : () => onTap(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.surface2),
                  ),
                  child: Row(
                    children: [
                      _Swatch(i),
                      const SizedBox(width: 6),
                      Expanded(
                        // Two lines, and the whole name on a long press: two
                        // profiles with a shared start look alike when cut.
                        child: Tooltip(
                          message: names[uid] ?? '',
                          child: Text(
                            names[uid] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // The player on screen cannot be changed, so no arrow.
                      if (i > 0)
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A profile's mark: its colour in a shape of its own (square, circle,
/// diamond), so two profiles never differ by colour alone. [letter] sits inside
/// when there is room for it.
class _Swatch extends StatelessWidget {
  final int index;
  final String? letter;
  const _Swatch(this.index, {this.letter});

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = switch (index) {
      0 => RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      1 => const CircleBorder(),
      _ => const StarBorder.polygon(sides: 4, pointRounding: 0.15),
    };
    final size = letter == null ? 11.0 : 18.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: AppTheme.profileColors[index],
        shape: shape,
      ),
      // No letter on the diamond: its corners leave no room for one. It is
      // never scaled with the text, which would outgrow the shape.
      child: letter == null || index > 1
          ? null
          : Text(
              letter!,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: AppTheme.onAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
    );
  }
}

/// How the profiles did across the games on show.
class _Summary extends StatelessWidget {
  final List<String> slots;
  final Map<String, String> names;
  final List<SharedMatch> games;
  const _Summary({
    required this.slots,
    required this.names,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    final perSlot = [
      for (final s in slots)
        [
          for (final m in games)
            if (m.games[s] != null) m.games[s]!,
        ],
    ];
    double? average(Iterable<int?> values) {
      final present = values.whereType<int>().toList();
      if (present.isEmpty) return null;
      return present.reduce((a, b) => a + b) / present.length;
    }

    final sameCount = perSlot.every((g) => g.length == perSlot.first.length);
    final trios = slots.length == 3
        ? games.where((m) => slots.every(m.includes)).length
        : null;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOGETHER', style: AppTheme.cardTitle),
          const SizedBox(height: AppTheme.xs),
          Text(
            trios == null
                ? plural(games.length, 'game')
                : '${plural(games.length, 'game')} · ${plural(trios, 'trio')}'
                      ' · ${plural(games.length - trios, 'duo')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.md),
          SquadTable(
            columns: [
              for (final (i, s) in slots.indexed)
                SquadColumn(names[s] ?? '', AppTheme.profileColors[i]),
            ],
            rows: [
              // Two profiles always share every game, so the count says nothing.
              if (!sameCount)
                SquadStatRow(
                  'Games',
                  [for (final g in perSlot) g.length],
                  (v) => '$v',
                  neutral: true,
                ),
              // A total favours whoever played more games: outlined only when
              // the counts match, and the average is outlined instead.
              SquadStatRow(
                'Net RP',
                [
                  // No reading, not a zero gain, for a profile with no games.
                  for (final g in perSlot)
                    g.isEmpty ? null : g.fold<int>(0, (a, m) => a + m.rpChange),
                ],
                (v) => formatSignedInt(v.toInt()),
                signed: true,
                neutral: !sameCount,
              ),
              if (!sameCount)
                SquadStatRow(
                  'Avg RP',
                  [for (final g in perSlot) average(g.map((m) => m.rpChange))],
                  (v) => formatSigned(v.toDouble()),
                  signed: true,
                ),
              SquadStatRow('Avg kills', [
                for (final g in perSlot) average(g.map((m) => m.kills)),
              ], (v) => formatAvgKills(v.toDouble())),
              SquadStatRow('Avg damage', [
                for (final g in perSlot) average(g.map((m) => m.damage)),
              ], (v) => formatAvgDamage(v.toDouble())),
            ],
          ),
        ],
      ),
    );
  }
}

class _GamesHeader extends StatelessWidget {
  final int count;
  final Widget? trailing;
  const _GamesHeader({required this.count, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GAMES · $count', style: AppTheme.cardTitle),
              const Text('Newest first', style: AppTheme.captionSmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  /// Whether the "Trios only" filter is what emptied the list.
  final bool triosOnly;
  const _Empty({this.triosOnly = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xl),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, size: 40, color: AppTheme.muted),
          const SizedBox(height: AppTheme.md),
          Text(
            triosOnly ? 'No trios in this period' : 'No games together',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            triosOnly
                ? 'None of these games had all three profiles in it. Turn off '
                      '"Trios only" to see the games two of them played.'
                : 'None of the ranked games recorded on this device for these '
                      'profiles line up in this period.',
            textAlign: TextAlign.center,
            style: AppTheme.captionLarge,
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final SharedMatch match;
  final List<String> slots;
  final Map<String, String> names;

  /// Whether to say duo or trio (the three-profile view).
  final bool showSquadTag;
  final VoidCallback onTap;
  const _GameRow({
    required this.match,
    required this.slots,
    required this.names,
    required this.showSquadTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = [
      for (final u in match.uids)
        if (!slots.contains(u)) u,
    ];
    final asset = battleRoyaleMapAsset(match.mapKey);
    final mapName = battleRoyaleMapName(match.mapKey);
    final spoken = [
      mapName,
      if (showSquadTag) match.squadSize == 3 ? 'trio' : 'duo',
      '${formatClock(match.start)}, ${formatDuration(match.lengthSecs)}',
      for (final uid in slots)
        if (match.games[uid] case final game?)
          '${names[uid] ?? ''} ${formatSignedInt(game.rpChange)} RP',
      if (extras.isNotEmpty)
        'also ${extras.map((u) => names[u] ?? '').join(', ')}',
    ].join(', ');
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.sm),
      child: Semantics(
        label: spoken,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: asset == null
                    ? const ColoredBox(color: AppTheme.surface2)
                    : MapAssetImage(asset: asset),
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        mapName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showSquadTag)
                        match.squadSize == 3
                            ? const _Tag(
                                'TRIO',
                                AppTheme.indigo,
                                icon: Icons.groups,
                              )
                            : const _Tag(
                                'DUO',
                                AppTheme.blue,
                                icon: Icons.people,
                              ),
                      // A count, not names: names can be very long. They are in
                      // the tooltip and on the game's own page.
                      if (extras.isNotEmpty)
                        Tooltip(
                          message:
                              'Also in this game: '
                              '${extras.map((u) => names[u] ?? '').join(', ')}',
                          child: _Tag(
                            '+${extras.length} more',
                            AppTheme.muted,
                            icon: Icons.person_add_alt_1,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${formatClock(match.start)} · '
                    '${formatDuration(match.lengthSecs)}',
                    style: AppTheme.captionSmall,
                  ),
                  const SizedBox(height: 6),
                  // Only who was in the game; a profile that was not is left out.
                  Wrap(
                    spacing: AppTheme.md,
                    runSpacing: 4,
                    children: [
                      for (final (i, uid) in slots.indexed)
                        if (match.games[uid] case final game?)
                          _MemberChip(
                            index: i,
                            letter: _initial(names[uid]),
                            legend: game.legend,
                            rp: game.rpChange,
                          ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Tag(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      border: Border.all(color: color.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

String _initial(String? name) =>
    name == null || name.isEmpty ? '' : name.characters.first.toUpperCase();

/// One profile in a game row: its mark, legend and RP.
class _MemberChip extends StatelessWidget {
  final int index;

  /// The profile's first letter, as a further hint beside colour and shape.
  final String letter;
  final String legend;
  final int rp;
  const _MemberChip({
    required this.index,
    required this.letter,
    required this.legend,
    required this.rp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Swatch(index, letter: letter),
        const SizedBox(width: 4),
        LegendIcon(legendName: legend, size: 14),
        const SizedBox(width: 4),
        Text(
          formatSignedInt(rp),
          style: TextStyle(
            color: AppTheme.signColor(rp >= 0),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

void _showInfoSheet(BuildContext context) => showInfoSheet(
  context,
  title: 'Squad Games',
  warning:
      'This is an estimate and may not be fully accurate. The app cannot tell '
      'for certain who played together, so it can miss a game you did play '
      'together, and now and then pair games that were not the same match.',
  lines: [
    'These are the ranked games two or three of your saved profiles played '
        'together, with each profile\'s results side by side. Tap a game to '
        'see it in full.',
    'The game data has no match ID, so games are matched by their start and end '
        'times. Games that start and end close together are paired. Looser '
        'ones are kept only when the games around them line up too.',
    'Only ranked games recorded on this device are used. Games played before '
        'a profile was added here, or while the app was not recording it, '
        'cannot appear.',
    'Each game\'s page says how close the match was. "Looser match" means it '
        'was counted because the games before and after also line up.',
    'The first profile is always the player on screen. Pick the others from '
        'the boxes at the top, and the season and week from the pills. In the '
        'three-profile view, games two of the three played are listed too, '
        'marked DUO.',
    'A grey "+1 more" means another saved profile of yours was in that game '
        'too. Its name is on the game\'s own page.',
    'In the tables, the outlined figure is the best of the row. Totals are '
        'only outlined when everyone played the same number of games.',
  ],
);
