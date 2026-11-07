import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_protocol/poker_protocol.dart';

void main() {
  test('a solo table is a virtual-card freeze-out with no turn timer', () {
    final config = soloRoomConfig(const SoloConfig(bots: 4, skill: BotSkill.normal, ladderHands: 8));
    expect(config.cardMode, CardMode.virtual);
    expect(config.isTournament, isTrue);
    expect(config.turnTimeLimitSeconds, 0);
    expect(config.solo?.bots, 4);
    expect(config.startingChips ~/ config.bigBlind, 75);
  });
}
