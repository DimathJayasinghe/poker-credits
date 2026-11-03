/// Platform seam: reading a join QR code with the camera (ADR-014).
library;

import 'package:flutter/widgets.dart';

export 'qr_scanner_stub.dart' if (dart.library.io) 'qr_scanner_io.dart';

/// Builds a live camera view that calls [onCode] with the text of every QR code it reads.
/// [onError] gets a short reason when the camera cannot be used (permission refused, no camera).
typedef QrScannerBuilder = Widget Function({required void Function(String text) onCode, required void Function(String reason) onError});
