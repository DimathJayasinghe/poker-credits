import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/sound_cues.dart';

/// The sounds are files in the app bundle. A cue without its file is silent in the field, and a
/// file without a cue is weight in every download, so both are caught here.
void main() {
  final dir = Directory('assets/sounds');

  test('every clip of every cue exists as a WAV file', () {
    for (final cue in SoundCue.values) {
      for (final clip in cue.clips) {
        expect(File('assets/sounds/$clip.wav').existsSync(), isTrue, reason: '$cue needs assets/sounds/$clip.wav');
      }
    }
  });

  test('no sound file is left without a cue', () {
    final used = {for (final cue in SoundCue.values) ...cue.clips.map((c) => '$c.wav')};
    final files = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.wav')).toSet();
    expect(files.difference(used), isEmpty);
  });

  test('the folder is declared as an asset, with the licence note beside the files', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/sounds/'));
    expect(File('assets/sounds/README.md').existsSync(), isTrue);
  });

  test('every clip is a short 16-bit mono WAV', () {
    for (final file in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav'))) {
      final bytes = file.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: file.path);
      expect(data.getUint16(22, Endian.little), 1, reason: '${file.path}: mono');
      expect(data.getUint16(34, Endian.little), 16, reason: '${file.path}: 16 bit');
      final seconds = (bytes.length - 44) / 2 / data.getUint32(24, Endian.little);
      expect(seconds, inInclusiveRange(0.15, 4.0), reason: '${file.path}: length');
    }
  });
}
