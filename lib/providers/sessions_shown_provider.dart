import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/prefs_keys.dart';
import '../utils/ranked/performance_insights.dart';
import 'settings_provider.dart' show sharedPreferencesProvider;

/// How many of the latest sessions the Performance Trends page looks at, as the
/// player last chose it: one of [kSessionsShownPresets], or [kSessionsShownAll].
/// Kept between visits. A choice too big for the sessions on screen is
/// narrowed when it is used (see [resolveSessionsShown]), not when it is saved,
/// so it applies again when there are enough sessions.
final sessionsShownProvider = NotifierProvider<SessionsShownNotifier, int>(
  SessionsShownNotifier.new,
);

class SessionsShownNotifier extends Notifier<int> {
  @override
  int build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getInt(PrefsKeys.trendSessionsShown);
    final known =
        saved == kSessionsShownAll ||
        (saved != null && kSessionsShownPresets.contains(saved));
    return known ? saved! : kDefaultSessionsShown;
  }

  /// Picks [window] and keeps it.
  Future<void> set(int window) async {
    state = window;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(PrefsKeys.trendSessionsShown, window);
  }
}
