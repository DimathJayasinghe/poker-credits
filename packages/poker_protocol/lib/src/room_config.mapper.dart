// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'room_config.dart';

class CardModeMapper extends EnumMapper<CardMode> {
  CardModeMapper._();

  static CardModeMapper? _instance;
  static CardModeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CardModeMapper._());
    }
    return _instance!;
  }

  static CardMode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CardMode decode(dynamic value) {
    switch (value) {
      case r'PHYSICAL':
        return CardMode.physical;
      case r'VIRTUAL':
        return CardMode.virtual;
      default:
        return CardMode.values[0];
    }
  }

  @override
  dynamic encode(CardMode self) {
    switch (self) {
      case CardMode.physical:
        return r'PHYSICAL';
      case CardMode.virtual:
        return r'VIRTUAL';
    }
  }
}

extension CardModeMapperExtension on CardMode {
  String toValue() {
    CardModeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CardMode>(this) as String;
  }
}

class BotSkillMapper extends EnumMapper<BotSkill> {
  BotSkillMapper._();

  static BotSkillMapper? _instance;
  static BotSkillMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BotSkillMapper._());
    }
    return _instance!;
  }

  static BotSkill fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  BotSkill decode(dynamic value) {
    switch (value) {
      case r'EASY':
        return BotSkill.easy;
      case r'NORMAL':
        return BotSkill.normal;
      case r'HARD':
        return BotSkill.hard;
      default:
        return BotSkill.values[1];
    }
  }

  @override
  dynamic encode(BotSkill self) {
    switch (self) {
      case BotSkill.easy:
        return r'EASY';
      case BotSkill.normal:
        return r'NORMAL';
      case BotSkill.hard:
        return r'HARD';
    }
  }
}

extension BotSkillMapperExtension on BotSkill {
  String toValue() {
    BotSkillMapper.ensureInitialized();
    return MapperContainer.globals.toValue<BotSkill>(this) as String;
  }
}

class SoloConfigMapper extends ClassMapperBase<SoloConfig> {
  SoloConfigMapper._();

  static SoloConfigMapper? _instance;
  static SoloConfigMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SoloConfigMapper._());
      BotSkillMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SoloConfig';

  static int _$bots(SoloConfig v) => v.bots;
  static const Field<SoloConfig, int> _f$bots = Field('bots', _$bots);
  static BotSkill _$skill(SoloConfig v) => v.skill;
  static const Field<SoloConfig, BotSkill> _f$skill = Field('skill', _$skill);
  static int _$ladderHands(SoloConfig v) => v.ladderHands;
  static const Field<SoloConfig, int> _f$ladderHands = Field(
    'ladderHands',
    _$ladderHands,
  );

  @override
  final MappableFields<SoloConfig> fields = const {
    #bots: _f$bots,
    #skill: _f$skill,
    #ladderHands: _f$ladderHands,
  };
  @override
  final bool ignoreNull = true;

  static SoloConfig _instantiate(DecodingData data) {
    return SoloConfig(
      bots: data.dec(_f$bots),
      skill: data.dec(_f$skill),
      ladderHands: data.dec(_f$ladderHands),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SoloConfig fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SoloConfig>(map);
  }

  static SoloConfig fromJson(String json) {
    return ensureInitialized().decodeJson<SoloConfig>(json);
  }
}

mixin SoloConfigMappable {
  String toJson() {
    return SoloConfigMapper.ensureInitialized().encodeJson<SoloConfig>(
      this as SoloConfig,
    );
  }

  Map<String, dynamic> toMap() {
    return SoloConfigMapper.ensureInitialized().encodeMap<SoloConfig>(
      this as SoloConfig,
    );
  }

  SoloConfigCopyWith<SoloConfig, SoloConfig, SoloConfig> get copyWith =>
      _SoloConfigCopyWithImpl<SoloConfig, SoloConfig>(
        this as SoloConfig,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SoloConfigMapper.ensureInitialized().stringifyValue(
      this as SoloConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    return SoloConfigMapper.ensureInitialized().equalsValue(
      this as SoloConfig,
      other,
    );
  }

  @override
  int get hashCode {
    return SoloConfigMapper.ensureInitialized().hashValue(this as SoloConfig);
  }
}

extension SoloConfigValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SoloConfig, $Out> {
  SoloConfigCopyWith<$R, SoloConfig, $Out> get $asSoloConfig =>
      $base.as((v, t, t2) => _SoloConfigCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SoloConfigCopyWith<$R, $In extends SoloConfig, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? bots, BotSkill? skill, int? ladderHands});
  SoloConfigCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SoloConfigCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SoloConfig, $Out>
    implements SoloConfigCopyWith<$R, SoloConfig, $Out> {
  _SoloConfigCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SoloConfig> $mapper =
      SoloConfigMapper.ensureInitialized();
  @override
  $R call({int? bots, BotSkill? skill, int? ladderHands}) => $apply(
    FieldCopyWithData({
      if (bots != null) #bots: bots,
      if (skill != null) #skill: skill,
      if (ladderHands != null) #ladderHands: ladderHands,
    }),
  );
  @override
  SoloConfig $make(CopyWithData data) => SoloConfig(
    bots: data.get(#bots, or: $value.bots),
    skill: data.get(#skill, or: $value.skill),
    ladderHands: data.get(#ladderHands, or: $value.ladderHands),
  );

  @override
  SoloConfigCopyWith<$R2, SoloConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SoloConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomConfigMapper extends ClassMapperBase<RoomConfig> {
  RoomConfigMapper._();

  static RoomConfigMapper? _instance;
  static RoomConfigMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomConfigMapper._());
      CardModeMapper.ensureInitialized();
      SoloConfigMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'RoomConfig';

  static int _$startingChips(RoomConfig v) => v.startingChips;
  static const Field<RoomConfig, int> _f$startingChips = Field(
    'startingChips',
    _$startingChips,
  );
  static int _$smallBlind(RoomConfig v) => v.smallBlind;
  static const Field<RoomConfig, int> _f$smallBlind = Field(
    'smallBlind',
    _$smallBlind,
  );
  static int _$bigBlind(RoomConfig v) => v.bigBlind;
  static const Field<RoomConfig, int> _f$bigBlind = Field(
    'bigBlind',
    _$bigBlind,
  );
  static int _$ante(RoomConfig v) => v.ante;
  static const Field<RoomConfig, int> _f$ante = Field('ante', _$ante);
  static bool _$isTournament(RoomConfig v) => v.isTournament;
  static const Field<RoomConfig, bool> _f$isTournament = Field(
    'isTournament',
    _$isTournament,
  );
  static int _$blindLevelMinutes(RoomConfig v) => v.blindLevelMinutes;
  static const Field<RoomConfig, int> _f$blindLevelMinutes = Field(
    'blindLevelMinutes',
    _$blindLevelMinutes,
  );
  static int _$turnTimeLimitSeconds(RoomConfig v) => v.turnTimeLimitSeconds;
  static const Field<RoomConfig, int> _f$turnTimeLimitSeconds = Field(
    'turnTimeLimitSeconds',
    _$turnTimeLimitSeconds,
  );
  static CardMode _$cardMode(RoomConfig v) => v.cardMode;
  static const Field<RoomConfig, CardMode> _f$cardMode = Field(
    'cardMode',
    _$cardMode,
    opt: true,
    def: CardMode.physical,
  );
  static SoloConfig? _$solo(RoomConfig v) => v.solo;
  static const Field<RoomConfig, SoloConfig> _f$solo = Field(
    'solo',
    _$solo,
    opt: true,
  );

  @override
  final MappableFields<RoomConfig> fields = const {
    #startingChips: _f$startingChips,
    #smallBlind: _f$smallBlind,
    #bigBlind: _f$bigBlind,
    #ante: _f$ante,
    #isTournament: _f$isTournament,
    #blindLevelMinutes: _f$blindLevelMinutes,
    #turnTimeLimitSeconds: _f$turnTimeLimitSeconds,
    #cardMode: _f$cardMode,
    #solo: _f$solo,
  };
  @override
  final bool ignoreNull = true;

  @override
  final MappingHook hook = const OmitWhenDefault({'cardMode': 'PHYSICAL'});
  static RoomConfig _instantiate(DecodingData data) {
    return RoomConfig(
      startingChips: data.dec(_f$startingChips),
      smallBlind: data.dec(_f$smallBlind),
      bigBlind: data.dec(_f$bigBlind),
      ante: data.dec(_f$ante),
      isTournament: data.dec(_f$isTournament),
      blindLevelMinutes: data.dec(_f$blindLevelMinutes),
      turnTimeLimitSeconds: data.dec(_f$turnTimeLimitSeconds),
      cardMode: data.dec(_f$cardMode),
      solo: data.dec(_f$solo),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RoomConfig fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomConfig>(map);
  }

  static RoomConfig fromJson(String json) {
    return ensureInitialized().decodeJson<RoomConfig>(json);
  }
}

mixin RoomConfigMappable {
  String toJson() {
    return RoomConfigMapper.ensureInitialized().encodeJson<RoomConfig>(
      this as RoomConfig,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomConfigMapper.ensureInitialized().encodeMap<RoomConfig>(
      this as RoomConfig,
    );
  }

  RoomConfigCopyWith<RoomConfig, RoomConfig, RoomConfig> get copyWith =>
      _RoomConfigCopyWithImpl<RoomConfig, RoomConfig>(
        this as RoomConfig,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RoomConfigMapper.ensureInitialized().stringifyValue(
      this as RoomConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomConfigMapper.ensureInitialized().equalsValue(
      this as RoomConfig,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomConfigMapper.ensureInitialized().hashValue(this as RoomConfig);
  }
}

extension RoomConfigValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomConfig, $Out> {
  RoomConfigCopyWith<$R, RoomConfig, $Out> get $asRoomConfig =>
      $base.as((v, t, t2) => _RoomConfigCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomConfigCopyWith<$R, $In extends RoomConfig, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  SoloConfigCopyWith<$R, SoloConfig, SoloConfig>? get solo;
  $R call({
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    int? ante,
    bool? isTournament,
    int? blindLevelMinutes,
    int? turnTimeLimitSeconds,
    CardMode? cardMode,
    SoloConfig? solo,
  });
  RoomConfigCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomConfigCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomConfig, $Out>
    implements RoomConfigCopyWith<$R, RoomConfig, $Out> {
  _RoomConfigCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomConfig> $mapper =
      RoomConfigMapper.ensureInitialized();
  @override
  SoloConfigCopyWith<$R, SoloConfig, SoloConfig>? get solo =>
      $value.solo?.copyWith.$chain((v) => call(solo: v));
  @override
  $R call({
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    int? ante,
    bool? isTournament,
    int? blindLevelMinutes,
    int? turnTimeLimitSeconds,
    CardMode? cardMode,
    Object? solo = $none,
  }) => $apply(
    FieldCopyWithData({
      if (startingChips != null) #startingChips: startingChips,
      if (smallBlind != null) #smallBlind: smallBlind,
      if (bigBlind != null) #bigBlind: bigBlind,
      if (ante != null) #ante: ante,
      if (isTournament != null) #isTournament: isTournament,
      if (blindLevelMinutes != null) #blindLevelMinutes: blindLevelMinutes,
      if (turnTimeLimitSeconds != null)
        #turnTimeLimitSeconds: turnTimeLimitSeconds,
      if (cardMode != null) #cardMode: cardMode,
      if (solo != $none) #solo: solo,
    }),
  );
  @override
  RoomConfig $make(CopyWithData data) => RoomConfig(
    startingChips: data.get(#startingChips, or: $value.startingChips),
    smallBlind: data.get(#smallBlind, or: $value.smallBlind),
    bigBlind: data.get(#bigBlind, or: $value.bigBlind),
    ante: data.get(#ante, or: $value.ante),
    isTournament: data.get(#isTournament, or: $value.isTournament),
    blindLevelMinutes: data.get(
      #blindLevelMinutes,
      or: $value.blindLevelMinutes,
    ),
    turnTimeLimitSeconds: data.get(
      #turnTimeLimitSeconds,
      or: $value.turnTimeLimitSeconds,
    ),
    cardMode: data.get(#cardMode, or: $value.cardMode),
    solo: data.get(#solo, or: $value.solo),
  );

  @override
  RoomConfigCopyWith<$R2, RoomConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

