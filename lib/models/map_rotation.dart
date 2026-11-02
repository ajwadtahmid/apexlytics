class MapRotation {
  final MapMode battleRoyaleCurrent;
  final MapMode battleRoyaleNext;
  final MapMode rankedCurrent;
  final MapMode rankedNext;
  final MapMode? ltmCurrent;
  final MapMode? ltmNext;
  final MapMode? wildcardCurrent;
  final MapMode? wildcardNext;

  /// When this rotation was received. Each mode's `remainingSecs` is a
  /// countdown from that moment, so it only means something next to it.
  final DateTime fetchedAt;

  MapRotation({
    required this.battleRoyaleCurrent,
    required this.battleRoyaleNext,
    required this.rankedCurrent,
    required this.rankedNext,
    this.ltmCurrent,
    this.ltmNext,
    this.wildcardCurrent,
    this.wildcardNext,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  /// This rotation with every countdown reduced by the time since it was
  /// fetched, so a plan made later still lands on the real rotation instants.
  MapRotation agedTo(DateTime now) {
    final elapsed = now.difference(fetchedAt);
    if (elapsed <= Duration.zero) return this;
    return MapRotation(
      battleRoyaleCurrent: battleRoyaleCurrent.aged(elapsed),
      battleRoyaleNext: battleRoyaleNext.aged(elapsed),
      rankedCurrent: rankedCurrent.aged(elapsed),
      rankedNext: rankedNext.aged(elapsed),
      ltmCurrent: ltmCurrent?.aged(elapsed),
      ltmNext: ltmNext?.aged(elapsed),
      wildcardCurrent: wildcardCurrent?.aged(elapsed),
      wildcardNext: wildcardNext?.aged(elapsed),
      fetchedAt: now,
    );
  }

  /// Any block that is not a JSON object (a PHP-style empty block arrives as
  /// `[]`) counts as absent, rather than failing the whole rotation: a cast
  /// error here would blank Home for every mode and abort the background
  /// alert job.
  static Map<String, dynamic>? _object(Object? v) =>
      v is Map<String, dynamic> ? v : null;

  factory MapRotation.fromJson(Map<String, dynamic> json) {
    final battleRoyaleJson = _object(json['battle_royale']) ?? {};
    final ranked = _object(json['ranked']) ?? {};
    final ltm = _object(json['ltm']);
    final wildcard = _object(json['wildcard']);

    MapMode mode(Map<String, dynamic> block, String key) =>
        MapMode.fromJson(_object(block[key]) ?? {});

    return MapRotation(
      battleRoyaleCurrent: mode(battleRoyaleJson, 'current'),
      battleRoyaleNext: mode(battleRoyaleJson, 'next'),
      rankedCurrent: mode(ranked, 'current'),
      rankedNext: mode(ranked, 'next'),
      ltmCurrent: ltm != null ? mode(ltm, 'current') : null,
      ltmNext: ltm != null ? mode(ltm, 'next') : null,
      wildcardCurrent: wildcard != null ? mode(wildcard, 'current') : null,
      wildcardNext: wildcard != null ? mode(wildcard, 'next') : null,
    );
  }
}

class MapMode {
  final String map;
  final int remainingSecs;
  final int durationMins;
  final String asset;
  final String? eventName;

  MapMode({
    required this.map,
    required this.remainingSecs,
    required this.durationMins,
    required this.asset,
    this.eventName,
  });

  factory MapMode.fromJson(Map<String, dynamic> json) {
    final mins = (json['remainingMins'] as num?)?.toInt() ?? 0;
    // The API sometimes returns minutes only — derive seconds from minutes
    // when remainingSecs is absent.
    final secs = (json['remainingSecs'] as num?)?.toInt() ?? mins * 60;
    return MapMode(
      map: json['map'] as String? ?? 'Unknown',
      // A glitch can send a negative countdown; it means "already over".
      remainingSecs: secs < 0 ? 0 : secs,
      // JSON key uses PascalCase — API inconsistency, not a typo.
      durationMins: (json['DurationInMinutes'] as num?)?.toInt() ?? 0,
      asset: json['asset'] as String? ?? '',
      eventName: json['eventName'] as String?,
    );
  }

  /// This mode with its countdown reduced by [elapsed], never below zero.
  MapMode aged(Duration elapsed) {
    final left = remainingSecs - elapsed.inSeconds;
    return MapMode(
      map: map,
      remainingSecs: left < 0 ? 0 : left,
      durationMins: durationMins,
      asset: asset,
      eventName: eventName,
    );
  }
}
