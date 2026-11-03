import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/room_state.dart';
import 'package:poker_protocol/poker_protocol.dart';

import '../support/fakes.dart';

final _now = DateTime.fromMillisecondsSinceEpoch(1000000);

void main() {
  RoomState apply(RoomState s, ServerMessage m) => s.apply(m, localNow: _now);

  test('a snapshot replaces the whole view and sets the clock offset', () {
    var state = apply(const RoomState(), snapshot(version: 5, serverTime: 1005000, nextActionSeq: 3, view: roomView(pot: 40)));
    expect(state.view!.totalPot, 40);
    expect(state.stateVersion, 5);
    expect(state.nextActionSeq, 3);
    expect(state.clockOffsetMs, 5000);

    state = apply(state, snapshot(version: 2, view: roomView(pot: 0)));
    expect(state.view!.totalPot, 0, reason: 'a snapshot always wins, even with a lower version');
    expect(state.stateVersion, 2);
  });

  test('state updates apply only when the version is higher', () {
    var state = apply(const RoomState(), snapshot(version: 5));
    state = apply(state, StateUpdate(stateVersion: 5, view: roomView(pot: 99)));
    expect(state.view!.totalPot, 0);
    state = apply(state, StateUpdate(stateVersion: 4, view: roomView(pot: 99)));
    expect(state.view!.totalPot, 0);
    state = apply(state, StateUpdate(stateVersion: 6, view: roomView(pot: 10)));
    expect(state.view!.totalPot, 10);
    expect(state.needsResync, isFalse);
  });

  test('a gap in versions asks for a resync and keeps the old view', () {
    var state = apply(const RoomState(), snapshot(version: 5));
    state = apply(state, StateUpdate(stateVersion: 7, view: roomView(pot: 10)));
    expect(state.needsResync, isTrue);
    expect(state.view!.totalPot, 0);
    expect(state.resyncRequested().needsResync, isFalse);
  });

  test('the turn prompt sets the action counter and goes away when the turn moves on', () {
    const legal = LegalActions(canFold: true, canCheck: false, canCall: true, callAmount: 20, canRaise: true, minRaiseTo: 40, maxRaiseTo: 500);
    var state = apply(const RoomState(), snapshot(version: 1, view: roomView(activeSeat: 2)));
    state = apply(state, const TurnPrompt(playerId: 'p2', seatIndex: 2, nextActionSeq: 4, legal: legal));
    expect(state.prompt!.legal.callAmount, 20);
    expect(state.nextActionSeq, 4);

    state = apply(state, StateUpdate(stateVersion: 2, view: roomView(activeSeat: 2)));
    expect(state.prompt, isNotNull, reason: 'still this seat to act');
    state = apply(state, StateUpdate(stateVersion: 3, view: roomView(activeSeat: 3)));
    expect(state.prompt, isNull);
  });

  test('ack overwrites the action counter with the server value', () {
    var state = apply(const RoomState(), snapshot(nextActionSeq: 7));
    state = apply(state, const Ack(nextActionSeq: 9, duplicate: false));
    expect(state.nextActionSeq, 9);
  });

  test('the ticker keeps the newest actions only', () {
    var state = const RoomState();
    for (var i = 0; i < RoomState.tickerLength + 5; i++) {
      state = apply(
        state,
        ActionPerformed(playerId: 'p', playerName: 'N$i', kind: ActionKind.call, amount: i, chipsRemaining: 0, allIn: false, auto: false),
      );
    }
    expect(state.ticker, hasLength(RoomState.tickerLength));
    expect(state.ticker.last.playerName, 'N${RoomState.tickerLength + 4}');
  });

  test('errors are kept until something is accepted', () {
    var state = apply(const RoomState(), const ErrorMessage(code: ErrorCode.belowMinRaise, message: 'too low'));
    expect(state.lastError!.code, ErrorCode.belowMinRaise);
    state = apply(state, const Ack(nextActionSeq: 1, duplicate: false));
    expect(state.lastError, isNull);
  });

  test('crash and expiry end the room', () {
    expect(apply(const RoomState(), const RoomCrashed(reason: 'x')).ended, RoomEnd.crashed);
    expect(apply(const RoomState(), const RoomExpired()).ended, RoomEnd.expired);
  });

  test('turn countdown uses the server clock offset', () {
    final state = apply(
      const RoomState(),
      snapshot(
        serverTime: 1000000 + 5000,
        view: roomView(deadline: 1000000 + 5000 + 21000),
      ),
    );
    expect(state.turnRemainingMs(_now), 21000);
    expect(state.turnRemainingMs(_now.add(const Duration(seconds: 30))), 0);
  });

  test('presence checks start and resolve', () {
    var state = apply(const RoomState(), const PresenceCheck(subjectPlayerId: 'p3', subjectName: 'Cara', deadlineMs: 5));
    expect(state.presenceCheck!.subjectName, 'Cara');
    state = apply(state, const PresenceResolved(subjectPlayerId: 'p3', removed: true));
    expect(state.presenceCheck, isNull);
  });
}
