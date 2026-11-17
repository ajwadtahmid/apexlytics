import 'dart:io';

import 'package:dio/dio.dart';

import 'package:apexlytics/utils/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendlyError for file system failures', () {
    FileSystemException failure(int? code) => FileSystemException(
      'Cannot create file',
      '/home/someone/Documents/apexlytics_backup.json.gz',
      code == null ? null : OSError('os message', code),
    );

    test('a permission error says to pick another location', () {
      for (final code in [1, 13, 5, 30, 19]) {
        final message = friendlyError(failure(code));
        expect(message, contains('permission'), reason: 'code $code');
        expect(message, contains('different'), reason: 'code $code');
      }
    });

    test('a full disk says so', () {
      for (final code in [28, 112]) {
        expect(
          friendlyError(failure(code)),
          contains('storage space'),
          reason: 'code $code',
        );
      }
    });

    test('any other file error still gets a specific, actionable message', () {
      expect(friendlyError(failure(2)), contains('Try a different location'));
      expect(
        friendlyError(failure(null)),
        contains('Try a different location'),
      );
    });

    test('never includes the path, which can carry the user\'s name', () {
      for (final code in [1, 28, 2, null]) {
        final message = friendlyError(failure(code));
        expect(message, isNot(contains('someone')));
        expect(message, isNot(contains('apexlytics_backup')));
        expect(message, isNot(contains('os message')));
      }
    });
  });

  test('a MalformedResponseException keeps its own message', () {
    expect(
      friendlyError(const MalformedResponseException('Unexpected response.')),
      'Unexpected response.',
    );
  });

  group('isConnectionError', () {
    DioException dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
    );

    test('is true when the device could not reach the server', () {
      expect(isConnectionError(dio(DioExceptionType.connectionError)), isTrue);
      expect(
        isConnectionError(dio(DioExceptionType.connectionTimeout)),
        isTrue,
      );
      expect(isConnectionError(dio(DioExceptionType.receiveTimeout)), isTrue);
    });

    test('is false when the server answered, or for anything else', () {
      expect(isConnectionError(dio(DioExceptionType.badResponse)), isFalse);
      expect(
        isConnectionError(const AppException('Player not found')),
        isFalse,
      );
      expect(isConnectionError(null), isFalse);
    });

    test('recognises the service\'s wrapped version of it too', () {
      expect(
        isConnectionError(
          AppException(friendlyError(dio(DioExceptionType.connectionError))),
        ),
        isTrue,
      );
      expect(
        isConnectionError(
          AppException(friendlyError(dio(DioExceptionType.receiveTimeout))),
        ),
        isTrue,
      );
      // A server's own answer is not.
      expect(
        isConnectionError(const AppException('Rate limit', status: 429)),
        isFalse,
      );
    });
  });
}
