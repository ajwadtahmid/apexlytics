import 'package:apexlytics/services/player_service.dart';
import 'package:apexlytics/utils/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

void main() {
  setUpAll(useFfiDatabase);

  const uid = '1006838015507';
  final goodBody = <String, dynamic>{
    'global': {
      'name': 'Player1',
      'uid': uid,
      'level': 100,
      'rank': {'rankName': 'Platinum', 'rankScore': 8000},
      'platform': 'PC',
    },
    'realtime': {'isOnline': 0, 'isInGame': 0},
    'legends': {
      'selected': {'LegendName': 'Wraith', 'data': []},
      'all': <String, dynamic>{},
    },
  };

  late Object body;
  late PlayerService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    body = goodBody;
    service = PlayerService(
      isolatedApiService(FakeHttpAdapter({'/player/uid': (_) => body})),
    );
  });

  Future<void> fetchExpectingNotFound() => expectLater(
    service.getPlayerStatsByUid(uid, 'PC'),
    throwsA(isA<AppException>()),
  );

  test('a good player body is kept as the offline copy', () async {
    await service.getPlayerStatsByUid(uid, 'PC');

    final cached = service.getCachedStats(
      uid,
      'PC',
      searchByUid: true,
      allowStale: true,
    );
    expect(cached?.data.name, 'Player1');
  });

  test('a body that is not a player does not replace the good copy', () async {
    await service.getPlayerStatsByUid(uid, 'PC');

    for (final bad in <Object>[
      <String, dynamic>{},
      {'something': 'else'},
      {
        'global': {'name': 'Nobody'},
      },
    ]) {
      body = bad;
      await fetchExpectingNotFound();
    }

    final cached = service.getCachedStats(
      uid,
      'PC',
      searchByUid: true,
      allowStale: true,
    );
    expect(cached?.data.name, 'Player1');
    expect(cached?.data.rankScore, 8000);
  });
}
