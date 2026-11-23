import 'package:apexlytics/constants/api_constants.dart';
import 'package:apexlytics/services/api_service.dart';
import 'package:apexlytics/services/map_service.dart';
import 'package:apexlytics/utils/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  Map<String, dynamic> mode(String map) => {
    'map': map,
    'remainingSecs': 3000,
    'remainingTimer': '00:50:00',
    'DurationInMinutes': 90,
    'asset': '',
  };

  Map<String, dynamic> rotation() => {
    'battle_royale': {'current': mode('Olympus'), 'next': mode('Storm Point')},
    'ranked': {'current': mode('Broken Moon'), 'next': mode('E-District')},
  };

  group('parseMapRotation', () {
    test('reads a real rotation', () {
      final parsed = parseMapRotation(rotation());
      expect(parsed.rankedCurrent.map, 'Broken Moon');
      expect(parsed.battleRoyaleCurrent.map, 'Olympus');
    });

    test('reads a rotation that has only one of the two blocks', () {
      final parsed = parseMapRotation({'ranked': rotation()['ranked']});
      expect(parsed.rankedNext.map, 'E-District');
    });

    // Each of these used to come back as a rotation with every mode unknown,
    // which cancelled every alert and stopped the refresh loop.
    for (final entry in <String, Object?>{
      "the upstream's own error object": {'Error': 'Rate limited'},
      'an empty object': <String, dynamic>{},
      'a reply wrapped by the client': {'_raw': '<html>Sign in</html>'},
      'a lower-case error object': {
        'error': 'x',
        'ranked': <String, dynamic>{},
      },
      'a list': <dynamic>[],
      'nothing': null,
    }.entries) {
      test('refuses ${entry.key}', () {
        expect(
          () => parseMapRotation(entry.value),
          throwsA(isA<MalformedResponseException>()),
        );
      });
    }
  });

  test('getMapRotation fails on a reply that is not a rotation', () async {
    final api = MockApiService();
    when(
      () => api.get(
        ApiConstants.mapRotationPath,
        params: any(named: 'params'),
        noCache: any(named: 'noCache'),
      ),
    ).thenAnswer((_) async => const ApiResult({'Error': 'Rate limited'}));

    await expectLater(
      MapService(api).getMapRotation(),
      throwsA(isA<MalformedResponseException>()),
    );
  });
}
