import 'package:flutter/foundation.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// What happened to the player over one single-player game, counted from the room views the
/// server sent. Nothing here decides anything about poker: it only tallies what the server paid.
///
/// The count starts when the game is opened, so a game resumed after the app was closed counts the
/// hands played since then.
@immutable
class SoloStats {
  const SoloStats({this.handsPlayed = 0, this.handsWon = 0, this.biggestWin = 0, this.bestHand, this.countedHand = 0});

  /// Hands that were paid out while the player was at the table.
  final int handsPlayed;

  /// Hands in which the player received a share of a pot.
  final int handsWon;

  /// The most chips the player took from one hand.
  final int biggestWin;

  /// The best hand the player showed at a showdown.
  final HandCategory? bestHand;

  /// The last hand already counted, so a view that is sent again is not counted twice.
  final int countedHand;

  /// These stats after [view], or the same object when [view] holds nothing new.
  SoloStats observe(RoomView view, String? myId) {
    final result = view.result;
    if (myId == null || result == null || view.handNumber <= countedHand) return this;
    var won = 0;
    for (final pot in result.pots) {
      for (final share in pot.shares) {
        if (share.playerId == myId) won += share.amount;
      }
    }
    HandCategory? best = bestHand;
    for (final reveal in view.reveals) {
      if (reveal.playerId == myId && (best == null || reveal.category.index > best.index)) best = reveal.category;
    }
    return SoloStats(
      handsPlayed: handsPlayed + 1,
      handsWon: handsWon + (won > 0 ? 1 : 0),
      biggestWin: won > biggestWin ? won : biggestWin,
      bestHand: best,
      countedHand: view.handNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoloStats &&
      other.handsPlayed == handsPlayed &&
      other.handsWon == handsWon &&
      other.biggestWin == biggestWin &&
      other.bestHand == bestHand &&
      other.countedHand == countedHand;

  @override
  int get hashCode => Object.hash(handsPlayed, handsWon, biggestWin, bestHand, countedHand);
}

/// How a finished single-player game ended for the player.
@immutable
class SoloResult {
  const SoloResult({required this.place, required this.of, required this.stats});

  /// 1 = won.
  final int place;

  /// Players who started the game.
  final int of;
  final SoloStats stats;

  bool get won => place == 1;

  /// The result once the player is in the view's finishing order; `null` while the game goes on.
  static SoloResult? from(RoomView view, String? myId, SoloStats stats) {
    if (myId == null) return null;
    for (final finish in view.finishOrder) {
      if (finish.playerId != myId) continue;
      // The server lists a player when they go out, so when I am the first out the order holds only me.
      // The first to go out takes the last place, so the biggest place listed is how many started.
      final started = view.finishOrder.fold<int>(0, (most, f) => f.place > most ? f.place : most);
      return SoloResult(place: finish.place, of: started, stats: stats);
    }
    return null;
  }
}

/// Who has gone out since the last look, as `(name, place)` pairs in the order it happened.
///
/// [seen] is how many finishing places the screen already announced. The first look at a game
/// announces nothing old: pass the current length as [seen] then.
List<Finish> newlyOut(List<Finish> finishOrder, int seen) => seen >= finishOrder.length ? const <Finish>[] : finishOrder.sublist(seen);
