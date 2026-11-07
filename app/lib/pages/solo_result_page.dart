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
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
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

  Widget _stat(BuildContext context, String label, String value) {
    final c = BrutalTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BrutalMetrics.gapM),
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
                style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 28, color: c.ink),
              ),
            ),
          ],
        ),
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
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: Strings.soloResultTitle, onBack: _starting ? null : _home),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BrutalMetrics.gapM),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: result == null || view == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapXl),
                          child: BrutalButton(label: Strings.goHome, kind: BrutalButtonKind.primary, onPressed: _home),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_failed) ...<Widget>[
                              const BrutalBanner(message: Strings.soloFailedUnknown, kind: BrutalBannerKind.error),
                              const SizedBox(height: BrutalMetrics.gapM),
                            ],
                            _Place(result: result),
                            const SizedBox(height: BrutalMetrics.gapM),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(child: _stat(context, Strings.soloStatHands, '${result.stats.handsPlayed}')),
                                  const SizedBox(width: BrutalMetrics.gapS),
                                  Expanded(child: _stat(context, Strings.soloStatWon, '${result.stats.handsWon}')),
                                ],
                              ),
                            ),
                            const SizedBox(height: BrutalMetrics.gapS),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(child: _stat(context, Strings.soloStatBiggest, '${result.stats.biggestWin}')),
                                  const SizedBox(width: BrutalMetrics.gapS),
                                  Expanded(
                                    child: _stat(
                                      context,
                                      Strings.soloStatBest,
                                      result.stats.bestHand == null ? '-' : handCategoryText(result.stats.bestHand!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (view.result != null && view.reveals.isNotEmpty) ...<Widget>[
                              const SizedBox(height: BrutalMetrics.gapM),
                              BrutalCard(
                                header: Strings.soloKnockout,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    ShowdownPanel(
                                      reveals: view.reveals,
                                      result: view.result!,
                                      board: view.board,
                                      fourColour: settings.fourColourDeck,
                                      myPlayerId: session.playerId,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: BrutalMetrics.gapL),
                            BrutalButton(
                              label: _starting ? Strings.soloStarting : Strings.playAgain,
                              kind: BrutalButtonKind.primary,
                              heavy: true,
                              minHeight: BrutalMetrics.tapPlayer,
                              onPressed: _starting ? null : _again,
                            ),
                            const SizedBox(height: BrutalMetrics.gapS),
                            BrutalButton(label: Strings.goHome, minHeight: BrutalMetrics.tap, onPressed: _starting ? null : _home),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The finishing place in large type.
class _Place extends StatelessWidget {
  const _Place({required this.result});

  final SoloResult result;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final fill = result.won ? c.accent : c.surface;
    final text = result.won ? c.onAccent : c.ink;
    final place = Strings.ordinal(result.place).toUpperCase();
    final label = result.won ? Strings.soloWon : '${Strings.soloOutOf} ${result.of}';
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
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  place,
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 96, height: 1.0, color: text),
                ),
              ),
              const SizedBox(height: BrutalMetrics.gapS),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, color: text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
