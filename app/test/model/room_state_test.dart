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

  group('who is connected', () {
    SeatView seat(int index, String id, {required bool connected}) => SeatView(
      seatIndex: index,
      playerId: id,
      name: 'P$index',
      chips: 1000,
      streetBet: 0,
      hasFolded: false,
      isAllIn: false,
      isSittingOut: false,
      isConnected: connected,
    );

    test('a connection notice flips that seat and nothing else, without a new snapshot', () {
      var state = apply(
        const RoomState(),
        snapshot(version: 3, view: roomView(seats: <SeatView>[seat(0, 'host', connected: true), seat(1, 'ana', connected: false)])),
      );
      state = apply(state, const PlayerConnection(seatIndex: 1, playerId: 'ana', isConnected: true));
      expect(state.view!.seats.map((s) => s.isConnected), <bool>[true, true], reason: 'the host sees a guest who just joined');
      expect(state.stateVersion, 3, reason: 'a presence notice does not move the state version');

      state = apply(state, const PlayerConnection(seatIndex: 1, playerId: 'ana', isConnected: false));
      expect(state.view!.seats.map((s) => s.isConnected), <bool>[true, false], reason: 'and sees her go');
    });

    test('a notice for a seat held by someone else, or for no view, changes nothing', () {
      final before = apply(const RoomState(), snapshot(version: 3, view: roomView(seats: <SeatView>[seat(1, 'ana', connected: false)])));
      final after = apply(before, const PlayerConnection(seatIndex: 1, playerId: 'bob', isConnected: true));
      expect(after.view!.seats.single.isConnected, isFalse, reason: 'the seat belongs to another player now');
      expect(apply(const RoomState(), const PlayerConnection(seatIndex: 1, playerId: 'ana', isConnected: true)).view, isNull);
    });
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

  group('showsCards (is this a virtual hand?)', () {
    test('a real-cards room never does', () {
      final state = apply(const RoomState(), snapshot(view: roomView(hand: 1, seats: <SeatView>[seatView(0, 'A'), seatView(1, 'B')])));
      expect(state.showsCards, isFalse);
    });

    test('a seat holding cards, a board, a result or my own cards each make it one', () {
      final held = apply(const RoomState(), snapshot(view: roomView(hand: 1, seats: <SeatView>[seatView(0, 'A', hasCards: true)])));
      expect(held.showsCards, isTrue);
      final board = apply(const RoomState(), snapshot(view: roomView(hand: 1, board: <PokerCard>[card('As'), card('Kd'), card('2c')])));
      expect(board.showsCards, isTrue);
      const paid = HandResult(uncontested: true, pots: <PotResult>[]);
      final result = apply(const RoomState(), snapshot(view: roomView(hand: 1, result: paid)));
      expect(result.showsCards, isTrue);
      final mine = apply(apply(const RoomState(), snapshot(view: roomView(hand: 2))), holeCards('As', 'Kd', hand: 2));
      expect(mine.showsCards, isTrue, reason: 'a player who folded still holds the hand they were dealt');
    });

    test('without a view it does not', () => expect(const RoomState().showsCards, isFalse));
  });

  group('hole cards', () {
    test('hole cards survive a snapshot of the same hand', () {
      var state = apply(const RoomState(), snapshot(version: 1, view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      expect(state.visibleHoleCards, [card('As'), card('Kd')]);
      state = apply(state, snapshot(version: 2, view: roomView(hand: 3)));
      expect(state.visibleHoleCards, [card('As'), card('Kd')], reason: 'a reconnect must not blink the cards away');
    });

    test('a higher hand number replaces hole cards', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      state = apply(state, StateUpdate(stateVersion: 2, view: roomView(hand: 4)));
      expect(state.visibleHoleCards, isNull, reason: 'between the hand 4 update and its cards the dock shows backs');
      state = apply(state, holeCards('2c', '7h', hand: 4));
      expect(state.visibleHoleCards, [card('2c'), card('7h')]);
    });

    test('cards that arrive before their hand view wait for it', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('2c', '7h', hand: 4));
      expect(state.visibleHoleCards, isNull);
      state = apply(state, StateUpdate(stateVersion: 2, view: roomView(hand: 4)));
      expect(state.visibleHoleCards, [card('2c'), card('7h')]);
    });

    test('an older hand\'s cards never replace newer ones', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 5)));
      state = apply(state, holeCards('2c', '7h', hand: 5));
      state = apply(state, holeCards('As', 'Kd', hand: 4));
      expect(state.visibleHoleCards, [card('2c'), card('7h')]);
    });

    test('a lobby view clears hole cards', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      state = apply(state, StateUpdate(stateVersion: 2, view: roomView(hand: 3, phase: WirePhase.lobby)));
      expect(state.holeCards, isNull);
    });

    test('duplicate hole cards are a no-op', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      final again = apply(state, holeCards('As', 'Kd', hand: 3));
      expect(identical(again, state), isTrue);
    });

    test('stale hole cards are not shown after a new deal', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      state = apply(state, snapshot(version: 2, view: roomView(hand: 4)));
      expect(state.visibleHoleCards, isNull);
      expect(state.holeCards, isNull, reason: 'a newer view drops the old hand\'s cards entirely');
    });

    test('the cards stay readable through the next-hand screen of the same hand', () {
      var state = apply(const RoomState(), snapshot(view: roomView(hand: 3)));
      state = apply(state, holeCards('As', 'Kd', hand: 3));
      state = apply(state, StateUpdate(stateVersion: 2, view: roomView(hand: 3, phase: WirePhase.nextHandPrep)));
      expect(state.visibleHoleCards, [card('As'), card('Kd')]);
    });
  });
}
