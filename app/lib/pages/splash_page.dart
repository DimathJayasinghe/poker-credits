import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/echo_title.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/cards/hole_cards_dock.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The loading screen: the wordmark, five cards turning over into a royal flush and a bar that
/// fills while the app gets ready. A tap skips it. With reduced motion the cards are simply face
/// up and the bar is full.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.duration, required this.onSkip});

  /// How long the bar takes to fill. The gate leaves the screen at this time.
  final Duration duration;
  final VoidCallback onSkip;

  /// The five cards, in the order they turn.
  static final List<PokerCard> hand = <PokerCard>[
    for (final r in <String>['A', 'K', 'Q', 'J', 'T']) PokerCard.parse('${r}s'),
  ];

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;
  int _faceUp = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _timer?.cancel();
      _faceUp = SplashView.hand.length;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 260), (timer) {
        if (!mounted || _faceUp >= SplashView.hand.length) {
          timer.cancel();
          return;
        }
        setState(() => _faceUp++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final reduced = MediaQuery.of(context).disableAnimations;
    return PaperScaffold(
      body: Semantics(
        label: '${Strings.appName}. ${Strings.splashLoading}',
        button: true,
        onTap: widget.onSkip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSkip,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(BrutalMetrics.gapL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: BrutalMetrics.gapL, left: BrutalMetrics.gapS),
                        child: EchoTitle(Strings.appName.split(' ')),
                      ),
                    ),
                    const SizedBox(height: BrutalMetrics.gapXl),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (var i = 0; i < SplashView.hand.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: BrutalMetrics.gapS),
                            ExcludeSemantics(
                              child: FlipCard(card: SplashView.hand[i], faceUp: i < _faceUp, size: CardSize.board),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: BrutalMetrics.gapXl),
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(color: c.line, width: BrutalMetrics.border),
                      ),
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
                        duration: reduced ? Duration.zero : widget.duration,
                        builder: (context, t, _) => FractionallySizedBox(
                          widthFactor: t,
                          heightFactor: 1,
                          child: ColoredBox(color: c.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: BrutalMetrics.gapS),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${Strings.splashLoading}…'.toUpperCase(),
                          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.ink),
                        ),
                        Text(
                          Strings.splashSkip.toUpperCase(),
                          style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 12, letterSpacing: 2, color: c.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
