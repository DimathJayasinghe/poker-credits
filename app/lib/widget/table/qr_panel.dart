import 'package:flutter/material.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Bordered block with the join QR, the typed address(es) and the room code in large type.
/// The QR sits beside the text on a wide panel and above it on a narrow one.
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.roomCode, required this.addresses, this.qrSize = 180, this.compact = false});

  final String roomCode;

  /// `address:port` strings; the first one goes into the QR code.
  final List<String> addresses;

  /// The side of the QR code, white margin included.
  final double qrSize;

  /// A short screen: the code beside the text whatever the width, smaller type, two addresses.
  final bool compact;

  static const double _narrowWidth = 480;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final link = addresses.isEmpty ? null : JoinLink(hostAndPort: addresses.first, roomCode: roomCode);

    final qr = link == null
        ? null
        : Semantics(
            label: '${Strings.joinWith}: $roomCode',
            image: true,
            child: Container(
              color: BrutalColors.light.paper,
              padding: EdgeInsets.all(compact ? BrutalMetrics.gapXs : BrutalMetrics.gapS),
              child: SizedBox(
                width: qrSize,
                height: qrSize,
                child: PrettyQrView.data(
                  data: link.toString(),
                  decoration: PrettyQrDecoration(shape: PrettyQrSquaresSymbol(color: BrutalColors.light.ink)),
                ),
              ),
            ),
          );

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          Strings.joinByCode.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 11 : null, letterSpacing: 0.5, color: c.muted),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            roomCode,
            style: TextStyle(fontFamily: BrutalFonts.display, fontSize: compact ? 44 : 64, height: 1, letterSpacing: compact ? 3 : 4, color: c.ink),
          ),
        ),
        SizedBox(height: compact ? BrutalMetrics.gapXs : BrutalMetrics.gapM),
        if (addresses.isNotEmpty) ...<Widget>[
          Text(
            Strings.orType.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 11 : null, letterSpacing: 0.5, color: c.muted),
          ),
          for (final address in addresses.take(compact ? 2 : 3))
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                address,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: compact ? 16 : 22, color: c.ink),
              ),
            ),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? BrutalMetrics.gapS : BrutalMetrics.gapM),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = !compact && constraints.maxWidth < _narrowWidth;
            if (narrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (qr != null) ...<Widget>[Center(child: qr), const SizedBox(height: BrutalMetrics.gapM)],
                  details,
                ],
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (qr != null) ...<Widget>[qr, SizedBox(width: compact ? BrutalMetrics.gapM : BrutalMetrics.gapL)],
                Flexible(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}
