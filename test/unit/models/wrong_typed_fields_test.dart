import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/models/news_article.dart';
import 'package:apexlytics/models/player_stats.dart';
import 'package:apexlytics/models/predator.dart';
import 'package:apexlytics/models/server_status.dart';
import 'package:apexlytics/utils/formatting/json_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// One wrongly typed value in a response must read as a missing one, not throw
/// and blank everything built from that response.
void main() {
  group('asInt', () {
    test('reads a number, and a number sent as text', () {
      expect(asInt(1200), 1200);
      expect(asInt(12.9), 12);
      expect(asInt('1200'), 1200);
      expect(asInt(' 1200 '), 1200);
      expect(asInt('12.5'), 12);
    });

    test('reads anything else as absent', () {
      expect(asInt(null), isNull);
      expect(asInt('soon'), isNull);
      expect(asInt(true), isNull);
      expect(asInt(const <int>[]), isNull);
      expect(asInt(double.infinity), isNull);
      expect(asInt(double.nan), isNull);
      expect(asInt('NaN'), isNull);
    });
  });

  test('a map mode with a number sent as text still reads', () {
    final mode = MapMode.fromJson({
      'map': 'Olympus',
      'remainingSecs': '1200',
      'DurationInMinutes': '30',
    });
    expect(mode.remainingSecs, 1200);
    expect(mode.durationMins, 30);
  });

  test('a map mode with wrongly typed fields falls back to its defaults', () {
    final mode = MapMode.fromJson({
      'map': 7,
      'remainingSecs': {'a': 1},
      'remainingMins': 2,
      'asset': false,
      'eventName': 3,
    });
    expect(mode.map, 'Unknown');
    expect(mode.remainingSecs, 120);
    expect(mode.asset, '');
    expect(mode.eventName, isNull);
  });

  test('a server region with wrongly typed fields reads as unknown', () {
    final region = RegionStatus.fromJson({'Status': 1, 'ResponseTime': 'x'});
    expect(region.status, 'UNKNOWN');
    expect(region.responseTime, 0);
  });

  test('a predator cutoff sent as text still reads', () {
    final r = PredatorResponse.fromJson({
      'RP': {
        'PC': {
          'val': '18000',
          'totalMastersAndPreds': [],
          'updateTimestamp': 'never',
        },
      },
    });
    expect(r.forPlatform('PC')?.minRp, 18000);
    expect(r.forPlatform('PC')?.totalMastersAndPreds, 0);
    expect(r.forPlatform('PC')?.updatedAt, isNull);
  });

  test(
    'a news article with wrongly typed fields falls back to its defaults',
    () {
      final a = NewsArticle.fromJson({
        'title': 5,
        'description': null,
        'link': [],
        'img': {},
      });
      expect(a.title, 'No Title');
      expect(a.description, '');
      expect(a.link, '');
      expect(a.imageUrl, '');
    },
  );

  test('a tracker with a wrongly typed name or value still reads', () {
    final stats = PlayerStats.fromJson({
      'global': {'name': 'Player', 'uid': '1', 'platform': 'PC'},
      'legends': {
        'selected': {
          'LegendName': 'Wraith',
          'data': [
            {'name': 12, 'value': '34'},
          ],
        },
      },
    });
    expect(stats.trackers.single.name, '');
    expect(stats.trackers.single.value, 34);
  });

  test('a saved legend with wrongly typed fields still reads', () {
    final legend = LegendStat.fromJson({
      'name': 4,
      'trackers': [
        {'key': 1, 'name': 2, 'value': '9'},
      ],
      'lu': 'yesterday',
    });
    expect(legend.name, '');
    expect(legend.trackers.single.key, '');
    expect(legend.trackers.single.value, 9);
    expect(legend.lastUpdated, isNull);

    expect(
      LegendStat.fromJson({'name': 'W', 'trackers': 'x'}).trackers,
      isEmpty,
    );
    expect(
      LegendStat.fromJson({'name': 'W', 'lu': 1700000000000}).lastUpdated?.year,
      2023,
    );
  });
}
