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

class HandCategoryMapper extends EnumMapper<HandCategory> {
  HandCategoryMapper._();

  static HandCategoryMapper? _instance;
  static HandCategoryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HandCategoryMapper._());
    }
    return _instance!;
  }

  static HandCategory fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  HandCategory decode(dynamic value) {
    switch (value) {
      case r'HIGH_CARD':
        return HandCategory.highCard;
      case r'PAIR':
        return HandCategory.pair;
      case r'TWO_PAIR':
        return HandCategory.twoPair;
      case r'THREE_OF_AKIND':
        return HandCategory.threeOfAKind;
      case r'STRAIGHT':
        return HandCategory.straight;
      case r'FLUSH':
        return HandCategory.flush;
      case r'FULL_HOUSE':
        return HandCategory.fullHouse;
      case r'FOUR_OF_AKIND':
        return HandCategory.fourOfAKind;
      case r'STRAIGHT_FLUSH':
        return HandCategory.straightFlush;
      default:
        return HandCategory.values[0];
    }
  }

  @override
  dynamic encode(HandCategory self) {
    switch (self) {
      case HandCategory.highCard:
        return r'HIGH_CARD';
      case HandCategory.pair:
        return r'PAIR';
      case HandCategory.twoPair:
        return r'TWO_PAIR';
      case HandCategory.threeOfAKind:
        return r'THREE_OF_AKIND';
      case HandCategory.straight:
        return r'STRAIGHT';
      case HandCategory.flush:
        return r'FLUSH';
      case HandCategory.fullHouse:
        return r'FULL_HOUSE';
      case HandCategory.fourOfAKind:
        return r'FOUR_OF_AKIND';
      case HandCategory.straightFlush:
        return r'STRAIGHT_FLUSH';
    }
  }
}

extension HandCategoryMapperExtension on HandCategory {
  String toValue() {
    HandCategoryMapper.ensureInitialized();
    return MapperContainer.globals.toValue<HandCategory>(this) as String;
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
  static bool _$hasCards(SeatView v) => v.hasCards;
  static const Field<SeatView, bool> _f$hasCards = Field(
    'hasCards',
    _$hasCards,
    opt: true,
    def: false,
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
    #hasCards: _f$hasCards,
  };
  @override
  final bool ignoreNull = true;

  @override
  final MappingHook hook = const OmitWhenDefault({'hasCards': false});
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
      hasCards: data.dec(_f$hasCards),
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
    bool? hasCards,
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
    bool? hasCards,
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
      if (hasCards != null) #hasCards: hasCards,
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
    hasCards: data.get(#hasCards, or: $value.hasCards),
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

class RevealMapper extends ClassMapperBase<Reveal> {
  RevealMapper._();

  static RevealMapper? _instance;
  static RevealMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RevealMapper._());
      MapperContainer.globals.useAll([PokerCardMapper()]);
      HandCategoryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Reveal';

  static String _$playerId(Reveal v) => v.playerId;
  static const Field<Reveal, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static String _$name(Reveal v) => v.name;
  static const Field<Reveal, String> _f$name = Field('name', _$name);
  static List<PokerCard> _$cards(Reveal v) => v.cards;
  static const Field<Reveal, List<PokerCard>> _f$cards = Field(
    'cards',
    _$cards,
  );
  static HandCategory _$category(Reveal v) => v.category;
  static const Field<Reveal, HandCategory> _f$category = Field(
    'category',
    _$category,
  );
  static List<PokerCard> _$bestFive(Reveal v) => v.bestFive;
  static const Field<Reveal, List<PokerCard>> _f$bestFive = Field(
    'bestFive',
    _$bestFive,
  );

  @override
  final MappableFields<Reveal> fields = const {
    #playerId: _f$playerId,
    #name: _f$name,
    #cards: _f$cards,
    #category: _f$category,
    #bestFive: _f$bestFive,
  };
  @override
  final bool ignoreNull = true;

  static Reveal _instantiate(DecodingData data) {
    return Reveal(
      playerId: data.dec(_f$playerId),
      name: data.dec(_f$name),
      cards: data.dec(_f$cards),
      category: data.dec(_f$category),
      bestFive: data.dec(_f$bestFive),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Reveal fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Reveal>(map);
  }

  static Reveal fromJson(String json) {
    return ensureInitialized().decodeJson<Reveal>(json);
  }
}

mixin RevealMappable {
  String toJson() {
    return RevealMapper.ensureInitialized().encodeJson<Reveal>(this as Reveal);
  }

  Map<String, dynamic> toMap() {
    return RevealMapper.ensureInitialized().encodeMap<Reveal>(this as Reveal);
  }

  RevealCopyWith<Reveal, Reveal, Reveal> get copyWith =>
      _RevealCopyWithImpl<Reveal, Reveal>(this as Reveal, $identity, $identity);
  @override
  String toString() {
    return RevealMapper.ensureInitialized().stringifyValue(this as Reveal);
  }

  @override
  bool operator ==(Object other) {
    return RevealMapper.ensureInitialized().equalsValue(this as Reveal, other);
  }

  @override
  int get hashCode {
    return RevealMapper.ensureInitialized().hashValue(this as Reveal);
  }
}

extension RevealValueCopy<$R, $Out> on ObjectCopyWith<$R, Reveal, $Out> {
  RevealCopyWith<$R, Reveal, $Out> get $asReveal =>
      $base.as((v, t, t2) => _RevealCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RevealCopyWith<$R, $In extends Reveal, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get cards;
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get bestFive;
  $R call({
    String? playerId,
    String? name,
    List<PokerCard>? cards,
    HandCategory? category,
    List<PokerCard>? bestFive,
  });
  RevealCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RevealCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Reveal, $Out>
    implements RevealCopyWith<$R, Reveal, $Out> {
  _RevealCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Reveal> $mapper = RevealMapper.ensureInitialized();
  @override
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get cards => ListCopyWith(
    $value.cards,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(cards: v),
  );
  @override
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get bestFive => ListCopyWith(
    $value.bestFive,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(bestFive: v),
  );
  @override
  $R call({
    String? playerId,
    String? name,
    List<PokerCard>? cards,
    HandCategory? category,
    List<PokerCard>? bestFive,
  }) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (name != null) #name: name,
      if (cards != null) #cards: cards,
      if (category != null) #category: category,
      if (bestFive != null) #bestFive: bestFive,
    }),
  );
  @override
  Reveal $make(CopyWithData data) => Reveal(
    playerId: data.get(#playerId, or: $value.playerId),
    name: data.get(#name, or: $value.name),
    cards: data.get(#cards, or: $value.cards),
    category: data.get(#category, or: $value.category),
    bestFive: data.get(#bestFive, or: $value.bestFive),
  );

  @override
  RevealCopyWith<$R2, Reveal, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _RevealCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ShareMapper extends ClassMapperBase<Share> {
  ShareMapper._();

  static ShareMapper? _instance;
  static ShareMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ShareMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Share';

  static String _$playerId(Share v) => v.playerId;
  static const Field<Share, String> _f$playerId = Field('playerId', _$playerId);
  static String _$name(Share v) => v.name;
  static const Field<Share, String> _f$name = Field('name', _$name);
  static int _$amount(Share v) => v.amount;
  static const Field<Share, int> _f$amount = Field('amount', _$amount);

  @override
  final MappableFields<Share> fields = const {
    #playerId: _f$playerId,
    #name: _f$name,
    #amount: _f$amount,
  };
  @override
  final bool ignoreNull = true;

  static Share _instantiate(DecodingData data) {
    return Share(
      playerId: data.dec(_f$playerId),
      name: data.dec(_f$name),
      amount: data.dec(_f$amount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Share fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Share>(map);
  }

  static Share fromJson(String json) {
    return ensureInitialized().decodeJson<Share>(json);
  }
}

mixin ShareMappable {
  String toJson() {
    return ShareMapper.ensureInitialized().encodeJson<Share>(this as Share);
  }

  Map<String, dynamic> toMap() {
    return ShareMapper.ensureInitialized().encodeMap<Share>(this as Share);
  }

  ShareCopyWith<Share, Share, Share> get copyWith =>
      _ShareCopyWithImpl<Share, Share>(this as Share, $identity, $identity);
  @override
  String toString() {
    return ShareMapper.ensureInitialized().stringifyValue(this as Share);
  }

  @override
  bool operator ==(Object other) {
    return ShareMapper.ensureInitialized().equalsValue(this as Share, other);
  }

  @override
  int get hashCode {
    return ShareMapper.ensureInitialized().hashValue(this as Share);
  }
}

extension ShareValueCopy<$R, $Out> on ObjectCopyWith<$R, Share, $Out> {
  ShareCopyWith<$R, Share, $Out> get $asShare =>
      $base.as((v, t, t2) => _ShareCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ShareCopyWith<$R, $In extends Share, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? playerId, String? name, int? amount});
  ShareCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ShareCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Share, $Out>
    implements ShareCopyWith<$R, Share, $Out> {
  _ShareCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Share> $mapper = ShareMapper.ensureInitialized();
  @override
  $R call({String? playerId, String? name, int? amount}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (name != null) #name: name,
      if (amount != null) #amount: amount,
    }),
  );
  @override
  Share $make(CopyWithData data) => Share(
    playerId: data.get(#playerId, or: $value.playerId),
    name: data.get(#name, or: $value.name),
    amount: data.get(#amount, or: $value.amount),
  );

  @override
  ShareCopyWith<$R2, Share, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ShareCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PotResultMapper extends ClassMapperBase<PotResult> {
  PotResultMapper._();

  static PotResultMapper? _instance;
  static PotResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PotResultMapper._());
      ShareMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PotResult';

  static int _$potIndex(PotResult v) => v.potIndex;
  static const Field<PotResult, int> _f$potIndex = Field(
    'potIndex',
    _$potIndex,
  );
  static int _$amount(PotResult v) => v.amount;
  static const Field<PotResult, int> _f$amount = Field('amount', _$amount);
  static List<String> _$winnerPlayerIds(PotResult v) => v.winnerPlayerIds;
  static const Field<PotResult, List<String>> _f$winnerPlayerIds = Field(
    'winnerPlayerIds',
    _$winnerPlayerIds,
  );
  static List<Share> _$shares(PotResult v) => v.shares;
  static const Field<PotResult, List<Share>> _f$shares = Field(
    'shares',
    _$shares,
  );

  @override
  final MappableFields<PotResult> fields = const {
    #potIndex: _f$potIndex,
    #amount: _f$amount,
    #winnerPlayerIds: _f$winnerPlayerIds,
    #shares: _f$shares,
  };
  @override
  final bool ignoreNull = true;

  static PotResult _instantiate(DecodingData data) {
    return PotResult(
      potIndex: data.dec(_f$potIndex),
      amount: data.dec(_f$amount),
      winnerPlayerIds: data.dec(_f$winnerPlayerIds),
      shares: data.dec(_f$shares),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PotResult fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PotResult>(map);
  }

  static PotResult fromJson(String json) {
    return ensureInitialized().decodeJson<PotResult>(json);
  }
}

mixin PotResultMappable {
  String toJson() {
    return PotResultMapper.ensureInitialized().encodeJson<PotResult>(
      this as PotResult,
    );
  }

  Map<String, dynamic> toMap() {
    return PotResultMapper.ensureInitialized().encodeMap<PotResult>(
      this as PotResult,
    );
  }

  PotResultCopyWith<PotResult, PotResult, PotResult> get copyWith =>
      _PotResultCopyWithImpl<PotResult, PotResult>(
        this as PotResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PotResultMapper.ensureInitialized().stringifyValue(
      this as PotResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return PotResultMapper.ensureInitialized().equalsValue(
      this as PotResult,
      other,
    );
  }

  @override
  int get hashCode {
    return PotResultMapper.ensureInitialized().hashValue(this as PotResult);
  }
}

extension PotResultValueCopy<$R, $Out> on ObjectCopyWith<$R, PotResult, $Out> {
  PotResultCopyWith<$R, PotResult, $Out> get $asPotResult =>
      $base.as((v, t, t2) => _PotResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PotResultCopyWith<$R, $In extends PotResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get winnerPlayerIds;
  ListCopyWith<$R, Share, ShareCopyWith<$R, Share, Share>> get shares;
  $R call({
    int? potIndex,
    int? amount,
    List<String>? winnerPlayerIds,
    List<Share>? shares,
  });
  PotResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PotResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PotResult, $Out>
    implements PotResultCopyWith<$R, PotResult, $Out> {
  _PotResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PotResult> $mapper =
      PotResultMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get winnerPlayerIds => ListCopyWith(
    $value.winnerPlayerIds,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(winnerPlayerIds: v),
  );
  @override
  ListCopyWith<$R, Share, ShareCopyWith<$R, Share, Share>> get shares =>
      ListCopyWith(
        $value.shares,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(shares: v),
      );
  @override
  $R call({
    int? potIndex,
    int? amount,
    List<String>? winnerPlayerIds,
    List<Share>? shares,
  }) => $apply(
    FieldCopyWithData({
      if (potIndex != null) #potIndex: potIndex,
      if (amount != null) #amount: amount,
      if (winnerPlayerIds != null) #winnerPlayerIds: winnerPlayerIds,
      if (shares != null) #shares: shares,
    }),
  );
  @override
  PotResult $make(CopyWithData data) => PotResult(
    potIndex: data.get(#potIndex, or: $value.potIndex),
    amount: data.get(#amount, or: $value.amount),
    winnerPlayerIds: data.get(#winnerPlayerIds, or: $value.winnerPlayerIds),
    shares: data.get(#shares, or: $value.shares),
  );

  @override
  PotResultCopyWith<$R2, PotResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PotResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class HandResultMapper extends ClassMapperBase<HandResult> {
  HandResultMapper._();

  static HandResultMapper? _instance;
  static HandResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HandResultMapper._());
      PotResultMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HandResult';

  static bool _$uncontested(HandResult v) => v.uncontested;
  static const Field<HandResult, bool> _f$uncontested = Field(
    'uncontested',
    _$uncontested,
  );
  static List<PotResult> _$pots(HandResult v) => v.pots;
  static const Field<HandResult, List<PotResult>> _f$pots = Field(
    'pots',
    _$pots,
  );

  @override
  final MappableFields<HandResult> fields = const {
    #uncontested: _f$uncontested,
    #pots: _f$pots,
  };
  @override
  final bool ignoreNull = true;

  static HandResult _instantiate(DecodingData data) {
    return HandResult(
      uncontested: data.dec(_f$uncontested),
      pots: data.dec(_f$pots),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HandResult fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HandResult>(map);
  }

  static HandResult fromJson(String json) {
    return ensureInitialized().decodeJson<HandResult>(json);
  }
}

mixin HandResultMappable {
  String toJson() {
    return HandResultMapper.ensureInitialized().encodeJson<HandResult>(
      this as HandResult,
    );
  }

  Map<String, dynamic> toMap() {
    return HandResultMapper.ensureInitialized().encodeMap<HandResult>(
      this as HandResult,
    );
  }

  HandResultCopyWith<HandResult, HandResult, HandResult> get copyWith =>
      _HandResultCopyWithImpl<HandResult, HandResult>(
        this as HandResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HandResultMapper.ensureInitialized().stringifyValue(
      this as HandResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return HandResultMapper.ensureInitialized().equalsValue(
      this as HandResult,
      other,
    );
  }

  @override
  int get hashCode {
    return HandResultMapper.ensureInitialized().hashValue(this as HandResult);
  }
}

extension HandResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HandResult, $Out> {
  HandResultCopyWith<$R, HandResult, $Out> get $asHandResult =>
      $base.as((v, t, t2) => _HandResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HandResultCopyWith<$R, $In extends HandResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, PotResult, PotResultCopyWith<$R, PotResult, PotResult>>
  get pots;
  $R call({bool? uncontested, List<PotResult>? pots});
  HandResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HandResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HandResult, $Out>
    implements HandResultCopyWith<$R, HandResult, $Out> {
  _HandResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HandResult> $mapper =
      HandResultMapper.ensureInitialized();
  @override
  ListCopyWith<$R, PotResult, PotResultCopyWith<$R, PotResult, PotResult>>
  get pots => ListCopyWith(
    $value.pots,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(pots: v),
  );
  @override
  $R call({bool? uncontested, List<PotResult>? pots}) => $apply(
    FieldCopyWithData({
      if (uncontested != null) #uncontested: uncontested,
      if (pots != null) #pots: pots,
    }),
  );
  @override
  HandResult $make(CopyWithData data) => HandResult(
    uncontested: data.get(#uncontested, or: $value.uncontested),
    pots: data.get(#pots, or: $value.pots),
  );

  @override
  HandResultCopyWith<$R2, HandResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HandResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class FinishMapper extends ClassMapperBase<Finish> {
  FinishMapper._();

  static FinishMapper? _instance;
  static FinishMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FinishMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Finish';

  static String _$playerId(Finish v) => v.playerId;
  static const Field<Finish, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static String _$name(Finish v) => v.name;
  static const Field<Finish, String> _f$name = Field('name', _$name);
  static int _$place(Finish v) => v.place;
  static const Field<Finish, int> _f$place = Field('place', _$place);

  @override
  final MappableFields<Finish> fields = const {
    #playerId: _f$playerId,
    #name: _f$name,
    #place: _f$place,
  };
  @override
  final bool ignoreNull = true;

  static Finish _instantiate(DecodingData data) {
    return Finish(
      playerId: data.dec(_f$playerId),
      name: data.dec(_f$name),
      place: data.dec(_f$place),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Finish fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Finish>(map);
  }

  static Finish fromJson(String json) {
    return ensureInitialized().decodeJson<Finish>(json);
  }
}

mixin FinishMappable {
  String toJson() {
    return FinishMapper.ensureInitialized().encodeJson<Finish>(this as Finish);
  }

  Map<String, dynamic> toMap() {
    return FinishMapper.ensureInitialized().encodeMap<Finish>(this as Finish);
  }

  FinishCopyWith<Finish, Finish, Finish> get copyWith =>
      _FinishCopyWithImpl<Finish, Finish>(this as Finish, $identity, $identity);
  @override
  String toString() {
    return FinishMapper.ensureInitialized().stringifyValue(this as Finish);
  }

  @override
  bool operator ==(Object other) {
    return FinishMapper.ensureInitialized().equalsValue(this as Finish, other);
  }

  @override
  int get hashCode {
    return FinishMapper.ensureInitialized().hashValue(this as Finish);
  }
}

extension FinishValueCopy<$R, $Out> on ObjectCopyWith<$R, Finish, $Out> {
  FinishCopyWith<$R, Finish, $Out> get $asFinish =>
      $base.as((v, t, t2) => _FinishCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FinishCopyWith<$R, $In extends Finish, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? playerId, String? name, int? place});
  FinishCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FinishCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Finish, $Out>
    implements FinishCopyWith<$R, Finish, $Out> {
  _FinishCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Finish> $mapper = FinishMapper.ensureInitialized();
  @override
  $R call({String? playerId, String? name, int? place}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (name != null) #name: name,
      if (place != null) #place: place,
    }),
  );
  @override
  Finish $make(CopyWithData data) => Finish(
    playerId: data.get(#playerId, or: $value.playerId),
    name: data.get(#name, or: $value.name),
    place: data.get(#place, or: $value.place),
  );

  @override
  FinishCopyWith<$R2, Finish, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _FinishCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class BlindsViewMapper extends ClassMapperBase<BlindsView> {
  BlindsViewMapper._();

  static BlindsViewMapper? _instance;
  static BlindsViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BlindsViewMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BlindsView';

  static int _$smallBlind(BlindsView v) => v.smallBlind;
  static const Field<BlindsView, int> _f$smallBlind = Field(
    'smallBlind',
    _$smallBlind,
  );
  static int _$bigBlind(BlindsView v) => v.bigBlind;
  static const Field<BlindsView, int> _f$bigBlind = Field(
    'bigBlind',
    _$bigBlind,
  );
  static int? _$nextSmallBlind(BlindsView v) => v.nextSmallBlind;
  static const Field<BlindsView, int> _f$nextSmallBlind = Field(
    'nextSmallBlind',
    _$nextSmallBlind,
    opt: true,
  );
  static int? _$nextBigBlind(BlindsView v) => v.nextBigBlind;
  static const Field<BlindsView, int> _f$nextBigBlind = Field(
    'nextBigBlind',
    _$nextBigBlind,
    opt: true,
  );
  static int? _$handsLeft(BlindsView v) => v.handsLeft;
  static const Field<BlindsView, int> _f$handsLeft = Field(
    'handsLeft',
    _$handsLeft,
    opt: true,
  );

  @override
  final MappableFields<BlindsView> fields = const {
    #smallBlind: _f$smallBlind,
    #bigBlind: _f$bigBlind,
    #nextSmallBlind: _f$nextSmallBlind,
    #nextBigBlind: _f$nextBigBlind,
    #handsLeft: _f$handsLeft,
  };
  @override
  final bool ignoreNull = true;

  static BlindsView _instantiate(DecodingData data) {
    return BlindsView(
      smallBlind: data.dec(_f$smallBlind),
      bigBlind: data.dec(_f$bigBlind),
      nextSmallBlind: data.dec(_f$nextSmallBlind),
      nextBigBlind: data.dec(_f$nextBigBlind),
      handsLeft: data.dec(_f$handsLeft),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BlindsView fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BlindsView>(map);
  }

  static BlindsView fromJson(String json) {
    return ensureInitialized().decodeJson<BlindsView>(json);
  }
}

mixin BlindsViewMappable {
  String toJson() {
    return BlindsViewMapper.ensureInitialized().encodeJson<BlindsView>(
      this as BlindsView,
    );
  }

  Map<String, dynamic> toMap() {
    return BlindsViewMapper.ensureInitialized().encodeMap<BlindsView>(
      this as BlindsView,
    );
  }

  BlindsViewCopyWith<BlindsView, BlindsView, BlindsView> get copyWith =>
      _BlindsViewCopyWithImpl<BlindsView, BlindsView>(
        this as BlindsView,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BlindsViewMapper.ensureInitialized().stringifyValue(
      this as BlindsView,
    );
  }

  @override
  bool operator ==(Object other) {
    return BlindsViewMapper.ensureInitialized().equalsValue(
      this as BlindsView,
      other,
    );
  }

  @override
  int get hashCode {
    return BlindsViewMapper.ensureInitialized().hashValue(this as BlindsView);
  }
}

extension BlindsViewValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BlindsView, $Out> {
  BlindsViewCopyWith<$R, BlindsView, $Out> get $asBlindsView =>
      $base.as((v, t, t2) => _BlindsViewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BlindsViewCopyWith<$R, $In extends BlindsView, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? smallBlind,
    int? bigBlind,
    int? nextSmallBlind,
    int? nextBigBlind,
    int? handsLeft,
  });
  BlindsViewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BlindsViewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BlindsView, $Out>
    implements BlindsViewCopyWith<$R, BlindsView, $Out> {
  _BlindsViewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BlindsView> $mapper =
      BlindsViewMapper.ensureInitialized();
  @override
  $R call({
    int? smallBlind,
    int? bigBlind,
    Object? nextSmallBlind = $none,
    Object? nextBigBlind = $none,
    Object? handsLeft = $none,
  }) => $apply(
    FieldCopyWithData({
      if (smallBlind != null) #smallBlind: smallBlind,
      if (bigBlind != null) #bigBlind: bigBlind,
      if (nextSmallBlind != $none) #nextSmallBlind: nextSmallBlind,
      if (nextBigBlind != $none) #nextBigBlind: nextBigBlind,
      if (handsLeft != $none) #handsLeft: handsLeft,
    }),
  );
  @override
  BlindsView $make(CopyWithData data) => BlindsView(
    smallBlind: data.get(#smallBlind, or: $value.smallBlind),
    bigBlind: data.get(#bigBlind, or: $value.bigBlind),
    nextSmallBlind: data.get(#nextSmallBlind, or: $value.nextSmallBlind),
    nextBigBlind: data.get(#nextBigBlind, or: $value.nextBigBlind),
    handsLeft: data.get(#handsLeft, or: $value.handsLeft),
  );

  @override
  BlindsViewCopyWith<$R2, BlindsView, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BlindsViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomViewMapper extends ClassMapperBase<RoomView> {
  RoomViewMapper._();

  static RoomViewMapper? _instance;
  static RoomViewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomViewMapper._());
      MapperContainer.globals.useAll([PokerCardMapper()]);
      WirePhaseMapper.ensureInitialized();
      PotViewMapper.ensureInitialized();
      SeatViewMapper.ensureInitialized();
      PendingRebuyViewMapper.ensureInitialized();
      RevealMapper.ensureInitialized();
      HandResultMapper.ensureInitialized();
      FinishMapper.ensureInitialized();
      BlindsViewMapper.ensureInitialized();
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
  static List<PokerCard> _$board(RoomView v) => v.board;
  static const Field<RoomView, List<PokerCard>> _f$board = Field(
    'board',
    _$board,
    opt: true,
    def: const <PokerCard>[],
  );
  static List<Reveal> _$reveals(RoomView v) => v.reveals;
  static const Field<RoomView, List<Reveal>> _f$reveals = Field(
    'reveals',
    _$reveals,
    opt: true,
    def: const <Reveal>[],
  );
  static HandResult? _$result(RoomView v) => v.result;
  static const Field<RoomView, HandResult> _f$result = Field(
    'result',
    _$result,
    opt: true,
  );
  static List<Finish> _$finishOrder(RoomView v) => v.finishOrder;
  static const Field<RoomView, List<Finish>> _f$finishOrder = Field(
    'finishOrder',
    _$finishOrder,
    opt: true,
    def: const <Finish>[],
  );
  static BlindsView? _$blinds(RoomView v) => v.blinds;
  static const Field<RoomView, BlindsView> _f$blinds = Field(
    'blinds',
    _$blinds,
    opt: true,
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
    #board: _f$board,
    #reveals: _f$reveals,
    #result: _f$result,
    #finishOrder: _f$finishOrder,
    #blinds: _f$blinds,
  };
  @override
  final bool ignoreNull = true;

  @override
  final MappingHook hook = const OmitWhenDefault({
    'board': <Object?>[],
    'reveals': <Object?>[],
    'finishOrder': <Object?>[],
  });
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
      board: data.dec(_f$board),
      reveals: data.dec(_f$reveals),
      result: data.dec(_f$result),
      finishOrder: data.dec(_f$finishOrder),
      blinds: data.dec(_f$blinds),
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
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get board;
  ListCopyWith<$R, Reveal, RevealCopyWith<$R, Reveal, Reveal>> get reveals;
  HandResultCopyWith<$R, HandResult, HandResult>? get result;
  ListCopyWith<$R, Finish, FinishCopyWith<$R, Finish, Finish>> get finishOrder;
  BlindsViewCopyWith<$R, BlindsView, BlindsView>? get blinds;
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
    List<PokerCard>? board,
    List<Reveal>? reveals,
    HandResult? result,
    List<Finish>? finishOrder,
    BlindsView? blinds,
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
  ListCopyWith<$R, PokerCard, ObjectCopyWith<$R, PokerCard, PokerCard>>
  get board => ListCopyWith(
    $value.board,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(board: v),
  );
  @override
  ListCopyWith<$R, Reveal, RevealCopyWith<$R, Reveal, Reveal>> get reveals =>
      ListCopyWith(
        $value.reveals,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(reveals: v),
      );
  @override
  HandResultCopyWith<$R, HandResult, HandResult>? get result =>
      $value.result?.copyWith.$chain((v) => call(result: v));
  @override
  ListCopyWith<$R, Finish, FinishCopyWith<$R, Finish, Finish>>
  get finishOrder => ListCopyWith(
    $value.finishOrder,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(finishOrder: v),
  );
  @override
  BlindsViewCopyWith<$R, BlindsView, BlindsView>? get blinds =>
      $value.blinds?.copyWith.$chain((v) => call(blinds: v));
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
    List<PokerCard>? board,
    List<Reveal>? reveals,
    Object? result = $none,
    List<Finish>? finishOrder,
    Object? blinds = $none,
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
      if (board != null) #board: board,
      if (reveals != null) #reveals: reveals,
      if (result != $none) #result: result,
      if (finishOrder != null) #finishOrder: finishOrder,
      if (blinds != $none) #blinds: blinds,
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
    board: data.get(#board, or: $value.board),
    reveals: data.get(#reveals, or: $value.reveals),
    result: data.get(#result, or: $value.result),
    finishOrder: data.get(#finishOrder, or: $value.finishOrder),
    blinds: data.get(#blinds, or: $value.blinds),
  );

  @override
  RoomViewCopyWith<$R2, RoomView, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomViewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

