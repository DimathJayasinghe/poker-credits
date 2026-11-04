// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'client_message.dart';

class WireAllocationMapper extends ClassMapperBase<WireAllocation> {
  WireAllocationMapper._();

  static WireAllocationMapper? _instance;
  static WireAllocationMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = WireAllocationMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'WireAllocation';

  static int _$potIndex(WireAllocation v) => v.potIndex;
  static const Field<WireAllocation, int> _f$potIndex = Field(
    'potIndex',
    _$potIndex,
  );
  static List<String> _$winnerPlayerIds(WireAllocation v) => v.winnerPlayerIds;
  static const Field<WireAllocation, List<String>> _f$winnerPlayerIds = Field(
    'winnerPlayerIds',
    _$winnerPlayerIds,
  );

  @override
  final MappableFields<WireAllocation> fields = const {
    #potIndex: _f$potIndex,
    #winnerPlayerIds: _f$winnerPlayerIds,
  };
  @override
  final bool ignoreNull = true;

  static WireAllocation _instantiate(DecodingData data) {
    return WireAllocation(
      potIndex: data.dec(_f$potIndex),
      winnerPlayerIds: data.dec(_f$winnerPlayerIds),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static WireAllocation fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<WireAllocation>(map);
  }

  static WireAllocation fromJson(String json) {
    return ensureInitialized().decodeJson<WireAllocation>(json);
  }
}

mixin WireAllocationMappable {
  String toJson() {
    return WireAllocationMapper.ensureInitialized().encodeJson<WireAllocation>(
      this as WireAllocation,
    );
  }

  Map<String, dynamic> toMap() {
    return WireAllocationMapper.ensureInitialized().encodeMap<WireAllocation>(
      this as WireAllocation,
    );
  }

  WireAllocationCopyWith<WireAllocation, WireAllocation, WireAllocation>
  get copyWith => _WireAllocationCopyWithImpl<WireAllocation, WireAllocation>(
    this as WireAllocation,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return WireAllocationMapper.ensureInitialized().stringifyValue(
      this as WireAllocation,
    );
  }

  @override
  bool operator ==(Object other) {
    return WireAllocationMapper.ensureInitialized().equalsValue(
      this as WireAllocation,
      other,
    );
  }

  @override
  int get hashCode {
    return WireAllocationMapper.ensureInitialized().hashValue(
      this as WireAllocation,
    );
  }
}

extension WireAllocationValueCopy<$R, $Out>
    on ObjectCopyWith<$R, WireAllocation, $Out> {
  WireAllocationCopyWith<$R, WireAllocation, $Out> get $asWireAllocation =>
      $base.as((v, t, t2) => _WireAllocationCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class WireAllocationCopyWith<$R, $In extends WireAllocation, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get winnerPlayerIds;
  $R call({int? potIndex, List<String>? winnerPlayerIds});
  WireAllocationCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _WireAllocationCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, WireAllocation, $Out>
    implements WireAllocationCopyWith<$R, WireAllocation, $Out> {
  _WireAllocationCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<WireAllocation> $mapper =
      WireAllocationMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get winnerPlayerIds => ListCopyWith(
    $value.winnerPlayerIds,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(winnerPlayerIds: v),
  );
  @override
  $R call({int? potIndex, List<String>? winnerPlayerIds}) => $apply(
    FieldCopyWithData({
      if (potIndex != null) #potIndex: potIndex,
      if (winnerPlayerIds != null) #winnerPlayerIds: winnerPlayerIds,
    }),
  );
  @override
  WireAllocation $make(CopyWithData data) => WireAllocation(
    potIndex: data.get(#potIndex, or: $value.potIndex),
    winnerPlayerIds: data.get(#winnerPlayerIds, or: $value.winnerPlayerIds),
  );

  @override
  WireAllocationCopyWith<$R2, WireAllocation, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _WireAllocationCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ClientMessageMapper extends ClassMapperBase<ClientMessage> {
  ClientMessageMapper._();

  static ClientMessageMapper? _instance;
  static ClientMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ClientMessageMapper._());
      CreateRoomMapper.ensureInitialized();
      JoinRoomMapper.ensureInitialized();
      ResumeMapper.ensureInitialized();
      StartHandMapper.ensureInitialized();
      GameActionMapper.ensureInitialized();
      BeginShowdownMapper.ensureInitialized();
      ResolveShowdownMapper.ensureInitialized();
      UndoMapper.ensureInitialized();
      PauseMapper.ensureInitialized();
      ResumeGameMapper.ensureInitialized();
      ApproveRebuyMapper.ensureInitialized();
      KickMapper.ensureInitialized();
      MoveSeatMapper.ensureInitialized();
      ChooseSeatMapper.ensureInitialized();
      RoomConfigureMapper.ensureInitialized();
      EndGameMapper.ensureInitialized();
      RequestRebuyMapper.ensureInitialized();
      SetSittingOutMapper.ensureInitialized();
      LeaveTableMapper.ensureInitialized();
      PresenceVoteMapper.ensureInitialized();
      PresenceAckMapper.ensureInitialized();
      PingMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ClientMessage';

  @override
  final MappableFields<ClientMessage> fields = const {};
  @override
  final bool ignoreNull = true;

  static ClientMessage _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ClientMessage',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ClientMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ClientMessage>(map);
  }

  static ClientMessage fromJson(String json) {
    return ensureInitialized().decodeJson<ClientMessage>(json);
  }
}

mixin ClientMessageMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ClientMessageCopyWith<ClientMessage, ClientMessage, ClientMessage>
  get copyWith;
}

abstract class ClientMessageCopyWith<$R, $In extends ClientMessage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ClientMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class CreateRoomMapper extends SubClassMapperBase<CreateRoom> {
  CreateRoomMapper._();

  static CreateRoomMapper? _instance;
  static CreateRoomMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreateRoomMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
      RoomConfigMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CreateRoom';

  static String _$hostName(CreateRoom v) => v.hostName;
  static const Field<CreateRoom, String> _f$hostName = Field(
    'hostName',
    _$hostName,
  );
  static RoomConfig _$config(CreateRoom v) => v.config;
  static const Field<CreateRoom, RoomConfig> _f$config = Field(
    'config',
    _$config,
  );

  @override
  final MappableFields<CreateRoom> fields = const {
    #hostName: _f$hostName,
    #config: _f$config,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'CREATE_ROOM';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static CreateRoom _instantiate(DecodingData data) {
    return CreateRoom(
      hostName: data.dec(_f$hostName),
      config: data.dec(_f$config),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreateRoom fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreateRoom>(map);
  }

  static CreateRoom fromJson(String json) {
    return ensureInitialized().decodeJson<CreateRoom>(json);
  }
}

mixin CreateRoomMappable {
  String toJson() {
    return CreateRoomMapper.ensureInitialized().encodeJson<CreateRoom>(
      this as CreateRoom,
    );
  }

  Map<String, dynamic> toMap() {
    return CreateRoomMapper.ensureInitialized().encodeMap<CreateRoom>(
      this as CreateRoom,
    );
  }

  CreateRoomCopyWith<CreateRoom, CreateRoom, CreateRoom> get copyWith =>
      _CreateRoomCopyWithImpl<CreateRoom, CreateRoom>(
        this as CreateRoom,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CreateRoomMapper.ensureInitialized().stringifyValue(
      this as CreateRoom,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreateRoomMapper.ensureInitialized().equalsValue(
      this as CreateRoom,
      other,
    );
  }

  @override
  int get hashCode {
    return CreateRoomMapper.ensureInitialized().hashValue(this as CreateRoom);
  }
}

extension CreateRoomValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreateRoom, $Out> {
  CreateRoomCopyWith<$R, CreateRoom, $Out> get $asCreateRoom =>
      $base.as((v, t, t2) => _CreateRoomCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CreateRoomCopyWith<$R, $In extends CreateRoom, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  RoomConfigCopyWith<$R, RoomConfig, RoomConfig> get config;
  @override
  $R call({String? hostName, RoomConfig? config});
  CreateRoomCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CreateRoomCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreateRoom, $Out>
    implements CreateRoomCopyWith<$R, CreateRoom, $Out> {
  _CreateRoomCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreateRoom> $mapper =
      CreateRoomMapper.ensureInitialized();
  @override
  RoomConfigCopyWith<$R, RoomConfig, RoomConfig> get config =>
      $value.config.copyWith.$chain((v) => call(config: v));
  @override
  $R call({String? hostName, RoomConfig? config}) => $apply(
    FieldCopyWithData({
      if (hostName != null) #hostName: hostName,
      if (config != null) #config: config,
    }),
  );
  @override
  CreateRoom $make(CopyWithData data) => CreateRoom(
    hostName: data.get(#hostName, or: $value.hostName),
    config: data.get(#config, or: $value.config),
  );

  @override
  CreateRoomCopyWith<$R2, CreateRoom, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreateRoomCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class JoinRoomMapper extends SubClassMapperBase<JoinRoom> {
  JoinRoomMapper._();

  static JoinRoomMapper? _instance;
  static JoinRoomMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinRoomMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'JoinRoom';

  static String _$roomCode(JoinRoom v) => v.roomCode;
  static const Field<JoinRoom, String> _f$roomCode = Field(
    'roomCode',
    _$roomCode,
  );
  static String _$name(JoinRoom v) => v.name;
  static const Field<JoinRoom, String> _f$name = Field('name', _$name);
  static int? _$seatIndex(JoinRoom v) => v.seatIndex;
  static const Field<JoinRoom, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
    opt: true,
  );
  static bool _$spectator(JoinRoom v) => v.spectator;
  static const Field<JoinRoom, bool> _f$spectator = Field(
    'spectator',
    _$spectator,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<JoinRoom> fields = const {
    #roomCode: _f$roomCode,
    #name: _f$name,
    #seatIndex: _f$seatIndex,
    #spectator: _f$spectator,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'JOIN_ROOM';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static JoinRoom _instantiate(DecodingData data) {
    return JoinRoom(
      roomCode: data.dec(_f$roomCode),
      name: data.dec(_f$name),
      seatIndex: data.dec(_f$seatIndex),
      spectator: data.dec(_f$spectator),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JoinRoom fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JoinRoom>(map);
  }

  static JoinRoom fromJson(String json) {
    return ensureInitialized().decodeJson<JoinRoom>(json);
  }
}

mixin JoinRoomMappable {
  String toJson() {
    return JoinRoomMapper.ensureInitialized().encodeJson<JoinRoom>(
      this as JoinRoom,
    );
  }

  Map<String, dynamic> toMap() {
    return JoinRoomMapper.ensureInitialized().encodeMap<JoinRoom>(
      this as JoinRoom,
    );
  }

  JoinRoomCopyWith<JoinRoom, JoinRoom, JoinRoom> get copyWith =>
      _JoinRoomCopyWithImpl<JoinRoom, JoinRoom>(
        this as JoinRoom,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return JoinRoomMapper.ensureInitialized().stringifyValue(this as JoinRoom);
  }

  @override
  bool operator ==(Object other) {
    return JoinRoomMapper.ensureInitialized().equalsValue(
      this as JoinRoom,
      other,
    );
  }

  @override
  int get hashCode {
    return JoinRoomMapper.ensureInitialized().hashValue(this as JoinRoom);
  }
}

extension JoinRoomValueCopy<$R, $Out> on ObjectCopyWith<$R, JoinRoom, $Out> {
  JoinRoomCopyWith<$R, JoinRoom, $Out> get $asJoinRoom =>
      $base.as((v, t, t2) => _JoinRoomCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JoinRoomCopyWith<$R, $In extends JoinRoom, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? roomCode, String? name, int? seatIndex, bool? spectator});
  JoinRoomCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _JoinRoomCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JoinRoom, $Out>
    implements JoinRoomCopyWith<$R, JoinRoom, $Out> {
  _JoinRoomCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JoinRoom> $mapper =
      JoinRoomMapper.ensureInitialized();
  @override
  $R call({
    String? roomCode,
    String? name,
    Object? seatIndex = $none,
    bool? spectator,
  }) => $apply(
    FieldCopyWithData({
      if (roomCode != null) #roomCode: roomCode,
      if (name != null) #name: name,
      if (seatIndex != $none) #seatIndex: seatIndex,
      if (spectator != null) #spectator: spectator,
    }),
  );
  @override
  JoinRoom $make(CopyWithData data) => JoinRoom(
    roomCode: data.get(#roomCode, or: $value.roomCode),
    name: data.get(#name, or: $value.name),
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
    spectator: data.get(#spectator, or: $value.spectator),
  );

  @override
  JoinRoomCopyWith<$R2, JoinRoom, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JoinRoomCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ResumeMapper extends SubClassMapperBase<Resume> {
  ResumeMapper._();

  static ResumeMapper? _instance;
  static ResumeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ResumeMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Resume';

  static String _$roomCode(Resume v) => v.roomCode;
  static const Field<Resume, String> _f$roomCode = Field(
    'roomCode',
    _$roomCode,
  );
  static String _$sessionToken(Resume v) => v.sessionToken;
  static const Field<Resume, String> _f$sessionToken = Field(
    'sessionToken',
    _$sessionToken,
  );
  static int? _$lastStateVersion(Resume v) => v.lastStateVersion;
  static const Field<Resume, int> _f$lastStateVersion = Field(
    'lastStateVersion',
    _$lastStateVersion,
    opt: true,
  );
  static String? _$hostToken(Resume v) => v.hostToken;
  static const Field<Resume, String> _f$hostToken = Field(
    'hostToken',
    _$hostToken,
    opt: true,
  );

  @override
  final MappableFields<Resume> fields = const {
    #roomCode: _f$roomCode,
    #sessionToken: _f$sessionToken,
    #lastStateVersion: _f$lastStateVersion,
    #hostToken: _f$hostToken,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'RESUME';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static Resume _instantiate(DecodingData data) {
    return Resume(
      roomCode: data.dec(_f$roomCode),
      sessionToken: data.dec(_f$sessionToken),
      lastStateVersion: data.dec(_f$lastStateVersion),
      hostToken: data.dec(_f$hostToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Resume fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Resume>(map);
  }

  static Resume fromJson(String json) {
    return ensureInitialized().decodeJson<Resume>(json);
  }
}

mixin ResumeMappable {
  String toJson() {
    return ResumeMapper.ensureInitialized().encodeJson<Resume>(this as Resume);
  }

  Map<String, dynamic> toMap() {
    return ResumeMapper.ensureInitialized().encodeMap<Resume>(this as Resume);
  }

  ResumeCopyWith<Resume, Resume, Resume> get copyWith =>
      _ResumeCopyWithImpl<Resume, Resume>(this as Resume, $identity, $identity);
  @override
  String toString() {
    return ResumeMapper.ensureInitialized().stringifyValue(this as Resume);
  }

  @override
  bool operator ==(Object other) {
    return ResumeMapper.ensureInitialized().equalsValue(this as Resume, other);
  }

  @override
  int get hashCode {
    return ResumeMapper.ensureInitialized().hashValue(this as Resume);
  }
}

extension ResumeValueCopy<$R, $Out> on ObjectCopyWith<$R, Resume, $Out> {
  ResumeCopyWith<$R, Resume, $Out> get $asResume =>
      $base.as((v, t, t2) => _ResumeCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ResumeCopyWith<$R, $In extends Resume, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? roomCode,
    String? sessionToken,
    int? lastStateVersion,
    String? hostToken,
  });
  ResumeCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ResumeCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Resume, $Out>
    implements ResumeCopyWith<$R, Resume, $Out> {
  _ResumeCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Resume> $mapper = ResumeMapper.ensureInitialized();
  @override
  $R call({
    String? roomCode,
    String? sessionToken,
    Object? lastStateVersion = $none,
    Object? hostToken = $none,
  }) => $apply(
    FieldCopyWithData({
      if (roomCode != null) #roomCode: roomCode,
      if (sessionToken != null) #sessionToken: sessionToken,
      if (lastStateVersion != $none) #lastStateVersion: lastStateVersion,
      if (hostToken != $none) #hostToken: hostToken,
    }),
  );
  @override
  Resume $make(CopyWithData data) => Resume(
    roomCode: data.get(#roomCode, or: $value.roomCode),
    sessionToken: data.get(#sessionToken, or: $value.sessionToken),
    lastStateVersion: data.get(#lastStateVersion, or: $value.lastStateVersion),
    hostToken: data.get(#hostToken, or: $value.hostToken),
  );

  @override
  ResumeCopyWith<$R2, Resume, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ResumeCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class StartHandMapper extends SubClassMapperBase<StartHand> {
  StartHandMapper._();

  static StartHandMapper? _instance;
  static StartHandMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = StartHandMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'StartHand';

  @override
  final MappableFields<StartHand> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'START_HAND';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static StartHand _instantiate(DecodingData data) {
    return StartHand();
  }

  @override
  final Function instantiate = _instantiate;

  static StartHand fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<StartHand>(map);
  }

  static StartHand fromJson(String json) {
    return ensureInitialized().decodeJson<StartHand>(json);
  }
}

mixin StartHandMappable {
  String toJson() {
    return StartHandMapper.ensureInitialized().encodeJson<StartHand>(
      this as StartHand,
    );
  }

  Map<String, dynamic> toMap() {
    return StartHandMapper.ensureInitialized().encodeMap<StartHand>(
      this as StartHand,
    );
  }

  StartHandCopyWith<StartHand, StartHand, StartHand> get copyWith =>
      _StartHandCopyWithImpl<StartHand, StartHand>(
        this as StartHand,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return StartHandMapper.ensureInitialized().stringifyValue(
      this as StartHand,
    );
  }

  @override
  bool operator ==(Object other) {
    return StartHandMapper.ensureInitialized().equalsValue(
      this as StartHand,
      other,
    );
  }

  @override
  int get hashCode {
    return StartHandMapper.ensureInitialized().hashValue(this as StartHand);
  }
}

extension StartHandValueCopy<$R, $Out> on ObjectCopyWith<$R, StartHand, $Out> {
  StartHandCopyWith<$R, StartHand, $Out> get $asStartHand =>
      $base.as((v, t, t2) => _StartHandCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class StartHandCopyWith<$R, $In extends StartHand, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  StartHandCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _StartHandCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, StartHand, $Out>
    implements StartHandCopyWith<$R, StartHand, $Out> {
  _StartHandCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<StartHand> $mapper =
      StartHandMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  StartHand $make(CopyWithData data) => StartHand();

  @override
  StartHandCopyWith<$R2, StartHand, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _StartHandCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GameActionMapper extends SubClassMapperBase<GameAction> {
  GameActionMapper._();

  static GameActionMapper? _instance;
  static GameActionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GameActionMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
      PlayerActionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GameAction';

  static int _$actionSeq(GameAction v) => v.actionSeq;
  static const Field<GameAction, int> _f$actionSeq = Field(
    'actionSeq',
    _$actionSeq,
  );
  static PlayerAction _$action(GameAction v) => v.action;
  static const Field<GameAction, PlayerAction> _f$action = Field(
    'action',
    _$action,
  );

  @override
  final MappableFields<GameAction> fields = const {
    #actionSeq: _f$actionSeq,
    #action: _f$action,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'GAME_ACTION';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static GameAction _instantiate(DecodingData data) {
    return GameAction(
      actionSeq: data.dec(_f$actionSeq),
      action: data.dec(_f$action),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GameAction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GameAction>(map);
  }

  static GameAction fromJson(String json) {
    return ensureInitialized().decodeJson<GameAction>(json);
  }
}

mixin GameActionMappable {
  String toJson() {
    return GameActionMapper.ensureInitialized().encodeJson<GameAction>(
      this as GameAction,
    );
  }

  Map<String, dynamic> toMap() {
    return GameActionMapper.ensureInitialized().encodeMap<GameAction>(
      this as GameAction,
    );
  }

  GameActionCopyWith<GameAction, GameAction, GameAction> get copyWith =>
      _GameActionCopyWithImpl<GameAction, GameAction>(
        this as GameAction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GameActionMapper.ensureInitialized().stringifyValue(
      this as GameAction,
    );
  }

  @override
  bool operator ==(Object other) {
    return GameActionMapper.ensureInitialized().equalsValue(
      this as GameAction,
      other,
    );
  }

  @override
  int get hashCode {
    return GameActionMapper.ensureInitialized().hashValue(this as GameAction);
  }
}

extension GameActionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GameAction, $Out> {
  GameActionCopyWith<$R, GameAction, $Out> get $asGameAction =>
      $base.as((v, t, t2) => _GameActionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GameActionCopyWith<$R, $In extends GameAction, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  PlayerActionCopyWith<$R, PlayerAction, PlayerAction> get action;
  @override
  $R call({int? actionSeq, PlayerAction? action});
  GameActionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GameActionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GameAction, $Out>
    implements GameActionCopyWith<$R, GameAction, $Out> {
  _GameActionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GameAction> $mapper =
      GameActionMapper.ensureInitialized();
  @override
  PlayerActionCopyWith<$R, PlayerAction, PlayerAction> get action =>
      $value.action.copyWith.$chain((v) => call(action: v));
  @override
  $R call({int? actionSeq, PlayerAction? action}) => $apply(
    FieldCopyWithData({
      if (actionSeq != null) #actionSeq: actionSeq,
      if (action != null) #action: action,
    }),
  );
  @override
  GameAction $make(CopyWithData data) => GameAction(
    actionSeq: data.get(#actionSeq, or: $value.actionSeq),
    action: data.get(#action, or: $value.action),
  );

  @override
  GameActionCopyWith<$R2, GameAction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GameActionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class BeginShowdownMapper extends SubClassMapperBase<BeginShowdown> {
  BeginShowdownMapper._();

  static BeginShowdownMapper? _instance;
  static BeginShowdownMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BeginShowdownMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'BeginShowdown';

  @override
  final MappableFields<BeginShowdown> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'BEGIN_SHOWDOWN';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static BeginShowdown _instantiate(DecodingData data) {
    return BeginShowdown();
  }

  @override
  final Function instantiate = _instantiate;

  static BeginShowdown fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BeginShowdown>(map);
  }

  static BeginShowdown fromJson(String json) {
    return ensureInitialized().decodeJson<BeginShowdown>(json);
  }
}

mixin BeginShowdownMappable {
  String toJson() {
    return BeginShowdownMapper.ensureInitialized().encodeJson<BeginShowdown>(
      this as BeginShowdown,
    );
  }

  Map<String, dynamic> toMap() {
    return BeginShowdownMapper.ensureInitialized().encodeMap<BeginShowdown>(
      this as BeginShowdown,
    );
  }

  BeginShowdownCopyWith<BeginShowdown, BeginShowdown, BeginShowdown>
  get copyWith => _BeginShowdownCopyWithImpl<BeginShowdown, BeginShowdown>(
    this as BeginShowdown,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return BeginShowdownMapper.ensureInitialized().stringifyValue(
      this as BeginShowdown,
    );
  }

  @override
  bool operator ==(Object other) {
    return BeginShowdownMapper.ensureInitialized().equalsValue(
      this as BeginShowdown,
      other,
    );
  }

  @override
  int get hashCode {
    return BeginShowdownMapper.ensureInitialized().hashValue(
      this as BeginShowdown,
    );
  }
}

extension BeginShowdownValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BeginShowdown, $Out> {
  BeginShowdownCopyWith<$R, BeginShowdown, $Out> get $asBeginShowdown =>
      $base.as((v, t, t2) => _BeginShowdownCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BeginShowdownCopyWith<$R, $In extends BeginShowdown, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  BeginShowdownCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BeginShowdownCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BeginShowdown, $Out>
    implements BeginShowdownCopyWith<$R, BeginShowdown, $Out> {
  _BeginShowdownCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BeginShowdown> $mapper =
      BeginShowdownMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  BeginShowdown $make(CopyWithData data) => BeginShowdown();

  @override
  BeginShowdownCopyWith<$R2, BeginShowdown, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BeginShowdownCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ResolveShowdownMapper extends SubClassMapperBase<ResolveShowdown> {
  ResolveShowdownMapper._();

  static ResolveShowdownMapper? _instance;
  static ResolveShowdownMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ResolveShowdownMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
      WireAllocationMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ResolveShowdown';

  static List<WireAllocation> _$allocations(ResolveShowdown v) => v.allocations;
  static const Field<ResolveShowdown, List<WireAllocation>> _f$allocations =
      Field('allocations', _$allocations);

  @override
  final MappableFields<ResolveShowdown> fields = const {
    #allocations: _f$allocations,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'RESOLVE_SHOWDOWN';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static ResolveShowdown _instantiate(DecodingData data) {
    return ResolveShowdown(allocations: data.dec(_f$allocations));
  }

  @override
  final Function instantiate = _instantiate;

  static ResolveShowdown fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ResolveShowdown>(map);
  }

  static ResolveShowdown fromJson(String json) {
    return ensureInitialized().decodeJson<ResolveShowdown>(json);
  }
}

mixin ResolveShowdownMappable {
  String toJson() {
    return ResolveShowdownMapper.ensureInitialized()
        .encodeJson<ResolveShowdown>(this as ResolveShowdown);
  }

  Map<String, dynamic> toMap() {
    return ResolveShowdownMapper.ensureInitialized().encodeMap<ResolveShowdown>(
      this as ResolveShowdown,
    );
  }

  ResolveShowdownCopyWith<ResolveShowdown, ResolveShowdown, ResolveShowdown>
  get copyWith =>
      _ResolveShowdownCopyWithImpl<ResolveShowdown, ResolveShowdown>(
        this as ResolveShowdown,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ResolveShowdownMapper.ensureInitialized().stringifyValue(
      this as ResolveShowdown,
    );
  }

  @override
  bool operator ==(Object other) {
    return ResolveShowdownMapper.ensureInitialized().equalsValue(
      this as ResolveShowdown,
      other,
    );
  }

  @override
  int get hashCode {
    return ResolveShowdownMapper.ensureInitialized().hashValue(
      this as ResolveShowdown,
    );
  }
}

extension ResolveShowdownValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ResolveShowdown, $Out> {
  ResolveShowdownCopyWith<$R, ResolveShowdown, $Out> get $asResolveShowdown =>
      $base.as((v, t, t2) => _ResolveShowdownCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ResolveShowdownCopyWith<$R, $In extends ResolveShowdown, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    WireAllocation,
    WireAllocationCopyWith<$R, WireAllocation, WireAllocation>
  >
  get allocations;
  @override
  $R call({List<WireAllocation>? allocations});
  ResolveShowdownCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ResolveShowdownCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ResolveShowdown, $Out>
    implements ResolveShowdownCopyWith<$R, ResolveShowdown, $Out> {
  _ResolveShowdownCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ResolveShowdown> $mapper =
      ResolveShowdownMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    WireAllocation,
    WireAllocationCopyWith<$R, WireAllocation, WireAllocation>
  >
  get allocations => ListCopyWith(
    $value.allocations,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(allocations: v),
  );
  @override
  $R call({List<WireAllocation>? allocations}) => $apply(
    FieldCopyWithData({if (allocations != null) #allocations: allocations}),
  );
  @override
  ResolveShowdown $make(CopyWithData data) => ResolveShowdown(
    allocations: data.get(#allocations, or: $value.allocations),
  );

  @override
  ResolveShowdownCopyWith<$R2, ResolveShowdown, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ResolveShowdownCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class UndoMapper extends SubClassMapperBase<Undo> {
  UndoMapper._();

  static UndoMapper? _instance;
  static UndoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UndoMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Undo';

  @override
  final MappableFields<Undo> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'UNDO';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static Undo _instantiate(DecodingData data) {
    return Undo();
  }

  @override
  final Function instantiate = _instantiate;

  static Undo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Undo>(map);
  }

  static Undo fromJson(String json) {
    return ensureInitialized().decodeJson<Undo>(json);
  }
}

mixin UndoMappable {
  String toJson() {
    return UndoMapper.ensureInitialized().encodeJson<Undo>(this as Undo);
  }

  Map<String, dynamic> toMap() {
    return UndoMapper.ensureInitialized().encodeMap<Undo>(this as Undo);
  }

  UndoCopyWith<Undo, Undo, Undo> get copyWith =>
      _UndoCopyWithImpl<Undo, Undo>(this as Undo, $identity, $identity);
  @override
  String toString() {
    return UndoMapper.ensureInitialized().stringifyValue(this as Undo);
  }

  @override
  bool operator ==(Object other) {
    return UndoMapper.ensureInitialized().equalsValue(this as Undo, other);
  }

  @override
  int get hashCode {
    return UndoMapper.ensureInitialized().hashValue(this as Undo);
  }
}

extension UndoValueCopy<$R, $Out> on ObjectCopyWith<$R, Undo, $Out> {
  UndoCopyWith<$R, Undo, $Out> get $asUndo =>
      $base.as((v, t, t2) => _UndoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class UndoCopyWith<$R, $In extends Undo, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  UndoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _UndoCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Undo, $Out>
    implements UndoCopyWith<$R, Undo, $Out> {
  _UndoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Undo> $mapper = UndoMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  Undo $make(CopyWithData data) => Undo();

  @override
  UndoCopyWith<$R2, Undo, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _UndoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PauseMapper extends SubClassMapperBase<Pause> {
  PauseMapper._();

  static PauseMapper? _instance;
  static PauseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PauseMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Pause';

  static String? _$reason(Pause v) => v.reason;
  static const Field<Pause, String> _f$reason = Field(
    'reason',
    _$reason,
    opt: true,
  );

  @override
  final MappableFields<Pause> fields = const {#reason: _f$reason};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PAUSE';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static Pause _instantiate(DecodingData data) {
    return Pause(reason: data.dec(_f$reason));
  }

  @override
  final Function instantiate = _instantiate;

  static Pause fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Pause>(map);
  }

  static Pause fromJson(String json) {
    return ensureInitialized().decodeJson<Pause>(json);
  }
}

mixin PauseMappable {
  String toJson() {
    return PauseMapper.ensureInitialized().encodeJson<Pause>(this as Pause);
  }

  Map<String, dynamic> toMap() {
    return PauseMapper.ensureInitialized().encodeMap<Pause>(this as Pause);
  }

  PauseCopyWith<Pause, Pause, Pause> get copyWith =>
      _PauseCopyWithImpl<Pause, Pause>(this as Pause, $identity, $identity);
  @override
  String toString() {
    return PauseMapper.ensureInitialized().stringifyValue(this as Pause);
  }

  @override
  bool operator ==(Object other) {
    return PauseMapper.ensureInitialized().equalsValue(this as Pause, other);
  }

  @override
  int get hashCode {
    return PauseMapper.ensureInitialized().hashValue(this as Pause);
  }
}

extension PauseValueCopy<$R, $Out> on ObjectCopyWith<$R, Pause, $Out> {
  PauseCopyWith<$R, Pause, $Out> get $asPause =>
      $base.as((v, t, t2) => _PauseCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PauseCopyWith<$R, $In extends Pause, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? reason});
  PauseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PauseCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Pause, $Out>
    implements PauseCopyWith<$R, Pause, $Out> {
  _PauseCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Pause> $mapper = PauseMapper.ensureInitialized();
  @override
  $R call({Object? reason = $none}) =>
      $apply(FieldCopyWithData({if (reason != $none) #reason: reason}));
  @override
  Pause $make(CopyWithData data) =>
      Pause(reason: data.get(#reason, or: $value.reason));

  @override
  PauseCopyWith<$R2, Pause, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PauseCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ResumeGameMapper extends SubClassMapperBase<ResumeGame> {
  ResumeGameMapper._();

  static ResumeGameMapper? _instance;
  static ResumeGameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ResumeGameMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ResumeGame';

  @override
  final MappableFields<ResumeGame> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'RESUME_GAME';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static ResumeGame _instantiate(DecodingData data) {
    return ResumeGame();
  }

  @override
  final Function instantiate = _instantiate;

  static ResumeGame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ResumeGame>(map);
  }

  static ResumeGame fromJson(String json) {
    return ensureInitialized().decodeJson<ResumeGame>(json);
  }
}

mixin ResumeGameMappable {
  String toJson() {
    return ResumeGameMapper.ensureInitialized().encodeJson<ResumeGame>(
      this as ResumeGame,
    );
  }

  Map<String, dynamic> toMap() {
    return ResumeGameMapper.ensureInitialized().encodeMap<ResumeGame>(
      this as ResumeGame,
    );
  }

  ResumeGameCopyWith<ResumeGame, ResumeGame, ResumeGame> get copyWith =>
      _ResumeGameCopyWithImpl<ResumeGame, ResumeGame>(
        this as ResumeGame,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ResumeGameMapper.ensureInitialized().stringifyValue(
      this as ResumeGame,
    );
  }

  @override
  bool operator ==(Object other) {
    return ResumeGameMapper.ensureInitialized().equalsValue(
      this as ResumeGame,
      other,
    );
  }

  @override
  int get hashCode {
    return ResumeGameMapper.ensureInitialized().hashValue(this as ResumeGame);
  }
}

extension ResumeGameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ResumeGame, $Out> {
  ResumeGameCopyWith<$R, ResumeGame, $Out> get $asResumeGame =>
      $base.as((v, t, t2) => _ResumeGameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ResumeGameCopyWith<$R, $In extends ResumeGame, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ResumeGameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ResumeGameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ResumeGame, $Out>
    implements ResumeGameCopyWith<$R, ResumeGame, $Out> {
  _ResumeGameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ResumeGame> $mapper =
      ResumeGameMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ResumeGame $make(CopyWithData data) => ResumeGame();

  @override
  ResumeGameCopyWith<$R2, ResumeGame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ResumeGameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ApproveRebuyMapper extends SubClassMapperBase<ApproveRebuy> {
  ApproveRebuyMapper._();

  static ApproveRebuyMapper? _instance;
  static ApproveRebuyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ApproveRebuyMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ApproveRebuy';

  static String _$playerId(ApproveRebuy v) => v.playerId;
  static const Field<ApproveRebuy, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static int _$amount(ApproveRebuy v) => v.amount;
  static const Field<ApproveRebuy, int> _f$amount = Field('amount', _$amount);

  @override
  final MappableFields<ApproveRebuy> fields = const {
    #playerId: _f$playerId,
    #amount: _f$amount,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'APPROVE_REBUY';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static ApproveRebuy _instantiate(DecodingData data) {
    return ApproveRebuy(
      playerId: data.dec(_f$playerId),
      amount: data.dec(_f$amount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ApproveRebuy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ApproveRebuy>(map);
  }

  static ApproveRebuy fromJson(String json) {
    return ensureInitialized().decodeJson<ApproveRebuy>(json);
  }
}

mixin ApproveRebuyMappable {
  String toJson() {
    return ApproveRebuyMapper.ensureInitialized().encodeJson<ApproveRebuy>(
      this as ApproveRebuy,
    );
  }

  Map<String, dynamic> toMap() {
    return ApproveRebuyMapper.ensureInitialized().encodeMap<ApproveRebuy>(
      this as ApproveRebuy,
    );
  }

  ApproveRebuyCopyWith<ApproveRebuy, ApproveRebuy, ApproveRebuy> get copyWith =>
      _ApproveRebuyCopyWithImpl<ApproveRebuy, ApproveRebuy>(
        this as ApproveRebuy,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ApproveRebuyMapper.ensureInitialized().stringifyValue(
      this as ApproveRebuy,
    );
  }

  @override
  bool operator ==(Object other) {
    return ApproveRebuyMapper.ensureInitialized().equalsValue(
      this as ApproveRebuy,
      other,
    );
  }

  @override
  int get hashCode {
    return ApproveRebuyMapper.ensureInitialized().hashValue(
      this as ApproveRebuy,
    );
  }
}

extension ApproveRebuyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ApproveRebuy, $Out> {
  ApproveRebuyCopyWith<$R, ApproveRebuy, $Out> get $asApproveRebuy =>
      $base.as((v, t, t2) => _ApproveRebuyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ApproveRebuyCopyWith<$R, $In extends ApproveRebuy, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId, int? amount});
  ApproveRebuyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ApproveRebuyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ApproveRebuy, $Out>
    implements ApproveRebuyCopyWith<$R, ApproveRebuy, $Out> {
  _ApproveRebuyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ApproveRebuy> $mapper =
      ApproveRebuyMapper.ensureInitialized();
  @override
  $R call({String? playerId, int? amount}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (amount != null) #amount: amount,
    }),
  );
  @override
  ApproveRebuy $make(CopyWithData data) => ApproveRebuy(
    playerId: data.get(#playerId, or: $value.playerId),
    amount: data.get(#amount, or: $value.amount),
  );

  @override
  ApproveRebuyCopyWith<$R2, ApproveRebuy, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ApproveRebuyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class KickMapper extends SubClassMapperBase<Kick> {
  KickMapper._();

  static KickMapper? _instance;
  static KickMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = KickMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Kick';

  static String _$playerId(Kick v) => v.playerId;
  static const Field<Kick, String> _f$playerId = Field('playerId', _$playerId);

  @override
  final MappableFields<Kick> fields = const {#playerId: _f$playerId};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'KICK';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static Kick _instantiate(DecodingData data) {
    return Kick(playerId: data.dec(_f$playerId));
  }

  @override
  final Function instantiate = _instantiate;

  static Kick fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Kick>(map);
  }

  static Kick fromJson(String json) {
    return ensureInitialized().decodeJson<Kick>(json);
  }
}

mixin KickMappable {
  String toJson() {
    return KickMapper.ensureInitialized().encodeJson<Kick>(this as Kick);
  }

  Map<String, dynamic> toMap() {
    return KickMapper.ensureInitialized().encodeMap<Kick>(this as Kick);
  }

  KickCopyWith<Kick, Kick, Kick> get copyWith =>
      _KickCopyWithImpl<Kick, Kick>(this as Kick, $identity, $identity);
  @override
  String toString() {
    return KickMapper.ensureInitialized().stringifyValue(this as Kick);
  }

  @override
  bool operator ==(Object other) {
    return KickMapper.ensureInitialized().equalsValue(this as Kick, other);
  }

  @override
  int get hashCode {
    return KickMapper.ensureInitialized().hashValue(this as Kick);
  }
}

extension KickValueCopy<$R, $Out> on ObjectCopyWith<$R, Kick, $Out> {
  KickCopyWith<$R, Kick, $Out> get $asKick =>
      $base.as((v, t, t2) => _KickCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class KickCopyWith<$R, $In extends Kick, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId});
  KickCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _KickCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Kick, $Out>
    implements KickCopyWith<$R, Kick, $Out> {
  _KickCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Kick> $mapper = KickMapper.ensureInitialized();
  @override
  $R call({String? playerId}) =>
      $apply(FieldCopyWithData({if (playerId != null) #playerId: playerId}));
  @override
  Kick $make(CopyWithData data) =>
      Kick(playerId: data.get(#playerId, or: $value.playerId));

  @override
  KickCopyWith<$R2, Kick, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _KickCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MoveSeatMapper extends SubClassMapperBase<MoveSeat> {
  MoveSeatMapper._();

  static MoveSeatMapper? _instance;
  static MoveSeatMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MoveSeatMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'MoveSeat';

  static String _$playerId(MoveSeat v) => v.playerId;
  static const Field<MoveSeat, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static int _$seatIndex(MoveSeat v) => v.seatIndex;
  static const Field<MoveSeat, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );

  @override
  final MappableFields<MoveSeat> fields = const {
    #playerId: _f$playerId,
    #seatIndex: _f$seatIndex,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'MOVE_SEAT';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static MoveSeat _instantiate(DecodingData data) {
    return MoveSeat(
      playerId: data.dec(_f$playerId),
      seatIndex: data.dec(_f$seatIndex),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MoveSeat fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MoveSeat>(map);
  }

  static MoveSeat fromJson(String json) {
    return ensureInitialized().decodeJson<MoveSeat>(json);
  }
}

mixin MoveSeatMappable {
  String toJson() {
    return MoveSeatMapper.ensureInitialized().encodeJson<MoveSeat>(
      this as MoveSeat,
    );
  }

  Map<String, dynamic> toMap() {
    return MoveSeatMapper.ensureInitialized().encodeMap<MoveSeat>(
      this as MoveSeat,
    );
  }

  MoveSeatCopyWith<MoveSeat, MoveSeat, MoveSeat> get copyWith =>
      _MoveSeatCopyWithImpl<MoveSeat, MoveSeat>(
        this as MoveSeat,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MoveSeatMapper.ensureInitialized().stringifyValue(this as MoveSeat);
  }

  @override
  bool operator ==(Object other) {
    return MoveSeatMapper.ensureInitialized().equalsValue(
      this as MoveSeat,
      other,
    );
  }

  @override
  int get hashCode {
    return MoveSeatMapper.ensureInitialized().hashValue(this as MoveSeat);
  }
}

extension MoveSeatValueCopy<$R, $Out> on ObjectCopyWith<$R, MoveSeat, $Out> {
  MoveSeatCopyWith<$R, MoveSeat, $Out> get $asMoveSeat =>
      $base.as((v, t, t2) => _MoveSeatCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MoveSeatCopyWith<$R, $In extends MoveSeat, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId, int? seatIndex});
  MoveSeatCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MoveSeatCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MoveSeat, $Out>
    implements MoveSeatCopyWith<$R, MoveSeat, $Out> {
  _MoveSeatCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MoveSeat> $mapper =
      MoveSeatMapper.ensureInitialized();
  @override
  $R call({String? playerId, int? seatIndex}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (seatIndex != null) #seatIndex: seatIndex,
    }),
  );
  @override
  MoveSeat $make(CopyWithData data) => MoveSeat(
    playerId: data.get(#playerId, or: $value.playerId),
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
  );

  @override
  MoveSeatCopyWith<$R2, MoveSeat, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MoveSeatCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ChooseSeatMapper extends SubClassMapperBase<ChooseSeat> {
  ChooseSeatMapper._();

  static ChooseSeatMapper? _instance;
  static ChooseSeatMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ChooseSeatMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ChooseSeat';

  static int _$seatIndex(ChooseSeat v) => v.seatIndex;
  static const Field<ChooseSeat, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );

  @override
  final MappableFields<ChooseSeat> fields = const {#seatIndex: _f$seatIndex};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'CHOOSE_SEAT';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static ChooseSeat _instantiate(DecodingData data) {
    return ChooseSeat(seatIndex: data.dec(_f$seatIndex));
  }

  @override
  final Function instantiate = _instantiate;

  static ChooseSeat fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ChooseSeat>(map);
  }

  static ChooseSeat fromJson(String json) {
    return ensureInitialized().decodeJson<ChooseSeat>(json);
  }
}

mixin ChooseSeatMappable {
  String toJson() {
    return ChooseSeatMapper.ensureInitialized().encodeJson<ChooseSeat>(
      this as ChooseSeat,
    );
  }

  Map<String, dynamic> toMap() {
    return ChooseSeatMapper.ensureInitialized().encodeMap<ChooseSeat>(
      this as ChooseSeat,
    );
  }

  ChooseSeatCopyWith<ChooseSeat, ChooseSeat, ChooseSeat> get copyWith =>
      _ChooseSeatCopyWithImpl<ChooseSeat, ChooseSeat>(
        this as ChooseSeat,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ChooseSeatMapper.ensureInitialized().stringifyValue(
      this as ChooseSeat,
    );
  }

  @override
  bool operator ==(Object other) {
    return ChooseSeatMapper.ensureInitialized().equalsValue(
      this as ChooseSeat,
      other,
    );
  }

  @override
  int get hashCode {
    return ChooseSeatMapper.ensureInitialized().hashValue(this as ChooseSeat);
  }
}

extension ChooseSeatValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ChooseSeat, $Out> {
  ChooseSeatCopyWith<$R, ChooseSeat, $Out> get $asChooseSeat =>
      $base.as((v, t, t2) => _ChooseSeatCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ChooseSeatCopyWith<$R, $In extends ChooseSeat, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? seatIndex});
  ChooseSeatCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ChooseSeatCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ChooseSeat, $Out>
    implements ChooseSeatCopyWith<$R, ChooseSeat, $Out> {
  _ChooseSeatCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ChooseSeat> $mapper =
      ChooseSeatMapper.ensureInitialized();
  @override
  $R call({int? seatIndex}) =>
      $apply(FieldCopyWithData({if (seatIndex != null) #seatIndex: seatIndex}));
  @override
  ChooseSeat $make(CopyWithData data) =>
      ChooseSeat(seatIndex: data.get(#seatIndex, or: $value.seatIndex));

  @override
  ChooseSeatCopyWith<$R2, ChooseSeat, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ChooseSeatCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomConfigureMapper extends SubClassMapperBase<RoomConfigure> {
  RoomConfigureMapper._();

  static RoomConfigureMapper? _instance;
  static RoomConfigureMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomConfigureMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
      RoomConfigMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'RoomConfigure';

  static RoomConfig _$config(RoomConfigure v) => v.config;
  static const Field<RoomConfigure, RoomConfig> _f$config = Field(
    'config',
    _$config,
  );

  @override
  final MappableFields<RoomConfigure> fields = const {#config: _f$config};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ROOM_CONFIGURE';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static RoomConfigure _instantiate(DecodingData data) {
    return RoomConfigure(config: data.dec(_f$config));
  }

  @override
  final Function instantiate = _instantiate;

  static RoomConfigure fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomConfigure>(map);
  }

  static RoomConfigure fromJson(String json) {
    return ensureInitialized().decodeJson<RoomConfigure>(json);
  }
}

mixin RoomConfigureMappable {
  String toJson() {
    return RoomConfigureMapper.ensureInitialized().encodeJson<RoomConfigure>(
      this as RoomConfigure,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomConfigureMapper.ensureInitialized().encodeMap<RoomConfigure>(
      this as RoomConfigure,
    );
  }

  RoomConfigureCopyWith<RoomConfigure, RoomConfigure, RoomConfigure>
  get copyWith => _RoomConfigureCopyWithImpl<RoomConfigure, RoomConfigure>(
    this as RoomConfigure,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return RoomConfigureMapper.ensureInitialized().stringifyValue(
      this as RoomConfigure,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomConfigureMapper.ensureInitialized().equalsValue(
      this as RoomConfigure,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomConfigureMapper.ensureInitialized().hashValue(
      this as RoomConfigure,
    );
  }
}

extension RoomConfigureValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomConfigure, $Out> {
  RoomConfigureCopyWith<$R, RoomConfigure, $Out> get $asRoomConfigure =>
      $base.as((v, t, t2) => _RoomConfigureCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomConfigureCopyWith<$R, $In extends RoomConfigure, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  RoomConfigCopyWith<$R, RoomConfig, RoomConfig> get config;
  @override
  $R call({RoomConfig? config});
  RoomConfigureCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomConfigureCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomConfigure, $Out>
    implements RoomConfigureCopyWith<$R, RoomConfigure, $Out> {
  _RoomConfigureCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomConfigure> $mapper =
      RoomConfigureMapper.ensureInitialized();
  @override
  RoomConfigCopyWith<$R, RoomConfig, RoomConfig> get config =>
      $value.config.copyWith.$chain((v) => call(config: v));
  @override
  $R call({RoomConfig? config}) =>
      $apply(FieldCopyWithData({if (config != null) #config: config}));
  @override
  RoomConfigure $make(CopyWithData data) =>
      RoomConfigure(config: data.get(#config, or: $value.config));

  @override
  RoomConfigureCopyWith<$R2, RoomConfigure, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomConfigureCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EndGameMapper extends SubClassMapperBase<EndGame> {
  EndGameMapper._();

  static EndGameMapper? _instance;
  static EndGameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EndGameMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EndGame';

  @override
  final MappableFields<EndGame> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'END_GAME';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static EndGame _instantiate(DecodingData data) {
    return EndGame();
  }

  @override
  final Function instantiate = _instantiate;

  static EndGame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EndGame>(map);
  }

  static EndGame fromJson(String json) {
    return ensureInitialized().decodeJson<EndGame>(json);
  }
}

mixin EndGameMappable {
  String toJson() {
    return EndGameMapper.ensureInitialized().encodeJson<EndGame>(
      this as EndGame,
    );
  }

  Map<String, dynamic> toMap() {
    return EndGameMapper.ensureInitialized().encodeMap<EndGame>(
      this as EndGame,
    );
  }

  EndGameCopyWith<EndGame, EndGame, EndGame> get copyWith =>
      _EndGameCopyWithImpl<EndGame, EndGame>(
        this as EndGame,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EndGameMapper.ensureInitialized().stringifyValue(this as EndGame);
  }

  @override
  bool operator ==(Object other) {
    return EndGameMapper.ensureInitialized().equalsValue(
      this as EndGame,
      other,
    );
  }

  @override
  int get hashCode {
    return EndGameMapper.ensureInitialized().hashValue(this as EndGame);
  }
}

extension EndGameValueCopy<$R, $Out> on ObjectCopyWith<$R, EndGame, $Out> {
  EndGameCopyWith<$R, EndGame, $Out> get $asEndGame =>
      $base.as((v, t, t2) => _EndGameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EndGameCopyWith<$R, $In extends EndGame, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EndGameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EndGameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EndGame, $Out>
    implements EndGameCopyWith<$R, EndGame, $Out> {
  _EndGameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EndGame> $mapper =
      EndGameMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EndGame $make(CopyWithData data) => EndGame();

  @override
  EndGameCopyWith<$R2, EndGame, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _EndGameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RequestRebuyMapper extends SubClassMapperBase<RequestRebuy> {
  RequestRebuyMapper._();

  static RequestRebuyMapper? _instance;
  static RequestRebuyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RequestRebuyMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RequestRebuy';

  static int _$amount(RequestRebuy v) => v.amount;
  static const Field<RequestRebuy, int> _f$amount = Field('amount', _$amount);

  @override
  final MappableFields<RequestRebuy> fields = const {#amount: _f$amount};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'REQUEST_REBUY';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static RequestRebuy _instantiate(DecodingData data) {
    return RequestRebuy(amount: data.dec(_f$amount));
  }

  @override
  final Function instantiate = _instantiate;

  static RequestRebuy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RequestRebuy>(map);
  }

  static RequestRebuy fromJson(String json) {
    return ensureInitialized().decodeJson<RequestRebuy>(json);
  }
}

mixin RequestRebuyMappable {
  String toJson() {
    return RequestRebuyMapper.ensureInitialized().encodeJson<RequestRebuy>(
      this as RequestRebuy,
    );
  }

  Map<String, dynamic> toMap() {
    return RequestRebuyMapper.ensureInitialized().encodeMap<RequestRebuy>(
      this as RequestRebuy,
    );
  }

  RequestRebuyCopyWith<RequestRebuy, RequestRebuy, RequestRebuy> get copyWith =>
      _RequestRebuyCopyWithImpl<RequestRebuy, RequestRebuy>(
        this as RequestRebuy,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RequestRebuyMapper.ensureInitialized().stringifyValue(
      this as RequestRebuy,
    );
  }

  @override
  bool operator ==(Object other) {
    return RequestRebuyMapper.ensureInitialized().equalsValue(
      this as RequestRebuy,
      other,
    );
  }

  @override
  int get hashCode {
    return RequestRebuyMapper.ensureInitialized().hashValue(
      this as RequestRebuy,
    );
  }
}

extension RequestRebuyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RequestRebuy, $Out> {
  RequestRebuyCopyWith<$R, RequestRebuy, $Out> get $asRequestRebuy =>
      $base.as((v, t, t2) => _RequestRebuyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RequestRebuyCopyWith<$R, $In extends RequestRebuy, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? amount});
  RequestRebuyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RequestRebuyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RequestRebuy, $Out>
    implements RequestRebuyCopyWith<$R, RequestRebuy, $Out> {
  _RequestRebuyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RequestRebuy> $mapper =
      RequestRebuyMapper.ensureInitialized();
  @override
  $R call({int? amount}) =>
      $apply(FieldCopyWithData({if (amount != null) #amount: amount}));
  @override
  RequestRebuy $make(CopyWithData data) =>
      RequestRebuy(amount: data.get(#amount, or: $value.amount));

  @override
  RequestRebuyCopyWith<$R2, RequestRebuy, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RequestRebuyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SetSittingOutMapper extends SubClassMapperBase<SetSittingOut> {
  SetSittingOutMapper._();

  static SetSittingOutMapper? _instance;
  static SetSittingOutMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SetSittingOutMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'SetSittingOut';

  static bool _$sittingOut(SetSittingOut v) => v.sittingOut;
  static const Field<SetSittingOut, bool> _f$sittingOut = Field(
    'sittingOut',
    _$sittingOut,
  );

  @override
  final MappableFields<SetSittingOut> fields = const {
    #sittingOut: _f$sittingOut,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'SET_SITTING_OUT';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static SetSittingOut _instantiate(DecodingData data) {
    return SetSittingOut(sittingOut: data.dec(_f$sittingOut));
  }

  @override
  final Function instantiate = _instantiate;

  static SetSittingOut fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SetSittingOut>(map);
  }

  static SetSittingOut fromJson(String json) {
    return ensureInitialized().decodeJson<SetSittingOut>(json);
  }
}

mixin SetSittingOutMappable {
  String toJson() {
    return SetSittingOutMapper.ensureInitialized().encodeJson<SetSittingOut>(
      this as SetSittingOut,
    );
  }

  Map<String, dynamic> toMap() {
    return SetSittingOutMapper.ensureInitialized().encodeMap<SetSittingOut>(
      this as SetSittingOut,
    );
  }

  SetSittingOutCopyWith<SetSittingOut, SetSittingOut, SetSittingOut>
  get copyWith => _SetSittingOutCopyWithImpl<SetSittingOut, SetSittingOut>(
    this as SetSittingOut,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SetSittingOutMapper.ensureInitialized().stringifyValue(
      this as SetSittingOut,
    );
  }

  @override
  bool operator ==(Object other) {
    return SetSittingOutMapper.ensureInitialized().equalsValue(
      this as SetSittingOut,
      other,
    );
  }

  @override
  int get hashCode {
    return SetSittingOutMapper.ensureInitialized().hashValue(
      this as SetSittingOut,
    );
  }
}

extension SetSittingOutValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SetSittingOut, $Out> {
  SetSittingOutCopyWith<$R, SetSittingOut, $Out> get $asSetSittingOut =>
      $base.as((v, t, t2) => _SetSittingOutCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SetSittingOutCopyWith<$R, $In extends SetSittingOut, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({bool? sittingOut});
  SetSittingOutCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SetSittingOutCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SetSittingOut, $Out>
    implements SetSittingOutCopyWith<$R, SetSittingOut, $Out> {
  _SetSittingOutCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SetSittingOut> $mapper =
      SetSittingOutMapper.ensureInitialized();
  @override
  $R call({bool? sittingOut}) => $apply(
    FieldCopyWithData({if (sittingOut != null) #sittingOut: sittingOut}),
  );
  @override
  SetSittingOut $make(CopyWithData data) =>
      SetSittingOut(sittingOut: data.get(#sittingOut, or: $value.sittingOut));

  @override
  SetSittingOutCopyWith<$R2, SetSittingOut, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SetSittingOutCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LeaveTableMapper extends SubClassMapperBase<LeaveTable> {
  LeaveTableMapper._();

  static LeaveTableMapper? _instance;
  static LeaveTableMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaveTableMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'LeaveTable';

  @override
  final MappableFields<LeaveTable> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'LEAVE_TABLE';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static LeaveTable _instantiate(DecodingData data) {
    return LeaveTable();
  }

  @override
  final Function instantiate = _instantiate;

  static LeaveTable fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LeaveTable>(map);
  }

  static LeaveTable fromJson(String json) {
    return ensureInitialized().decodeJson<LeaveTable>(json);
  }
}

mixin LeaveTableMappable {
  String toJson() {
    return LeaveTableMapper.ensureInitialized().encodeJson<LeaveTable>(
      this as LeaveTable,
    );
  }

  Map<String, dynamic> toMap() {
    return LeaveTableMapper.ensureInitialized().encodeMap<LeaveTable>(
      this as LeaveTable,
    );
  }

  LeaveTableCopyWith<LeaveTable, LeaveTable, LeaveTable> get copyWith =>
      _LeaveTableCopyWithImpl<LeaveTable, LeaveTable>(
        this as LeaveTable,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LeaveTableMapper.ensureInitialized().stringifyValue(
      this as LeaveTable,
    );
  }

  @override
  bool operator ==(Object other) {
    return LeaveTableMapper.ensureInitialized().equalsValue(
      this as LeaveTable,
      other,
    );
  }

  @override
  int get hashCode {
    return LeaveTableMapper.ensureInitialized().hashValue(this as LeaveTable);
  }
}

extension LeaveTableValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LeaveTable, $Out> {
  LeaveTableCopyWith<$R, LeaveTable, $Out> get $asLeaveTable =>
      $base.as((v, t, t2) => _LeaveTableCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LeaveTableCopyWith<$R, $In extends LeaveTable, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  LeaveTableCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LeaveTableCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LeaveTable, $Out>
    implements LeaveTableCopyWith<$R, LeaveTable, $Out> {
  _LeaveTableCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LeaveTable> $mapper =
      LeaveTableMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  LeaveTable $make(CopyWithData data) => LeaveTable();

  @override
  LeaveTableCopyWith<$R2, LeaveTable, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LeaveTableCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PresenceVoteMapper extends SubClassMapperBase<PresenceVote> {
  PresenceVoteMapper._();

  static PresenceVoteMapper? _instance;
  static PresenceVoteMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PresenceVoteMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PresenceVote';

  static String _$playerId(PresenceVote v) => v.playerId;
  static const Field<PresenceVote, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static bool _$stillPlaying(PresenceVote v) => v.stillPlaying;
  static const Field<PresenceVote, bool> _f$stillPlaying = Field(
    'stillPlaying',
    _$stillPlaying,
  );

  @override
  final MappableFields<PresenceVote> fields = const {
    #playerId: _f$playerId,
    #stillPlaying: _f$stillPlaying,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PRESENCE_VOTE';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static PresenceVote _instantiate(DecodingData data) {
    return PresenceVote(
      playerId: data.dec(_f$playerId),
      stillPlaying: data.dec(_f$stillPlaying),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PresenceVote fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PresenceVote>(map);
  }

  static PresenceVote fromJson(String json) {
    return ensureInitialized().decodeJson<PresenceVote>(json);
  }
}

mixin PresenceVoteMappable {
  String toJson() {
    return PresenceVoteMapper.ensureInitialized().encodeJson<PresenceVote>(
      this as PresenceVote,
    );
  }

  Map<String, dynamic> toMap() {
    return PresenceVoteMapper.ensureInitialized().encodeMap<PresenceVote>(
      this as PresenceVote,
    );
  }

  PresenceVoteCopyWith<PresenceVote, PresenceVote, PresenceVote> get copyWith =>
      _PresenceVoteCopyWithImpl<PresenceVote, PresenceVote>(
        this as PresenceVote,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PresenceVoteMapper.ensureInitialized().stringifyValue(
      this as PresenceVote,
    );
  }

  @override
  bool operator ==(Object other) {
    return PresenceVoteMapper.ensureInitialized().equalsValue(
      this as PresenceVote,
      other,
    );
  }

  @override
  int get hashCode {
    return PresenceVoteMapper.ensureInitialized().hashValue(
      this as PresenceVote,
    );
  }
}

extension PresenceVoteValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PresenceVote, $Out> {
  PresenceVoteCopyWith<$R, PresenceVote, $Out> get $asPresenceVote =>
      $base.as((v, t, t2) => _PresenceVoteCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PresenceVoteCopyWith<$R, $In extends PresenceVote, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId, bool? stillPlaying});
  PresenceVoteCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PresenceVoteCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PresenceVote, $Out>
    implements PresenceVoteCopyWith<$R, PresenceVote, $Out> {
  _PresenceVoteCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PresenceVote> $mapper =
      PresenceVoteMapper.ensureInitialized();
  @override
  $R call({String? playerId, bool? stillPlaying}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (stillPlaying != null) #stillPlaying: stillPlaying,
    }),
  );
  @override
  PresenceVote $make(CopyWithData data) => PresenceVote(
    playerId: data.get(#playerId, or: $value.playerId),
    stillPlaying: data.get(#stillPlaying, or: $value.stillPlaying),
  );

  @override
  PresenceVoteCopyWith<$R2, PresenceVote, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PresenceVoteCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PresenceAckMapper extends SubClassMapperBase<PresenceAck> {
  PresenceAckMapper._();

  static PresenceAckMapper? _instance;
  static PresenceAckMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PresenceAckMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PresenceAck';

  @override
  final MappableFields<PresenceAck> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PRESENCE_ACK';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static PresenceAck _instantiate(DecodingData data) {
    return PresenceAck();
  }

  @override
  final Function instantiate = _instantiate;

  static PresenceAck fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PresenceAck>(map);
  }

  static PresenceAck fromJson(String json) {
    return ensureInitialized().decodeJson<PresenceAck>(json);
  }
}

mixin PresenceAckMappable {
  String toJson() {
    return PresenceAckMapper.ensureInitialized().encodeJson<PresenceAck>(
      this as PresenceAck,
    );
  }

  Map<String, dynamic> toMap() {
    return PresenceAckMapper.ensureInitialized().encodeMap<PresenceAck>(
      this as PresenceAck,
    );
  }

  PresenceAckCopyWith<PresenceAck, PresenceAck, PresenceAck> get copyWith =>
      _PresenceAckCopyWithImpl<PresenceAck, PresenceAck>(
        this as PresenceAck,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PresenceAckMapper.ensureInitialized().stringifyValue(
      this as PresenceAck,
    );
  }

  @override
  bool operator ==(Object other) {
    return PresenceAckMapper.ensureInitialized().equalsValue(
      this as PresenceAck,
      other,
    );
  }

  @override
  int get hashCode {
    return PresenceAckMapper.ensureInitialized().hashValue(this as PresenceAck);
  }
}

extension PresenceAckValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PresenceAck, $Out> {
  PresenceAckCopyWith<$R, PresenceAck, $Out> get $asPresenceAck =>
      $base.as((v, t, t2) => _PresenceAckCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PresenceAckCopyWith<$R, $In extends PresenceAck, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  PresenceAckCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PresenceAckCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PresenceAck, $Out>
    implements PresenceAckCopyWith<$R, PresenceAck, $Out> {
  _PresenceAckCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PresenceAck> $mapper =
      PresenceAckMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  PresenceAck $make(CopyWithData data) => PresenceAck();

  @override
  PresenceAckCopyWith<$R2, PresenceAck, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PresenceAckCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PingMapper extends SubClassMapperBase<Ping> {
  PingMapper._();

  static PingMapper? _instance;
  static PingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PingMapper._());
      ClientMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Ping';

  static int _$t(Ping v) => v.t;
  static const Field<Ping, int> _f$t = Field('t', _$t);

  @override
  final MappableFields<Ping> fields = const {#t: _f$t};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PING';
  @override
  late final ClassMapperBase superMapper =
      ClientMessageMapper.ensureInitialized();

  static Ping _instantiate(DecodingData data) {
    return Ping(t: data.dec(_f$t));
  }

  @override
  final Function instantiate = _instantiate;

  static Ping fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Ping>(map);
  }

  static Ping fromJson(String json) {
    return ensureInitialized().decodeJson<Ping>(json);
  }
}

mixin PingMappable {
  String toJson() {
    return PingMapper.ensureInitialized().encodeJson<Ping>(this as Ping);
  }

  Map<String, dynamic> toMap() {
    return PingMapper.ensureInitialized().encodeMap<Ping>(this as Ping);
  }

  PingCopyWith<Ping, Ping, Ping> get copyWith =>
      _PingCopyWithImpl<Ping, Ping>(this as Ping, $identity, $identity);
  @override
  String toString() {
    return PingMapper.ensureInitialized().stringifyValue(this as Ping);
  }

  @override
  bool operator ==(Object other) {
    return PingMapper.ensureInitialized().equalsValue(this as Ping, other);
  }

  @override
  int get hashCode {
    return PingMapper.ensureInitialized().hashValue(this as Ping);
  }
}

extension PingValueCopy<$R, $Out> on ObjectCopyWith<$R, Ping, $Out> {
  PingCopyWith<$R, Ping, $Out> get $asPing =>
      $base.as((v, t, t2) => _PingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PingCopyWith<$R, $In extends Ping, $Out>
    implements ClientMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? t});
  PingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PingCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Ping, $Out>
    implements PingCopyWith<$R, Ping, $Out> {
  _PingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Ping> $mapper = PingMapper.ensureInitialized();
  @override
  $R call({int? t}) => $apply(FieldCopyWithData({if (t != null) #t: t}));
  @override
  Ping $make(CopyWithData data) => Ping(t: data.get(#t, or: $value.t));

  @override
  PingCopyWith<$R2, Ping, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

