import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/map_rotation.dart';
import '../../../utils/formatting/format.dart' show formatClock, formatTimeLeft;
import '../../../utils/alert_silence.dart' show formatMuteEnd;
import '../../../utils/theme.dart';
import '../../../widgets/surface_card.dart';
import 'map_hero_image.dart';

const _kModeRanked = 'Ranked';
const _kModePubs = 'Pubs';
const _kModeWildcard = 'Wildcards';
const _kModeMixtape = 'Mixtape';

/// Clock time the next map ends ("5:40 PM", plus "tomorrow" on another day),
/// or null when its length is unknown.
@visibleForTesting
String? formatNextMapEnd({
  required int remainingSecs,
  required int durationMins,
  DateTime? now,
}) {
  if (durationMins <= 0) return null;
  final from = now ?? DateTime.now();
  final end = from.add(Duration(seconds: remainingSecs + durationMins * 60));
  final time = formatClock(end);
  final sameDay =
      end.year == from.year && end.month == from.month && end.day == from.day;
  return sameDay ? time : '$time tomorrow';
}

/// Map rotation card: mode picker + the selected mode's current/next map,
/// with a live countdown. Owns its own mode-selection state since switching
/// modes is purely a display concern, not something the rest of Home cares
/// about.
///
/// With [onAlertTap], the map shows a bell for the mode on screen: filled when
/// [alertActive] says that mode's alert is on, and paused while
/// [alertMutedUntil] gives an end time for it. All three take the mode's label.
class MapRotationCard extends StatefulWidget {
  final MapRotation rotation;
  final VoidCallback? onExpired;
  final bool Function(String mode)? alertActive;
  final DateTime? Function(String mode)? alertMutedUntil;
  final ValueChanged<String>? onAlertTap;

  const MapRotationCard({
    super.key,
    required this.rotation,
    this.onExpired,
    this.alertActive,
    this.alertMutedUntil,
    this.onAlertTap,
  });

  @override
  State<MapRotationCard> createState() => _MapRotationCardState();
}

class _MapRotationCardState extends State<MapRotationCard> {
  int _modeIndex = 0;

  List<_ModeData> _buildModes(MapRotation rotation) => [
    _ModeData(
      label: _kModeRanked,
      current: rotation.rankedCurrent,
      next: rotation.rankedNext,
    ),
    _ModeData(
      label: _kModePubs,
      current: rotation.battleRoyaleCurrent,
      next: rotation.battleRoyaleNext,
    ),
    if (rotation.wildcardCurrent != null && rotation.wildcardNext != null)
      _ModeData(
        label: _kModeWildcard,
        current: rotation.wildcardCurrent!,
        next: rotation.wildcardNext!,
      ),
    if (rotation.ltmCurrent != null && rotation.ltmNext != null)
      _ModeData(
        label: _kModeMixtape,
        current: rotation.ltmCurrent!,
        next: rotation.ltmNext!,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final modes = _buildModes(widget.rotation);
    if (modes.isEmpty) return const SizedBox.shrink();
    final idx = _modeIndex.clamp(0, modes.length - 1);
    return Column(
      children: [
        _ModePicker(
          modes: modes.map((m) => m.label).toList(),
          selected: idx,
          onSelect: (i) => setState(() => _modeIndex = i),
        ),
        const SizedBox(height: AppTheme.md),
        _MapCard(
          mode: modes[idx],
          onExpired: widget.onExpired,
          alertActive: widget.alertActive?.call(modes[idx].label) ?? false,
          mutedUntil: widget.alertMutedUntil?.call(modes[idx].label),
          onAlertTap: widget.onAlertTap == null
              ? null
              : () => widget.onAlertTap!(modes[idx].label),
        ),
      ],
    );
  }
}

class _ModeData {
  final String label;
  final MapMode current;
  final MapMode next;
  const _ModeData({
    required this.label,
    required this.current,
    required this.next,
  });
}

// ── Mode picker ───────────────────────────────────────────────────────────────

class _ModePicker extends StatelessWidget {
  final List<String> modes;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ModePicker({
    required this.modes,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppTheme.xs),
      radius: AppTheme.radiusFull,
      child: Row(
        children: List.generate(modes.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: AppTheme.shortAnimation,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                // Four labels share one row, so the longest ("Wildcards") would
                // break mid-word past this size.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    modes[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.muted,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Map card ──────────────────────────────────────────────────────────────────

const _kCountdownTickInterval = Duration(seconds: 1);

/// How long a finished card waits before asking again when the refetch came
/// back unchanged.
const _kExpiredRetryDelay = Duration(seconds: 30);

class _MapCard extends StatefulWidget {
  final _ModeData mode;
  final VoidCallback? onExpired;
  final bool alertActive;
  final DateTime? mutedUntil;
  final VoidCallback? onAlertTap;
  const _MapCard({
    required this.mode,
    this.onExpired,
    this.alertActive = false,
    this.mutedUntil,
    this.onAlertTap,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  late int _remaining;
  late DateTime _startedAt;
  Timer? _timer;
  Timer? _retryTimer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _reset(widget.mode.current.remainingSecs);
  }

  @override
  void didUpdateWidget(_MapCard old) {
    super.didUpdateWidget(old);
    if (old.mode.label != widget.mode.label ||
        old.mode.current.map != widget.mode.current.map ||
        old.mode.current.remainingSecs != widget.mode.current.remainingSecs) {
      _reset(widget.mode.current.remainingSecs);
    } else if (_expired && !identical(old.mode.current, widget.mode.current)) {
      // The refetch at expiry came back unchanged (a cached copy), so the old
      // map is still showing: ask again shortly rather than never.
      _retryTimer?.cancel();
      _retryTimer = Timer(_kExpiredRetryDelay, () {
        if (mounted) widget.onExpired?.call();
      });
    }
  }

  void _reset(int secs) {
    _expired = false;
    _retryTimer?.cancel();
    _timer?.cancel();
    _remaining = secs;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(_kCountdownTickInterval, (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_startedAt).inSeconds;
      final newRemaining = (secs - elapsed).clamp(0, secs);
      if (newRemaining != _remaining) {
        setState(() => _remaining = newRemaining);
      }
      if (newRemaining == 0 && !_expired) {
        _expired = true;
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  static String _formatEndTime(int remainingSecs) {
    final end = DateTime.now().add(Duration(seconds: remainingSecs));
    return formatClock(end);
  }

  static String _formatMapDisplay(
    String mapName,
    String? eventName,
    bool isMixtape,
  ) {
    if (isMixtape && eventName != null && eventName.isNotEmpty) {
      return '$mapName ($eventName)';
    }
    return mapName;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.mode.current;
    final next = widget.mode.next;
    final isMixtape = widget.mode.label == _kModeMixtape;

    return SurfaceCard(
      radius: AppTheme.radiusLg,
      clip: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MapHeroImage(mapName: current.map, assetUrl: current.asset),
              if (widget.onAlertTap != null)
                Positioned(
                  // The bell's tap area is 4 dp bigger all round than the
                  // circle drawn, so it moves out to keep the circle in place.
                  top: AppTheme.sm - 4,
                  right: AppTheme.sm - 4,
                  child: _AlertBell(
                    mode: widget.mode.label,
                    active: widget.alertActive,
                    mutedUntil: widget.mutedUntil,
                    onTap: widget.onAlertTap!,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  _formatMapDisplay(current.map, current.eventName, isMixtape),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppTheme.accent,
                      size: 14,
                    ),
                    const SizedBox(width: AppTheme.xs),
                    Text(
                      '${formatTimeLeft(_remaining)} remaining',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AppTheme.surface2, height: 1),
                const SizedBox(height: 10),
                _NextMapRow(
                  next: next,
                  remaining: _remaining,
                  isMixtape: isMixtape,
                  formatEndTime: _formatEndTime,
                  formatMapDisplay: _formatMapDisplay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Alert bell ────────────────────────────────────────────────────────────────

/// A round bell over the map: outlined to set an alert for [mode], filled and
/// orange once one is set, and paused (with the time it ends, in its label)
/// while [mutedUntil] is set.
class _AlertBell extends StatelessWidget {
  final String mode;
  final bool active;
  final DateTime? mutedUntil;
  final VoidCallback onTap;

  const _AlertBell({
    required this.mode,
    required this.active,
    required this.mutedUntil,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = active && mutedUntil != null;
    final label = muted
        ? '$mode alerts are muted until ${formatMuteEnd(mutedUntil!, DateTime.now())}. Tap to unmute.'
        : active
        ? '$mode alerts are on. Tap to change.'
        : 'Alert me before the $mode map changes';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        // 48 dp to tap, 40 dp drawn.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      muted
                          ? Icons.notifications_paused
                          : active
                          ? Icons.notifications_active
                          : Icons.notifications_none_outlined,
                      color: muted
                          ? AppTheme.muted
                          : active
                          ? AppTheme.accent
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Next map row ──────────────────────────────────────────────────────────────

class _NextMapRow extends StatelessWidget {
  final MapMode next;
  final int remaining;
  final bool isMixtape;
  final String Function(int) formatEndTime;
  final String Function(String, String?, bool) formatMapDisplay;

  const _NextMapRow({
    required this.next,
    required this.remaining,
    required this.isMixtape,
    required this.formatEndTime,
    required this.formatMapDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final nextEnd = formatNextMapEnd(
      remainingSecs: remaining,
      durationMins: next.durationMins,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'UP NEXT',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Starts at ${formatEndTime(remaining)}',
              style: AppTheme.caption,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        Row(
          children: [
            const Icon(Icons.arrow_forward, size: 14, color: AppTheme.muted),
            const SizedBox(width: AppTheme.xs),
            Expanded(
              child: Text(
                formatMapDisplay(next.map, next.eventName, isMixtape),
                style: AppTheme.captionLarge,
              ),
            ),
            if (nextEnd != null) ...[
              const SizedBox(width: AppTheme.sm),
              Text('Ends at $nextEnd', style: AppTheme.caption),
            ],
          ],
        ),
      ],
    );
  }
}
