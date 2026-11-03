// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'room_view.dart';

class RoleMapper extends EnumMapper<Role> {
  RoleMapper._();

  static RoleMapper? _instance;
  static RoleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoleMapper._());
    }
    return _instance!;
  }

  static Role fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  Role decode(dynamic value) {
    switch (value) {
      case r'HOST':
        return Role.host;
      case r'PLAYER':
        return Role.player;
      case r'SPECTATOR':
        return Role.spectator;
      default:
        return Role.values[2];
    }
  }

  @override
  dynamic encode(Role self) {
    switch (self) {
      case Role.host:
        return r'HOST';
      case Role.player:
        return r'PLAYER';
      case Role.spectator:
        return r'SPECTATOR';
    }
  }
}

extension RoleMapperExtension on Role {
  String toValue() {
    RoleMapper.ensureInitialized();
    return MapperContainer.globals.toValue<Role>(this) as String;
  }
}

class WirePhaseMapper extends EnumMapper<WirePhase> {
  WirePhaseMapper._();

  static WirePhaseMapper? _instance;
  static WirePhaseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = WirePhaseMapper._());
    }
    return _instance!;
  }

  static WirePhase fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  WirePhase decode(dynamic value) {
    switch (value) {
      case r'LOBBY':
        return WirePhase.lobby;
      case r'PRE_FLOP':
        return WirePhase.preFlop;
      case r'FLOP':
        return WirePhase.flop;
      case r'TURN':
        return WirePhase.turn;
      case r'RIVER':
        return WirePhase.river;
      case r'ALL_IN_RUNOUT':
        return WirePhase.allInRunout;
      case r'SHOWDOWN':
        return WirePhase.showdown;
      case r'NEXT_HAND_PREP':
        return WirePhase.nextHandPrep;
      case r'PAUSED':
        return WirePhase.paused;
      default:
        return WirePhase.values[0];
    }
  }

  @override
  dynamic encode(WirePhase self) {
    switch (self) {
      case WirePhase.lobby:
        return r'LOBBY';
      case WirePhase.preFlop:
        return r'PRE_FLOP';
      case WirePhase.flop:
        return r'FLOP';
      case WirePhase.turn:
        return r'TURN';
      case WirePhase.river:
        return r'RIVER';
      case WirePhase.allInRunout:
        return r'ALL_IN_RUNOUT';
      case WirePhase.showdown:
        return r'SHOWDOWN';
      case WirePhase.nextHandPrep:
        return r'NEXT_HAND_PREP';
      case WirePhase.paused:
        return r'PAUSED';
    }
  }
}

extension WirePhaseMapperExtension on WirePhase {
  String toValue() {
    WirePhaseMapper.ensureInitialized();
    return MapperContainer.globals.toValue<WirePhase>(this) as String;
  }
}

class SeatViewMapper extends ClassMapperBase<SeatView> {
  SeatViewMapper._();

  static SeatViewMapper? _instance;
  static SeatViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SeatViewMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SeatView';

  static int _$seatIndex(SeatView v) => v.seatIndex;
  static const Field<SeatView, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );
  static String _$playerId(SeatView v) => v.playerId;
  static const Field<SeatView, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static String _$name(SeatView v) => v.name;
  static const Field<SeatView, String> _f$name = Field('name', _$name);
  static int _$chips(SeatView v) => v.chips;
  static const Field<SeatView, int> _f$chips = Field('chips', _$chips);
  static int _$streetBet(SeatView v) => v.streetBet;
  static const Field<SeatView, int> _f$streetBet = Field(
    'streetBet',
    _$streetBet,
  );
  static bool _$hasFolded(SeatView v) => v.hasFolded;
  static const Field<SeatView, bool> _f$hasFolded = Field(
    'hasFolded',
    _$hasFolded,
  );
  static bool _$isAllIn(SeatView v) => v.isAllIn;
  static const Field<SeatView, bool> _f$isAllIn = Field('isAllIn', _$isAllIn);
  static bool _$isSittingOut(SeatView v) => v.isSittingOut;
  static const Field<SeatView, bool> _f$isSittingOut = Field(
    'isSittingOut',
    _$isSittingOut,
  );
  static bool _$isConnected(SeatView v) => v.isConnected;
  static const Field<SeatView, bool> _f$isConnected = Field(
    'isConnected',
    _$isConnected,
  );

  @override
  final MappableFields<SeatView> fields = const {
    #seatIndex: _f$seatIndex,
    #playerId: _f$playerId,
    #name: _f$name,
    #chips: _f$chips,
    #streetBet: _f$streetBet,
    #hasFolded: _f$hasFolded,
    #isAllIn: _f$isAllIn,
    #isSittingOut: _f$isSittingOut,
    #isConnected: _f$isConnected,
  };
  @override
  final bool ignoreNull = true;

  static SeatView _instantiate(DecodingData data) {
    return SeatView(
      seatIndex: data.dec(_f$seatIndex),
      playerId: data.dec(_f$playerId),
      name: data.dec(_f$name),
      chips: data.dec(_f$chips),
      streetBet: data.dec(_f$streetBet),
      hasFolded: data.dec(_f$hasFolded),
      isAllIn: data.dec(_f$isAllIn),
      isSittingOut: data.dec(_f$isSittingOut),
      isConnected: data.dec(_f$isConnected),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SeatView fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SeatView>(map);
  }

  static SeatView fromJson(String json) {
    return ensureInitialized().decodeJson<SeatView>(json);
  }
}

mixin SeatViewMappable {
  String toJson() {
    return SeatViewMapper.ensureInitialized().encodeJson<SeatView>(
      this as SeatView,
    );
  }

  Map<String, dynamic> toMap() {
    return SeatViewMapper.ensureInitialized().encodeMap<SeatView>(
      this as SeatView,
    );
  }

  SeatViewCopyWith<SeatView, SeatView, SeatView> get copyWith =>
      _SeatViewCopyWithImpl<SeatView, SeatView>(
        this as SeatView,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SeatViewMapper.ensureInitialized().stringifyValue(this as SeatView);
  }

  @override
  bool operator ==(Object other) {
    return SeatViewMapper.ensureInitialized().equalsValue(
      this as SeatView,
      other,
    );
  }

  @override
  int get hashCode {
    return SeatViewMapper.ensureInitialized().hashValue(this as SeatView);
  }
}

extension SeatViewValueCopy<$R, $Out> on ObjectCopyWith<$R, SeatView, $Out> {
  SeatViewCopyWith<$R, SeatView, $Out> get $asSeatView =>
      $base.as((v, t, t2) => _SeatViewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SeatViewCopyWith<$R, $In extends SeatView, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? seatIndex,
    String? playerId,
    String? name,
    int? chips,
    int? streetBet,
    bool? hasFolded,
    bool? isAllIn,
    bool? isSittingOut,
    bool? isConnected,
  });
  SeatViewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SeatViewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SeatView, $Out>
    implements SeatViewCopyWith<$R, SeatView, $Out> {
  _SeatViewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SeatView> $mapper =
      SeatViewMapper.ensureInitialized();
  @override
  $R call({
    int? seatIndex,
    String? playerId,
    String? name,
    int? chips,
    int? streetBet,
    bool? hasFolded,
    bool? isAllIn,
    bool? isSittingOut,
    bool? isConnected,
  }) => $apply(
    FieldCopyWithData({
      if (seatIndex != null) #seatIndex: seatIndex,
      if (playerId != null) #playerId: playerId,
      if (name != null) #name: name,
      if (chips != null) #chips: chips,
      if (streetBet != null) #streetBet: streetBet,
      if (hasFolded != null) #hasFolded: hasFolded,
      if (isAllIn != null) #isAllIn: isAllIn,
      if (isSittingOut != null) #isSittingOut: isSittingOut,
      if (isConnected != null) #isConnected: isConnected,
    }),
  );
  @override
  SeatView $make(CopyWithData data) => SeatView(
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
    playerId: data.get(#playerId, or: $value.playerId),
    name: data.get(#name, or: $value.name),
    chips: data.get(#chips, or: $value.chips),
    streetBet: data.get(#streetBet, or: $value.streetBet),
    hasFolded: data.get(#hasFolded, or: $value.hasFolded),
    isAllIn: data.get(#isAllIn, or: $value.isAllIn),
    isSittingOut: data.get(#isSittingOut, or: $value.isSittingOut),
    isConnected: data.get(#isConnected, or: $value.isConnected),
  );

  @override
  SeatViewCopyWith<$R2, SeatView, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SeatViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PotViewMapper extends ClassMapperBase<PotView> {
  PotViewMapper._();

  static PotViewMapper? _instance;
  static PotViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PotViewMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PotView';

  static int _$tierIndex(PotView v) => v.tierIndex;
  static const Field<PotView, int> _f$tierIndex = Field(
    'tierIndex',
    _$tierIndex,
  );
  static int _$amount(PotView v) => v.amount;
  static const Field<PotView, int> _f$amount = Field('amount', _$amount);
  static List<String> _$eligiblePlayerIds(PotView v) => v.eligiblePlayerIds;
  static const Field<PotView, List<String>> _f$eligiblePlayerIds = Field(
    'eligiblePlayerIds',
    _$eligiblePlayerIds,
  );

  @override
  final MappableFields<PotView> fields = const {
    #tierIndex: _f$tierIndex,
    #amount: _f$amount,
    #eligiblePlayerIds: _f$eligiblePlayerIds,
  };
  @override
  final bool ignoreNull = true;

  static PotView _instantiate(DecodingData data) {
    return PotView(
      tierIndex: data.dec(_f$tierIndex),
      amount: data.dec(_f$amount),
      eligiblePlayerIds: data.dec(_f$eligiblePlayerIds),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PotView fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PotView>(map);
  }

  static PotView fromJson(String json) {
    return ensureInitialized().decodeJson<PotView>(json);
  }
}

mixin PotViewMappable {
  String toJson() {
    return PotViewMapper.ensureInitialized().encodeJson<PotView>(
      this as PotView,
    );
  }

  Map<String, dynamic> toMap() {
    return PotViewMapper.ensureInitialized().encodeMap<PotView>(
      this as PotView,
    );
  }

  PotViewCopyWith<PotView, PotView, PotView> get copyWith =>
      _PotViewCopyWithImpl<PotView, PotView>(
        this as PotView,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PotViewMapper.ensureInitialized().stringifyValue(this as PotView);
  }

  @override
  bool operator ==(Object other) {
    return PotViewMapper.ensureInitialized().equalsValue(
      this as PotView,
      other,
    );
  }

  @override
  int get hashCode {
    return PotViewMapper.ensureInitialized().hashValue(this as PotView);
  }
}

extension PotViewValueCopy<$R, $Out> on ObjectCopyWith<$R, PotView, $Out> {
  PotViewCopyWith<$R, PotView, $Out> get $asPotView =>
      $base.as((v, t, t2) => _PotViewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PotViewCopyWith<$R, $In extends PotView, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get eligiblePlayerIds;
  $R call({int? tierIndex, int? amount, List<String>? eligiblePlayerIds});
  PotViewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PotViewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PotView, $Out>
    implements PotViewCopyWith<$R, PotView, $Out> {
  _PotViewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PotView> $mapper =
      PotViewMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get eligiblePlayerIds => ListCopyWith(
    $value.eligiblePlayerIds,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(eligiblePlayerIds: v),
  );
  @override
  $R call({int? tierIndex, int? amount, List<String>? eligiblePlayerIds}) =>
      $apply(
        FieldCopyWithData({
          if (tierIndex != null) #tierIndex: tierIndex,
          if (amount != null) #amount: amount,
          if (eligiblePlayerIds != null) #eligiblePlayerIds: eligiblePlayerIds,
        }),
      );
  @override
  PotView $make(CopyWithData data) => PotView(
    tierIndex: data.get(#tierIndex, or: $value.tierIndex),
    amount: data.get(#amount, or: $value.amount),
    eligiblePlayerIds: data.get(
      #eligiblePlayerIds,
      or: $value.eligiblePlayerIds,
    ),
  );

  @override
  PotViewCopyWith<$R2, PotView, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PotViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PendingRebuyViewMapper extends ClassMapperBase<PendingRebuyView> {
  PendingRebuyViewMapper._();

  static PendingRebuyViewMapper? _instance;
  static PendingRebuyViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PendingRebuyViewMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PendingRebuyView';

  static String _$playerId(PendingRebuyView v) => v.playerId;
  static const Field<PendingRebuyView, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static int _$amount(PendingRebuyView v) => v.amount;
  static const Field<PendingRebuyView, int> _f$amount = Field(
    'amount',
    _$amount,
  );
  static bool _$approved(PendingRebuyView v) => v.approved;
  static const Field<PendingRebuyView, bool> _f$approved = Field(
    'approved',
    _$approved,
  );

  @override
  final MappableFields<PendingRebuyView> fields = const {
    #playerId: _f$playerId,
    #amount: _f$amount,
    #approved: _f$approved,
  };
  @override
  final bool ignoreNull = true;

  static PendingRebuyView _instantiate(DecodingData data) {
    return PendingRebuyView(
      playerId: data.dec(_f$playerId),
      amount: data.dec(_f$amount),
      approved: data.dec(_f$approved),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PendingRebuyView fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PendingRebuyView>(map);
  }

  static PendingRebuyView fromJson(String json) {
    return ensureInitialized().decodeJson<PendingRebuyView>(json);
  }
}

mixin PendingRebuyViewMappable {
  String toJson() {
    return PendingRebuyViewMapper.ensureInitialized()
        .encodeJson<PendingRebuyView>(this as PendingRebuyView);
  }

  Map<String, dynamic> toMap() {
    return PendingRebuyViewMapper.ensureInitialized()
        .encodeMap<PendingRebuyView>(this as PendingRebuyView);
  }

  PendingRebuyViewCopyWith<PendingRebuyView, PendingRebuyView, PendingRebuyView>
  get copyWith =>
      _PendingRebuyViewCopyWithImpl<PendingRebuyView, PendingRebuyView>(
        this as PendingRebuyView,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PendingRebuyViewMapper.ensureInitialized().stringifyValue(
      this as PendingRebuyView,
    );
  }

  @override
  bool operator ==(Object other) {
    return PendingRebuyViewMapper.ensureInitialized().equalsValue(
      this as PendingRebuyView,
      other,
    );
  }

  @override
  int get hashCode {
    return PendingRebuyViewMapper.ensureInitialized().hashValue(
      this as PendingRebuyView,
    );
  }
}

extension PendingRebuyViewValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PendingRebuyView, $Out> {
  PendingRebuyViewCopyWith<$R, PendingRebuyView, $Out>
  get $asPendingRebuyView =>
      $base.as((v, t, t2) => _PendingRebuyViewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PendingRebuyViewCopyWith<$R, $In extends PendingRebuyView, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? playerId, int? amount, bool? approved});
  PendingRebuyViewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PendingRebuyViewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PendingRebuyView, $Out>
    implements PendingRebuyViewCopyWith<$R, PendingRebuyView, $Out> {
  _PendingRebuyViewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PendingRebuyView> $mapper =
      PendingRebuyViewMapper.ensureInitialized();
  @override
  $R call({String? playerId, int? amount, bool? approved}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (amount != null) #amount: amount,
      if (approved != null) #approved: approved,
    }),
  );
  @override
  PendingRebuyView $make(CopyWithData data) => PendingRebuyView(
    playerId: data.get(#playerId, or: $value.playerId),
    amount: data.get(#amount, or: $value.amount),
    approved: data.get(#approved, or: $value.approved),
  );

  @override
  PendingRebuyViewCopyWith<$R2, PendingRebuyView, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PendingRebuyViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomViewMapper extends ClassMapperBase<RoomView> {
  RoomViewMapper._();

  static RoomViewMapper? _instance;
  static RoomViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomViewMapper._());
      WirePhaseMapper.ensureInitialized();
      PotViewMapper.ensureInitialized();
      SeatViewMapper.ensureInitialized();
      PendingRebuyViewMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'RoomView';

  static String _$roomCode(RoomView v) => v.roomCode;
  static const Field<RoomView, String> _f$roomCode = Field(
    'roomCode',
    _$roomCode,
  );
  static int _$handNumber(RoomView v) => v.handNumber;
  static const Field<RoomView, int> _f$handNumber = Field(
    'handNumber',
    _$handNumber,
  );
  static WirePhase _$phase(RoomView v) => v.phase;
  static const Field<RoomView, WirePhase> _f$phase = Field('phase', _$phase);
  static int? _$dealerSeat(RoomView v) => v.dealerSeat;
  static const Field<RoomView, int> _f$dealerSeat = Field(
    'dealerSeat',
    _$dealerSeat,
    opt: true,
  );
  static int? _$smallBlindSeat(RoomView v) => v.smallBlindSeat;
  static const Field<RoomView, int> _f$smallBlindSeat = Field(
    'smallBlindSeat',
    _$smallBlindSeat,
    opt: true,
  );
  static int? _$bigBlindSeat(RoomView v) => v.bigBlindSeat;
  static const Field<RoomView, int> _f$bigBlindSeat = Field(
    'bigBlindSeat',
    _$bigBlindSeat,
    opt: true,
  );
  static int? _$activeSeat(RoomView v) => v.activeSeat;
  static const Field<RoomView, int> _f$activeSeat = Field(
    'activeSeat',
    _$activeSeat,
    opt: true,
  );
  static int _$currentHighBet(RoomView v) => v.currentHighBet;
  static const Field<RoomView, int> _f$currentHighBet = Field(
    'currentHighBet',
    _$currentHighBet,
  );
  static int _$minRaiseTo(RoomView v) => v.minRaiseTo;
  static const Field<RoomView, int> _f$minRaiseTo = Field(
    'minRaiseTo',
    _$minRaiseTo,
  );
  static int _$totalPot(RoomView v) => v.totalPot;
  static const Field<RoomView, int> _f$totalPot = Field('totalPot', _$totalPot);
  static List<PotView> _$pots(RoomView v) => v.pots;
  static const Field<RoomView, List<PotView>> _f$pots = Field('pots', _$pots);
  static List<SeatView> _$seats(RoomView v) => v.seats;
  static const Field<RoomView, List<SeatView>> _f$seats = Field(
    'seats',
    _$seats,
  );
  static bool _$paused(RoomView v) => v.paused;
  static const Field<RoomView, bool> _f$paused = Field('paused', _$paused);
  static int? _$turnDeadlineMs(RoomView v) => v.turnDeadlineMs;
  static const Field<RoomView, int> _f$turnDeadlineMs = Field(
    'turnDeadlineMs',
    _$turnDeadlineMs,
    opt: true,
  );
  static int _$spectatorCount(RoomView v) => v.spectatorCount;
  static const Field<RoomView, int> _f$spectatorCount = Field(
    'spectatorCount',
    _$spectatorCount,
  );
  static List<PendingRebuyView> _$pendingRebuys(RoomView v) => v.pendingRebuys;
  static const Field<RoomView, List<PendingRebuyView>> _f$pendingRebuys = Field(
    'pendingRebuys',
    _$pendingRebuys,
    opt: true,
    def: const <PendingRebuyView>[],
  );

  @override
  final MappableFields<RoomView> fields = const {
    #roomCode: _f$roomCode,
    #handNumber: _f$handNumber,
    #phase: _f$phase,
    #dealerSeat: _f$dealerSeat,
    #smallBlindSeat: _f$smallBlindSeat,
    #bigBlindSeat: _f$bigBlindSeat,
    #activeSeat: _f$activeSeat,
    #currentHighBet: _f$currentHighBet,
    #minRaiseTo: _f$minRaiseTo,
    #totalPot: _f$totalPot,
    #pots: _f$pots,
    #seats: _f$seats,
    #paused: _f$paused,
    #turnDeadlineMs: _f$turnDeadlineMs,
    #spectatorCount: _f$spectatorCount,
    #pendingRebuys: _f$pendingRebuys,
  };
  @override
  final bool ignoreNull = true;

  static RoomView _instantiate(DecodingData data) {
    return RoomView(
      roomCode: data.dec(_f$roomCode),
      handNumber: data.dec(_f$handNumber),
      phase: data.dec(_f$phase),
      dealerSeat: data.dec(_f$dealerSeat),
      smallBlindSeat: data.dec(_f$smallBlindSeat),
      bigBlindSeat: data.dec(_f$bigBlindSeat),
      activeSeat: data.dec(_f$activeSeat),
      currentHighBet: data.dec(_f$currentHighBet),
      minRaiseTo: data.dec(_f$minRaiseTo),
      totalPot: data.dec(_f$totalPot),
      pots: data.dec(_f$pots),
      seats: data.dec(_f$seats),
      paused: data.dec(_f$paused),
      turnDeadlineMs: data.dec(_f$turnDeadlineMs),
      spectatorCount: data.dec(_f$spectatorCount),
      pendingRebuys: data.dec(_f$pendingRebuys),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RoomView fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomView>(map);
  }

  static RoomView fromJson(String json) {
    return ensureInitialized().decodeJson<RoomView>(json);
  }
}

mixin RoomViewMappable {
  String toJson() {
    return RoomViewMapper.ensureInitialized().encodeJson<RoomView>(
      this as RoomView,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomViewMapper.ensureInitialized().encodeMap<RoomView>(
      this as RoomView,
    );
  }

  RoomViewCopyWith<RoomView, RoomView, RoomView> get copyWith =>
      _RoomViewCopyWithImpl<RoomView, RoomView>(
        this as RoomView,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RoomViewMapper.ensureInitialized().stringifyValue(this as RoomView);
  }

  @override
  bool operator ==(Object other) {
    return RoomViewMapper.ensureInitialized().equalsValue(
      this as RoomView,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomViewMapper.ensureInitialized().hashValue(this as RoomView);
  }
}

extension RoomViewValueCopy<$R, $Out> on ObjectCopyWith<$R, RoomView, $Out> {
  RoomViewCopyWith<$R, RoomView, $Out> get $asRoomView =>
      $base.as((v, t, t2) => _RoomViewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomViewCopyWith<$R, $In extends RoomView, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, PotView, PotViewCopyWith<$R, PotView, PotView>> get pots;
  ListCopyWith<$R, SeatView, SeatViewCopyWith<$R, SeatView, SeatView>>
  get seats;
  ListCopyWith<
    $R,
    PendingRebuyView,
    PendingRebuyViewCopyWith<$R, PendingRebuyView, PendingRebuyView>
  >
  get pendingRebuys;
  $R call({
    String? roomCode,
    int? handNumber,
    WirePhase? phase,
    int? dealerSeat,
    int? smallBlindSeat,
    int? bigBlindSeat,
    int? activeSeat,
    int? currentHighBet,
    int? minRaiseTo,
    int? totalPot,
    List<PotView>? pots,
    List<SeatView>? seats,
    bool? paused,
    int? turnDeadlineMs,
    int? spectatorCount,
    List<PendingRebuyView>? pendingRebuys,
  });
  RoomViewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomViewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomView, $Out>
    implements RoomViewCopyWith<$R, RoomView, $Out> {
  _RoomViewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomView> $mapper =
      RoomViewMapper.ensureInitialized();
  @override
  ListCopyWith<$R, PotView, PotViewCopyWith<$R, PotView, PotView>> get pots =>
      ListCopyWith(
        $value.pots,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(pots: v),
      );
  @override
  ListCopyWith<$R, SeatView, SeatViewCopyWith<$R, SeatView, SeatView>>
  get seats => ListCopyWith(
    $value.seats,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(seats: v),
  );
  @override
  ListCopyWith<
    $R,
    PendingRebuyView,
    PendingRebuyViewCopyWith<$R, PendingRebuyView, PendingRebuyView>
  >
  get pendingRebuys => ListCopyWith(
    $value.pendingRebuys,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(pendingRebuys: v),
  );
  @override
  $R call({
    String? roomCode,
    int? handNumber,
    WirePhase? phase,
    Object? dealerSeat = $none,
    Object? smallBlindSeat = $none,
    Object? bigBlindSeat = $none,
    Object? activeSeat = $none,
    int? currentHighBet,
    int? minRaiseTo,
    int? totalPot,
    List<PotView>? pots,
    List<SeatView>? seats,
    bool? paused,
    Object? turnDeadlineMs = $none,
    int? spectatorCount,
    List<PendingRebuyView>? pendingRebuys,
  }) => $apply(
    FieldCopyWithData({
      if (roomCode != null) #roomCode: roomCode,
      if (handNumber != null) #handNumber: handNumber,
      if (phase != null) #phase: phase,
      if (dealerSeat != $none) #dealerSeat: dealerSeat,
      if (smallBlindSeat != $none) #smallBlindSeat: smallBlindSeat,
      if (bigBlindSeat != $none) #bigBlindSeat: bigBlindSeat,
      if (activeSeat != $none) #activeSeat: activeSeat,
      if (currentHighBet != null) #currentHighBet: currentHighBet,
      if (minRaiseTo != null) #minRaiseTo: minRaiseTo,
      if (totalPot != null) #totalPot: totalPot,
      if (pots != null) #pots: pots,
      if (seats != null) #seats: seats,
      if (paused != null) #paused: paused,
      if (turnDeadlineMs != $none) #turnDeadlineMs: turnDeadlineMs,
      if (spectatorCount != null) #spectatorCount: spectatorCount,
      if (pendingRebuys != null) #pendingRebuys: pendingRebuys,
    }),
  );
  @override
  RoomView $make(CopyWithData data) => RoomView(
    roomCode: data.get(#roomCode, or: $value.roomCode),
    handNumber: data.get(#handNumber, or: $value.handNumber),
    phase: data.get(#phase, or: $value.phase),
    dealerSeat: data.get(#dealerSeat, or: $value.dealerSeat),
    smallBlindSeat: data.get(#smallBlindSeat, or: $value.smallBlindSeat),
    bigBlindSeat: data.get(#bigBlindSeat, or: $value.bigBlindSeat),
    activeSeat: data.get(#activeSeat, or: $value.activeSeat),
    currentHighBet: data.get(#currentHighBet, or: $value.currentHighBet),
    minRaiseTo: data.get(#minRaiseTo, or: $value.minRaiseTo),
    totalPot: data.get(#totalPot, or: $value.totalPot),
    pots: data.get(#pots, or: $value.pots),
    seats: data.get(#seats, or: $value.seats),
    paused: data.get(#paused, or: $value.paused),
    turnDeadlineMs: data.get(#turnDeadlineMs, or: $value.turnDeadlineMs),
    spectatorCount: data.get(#spectatorCount, or: $value.spectatorCount),
    pendingRebuys: data.get(#pendingRebuys, or: $value.pendingRebuys),
  );

  @override
  RoomViewCopyWith<$R2, RoomView, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

