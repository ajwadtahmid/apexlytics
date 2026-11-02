import 'dart:convert';

/// The largest epoch-millisecond value a `DateTime` can hold.
const int kMaxEpochMs = 8640000000000000;

/// [v] as epoch milliseconds, or null when it is not a number a `DateTime` can
/// hold (a non-finite or out-of-range one makes the constructor throw).
int? asEpochMs(Object? v) =>
    v is num && v.isFinite && v.abs() <= kMaxEpochMs ? v.toInt() : null;

/// [v] as a JSON object, or null for anything else. A PHP-backed API sends an
/// empty object as `[]`, which must read as absent, not throw.
Map<String, dynamic>? asObject(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// [v] as a JSON array, or null for anything else.
List<dynamic>? asList(Object? v) => v is List ? v : null;

/// [v] as a string, or null for anything else.
String? asString(Object? v) => v is String ? v : null;

/// Decodes a JSON-encoded string array from SharedPreferences.
/// Returns an empty list on null input, malformed JSON, or JSON whose shape
/// isn't a list — the last of those throws TypeError on the `as List?` cast
/// rather than FormatException, so the catch is deliberately broad. See
/// rp_snapshot_storage._parseSnapshots for the same reasoning.
List<String> parseStringList(String? raw) {
  try {
    final list = (raw != null ? jsonDecode(raw) as List? : null) ?? [];
    return list.whereType<String>().toList();
  } catch (e) {
    return [];
  }
}
