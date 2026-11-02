import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../constants/prefs_keys.dart';

/// More than anyone saves; bounds the list a crafted backup could carry.
const int kMaxFormerProfileUids = 200;

final _uidShape = RegExp('^${ApiConstants.uidPattern.pattern}\$');

/// Whether [v] could be a profile's UID. Loose on purpose: whatever a profile
/// carried must stay protected, and a bound keeps a crafted backup small.
bool _plausibleUid(String v) => v.isNotEmpty && v.length <= 64;

/// The UIDs in a stored list, skipping anything that is not a UID.
Set<String> parseFormerProfileUids(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return {
      for (final v in decoded)
        if (v is String && _plausibleUid(v)) v,
    };
  } on FormatException {
    return {};
  }
}

String _encode(Set<String> uids) =>
    jsonEncode(uids.take(kMaxFormerProfileUids).toList());

/// Every UID that has been a saved profile on this device.
Set<String> loadFormerProfileUids(SharedPreferences prefs) =>
    parseFormerProfileUids(prefs.getString(PrefsKeys.formerProfileUids));

/// Adds [uids] to the list. A removed profile's history is then kept like a
/// current one's, so removing a profile never starts its trim.
Future<void> rememberProfileUids(
  SharedPreferences prefs,
  Iterable<String> uids,
) async {
  final known = loadFormerProfileUids(prefs);
  final added = uids.where(_plausibleUid);
  final merged = {...known, ...added};
  if (merged.length == known.length) return;
  await prefs.setString(PrefsKeys.formerProfileUids, _encode(merged));
}

/// The UIDs whose RP history the launch trim leaves alone: the [current]
/// profiles and every UID that has been one. [current] is remembered first, so
/// profiles saved before the list existed, or arriving with a restore, join it.
Future<Set<String>> profileUidsToProtect(
  SharedPreferences prefs,
  Set<String> current,
) async {
  await rememberProfileUids(prefs, current);
  return {...current, ...loadFormerProfileUids(prefs)};
}

/// Keeps only [keep] in the list, for after the history of everyone else is
/// cleared.
Future<void> retainProfileUids(
  SharedPreferences prefs,
  Set<String> keep,
) async {
  final known = loadFormerProfileUids(prefs);
  final kept = known.intersection(keep);
  if (kept.length == known.length) return;
  if (kept.isEmpty) {
    await prefs.remove(PrefsKeys.formerProfileUids);
  } else {
    await prefs.setString(PrefsKeys.formerProfileUids, _encode(kept));
  }
}

/// The list a restore leaves: this device's own UIDs plus the backup's. A
/// restore replaces the profiles, so the ones it replaces must stay known.
String mergeRestoredFormerProfileUids({
  required String backupRaw,
  required String? deviceRaw,
}) => _encode({
  ...parseFormerProfileUids(deviceRaw),
  ...parseFormerProfileUids(backupRaw),
});

/// Prefixes of the prefs keys that hold one player's data, `<prefix><uid>`.
/// The rank goal key adds `@<split>` after the UID.
final List<String> _uidScopedPrefixes = [
  PrefsKeys.snapshotKeyPrefix,
  PrefsKeys.legendStatsKeyPrefix,
  PrefsKeys.legendVisitStackPrefix,
  PrefsKeys.rankGoalPrefix,
  PrefsKeys.gamesNextSync(''),
  PrefsKeys.gamesLastOutcome(''),
];

/// The UID in a player-scoped prefs [key], or null for any other key.
String? uidOfScopedKey(String key) {
  for (final prefix in _uidScopedPrefixes) {
    if (!key.startsWith(prefix)) continue;
    final uid = key.substring(prefix.length).split('@').first;
    return _uidShape.hasMatch(uid) ? uid : null;
  }
  return null;
}

/// The player-scoped prefs keys of everyone not in [keep].
List<String> scopedKeysExcept(SharedPreferences prefs, Set<String> keep) => [
  for (final key in prefs.getKeys())
    if (uidOfScopedKey(key) case final uid? when !keep.contains(uid)) key,
];
