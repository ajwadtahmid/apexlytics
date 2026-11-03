import 'dart:convert';
import 'formatting/format.dart' show formatClock;

/// The two reasons a map alert that is otherwise due is not sent: the player's
/// quiet hours, and a mute pressed on an earlier alert.
///
/// Pure and free of any platform call, so the background fetch (which has only
/// prefs), the app and the tests all apply the same rules.

/// The default window offered when quiet hours are first switched on.
const int kDefaultQuietStartMinute = 23 * 60;
const int kDefaultQuietEndMinute = 7 * 60;

/// [value] as a minute of the day (0 to 1439), or null for anything else.
int? validMinuteOfDay(Object? value) =>
    value is int && value >= 0 && value < 24 * 60 ? value : null;

/// A window of the day, in local time, in which no alert is sent.
class QuietHours {
  final bool enabled;

  /// Minutes after local midnight. A start later than the end means the window
  /// runs past midnight (11 PM to 7 AM).
  final int startMinute;
  final int endMinute;

  const QuietHours({
    this.enabled = false,
    this.startMinute = kDefaultQuietStartMinute,
    this.endMinute = kDefaultQuietEndMinute,
  });

  static const off = QuietHours();

  /// Whether it silences anything. An empty window (start equal to end) does not.
  bool get isActive => enabled && startMinute != endMinute;

  /// Whether the local clock reads [minuteOfDay] inside the window. The start
  /// minute is inside and the end minute is not.
  bool containsMinute(int minuteOfDay) {
    if (!isActive) return false;
    return startMinute < endMinute
        ? minuteOfDay >= startMinute && minuteOfDay < endMinute
        : minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  /// Whether an alert that fires at [instant] falls in the window, by the wall
  /// clock on this device at that moment (so a DST change moves nothing by
  /// itself).
  bool covers(DateTime instant) {
    // Through the epoch: a planner time is a UTC `TZDateTime`, whose own
    // `toLocal` needs a time zone database the app never loads.
    final local = DateTime.fromMillisecondsSinceEpoch(
      instant.millisecondsSinceEpoch,
    );
    return containsMinute(local.hour * 60 + local.minute);
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.enabled == enabled &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(enabled, startMinute, endMinute);
}

/// The two mute buttons on a map alert.
enum MuteChoice {
  threeHours('mute_3h', 'Mute 3 h'),
  untilTomorrow('mute_tomorrow', 'Until tomorrow');

  /// The action id the notification carries.
  final String actionId;

  /// The button's label.
  final String label;
  const MuteChoice(this.actionId, this.label);

  static MuteChoice? fromActionId(String? id) {
    for (final c in values) {
      if (c.actionId == id) return c;
    }
    return null;
  }
}

/// The action id of the Undo button on a mute's confirmation.
const String kUnmuteActionId = 'unmute';

/// The local hour "until tomorrow" ends at.
const int kMuteUntilHour = 6;

/// When a mute pressed at [now] ends. Three hours later, or the next 6:00 AM on
/// the local clock: a mute pressed at night lasts until that morning, and one
/// pressed after 6:00 AM until tomorrow's.
DateTime muteEnd(MuteChoice choice, DateTime now) {
  switch (choice) {
    case MuteChoice.threeHours:
      return now.add(const Duration(hours: 3));
    case MuteChoice.untilTomorrow:
      final local = now.toLocal();
      final today = DateTime(
        local.year,
        local.month,
        local.day,
        kMuteUntilHour,
      );
      return local.isBefore(today)
          ? today
          : DateTime(local.year, local.month, local.day + 1, kMuteUntilHour);
  }
}

/// When a mute ends, for a label or a message: "9:40 PM" for today, or
/// "6:00 AM tomorrow".
String formatMuteEnd(DateTime end, DateTime now) {
  final e = end.toLocal();
  final n = now.toLocal();
  final sameDay = e.year == n.year && e.month == n.month && e.day == n.day;
  return sameDay ? formatClock(e) : '${formatClock(e)} tomorrow';
}

/// The muted modes in [json] (`{mode: end in ms}`) that are still muted at
/// [now]. A missing, malformed or expired entry is left out, never an error.
Map<String, DateTime> parseMutes(String? json, DateTime now) {
  if (json == null || json.isEmpty) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    final result = <String, DateTime>{};
    decoded.forEach((key, value) {
      if (key is! String || value is! int) return;
      final end = DateTime.fromMillisecondsSinceEpoch(value);
      if (end.isAfter(now)) result[key] = end;
    });
    return result;
  } on FormatException {
    return const {};
  }
}

/// [mutes] as the stored JSON, or null when nothing is muted.
String? encodeMutes(Map<String, DateTime> mutes) => mutes.isEmpty
    ? null
    : jsonEncode({
        for (final e in mutes.entries) e.key: e.value.millisecondsSinceEpoch,
      });

/// What an alert carries so its mute button knows the mode and the alert's own
/// fire time: `ranked|1782090000000`.
String alertPayload(String mode, DateTime notifyAt) =>
    '$mode|${notifyAt.millisecondsSinceEpoch}';

/// The mode and fire time in an alert's payload, or null for anything else (an
/// alert armed by an older version carries none).
({String mode, DateTime? at})? parseAlertPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  final parts = payload.split('|');
  final mode = parts.first;
  if (mode.isEmpty) return null;
  final ms = parts.length > 1 ? int.tryParse(parts[1]) : null;
  return (
    mode: mode,
    at: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
  );
}
