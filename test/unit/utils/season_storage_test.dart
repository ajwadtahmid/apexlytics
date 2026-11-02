import 'dart:convert';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/season_meta.dart';
import 'package:apexlytics/utils/storage/season_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SeasonMeta season(String id) => SeasonMeta.fromApi(
    id: id,
    startSeconds: 1_780_000_000,
    endSeconds: 1_790_000_000,
  );

  group('SeasonMeta.isSplitId', () {
    test('accepts real split ids', () {
      expect(SeasonMeta.isSplitId('br_ranked_s29_s1'), isTrue);
      expect(SeasonMeta.isSplitId('br_ranked_s30_s2'), isTrue);
    });

    test('rejects placeholders and the unknown bucket', () {
      expect(SeasonMeta.isSplitId('__other__'), isFalse);
      expect(SeasonMeta.isSplitId('__unknown__'), isFalse);
      expect(SeasonMeta.isSplitId(''), isFalse);
    });
  });

  group('one corrupt window among good ones', () {
    String history() => jsonEncode([
      season('br_ranked_s29_s1').toJson(),
      {'id': 'br_ranked_s29_s2', 'start': 1e20, 'end': 1790000000000},
      season('br_ranked_s30_s1').toJson(),
    ]);

    test('is skipped on read, and the others stay', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.seasonHistory: history()});
      final prefs = await SharedPreferences.getInstance();

      expect(loadAllSeasonsSync(prefs).keys, [
        'br_ranked_s29_s1',
        'br_ranked_s30_s1',
      ]);
    });

    test('is skipped in a restore, and the others are merged', () {
      final merged = mergeRestoredSeasonHistory(backupRaw: history());

      final ids = [for (final e in jsonDecode(merged) as List) (e as Map)['id']];
      expect(ids, ['br_ranked_s29_s1', 'br_ranked_s30_s1']);
    });
  });

  group('season history never stores a placeholder season', () {
    // Its window can overlap the real split's, and a match classified under
    // it would never move to the real one.
    test('upsertSeason ignores a placeholder id', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await upsertSeason(season('__other__'), prefs), isFalse);
      expect(loadAllSeasonsSync(prefs), isEmpty);

      expect(await upsertSeason(season('br_ranked_s29_s1'), prefs), isTrue);
      expect(loadAllSeasonsSync(prefs).keys, ['br_ranked_s29_s1']);
    });

    test('upsertSeason refuses a window that is not believable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      SeasonMeta window(DateTime start, DateTime end) => SeasonMeta(
        id: 'br_ranked_s29_s1',
        displayName: 'S29',
        start: start,
        end: end,
      );

      // Start of 0 (a missing value), reversed, empty, and far too long.
      expect(
        await upsertSeason(
          window(DateTime.fromMillisecondsSinceEpoch(0), DateTime.utc(2026, 9)),
          prefs,
        ),
        isFalse,
      );
      expect(
        await upsertSeason(
          window(DateTime.utc(2026, 9), DateTime.utc(2026, 6)),
          prefs,
        ),
        isFalse,
      );
      expect(
        await upsertSeason(
          window(DateTime.utc(2026, 6), DateTime.utc(2026, 6)),
          prefs,
        ),
        isFalse,
      );
      expect(loadAllSeasonsSync(prefs), isEmpty);

      // A real split of about three months is stored.
      expect(
        await upsertSeason(
          window(DateTime.utc(2026, 6), DateTime.utc(2026, 9)),
          prefs,
        ),
        isTrue,
      );
    });

    test('a placeholder stored by an older build is dropped on read', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.seasonHistory: jsonEncode([
          season('__other__').toJson(),
          season('br_ranked_s29_s1').toJson(),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      expect(loadAllSeasonsSync(prefs).keys, ['br_ranked_s29_s1']);
    });
  });
}
