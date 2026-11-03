import 'package:flutter/widgets.dart';
import 'package:poker_credits/platform/qr_scanner.dart';

/// Web and other targets without a camera plugin: typed address only.
bool get qrScanSupported => false;

QrScannerBuilder get qrScannerBuilder =>
    ({required onCode, required onError}) => const SizedBox.shrink();
