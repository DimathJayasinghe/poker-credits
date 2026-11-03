// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'player_action.dart';

class ActionKindMapper extends EnumMapper<ActionKind> {
  ActionKindMapper._();

  static ActionKindMapper? _instance;
  static ActionKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ActionKindMapper._());
    }
    return _instance!;
  }

  static ActionKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ActionKind decode(dynamic value) {
    switch (value) {
      case r'FOLD':
        return ActionKind.fold;
      case r'CHECK':
        return ActionKind.check;
      case r'CALL':
        return ActionKind.call;
      case r'BET':
        return ActionKind.bet;
      case r'RAISE':
        return ActionKind.raise;
      case r'UNKNOWN':
        return ActionKind.unknown;
      default:
        return ActionKind.values[5];
    }
  }

  @override
  dynamic encode(ActionKind self) {
    switch (self) {
      case ActionKind.fold:
        return r'FOLD';
      case ActionKind.check:
        return r'CHECK';
      case ActionKind.call:
        return r'CALL';
      case ActionKind.bet:
        return r'BET';
      case ActionKind.raise:
        return r'RAISE';
      case ActionKind.unknown:
        return r'UNKNOWN';
    }
  }
}

extension ActionKindMapperExtension on ActionKind {
  String toValue() {
    ActionKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ActionKind>(this) as String;
  }
}

class PlayerActionMapper extends ClassMapperBase<PlayerAction> {
  PlayerActionMapper._();

  static PlayerActionMapper? _instance;
  static PlayerActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlayerActionMapper._());
      FoldActionMapper.ensureInitialized();
      CheckActionMapper.ensureInitialized();
      CallActionMapper.ensureInitialized();
      RaiseActionMapper.ensureInitialized();
      AllInActionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PlayerAction';

  @override
  final MappableFields<PlayerAction> fields = const {};
  @override
  final bool ignoreNull = true;

  static PlayerAction _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'PlayerAction',
      'kind',
      '${data.value['kind']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlayerAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlayerAction>(map);
  }

  static PlayerAction fromJson(String json) {
    return ensureInitialized().decodeJson<PlayerAction>(json);
  }
}

mixin PlayerActionMappable {
  String toJson();
  Map<String, dynamic> toMap();
  PlayerActionCopyWith<PlayerAction, PlayerAction, PlayerAction> get copyWith;
}

abstract class PlayerActionCopyWith<$R, $In extends PlayerAction, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  PlayerActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class FoldActionMapper extends SubClassMapperBase<FoldAction> {
  FoldActionMapper._();

  static FoldActionMapper? _instance;
  static FoldActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FoldActionMapper._());
      PlayerActionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'FoldAction';

  @override
  final MappableFields<FoldAction> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'FOLD';
  @override
  late final ClassMapperBase superMapper =
      PlayerActionMapper.ensureInitialized();

  static FoldAction _instantiate(DecodingData data) {
    return FoldAction();
  }

  @override
  final Function instantiate = _instantiate;

  static FoldAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FoldAction>(map);
  }

  static FoldAction fromJson(String json) {
    return ensureInitialized().decodeJson<FoldAction>(json);
  }
}

mixin FoldActionMappable {
  String toJson() {
    return FoldActionMapper.ensureInitialized().encodeJson<FoldAction>(
      this as FoldAction,
    );
  }

  Map<String, dynamic> toMap() {
    return FoldActionMapper.ensureInitialized().encodeMap<FoldAction>(
      this as FoldAction,
    );
  }

  FoldActionCopyWith<FoldAction, FoldAction, FoldAction> get copyWith =>
      _FoldActionCopyWithImpl<FoldAction, FoldAction>(
        this as FoldAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FoldActionMapper.ensureInitialized().stringifyValue(
      this as FoldAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return FoldActionMapper.ensureInitialized().equalsValue(
      this as FoldAction,
      other,
    );
  }

  @override
  int get hashCode {
    return FoldActionMapper.ensureInitialized().hashValue(this as FoldAction);
  }
}

extension FoldActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FoldAction, $Out> {
  FoldActionCopyWith<$R, FoldAction, $Out> get $asFoldAction =>
      $base.as((v, t, t2) => _FoldActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FoldActionCopyWith<$R, $In extends FoldAction, $Out>
    implements PlayerActionCopyWith<$R, $In, $Out> {
  @override
  $R call();
  FoldActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FoldActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FoldAction, $Out>
    implements FoldActionCopyWith<$R, FoldAction, $Out> {
  _FoldActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FoldAction> $mapper =
      FoldActionMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  FoldAction $make(CopyWithData data) => FoldAction();

  @override
  FoldActionCopyWith<$R2, FoldAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FoldActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CheckActionMapper extends SubClassMapperBase<CheckAction> {
  CheckActionMapper._();

  static CheckActionMapper? _instance;
  static CheckActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CheckActionMapper._());
      PlayerActionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CheckAction';

  @override
  final MappableFields<CheckAction> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'CHECK';
  @override
  late final ClassMapperBase superMapper =
      PlayerActionMapper.ensureInitialized();

  static CheckAction _instantiate(DecodingData data) {
    return CheckAction();
  }

  @override
  final Function instantiate = _instantiate;

  static CheckAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CheckAction>(map);
  }

  static CheckAction fromJson(String json) {
    return ensureInitialized().decodeJson<CheckAction>(json);
  }
}

mixin CheckActionMappable {
  String toJson() {
    return CheckActionMapper.ensureInitialized().encodeJson<CheckAction>(
      this as CheckAction,
    );
  }

  Map<String, dynamic> toMap() {
    return CheckActionMapper.ensureInitialized().encodeMap<CheckAction>(
      this as CheckAction,
    );
  }

  CheckActionCopyWith<CheckAction, CheckAction, CheckAction> get copyWith =>
      _CheckActionCopyWithImpl<CheckAction, CheckAction>(
        this as CheckAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CheckActionMapper.ensureInitialized().stringifyValue(
      this as CheckAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return CheckActionMapper.ensureInitialized().equalsValue(
      this as CheckAction,
      other,
    );
  }

  @override
  int get hashCode {
    return CheckActionMapper.ensureInitialized().hashValue(this as CheckAction);
  }
}

extension CheckActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CheckAction, $Out> {
  CheckActionCopyWith<$R, CheckAction, $Out> get $asCheckAction =>
      $base.as((v, t, t2) => _CheckActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CheckActionCopyWith<$R, $In extends CheckAction, $Out>
    implements PlayerActionCopyWith<$R, $In, $Out> {
  @override
  $R call();
  CheckActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CheckActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CheckAction, $Out>
    implements CheckActionCopyWith<$R, CheckAction, $Out> {
  _CheckActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CheckAction> $mapper =
      CheckActionMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  CheckAction $make(CopyWithData data) => CheckAction();

  @override
  CheckActionCopyWith<$R2, CheckAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CheckActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CallActionMapper extends SubClassMapperBase<CallAction> {
  CallActionMapper._();

  static CallActionMapper? _instance;
  static CallActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CallActionMapper._());
      PlayerActionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CallAction';

  @override
  final MappableFields<CallAction> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'CALL';
  @override
  late final ClassMapperBase superMapper =
      PlayerActionMapper.ensureInitialized();

  static CallAction _instantiate(DecodingData data) {
    return CallAction();
  }

  @override
  final Function instantiate = _instantiate;

  static CallAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CallAction>(map);
  }

  static CallAction fromJson(String json) {
    return ensureInitialized().decodeJson<CallAction>(json);
  }
}

mixin CallActionMappable {
  String toJson() {
    return CallActionMapper.ensureInitialized().encodeJson<CallAction>(
      this as CallAction,
    );
  }

  Map<String, dynamic> toMap() {
    return CallActionMapper.ensureInitialized().encodeMap<CallAction>(
      this as CallAction,
    );
  }

  CallActionCopyWith<CallAction, CallAction, CallAction> get copyWith =>
      _CallActionCopyWithImpl<CallAction, CallAction>(
        this as CallAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CallActionMapper.ensureInitialized().stringifyValue(
      this as CallAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return CallActionMapper.ensureInitialized().equalsValue(
      this as CallAction,
      other,
    );
  }

  @override
  int get hashCode {
    return CallActionMapper.ensureInitialized().hashValue(this as CallAction);
  }
}

extension CallActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CallAction, $Out> {
  CallActionCopyWith<$R, CallAction, $Out> get $asCallAction =>
      $base.as((v, t, t2) => _CallActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CallActionCopyWith<$R, $In extends CallAction, $Out>
    implements PlayerActionCopyWith<$R, $In, $Out> {
  @override
  $R call();
  CallActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CallActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CallAction, $Out>
    implements CallActionCopyWith<$R, CallAction, $Out> {
  _CallActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CallAction> $mapper =
      CallActionMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  CallAction $make(CopyWithData data) => CallAction();

  @override
  CallActionCopyWith<$R2, CallAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CallActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RaiseActionMapper extends SubClassMapperBase<RaiseAction> {
  RaiseActionMapper._();

  static RaiseActionMapper? _instance;
  static RaiseActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RaiseActionMapper._());
      PlayerActionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RaiseAction';

  static int _$toAmount(RaiseAction v) => v.toAmount;
  static const Field<RaiseAction, int> _f$toAmount = Field(
    'toAmount',
    _$toAmount,
  );

  @override
  final MappableFields<RaiseAction> fields = const {#toAmount: _f$toAmount};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'RAISE';
  @override
  late final ClassMapperBase superMapper =
      PlayerActionMapper.ensureInitialized();

  static RaiseAction _instantiate(DecodingData data) {
    return RaiseAction(toAmount: data.dec(_f$toAmount));
  }

  @override
  final Function instantiate = _instantiate;

  static RaiseAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RaiseAction>(map);
  }

  static RaiseAction fromJson(String json) {
    return ensureInitialized().decodeJson<RaiseAction>(json);
  }
}

mixin RaiseActionMappable {
  String toJson() {
    return RaiseActionMapper.ensureInitialized().encodeJson<RaiseAction>(
      this as RaiseAction,
    );
  }

  Map<String, dynamic> toMap() {
    return RaiseActionMapper.ensureInitialized().encodeMap<RaiseAction>(
      this as RaiseAction,
    );
  }

  RaiseActionCopyWith<RaiseAction, RaiseAction, RaiseAction> get copyWith =>
      _RaiseActionCopyWithImpl<RaiseAction, RaiseAction>(
        this as RaiseAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RaiseActionMapper.ensureInitialized().stringifyValue(
      this as RaiseAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return RaiseActionMapper.ensureInitialized().equalsValue(
      this as RaiseAction,
      other,
    );
  }

  @override
  int get hashCode {
    return RaiseActionMapper.ensureInitialized().hashValue(this as RaiseAction);
  }
}

extension RaiseActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RaiseAction, $Out> {
  RaiseActionCopyWith<$R, RaiseAction, $Out> get $asRaiseAction =>
      $base.as((v, t, t2) => _RaiseActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RaiseActionCopyWith<$R, $In extends RaiseAction, $Out>
    implements PlayerActionCopyWith<$R, $In, $Out> {
  @override
  $R call({int? toAmount});
  RaiseActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RaiseActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RaiseAction, $Out>
    implements RaiseActionCopyWith<$R, RaiseAction, $Out> {
  _RaiseActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RaiseAction> $mapper =
      RaiseActionMapper.ensureInitialized();
  @override
  $R call({int? toAmount}) =>
      $apply(FieldCopyWithData({if (toAmount != null) #toAmount: toAmount}));
  @override
  RaiseAction $make(CopyWithData data) =>
      RaiseAction(toAmount: data.get(#toAmount, or: $value.toAmount));

  @override
  RaiseActionCopyWith<$R2, RaiseAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RaiseActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AllInActionMapper extends SubClassMapperBase<AllInAction> {
  AllInActionMapper._();

  static AllInActionMapper? _instance;
  static AllInActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AllInActionMapper._());
      PlayerActionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'AllInAction';

  @override
  final MappableFields<AllInAction> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'ALL_IN';
  @override
  late final ClassMapperBase superMapper =
      PlayerActionMapper.ensureInitialized();

  static AllInAction _instantiate(DecodingData data) {
    return AllInAction();
  }

  @override
  final Function instantiate = _instantiate;

  static AllInAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AllInAction>(map);
  }

  static AllInAction fromJson(String json) {
    return ensureInitialized().decodeJson<AllInAction>(json);
  }
}

mixin AllInActionMappable {
  String toJson() {
    return AllInActionMapper.ensureInitialized().encodeJson<AllInAction>(
      this as AllInAction,
    );
  }

  Map<String, dynamic> toMap() {
    return AllInActionMapper.ensureInitialized().encodeMap<AllInAction>(
      this as AllInAction,
    );
  }

  AllInActionCopyWith<AllInAction, AllInAction, AllInAction> get copyWith =>
      _AllInActionCopyWithImpl<AllInAction, AllInAction>(
        this as AllInAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AllInActionMapper.ensureInitialized().stringifyValue(
      this as AllInAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return AllInActionMapper.ensureInitialized().equalsValue(
      this as AllInAction,
      other,
    );
  }

  @override
  int get hashCode {
    return AllInActionMapper.ensureInitialized().hashValue(this as AllInAction);
  }
}

extension AllInActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AllInAction, $Out> {
  AllInActionCopyWith<$R, AllInAction, $Out> get $asAllInAction =>
      $base.as((v, t, t2) => _AllInActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AllInActionCopyWith<$R, $In extends AllInAction, $Out>
    implements PlayerActionCopyWith<$R, $In, $Out> {
  @override
  $R call();
  AllInActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AllInActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AllInAction, $Out>
    implements AllInActionCopyWith<$R, AllInAction, $Out> {
  _AllInActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AllInAction> $mapper =
      AllInActionMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  AllInAction $make(CopyWithData data) => AllInAction();

  @override
  AllInActionCopyWith<$R2, AllInAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AllInActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LegalActionsMapper extends ClassMapperBase<LegalActions> {
  LegalActionsMapper._();

  static LegalActionsMapper? _instance;
  static LegalActionsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LegalActionsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LegalActions';

  static bool _$canFold(LegalActions v) => v.canFold;
  static const Field<LegalActions, bool> _f$canFold = Field(
    'canFold',
    _$canFold,
  );
  static bool _$canCheck(LegalActions v) => v.canCheck;
  static const Field<LegalActions, bool> _f$canCheck = Field(
    'canCheck',
    _$canCheck,
  );
  static bool _$canCall(LegalActions v) => v.canCall;
  static const Field<LegalActions, bool> _f$canCall = Field(
    'canCall',
    _$canCall,
  );
  static int _$callAmount(LegalActions v) => v.callAmount;
  static const Field<LegalActions, int> _f$callAmount = Field(
    'callAmount',
    _$callAmount,
  );
  static bool _$canRaise(LegalActions v) => v.canRaise;
  static const Field<LegalActions, bool> _f$canRaise = Field(
    'canRaise',
    _$canRaise,
  );
  static int _$minRaiseTo(LegalActions v) => v.minRaiseTo;
  static const Field<LegalActions, int> _f$minRaiseTo = Field(
    'minRaiseTo',
    _$minRaiseTo,
  );
  static int _$maxRaiseTo(LegalActions v) => v.maxRaiseTo;
  static const Field<LegalActions, int> _f$maxRaiseTo = Field(
    'maxRaiseTo',
    _$maxRaiseTo,
  );

  @override
  final MappableFields<LegalActions> fields = const {
    #canFold: _f$canFold,
    #canCheck: _f$canCheck,
    #canCall: _f$canCall,
    #callAmount: _f$callAmount,
    #canRaise: _f$canRaise,
    #minRaiseTo: _f$minRaiseTo,
    #maxRaiseTo: _f$maxRaiseTo,
  };
  @override
  final bool ignoreNull = true;

  static LegalActions _instantiate(DecodingData data) {
    return LegalActions(
      canFold: data.dec(_f$canFold),
      canCheck: data.dec(_f$canCheck),
      canCall: data.dec(_f$canCall),
      callAmount: data.dec(_f$callAmount),
      canRaise: data.dec(_f$canRaise),
      minRaiseTo: data.dec(_f$minRaiseTo),
      maxRaiseTo: data.dec(_f$maxRaiseTo),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LegalActions fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LegalActions>(map);
  }

  static LegalActions fromJson(String json) {
    return ensureInitialized().decodeJson<LegalActions>(json);
  }
}

mixin LegalActionsMappable {
  String toJson() {
    return LegalActionsMapper.ensureInitialized().encodeJson<LegalActions>(
      this as LegalActions,
    );
  }

  Map<String, dynamic> toMap() {
    return LegalActionsMapper.ensureInitialized().encodeMap<LegalActions>(
      this as LegalActions,
    );
  }

  LegalActionsCopyWith<LegalActions, LegalActions, LegalActions> get copyWith =>
      _LegalActionsCopyWithImpl<LegalActions, LegalActions>(
        this as LegalActions,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LegalActionsMapper.ensureInitialized().stringifyValue(
      this as LegalActions,
    );
  }

  @override
  bool operator ==(Object other) {
    return LegalActionsMapper.ensureInitialized().equalsValue(
      this as LegalActions,
      other,
    );
  }

  @override
  int get hashCode {
    return LegalActionsMapper.ensureInitialized().hashValue(
      this as LegalActions,
    );
  }
}

extension LegalActionsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LegalActions, $Out> {
  LegalActionsCopyWith<$R, LegalActions, $Out> get $asLegalActions =>
      $base.as((v, t, t2) => _LegalActionsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LegalActionsCopyWith<$R, $In extends LegalActions, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    bool? canFold,
    bool? canCheck,
    bool? canCall,
    int? callAmount,
    bool? canRaise,
    int? minRaiseTo,
    int? maxRaiseTo,
  });
  LegalActionsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LegalActionsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LegalActions, $Out>
    implements LegalActionsCopyWith<$R, LegalActions, $Out> {
  _LegalActionsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LegalActions> $mapper =
      LegalActionsMapper.ensureInitialized();
  @override
  $R call({
    bool? canFold,
    bool? canCheck,
    bool? canCall,
    int? callAmount,
    bool? canRaise,
    int? minRaiseTo,
    int? maxRaiseTo,
  }) => $apply(
    FieldCopyWithData({
      if (canFold != null) #canFold: canFold,
      if (canCheck != null) #canCheck: canCheck,
      if (canCall != null) #canCall: canCall,
      if (callAmount != null) #callAmount: callAmount,
      if (canRaise != null) #canRaise: canRaise,
      if (minRaiseTo != null) #minRaiseTo: minRaiseTo,
      if (maxRaiseTo != null) #maxRaiseTo: maxRaiseTo,
    }),
  );
  @override
  LegalActions $make(CopyWithData data) => LegalActions(
    canFold: data.get(#canFold, or: $value.canFold),
    canCheck: data.get(#canCheck, or: $value.canCheck),
    canCall: data.get(#canCall, or: $value.canCall),
    callAmount: data.get(#callAmount, or: $value.callAmount),
    canRaise: data.get(#canRaise, or: $value.canRaise),
    minRaiseTo: data.get(#minRaiseTo, or: $value.minRaiseTo),
    maxRaiseTo: data.get(#maxRaiseTo, or: $value.maxRaiseTo),
  );

  @override
  LegalActionsCopyWith<$R2, LegalActions, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LegalActionsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

