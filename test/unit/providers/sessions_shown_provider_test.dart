import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/sessions_shown_provider.dart';
import 'package:apexlytics/utils/ranked/performance_insights.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  test('is five until one is picked', () async {
    final (container, _) = await prefsContainer();

    expect(container.read(sessionsShownProvider), kDefaultSessionsShown);
    expect(kDefaultSessionsShown, 5);
  });

  test('comes back as it was saved', () async {
    for (final saved in [...kSessionsShownPresets, kSessionsShownAll]) {
      final (container, _) = await prefsContainer(
        values: {PrefsKeys.trendSessionsShown: saved},
      );

      expect(container.read(sessionsShownProvider), saved);
    }
  });

  test('ignores a saved value that is not one of the counts', () async {
    for (final saved in [7, -1, 100]) {
      final (container, _) = await prefsContainer(
        values: {PrefsKeys.trendSessionsShown: saved},
      );

      expect(container.read(sessionsShownProvider), kDefaultSessionsShown);
    }
  });

  test('picking one changes it and keeps it', () async {
    final (container, prefs) = await prefsContainer();

    await container.read(sessionsShownProvider.notifier).set(25);

    expect(container.read(sessionsShownProvider), 25);
    expect(prefs.getInt(PrefsKeys.trendSessionsShown), 25);
  });

  test('All is kept too', () async {
    final (container, prefs) = await prefsContainer(
      values: {PrefsKeys.trendSessionsShown: 10},
    );

    await container.read(sessionsShownProvider.notifier).set(kSessionsShownAll);

    expect(container.read(sessionsShownProvider), kSessionsShownAll);
    expect(prefs.getInt(PrefsKeys.trendSessionsShown), 0);
  });
}
