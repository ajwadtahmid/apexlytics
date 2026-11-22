import 'package:flutter_test/flutter_test.dart';

import 'package:apexlytics/models/ranked_match.dart';
import 'package:apexlytics/utils/ranked/shared_matches.dart';

import '../../helpers.dart';

void main() {
  const base = 1782090000;

  /// A ranked game for [uid] starting [at] seconds after the base time and
  /// lasting [length] seconds.
  RankedMatch game(
    String uid,
    int at, {
    int length = 600,
    int rp = 10,
    String gameMode = 'BATTLE_ROYALE',
    bool excluded = false,
  }) => buildMatch(
    uid: uid,
    start: base + at,
    length: length,
    rp: rp,
    gameMode: gameMode,
    excluded: excluded,
  );

  List<SharedMatch> find(Map<String, List<RankedMatch>> byUid) =>
      findSharedMatches(byUid);

  group('a tight pair', () {
    test('is accepted on its own', () {
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 30, length: 640)],
      });
      expect(found, hasLength(1));
      expect(found.single.uids, ['a', 'b']);
      expect(found.single.isClose, isTrue);
    });

    test('holds at exactly 60 s apart in start and 120 s in end', () {
      // b starts 60 s later and lasts 60 s longer: it ends 120 s later.
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 60, length: 660)],
      });
      expect(found, hasLength(1));
      expect(found.single.isClose, isTrue);
    });

    test('is rejected a second past the tight start and needs a run', () {
      expect(
        find({
          'a': [game('a', 0)],
          'b': [game('b', 61)],
        }),
        isEmpty,
      );
    });
  });

  group('a wide pair', () {
    // Starts 100 s apart: outside tight, inside wide.
    List<RankedMatch> a(List<int> at) => [for (final t in at) game('a', t)];
    List<RankedMatch> b(List<int> at) => [
      for (final t in at) game('b', t + 100),
    ];

    test('is rejected on its own', () {
      expect(
        find({
          'a': a([0]),
          'b': b([0]),
        }),
        isEmpty,
      );
    });

    test('is accepted when the next games on both pair up too', () {
      final found = find({
        'a': a([0, 1000]),
        'b': b([0, 1000]),
      });
      expect(found, hasLength(2));
      expect(found.every((m) => !m.isClose), isTrue);
    });

    test('is accepted through the game before, and an isolated one is not', () {
      final found = find({
        'a': a([0, 1000, 3000]),
        'b': b([0, 1000]),
      });
      // The run of two pairs up; a's third game has no partner.
      expect(found, hasLength(2));
      expect(
        found.every((m) => m.start.isBefore(game('a', 2000).startTime)),
        isTrue,
      );
    });

    test('is rejected when only one profile has a neighbour', () {
      expect(
        find({
          'a': a([0, 1000]),
          'b': b([0]),
        }),
        isEmpty,
      );
    });

    test('is rejected when the neighbours are far apart', () {
      expect(
        find({
          'a': a([0, 1000]),
          'b': [game('b', 100), game('b', 1400)],
        }),
        isEmpty,
      );
    });

    test('is rejected just outside the wide bounds, even in a run', () {
      // 181 s apart in start.
      expect(
        find({
          'a': [game('a', 0), game('a', 1000)],
          'b': [game('b', 181), game('b', 1181)],
        }),
        isEmpty,
      );
      // Starts 100 s apart, but b lasts longer: the ends are 301 s apart.
      expect(
        find({
          'a': [game('a', 0), game('a', 1000)],
          'b': [game('b', 100, length: 801), game('b', 1100, length: 801)],
        }),
        isEmpty,
      );
    });
  });

  group('pairing', () {
    test('uses each game once, the closest pair first', () {
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 40), game('b', 10)],
      });
      expect(found, hasLength(1));
      final a = found.single.games['a']!;
      final b = found.single.games['b']!;
      expect(b.startTime.difference(a.startTime).inSeconds, 10);
    });

    test('leaves solo games out', () {
      final found = find({
        'a': [game('a', 0), game('a', 5000)],
        'b': [game('b', 10)],
      });
      expect(found, hasLength(1));
    });

    test('gives the same pairs whatever the order of the games', () {
      final a = [
        for (final t in [0, 1000, 2000, 3000]) game('a', t),
      ];
      final b = [
        for (final t in [20, 1030, 2090, 3010]) game('b', t),
      ];
      final forward = find({'a': a, 'b': b});
      final shuffled = find({
        'b': b.reversed.toList(),
        'a': [a[2], a[0], a[3], a[1]],
      });
      expect(forward, hasLength(4));
      expect(shuffled.map((m) => m.start), forward.map((m) => m.start));
    });

    test('lists the newest first', () {
      final found = find({
        'a': [game('a', 0), game('a', 5000), game('a', 9000)],
        'b': [game('b', 5), game('b', 5003), game('b', 9002)],
      });
      final starts = found.map((m) => m.start).toList();
      expect(starts, hasLength(3));
      expect(starts, [...starts]..sort((x, y) => y.compareTo(x)));
    });
  });

  group('games that are left out', () {
    test('a game excluded from the stats does not pair', () {
      expect(
        find({
          'a': [game('a', 0)],
          'b': [game('b', 10, excluded: true)],
        }),
        isEmpty,
      );
    });

    test('a game with no RP change (not ranked) does not pair', () {
      expect(
        find({
          'a': [game('a', 0)],
          'b': [game('b', 10, rp: 0)],
        }),
        isEmpty,
      );
    });

    test('a game outside Battle Royale does not pair', () {
      expect(
        find({
          'a': [game('a', 0)],
          'b': [game('b', 10, gameMode: 'UNKNOWN')],
        }),
        isEmpty,
      );
    });

    test('nothing to pair gives nothing', () {
      expect(find({}), isEmpty);
      expect(find({'a': []}), isEmpty);
      expect(find({'a': [], 'b': []}), isEmpty);
      expect(
        find({
          'a': [game('a', 0)],
        }),
        isEmpty,
      );
    });
  });

  group('a trio', () {
    test('forms when all three pair up', () {
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 20)],
        'c': [game('c', 45)],
      });
      expect(found, hasLength(1));
      expect(found.single.squadSize, 3);
      expect(found.single.uids, ['a', 'b', 'c']);
    });

    test('is a duo when the other two are not a pair themselves', () {
      // b and c each pair with a (170 s apart, in a run), but they start 340 s
      // apart from each other, so the three are not one game.
      final found = find({
        'a': [game('a', 0), game('a', 1000)],
        'b': [game('b', -170), game('b', 830)],
        'c': [game('c', 170), game('c', 1170)],
      });
      expect(found, hasLength(2));
      expect(found.every((m) => m.squadSize == 2), isTrue);
    });

    test('never holds more than three profiles', () {
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 5)],
        'c': [game('c', 10)],
        'd': [game('d', 15)],
      });
      expect(found, hasLength(1));
      expect(found.single.squadSize, 3);
    });

    test('a duo and a trio on different games stay apart', () {
      final found = find({
        'a': [game('a', 0), game('a', 5000)],
        'b': [game('b', 10), game('b', 5010)],
        'c': [game('c', 20)],
      });
      expect(found.map((m) => m.squadSize), [2, 3]);
    });
  });

  group('SharedMatch', () {
    test('reports when and how far apart the members were', () {
      final found = find({
        'a': [game('a', 0)],
        'b': [game('b', 50, length: 650)],
      }).single;
      expect(found.start, game('a', 0).startTime);
      expect(found.startSpreadSecs, 50);
      expect(found.endSpreadSecs, 100);
      expect(found.lengthSecs, 650);
      expect(found.isClose, isTrue);
      expect(found.includes('b'), isTrue);
      expect(found.includes('z'), isFalse);
    });
  });
}
