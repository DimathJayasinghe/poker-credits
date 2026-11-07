import 'package:flutter/material.dart';
import 'package:poker_credits/model/solo_result.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/provider/solo_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_credits/widget/cards/showdown_panel.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// How a single-player game ended: the finishing place, what the player did, and the hand that
/// decided it. Play again starts a new game with the same settings; Home leaves.
class SoloResultPage extends StatefulWidget {
  const SoloResultPage({super.key});

  @override
  State<SoloResultPage> createState() => _SoloResultPageState();
}

class _SoloResultPageState extends State<SoloResultPage> with Refena {
  bool _starting = false;
  bool _failed = false;

  Future<void> _home() async {
    await ref.notifier(soloProvider).leave();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _again() async {
    setState(() {
      _starting = true;
      _failed = false;
    });
    final session = ref.read(sessionProvider);
    final settings = ref.read(settingsProvider);
    final solo = ref.notifier(soloProvider);
    final kind = solo.kind;
    final name = session.mySeat?.name ?? settings.defaultName;
    await solo.leave();
    final ok = await solo.start(
      name: name,
      solo: SoloConfig(bots: kind?.bots ?? settings.soloBots, skill: kind?.skill ?? settings.soloSkill, ladderHands: settings.soloLength.ladderHands),
    );
    if (!mounted) return;
    if (ok) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const SoloTablePage()));
    } else {
      setState(() {
        _starting = false;
        _failed = true;
      });
    }
  }

  Widget _stat(BuildContext context, FitInfo info, String label, String value) {
    final c = BrutalTheme.of(context).colors;
    final pad = info.roomy ? BrutalMetrics.gapM : (info.sideBySide ? 6.0 : BrutalMetrics.gapS);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              maxLines: 2,
              style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: c.muted),
            ),
            const SizedBox(height: BrutalMetrics.gapXs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: info.roomy ? 28 : (info.sideBySide ? 20 : 24), color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllHands(RoomView view, String? me, bool fourColour) {
    showBrutalSheet<void>(
      context: context,
      title: Strings.showdownTitle,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(BrutalMetrics.gapM),
        child: ShowdownPanel(reveals: view.reveals, result: view.result!, board: view.board, fourColour: fourColour, myPlayerId: me),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    final stats = context.ref.watch(soloProvider).stats;
    final settings = context.ref.watch(settingsProvider);
    final view = session.room.view;
    final result = view == null ? null : SoloResult.from(view, session.playerId, stats);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return FitPage(
      title: Strings.soloResultTitle,
      onBack: _starting ? null : _home,
      compactBelow: 800,
      tightBelow: 560,
      footer: result == null || view == null
          ? null
          : (context, info) {
              final again = BrutalButton(
                label: _starting ? Strings.soloStarting : Strings.playAgain,
                kind: BrutalButtonKind.primary,
                heavy: true,
                minHeight: info.roomy ? BrutalMetrics.tapPlayer : 52,
                onPressed: _starting ? null : _again,
              );
              final home = BrutalButton(label: Strings.goHome, minHeight: info.roomy ? BrutalMetrics.tap : 52, onPressed: _starting ? null : _home);
              if (info.sideBySide) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    again,
                    SizedBox(height: info.gap),
                    home,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 3, child: again),
                    SizedBox(width: info.gap),
                    Expanded(flex: 2, child: home),
                  ],
                ),
              );
            },
      builder: (context, info) {
        if (result == null || view == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapXl),
            child: BrutalButton(label: Strings.goHome, kind: BrutalButtonKind.primary, onPressed: _home),
          );
        }
        Widget gap() => SizedBox(height: info.gap);
        Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: a),
              const SizedBox(width: BrutalMetrics.gapS),
              Expanded(child: b),
            ],
          ),
        );
        final place = _Place(
          result: result,
          size: info.sideBySide ? 44 : (info.roomy ? 96 : (info.tight ? 56 : 72)),
          pad: info.roomy ? BrutalMetrics.gapL : (info.sideBySide ? BrutalMetrics.gapS : BrutalMetrics.gapM),
          horizontal: info.sideBySide,
        );
        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            pair(
              _stat(context, info, Strings.soloStatHands, '${result.stats.handsPlayed}'),
              _stat(context, info, Strings.soloStatWon, '${result.stats.handsWon}'),
            ),
            const SizedBox(height: BrutalMetrics.gapS),
            pair(
              _stat(context, info, Strings.soloStatBiggest, '${result.stats.biggestWin}'),
              _stat(context, info, Strings.soloStatBest, result.stats.bestHand == null ? '-' : handCategoryText(result.stats.bestHand!)),
            ),
          ],
        );
        Widget? deciding;
        if (view.result != null && view.reveals.isNotEmpty) {
          final scale = textScale > 1 ? textScale : 1.0;
          void showAll() => _showAllHands(view, session.playerId, settings.fourColourDeck);
          // What the numbers and the place leave of the page: the deciding hand gets that, as
          // many lines as fit, or a single row that opens it when there is not even room for one.
          final placeHeight = (info.roomy ? 184.0 : (info.tight ? 128.0 : 144.0)) + (scale > 1 ? 8 : 0);
          final statsHeight = info.roomy ? 178.0 : (scale > 1 ? 164.0 : 138.0);
          final left = info.sideBySide ? info.bodyHeight : info.bodyHeight - placeHeight - statsHeight - info.gap * 2;
          final overhead = 30 + 19 + 60 + view.result!.pots.length * 34 + 44 + 16;
          final rows = view.result!.uncontested ? 1 : ((left - overhead) / (ShowdownPanel.compactRowHeight + 6)).floor();
          deciding = rows < 1
              ? BrutalButton(label: Strings.soloKnockout, onPressed: showAll)
              : FitSection(
                  info: info,
                  label: Strings.soloKnockout,
                  child: ShowdownPanel(
                    compact: true,
                    maxRows: rows,
                    reveals: view.reveals,
                    result: view.result!,
                    board: view.board,
                    fourColour: settings.fourColourDeck,
                    myPlayerId: session.playerId,
                    onMore: showAll,
                  ),
                );
        }
        final banner = _failed ? const BrutalBanner(message: Strings.soloFailedUnknown, kind: BrutalBannerKind.error) : null;
        if (info.sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?banner,
              if (banner != null) gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[place, gap(), grid]),
                  ),
                  SizedBox(width: info.pad),
                  if (deciding != null) Expanded(child: deciding),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ?banner,
            if (banner != null) gap(),
            place,
            gap(),
            grid,
            if (deciding != null) ...<Widget>[gap(), deciding],
          ],
        );
      },
    );
  }
}

/// The finishing place in large type.
class _Place extends StatelessWidget {
  const _Place({required this.result, required this.size, required this.pad, this.horizontal = false});

  final SoloResult result;

  /// The size of the numeral; it keeps its size when the text is enlarged, like a logo.
  final double size;
  final double pad;

  /// The numeral and its caption side by side, for a page with little height.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final fill = result.won ? c.accent : c.surface;
    final text = result.won ? c.onAccent : c.ink;
    final place = Strings.ordinal(result.place).toUpperCase();
    final label = result.won ? Strings.soloWon : '${Strings.soloOutOf} ${result.of}';
    final numeral = MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          place,
          style: TextStyle(fontFamily: BrutalFonts.display, fontSize: size, height: 1.0, color: text),
        ),
      ),
    );
    final caption = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, color: text),
      ),
    );
    return Semantics(
      container: true,
      label: result.won ? '${Strings.soloWon}, $place ${Strings.soloOutOf} ${result.of}' : '$place ${Strings.soloOutOf} ${result.of}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: c.line, width: BrutalMetrics.borderHeavy),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: pad),
          child: horizontal
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    numeral,
                    const SizedBox(width: BrutalMetrics.gapM),
                    Flexible(child: caption),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    numeral,
                    const SizedBox(height: BrutalMetrics.gapS),
                    caption,
                  ],
                ),
        ),
      ),
    );
  }
}
