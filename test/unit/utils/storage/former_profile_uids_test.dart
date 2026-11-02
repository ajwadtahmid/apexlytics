import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/utils/storage/former_profile_uids.dart';
import 'package:apexlytics/utils/formatting/snapshot_types.dart';
import 'package:apexlytics/utils/storage/ranked_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const a = '1006838015507';
  const b = '1006838015508';
  const c = '1006838015509';

  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('the former profile list', () {
    test('reads only strings and ignores anything else', () {
      expect(parseFormerProfileUids(null), isEmpty);
      expect(parseFormerProfileUids('not json'), isEmpty);
      expect(parseFormerProfileUids('{"a":1}'), isEmpty);
      expect(parseFormerProfileUids('["$a", 5, null, "", "$b"]'), {a, b});
    });

    test('remembering adds to what is there and keeps it', () async {
      final prefs = await prefsWith();

      await rememberProfileUids(prefs, [a]);
      await rememberProfileUids(prefs, [b, '']);

      expect(loadFormerProfileUids(prefs), {a, b});
    });

    test('remembering nothing new writes nothing', () async {
      final prefs = await prefsWith();
      await rememberProfileUids(prefs, [a]);
      final before = prefs.getString(PrefsKeys.formerProfileUids);

      await rememberProfileUids(prefs, [a]);

      expect(prefs.getString(PrefsKeys.formerProfileUids), before);
    });

    test(
      'retaining keeps only the given UIDs, and none removes the key',
      () async {
        final prefs = await prefsWith();
        await rememberProfileUids(prefs, [a, b, c]);

        await retainProfileUids(prefs, {a, c});
        expect(loadFormerProfileUids(prefs), {a, c});

        await retainProfileUids(prefs, {});
        expect(prefs.containsKey(PrefsKeys.formerProfileUids), isFalse);
      },
    );

    test('a restore joins the backup\'s list to the device\'s', () {
      final merged = mergeRestoredFormerProfileUids(
        backupRaw: '["$a", "$b"]',
        deviceRaw: '["$b", "$c"]',
      );

      expect(parseFormerProfileUids(merged), {a, b, c});
    });

    test('a restore with an unreadable list keeps the device\'s', () {
      final merged = mergeRestoredFormerProfileUids(
        backupRaw: 'garbage',
        deviceRaw: '["$a"]',
      );

      expect(parseFormerProfileUids(merged), {a});
    });

    test('the list is capped', () {
      final many = [for (var i = 0; i < 500; i++) '${1000000000000 + i}'];
      final merged = mergeRestoredFormerProfileUids(
        backupRaw: '[${many.map((u) => '"$u"').join(',')}]',
        deviceRaw: null,
      );

      expect(parseFormerProfileUids(merged).length, kMaxFormerProfileUids);
    });
  });

  group('the launch trim', () {
    test('a removed profile with only old RP readings keeps them', () async {
      final prefs = await prefsWith();
      final store = RankedHistoryStore(overridePath: inMemoryDatabasePath);
      addTearDown(store.close);
      await store.deleteAll();
      final old = DateTime.now().subtract(const Duration(days: 200));
      for (final uid in [a, b]) {
        await store.appendSnapshotFor(
          uid,
          StatSnapshot(timestamp: old, rp: 1200),
        );
      }
      // A is saved as a profile, then removed; B was only ever looked up.
      await rememberProfileUids(prefs, [a]);

      final protect = await profileUidsToProtect(prefs, {});
      await store.pruneSnapshots(profileUids: protect, favoriteUids: {});

      expect(await store.snapshotCount(a), 1);
      expect(await store.snapshotCount(b), 0);
    });

    test(
      'a profile saved before the list existed is added at launch',
      () async {
        final prefs = await prefsWith();

        final protect = await profileUidsToProtect(prefs, {a});

        expect(protect, {a});
        expect(loadFormerProfileUids(prefs), {a});
      },
    );
  });

  group('player-scoped prefs keys', () {
    test('the UID is read from each shape, and only from those', () {
      expect(uidOfScopedKey(PrefsKeys.snapshotKeyFor(a)), a);
      expect(uidOfScopedKey(PrefsKeys.legendStatsKeyFor(a)), a);
      expect(uidOfScopedKey(PrefsKeys.legendVisitStackKeyFor(a)), a);
      expect(uidOfScopedKey(PrefsKeys.rankGoalKeyFor(a)), a);
      expect(
        uidOfScopedKey(PrefsKeys.rankGoalKeyForSplit(a, 'br_ranked_s1_s1')),
        a,
      );
      expect(uidOfScopedKey(PrefsKeys.gamesNextSync(a)), a);
      expect(uidOfScopedKey(PrefsKeys.gamesLastOutcome(a)), a);

      // The legacy global keys and ordinary settings carry no UID.
      expect(uidOfScopedKey(PrefsKeys.statSnapshots), isNull);
      expect(uidOfScopedKey(PrefsKeys.legendStats), isNull);
      expect(uidOfScopedKey(PrefsKeys.profiles), isNull);
      expect(uidOfScopedKey('legend_stats_sort'), isNull);
    });

    test('keys of everyone but the kept players are listed', () async {
      final prefs = await prefsWith({
        PrefsKeys.snapshotKeyFor(a): '[]',
        PrefsKeys.legendStatsKeyFor(b): '{}',
        PrefsKeys.rankGoalKeyForSplit(b, 'br_ranked_s1_s1'): 3,
        PrefsKeys.profiles: '[]',
      });

      expect(
        scopedKeysExcept(prefs, {a}),
        unorderedEquals([
          PrefsKeys.legendStatsKeyFor(b),
          PrefsKeys.rankGoalKeyForSplit(b, 'br_ranked_s1_s1'),
        ]),
      );
      expect(scopedKeysExcept(prefs, {a, b}), isEmpty);
    });
  });
}
