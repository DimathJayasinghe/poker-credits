import 'package:flutter/material.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/host_page.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/pages/settings_page.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/spectator_page.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/echo_title.dart';
import 'package:poker_credits/widget/brutal/felt_panel.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
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
  int _tab = 0;
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

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Flips between light and dark from what is actually shown. Decided from the settings and the
  /// operating system, not from the theme in the tree, which is still mid-animation right after
  /// a change.
  void _toggleTheme() {
    final settings = ref.read(settingsProvider);
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final showingDark = switch (settings.theme) {
      ThemeChoice.dark => true,
      ThemeChoice.light => false,
      ThemeChoice.system => platformDark,
    };
    ref.notifier(settingsProvider).update((s) => s.copyWith(theme: showingDark ? ThemeChoice.light : ThemeChoice.dark));
  }

  /// Title, tagline and the actions: the Play destination.
  Widget _actions(BuildContext context, {required bool supported}) {
    final c = BrutalTheme.of(context).colors;
    final resume = (_hosted != null && supported) ? _hosted : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapXl, BrutalMetrics.gapL, BrutalMetrics.gapL),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Fits the width at any text size instead of overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: BrutalMetrics.gapL, left: BrutalMetrics.gapS),
                  child: EchoTitle(Strings.appName.split(' ')),
                ),
              ),
              const SizedBox(height: BrutalMetrics.gapM),
              Text(Strings.tagline, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted)),
            ],
          ),
        ),
        if (_resumeError != null) BrutalBanner(message: _resumeError!, kind: BrutalBannerKind.error),
        if (resume != null)
          BrutalRow(
            label: '${Strings.resumeHosting} ${resume.roomCode}',
            emphasis: true,
            onTap: _resuming ? null : _resume,
          ),
        if (_playing != null) BrutalRow(label: '${Strings.resumeGame} ${_playing!.roomCode}', emphasis: resume == null, onTap: _resumePlaying),
        BrutalRow(
          label: Strings.hostGame,
          caption: supported ? Strings.hostRowCaption : Strings.hostUnsupported,
          emphasis: resume == null && _playing == null && supported,
          onTap: supported ? () => _push(const HostPage()) : null,
        ),
        BrutalRow(label: Strings.joinGame, caption: Strings.joinRowCaption, onTap: () => _push(const JoinPage())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final supported = context.ref.watch(hostServerProvider).isSupported;
    final wide = MediaQuery.sizeOf(context).width >= BrutalMetrics.wide;
    final play = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTopBar(
          title: Strings.navPlay,
          actions: <Widget>[
            TopBarCell(
              semanticLabel: Strings.switchTheme,
              onTap: _toggleTheme,
              child: Icon(Icons.contrast, size: 22, color: c.ink),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _actions(context, supported: supported),
                if (!wide) const FeltPanel(height: 180),
              ],
            ),
          ),
        ),
      ],
    );
    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 5, child: play),
              VerticalDivider(width: BrutalMetrics.border, thickness: BrutalMetrics.border, color: c.line),
              const Expanded(flex: 4, child: FeltPanel()),
            ],
          )
        : play;
    return PaperScaffold(
      body: AppShell(
        destinations: const <AppDestination>[AppDestination(Strings.navPlay), AppDestination(Strings.navSettings)],
        index: _tab,
        onSelect: (i) => setState(() => _tab = i),
        body: IndexedStack(
          index: _tab,
          children: <Widget>[
            body,
            SettingsView(
              onGameForgotten: () => setState(() {
                _hosted = null;
                _playing = null;
              }),
            ),
          ],
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
