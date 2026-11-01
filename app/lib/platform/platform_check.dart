import 'package:flutter/foundation.dart';

/// Web-safe platform helpers. Never use dart:io Platform here (ADR-014).
bool isDesktop() =>
    !kIsWeb && const <TargetPlatform>{TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}.contains(defaultTargetPlatform);

bool isMobile() => !kIsWeb && const <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform);
