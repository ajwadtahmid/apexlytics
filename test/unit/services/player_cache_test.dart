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
      isolatedApiService(
        FakeHttpAdapter({'/player/uid': (_) => body, '/player': (_) => body}),
      ),
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

  group('a reply that is not an object', () {
    const signInPage = '<html>Sign in to the network</html>';

    test('is a connection problem, not an unknown player', () async {
      body = signInPage;

      await expectLater(
        service.getPlayerStatsByUid(uid, 'PC'),
        throwsA(
          isA<MalformedResponseException>().having(
            (e) => e.status,
            'status',
            isNull,
          ),
        ),
      );
    });

    test('is the same for a lookup by name', () async {
      body = signInPage;

      await expectLater(
        service.getPlayerStats('Player1', 'PC'),
        throwsA(isA<MalformedResponseException>()),
      );
    });

    test('serves the last copy of the player, marked stale', () async {
      await service.getPlayerStatsByUid(uid, 'PC');
      body = signInPage;

      final result = await service.getPlayerStatsByUid(uid, 'PC');

      expect(result.data.name, 'Player1');
      expect(result.staleAt, isNotNull);
    });
  });
}
