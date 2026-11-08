import 'package:flutter/material.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/lesson_content.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/card_row.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/table/pot_display.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

List<PokerCard> _cards(List<String> text) => <PokerCard>[for (final t in text) PokerCard.parse(t)];

SeatView _seat(int index, String name, int chips, {bool cards = true, int bet = 0}) => SeatView(
  seatIndex: index,
  playerId: 'demo_$index',
  name: name,
  chips: chips,
  streetBet: bet,
  hasFolded: false,
  isAllIn: false,
  isSittingOut: false,
  isConnected: true,
  hasCards: cards,
);

/// The picture above a walkthrough step: a small, still scene made of the real widgets. It does
/// not react to taps and is hidden from screen readers (the step carries a description instead).
/// The scene is drawn at one natural size and scaled down to fit, so no width or text size can
/// make it overflow.
class StepArtView extends StatelessWidget {
  const StepArtView({super.key, required this.art, required this.label, this.bare = false});

  final StepArt art;
  final String label;

  /// Without the felt panel behind it, for a page that draws the panel itself.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final scene = IgnorePointer(
      child: MediaQuery.withNoTextScaling(
        child: Padding(
          padding: EdgeInsets.all(bare ? BrutalMetrics.gapM : BrutalMetrics.gapL),
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: _scene(context)),
          ),
        ),
      ),
    );
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: bare
          ? scene
          : DecoratedBox(
              decoration: BoxDecoration(
                color: c.felt,
                border: Border(
                  bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
                ),
              ),
              child: scene,
            ),
    );
  }

  Widget _scene(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    TextStyle display(double size, {Color? color}) =>
        TextStyle(fontFamily: BrutalFonts.display, fontSize: size, height: 1.05, color: color ?? c.onFelt);
    switch (art) {
      case StepArt.welcome:
        return CardRow(cards: _cards(handExamples.first.$2), size: CardSize.board, gap: 8);
      case StepArt.host:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              color: BrutalColors.light.paper,
              padding: const EdgeInsets.all(BrutalMetrics.gapS),
              child: SizedBox(
                width: 112,
                height: 112,
                child: PrettyQrView.data(
                  data: 'poker-credits-demo',
                  decoration: PrettyQrDecoration(shape: PrettyQrSquaresSymbol(color: BrutalColors.light.ink)),
                ),
              ),
            ),
            const SizedBox(width: BrutalMetrics.gapL),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ROOM CODE',
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.onFelt),
                ),
                Text('KQ7M', style: display(64).copyWith(letterSpacing: 4)),
              ],
            ),
          ],
        );
      case StepArt.join:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final ch in 'KQ7M'.split(''))
                  Container(
                    width: 56,
                    height: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line, width: BrutalMetrics.borderHeavy),
                    ),
                    child: Text(ch, style: display(40, color: c.ink)),
                  ),
              ],
            ),
            const SizedBox(height: BrutalMetrics.gapM),
            SizedBox(
              width: 240,
              child: BrutalButton(label: 'Join', kind: BrutalButtonKind.primary, heavy: true, onPressed: () {}),
            ),
          ],
        );
      case StepArt.cardMode:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: BrutalSegmented<int>(
                value: 1,
                options: const <(int, String)>[(0, 'Real cards'), (1, 'Cards in the app')],
                onChanged: (_) {},
              ),
            ),
            const SizedBox(height: BrutalMetrics.gapM),
            const CardRow(cards: <PokerCard?>[null, null], size: CardSize.hero, gap: 12),
          ],
        );
      case StepArt.yourTurn:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('YOUR TURN  0:27', style: display(40, color: c.onFelt)),
            const SizedBox(height: BrutalMetrics.gapM),
            SizedBox(
              width: 380,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: BrutalButton(label: 'Fold', onPressed: () {}),
                  ),
                  const SizedBox(width: BrutalMetrics.gapS),
                  Expanded(
                    child: BrutalButton(label: 'Call 20', kind: BrutalButtonKind.info, onPressed: () {}),
                  ),
                  const SizedBox(width: BrutalMetrics.gapS),
                  Expanded(
                    child: BrutalButton(label: 'Raise', kind: BrutalButtonKind.primary, onPressed: () {}),
                  ),
                ],
              ),
            ),
          ],
        );
      case StepArt.showdown:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 190,
              child: SeatPlate(seat: _seat(0, 'Alice', 1020), isWinner: true, cards: _cards(exampleAlice)),
            ),
            const SizedBox(width: BrutalMetrics.gapM),
            SizedBox(
              width: 190,
              child: SeatPlate(seat: _seat(1, 'Bob', 980), cards: _cards(exampleBob)),
            ),
          ],
        );
      case StepArt.playAlone:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: BrutalSegmented<int>(
                value: 1,
                options: const <(int, String)>[(0, 'Easy'), (1, 'Normal'), (2, 'Hard')],
                onChanged: (_) {},
              ),
            ),
            const SizedBox(height: BrutalMetrics.gapL),
            Text('4 OPPONENTS', style: display(40, color: c.onFelt)),
          ],
        );
      case StepArt.staySafe:
        return CustomPaint(size: const Size(215, 150), painter: _WifiLockPainter(c.onFelt, c.felt, c.accent));
      case StepArt.goal:
        return const PotDisplay(total: 240, pots: <PotView>[], fontSize: 64);
      case StepArt.winWays:
        return _winWays(c);
      case StepArt.holeCards:
        return CardRow(cards: _cards(const <String>['As', 'Kd']), size: CardSize.hero, gap: 16);
      case StepArt.board:
        return BoardView(shown: _cards(lessonBoard), size: CardSize.board, slotColor: c.onFelt);
      case StepArt.sevenCards:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _caption(c, 'THE BOARD'),
            const SizedBox(height: BrutalMetrics.gapS),
            BoardView(shown: _cards(lessonBoard), size: CardSize.board, slotColor: c.onFelt),
            const SizedBox(height: BrutalMetrics.gapL),
            _caption(c, 'YOUR TWO CARDS'),
            const SizedBox(height: BrutalMetrics.gapS),
            CardRow(cards: _cards(const <String>['As', 'Kd']), size: CardSize.board, gap: 8),
          ],
        );
      case StepArt.rounds:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final (name, count) in const <(String, int)>[('PRE-FLOP', 0), ('FLOP', 3), ('TURN', 4), ('RIVER', 5)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      child: Text(name, style: display(22, color: c.onFelt)),
                    ),
                    BoardView(shown: _cards(lessonBoard.take(count).toList()), size: CardSize.mini, slotColor: c.onFelt),
                  ],
                ),
              ),
          ],
        );
      case StepArt.choices:
        return SizedBox(
          width: 420,
          child: Row(
            children: <Widget>[
              for (final (label, kind) in const <(String, BrutalButtonKind)>[
                ('Fold', BrutalButtonKind.neutral),
                ('Check', BrutalButtonKind.neutral),
                ('Call', BrutalButtonKind.info),
                ('Raise', BrutalButtonKind.primary),
              ]) ...<Widget>[
                Expanded(
                  child: BrutalButton(label: label, kind: kind, onPressed: () {}),
                ),
                if (label != 'Raise') const SizedBox(width: BrutalMetrics.gapS),
              ],
            ],
          ),
        );
      case StepArt.dealerButton:
        return _seats(c, <(Widget, String)>[
          (SeatPlate(seat: _seat(0, 'Alice', 1000, cards: false), isDealer: true), 'DEALER'),
          (SeatPlate(seat: _seat(1, 'Bob', 1000, cards: false)), ''),
          (SeatPlate(seat: _seat(2, 'Cara', 1000, cards: false)), ''),
        ]);
      case StepArt.blinds:
        return _seats(c, <(Widget, String)>[
          (SeatPlate(seat: _seat(0, 'Alice', 1000, cards: false), isDealer: true), 'DEALER'),
          (SeatPlate(seat: _seat(1, 'Bob', 995, cards: false, bet: 5), isSmallBlind: true), 'SMALL BLIND'),
          (SeatPlate(seat: _seat(2, 'Cara', 990, cards: false, bet: 10), isBigBlind: true), 'BIG BLIND'),
        ]);
      case StepArt.moveFold:
        return _moves(c, 'Fold', 'GIVE UP THIS HAND');
      case StepArt.moveCheck:
        return _moves(c, 'Check', 'PASS WITH NO BET');
      case StepArt.moveCall:
        return _moves(c, 'Call 20', 'MATCH THE BET');
      case StepArt.moveRaise:
        return _moves(c, 'Raise', 'BET MORE');
      case StepArt.moveAllIn:
        return _moves(c, 'All-in', 'BET EVERYTHING');
      case StepArt.reveal:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _player(c, 'Alice', flushAlice),
            const SizedBox(width: BrutalMetrics.gapXl),
            _player(c, 'Bob', flushBob),
          ],
        );
      case StepArt.handsWeakest:
      case StepArt.handsPairs:
      case StepArt.handsRuns:
      case StepArt.handsFull:
      case StepArt.handsBest:
        final (_, weaker, stronger) = lessonHandPairs.firstWhere((p) => p.$1 == art);
        return _handPair(c, weaker, stronger);
      case StepArt.exampleFlush:
        return _showdownScene(c, flushBoard, flushAlice, flushBob);
      case StepArt.tieBreak:
        return _versus(c, tieBreakRows);
      case StepArt.kicker:
        return _versus(c, kickerRows);
      case StepArt.workedExample:
        return _showdownScene(c, exampleBoard, exampleAlice, exampleBob);
      case StepArt.words:
        return SizedBox(
          width: 400,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: BrutalMetrics.gapS,
            runSpacing: BrutalMetrics.gapS,
            children: <Widget>[
              for (final (word, fill, ink) in <(String, Color, Color)>[
                ('FOLD', c.surface, c.ink),
                ('CHECK', c.surface, c.ink),
                ('CALL', c.ink, c.paper),
                ('RAISE', c.accent, c.onAccent),
                ('ALL-IN', c.accent, c.onAccent),
                ('POT', c.chip, c.onChip),
                ('KICKER', c.surface, c.ink),
              ])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(color: c.line, width: BrutalMetrics.border),
                  ),
                  child: Text(word, style: display(28, color: ink)),
                ),
            ],
          ),
        );
    }
  }

  TextStyle _display(BrutalColors c, double size, {Color? color}) =>
      TextStyle(fontFamily: BrutalFonts.display, fontSize: size, height: 1.05, color: color ?? c.onFelt);

  Widget _caption(BrutalColors c, String text) => Text(
    text,
    style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.onFelt),
  );

  /// Seats one under the other, each with a word beside it where there is something to say.
  Widget _seats(BrutalColors c, List<(Widget, String)> rows) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (final (plate, word) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapXs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(width: 200, child: plate),
              SizedBox(
                width: 190,
                child: Padding(
                  padding: const EdgeInsets.only(left: BrutalMetrics.gapM),
                  child: Text(word, style: _display(c, 26)),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// A name over two face-up cards.
  Widget _player(BrutalColors c, String name, List<String> cards, {bool wins = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(name.toUpperCase(), style: _display(c, 26)),
          if (wins) ...<Widget>[const SizedBox(width: BrutalMetrics.gapS), _winsTag(c)],
        ],
      ),
      const SizedBox(height: BrutalMetrics.gapS),
      CardRow(cards: _cards(cards), size: CardSize.hero, gap: 8),
    ],
  );

  Widget _winsTag(BrutalColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: c.accent,
      border: Border.all(color: c.line, width: BrutalMetrics.border),
    ),
    child: Text('WINS', style: _display(c, 20, color: c.onAccent)),
  );

  /// The two ways to win a pot, side by side.
  Widget _winWays(BrutalColors c) {
    Widget panel(String title, Widget body) => Container(
      width: 250,
      padding: const EdgeInsets.all(BrutalMetrics.gapM),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: _display(c, 24, color: c.ink)),
          const SizedBox(height: BrutalMetrics.gapS),
          body,
        ],
      ),
    );
    Widget fold() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.line, width: BrutalMetrics.border),
      ),
      child: Text('FOLD', style: _display(c, 22, color: c.ink)),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        panel('BEST HAND', CardRow(cards: _cards(handExamples[4].$2), size: CardSize.mini, gap: 3)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
          child: Text('OR', style: _display(c, 30)),
        ),
        panel(
          'EVERYONE ELSE',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[fold(), const SizedBox(width: 6), fold(), const SizedBox(width: 6), fold()],
          ),
        ),
      ],
    );
  }

  /// One move as its button, large, with what it means underneath. [label] starts with the move.
  Widget _moves(BrutalColors c, String label, String meaning) {
    final kind = switch (label.split(' ').first) {
      'Call' => BrutalButtonKind.info,
      'Raise' || 'All-in' => BrutalButtonKind.primary,
      _ => BrutalButtonKind.neutral,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 240,
          child: BrutalButton(label: label, kind: kind, heavy: true, onPressed: () {}),
        ),
        const SizedBox(height: BrutalMetrics.gapL),
        Text(meaning, style: _display(c, 34)),
      ],
    );
  }

  /// Two of the ten hands, each with its name above its five cards. [weaker] and [stronger] index
  /// [handExamples].
  Widget _handPair(BrutalColors c, int weaker, int stronger) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final index in <int>[weaker, stronger])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(handExamples[index].$1.toUpperCase(), style: _display(c, 28)),
              const SizedBox(height: BrutalMetrics.gapXs),
              CardRow(cards: _cards(handExamples[index].$2), size: CardSize.board, gap: 6),
            ],
          ),
        ),
    ],
  );

  /// Two five-card hands, one above the other, the winner tagged.
  Widget _versus(BrutalColors c, List<(String, List<String>, bool)> rows) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final (label, cards, wins) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label.toUpperCase(), style: _display(c, 26)),
                  if (wins) ...<Widget>[
                    const SizedBox(width: BrutalMetrics.gapM),
                    _winsTag(c),
                  ],
                ],
              ),
              const SizedBox(height: BrutalMetrics.gapXs),
              CardRow(cards: _cards(cards), size: CardSize.board, gap: 6),
            ],
          ),
        ),
    ],
  );

  /// The board, and two players who show their cards; the first one wins.
  Widget _showdownScene(BrutalColors c, List<String> board, List<String> alice, List<String> bob) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      BoardView(shown: _cards(board), size: CardSize.board),
      const SizedBox(height: BrutalMetrics.gapL),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _player(c, 'Alice', alice, wins: true),
          const SizedBox(width: BrutalMetrics.gapXl),
          _player(c, 'Bob', bob),
        ],
      ),
    ],
  );
}

/// A Wi-Fi symbol with a padlock on it: three arcs and a dot, and a lock at the lower right.
class _WifiLockPainter extends CustomPainter {
  const _WifiLockPainter(this.ink, this.background, this.accent);

  final Color ink;
  final Color background;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.butt;
    final centre = Offset(72, size.height - 22);
    for (final radius in <double>[34, 66, 98]) {
      canvas.drawArc(Rect.fromCircle(center: centre, radius: radius), -2.36, 1.58, false, stroke);
    }
    canvas.drawCircle(centre, 8, Paint()..color = ink);
    // The padlock: a body with a shackle, on a cut-out of the background colour.
    final body = Rect.fromLTWH(size.width - 68, size.height - 58, 62, 50);
    canvas.drawRect(body.inflate(7), Paint()..color = background);
    canvas.drawArc(Rect.fromLTWH(body.left + 12, body.top - 24, 38, 40), 3.14159, 3.14159, false, stroke..strokeWidth = 7);
    canvas.drawRect(body, Paint()..color = accent);
    canvas.drawRect(
      body,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_WifiLockPainter old) => old.ink != ink || old.background != background || old.accent != accent;
}
