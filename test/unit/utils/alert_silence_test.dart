import 'package:apexlytics/utils/alert_silence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuietHours', () {
    const night = QuietHours(
      enabled: true,
      startMinute: 23 * 60,
      endMinute: 7 * 60,
    );
    const day = QuietHours(
      enabled: true,
      startMinute: 9 * 60,
      endMinute: 17 * 60,
    );

    test('is off until it is switched on, and then covers 11 PM to 7 AM', () {
      expect(QuietHours.off.isActive, isFalse);
      expect(QuietHours.off.containsMinute(0), isFalse);
      const defaults = QuietHours(enabled: true);
      expect(defaults.startMinute, 23 * 60);
      expect(defaults.endMinute, 7 * 60);
    });

    test('a window that runs past midnight covers both sides of it', () {
      expect(night.containsMinute(23 * 60), isTrue);
      expect(night.containsMinute(0), isTrue);
      expect(night.containsMinute(6 * 60 + 59), isTrue);
      expect(night.containsMinute(12 * 60), isFalse);
      expect(night.containsMinute(22 * 60 + 59), isFalse);
    });

    test('the start minute is inside and the end minute is not', () {
      expect(night.containsMinute(7 * 60), isFalse);
      expect(day.containsMinute(9 * 60), isTrue);
      expect(day.containsMinute(17 * 60), isFalse);
      expect(day.containsMinute(8 * 60 + 59), isFalse);
    });

    test('an empty window, or one that is off, silences nothing', () {
      const empty = QuietHours(enabled: true, startMinute: 600, endMinute: 600);
      expect(empty.isActive, isFalse);
      expect(empty.containsMinute(600), isFalse);
      const off = QuietHours(startMinute: 0, endMinute: 1439);
      expect(off.containsMinute(100), isFalse);
    });

    test('covers reads the wall clock of the device at that instant', () {
      // Local clock times, so the test means the same in any time zone.
      expect(night.covers(DateTime(2026, 11, 2, 23, 30)), isTrue);
      expect(night.covers(DateTime(2026, 11, 2, 12, 0)), isFalse);
      // A UTC instant is judged by what the local clock then says.
      final utc = DateTime(2026, 11, 2, 3, 0).toUtc();
      expect(night.covers(utc), isTrue);
    });

    test('has value equality', () {
      expect(const QuietHours(enabled: true), const QuietHours(enabled: true));
      expect(const QuietHours(enabled: true) == const QuietHours(), isFalse);
    });
  });

  group('validMinuteOfDay', () {
    test('accepts 0 to 1439 and nothing else', () {
      expect(validMinuteOfDay(0), 0);
      expect(validMinuteOfDay(1439), 1439);
      expect(validMinuteOfDay(1440), isNull);
      expect(validMinuteOfDay(-1), isNull);
      expect(validMinuteOfDay('600'), isNull);
      expect(validMinuteOfDay(null), isNull);
    });
  });

  group('muteEnd', () {
    test('three hours is three hours', () {
      final now = DateTime(2026, 11, 2, 21, 15);
      expect(muteEnd(MuteChoice.threeHours, now), DateTime(2026, 11, 3, 0, 15));
    });

    test('until tomorrow is the next 6:00 AM on the local clock', () {
      // At night: tomorrow morning.
      expect(
        muteEnd(MuteChoice.untilTomorrow, DateTime(2026, 11, 2, 23, 0)),
        DateTime(2026, 11, 3, 6),
      );
      // In the daytime: tomorrow morning too.
      expect(
        muteEnd(MuteChoice.untilTomorrow, DateTime(2026, 11, 2, 10, 0)),
        DateTime(2026, 11, 3, 6),
      );
      // After midnight but before 6:00 AM: this morning.
      expect(
        muteEnd(MuteChoice.untilTomorrow, DateTime(2026, 11, 3, 2, 0)),
        DateTime(2026, 11, 3, 6),
      );
      // Exactly 6:00 AM: the next one.
      expect(
        muteEnd(MuteChoice.untilTomorrow, DateTime(2026, 11, 3, 6, 0)),
        DateTime(2026, 11, 4, 6),
      );
    });

    test('until tomorrow crosses the end of a month and a year', () {
      expect(
        muteEnd(MuteChoice.untilTomorrow, DateTime(2026, 12, 31, 20, 0)),
        DateTime(2027, 1, 1, 6),
      );
    });
  });

  group('mutes in storage', () {
    final now = DateTime(2026, 11, 2, 12, 0);

    test('a round trip keeps the end of each mute', () {
      final stored = {
        'ranked': DateTime(2026, 11, 2, 15, 0),
        'pubs': DateTime(2026, 11, 3, 6, 0),
      };
      expect(parseMutes(encodeMutes(stored), now), stored);
    });

    test('a mute that has ended is left out', () {
      final json = encodeMutes({
        'ranked': now.subtract(const Duration(minutes: 1)),
        'pubs': now.add(const Duration(minutes: 1)),
      });
      expect(parseMutes(json, now).keys, ['pubs']);
    });

    test('nothing muted stores nothing', () {
      expect(encodeMutes({}), isNull);
      expect(parseMutes(null, now), isEmpty);
      expect(parseMutes('', now), isEmpty);
    });

    test('a damaged value reads as no mute, never an error', () {
      expect(parseMutes('not json', now), isEmpty);
      expect(parseMutes('[1, 2]', now), isEmpty);
      expect(parseMutes('{"ranked": "soon", "pubs": 1.5}', now), isEmpty);
    });
  });

  group('alert payload', () {
    test('keeps the mode and the fire time', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1782090000000);
      final parsed = parseAlertPayload(alertPayload('ranked', at))!;
      expect(parsed.mode, 'ranked');
      expect(parsed.at, at);
    });

    test('an alert from an older version, or a blank one, has none', () {
      expect(parseAlertPayload(null), isNull);
      expect(parseAlertPayload(''), isNull);
      expect(parseAlertPayload('|123'), isNull);
    });

    test('a mode with no readable time is still a mode', () {
      final parsed = parseAlertPayload('pubs|soon')!;
      expect(parsed.mode, 'pubs');
      expect(parsed.at, isNull);
    });
  });

  group('MuteChoice', () {
    test('is found by the action id its button carries', () {
      expect(MuteChoice.fromActionId('mute_3h'), MuteChoice.threeHours);
      expect(
        MuteChoice.fromActionId('mute_tomorrow'),
        MuteChoice.untilTomorrow,
      );
      expect(MuteChoice.fromActionId('open'), isNull);
      expect(MuteChoice.fromActionId(null), isNull);
    });
  });

  group('formatMuteEnd', () {
    test('says the time for today and adds tomorrow for another day', () {
      final now = DateTime(2026, 11, 2, 21, 0);
      expect(
        formatMuteEnd(DateTime(2026, 11, 2, 23, 40), now),
        isNot(contains('tomorrow')),
      );
      expect(
        formatMuteEnd(DateTime(2026, 11, 3, 6, 0), now),
        endsWith('tomorrow'),
      );
    });
  });
}
