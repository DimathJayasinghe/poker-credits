// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'room_config.dart';

class RoomConfigMapper extends ClassMapperBase<RoomConfig> {
  RoomConfigMapper._();

  static RoomConfigMapper? _instance;
  static RoomConfigMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomConfigMapper._());
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

  @override
  final MappableFields<RoomConfig> fields = const {
    #startingChips: _f$startingChips,
    #smallBlind: _f$smallBlind,
    #bigBlind: _f$bigBlind,
    #ante: _f$ante,
    #isTournament: _f$isTournament,
    #blindLevelMinutes: _f$blindLevelMinutes,
    #turnTimeLimitSeconds: _f$turnTimeLimitSeconds,
  };
  @override
  final bool ignoreNull = true;

  static RoomConfig _instantiate(DecodingData data) {
    return RoomConfig(
      startingChips: data.dec(_f$startingChips),
      smallBlind: data.dec(_f$smallBlind),
      bigBlind: data.dec(_f$bigBlind),
      ante: data.dec(_f$ante),
      isTournament: data.dec(_f$isTournament),
      blindLevelMinutes: data.dec(_f$blindLevelMinutes),
      turnTimeLimitSeconds: data.dec(_f$turnTimeLimitSeconds),
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
  $R call({
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    int? ante,
    bool? isTournament,
    int? blindLevelMinutes,
    int? turnTimeLimitSeconds,
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
  $R call({
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    int? ante,
    bool? isTournament,
    int? blindLevelMinutes,
    int? turnTimeLimitSeconds,
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
  );

  @override
  RoomConfigCopyWith<$R2, RoomConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

