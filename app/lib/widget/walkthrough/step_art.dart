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

SeatView _seat(int index, String name, int chips, {bool cards = true}) => SeatView(
  seatIndex: index,
  playerId: 'demo_$index',
  name: name,
  chips: chips,
  streetBet: 0,
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
      case StepArt.holeCards:
        return CardRow(cards: _cards(const <String>['As', 'Kd']), size: CardSize.hero, gap: 16);
      case StepArt.board:
        return BoardView(shown: _cards(lessonBoard), size: CardSize.board, slotColor: c.onFelt);
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
      case StepArt.blinds:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 190,
              child: SeatPlate(seat: _seat(0, 'Alice', 995, cards: false), isDealer: true, isSmallBlind: true),
            ),
            const SizedBox(width: BrutalMetrics.gapM),
            SizedBox(
              width: 190,
              child: SeatPlate(seat: _seat(1, 'Bob', 990, cards: false), isBigBlind: true),
            ),
          ],
        );
      case StepArt.handsTop:
        return _handList(c, handExamples.take(5).toList());
      case StepArt.handsBottom:
        return _handList(c, handExamples.skip(5).toList());
      case StepArt.workedExample:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BoardView(shown: _cards(exampleBoard), size: CardSize.board),
            const SizedBox(height: BrutalMetrics.gapM),
            Row(
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
            ),
          ],
        );
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

  /// A hand name beside its five cards, one row per hand.
  Widget _handList(BrutalColors c, List<(String, List<String>)> hands) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final (name, cards) in hands)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 210,
                child: Text(
                  name.toUpperCase(),
                  style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 22, color: c.onFelt),
                ),
              ),
              CardRow(cards: _cards(cards), size: CardSize.mini, gap: 3),
            ],
          ),
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
