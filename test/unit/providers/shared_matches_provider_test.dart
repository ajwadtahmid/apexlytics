import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/providers/ranked_provider.dart';
import 'package:apexlytics/providers/shared_matches_provider.dart';
import 'package:apexlytics/utils/ranked/ranked_period.dart';
import 'package:apexlytics/utils/ranked/shared_matches.dart';
import 'package:apexlytics/utils/storage/ranked_history_store.dart';

import '../../helpers.dart';

void main() {
  const current = 'br_ranked_s29_s2';
  const earlier = 'br_ranked_s29_s1';
  final seasons = {
    earlier: SeasonMeta(
      id: earlier,
      displayName: 'S29 Split 1',
      start: DateTime.utc(2026, 2, 1),
      end: DateTime.utc(2026, 6, 1),
    ),
    current: SeasonMeta(
      id: current,
      displayName: 'S29 Split 2',
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 9, 1),
    ),
  };

  // 2026-06-21, inside the current split; a hundred days before is inside the
  // earlier one.
  const now = 1782090000;
  const hundredDays = 100 * 86400;

  late RankedHistoryStore store;

  setUpAll(useFfiDatabase);

  setUp(() {
    store = RankedHistoryStore(
      overridePath: 'file:squad_games_provider?mode=memory&cache=shared',
    );
  });

  tearDown(() async {
    await store.deleteAll();
    await store.close();
  });

  Future<void> record(String uid, List<int> starts) => store.upsertAll(uid, [
    for (final s in starts) buildMatch(uid: uid, start: s),
  ], seasons: seasons);

  Future<List<SharedMatch>> read(
    String splitId, {
    List<String> saved = const ['a', 'b'],
  }) async {
    final (container, _) = await prefsContainer(
      values: {
        'player_profiles': jsonEncode([
          for (final uid in saved)
            {'name': uid.toUpperCase(), 'uid': uid, 'platform': 'PC'},
        ]),
      },
      overrides: [rankedHistoryStoreProvider.overrideWithValue(store)],
    );
    return container.read(sharedMatchesProvider(splitId).future);
  }

  test('pairs the games the saved profiles recorded in a split', () async {
    await record('a', [now, now + 5000]);
    await record('b', [now + 10, now + 5010, now + 9000]);
    final found = await read(current);
    expect(found, hasLength(2));
    expect(found.every((m) => m.uids.toList().join() == 'ab'), isTrue);
  });

  test('keeps to the split asked for', () async {
    await record('a', [now, now - hundredDays]);
    await record('b', [now + 10, now - hundredDays + 10]);
    expect(await read(current), hasLength(1));
    expect(await read(earlier), hasLength(1));
  });

  test('the Lifetime scope covers every split', () async {
    await record('a', [now, now - hundredDays]);
    await record('b', [now + 10, now - hundredDays + 10]);
    expect(await read(kLifetimeSplitId), hasLength(2));
  });

  test('only matches profiles that are saved', () async {
    await record('a', [now]);
    await record('b', [now + 10]);
    await record('c', [now + 20]);
    final found = await read(current, saved: const ['a', 'b']);
    expect(found, hasLength(1));
    expect(found.single.squadSize, 2);
  });

  test('finds a trio across three saved profiles', () async {
    await record('a', [now]);
    await record('b', [now + 10]);
    await record('c', [now + 20]);
    final found = await read(current, saved: const ['a', 'b', 'c']);
    expect(found.single.squadSize, 3);
  });

  test('gives nothing with one saved profile', () async {
    await record('a', [now]);
    expect(await read(current, saved: const ['a']), isEmpty);
  });
}
