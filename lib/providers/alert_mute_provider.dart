import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/prefs_keys.dart';
import '../services/notification_service.dart';
import '../utils/alert_silence.dart';
import 'settings_provider.dart' show sharedPreferencesProvider;

/// The modes muted from an alert's button, by `MapAlertMode.name`, with when each
/// mute ends. A mute is pressed in the notification shade, often while the app
/// is closed, so the value is read from prefs again on resume and whenever the
/// service reports a change; an entry drops out by itself when it ends.
final alertMuteProvider =
    NotifierProvider<AlertMuteNotifier, Map<String, DateTime>>(
      AlertMuteNotifier.new,
    );

class AlertMuteNotifier extends Notifier<Map<String, DateTime>> {
  Timer? _expiry;

  @override
  Map<String, DateTime> build() {
    NotificationService.muteChanges.addListener(refresh);
    ref.onDispose(() {
      NotificationService.muteChanges.removeListener(refresh);
      _expiry?.cancel();
    });
    return _read();
  }

  Map<String, DateTime> _read() {
    final mutes = parseMutes(
      ref.read(sharedPreferencesProvider).getString(PrefsKeys.alertMuteUntil),
      DateTime.now(),
    );
    _armExpiry(mutes);
    return mutes;
  }

  /// Shows the mute ending by itself, without waiting for something else to
  /// rebuild Home.
  void _armExpiry(Map<String, DateTime> mutes) {
    _expiry?.cancel();
    if (mutes.isEmpty) return;
    final soonest = mutes.values.reduce((a, b) => a.isBefore(b) ? a : b);
    _expiry = Timer(
      soonest.difference(DateTime.now()) + const Duration(seconds: 1),
      () => state = _read(),
    );
  }

  /// Reads the mutes again from storage, which the background isolate may have
  /// changed since this one last looked.
  Future<void> refresh() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    state = _read();
  }

  /// Ends [mode]'s mute now. The caller plans the alerts again.
  Future<void> unmute(String mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    final mutes = {
      ...parseMutes(prefs.getString(PrefsKeys.alertMuteUntil), DateTime.now()),
    }..remove(mode);
    final encoded = encodeMutes(mutes);
    if (encoded == null) {
      await prefs.remove(PrefsKeys.alertMuteUntil);
    } else {
      await prefs.setString(PrefsKeys.alertMuteUntil, encoded);
    }
    state = _read();
  }
}
