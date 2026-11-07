import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/table/seat_plate.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

PokerCard c(String text) => PokerCard.parse(text);

void main() {
  setUpAll(loadBrutalFonts);

  for (final scale in <double>[1, 1.5, 3]) {
    testWidgets('every seat plate has the same size, whatever it shows (text scale $scale)', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final plates = <Widget>[
        SeatPlate(seat: seatView(0, 'Dimath', chips: 940), isDealer: true, cards: const <PokerCard?>[null, null]),
        SeatPlate(
          seat: seatView(1, 'Alice', chips: 1200, bet: 60),
          isWinner: true,
          isBigBlind: true,
          cards: <PokerCard?>[c('Kh'), c('Kc')],
        ),
        SeatPlate(seat: seatView(2, 'Bob', chips: 300, folded: true)),
        SeatPlate(seat: seatView(3, 'Cara', chips: 610, bet: 60), isActive: true, turnFraction: 0.5, seatNumber: 4),
        SeatPlate(seat: seatView(4, 'A very long player name', chips: 1234567, bet: 123456, allIn: true, connected: false), isSmallBlind: true),
      ];
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: const Size(900, 2400), textScaler: TextScaler.linear(scale)),
          child: brutalHost(
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final plate in plates) SizedBox(width: 200, child: plate),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');

      final sizes = <Size>[for (final e in tester.elementList(find.byType(SeatPlate))) e.size!];
      expect(sizes, hasLength(plates.length));
      for (final size in sizes) {
        expect(size, sizes.first);
      }
    });
  }
}
