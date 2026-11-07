import 'package:flutter/widgets.dart';

/// A phone, tablet or window as the app sees it: the logical size and the room the system bars
/// (status bar, navigation bar or home indicator) take at the top and the bottom.
class Device {
  const Device(this.name, this.width, this.height, {this.top = 0, this.bottom = 0});

  final String name;
  final double width;
  final double height;
  final double top;
  final double bottom;

  Size get size => Size(width, height);
  EdgeInsets get insets => EdgeInsets.only(top: top, bottom: bottom);

  /// What is left for the app: height without the system bars.
  double get usable => height - top - bottom;

  @override
  String toString() => '$name ${width.toInt()}x${height.toInt()}';
}

/// Phones people really own, upright. Android has three-button and gesture navigation.
const List<Device> phones = <Device>[
  Device('Android budget', 360, 640, top: 24, bottom: 48),
  Device('Android 360x720', 360, 720, top: 24, bottom: 48),
  Device('Android 360x800', 360, 800, top: 28, bottom: 16),
  Device('Galaxy S24', 384, 832, top: 32, bottom: 24),
  Device('Android 393x851', 393, 851, top: 28, bottom: 24),
  Device('Pixel', 412, 915, top: 36, bottom: 24),
  Device('iPhone SE', 375, 667, top: 20),
  Device('iPhone 13 mini', 375, 812, top: 50, bottom: 34),
  Device('iPhone 14', 390, 844, top: 47, bottom: 34),
  Device('iPhone 15 Pro', 393, 852, top: 59, bottom: 34),
  Device('iPhone 16 Pro Max', 440, 956, top: 62, bottom: 34),
];

/// Phones on their side: the bars sit at the sides, only the bottom one costs height.
const List<Device> phonesOnTheirSide = <Device>[
  Device('iPhone 14 landscape', 844, 390, bottom: 21),
  Device('iPhone SE landscape', 667, 375),
  Device('Android landscape', 800, 360, top: 24),
];

/// Bigger screens and a desktop window.
const List<Device> bigScreens = <Device>[
  Device('iPad mini', 744, 1133, top: 24, bottom: 20),
  Device('iPad landscape', 1180, 820, top: 24, bottom: 20),
  Device('narrow desktop window', 368, 690),
  Device('desktop', 1280, 800),
];

const List<Device> allDevices = <Device>[...phones, ...phonesOnTheirSide, ...bigScreens];
