import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/prefs_keys.dart';
import '../app_logger.dart';
import 'backup_service.dart';
import 'ranked_history_store.dart';

/// How long the newest automatic copy stands before the next one is made.
const kAutoBackupInterval = Duration(days: 3);

/// How many automatic copies are kept; the oldest goes when a new one is made.
const kAutoBackupKeep = 3;

/// Phones only. A computer's data folder is easy to copy by hand, and its user
/// can export a file to wherever they like.
bool get autoBackupSupported => Platform.isAndroid || Platform.isIOS;

/// Whether the player has left automatic copies on. They are on until switched
/// off.
bool autoBackupEnabled(SharedPreferences prefs) =>
    prefs.getBool(PrefsKeys.autoBackupEnabled) ?? true;

/// When the last automatic copy was made, or null before the first.
DateTime? lastAutoBackupAt(SharedPreferences prefs) {
  final ms = prefs.getInt(PrefsKeys.autoBackupLastAt);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Whether a copy is due at [now]. A last copy dated in the future (the clock
/// was set back) counts as due, or no copy would be made until that date.
bool autoBackupDue(DateTime? last, DateTime now) =>
    last == null ||
    last.isAfter(now) ||
    now.difference(last) >= kAutoBackupInterval;

/// The file name of a copy taken at [at]. Sorts in time order.
String autoBackupName(DateTime at) =>
    'auto_${DateFormat('yyyyMMdd_HHmmss').format(at)}.json.gz';

final _nameShape = RegExp(r'^auto_(\d{8})_(\d{6})\.json\.gz$');

/// When the copy called [name] was taken, or null if it is not one of ours.
DateTime? parseAutoBackupName(String name) {
  final m = _nameShape.firstMatch(name);
  if (m == null) return null;
  final d = m.group(1)!, t = m.group(2)!;
  int part(String digits, int from, int to) =>
      int.parse(digits.substring(from, to));
  final at = DateTime(
    part(d, 0, 4),
    part(d, 4, 6),
    part(d, 6, 8),
    part(t, 0, 2),
    part(t, 2, 4),
    part(t, 4, 6),
  );
  // A month 13 or hour 25 rolls over instead of failing; that is not a copy.
  return autoBackupName(at) == name ? at : null;
}

/// One automatic copy on the device.
class AutoBackupFile {
  final File file;
  final DateTime takenAt;
  final int bytes;

  const AutoBackupFile({
    required this.file,
    required this.takenAt,
    required this.bytes,
  });
}

/// The folder the copies live in, inside the app's private storage.
Future<Directory> autoBackupDirectory() async => Directory(
  p.join((await getApplicationSupportDirectory()).path, 'auto_backups'),
);

/// The copies in [directory], newest first. Anything else in it is left alone.
Future<List<AutoBackupFile>> listAutoBackups(Directory directory) async {
  if (!await directory.exists()) return const [];
  final found = <AutoBackupFile>[];
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final at = parseAutoBackupName(p.basename(entity.path));
    if (at == null) continue;
    found.add(
      AutoBackupFile(file: entity, takenAt: at, bytes: await entity.length()),
    );
  }
  found.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  return found;
}

/// Deletes every automatic copy and the folder. Used by "Clear all data".
Future<void> deleteAutoBackups(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
}

bool _running = false;
DateTime? _lastFailure;

/// A failed attempt is not tried again for this long, so a full disk does not
/// rebuild the whole history on every return to the app.
const _retryAfterFailure = Duration(hours: 1);

@visibleForTesting
void resetAutoBackupAttempts() {
  _running = false;
  _lastFailure = null;
}

/// Makes an automatic copy if one is due, keeps the newest [kAutoBackupKeep]
/// and returns the new file, or null when nothing was made.
///
/// A copy is written under a temporary name, read back as a restore would read
/// it and only then renamed into place, so a bad write can never replace a
/// good copy. Never throws: a failure is logged without any path or name.
///
/// [force] makes one now, switched on or not (the copy taken just before a
/// restore). [directory] and [now] are for tests.
Future<AutoBackupFile?> runAutoBackup(
  SharedPreferences prefs,
  RankedHistoryStore store, {
  bool force = false,
  Directory? directory,
  DateTime? now,
}) async {
  if (_running) return null;
  final at = now ?? DateTime.now();
  if (!force) {
    if (!autoBackupEnabled(prefs)) return null;
    if (!autoBackupDue(lastAutoBackupAt(prefs), at)) return null;
    final failed = _lastFailure;
    if (failed != null && at.difference(failed) < _retryAfterFailure) {
      return null;
    }
  }
  _running = true;
  File? temp;
  try {
    // Nothing worth keeping on a fresh install.
    if (!force &&
        await store.countStartedSince(null) == 0 &&
        !_hasProfiles(prefs)) {
      return null;
    }
    final dir = directory ?? await autoBackupDirectory();
    await dir.create(recursive: true);
    // What an interrupted write left behind; nothing else is writing here.
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        await entity.delete();
      }
    }

    final (:bytes, :matchCount) = await buildBackup(prefs, rankedStore: store);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final name = autoBackupName(at);
    temp = File(p.join(dir.path, '$name.tmp'));
    await temp.writeAsBytes(data, flush: true);

    final readBack = await Isolate.run(() => verifyBackupBytes(data));
    if (readBack != matchCount) {
      throw StateError('read back $readBack matches, wrote $matchCount');
    }
    final saved = await temp.rename(p.join(dir.path, name));
    temp = null;
    await prefs.setInt(PrefsKeys.autoBackupLastAt, at.millisecondsSinceEpoch);
    _lastFailure = null;

    final copies = await listAutoBackups(dir);
    for (final old in copies.skip(kAutoBackupKeep)) {
      try {
        await old.file.delete();
      } on FileSystemException {
        // Tried again with the next copy.
      }
    }
    log.i('Automatic backup: $matchCount matches, ${data.length} bytes');
    return AutoBackupFile(file: saved, takenAt: at, bytes: data.length);
  } catch (e) {
    _lastFailure = at;
    // The type only: a file error's text carries a path.
    log.w('Automatic backup failed (${e.runtimeType})');
    return null;
  } finally {
    _running = false;
    try {
      if (temp != null && await temp.exists()) await temp.delete();
    } catch (_) {
      // A leftover .tmp is ignored by the list and swept by the next run.
    }
  }
}

bool _hasProfiles(SharedPreferences prefs) {
  final raw = prefs.getString(PrefsKeys.profiles);
  if (raw == null) return false;
  try {
    final decoded = jsonDecode(raw);
    return decoded is List && decoded.isNotEmpty;
  } on FormatException {
    return false;
  }
}
