import 'package:flutter/material.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/host_page.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/spectator_page.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Landing screen: host a game, or go back to the game this device was hosting.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  StoredSession? _hosted;
  StoredSession? _playing;
  bool _resuming = false;
  String? _resumeError;

  @override
  void initState() {
    super.initState();
    ensureRef((ref) async {
      final stored = await ref.read(tokenStoreProvider).read();
      if (!mounted || stored == null) return;
      setState(() {
        if (stored.isHost) {
          _hosted = stored;
        } else {
          _playing = stored;
        }
      });
    });
  }

  Future<void> _resume() async {
    setState(() {
      _resuming = true;
      _resumeError = null;
    });
    final ok = await ref.notifier(hostProvider).restore();
    if (!mounted) return;
    if (ok) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TablePage()));
    } else {
      setState(() => _resumeError = Strings.hostingUnavailable);
    }
    if (mounted) setState(() => _resuming = false);
  }

  /// Back to the game this device joined as a guest: a `RESUME` with the stored session. Whether
  /// the session is still good is the server's call; the page shows the answer.
  Future<void> _resumePlaying() async {
    final ok = await ref.read(joinProvider).restore();
    if (!mounted) return;
    if (!ok) {
      setState(() => _playing = null);
      return;
    }
    // A guest without a seat in the view was a spectator.
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _ResumedGuestPage()));
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final supported = context.ref.watch(hostServerProvider).isSupported;
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
                  if (_resumeError != null) ...<Widget>[
                    BrutalBanner(message: _resumeError!, kind: BrutalBannerKind.error),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ],
                  if (_hosted != null && supported) ...<Widget>[
                    BrutalButton(
                      label: '${Strings.resumeHosting} ${_hosted!.roomCode}',
                      kind: BrutalButtonKind.info,
                      minHeight: BrutalMetrics.tapPlayer,
                      onPressed: _resuming ? null : _resume,
                    ),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ],
                  if (_playing != null) ...<Widget>[
                    BrutalButton(
                      label: '${Strings.resumeGame} ${_playing!.roomCode}',
                      kind: BrutalButtonKind.info,
                      minHeight: BrutalMetrics.tapPlayer,
                      onPressed: _resumePlaying,
                    ),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ],
                  BrutalButton(
                    label: Strings.joinGame,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JoinPage())),
                    kind: BrutalButtonKind.info,
                    heavy: true,
                    minHeight: BrutalMetrics.tapPlayer,
                  ),
                  const SizedBox(height: BrutalMetrics.gapM),
                  BrutalButton(
                    label: Strings.hostGame,
                    onPressed: supported ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HostPage())) : null,
                    kind: BrutalButtonKind.primary,
                    heavy: true,
                    minHeight: BrutalMetrics.tapPlayer,
                  ),
                  if (!supported) ...<Widget>[
                    const SizedBox(height: BrutalMetrics.gapS),
                    Text(Strings.hostUnsupported, style: TextStyle(color: c.muted)),
                  ],
                  const SizedBox(height: BrutalMetrics.gapL),
                  Text('PROTOCOL V$protocolVersion', style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown after a guest resumes: becomes the player controller once the server confirms a seat,
/// or the spectator view if the session has none.
class _ResumedGuestPage extends StatelessWidget {
  const _ResumedGuestPage();

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    final spectating = session.room.view != null && !session.isSeated && session.role != Role.player;
    return spectating ? const SpectatorPage() : const PlayerPage();
  }
}
