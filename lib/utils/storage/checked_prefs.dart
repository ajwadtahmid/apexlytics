import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when SharedPreferences reports that a write or a remove did not
/// happen. The setters return a `bool` instead of throwing (a full disk on
/// Android's `commit()`, or a caught failure on Linux and Windows), so a
/// caller that ignores it carries on as if the write had landed. Carries a
/// count only: a key can name a player.
class PrefsWriteException implements Exception {
  final int failed;
  const PrefsWriteException([this.failed = 1]);

  @override
  String toString() => 'PrefsWriteException($failed not written)';
}

/// Awaits a write or remove, and throws a [PrefsWriteException] if it did not
/// take.
Future<void> requireWritten(Future<bool> write) async {
  if (!await write) throw const PrefsWriteException();
}

/// Removes every key in [keys], all of them even if one fails, then throws a
/// [PrefsWriteException] naming how many did not go.
Future<void> removeAllChecked(
  SharedPreferences prefs,
  Iterable<String> keys,
) async {
  final results = await Future.wait(keys.map(prefs.remove));
  final failed = results.where((ok) => !ok).length;
  if (failed > 0) throw PrefsWriteException(failed);
}
