import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/prefs_keys.dart';
import '../utils/storage/auto_backup.dart';
import 'ranked_provider.dart';
import 'settings_provider.dart';

/// Whether automatic copies are on. On until the player switches them off.
final autoBackupEnabledProvider =
    NotifierProvider<AutoBackupEnabledNotifier, bool>(
      AutoBackupEnabledNotifier.new,
    );

class AutoBackupEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => autoBackupEnabled(ref.read(sharedPreferencesProvider));

  Future<void> set(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefsKeys.autoBackupEnabled, enabled);
    state = enabled;
  }
}

/// The automatic copies on the device, newest first.
final autoBackupListProvider = FutureProvider.autoDispose<List<AutoBackupFile>>(
  (ref) async {
    if (!autoBackupSupported) return const [];
    return listAutoBackups(await autoBackupDirectory());
  },
);

/// Makes an automatic copy if one is due, and refreshes the list when one was
/// made. Safe to call at any time: it does nothing when off, not due or already
/// running.
Future<void> runAutoBackupIfDue(WidgetRef ref) async {
  if (!autoBackupSupported) return;
  final made = await runAutoBackup(
    ref.read(sharedPreferencesProvider),
    ref.read(rankedHistoryStoreProvider),
  );
  if (made != null) ref.invalidate(autoBackupListProvider);
}
