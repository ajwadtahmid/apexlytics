import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/services/background_service.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fake_notification_plugin.dart';

MapMode _mode(String map, {int secs = 3600}) =>
    MapMode(map: map, remainingSecs: secs, durationMins: 60, asset: '');

MapRotation _rotation() => MapRotation(
  battleRoyaleCurrent: _mode('Olympus'),
  battleRoyaleNext: _mode("World's Edge"),
  rankedCurrent: _mode('Kings Canyon'),
  rankedNext: _mode('Storm Point'),
);

/// Whether any desktop timer is waiting with an id from [base] to base + 11.
bool _hasBlock(int base) => NotificationService.pendingDesktopAlertIds.any(
  (id) => id >= base && id < base + 12,
);

void main() {
  late FakeNotificationPlugin plugin;

  setUp(() {
    plugin = FakeNotificationPlugin();
    NotificationService.useFakePlugin(plugin);
  });

  tearDown(() async {
    await NotificationService.cancelAll();
  });

  Future<void> armRankedAndPubs() => NotificationService.scheduleAll(
    _rotation(),
    notifyRanked: true,
    rankedMinutesBefore: 10,
    notifyPubs: true,
    pubsMinutesBefore: 10,
  );

  group('cancelling one mode', () {
    test('removes that mode\'s alerts and leaves the others armed', () async {
      await armRankedAndPubs();
      expect(_hasBlock(NotificationService.rankedIdBase), isTrue);
      expect(_hasBlock(NotificationService.pubsIdBase), isTrue);

      await NotificationService.cancelMode(NotificationService.rankedIdBase);

      expect(_hasBlock(NotificationService.rankedIdBase), isFalse);
      expect(_hasBlock(NotificationService.pubsIdBase), isTrue);
    });

    test('asks the system to drop each id in the mode\'s block', () async {
      await NotificationService.cancelMode(NotificationService.pubsIdBase);

      expect(plugin.cancelled, [
        for (var i = 0; i < 12; i++) NotificationService.pubsIdBase + i,
      ]);
      expect(plugin.cancelAllCalls, 0);
    });
  });

  group('planning from a fetch that was in flight', () {
    Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test('plans the alerts that are on now', () async {
      final prefs = await prefsWith({
        PrefsKeys.notifyRankedMapRotation: true,
        PrefsKeys.rankedNotifyMinutes: 10,
      });

      expect(await scheduleFetchedRotation(prefs, _rotation()), isTrue);
      expect(_hasBlock(NotificationService.rankedIdBase), isTrue);
    });

    test('cancels instead when the alerts were turned off meanwhile', () async {
      final prefs = await prefsWith({
        PrefsKeys.notifyRankedMapRotation: true,
        PrefsKeys.rankedNotifyMinutes: 10,
      });
      await armRankedAndPubs();
      // The user switches Ranked off while the request is out.
      await prefs.setBool(PrefsKeys.notifyRankedMapRotation, false);

      expect(await scheduleFetchedRotation(prefs, _rotation()), isFalse);
      expect(NotificationService.pendingDesktopAlertIds, isEmpty);
      expect(plugin.cancelAllCalls, greaterThan(0));
    });

    test('cancels instead after all data was cleared meanwhile', () async {
      final prefs = await prefsWith({
        PrefsKeys.notifyPubsMapRotation: true,
        PrefsKeys.pubsNotifyMinutes: 15,
      });
      await armRankedAndPubs();
      await prefs.clear();

      expect(await scheduleFetchedRotation(prefs, _rotation()), isFalse);
      expect(NotificationService.pendingDesktopAlertIds, isEmpty);
    });
  });

  group('on a computer', () {
    test('planning again leaves alerts already shown alone', () async {
      await armRankedAndPubs();
      await armRankedAndPubs();

      // Only the timers are replaced; closing shown alerts is cancelAll's job.
      expect(plugin.cancelAllCalls, 0);
      expect(_hasBlock(NotificationService.rankedIdBase), isTrue);
    });

    test('turning everything off still clears the plugin', () async {
      await armRankedAndPubs();
      await NotificationService.cancelAll();

      expect(plugin.cancelAllCalls, 1);
      expect(NotificationService.pendingDesktopAlertIds, isEmpty);
    });

    test('an alert is dropped once it fires over a minute late', () {
      final at = DateTime.utc(2026, 11, 2, 14, 45);

      expect(NotificationService.desktopAlertIsLate(at, at), isFalse);
      expect(
        NotificationService.desktopAlertIsLate(
          at,
          at.add(NotificationService.desktopLateMargin),
        ),
        isFalse,
      );
      expect(
        NotificationService.desktopAlertIsLate(
          at,
          at.add(const Duration(minutes: 30)),
        ),
        isTrue,
      );
    });
  });
}
