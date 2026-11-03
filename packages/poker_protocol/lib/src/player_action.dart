import 'package:dart_mappable/dart_mappable.dart';

import 'wire_case.dart';

part 'player_action.mapper.dart';

/// What a player does on their turn: `{"kind":"RAISE","toAmount":60}`.
@MappableClass(discriminatorKey: 'kind', caseStyle: screamingSnake)
sealed class PlayerAction with PlayerActionMappable {
  const PlayerAction();
}

@MappableClass(discriminatorValue: 'FOLD')
class FoldAction extends PlayerAction with FoldActionMappable {
  const FoldAction();
}

@MappableClass(discriminatorValue: 'CHECK')
class CheckAction extends PlayerAction with CheckActionMappable {
  const CheckAction();
}

@MappableClass(discriminatorValue: 'CALL')
class CallAction extends PlayerAction with CallActionMappable {
  const CallAction();
}

/// Raise (or open the betting) so the street bet becomes [toAmount].
@MappableClass(discriminatorValue: 'RAISE')
class RaiseAction extends PlayerAction with RaiseActionMappable {
  const RaiseAction({required this.toAmount});

  final int toAmount;
}

@MappableClass(discriminatorValue: 'ALL_IN')
class AllInAction extends PlayerAction with AllInActionMappable {
  const AllInAction();
}

/// What a performed action was, as reported in `ACTION_PERFORMED`.
@MappableEnum(caseStyle: screamingSnake, defaultValue: ActionKind.unknown)
enum ActionKind { fold, check, call, bet, raise, unknown }

/// What the player on turn may do now (`TURN_PROMPT.legal`).
@MappableClass()
class LegalActions with LegalActionsMappable {
  const LegalActions({
    required this.canFold,
    required this.canCheck,
    required this.canCall,
    required this.callAmount,
    required this.canRaise,
    required this.minRaiseTo,
    required this.maxRaiseTo,
  });

  final bool canFold;
  final bool canCheck;
  final bool canCall;
  final int callAmount;
  final bool canRaise;
  final int minRaiseTo;
  final int maxRaiseTo;
}
