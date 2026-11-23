import 'package:apexlytics/widgets/uid_search_toggle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lookupLengthProblem', () {
    test('accepts a UID of up to 20 digits and rejects a longer one', () {
      expect(lookupLengthProblem('1' * 20, byUid: true), isNull);
      expect(lookupLengthProblem('1' * 21, byUid: true), isNotNull);
    });

    test('accepts a name of up to 64 characters and rejects a longer one', () {
      expect(lookupLengthProblem('a' * 64, byUid: false), isNull);
      expect(lookupLengthProblem('a' * 65, byUid: false), isNotNull);
    });

    test('does not apply the name limit to a UID, or the reverse', () {
      expect(lookupLengthProblem('1' * 30, byUid: false), isNull);
      expect(lookupLengthProblem('a' * 15, byUid: true), isNull);
    });
  });
}
