import 'dart:convert';

import 'package:apexlytics/providers/api_provider.dart';
import 'package:apexlytics/models/player_stats.dart';
import 'package:apexlytics/providers/player_provider.dart';
import 'package:apexlytics/services/api_service.dart';
import 'package:apexlytics/services/player_service.dart';
import 'package:apexlytics/utils/error_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers.dart';

class MockPlayerService extends Mock implements PlayerService {}

void main() {
  final savedAt = DateTime(2026, 11, 2, 9);
  late MockPlayerService service;
  late ProviderContainer container;

  setUp(() async {
    service = MockPlayerService();
    // A copy still inside its lifetime, as the cache reads it back.
    when(
      () => service.getCachedStats(
        'uid123',
        'PC',
        searchByUid: true,
        allowStale: any(named: 'allowStale'),
      ),
    ).thenReturn(ApiResult(buildStats(rankScore: 1000), staleAt: savedAt));
    final (c, _) = await prefsContainer(
      values: {
        'player_profiles': jsonEncode([
          {'name': 'TestPlayer', 'uid': 'uid123', 'platform': 'PC'},
        ]),
      },
      overrides: [playerServiceProvider.overrideWithValue(service)],
    );
    container = c;
  });

  // After the test has said how the refresh goes: reading starts it.
  Future<ApiResult<PlayerStats?>> open() {
    container.listen(myPlayerStatsProvider, (_, _) {});
    return container.read(myPlayerStatsProvider.future);
  }

  // A refresh that answers a moment after the cached copy is shown, as a real
  // request does.
  Future<T> later<T>(T Function() answer) =>
      Future.delayed(const Duration(milliseconds: 5), answer);

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  group('a copy from the cache', () {
    test(
      'is shown with no "last synced" mark while the refresh runs',
      () async {
        when(
          () => service.getPlayerStatsByUid('uid123', 'PC'),
        ).thenAnswer((_) => Future.any<ApiResult<PlayerStats>>([]));

        final shown = await open();

        expect(shown.staleAt, isNull);
        expect(shown.data?.rankScore, 1000);
      },
    );

    test('is replaced by the fresh answer when it lands', () async {
      when(
        () => service.getPlayerStatsByUid('uid123', 'PC'),
      ).thenAnswer((_) => later(() => ApiResult(buildStats(rankScore: 1100))));

      await open();
      await settle();

      final now = container.read(myPlayerStatsProvider).requireValue;
      expect(now.data?.rankScore, 1100);
      expect(now.staleAt, isNull);
    });

    test('gets the mark only if the refresh fails', () async {
      when(() => service.getPlayerStatsByUid('uid123', 'PC')).thenAnswer(
        (_) => later<ApiResult<PlayerStats>>(
          () => throw const AppException('Player not found.', status: 404),
        ),
      );

      await open();
      await settle();

      final now = container.read(myPlayerStatsProvider).requireValue;
      expect(now.data?.rankScore, 1000);
      expect(now.staleAt, savedAt);
    });

    test('keeps the mark a failed refresh falls back with', () async {
      final fallbackAt = DateTime(2026, 11, 1, 20);
      when(() => service.getPlayerStatsByUid('uid123', 'PC')).thenAnswer(
        (_) => later(
          () => ApiResult(buildStats(rankScore: 1000), staleAt: fallbackAt),
        ),
      );

      await open();
      await settle();

      expect(
        container.read(myPlayerStatsProvider).requireValue.staleAt,
        fallbackAt,
      );
    });
  });

  group('adoptCached', () {
    test('shows what the cache holds without sending a request', () async {
      when(
        () => service.getPlayerStatsByUid('uid123', 'PC'),
      ).thenAnswer((_) async => ApiResult(buildStats(rankScore: 1000)));
      await open();
      await settle();
      clearInteractions(service);

      // A run elsewhere fetched and saved a newer copy.
      when(
        () => service.getCachedStats(
          'uid123',
          'PC',
          searchByUid: true,
          allowStale: any(named: 'allowStale'),
        ),
      ).thenReturn(ApiResult(buildStats(rankScore: 1250), staleAt: savedAt));
      container.read(myPlayerStatsProvider.notifier).adoptCached();
      await settle();

      final now = container.read(myPlayerStatsProvider).requireValue;
      expect(now.data?.rankScore, 1250);
      expect(now.staleAt, isNull);
      verifyNever(() => service.getPlayerStatsByUid(any(), any()));
    });
  });
}
