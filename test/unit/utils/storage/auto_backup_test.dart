import 'dart:convert';
import 'dart:io';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/utils/storage/auto_backup.dart';
import 'package:apexlytics/utils/storage/backup_service.dart';
import 'package:apexlytics/utils/storage/ranked_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers.dart';

void main() {
  setUpAll(useFfiDatabase);

  const uid = '1006838015507';
  final day1 = DateTime(2026, 11, 1, 9, 40);

  group('names', () {
    test('a name reads back as the time it was made', () {
      final at = DateTime(2026, 11, 3, 9, 40, 5);
      expect(autoBackupName(at), 'auto_20261103_094005.json.gz');
      expect(parseAutoBackupName(autoBackupName(at)), at);
    });

    test('names that are not ours are not copies', () {
      expect(parseAutoBackupName('apexlytics_20261103_094005.json.gz'), isNull);
      expect(parseAutoBackupName('auto_20261103_094005.json.gz.tmp'), isNull);
      expect(parseAutoBackupName('auto_20261399_094005.json.gz'), isNull);
      expect(parseAutoBackupName('notes.txt'), isNull);
    });
  });

  group('when one is due', () {
    test('the first one is, then not until three days have passed', () {
      expect(autoBackupDue(null, day1), isTrue);
      expect(
        autoBackupDue(day1, day1.add(const Duration(days: 2, hours: 23))),
        isFalse,
      );
      expect(autoBackupDue(day1, day1.add(const Duration(days: 3))), isTrue);
    });

    test('a last copy dated in the future does not wait for that date', () {
      expect(autoBackupDue(day1.add(const Duration(days: 30)), day1), isTrue);
    });

    test('is on until switched off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(autoBackupEnabled(prefs), isTrue);
      await prefs.setBool(PrefsKeys.autoBackupEnabled, false);
      expect(autoBackupEnabled(prefs), isFalse);
    });
  });

  group('making copies', () {
    late Directory dir;
    late SharedPreferences prefs;
    late RankedHistoryStore store;

    setUp(() async {
      resetAutoBackupAttempts();
      dir = Directory.systemTemp.createTempSync('auto_backup_test');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RankedHistoryStore(overridePath: inMemoryDatabasePath);
      addTearDown(store.close);
      await store.deleteAll();
    });

    Future<void> addGame() =>
        store.upsertAll(uid, [buildMatch(uid: uid, start: 1000)]);

    Future<AutoBackupFile?> run(DateTime at, {bool force = false}) =>
        runAutoBackup(prefs, store, directory: dir, now: at, force: force);

    test('writes a copy that restores, and records when', () async {
      await addGame();
      final made = await run(day1);

      expect(made, isNotNull);
      expect(p.basename(made!.file.path), autoBackupName(day1));
      expect(lastAutoBackupAt(prefs), day1);
      final bytes = await made.file.readAsBytes();
      expect(verifyBackupBytes(bytes), 1);
      final copies = await listAutoBackups(dir);
      expect(copies.map((c) => c.takenAt), [day1]);
      expect(copies.single.bytes, bytes.length);
    });

    test('keeps the newest three and drops the oldest', () async {
      await addGame();
      final times = [
        for (var i = 0; i < 5; i++) day1.add(Duration(days: 3 * i)),
      ];
      for (final t in times) {
        expect(await run(t), isNotNull);
      }
      final kept = await listAutoBackups(dir);
      expect(kept.map((c) => c.takenAt), times.reversed.take(3));
    });

    test('does nothing before three days, or when switched off', () async {
      await addGame();
      await run(day1);
      expect(await run(day1.add(const Duration(days: 2))), isNull);
      expect(await listAutoBackups(dir), hasLength(1));

      await prefs.setBool(PrefsKeys.autoBackupEnabled, false);
      expect(await run(day1.add(const Duration(days: 9))), isNull);
      expect(await listAutoBackups(dir), hasLength(1));
    });

    test(
      'makes none on a fresh install, but does once there is a game',
      () async {
        expect(await run(day1), isNull);
        expect(await listAutoBackups(dir), isEmpty);

        await addGame();
        expect(await run(day1), isNotNull);
      },
    );

    test('a saved profile alone is worth a copy', () async {
      await prefs.setString(
        PrefsKeys.profiles,
        jsonEncode([
          {'name': 'Test', 'uid': uid, 'platform': 'PC'},
        ]),
      );
      expect(await run(day1), isNotNull);
    });

    test('a forced copy ignores the schedule and the switch', () async {
      await addGame();
      await run(day1);
      await prefs.setBool(PrefsKeys.autoBackupEnabled, false);
      final forced = await run(day1.add(const Duration(hours: 1)), force: true);
      expect(forced, isNotNull);
      expect(await listAutoBackups(dir), hasLength(2));
    });

    test(
      'a failure is quiet, keeps the old copies and waits before retrying',
      () async {
        await addGame();
        await run(day1);
        final later = day1.add(const Duration(days: 4));

        // A file where the folder should be, so the write cannot happen.
        final blocked = File(p.join(dir.path, 'blocked'))
          ..writeAsStringSync('x');
        final failed = await runAutoBackup(
          prefs,
          store,
          directory: Directory(blocked.path),
          now: later,
        );
        expect(failed, isNull);
        expect(lastAutoBackupAt(prefs), day1);
        expect(await listAutoBackups(dir), hasLength(1));

        // Not tried again within the hour, even though a copy is due.
        expect(await run(later.add(const Duration(minutes: 30))), isNull);
        expect(await run(later.add(const Duration(hours: 2))), isNotNull);
      },
    );

    test('sweeps a temporary file an interrupted write left behind', () async {
      await addGame();
      final stale = File(p.join(dir.path, '${autoBackupName(day1)}.tmp'))
        ..writeAsStringSync('partial');
      await run(day1.add(const Duration(days: 1)));
      expect(stale.existsSync(), isFalse);
    });

    test('lists only its own files, newest first', () async {
      await addGame();
      await run(day1);
      await run(day1.add(const Duration(days: 3)));
      File(p.join(dir.path, 'notes.txt')).writeAsStringSync('x');
      final copies = await listAutoBackups(dir);
      expect(copies, hasLength(2));
      expect(copies.first.takenAt.isAfter(copies.last.takenAt), isTrue);
    });

    test('deleting removes the folder and every copy', () async {
      await addGame();
      await run(day1);
      await deleteAutoBackups(dir);
      expect(dir.existsSync(), isFalse);
      expect(await listAutoBackups(dir), isEmpty);
    });

    test(
      'a copy previews like a picked file and restores its history',
      () async {
        await addGame();
        final made = (await run(day1))!;

        final result = await previewBackupFile(made.file, rankedStore: store);
        expect(result, isA<PreviewReady>());
        final preview = (result as PreviewReady).preview;
        expect(preview.matchCount, 1);
        expect(preview.newMatchCount, 0);

        await store.deleteAll();
        final restored = await commitBackupImport(
          preview,
          prefs,
          rankedStore: store,
        );
        expect(restored, isA<ImportSuccess>());
        expect(await store.count(uid), 1);
      },
    );

    test('a damaged copy is refused with a message, not an error', () async {
      final bad = File(p.join(dir.path, autoBackupName(day1)))
        ..writeAsBytesSync([0x1F, 0x8B, 1, 2, 3]);
      final result = await previewBackupFile(bad);
      expect(result, isA<PreviewError>());
    });
  });
}
