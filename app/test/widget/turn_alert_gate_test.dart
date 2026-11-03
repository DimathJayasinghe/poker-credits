import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/widget/player/turn_alert.dart';
import 'package:poker_protocol/poker_protocol.dart';

const LegalActions _legal = LegalActions(
  canFold: true,
  canCheck: true,
  canCall: false,
  callAmount: 0,
  canRaise: true,
  minRaiseTo: 20,
  maxRaiseTo: 100,
);

TurnPrompt _prompt({int seat = 1, int seq = 4}) => TurnPrompt(playerId: 'p_$seat', seatIndex: seat, nextActionSeq: seq, legal: _legal);

void main() {
  test('fires once per turn, not again for a repeated prompt', () {
    final gate = TurnAlertGate();
    expect(gate.shouldFire(prompt: _prompt(), handNumber: 3), isTrue);
    expect(gate.shouldFire(prompt: _prompt(), handNumber: 3), isFalse, reason: 'sent again after a reconnect');
    expect(gate.shouldFire(prompt: null, handNumber: 3), isFalse);
    expect(gate.shouldFire(prompt: _prompt(), handNumber: 3), isFalse, reason: 'still the same turn after a gap');
  });

  test('a later turn of the same player fires again', () {
    final gate = TurnAlertGate();
    expect(gate.shouldFire(prompt: _prompt(seq: 4), handNumber: 3), isTrue);
    expect(gate.shouldFire(prompt: _prompt(seq: 5), handNumber: 3), isTrue, reason: 'raised and re-raised on the same street');
    expect(gate.shouldFire(prompt: _prompt(seq: 5), handNumber: 4), isTrue, reason: 'next hand');
  });
}
