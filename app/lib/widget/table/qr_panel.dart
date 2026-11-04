import 'package:flutter/material.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Bordered block with the join QR, the typed address(es) and the room code in large type.
/// The QR sits beside the text on a wide panel and above it on a narrow one.
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.roomCode, required this.addresses});

  final String roomCode;

  /// `address:port` strings; the first one goes into the QR code.
  final List<String> addresses;

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
              padding: const EdgeInsets.all(BrutalMetrics.gapS),
              child: SizedBox(
                width: 180,
                height: 180,
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
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c.muted),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            roomCode,
            style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 64, height: 1, letterSpacing: 4, color: c.ink),
          ),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        if (addresses.isNotEmpty) ...<Widget>[
          Text(
            Strings.orType.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c.muted),
          ),
          for (final address in addresses.take(3))
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                address,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 22, color: c.ink),
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
        padding: const EdgeInsets.all(BrutalMetrics.gapM),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < _narrowWidth;
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
                if (qr != null) ...<Widget>[qr, const SizedBox(width: BrutalMetrics.gapL)],
                Flexible(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}
