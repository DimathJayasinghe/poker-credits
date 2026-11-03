import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:poker_credits/platform/qr_scanner.dart';

/// The camera plugin covers Android, iOS and macOS; Linux and Windows use the typed address.
bool get qrScanSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

QrScannerBuilder get qrScannerBuilder =>
    ({required onCode, required onError}) => _Scanner(onCode: onCode, onError: onError);

class _Scanner extends StatefulWidget {
  const _Scanner({required this.onCode, required this.onError});

  final void Function(String text) onCode;
  final void Function(String reason) onError;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final MobileScannerController _controller = MobileScannerController(formats: const <BarcodeFormat>[BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final text = barcode.rawValue;
          if (text != null) {
            widget.onCode(text);
            return;
          }
        }
      },
      errorBuilder: (context, error) {
        widget.onError(error.errorCode.name);
        return const SizedBox.shrink();
      },
    );
  }
}
