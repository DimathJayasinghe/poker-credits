import 'package:flutter/material.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Placeholder landing screen that proves the theme, the platform seam and the protocol package.
class HomePage extends StatelessWidget {
  HomePage({super.key, HostServer? hostServer}) : hostServer = hostServer ?? createHostServer();

  final HostServer hostServer;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(BrutalMetrics.gapM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    Strings.appName.toUpperCase(),
                    style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 40, height: 1, color: c.ink),
                  ),
                  const SizedBox(height: BrutalMetrics.gapS),
                  Text(Strings.tagline.toUpperCase(), style: TextStyle(letterSpacing: 0.5, color: c.muted)),
                  const SizedBox(height: BrutalMetrics.gapL),
                  const BrutalCard(
                    header: 'Status',
                    child: Text('${Strings.comingSoon}\nPROTOCOL V$protocolVersion'),
                  ),
                  const SizedBox(height: BrutalMetrics.gapL),
                  BrutalButton(
                    label: Strings.hostGame,
                    onPressed: hostServer.isSupported ? () {} : null,
                    kind: BrutalButtonKind.primary,
                    heavy: true,
                  ),
                  if (!hostServer.isSupported) ...<Widget>[
                    const SizedBox(height: BrutalMetrics.gapS),
                    Text(Strings.hostUnsupported, style: TextStyle(color: c.muted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
