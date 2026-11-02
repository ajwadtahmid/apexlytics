import 'dart:io';

import 'package:apexlytics/utils/share_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late Directory shared;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apx_cache_');
    shared = Directory('${tmp.path}/share_plus')..createSync();
    File('${shared.path}/apexlytics_card.png').writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('on Android the share helper\'s copies are removed', () async {
    await clearSharedCardCopies(tempDir: tmp, android: true);

    expect(shared.existsSync(), isFalse);
  });

  test('other things in the cache are left alone', () async {
    final other = File('${tmp.path}/keep.txt')..writeAsStringSync('x');

    await clearSharedCardCopies(tempDir: tmp, android: true);

    expect(other.existsSync(), isTrue);
  });

  test('other platforms are not touched', () async {
    await clearSharedCardCopies(tempDir: tmp, android: false);

    expect(shared.existsSync(), isTrue);
  });

  test('a missing folder is fine', () async {
    shared.deleteSync(recursive: true);

    await clearSharedCardCopies(tempDir: tmp, android: true);
  });
}
