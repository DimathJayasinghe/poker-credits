import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Folder for the Microsoft Store listing screenshots. Unset in every normal run, which then skips
/// the tests that make them: `STORE_SHOTS_DIR=$PWD/../packaging/windows/store/screenshots fvm flutter test test/store`
/// (docs/MICROSOFT_STORE.md).
final String? storeShotsDir = Platform.environment['STORE_SHOTS_DIR'];

/// The size of a Store screenshot: Partner Center takes 1366 x 768 up to 3840 x 2160.
const Size storeShotSize = Size(1920, 1080);

/// A golden comparator that does not compare: it writes the picture into [dir].
class _WritingComparator extends GoldenFileComparator {
  _WritingComparator(this.dir);

  final String dir;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await Directory(dir).create(recursive: true);
    await File('$dir${Platform.pathSeparator}${golden.pathSegments.last}').writeAsBytes(imageBytes);
  }
}

/// Writes what the app shows now as `<STORE_SHOTS_DIR>/<name>.png`, at the window's own size.
Future<void> saveStoreShot(WidgetTester tester, String name) async {
  final dir = storeShotsDir;
  if (dir == null) return;
  final previous = goldenFileComparator;
  goldenFileComparator = _WritingComparator(dir);
  try {
    await expectLater(find.byType(WidgetsApp), matchesGoldenFile('$name.png'));
  } finally {
    goldenFileComparator = previous;
  }
}
