import 'dart:async';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/services/background_service.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fake_notification_plugin.dart';

MapMode _mode(String map) =>
    MapMode(map: map, remainingSecs: 3600, durationMins: 60, asset: '');

MapRotation _rotation() => MapRotation(
  battleRoyaleCurrent: _mode('Olympus'),
  battleRoyaleNext: _mode("World's Edge"),
  rankedCurrent: _mode('Kings Canyon'),
  rankedNext: _mode('Storm Point'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'com.transistorsoft/flutter_background_fetch/methods',
  );
  late FakeNotificationPlugin plugin;
  late List<String> finished;

  setUp(() {
    plugin = FakeNotificationPlugin();
    NotificationService.useFakePlugin(plugin);
    finished = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'finish') finished.add(call.arguments as String);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  });

  tearDown(() => NotificationService.cancelAll());

  Future<SharedPreferences> alertsOn() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.notifyRankedMapRotation: true,
      PrefsKeys.rankedNotifyMinutes: 10,
    });
    return SharedPreferences.getInstance();
  }

  test('a run the OS timed out plans nothing and keeps the failure', () async {
    final prefs = await alertsOn();
    final reply = Completer<MapRotation>();

    final run = runBackgroundFetch(fetch: () => reply.future);
    await Future<void>.delayed(Duration.zero);
    await onBackgroundTaskTimeout('task');
    reply.complete(_rotation());
    await run;
    await prefs.reload();

    expect(prefs.getString(PrefsKeys.bgFetchLastResult), startsWith('error:'));
    expect(
      NotificationService.pendingDesktopAlertIds,
      isEmpty,
      reason: 'a timed-out run must not arm alerts',
    );
    expect(finished, ['task']);
  });

  test('a run that is not timed out still plans and records ok', () async {
    final prefs = await alertsOn();

    await runBackgroundFetch(fetch: () async => _rotation());
    await prefs.reload();

    expect(prefs.getString(PrefsKeys.bgFetchLastResult), startsWith('ok:'));
    expect(NotificationService.pendingDesktopAlertIds, isNotEmpty);
  });

  test('a task is handed back to the OS only once', () async {
    await alertsOn();

    await onBackgroundTaskTimeout('again');
    await onBackgroundTaskTimeout('again');

    expect(finished, ['again']);
  });
}
