import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Loads the bundled fonts so goldens render real glyphs instead of test boxes.
Future<void> loadBrutalFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('assets/fonts/$file').readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load(BrutalFonts.display, <String>['ArchivoBlack-Regular.ttf']);
  await load(BrutalFonts.mono, <String>['SpaceMono-Regular.ttf', 'SpaceMono-Bold.ttf']);
}

/// Wraps [child] in the brutalist theme.
Widget brutalHost(Widget child, {bool dark = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildBrutalTheme(dark ? BrutalColors.dark : BrutalColors.light, dark ? Brightness.dark : Brightness.light),
  home: Scaffold(body: child),
);
