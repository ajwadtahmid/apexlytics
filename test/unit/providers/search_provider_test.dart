import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/search_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/utils/error_messages.dart' show AppException;

import '../../helpers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SearchNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('initializes with empty favorites', () async {
      final state = container.read(searchStateProvider);
      expect(state.favorites, isEmpty);
    });

    test('adds a new favorite', () async {
      const playerRef = PlayerRef(
        query: 'TestPlayer',
        platform: 'PC',
        uid: '123',
      );

      await container
          .read(searchStateProvider.notifier)
          .toggleFavorite(playerRef);

      final state = container.read(searchStateProvider);
      expect(state.favorites, contains(playerRef));
    });

    test('removes a favorite when toggled again', () async {
      const playerRef = PlayerRef(
        query: 'TestPlayer',
        platform: 'PC',
        uid: '123',
      );

      final notifier = container.read(searchStateProvider.notifier);
      await notifier.toggleFavorite(playerRef);
      await notifier.toggleFavorite(playerRef);

      final state = container.read(searchStateProvider);
      expect(state.favorites, isEmpty);
    });

    test(
      'a case-different name+platform match is treated as a duplicate',
      () async {
        const player1 = PlayerRef(query: 'TestPlayer', platform: 'PC');
        const player2 = PlayerRef(query: 'testplayer', platform: 'PC');

        final notifier = container.read(searchStateProvider.notifier);
        await notifier.toggleFavorite(player1);
        await notifier.toggleFavorite(player2);

        expect(container.read(searchStateProvider).favorites, isEmpty);
      },
    );

    test(
      'a name-only entry and a UID entry for the same player dedupe too',
      () async {
        const nameOnly = PlayerRef(query: 'TestPlayer', platform: 'PC');
        const withUid = PlayerRef(
          query: 'TestPlayer',
          platform: 'PC',
          uid: '123',
        );

        final notifier = container.read(searchStateProvider.notifier);
        await notifier.toggleFavorite(nameOnly);
        await notifier.toggleFavorite(withUid);

        expect(container.read(searchStateProvider).favorites, isEmpty);
      },
    );

    test(
      'adding past the cap is refused, keeping every saved favorite',
      () async {
        final notifier = container.read(searchStateProvider.notifier);
        for (var i = 0; i < SearchNotifier.maxFavorites; i++) {
          await notifier.toggleFavorite(
            PlayerRef(query: 'Player$i', platform: 'PC', uid: '$i'),
          );
        }

        await expectLater(
          notifier.toggleFavorite(
            const PlayerRef(query: 'OneTooMany', platform: 'PC', uid: '999'),
          ),
          throwsA(isA<AppException>()),
        );

        final favorites = container.read(searchStateProvider).favorites;
        expect(favorites, hasLength(SearchNotifier.maxFavorites));
        expect(favorites.any((f) => f.uid == '0'), isTrue);
        expect(favorites.any((f) => f.uid == '999'), isFalse);

        // Removing is still allowed at the cap, which frees a slot.
        await notifier.toggleFavorite(
          const PlayerRef(query: 'Player0', platform: 'PC', uid: '0'),
        );
        await notifier.toggleFavorite(
          const PlayerRef(query: 'OneTooMany', platform: 'PC', uid: '999'),
        );
        expect(container.read(searchStateProvider).favorites.first.uid, '999');
      },
    );

    test('deduplicates by UID when both entries have UIDs', () async {
      const player1 = PlayerRef(query: 'OldName', platform: 'PC', uid: '123');
      const player2 = PlayerRef(
        query: 'TestPlayer2',
        platform: 'PC',
        uid: '456',
      );

      final notifier = container.read(searchStateProvider.notifier);
      await notifier.toggleFavorite(player1);
      await notifier.toggleFavorite(player2);

      final state = container.read(searchStateProvider);
      expect(state.favorites, hasLength(2));
      // player2 is inserted at position 0, so it should be first
      expect(state.favorites.first.uid, '456');
      expect(state.favorites.last.uid, '123');
    });

    test('syncs display name for existing favorites', () async {
      const playerRef = PlayerRef(query: 'OldName', platform: 'PC', uid: null);

      final notifier = container.read(searchStateProvider.notifier);
      await notifier.toggleFavorite(playerRef);

      // syncDisplayName matches by name, enriches with UID
      await notifier.syncDisplayName('123', 'OldName');

      final state = container.read(searchStateProvider);
      expect(state.favorites, hasLength(1));
      expect(state.favorites.first.uid, '123');
      expect(state.favorites.first.query, 'OldName');
    });

    test('clears all favorites', () async {
      const playerRef = PlayerRef(
        query: 'TestPlayer',
        platform: 'PC',
        uid: '123',
      );

      final notifier = container.read(searchStateProvider.notifier);
      await notifier.toggleFavorite(playerRef);
      await notifier.clearFavorites();

      final state = container.read(searchStateProvider);
      expect(state.favorites, isEmpty);
    });

    group('removing one favorite', () {
      PlayerRef fav(int n) =>
          PlayerRef(query: 'Player$n', platform: 'PC', uid: '$n');

      List<PlayerRef> saved() => [
        for (final m
            in jsonDecode(prefs.getString(PrefsKeys.searchFavorites)!) as List)
          PlayerRef.fromJson(m as Map<String, dynamic>),
      ];

      Future<SearchNotifier> three() async {
        final notifier = container.read(searchStateProvider.notifier);
        // Each is added first, so the list reads 3, 2, 1.
        for (final n in [1, 2, 3]) {
          await notifier.toggleFavorite(fav(n));
        }
        return notifier;
      }

      test('takes only that one, and keeps that', () async {
        final notifier = await three();

        await notifier.removeFavorite(fav(2));

        expect(container.read(searchStateProvider).favorites, [fav(3), fav(1)]);
        expect(saved(), [fav(3), fav(1)]);
      });

      test('changes the list before the save is done', () async {
        final notifier = await three();

        final saving = notifier.removeFavorite(fav(2));

        expect(container.read(searchStateProvider).favorites, [fav(3), fav(1)]);
        await saving;
      });

      test('does nothing for a player who is not saved', () async {
        final notifier = await three();

        await notifier.removeFavorite(fav(9));

        expect(container.read(searchStateProvider).favorites, hasLength(3));
      });

      test('an undo puts it back where it was', () async {
        final notifier = await three();
        final index = container
            .read(searchStateProvider)
            .favorites
            .indexOf(fav(2));
        await notifier.removeFavorite(fav(2));

        await notifier.restoreFavorite(fav(2), index);

        expect(container.read(searchStateProvider).favorites, [
          fav(3),
          fav(2),
          fav(1),
        ]);
        expect(saved(), [fav(3), fav(2), fav(1)]);
      });

      test('an undo for a player saved again meanwhile adds nothing', () async {
        final notifier = await three();
        await notifier.removeFavorite(fav(2));
        await notifier.toggleFavorite(fav(2));

        await notifier.restoreFavorite(fav(2), 2);

        expect(
          container
              .read(searchStateProvider)
              .favorites
              .where((f) => f == fav(2)),
          hasLength(1),
        );
      });

      test('an undo past the cap is refused', () async {
        final notifier = container.read(searchStateProvider.notifier);
        for (var i = 0; i < SearchNotifier.maxFavorites; i++) {
          await notifier.toggleFavorite(fav(i));
        }
        await notifier.removeFavorite(fav(0));
        await notifier.toggleFavorite(fav(99));

        await expectLater(
          notifier.restoreFavorite(fav(0), 0),
          throwsA(isA<AppException>()),
        );
        expect(
          container.read(searchStateProvider).favorites,
          hasLength(SearchNotifier.maxFavorites),
        );
      });
    });
  });

  group('recent searches', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    PlayerRef player(int n) =>
        PlayerRef(query: 'Player$n', platform: 'PC', uid: '$n');

    test('lists the newest lookup first', () async {
      final notifier = container.read(searchStateProvider.notifier);
      await notifier.recordRecent(player(1));
      await notifier.recordRecent(player(2));

      expect(container.read(searchStateProvider).recents, [
        player(2),
        player(1),
      ]);
    });

    test('looking up the same player again moves them to the top', () async {
      final notifier = container.read(searchStateProvider.notifier);
      await notifier.recordRecent(player(1));
      await notifier.recordRecent(player(2));
      await notifier.recordRecent(
        const PlayerRef(query: 'Renamed', platform: 'PC', uid: '1'),
      );

      final recents = container.read(searchStateProvider).recents;
      expect(recents, hasLength(2));
      expect(recents.first.query, 'Renamed');
    });

    test('keeps only the last five', () async {
      final notifier = container.read(searchStateProvider.notifier);
      for (var i = 1; i <= 8; i++) {
        await notifier.recordRecent(player(i));
      }

      final recents = container.read(searchStateProvider).recents;
      expect(recents, hasLength(SearchNotifier.maxRecents));
      expect(recents.first, player(8));
      expect(recents.last, player(4));
    });

    test('survive a restart, and clear on request', () async {
      await container
          .read(searchStateProvider.notifier)
          .recordRecent(player(1));

      final reopened = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reopened.dispose);
      expect(reopened.read(searchStateProvider).recents, [player(1)]);

      await reopened.read(searchStateProvider.notifier).clearRecents();
      expect(reopened.read(searchStateProvider).recents, isEmpty);
      expect(prefs.containsKey(PrefsKeys.recentSearches), isFalse);
    });

    test('are separate from favourites', () async {
      final notifier = container.read(searchStateProvider.notifier);
      await notifier.recordRecent(player(1));
      await notifier.toggleFavorite(player(1));
      await notifier.clearFavorites();

      final state = container.read(searchStateProvider);
      expect(state.favorites, isEmpty);
      expect(state.recents, [player(1)]);
    });
  });
  group('favorite snapshots', () {
    late ProviderContainer container;
    late SearchNotifier notifier;

    const alpha = PlayerRef(query: 'Alpha', platform: 'PC', uid: '1');

    PlayerSnapshot? kept(String uid) => container
        .read(searchStateProvider)
        .favorites
        .firstWhere((f) => f.uid == uid)
        .snapshot;

    setUp(() {
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      notifier = container.read(searchStateProvider.notifier);
    });

    test('round-trip through the saved JSON', () {
      final ref = alpha.withSnapshot(
        PlayerSnapshot(
          name: 'Alpha',
          rank: 'Master',
          rankScore: 52671,
          savedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
      );

      final back = PlayerRef.fromJson(
        jsonDecode(jsonEncode(ref.toJson())) as Map<String, dynamic>,
      );

      expect(back.snapshot, ref.snapshot);
    });

    test('a favorite saved without one still loads, with none', () {
      final ref = PlayerRef.fromJson({
        'query': 'Alpha',
        'platform': 'PC',
        'uid': '1',
      });

      expect(ref.snapshot, isNull);
      expect(ref.toJson().containsKey('snapshot'), isFalse);
    });

    test('a damaged one reads as none instead of dropping the favorite', () {
      for (final bad in <Object?>[
        'text',
        {'name': 'Alpha'},
        {'name': 'Alpha', 'rank': 'Gold', 'rp': 'x', 'at': 1},
      ]) {
        final ref = PlayerRef.fromJson({
          'query': 'Alpha',
          'platform': 'PC',
          'uid': '1',
          'snapshot': bad,
        });
        expect(ref.query, 'Alpha', reason: '$bad');
        expect(ref.snapshot, isNull, reason: '$bad');
      }
    });

    test('a lookup of a favorite is kept, and saved', () async {
      await notifier.toggleFavorite(alpha);

      await notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1', rank: 'Diamond', rankScore: 11000),
      );

      final snapshot = kept('1')!;
      expect(snapshot.rank, 'Diamond');
      expect(snapshot.rankScore, 11000);
      final saved =
          jsonDecode(prefs.getString(PrefsKeys.searchFavorites)!) as List;
      expect(
        PlayerRef.fromJson(saved.single as Map<String, dynamic>).snapshot,
        snapshot,
      );
    });

    test(
      'is told to listeners, though the favorite is the same player',
      () async {
        await notifier.toggleFavorite(alpha);
        final before = container.read(searchStateProvider);

        await notifier.updateSnapshot(
          'PC',
          buildStats(name: 'Alpha', uid: '1'),
        );

        expect(container.read(searchStateProvider), isNot(before));
      },
    );

    test('a player who is not a favorite is not stored', () async {
      await notifier.toggleFavorite(alpha);

      await notifier.updateSnapshot('PC', buildStats(name: 'Zed', uid: '9'));

      expect(
        prefs.getString(PrefsKeys.searchFavorites),
        isNot(contains('Zed')),
      );
      expect(kept('1'), isNull);
    });

    test('a recent lookup is not given one', () async {
      await notifier.recordRecent(alpha);

      await notifier.updateSnapshot('PC', buildStats(name: 'Alpha', uid: '1'));

      expect(
        container.read(searchStateProvider).recents.single.snapshot,
        isNull,
      );
    });

    test('an older reading never replaces a newer one', () async {
      await notifier.toggleFavorite(alpha);
      final now = DateTime.now();
      await notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1', rankScore: 5000),
        at: now,
      );

      await notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1', rankScore: 4000),
        at: now.subtract(const Duration(days: 2)),
      );

      expect(kept('1')!.rankScore, 5000);

      await notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1', rankScore: 6000),
        at: now.add(const Duration(minutes: 1)),
      );

      expect(kept('1')!.rankScore, 6000);
    });

    test('is found by name for a favorite saved before it had a UID', () async {
      await notifier.toggleFavorite(
        const PlayerRef(query: 'alpha', platform: 'PC'),
      );

      await notifier.updateSnapshot('PC', buildStats(name: 'Alpha', uid: '1'));

      expect(
        container.read(searchStateProvider).favorites.single.snapshot,
        isNotNull,
      );
    });

    test('survives the name being brought up to date', () async {
      await notifier.toggleFavorite(alpha);
      await notifier.updateSnapshot('PC', buildStats(name: 'Alpha', uid: '1'));

      await notifier.syncDisplayName('1', 'AlphaRenamed');

      final favorite = container.read(searchStateProvider).favorites.single;
      expect(favorite.query, 'AlphaRenamed');
      expect(favorite.snapshot, isNotNull);
    });
  });

  group('favorite updates that overlap', () {
    late ProviderContainer container;
    late SearchNotifier notifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      notifier = container.read(searchStateProvider.notifier);
    });

    List<PlayerRef> saved() =>
        (jsonDecode(prefs.getString(PrefsKeys.searchFavorites)!) as List)
            .map((e) => PlayerRef.fromJson(e as Map<String, dynamic>))
            .toList();

    test('a name update and a snapshot update both stay', () async {
      // Saved by name, as before it had a UID.
      await notifier.toggleFavorite(
        const PlayerRef(query: 'Alpha', platform: 'PC'),
      );

      // Both fire from the same result, neither waiting for the other.
      final named = notifier.syncDisplayName('1', 'Alpha');
      final snapshot = notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1'),
      );
      await Future.wait([named, snapshot]);

      for (final favorite in [
        container.read(searchStateProvider).favorites.single,
        saved().single,
      ]) {
        expect(favorite.uid, '1');
        expect(favorite.snapshot, isNotNull);
      }
    });

    test('a favorite removed meanwhile stays removed', () async {
      const alpha = PlayerRef(query: 'Alpha', platform: 'PC', uid: '1');
      await notifier.toggleFavorite(alpha);

      final update = notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1'),
      );
      final removal = notifier.removeFavorite(alpha);
      await Future.wait([update, removal]);

      expect(container.read(searchStateProvider).favorites, isEmpty);
      expect(saved(), isEmpty);
    });

    test('adding one while a snapshot is saved keeps both', () async {
      const alpha = PlayerRef(query: 'Alpha', platform: 'PC', uid: '1');
      const bravo = PlayerRef(query: 'Bravo', platform: 'PC', uid: '2');
      await notifier.toggleFavorite(alpha);

      final update = notifier.updateSnapshot(
        'PC',
        buildStats(name: 'Alpha', uid: '1'),
      );
      final add = notifier.toggleFavorite(bravo);
      await Future.wait([update, add]);

      final favorites = container.read(searchStateProvider).favorites;
      expect(favorites.map((f) => f.uid), unorderedEquals(['1', '2']));
      expect(favorites.firstWhere((f) => f.uid == '1').snapshot, isNotNull);
      expect(saved().map((f) => f.uid), unorderedEquals(['1', '2']));
    });
  });

  group('a damaged entry in a saved list', () {
    ProviderContainer open() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Map<String, Object?> entry(String name, {Object? uid = '1006838015507'}) => {
      'query': name,
      'platform': 'PC',
      'uid': uid,
    };

    test('only that favorite is dropped, and the rest survive a new save', () async {
      await prefs.setString(
        PrefsKeys.searchFavorites,
        jsonEncode([
          entry('One'),
          entry('Bad', uid: 1006838015507), // a number, not a string
          entry('Two', uid: '1006838015508'),
        ]),
      );
      final container = open();

      expect(container.read(searchStateProvider).favorites.map((f) => f.query), [
        'One',
        'Two',
      ]);

      await container
          .read(searchStateProvider.notifier)
          .toggleFavorite(
            const PlayerRef(query: 'Three', platform: 'PC', uid: '1006838015509'),
          );
      final saved = jsonDecode(prefs.getString(PrefsKeys.searchFavorites)!) as List;
      expect(saved.map((e) => (e as Map)['query']), ['Three', 'One', 'Two']);
    });

    test('only that recent search is dropped', () async {
      await prefs.setString(
        PrefsKeys.recentSearches,
        jsonEncode([
          entry('One'),
          {'query': 'Bad', 'platform': 'PC', 'byUid': 'true'},
          entry('Two', uid: '1006838015508'),
        ]),
      );

      expect(open().read(searchStateProvider).recents.map((r) => r.query), [
        'One',
        'Two',
      ]);
    });

    test('a snapshot time that cannot exist drops the snapshot, not the favorite', () async {
      await prefs.setString(
        PrefsKeys.searchFavorites,
        jsonEncode([
          {
            ...entry('One'),
            'snapshot': {'name': 'One', 'rank': 'Gold', 'rp': 5000, 'at': 1e20},
          },
          {
            ...entry('Two', uid: '1006838015508'),
            'snapshot': {'name': 'Two', 'rank': 'Gold', 'rp': 5000, 'at': 1700000000000},
          },
        ]),
      );

      final favorites = open().read(searchStateProvider).favorites;
      expect(favorites.map((f) => f.query), ['One', 'Two']);
      expect(favorites[0].snapshot, isNull);
      expect(favorites[1].snapshot, isNotNull);
    });
  });
}
