import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/cards/board_view.dart';
import 'package:poker_credits/widget/cards/playing_card.dart';
import 'package:poker_credits/widget/player/opponent_strip.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

SeatView _seat(int index, String id) => SeatView(
  seatIndex: index,
  playerId: id,
  name: id.toUpperCase(),
  chips: 1000,
  streetBet: 0,
  hasFolded: false,
  isAllIn: false,
  isSittingOut: false,
  isConnected: true,
  hasCards: true,
);

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: ThemeData(extensions: <ThemeExtension<dynamic>>[const BrutalTheme(colors: BrutalColors.light)]),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

double _barWidth(WidgetTester tester) {
  final box = find.descendant(of: find.byType(ThinkingBar), matching: find.byType(FractionallySizedBox));
  if (box.evaluate().isEmpty) return 0;
  return tester.widget<FractionallySizedBox>(box).widthFactor ?? 0;
}

void main() {
  test('the fill slows down and never reaches the end', () {
    var last = 0.0;
    for (final ms in <int>[0, 500, 1000, 2000, 4000, 8000, 20000]) {
      final f = ThinkingBar.fill(Duration(milliseconds: ms));
      expect(f, greaterThanOrEqualTo(last));
      expect(f, lessThan(1.0));
      last = f;
    }
    expect(
      ThinkingBar.fill(const Duration(seconds: 2)) - ThinkingBar.fill(Duration.zero),
      greaterThan(ThinkingBar.fill(const Duration(seconds: 12)) - ThinkingBar.fill(const Duration(seconds: 10))),
    );
  });

  testWidgets('only the opponent on turn shows a bar, it grows, and stops while paused', (tester) async {
    final seats = <SeatView>[_seat(0, 'me'), _seat(1, 'maya'), _seat(2, 'liam')];
    Widget strip({required int? active, bool paused = false}) =>
        _host(OpponentStrip(seats: seats, myPlayerId: 'me', showStacks: true, activeSeat: active, turnKey: 'h1', paused: paused));
    await tester.pumpWidget(strip(active: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ThinkingBar), findsNWidgets(2));
    final early = _barWidth(tester);
    await tester.pump(const Duration(seconds: 2));
    final later = _barWidth(tester);
    expect(later, greaterThan(early));
    expect(later, lessThan(1.0));
    await tester.pumpWidget(strip(active: 1, paused: true));
    await tester.pump();
    final frozen = _barWidth(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_barWidth(tester), frozen, reason: 'a paused game stands still');
    await tester.pumpWidget(strip(active: 0));
    await tester.pump();
    expect(_barWidth(tester), 0, reason: 'my own turn shows no bar on the others');
  });

  testWidgets('a new turn starts the bar again', (tester) async {
    final seats = <SeatView>[_seat(0, 'me'), _seat(1, 'maya')];
    Widget strip(String key) => _host(OpponentStrip(seats: seats, myPlayerId: 'me', showStacks: true, activeSeat: 1, turnKey: key));
    await tester.pumpWidget(strip('a'));
    await tester.pump(const Duration(seconds: 5));
    final long = _barWidth(tester);
    await tester.pumpWidget(strip('b'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_barWidth(tester), lessThan(long));
  });

  testWidgets('with reduced motion the bar is a fixed half and the board shows faces at once', (tester) async {
    final seats = <SeatView>[_seat(0, 'me'), _seat(1, 'maya')];
    await tester.pumpWidget(_host(OpponentStrip(seats: seats, myPlayerId: 'me', showStacks: true, activeSeat: 1, turnKey: 'a'), reduced: true));
    await tester.pump(const Duration(seconds: 3));
    expect(_barWidth(tester), 0.5);
    await tester.pumpWidget(_host(BoardView(shown: <PokerCard>[card('9c'), card('Jh'), card('2d')], animate: true), reduced: true));
    expect(find.bySemanticsLabel('Nine of clubs'), findsOneWidget);
  });

  testWidgets('the flop turns over one card after the other and the turn comes alone', (tester) async {
    await tester.pumpWidget(_host(BoardView(shown: <PokerCard>[card('9c'), card('Jh'), card('2d')], animate: true)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Nine of clubs'), findsNothing, reason: 'still face down');
    await tester.pump(const Duration(seconds: 3));
    expect(find.descendant(of: find.byType(BoardView), matching: find.byType(PlayingCard)), findsNWidgets(3));
    expect(find.bySemanticsLabel('Nine of clubs'), findsOneWidget);
    expect(find.bySemanticsLabel('Jack of hearts'), findsOneWidget);
  });
}
