import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/services/background_service.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fake_notification_plugin.dart';
import 'package:apexlytics/utils/alert_silence.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  group('muting from an alert', () {
    PendingNotificationRequest armed(int id, String mode, DateTime at) =>
        PendingNotificationRequest(
          id,
          'Apexlytics',
          'body',
          alertPayload(mode, at),
        );

    final now = DateTime(2026, 11, 2, 21, 0);

    Future<SharedPreferences> prefs([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test(
      'cancels that mode\'s alerts due before the mute ends, and no others',
      () async {
        plugin.pending.addAll([
          armed(
            100,
            'ranked',
            now.add(const Duration(hours: 1)),
          ), // inside the 3 h
          armed(101, 'ranked', now.add(const Duration(hours: 2))), // inside
          armed(
            102,
            'ranked',
            now.add(const Duration(hours: 4)),
          ), // after: stays
          armed(120, 'pubs', now.add(const Duration(hours: 1))), // another mode
        ]);
        final p = await prefs();

        final end = await NotificationService.muteMode(
          p,
          'ranked',
          MuteChoice.threeHours,
          now,
        );

        expect(end, now.add(const Duration(hours: 3)));
        expect(plugin.cancelled, [100, 101]);
        expect(parseMutes(p.getString(PrefsKeys.alertMuteUntil), now).keys, [
          'ranked',
        ]);
      },
    );

    test(
      'an alert armed by an older version, with no time, is cancelled too',
      () async {
        plugin.pending.add(
          const PendingNotificationRequest(103, 'Apexlytics', 'b', null),
        );
        await NotificationService.muteMode(
          await prefs(),
          'ranked',
          MuteChoice.threeHours,
          now,
        );
        expect(plugin.cancelled, [103]);
      },
    );

    test('a shorter mute never cuts a longer one short', () async {
      final longer = DateTime(2026, 11, 3, 6);
      final p = await prefs({
        PrefsKeys.alertMuteUntil: encodeMutes({'ranked': longer})!,
      });
      final end = await NotificationService.muteMode(
        p,
        'ranked',
        MuteChoice.threeHours,
        now,
      );
      expect(end, longer);
    });

    test('muting one mode leaves another\'s mute alone', () async {
      final p = await prefs();
      await NotificationService.muteMode(
        p,
        'ranked',
        MuteChoice.threeHours,
        now,
      );
      await NotificationService.muteMode(
        p,
        'pubs',
        MuteChoice.untilTomorrow,
        now,
      );
      expect(
        parseMutes(p.getString(PrefsKeys.alertMuteUntil), now).keys,
        unorderedEquals(['ranked', 'pubs']),
      );
    });

    test(
      'a mute is followed by a quiet confirmation with an Undo button',
      () async {
        final p = await prefs();

        final end = await NotificationService.muteMode(
          p,
          'ranked',
          MuteChoice.untilTomorrow,
          now,
        );

        final (id, body, payload) = plugin.shown.single;
        expect(id, 10);
        expect(body, 'Ranked alerts muted until ${formatMuteEnd(end!, now)}.');
        expect(parseAlertPayload(payload)!.mode, 'ranked');
        final actions = plugin.shownDetails.single!.android!.actions!;
        expect(actions.map((a) => a.id), ['unmute']);
        expect(actions.single.title, 'Undo');
      },
    );

    test(
      'each mode has its own confirmation, named as the app names it',
      () async {
        final p = await prefs();
        for (final mode in ['ranked', 'pubs', 'mixtape', 'wildcard']) {
          await NotificationService.muteMode(
            p,
            mode,
            MuteChoice.threeHours,
            now,
          );
        }
        expect(plugin.shown.map((s) => s.$1), [10, 11, 12, 13]);
        expect(plugin.shown.map((s) => s.$2!.split(' alerts').first), [
          'Ranked',
          'Pubs',
          'Mixtape',
          'Wildcards',
        ]);
      },
    );

    test('a mode nobody knows gets no confirmation', () async {
      await NotificationService.muteMode(
        await prefs(),
        'arenas',
        MuteChoice.threeHours,
        now,
      );
      expect(plugin.shown, isEmpty);
    });

    test(
      'Undo ends that mute, keeps the others and plans the alerts again',
      () async {
        final p = await prefs({
          PrefsKeys.alertMuteUntil: encodeMutes({
            'ranked': DateTime.now().add(const Duration(hours: 2)),
            'pubs': DateTime.now().add(const Duration(hours: 2)),
          })!,
        });
        var replanned = 0;
        final original = NotificationService.replanner;
        addTearDown(() => NotificationService.replanner = original);
        NotificationService.replanner = () async => replanned++;
        final before = NotificationService.muteChanges.value;

        await NotificationService.handleResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'unmute',
            payload: alertPayload('ranked', DateTime.now()),
          ),
        );

        expect(
          parseMutes(
            p.getString(PrefsKeys.alertMuteUntil),
            DateTime.now(),
          ).keys,
          ['pubs'],
        );
        expect(replanned, 1);
        expect(NotificationService.muteChanges.value, before + 1);
      },
    );

    test('Undo on the last mute removes the stored value', () async {
      final p = await prefs({
        PrefsKeys.alertMuteUntil: encodeMutes({
          'ranked': DateTime.now().add(const Duration(hours: 2)),
        })!,
      });
      await NotificationService.unmuteMode(p, 'ranked');
      expect(p.containsKey(PrefsKeys.alertMuteUntil), isFalse);
    });

    test('a mode nobody knows is ignored', () async {
      final p = await prefs();
      expect(
        await NotificationService.muteMode(
          p,
          'arenas',
          MuteChoice.threeHours,
          now,
        ),
        isNull,
      );
      expect(p.getString(PrefsKeys.alertMuteUntil), isNull);
    });

    test('the button press does it, and tells the app', () async {
      final p = await prefs();
      final before = NotificationService.muteChanges.value;
      await NotificationService.handleResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'mute_tomorrow',
          payload: alertPayload('wildcard', DateTime.now()),
        ),
      );
      final stored = await SharedPreferences.getInstance();
      await stored.reload();
      expect(
        parseMutes(
          stored.getString(PrefsKeys.alertMuteUntil),
          DateTime.now(),
        ).keys,
        ['wildcard'],
      );
      expect(NotificationService.muteChanges.value, before + 1);
      expect(p, isNotNull);
    });

    test(
      'tapping the alert itself, or an alert with no mode, mutes nothing',
      () async {
        final p = await prefs();
        await NotificationService.handleResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: alertPayload('ranked', DateTime.now()),
          ),
        );
        await NotificationService.handleResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'mute_3h',
          ),
        );
        expect(p.getString(PrefsKeys.alertMuteUntil), isNull);
      },
    );
  });

  group('the test alert', () {
    test(
      'has the mute buttons, and a payload that names no real mode',
      () async {
        expect(await NotificationService.sendTestAlert(), TestAlertResult.sent);

        final (id, _, payload) = plugin.shown.single;
        expect(id, inInclusiveRange(1, 9));
        expect(parseAlertPayload(payload)!.mode, 'test');
        final actions = plugin.shownDetails.single!.android!.actions!;
        expect(actions.map((a) => a.id), ['mute_3h', 'mute_tomorrow']);
      },
    );

    test('pressing a button answers, and mutes nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      plugin.pending.add(
        PendingNotificationRequest(
          100,
          'Apexlytics',
          'b',
          alertPayload('ranked', DateTime.now().add(const Duration(hours: 1))),
        ),
      );

      await NotificationService.handleResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'mute_tomorrow',
          payload: alertPayload('test', DateTime.now()),
        ),
      );

      expect(prefs.getString(PrefsKeys.alertMuteUntil), isNull);
      expect(plugin.cancelled, isEmpty);
      final (_, body, _) = plugin.shown.single;
      expect(
        body,
        allOf(contains('Until tomorrow'), contains('Nothing was muted')),
      );
    });
  });

  group('planning from a background fetch', () {
    test('leaves out a mode that is muted, and keeps the others', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.notifyRankedMapRotation: true,
        PrefsKeys.rankedNotifyMinutes: 10,
        PrefsKeys.notifyPubsMapRotation: true,
        PrefsKeys.pubsNotifyMinutes: 10,
        PrefsKeys.alertMuteUntil: encodeMutes({
          'ranked': DateTime.now().add(const Duration(days: 2)),
        })!,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await scheduleFetchedRotation(prefs, _rotation()), isTrue);

      expect(_hasBlock(NotificationService.rankedIdBase), isFalse);
      expect(_hasBlock(NotificationService.pubsIdBase), isTrue);
    });
  });

  group('planning with a mute and quiet hours', () {
    test('a mode that is muted arms nothing before the mute ends', () async {
      await NotificationService.scheduleAll(
        _rotation(),
        notifyRanked: true,
        rankedMinutesBefore: 10,
        notifyPubs: true,
        pubsMinutesBefore: 10,
        mutedUntil: {'ranked': DateTime.now().add(const Duration(days: 2))},
      );
      expect(_hasBlock(NotificationService.rankedIdBase), isFalse);
      expect(_hasBlock(NotificationService.pubsIdBase), isTrue);
    });
  });
}
