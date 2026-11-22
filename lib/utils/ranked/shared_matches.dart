/// Finds the ranked games that two or three saved profiles played together.
///
/// Upstream gives no match id, so "played together" is estimated from times.
/// The rule below is provisional: it comes from testing on real histories and
/// may still change, so it lives in one function and four named constants.
///
/// A game on one profile and a game on another are a *pair* when their starts
/// and ends are close:
///
/// - **Tight**: starts within [kSharedTightStartSecs] and ends within
///   [kSharedTightEndSecs]. Accepted on its own.
/// - **Wide**: starts within [kSharedWideStartSecs] and ends within
///   [kSharedWideEndSecs]. Accepted only when the game before, or the game
///   after, on both profiles is a wide pair too: real co-play comes in runs,
///   a chance pair is isolated.
///
/// Start is the stronger signal (a recorded game ends when that player is out
/// or leaves, so squad mates can end minutes apart), and map and length are not
/// part of the rule: they added nothing in testing.
///
/// Every game is used once, closest pair first. Three profiles form a trio
/// when each of the three pairs is at least wide.
library;

import '../../models/ranked_match.dart';

const kSharedTightStartSecs = 60;
const kSharedTightEndSecs = 120;
const kSharedWideStartSecs = 180;
const kSharedWideEndSecs = 300;

/// A squad is at most this many players.
const kMaxSquadSize = 3;

/// One game the saved profiles played together: each member's own record of it.
class SharedMatch {
  /// Each member's game, by uid.
  final Map<String, RankedMatch> games;
  const SharedMatch(this.games);

  Iterable<String> get uids => games.keys;
  int get squadSize => games.length;
  bool includes(String uid) => games.containsKey(uid);

  RankedMatch get _first =>
      games.values.reduce((a, b) => b.startTime.isBefore(a.startTime) ? b : a);

  /// When the first of the members started.
  DateTime get start => _first.startTime;
  DateTime get end =>
      games.values.map((m) => m.endTime).reduce((a, b) => b.isAfter(a) ? b : a);

  /// The map as the member who started first recorded it.
  String get mapKey => _first.mapKey;

  /// The longest any member was in the game.
  int get lengthSecs =>
      games.values.map((m) => m.lengthSecs).reduce((a, b) => a > b ? a : b);

  /// How far apart the first and the last member started, and ended, in
  /// seconds.
  int get startSpreadSecs => _spreadSecs(games.values.map((m) => m.startTime));
  int get endSpreadSecs => _spreadSecs(games.values.map((m) => m.endTime));

  /// Whether the members' times are close enough to count on their own, rather
  /// than because the games around this one line up too.
  bool get isClose =>
      startSpreadSecs <= kSharedTightStartSecs &&
      endSpreadSecs <= kSharedTightEndSecs;

  static int _spreadSecs(Iterable<DateTime> times) {
    final first = times.reduce((a, b) => b.isBefore(a) ? b : a);
    final last = times.reduce((a, b) => b.isAfter(a) ? b : a);
    return last.difference(first).inSeconds;
  }
}

bool _within(DateTime a, DateTime b, int secs) =>
    a.difference(b).inMilliseconds.abs() <= secs * 1000;

bool _isTight(RankedMatch a, RankedMatch b) =>
    _within(a.startTime, b.startTime, kSharedTightStartSecs) &&
    _within(a.endTime, b.endTime, kSharedTightEndSecs);

bool _isWide(RankedMatch a, RankedMatch b) =>
    _within(a.startTime, b.startTime, kSharedWideStartSecs) &&
    _within(a.endTime, b.endTime, kSharedWideEndSecs);

/// A game on a profile: its profile's place in the sorted uids, and its place
/// in that profile's games.
typedef _Node = ({int uid, int game});

class _Edge {
  final _Node a;
  final _Node b;
  final int distance;
  const _Edge(this.a, this.b, this.distance);
}

/// The games [byUid] (each profile's games, any order) played together, newest
/// first. Only ranked games that count toward the stats are looked at. A result
/// holds two or three profiles; solo games are left out. Deterministic: the
/// same input always gives the same pairs.
List<SharedMatch> findSharedMatches(Map<String, List<RankedMatch>> byUid) {
  final uids = byUid.keys.toList()..sort();
  final games = [
    for (final uid in uids)
      [
        for (final m in byUid[uid]!)
          if (m.isRanked && m.countsTowardStats) m,
      ]..sort(_byStart),
  ];

  final edges = <_Edge>[];
  for (var i = 0; i < uids.length; i++) {
    for (var j = i + 1; j < uids.length; j++) {
      edges.addAll(_acceptedPairs(i, games[i], j, games[j]));
    }
  }
  // Closest first; the rest of the key only makes ties deterministic.
  edges.sort((x, y) {
    final d = x.distance.compareTo(y.distance);
    if (d != 0) return d;
    final a = _compareNodes(x.a, y.a);
    return a != 0 ? a : _compareNodes(x.b, y.b);
  });

  // Each game is in one group; a group holds one game per profile.
  final groupOf = <_Node, List<_Node>>{};
  for (final e in edges) {
    final ga = groupOf[e.a] ?? [e.a];
    final gb = groupOf[e.b] ?? [e.b];
    if (identical(ga, gb)) continue;
    if (ga.length + gb.length > kMaxSquadSize) continue;
    final fits = [
      for (final x in ga)
        for (final y in gb)
          x.uid != y.uid && _isWide(games[x.uid][x.game], games[y.uid][y.game]),
    ].every((ok) => ok);
    if (!fits) continue;
    final merged = [...ga, ...gb];
    for (final n in merged) {
      groupOf[n] = merged;
    }
  }

  final result = [
    for (final group in groupOf.values.toSet())
      SharedMatch({
        for (final n in (group.toList()..sort((x, y) => x.uid - y.uid)))
          uids[n.uid]: games[n.uid][n.game],
      }),
  ]..sort(_newestFirst);
  return result;
}

/// The pairs between profile [ia] (with [a]) and [ib] (with [b]) that the rule
/// accepts, both lists sorted by start.
List<_Edge> _acceptedPairs(
  int ia,
  List<RankedMatch> a,
  int ib,
  List<RankedMatch> b,
) {
  final out = <_Edge>[];
  var lo = 0;
  for (var x = 0; x < a.length; x++) {
    final from = a[x].startTime.subtract(
      const Duration(seconds: kSharedWideStartSecs),
    );
    // Both lists are sorted, so the window only moves forward.
    while (lo < b.length && b[lo].startTime.isBefore(from)) {
      lo++;
    }
    for (var y = lo; y < b.length; y++) {
      if (b[y].startTime.difference(a[x].startTime).inSeconds >
          kSharedWideStartSecs) {
        break;
      }
      if (!_isWide(a[x], b[y])) continue;
      if (!_isTight(a[x], b[y]) && !_hasWideNeighbour(a, x, b, y)) continue;
      out.add(
        _Edge(
          (uid: ia, game: x),
          (uid: ib, game: y),
          a[x].startTime.difference(b[y].startTime).inSeconds.abs() +
              a[x].endTime.difference(b[y].endTime).inSeconds.abs(),
        ),
      );
    }
  }
  return out;
}

/// Whether the game before, or the game after, on both profiles is a wide pair.
bool _hasWideNeighbour(List<RankedMatch> a, int x, List<RankedMatch> b, int y) {
  final before = x > 0 && y > 0 && _isWide(a[x - 1], b[y - 1]);
  final after =
      x + 1 < a.length && y + 1 < b.length && _isWide(a[x + 1], b[y + 1]);
  return before || after;
}

int _byStart(RankedMatch a, RankedMatch b) {
  final d = a.startTime.compareTo(b.startTime);
  return d != 0 ? d : a.id.compareTo(b.id);
}

int _compareNodes(_Node a, _Node b) {
  final u = a.uid.compareTo(b.uid);
  return u != 0 ? u : a.game.compareTo(b.game);
}

int _newestFirst(SharedMatch a, SharedMatch b) {
  final d = b.start.compareTo(a.start);
  if (d != 0) return d;
  // The same start: the same members in a fixed order.
  return a.uids.join(',').compareTo(b.uids.join(','));
}
