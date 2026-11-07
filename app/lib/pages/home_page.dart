import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/guide_page.dart';
import 'package:poker_credits/pages/host_page.dart';
import 'package:poker_credits/pages/join_page.dart';
import 'package:poker_credits/pages/settings_page.dart';
import 'package:poker_credits/pages/solo_setup_page.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/spectator_page.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/provider/solo_provider.dart';
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
      unawaited(ref.notifier(soloProvider).refreshSaved());
      if (!mounted) return;
      setState(() {
        if (stored == null) return;
        if (stored.isHost) {
          _hosted = stored;
        } else {
          _playing = stored;
        }
      });
    });
  }

  Future<void> _resumeSolo() async {
    setState(() => _resumeError = null);
    final ok = await ref.notifier(soloProvider).restore();
    if (!mounted) return;
    if (!ok) {
      setState(() => _resumeError = Strings.soloResumeFailed);
      // A game the server no longer knows is of no use: forget it.
      await ref.notifier(soloProvider).leave();
      return;
    }
    _push(const SoloTablePage());
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

  /// The wordmark and, when there is room, the tagline. [size] 0 draws the one-line mini mark.
  Widget _header(BuildContext context, {required double size, required bool tagline, required double pad}) {
    final c = BrutalTheme.of(context).colors;
    final mini = size < 40;
    return Container(
      padding: EdgeInsets.fromLTRB(BrutalMetrics.gapL, pad, BrutalMetrics.gapL, pad),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The wordmark is a logo, not reading text: it keeps its size when the text is enlarged.
          MediaQuery.withNoTextScaling(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: mini ? 0 : size * 0.1, left: BrutalMetrics.gapS),
                child: EchoTitle(mini ? <String>[Strings.appName] : Strings.appName.split(' '), size: size),
              ),
            ),
          ),
          if (tagline) ...<Widget>[
            const SizedBox(height: BrutalMetrics.gapM),
            Text(Strings.tagline, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted)),
          ],
        ],
      ),
    );
  }

  /// The actions: the Play destination. [snug] draws them tighter on a short screen; [captions]
  /// false leaves out the line under each label.
  List<Widget> _rows({required bool supported, required bool hasSolo, required bool snug, bool captions = true}) {
    final resume = (_hosted != null && supported) ? _hosted : null;
    return <Widget>[
      if (_resumeError != null) BrutalBanner(message: _resumeError!, kind: BrutalBannerKind.error),
      if (resume != null)
        BrutalRow(
          label: '${Strings.resumeHosting} ${resume.roomCode}',
          emphasis: true,
          dense: snug,
          snug: snug,
          onTap: _resuming ? null : _resume,
        ),
      if (_playing != null)
        BrutalRow(label: '${Strings.resumeGame} ${_playing!.roomCode}', emphasis: resume == null, dense: snug, snug: snug, onTap: _resumePlaying),
      if (hasSolo && supported)
        BrutalRow(label: Strings.resumeSolo, emphasis: resume == null && _playing == null, dense: snug, snug: snug, onTap: _resumeSolo),
      BrutalRow(
        label: Strings.hostGame,
        caption: captions ? (supported ? Strings.hostRowCaption : Strings.hostUnsupported) : null,
        emphasis: resume == null && _playing == null && !hasSolo && supported,
        dense: snug,
        snug: snug,
        onTap: supported ? () => _push(const HostPage()) : null,
      ),
      if (supported)
        BrutalRow(
          label: Strings.playAlone,
          caption: captions ? Strings.playAloneCaption : null,
          dense: snug,
          snug: snug,
          onTap: () => _push(const SoloSetupPage()),
        ),
      BrutalRow(
        label: Strings.joinGame,
        caption: captions ? Strings.joinRowCaption : null,
        dense: snug,
        snug: snug,
        onTap: () => _push(const JoinPage()),
      ),
    ];
  }

  /// The Play destination. It never scrolls on a phone (docs/UI_DESIGN.md "No scrolling"): the
  /// wordmark gets smaller as the height gets shorter, the rows get tighter, and the felt panel
  /// is only what is left over, or nothing.
  Widget _play(BuildContext context, {required bool supported, required bool hasSolo, required bool felt}) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight / (textScale < 1 ? 1 : textScale);
        final screen = MediaQuery.sizeOf(context);
        final side = screen.width >= 600 && screen.height < 460;
        // Extra rows (back to a game) take the space the big wordmark and the tagline would have used.
        final extra =
            (_hosted != null && supported ? 1 : 0) +
            (_playing != null ? 1 : 0) +
            (context.ref.watch(soloProvider.select((s) => s.hasSaved)) && supported ? 1 : 0);
        final roomy = !side && height >= 660 + extra * 80;
        final snug = side || height < 520;
        // A phone on its side has the rows' height only: with a game to go back to, or big text,
        // the one-line captions go and the labels carry the rows.
        final rows = _rows(supported: supported, hasSolo: hasSolo, snug: snug, captions: !(side && (extra > 0 || textScale > 1.15)));
        if (side) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                // Centred when there is room; scrolls only if the text is enlarged past it.
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Center(child: _header(context, size: 52, tagline: true, pad: BrutalMetrics.gapM)),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
                ),
              ),
            ],
          );
        }
        final header = _header(
          context,
          size: roomy ? 104 : (extra > 0 ? 34 : (height >= 560 ? 76 : 52)),
          tagline: roomy,
          pad: roomy ? BrutalMetrics.gapL : BrutalMetrics.gapM,
        );
        // Whatever height is left is the felt; too little of it is not worth drawing. The scroll
        // view is only the last resort (a text size past 1.3).
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  header,
                  ...rows,
                  // In the two-pane layout the felt is the right pane, not a band under the rows.
                  if (felt) const Expanded(child: FeltPanel(hideBelow: 72)) else const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final supported = context.ref.watch(hostServerProvider).isSupported;
    final hasSolo = context.ref.watch(soloProvider.select((s) => s.hasSaved));
    final size = MediaQuery.sizeOf(context);
    // The two panes need room in both directions; a phone on its side has none to spare.
    final wide = size.width >= BrutalMetrics.wide && size.height >= 460;
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
          child: _play(context, supported: supported, hasSolo: hasSolo, felt: !wide),
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
        destinations: const <AppDestination>[AppDestination(Strings.navPlay), AppDestination(Strings.navGuide), AppDestination(Strings.navSettings)],
        index: _tab,
        onSelect: (i) => setState(() => _tab = i),
        body: IndexedStack(
          index: _tab,
          children: <Widget>[
            body,
            const GuideView(),
            SettingsView(
              onGameForgotten: () => setState(() {
                unawaited(ref.notifier(soloProvider).refreshSaved());
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
