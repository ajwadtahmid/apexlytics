import 'package:flutter_test/flutter_test.dart';
import 'package:apexlytics/models/season_meta.dart';

void main() {
  group('SeasonMeta.fromJson with a time DateTime cannot hold', () {
    Map<String, dynamic> entry(Object? start, Object? end) => {
      'id': 'br_ranked_s30_s2',
      'start': start,
      'end': end,
    };

    test('is skipped, not thrown', () {
      expect(SeasonMeta.fromJson(entry(1e20, 1782000000000)), isNull);
      expect(SeasonMeta.fromJson(entry(1782000000000, -1e20)), isNull);
      expect(SeasonMeta.fromJson(entry(double.infinity, 1782000000000)), isNull);
      expect(SeasonMeta.fromJson(entry(double.nan, 1782000000000)), isNull);
    });

    test('a normal entry still reads', () {
      expect(SeasonMeta.fromJson(entry(1780000000000, 1790000000000)), isNotNull);
    });
  });

  group('SeasonMeta.fromApi displayName', () {
    test('formats a well-formed split id', () {
      final season = SeasonMeta.fromApi(
        id: 'br_ranked_s30_s2',
        startSeconds: 0,
        endSeconds: 1,
      );
      expect(season.displayName, 'Season 30 (Split 2)');
    });

    test(
      'falls back to "Other" for a non-split id, instead of leaking the '
      'raw upstream string (e.g. the API\'s "__other__" placeholder season)',
      () {
        final season = SeasonMeta.fromApi(
          id: '__other__',
          startSeconds: 0,
          endSeconds: 1,
        );
        expect(season.displayName, 'Other');
      },
    );

    test('fromJson applies the same fallback on reload', () {
      final season = SeasonMeta.fromJson({
        'id': '__other__',
        'start': 0,
        'end': 1000,
      });
      expect(season!.displayName, 'Other');
    });
  });
}
