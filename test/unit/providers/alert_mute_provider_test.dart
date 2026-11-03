import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/alert_mute_provider.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:apexlytics/utils/alert_silence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  final soon = DateTime.now().add(const Duration(hours: 2));

  test(
    'starts with the mutes still in force, and none after they end',
    () async {
      final (container, _) = await prefsContainer(
        values: {
          PrefsKeys.alertMuteUntil: encodeMutes({
            'ranked': soon,
            'pubs': DateTime.now().subtract(const Duration(minutes: 1)),
          })!,
        },
      );
      expect(container.read(alertMuteProvider).keys, ['ranked']);
    },
  );

  test('is empty when nothing was ever muted', () async {
    final (container, _) = await prefsContainer();
    expect(container.read(alertMuteProvider), isEmpty);
  });

  test('unmute ends one mode and keeps the others', () async {
    final (container, prefs) = await prefsContainer(
      values: {
        PrefsKeys.alertMuteUntil: encodeMutes({'ranked': soon, 'pubs': soon})!,
      },
    );
    await container.read(alertMuteProvider.notifier).unmute('ranked');
    expect(container.read(alertMuteProvider).keys, ['pubs']);
    expect(
      parseMutes(
        prefs.getString(PrefsKeys.alertMuteUntil),
        DateTime.now(),
      ).keys,
      ['pubs'],
    );
  });

  test('unmuting the last mode removes the stored value', () async {
    final (container, prefs) = await prefsContainer(
      values: {
        PrefsKeys.alertMuteUntil: encodeMutes({'ranked': soon})!,
      },
    );
    await container.read(alertMuteProvider.notifier).unmute('ranked');
    expect(container.read(alertMuteProvider), isEmpty);
    expect(prefs.containsKey(PrefsKeys.alertMuteUntil), isFalse);
  });

  test(
    'refresh picks up a mute written since, as the background does',
    () async {
      final (container, prefs) = await prefsContainer();
      expect(container.read(alertMuteProvider), isEmpty);
      await prefs.setString(
        PrefsKeys.alertMuteUntil,
        encodeMutes({'wildcard': soon})!,
      );
      await container.read(alertMuteProvider.notifier).refresh();
      expect(container.read(alertMuteProvider).keys, ['wildcard']);
    },
  );

  test('a mute reported by the service shows up without a resume', () async {
    final (container, prefs) = await prefsContainer();
    container.read(alertMuteProvider);
    await prefs.setString(
      PrefsKeys.alertMuteUntil,
      encodeMutes({'pubs': soon})!,
    );
    NotificationService.muteChanges.value++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(alertMuteProvider).keys, ['pubs']);
  });
}
