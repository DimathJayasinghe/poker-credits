import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'devices.dart';
import 'fakes.dart';
import 'package:poker_credits/main.dart';

/// Opens the whole app on [d] at text size [scale], with the system bars taken off the top and
/// the bottom like on the real device. [keyboard] is the height of an open on-screen keyboard.
Future<void> launchOn(WidgetTester tester, TestHarness harness, Device d, {double scale = 1, double keyboard = 0, bool dark = false}) async {
  tester.view
    ..physicalSize = d.size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: d.size,
        textScaler: TextScaler.linear(scale),
        padding: d.insets,
        viewPadding: d.insets,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: harness.scope(const PokerCreditsApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// The vertical scroll extent of every scrollable that holds [anchor].
double extentAround(WidgetTester tester, Finder anchor) {
  var most = 0.0;
  for (final element in tester.elementList(anchor)) {
    element.visitAncestorElements((ancestor) {
      if (ancestor is StatefulElement && ancestor.state is ScrollableState) {
        final position = (ancestor.state as ScrollableState).position;
        if (position.axis == Axis.vertical && position.maxScrollExtent > most) most = position.maxScrollExtent;
      }
      return true;
    });
  }
  return most;
}

/// Collects what does not fit, so one run reports every screen at once.
class Misfits {
  final List<String> lines = <String>[];

  void check(WidgetTester tester, String screen, Finder anchor, Device d, double scale) {
    final error = tester.takeException();
    if (error != null) {
      lines.add('$screen: EXCEPTION $error');
    }
    final extent = extentAround(tester, anchor);
    if (extent > 0.5) {
      lines.add('$screen scrolls by ${extent.toStringAsFixed(0)} px');
    }
  }

  void done(Device d, double scale) {
    if (lines.isNotEmpty) {
      fail('${d.name} ${d.width.toInt()}x${d.height.toInt()} (usable ${d.usable.toInt()}), text x$scale:\n  ${lines.join('\n  ')}');
    }
  }
}
