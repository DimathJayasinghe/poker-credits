// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'server_message.dart';

class ServerMessageMapper extends ClassMapperBase<ServerMessage> {
  ServerMessageMapper._();

  static ServerMessageMapper? _instance;
  static ServerMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ServerMessageMapper._());
      UnknownServerMessageMapper.ensureInitialized();
      RoomCreatedMapper.ensureInitialized();
      JoinedMapper.ensureInitialized();
      SnapshotMapper.ensureInitialized();
      StateUpdateMapper.ensureInitialized();
      TurnPromptMapper.ensureInitialized();
      ActionPerformedMapper.ensureInitialized();
      AckMapper.ensureInitialized();
      ErrorMessageMapper.ensureInitialized();
      PlayerConnectionMapper.ensureInitialized();
      GamePausedMapper.ensureInitialized();
      GameResumedMapper.ensureInitialized();
      RoomRecoveredMapper.ensureInitialized();
      RoomCrashedMapper.ensureInitialized();
      RoomExpiredMapper.ensureInitialized();
      PongMapper.ensureInitialized();
      PlayerAwayMapper.ensureInitialized();
      PresenceCheckMapper.ensureInitialized();
      PresenceResolvedMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ServerMessage';

  @override
  final MappableFields<ServerMessage> fields = const {};
  @override
  final bool ignoreNull = true;

  static ServerMessage _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ServerMessage',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ServerMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ServerMessage>(map);
  }

  static ServerMessage fromJson(String json) {
    return ensureInitialized().decodeJson<ServerMessage>(json);
  }
}

mixin ServerMessageMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ServerMessageCopyWith<ServerMessage, ServerMessage, ServerMessage>
  get copyWith;
}

abstract class ServerMessageCopyWith<$R, $In extends ServerMessage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ServerMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class UnknownServerMessageMapper
    extends SubClassMapperBase<UnknownServerMessage> {
  UnknownServerMessageMapper._();

  static UnknownServerMessageMapper? _instance;
  static UnknownServerMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UnknownServerMessageMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'UnknownServerMessage';

  @override
  final MappableFields<UnknownServerMessage> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = MappableClass.useAsDefault;
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static UnknownServerMessage _instantiate(DecodingData data) {
    return UnknownServerMessage();
  }

  @override
  final Function instantiate = _instantiate;

  static UnknownServerMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UnknownServerMessage>(map);
  }

  static UnknownServerMessage fromJson(String json) {
    return ensureInitialized().decodeJson<UnknownServerMessage>(json);
  }
}

mixin UnknownServerMessageMappable {
  String toJson() {
    return UnknownServerMessageMapper.ensureInitialized()
        .encodeJson<UnknownServerMessage>(this as UnknownServerMessage);
  }

  Map<String, dynamic> toMap() {
    return UnknownServerMessageMapper.ensureInitialized()
        .encodeMap<UnknownServerMessage>(this as UnknownServerMessage);
  }

  UnknownServerMessageCopyWith<
    UnknownServerMessage,
    UnknownServerMessage,
    UnknownServerMessage
  >
  get copyWith =>
      _UnknownServerMessageCopyWithImpl<
        UnknownServerMessage,
        UnknownServerMessage
      >(this as UnknownServerMessage, $identity, $identity);
  @override
  String toString() {
    return UnknownServerMessageMapper.ensureInitialized().stringifyValue(
      this as UnknownServerMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return UnknownServerMessageMapper.ensureInitialized().equalsValue(
      this as UnknownServerMessage,
      other,
    );
  }

  @override
  int get hashCode {
    return UnknownServerMessageMapper.ensureInitialized().hashValue(
      this as UnknownServerMessage,
    );
  }
}

extension UnknownServerMessageValueCopy<$R, $Out>
    on ObjectCopyWith<$R, UnknownServerMessage, $Out> {
  UnknownServerMessageCopyWith<$R, UnknownServerMessage, $Out>
  get $asUnknownServerMessage => $base.as(
    (v, t, t2) => _UnknownServerMessageCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class UnknownServerMessageCopyWith<
  $R,
  $In extends UnknownServerMessage,
  $Out
>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  UnknownServerMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _UnknownServerMessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UnknownServerMessage, $Out>
    implements UnknownServerMessageCopyWith<$R, UnknownServerMessage, $Out> {
  _UnknownServerMessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UnknownServerMessage> $mapper =
      UnknownServerMessageMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  UnknownServerMessage $make(CopyWithData data) => UnknownServerMessage();

  @override
  UnknownServerMessageCopyWith<$R2, UnknownServerMessage, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _UnknownServerMessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomCreatedMapper extends SubClassMapperBase<RoomCreated> {
  RoomCreatedMapper._();

  static RoomCreatedMapper? _instance;
  static RoomCreatedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomCreatedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RoomCreated';

  static String _$roomCode(RoomCreated v) => v.roomCode;
  static const Field<RoomCreated, String> _f$roomCode = Field(
    'roomCode',
    _$roomCode,
  );
  static String _$hostToken(RoomCreated v) => v.hostToken;
  static const Field<RoomCreated, String> _f$hostToken = Field(
    'hostToken',
    _$hostToken,
  );
  static String _$sessionToken(RoomCreated v) => v.sessionToken;
  static const Field<RoomCreated, String> _f$sessionToken = Field(
    'sessionToken',
    _$sessionToken,
  );
  static String _$playerId(RoomCreated v) => v.playerId;
  static const Field<RoomCreated, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );

  @override
  final MappableFields<RoomCreated> fields = const {
    #roomCode: _f$roomCode,
    #hostToken: _f$hostToken,
    #sessionToken: _f$sessionToken,
    #playerId: _f$playerId,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ROOM_CREATED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static RoomCreated _instantiate(DecodingData data) {
    return RoomCreated(
      roomCode: data.dec(_f$roomCode),
      hostToken: data.dec(_f$hostToken),
      sessionToken: data.dec(_f$sessionToken),
      playerId: data.dec(_f$playerId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RoomCreated fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomCreated>(map);
  }

  static RoomCreated fromJson(String json) {
    return ensureInitialized().decodeJson<RoomCreated>(json);
  }
}

mixin RoomCreatedMappable {
  String toJson() {
    return RoomCreatedMapper.ensureInitialized().encodeJson<RoomCreated>(
      this as RoomCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomCreatedMapper.ensureInitialized().encodeMap<RoomCreated>(
      this as RoomCreated,
    );
  }

  RoomCreatedCopyWith<RoomCreated, RoomCreated, RoomCreated> get copyWith =>
      _RoomCreatedCopyWithImpl<RoomCreated, RoomCreated>(
        this as RoomCreated,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RoomCreatedMapper.ensureInitialized().stringifyValue(
      this as RoomCreated,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomCreatedMapper.ensureInitialized().equalsValue(
      this as RoomCreated,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomCreatedMapper.ensureInitialized().hashValue(this as RoomCreated);
  }
}

extension RoomCreatedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomCreated, $Out> {
  RoomCreatedCopyWith<$R, RoomCreated, $Out> get $asRoomCreated =>
      $base.as((v, t, t2) => _RoomCreatedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomCreatedCopyWith<$R, $In extends RoomCreated, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? roomCode,
    String? hostToken,
    String? sessionToken,
    String? playerId,
  });
  RoomCreatedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomCreatedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomCreated, $Out>
    implements RoomCreatedCopyWith<$R, RoomCreated, $Out> {
  _RoomCreatedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomCreated> $mapper =
      RoomCreatedMapper.ensureInitialized();
  @override
  $R call({
    String? roomCode,
    String? hostToken,
    String? sessionToken,
    String? playerId,
  }) => $apply(
    FieldCopyWithData({
      if (roomCode != null) #roomCode: roomCode,
      if (hostToken != null) #hostToken: hostToken,
      if (sessionToken != null) #sessionToken: sessionToken,
      if (playerId != null) #playerId: playerId,
    }),
  );
  @override
  RoomCreated $make(CopyWithData data) => RoomCreated(
    roomCode: data.get(#roomCode, or: $value.roomCode),
    hostToken: data.get(#hostToken, or: $value.hostToken),
    sessionToken: data.get(#sessionToken, or: $value.sessionToken),
    playerId: data.get(#playerId, or: $value.playerId),
  );

  @override
  RoomCreatedCopyWith<$R2, RoomCreated, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomCreatedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class JoinedMapper extends SubClassMapperBase<Joined> {
  JoinedMapper._();

  static JoinedMapper? _instance;
  static JoinedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      RoleMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Joined';

  static String _$playerId(Joined v) => v.playerId;
  static const Field<Joined, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static Role _$role(Joined v) => v.role;
  static const Field<Joined, Role> _f$role = Field('role', _$role);
  static int? _$seatIndex(Joined v) => v.seatIndex;
  static const Field<Joined, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
    opt: true,
  );
  static String _$sessionToken(Joined v) => v.sessionToken;
  static const Field<Joined, String> _f$sessionToken = Field(
    'sessionToken',
    _$sessionToken,
  );

  @override
  final MappableFields<Joined> fields = const {
    #playerId: _f$playerId,
    #role: _f$role,
    #seatIndex: _f$seatIndex,
    #sessionToken: _f$sessionToken,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'JOINED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static Joined _instantiate(DecodingData data) {
    return Joined(
      playerId: data.dec(_f$playerId),
      role: data.dec(_f$role),
      seatIndex: data.dec(_f$seatIndex),
      sessionToken: data.dec(_f$sessionToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Joined fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Joined>(map);
  }

  static Joined fromJson(String json) {
    return ensureInitialized().decodeJson<Joined>(json);
  }
}

mixin JoinedMappable {
  String toJson() {
    return JoinedMapper.ensureInitialized().encodeJson<Joined>(this as Joined);
  }

  Map<String, dynamic> toMap() {
    return JoinedMapper.ensureInitialized().encodeMap<Joined>(this as Joined);
  }

  JoinedCopyWith<Joined, Joined, Joined> get copyWith =>
      _JoinedCopyWithImpl<Joined, Joined>(this as Joined, $identity, $identity);
  @override
  String toString() {
    return JoinedMapper.ensureInitialized().stringifyValue(this as Joined);
  }

  @override
  bool operator ==(Object other) {
    return JoinedMapper.ensureInitialized().equalsValue(this as Joined, other);
  }

  @override
  int get hashCode {
    return JoinedMapper.ensureInitialized().hashValue(this as Joined);
  }
}

extension JoinedValueCopy<$R, $Out> on ObjectCopyWith<$R, Joined, $Out> {
  JoinedCopyWith<$R, Joined, $Out> get $asJoined =>
      $base.as((v, t, t2) => _JoinedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JoinedCopyWith<$R, $In extends Joined, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId, Role? role, int? seatIndex, String? sessionToken});
  JoinedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _JoinedCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Joined, $Out>
    implements JoinedCopyWith<$R, Joined, $Out> {
  _JoinedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Joined> $mapper = JoinedMapper.ensureInitialized();
  @override
  $R call({
    String? playerId,
    Role? role,
    Object? seatIndex = $none,
    String? sessionToken,
  }) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (role != null) #role: role,
      if (seatIndex != $none) #seatIndex: seatIndex,
      if (sessionToken != null) #sessionToken: sessionToken,
    }),
  );
  @override
  Joined $make(CopyWithData data) => Joined(
    playerId: data.get(#playerId, or: $value.playerId),
    role: data.get(#role, or: $value.role),
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
    sessionToken: data.get(#sessionToken, or: $value.sessionToken),
  );

  @override
  JoinedCopyWith<$R2, Joined, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _JoinedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SnapshotMapper extends SubClassMapperBase<Snapshot> {
  SnapshotMapper._();

  static SnapshotMapper? _instance;
  static SnapshotMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SnapshotMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      RoomViewMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Snapshot';

  static int _$stateVersion(Snapshot v) => v.stateVersion;
  static const Field<Snapshot, int> _f$stateVersion = Field(
    'stateVersion',
    _$stateVersion,
  );
  static int _$serverTime(Snapshot v) => v.serverTime;
  static const Field<Snapshot, int> _f$serverTime = Field(
    'serverTime',
    _$serverTime,
  );
  static int _$nextActionSeq(Snapshot v) => v.nextActionSeq;
  static const Field<Snapshot, int> _f$nextActionSeq = Field(
    'nextActionSeq',
    _$nextActionSeq,
  );
  static RoomView _$view(Snapshot v) => v.view;
  static const Field<Snapshot, RoomView> _f$view = Field('view', _$view);

  @override
  final MappableFields<Snapshot> fields = const {
    #stateVersion: _f$stateVersion,
    #serverTime: _f$serverTime,
    #nextActionSeq: _f$nextActionSeq,
    #view: _f$view,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'SNAPSHOT';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static Snapshot _instantiate(DecodingData data) {
    return Snapshot(
      stateVersion: data.dec(_f$stateVersion),
      serverTime: data.dec(_f$serverTime),
      nextActionSeq: data.dec(_f$nextActionSeq),
      view: data.dec(_f$view),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Snapshot fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Snapshot>(map);
  }

  static Snapshot fromJson(String json) {
    return ensureInitialized().decodeJson<Snapshot>(json);
  }
}

mixin SnapshotMappable {
  String toJson() {
    return SnapshotMapper.ensureInitialized().encodeJson<Snapshot>(
      this as Snapshot,
    );
  }

  Map<String, dynamic> toMap() {
    return SnapshotMapper.ensureInitialized().encodeMap<Snapshot>(
      this as Snapshot,
    );
  }

  SnapshotCopyWith<Snapshot, Snapshot, Snapshot> get copyWith =>
      _SnapshotCopyWithImpl<Snapshot, Snapshot>(
        this as Snapshot,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SnapshotMapper.ensureInitialized().stringifyValue(this as Snapshot);
  }

  @override
  bool operator ==(Object other) {
    return SnapshotMapper.ensureInitialized().equalsValue(
      this as Snapshot,
      other,
    );
  }

  @override
  int get hashCode {
    return SnapshotMapper.ensureInitialized().hashValue(this as Snapshot);
  }
}

extension SnapshotValueCopy<$R, $Out> on ObjectCopyWith<$R, Snapshot, $Out> {
  SnapshotCopyWith<$R, Snapshot, $Out> get $asSnapshot =>
      $base.as((v, t, t2) => _SnapshotCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SnapshotCopyWith<$R, $In extends Snapshot, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  RoomViewCopyWith<$R, RoomView, RoomView> get view;
  @override
  $R call({
    int? stateVersion,
    int? serverTime,
    int? nextActionSeq,
    RoomView? view,
  });
  SnapshotCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SnapshotCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Snapshot, $Out>
    implements SnapshotCopyWith<$R, Snapshot, $Out> {
  _SnapshotCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Snapshot> $mapper =
      SnapshotMapper.ensureInitialized();
  @override
  RoomViewCopyWith<$R, RoomView, RoomView> get view =>
      $value.view.copyWith.$chain((v) => call(view: v));
  @override
  $R call({
    int? stateVersion,
    int? serverTime,
    int? nextActionSeq,
    RoomView? view,
  }) => $apply(
    FieldCopyWithData({
      if (stateVersion != null) #stateVersion: stateVersion,
      if (serverTime != null) #serverTime: serverTime,
      if (nextActionSeq != null) #nextActionSeq: nextActionSeq,
      if (view != null) #view: view,
    }),
  );
  @override
  Snapshot $make(CopyWithData data) => Snapshot(
    stateVersion: data.get(#stateVersion, or: $value.stateVersion),
    serverTime: data.get(#serverTime, or: $value.serverTime),
    nextActionSeq: data.get(#nextActionSeq, or: $value.nextActionSeq),
    view: data.get(#view, or: $value.view),
  );

  @override
  SnapshotCopyWith<$R2, Snapshot, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SnapshotCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class StateUpdateMapper extends SubClassMapperBase<StateUpdate> {
  StateUpdateMapper._();

  static StateUpdateMapper? _instance;
  static StateUpdateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = StateUpdateMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      RoomViewMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'StateUpdate';

  static int _$stateVersion(StateUpdate v) => v.stateVersion;
  static const Field<StateUpdate, int> _f$stateVersion = Field(
    'stateVersion',
    _$stateVersion,
  );
  static RoomView _$view(StateUpdate v) => v.view;
  static const Field<StateUpdate, RoomView> _f$view = Field('view', _$view);

  @override
  final MappableFields<StateUpdate> fields = const {
    #stateVersion: _f$stateVersion,
    #view: _f$view,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'STATE_UPDATE';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static StateUpdate _instantiate(DecodingData data) {
    return StateUpdate(
      stateVersion: data.dec(_f$stateVersion),
      view: data.dec(_f$view),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static StateUpdate fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<StateUpdate>(map);
  }

  static StateUpdate fromJson(String json) {
    return ensureInitialized().decodeJson<StateUpdate>(json);
  }
}

mixin StateUpdateMappable {
  String toJson() {
    return StateUpdateMapper.ensureInitialized().encodeJson<StateUpdate>(
      this as StateUpdate,
    );
  }

  Map<String, dynamic> toMap() {
    return StateUpdateMapper.ensureInitialized().encodeMap<StateUpdate>(
      this as StateUpdate,
    );
  }

  StateUpdateCopyWith<StateUpdate, StateUpdate, StateUpdate> get copyWith =>
      _StateUpdateCopyWithImpl<StateUpdate, StateUpdate>(
        this as StateUpdate,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return StateUpdateMapper.ensureInitialized().stringifyValue(
      this as StateUpdate,
    );
  }

  @override
  bool operator ==(Object other) {
    return StateUpdateMapper.ensureInitialized().equalsValue(
      this as StateUpdate,
      other,
    );
  }

  @override
  int get hashCode {
    return StateUpdateMapper.ensureInitialized().hashValue(this as StateUpdate);
  }
}

extension StateUpdateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, StateUpdate, $Out> {
  StateUpdateCopyWith<$R, StateUpdate, $Out> get $asStateUpdate =>
      $base.as((v, t, t2) => _StateUpdateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class StateUpdateCopyWith<$R, $In extends StateUpdate, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  RoomViewCopyWith<$R, RoomView, RoomView> get view;
  @override
  $R call({int? stateVersion, RoomView? view});
  StateUpdateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _StateUpdateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, StateUpdate, $Out>
    implements StateUpdateCopyWith<$R, StateUpdate, $Out> {
  _StateUpdateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<StateUpdate> $mapper =
      StateUpdateMapper.ensureInitialized();
  @override
  RoomViewCopyWith<$R, RoomView, RoomView> get view =>
      $value.view.copyWith.$chain((v) => call(view: v));
  @override
  $R call({int? stateVersion, RoomView? view}) => $apply(
    FieldCopyWithData({
      if (stateVersion != null) #stateVersion: stateVersion,
      if (view != null) #view: view,
    }),
  );
  @override
  StateUpdate $make(CopyWithData data) => StateUpdate(
    stateVersion: data.get(#stateVersion, or: $value.stateVersion),
    view: data.get(#view, or: $value.view),
  );

  @override
  StateUpdateCopyWith<$R2, StateUpdate, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _StateUpdateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TurnPromptMapper extends SubClassMapperBase<TurnPrompt> {
  TurnPromptMapper._();

  static TurnPromptMapper? _instance;
  static TurnPromptMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TurnPromptMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      LegalActionsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TurnPrompt';

  static String _$playerId(TurnPrompt v) => v.playerId;
  static const Field<TurnPrompt, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static int _$seatIndex(TurnPrompt v) => v.seatIndex;
  static const Field<TurnPrompt, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );
  static int? _$turnDeadlineMs(TurnPrompt v) => v.turnDeadlineMs;
  static const Field<TurnPrompt, int> _f$turnDeadlineMs = Field(
    'turnDeadlineMs',
    _$turnDeadlineMs,
    opt: true,
  );
  static int _$nextActionSeq(TurnPrompt v) => v.nextActionSeq;
  static const Field<TurnPrompt, int> _f$nextActionSeq = Field(
    'nextActionSeq',
    _$nextActionSeq,
  );
  static LegalActions _$legal(TurnPrompt v) => v.legal;
  static const Field<TurnPrompt, LegalActions> _f$legal = Field(
    'legal',
    _$legal,
  );

  @override
  final MappableFields<TurnPrompt> fields = const {
    #playerId: _f$playerId,
    #seatIndex: _f$seatIndex,
    #turnDeadlineMs: _f$turnDeadlineMs,
    #nextActionSeq: _f$nextActionSeq,
    #legal: _f$legal,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'TURN_PROMPT';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static TurnPrompt _instantiate(DecodingData data) {
    return TurnPrompt(
      playerId: data.dec(_f$playerId),
      seatIndex: data.dec(_f$seatIndex),
      turnDeadlineMs: data.dec(_f$turnDeadlineMs),
      nextActionSeq: data.dec(_f$nextActionSeq),
      legal: data.dec(_f$legal),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TurnPrompt fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TurnPrompt>(map);
  }

  static TurnPrompt fromJson(String json) {
    return ensureInitialized().decodeJson<TurnPrompt>(json);
  }
}

mixin TurnPromptMappable {
  String toJson() {
    return TurnPromptMapper.ensureInitialized().encodeJson<TurnPrompt>(
      this as TurnPrompt,
    );
  }

  Map<String, dynamic> toMap() {
    return TurnPromptMapper.ensureInitialized().encodeMap<TurnPrompt>(
      this as TurnPrompt,
    );
  }

  TurnPromptCopyWith<TurnPrompt, TurnPrompt, TurnPrompt> get copyWith =>
      _TurnPromptCopyWithImpl<TurnPrompt, TurnPrompt>(
        this as TurnPrompt,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TurnPromptMapper.ensureInitialized().stringifyValue(
      this as TurnPrompt,
    );
  }

  @override
  bool operator ==(Object other) {
    return TurnPromptMapper.ensureInitialized().equalsValue(
      this as TurnPrompt,
      other,
    );
  }

  @override
  int get hashCode {
    return TurnPromptMapper.ensureInitialized().hashValue(this as TurnPrompt);
  }
}

extension TurnPromptValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TurnPrompt, $Out> {
  TurnPromptCopyWith<$R, TurnPrompt, $Out> get $asTurnPrompt =>
      $base.as((v, t, t2) => _TurnPromptCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TurnPromptCopyWith<$R, $In extends TurnPrompt, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  LegalActionsCopyWith<$R, LegalActions, LegalActions> get legal;
  @override
  $R call({
    String? playerId,
    int? seatIndex,
    int? turnDeadlineMs,
    int? nextActionSeq,
    LegalActions? legal,
  });
  TurnPromptCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TurnPromptCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TurnPrompt, $Out>
    implements TurnPromptCopyWith<$R, TurnPrompt, $Out> {
  _TurnPromptCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TurnPrompt> $mapper =
      TurnPromptMapper.ensureInitialized();
  @override
  LegalActionsCopyWith<$R, LegalActions, LegalActions> get legal =>
      $value.legal.copyWith.$chain((v) => call(legal: v));
  @override
  $R call({
    String? playerId,
    int? seatIndex,
    Object? turnDeadlineMs = $none,
    int? nextActionSeq,
    LegalActions? legal,
  }) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (seatIndex != null) #seatIndex: seatIndex,
      if (turnDeadlineMs != $none) #turnDeadlineMs: turnDeadlineMs,
      if (nextActionSeq != null) #nextActionSeq: nextActionSeq,
      if (legal != null) #legal: legal,
    }),
  );
  @override
  TurnPrompt $make(CopyWithData data) => TurnPrompt(
    playerId: data.get(#playerId, or: $value.playerId),
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
    turnDeadlineMs: data.get(#turnDeadlineMs, or: $value.turnDeadlineMs),
    nextActionSeq: data.get(#nextActionSeq, or: $value.nextActionSeq),
    legal: data.get(#legal, or: $value.legal),
  );

  @override
  TurnPromptCopyWith<$R2, TurnPrompt, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TurnPromptCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ActionPerformedMapper extends SubClassMapperBase<ActionPerformed> {
  ActionPerformedMapper._();

  static ActionPerformedMapper? _instance;
  static ActionPerformedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ActionPerformedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      ActionKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ActionPerformed';

  static String _$playerId(ActionPerformed v) => v.playerId;
  static const Field<ActionPerformed, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static String _$playerName(ActionPerformed v) => v.playerName;
  static const Field<ActionPerformed, String> _f$playerName = Field(
    'playerName',
    _$playerName,
  );
  static ActionKind _$kind(ActionPerformed v) => v.kind;
  static const Field<ActionPerformed, ActionKind> _f$kind = Field(
    'kind',
    _$kind,
  );
  static int _$amount(ActionPerformed v) => v.amount;
  static const Field<ActionPerformed, int> _f$amount = Field(
    'amount',
    _$amount,
  );
  static int _$chipsRemaining(ActionPerformed v) => v.chipsRemaining;
  static const Field<ActionPerformed, int> _f$chipsRemaining = Field(
    'chipsRemaining',
    _$chipsRemaining,
  );
  static bool _$allIn(ActionPerformed v) => v.allIn;
  static const Field<ActionPerformed, bool> _f$allIn = Field('allIn', _$allIn);
  static bool _$auto(ActionPerformed v) => v.auto;
  static const Field<ActionPerformed, bool> _f$auto = Field('auto', _$auto);

  @override
  final MappableFields<ActionPerformed> fields = const {
    #playerId: _f$playerId,
    #playerName: _f$playerName,
    #kind: _f$kind,
    #amount: _f$amount,
    #chipsRemaining: _f$chipsRemaining,
    #allIn: _f$allIn,
    #auto: _f$auto,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ACTION_PERFORMED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static ActionPerformed _instantiate(DecodingData data) {
    return ActionPerformed(
      playerId: data.dec(_f$playerId),
      playerName: data.dec(_f$playerName),
      kind: data.dec(_f$kind),
      amount: data.dec(_f$amount),
      chipsRemaining: data.dec(_f$chipsRemaining),
      allIn: data.dec(_f$allIn),
      auto: data.dec(_f$auto),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ActionPerformed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ActionPerformed>(map);
  }

  static ActionPerformed fromJson(String json) {
    return ensureInitialized().decodeJson<ActionPerformed>(json);
  }
}

mixin ActionPerformedMappable {
  String toJson() {
    return ActionPerformedMapper.ensureInitialized()
        .encodeJson<ActionPerformed>(this as ActionPerformed);
  }

  Map<String, dynamic> toMap() {
    return ActionPerformedMapper.ensureInitialized().encodeMap<ActionPerformed>(
      this as ActionPerformed,
    );
  }

  ActionPerformedCopyWith<ActionPerformed, ActionPerformed, ActionPerformed>
  get copyWith =>
      _ActionPerformedCopyWithImpl<ActionPerformed, ActionPerformed>(
        this as ActionPerformed,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ActionPerformedMapper.ensureInitialized().stringifyValue(
      this as ActionPerformed,
    );
  }

  @override
  bool operator ==(Object other) {
    return ActionPerformedMapper.ensureInitialized().equalsValue(
      this as ActionPerformed,
      other,
    );
  }

  @override
  int get hashCode {
    return ActionPerformedMapper.ensureInitialized().hashValue(
      this as ActionPerformed,
    );
  }
}

extension ActionPerformedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ActionPerformed, $Out> {
  ActionPerformedCopyWith<$R, ActionPerformed, $Out> get $asActionPerformed =>
      $base.as((v, t, t2) => _ActionPerformedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ActionPerformedCopyWith<$R, $In extends ActionPerformed, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? playerId,
    String? playerName,
    ActionKind? kind,
    int? amount,
    int? chipsRemaining,
    bool? allIn,
    bool? auto,
  });
  ActionPerformedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ActionPerformedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ActionPerformed, $Out>
    implements ActionPerformedCopyWith<$R, ActionPerformed, $Out> {
  _ActionPerformedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ActionPerformed> $mapper =
      ActionPerformedMapper.ensureInitialized();
  @override
  $R call({
    String? playerId,
    String? playerName,
    ActionKind? kind,
    int? amount,
    int? chipsRemaining,
    bool? allIn,
    bool? auto,
  }) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (playerName != null) #playerName: playerName,
      if (kind != null) #kind: kind,
      if (amount != null) #amount: amount,
      if (chipsRemaining != null) #chipsRemaining: chipsRemaining,
      if (allIn != null) #allIn: allIn,
      if (auto != null) #auto: auto,
    }),
  );
  @override
  ActionPerformed $make(CopyWithData data) => ActionPerformed(
    playerId: data.get(#playerId, or: $value.playerId),
    playerName: data.get(#playerName, or: $value.playerName),
    kind: data.get(#kind, or: $value.kind),
    amount: data.get(#amount, or: $value.amount),
    chipsRemaining: data.get(#chipsRemaining, or: $value.chipsRemaining),
    allIn: data.get(#allIn, or: $value.allIn),
    auto: data.get(#auto, or: $value.auto),
  );

  @override
  ActionPerformedCopyWith<$R2, ActionPerformed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ActionPerformedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AckMapper extends SubClassMapperBase<Ack> {
  AckMapper._();

  static AckMapper? _instance;
  static AckMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AckMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Ack';

  static int _$nextActionSeq(Ack v) => v.nextActionSeq;
  static const Field<Ack, int> _f$nextActionSeq = Field(
    'nextActionSeq',
    _$nextActionSeq,
  );
  static bool _$duplicate(Ack v) => v.duplicate;
  static const Field<Ack, bool> _f$duplicate = Field('duplicate', _$duplicate);

  @override
  final MappableFields<Ack> fields = const {
    #nextActionSeq: _f$nextActionSeq,
    #duplicate: _f$duplicate,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ACK';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static Ack _instantiate(DecodingData data) {
    return Ack(
      nextActionSeq: data.dec(_f$nextActionSeq),
      duplicate: data.dec(_f$duplicate),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Ack fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Ack>(map);
  }

  static Ack fromJson(String json) {
    return ensureInitialized().decodeJson<Ack>(json);
  }
}

mixin AckMappable {
  String toJson() {
    return AckMapper.ensureInitialized().encodeJson<Ack>(this as Ack);
  }

  Map<String, dynamic> toMap() {
    return AckMapper.ensureInitialized().encodeMap<Ack>(this as Ack);
  }

  AckCopyWith<Ack, Ack, Ack> get copyWith =>
      _AckCopyWithImpl<Ack, Ack>(this as Ack, $identity, $identity);
  @override
  String toString() {
    return AckMapper.ensureInitialized().stringifyValue(this as Ack);
  }

  @override
  bool operator ==(Object other) {
    return AckMapper.ensureInitialized().equalsValue(this as Ack, other);
  }

  @override
  int get hashCode {
    return AckMapper.ensureInitialized().hashValue(this as Ack);
  }
}

extension AckValueCopy<$R, $Out> on ObjectCopyWith<$R, Ack, $Out> {
  AckCopyWith<$R, Ack, $Out> get $asAck =>
      $base.as((v, t, t2) => _AckCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AckCopyWith<$R, $In extends Ack, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? nextActionSeq, bool? duplicate});
  AckCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AckCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Ack, $Out>
    implements AckCopyWith<$R, Ack, $Out> {
  _AckCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Ack> $mapper = AckMapper.ensureInitialized();
  @override
  $R call({int? nextActionSeq, bool? duplicate}) => $apply(
    FieldCopyWithData({
      if (nextActionSeq != null) #nextActionSeq: nextActionSeq,
      if (duplicate != null) #duplicate: duplicate,
    }),
  );
  @override
  Ack $make(CopyWithData data) => Ack(
    nextActionSeq: data.get(#nextActionSeq, or: $value.nextActionSeq),
    duplicate: data.get(#duplicate, or: $value.duplicate),
  );

  @override
  AckCopyWith<$R2, Ack, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AckCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ErrorMessageMapper extends SubClassMapperBase<ErrorMessage> {
  ErrorMessageMapper._();

  static ErrorMessageMapper? _instance;
  static ErrorMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ErrorMessageMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
      ErrorCodeMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ErrorMessage';

  static ErrorCode _$code(ErrorMessage v) => v.code;
  static const Field<ErrorMessage, ErrorCode> _f$code = Field('code', _$code);
  static String _$message(ErrorMessage v) => v.message;
  static const Field<ErrorMessage, String> _f$message = Field(
    'message',
    _$message,
  );
  static Map<String, dynamic>? _$details(ErrorMessage v) => v.details;
  static const Field<ErrorMessage, Map<String, dynamic>> _f$details = Field(
    'details',
    _$details,
    opt: true,
  );

  @override
  final MappableFields<ErrorMessage> fields = const {
    #code: _f$code,
    #message: _f$message,
    #details: _f$details,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ERROR';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static ErrorMessage _instantiate(DecodingData data) {
    return ErrorMessage(
      code: data.dec(_f$code),
      message: data.dec(_f$message),
      details: data.dec(_f$details),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ErrorMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ErrorMessage>(map);
  }

  static ErrorMessage fromJson(String json) {
    return ensureInitialized().decodeJson<ErrorMessage>(json);
  }
}

mixin ErrorMessageMappable {
  String toJson() {
    return ErrorMessageMapper.ensureInitialized().encodeJson<ErrorMessage>(
      this as ErrorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return ErrorMessageMapper.ensureInitialized().encodeMap<ErrorMessage>(
      this as ErrorMessage,
    );
  }

  ErrorMessageCopyWith<ErrorMessage, ErrorMessage, ErrorMessage> get copyWith =>
      _ErrorMessageCopyWithImpl<ErrorMessage, ErrorMessage>(
        this as ErrorMessage,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ErrorMessageMapper.ensureInitialized().stringifyValue(
      this as ErrorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return ErrorMessageMapper.ensureInitialized().equalsValue(
      this as ErrorMessage,
      other,
    );
  }

  @override
  int get hashCode {
    return ErrorMessageMapper.ensureInitialized().hashValue(
      this as ErrorMessage,
    );
  }
}

extension ErrorMessageValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ErrorMessage, $Out> {
  ErrorMessageCopyWith<$R, ErrorMessage, $Out> get $asErrorMessage =>
      $base.as((v, t, t2) => _ErrorMessageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ErrorMessageCopyWith<$R, $In extends ErrorMessage, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>?
  get details;
  @override
  $R call({ErrorCode? code, String? message, Map<String, dynamic>? details});
  ErrorMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ErrorMessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ErrorMessage, $Out>
    implements ErrorMessageCopyWith<$R, ErrorMessage, $Out> {
  _ErrorMessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ErrorMessage> $mapper =
      ErrorMessageMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>?
  get details => $value.details != null
      ? MapCopyWith(
          $value.details!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(details: v),
        )
      : null;
  @override
  $R call({ErrorCode? code, String? message, Object? details = $none}) =>
      $apply(
        FieldCopyWithData({
          if (code != null) #code: code,
          if (message != null) #message: message,
          if (details != $none) #details: details,
        }),
      );
  @override
  ErrorMessage $make(CopyWithData data) => ErrorMessage(
    code: data.get(#code, or: $value.code),
    message: data.get(#message, or: $value.message),
    details: data.get(#details, or: $value.details),
  );

  @override
  ErrorMessageCopyWith<$R2, ErrorMessage, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ErrorMessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PlayerConnectionMapper extends SubClassMapperBase<PlayerConnection> {
  PlayerConnectionMapper._();

  static PlayerConnectionMapper? _instance;
  static PlayerConnectionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlayerConnectionMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PlayerConnection';

  static int _$seatIndex(PlayerConnection v) => v.seatIndex;
  static const Field<PlayerConnection, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );
  static String _$playerId(PlayerConnection v) => v.playerId;
  static const Field<PlayerConnection, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static bool _$isConnected(PlayerConnection v) => v.isConnected;
  static const Field<PlayerConnection, bool> _f$isConnected = Field(
    'isConnected',
    _$isConnected,
  );

  @override
  final MappableFields<PlayerConnection> fields = const {
    #seatIndex: _f$seatIndex,
    #playerId: _f$playerId,
    #isConnected: _f$isConnected,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PLAYER_CONNECTION';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static PlayerConnection _instantiate(DecodingData data) {
    return PlayerConnection(
      seatIndex: data.dec(_f$seatIndex),
      playerId: data.dec(_f$playerId),
      isConnected: data.dec(_f$isConnected),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlayerConnection fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlayerConnection>(map);
  }

  static PlayerConnection fromJson(String json) {
    return ensureInitialized().decodeJson<PlayerConnection>(json);
  }
}

mixin PlayerConnectionMappable {
  String toJson() {
    return PlayerConnectionMapper.ensureInitialized()
        .encodeJson<PlayerConnection>(this as PlayerConnection);
  }

  Map<String, dynamic> toMap() {
    return PlayerConnectionMapper.ensureInitialized()
        .encodeMap<PlayerConnection>(this as PlayerConnection);
  }

  PlayerConnectionCopyWith<PlayerConnection, PlayerConnection, PlayerConnection>
  get copyWith =>
      _PlayerConnectionCopyWithImpl<PlayerConnection, PlayerConnection>(
        this as PlayerConnection,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PlayerConnectionMapper.ensureInitialized().stringifyValue(
      this as PlayerConnection,
    );
  }

  @override
  bool operator ==(Object other) {
    return PlayerConnectionMapper.ensureInitialized().equalsValue(
      this as PlayerConnection,
      other,
    );
  }

  @override
  int get hashCode {
    return PlayerConnectionMapper.ensureInitialized().hashValue(
      this as PlayerConnection,
    );
  }
}

extension PlayerConnectionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PlayerConnection, $Out> {
  PlayerConnectionCopyWith<$R, PlayerConnection, $Out>
  get $asPlayerConnection =>
      $base.as((v, t, t2) => _PlayerConnectionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PlayerConnectionCopyWith<$R, $In extends PlayerConnection, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? seatIndex, String? playerId, bool? isConnected});
  PlayerConnectionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PlayerConnectionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PlayerConnection, $Out>
    implements PlayerConnectionCopyWith<$R, PlayerConnection, $Out> {
  _PlayerConnectionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PlayerConnection> $mapper =
      PlayerConnectionMapper.ensureInitialized();
  @override
  $R call({int? seatIndex, String? playerId, bool? isConnected}) => $apply(
    FieldCopyWithData({
      if (seatIndex != null) #seatIndex: seatIndex,
      if (playerId != null) #playerId: playerId,
      if (isConnected != null) #isConnected: isConnected,
    }),
  );
  @override
  PlayerConnection $make(CopyWithData data) => PlayerConnection(
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
    playerId: data.get(#playerId, or: $value.playerId),
    isConnected: data.get(#isConnected, or: $value.isConnected),
  );

  @override
  PlayerConnectionCopyWith<$R2, PlayerConnection, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PlayerConnectionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GamePausedMapper extends SubClassMapperBase<GamePaused> {
  GamePausedMapper._();

  static GamePausedMapper? _instance;
  static GamePausedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GamePausedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'GamePaused';

  static String _$pausedBy(GamePaused v) => v.pausedBy;
  static const Field<GamePaused, String> _f$pausedBy = Field(
    'pausedBy',
    _$pausedBy,
  );
  static String? _$reason(GamePaused v) => v.reason;
  static const Field<GamePaused, String> _f$reason = Field(
    'reason',
    _$reason,
    opt: true,
  );

  @override
  final MappableFields<GamePaused> fields = const {
    #pausedBy: _f$pausedBy,
    #reason: _f$reason,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'GAME_PAUSED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static GamePaused _instantiate(DecodingData data) {
    return GamePaused(
      pausedBy: data.dec(_f$pausedBy),
      reason: data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GamePaused fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GamePaused>(map);
  }

  static GamePaused fromJson(String json) {
    return ensureInitialized().decodeJson<GamePaused>(json);
  }
}

mixin GamePausedMappable {
  String toJson() {
    return GamePausedMapper.ensureInitialized().encodeJson<GamePaused>(
      this as GamePaused,
    );
  }

  Map<String, dynamic> toMap() {
    return GamePausedMapper.ensureInitialized().encodeMap<GamePaused>(
      this as GamePaused,
    );
  }

  GamePausedCopyWith<GamePaused, GamePaused, GamePaused> get copyWith =>
      _GamePausedCopyWithImpl<GamePaused, GamePaused>(
        this as GamePaused,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GamePausedMapper.ensureInitialized().stringifyValue(
      this as GamePaused,
    );
  }

  @override
  bool operator ==(Object other) {
    return GamePausedMapper.ensureInitialized().equalsValue(
      this as GamePaused,
      other,
    );
  }

  @override
  int get hashCode {
    return GamePausedMapper.ensureInitialized().hashValue(this as GamePaused);
  }
}

extension GamePausedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GamePaused, $Out> {
  GamePausedCopyWith<$R, GamePaused, $Out> get $asGamePaused =>
      $base.as((v, t, t2) => _GamePausedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GamePausedCopyWith<$R, $In extends GamePaused, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? pausedBy, String? reason});
  GamePausedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GamePausedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GamePaused, $Out>
    implements GamePausedCopyWith<$R, GamePaused, $Out> {
  _GamePausedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GamePaused> $mapper =
      GamePausedMapper.ensureInitialized();
  @override
  $R call({String? pausedBy, Object? reason = $none}) => $apply(
    FieldCopyWithData({
      if (pausedBy != null) #pausedBy: pausedBy,
      if (reason != $none) #reason: reason,
    }),
  );
  @override
  GamePaused $make(CopyWithData data) => GamePaused(
    pausedBy: data.get(#pausedBy, or: $value.pausedBy),
    reason: data.get(#reason, or: $value.reason),
  );

  @override
  GamePausedCopyWith<$R2, GamePaused, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GamePausedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GameResumedMapper extends SubClassMapperBase<GameResumed> {
  GameResumedMapper._();

  static GameResumedMapper? _instance;
  static GameResumedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GameResumedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'GameResumed';

  static String _$resumedBy(GameResumed v) => v.resumedBy;
  static const Field<GameResumed, String> _f$resumedBy = Field(
    'resumedBy',
    _$resumedBy,
  );
  static int? _$turnDeadlineMs(GameResumed v) => v.turnDeadlineMs;
  static const Field<GameResumed, int> _f$turnDeadlineMs = Field(
    'turnDeadlineMs',
    _$turnDeadlineMs,
    opt: true,
  );

  @override
  final MappableFields<GameResumed> fields = const {
    #resumedBy: _f$resumedBy,
    #turnDeadlineMs: _f$turnDeadlineMs,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'GAME_RESUMED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static GameResumed _instantiate(DecodingData data) {
    return GameResumed(
      resumedBy: data.dec(_f$resumedBy),
      turnDeadlineMs: data.dec(_f$turnDeadlineMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GameResumed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GameResumed>(map);
  }

  static GameResumed fromJson(String json) {
    return ensureInitialized().decodeJson<GameResumed>(json);
  }
}

mixin GameResumedMappable {
  String toJson() {
    return GameResumedMapper.ensureInitialized().encodeJson<GameResumed>(
      this as GameResumed,
    );
  }

  Map<String, dynamic> toMap() {
    return GameResumedMapper.ensureInitialized().encodeMap<GameResumed>(
      this as GameResumed,
    );
  }

  GameResumedCopyWith<GameResumed, GameResumed, GameResumed> get copyWith =>
      _GameResumedCopyWithImpl<GameResumed, GameResumed>(
        this as GameResumed,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GameResumedMapper.ensureInitialized().stringifyValue(
      this as GameResumed,
    );
  }

  @override
  bool operator ==(Object other) {
    return GameResumedMapper.ensureInitialized().equalsValue(
      this as GameResumed,
      other,
    );
  }

  @override
  int get hashCode {
    return GameResumedMapper.ensureInitialized().hashValue(this as GameResumed);
  }
}

extension GameResumedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GameResumed, $Out> {
  GameResumedCopyWith<$R, GameResumed, $Out> get $asGameResumed =>
      $base.as((v, t, t2) => _GameResumedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GameResumedCopyWith<$R, $In extends GameResumed, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? resumedBy, int? turnDeadlineMs});
  GameResumedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GameResumedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GameResumed, $Out>
    implements GameResumedCopyWith<$R, GameResumed, $Out> {
  _GameResumedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GameResumed> $mapper =
      GameResumedMapper.ensureInitialized();
  @override
  $R call({String? resumedBy, Object? turnDeadlineMs = $none}) => $apply(
    FieldCopyWithData({
      if (resumedBy != null) #resumedBy: resumedBy,
      if (turnDeadlineMs != $none) #turnDeadlineMs: turnDeadlineMs,
    }),
  );
  @override
  GameResumed $make(CopyWithData data) => GameResumed(
    resumedBy: data.get(#resumedBy, or: $value.resumedBy),
    turnDeadlineMs: data.get(#turnDeadlineMs, or: $value.turnDeadlineMs),
  );

  @override
  GameResumedCopyWith<$R2, GameResumed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GameResumedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomRecoveredMapper extends SubClassMapperBase<RoomRecovered> {
  RoomRecoveredMapper._();

  static RoomRecoveredMapper? _instance;
  static RoomRecoveredMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomRecoveredMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RoomRecovered';

  static String _$reason(RoomRecovered v) => v.reason;
  static const Field<RoomRecovered, String> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<RoomRecovered> fields = const {#reason: _f$reason};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ROOM_RECOVERED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static RoomRecovered _instantiate(DecodingData data) {
    return RoomRecovered(reason: data.dec(_f$reason));
  }

  @override
  final Function instantiate = _instantiate;

  static RoomRecovered fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomRecovered>(map);
  }

  static RoomRecovered fromJson(String json) {
    return ensureInitialized().decodeJson<RoomRecovered>(json);
  }
}

mixin RoomRecoveredMappable {
  String toJson() {
    return RoomRecoveredMapper.ensureInitialized().encodeJson<RoomRecovered>(
      this as RoomRecovered,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomRecoveredMapper.ensureInitialized().encodeMap<RoomRecovered>(
      this as RoomRecovered,
    );
  }

  RoomRecoveredCopyWith<RoomRecovered, RoomRecovered, RoomRecovered>
  get copyWith => _RoomRecoveredCopyWithImpl<RoomRecovered, RoomRecovered>(
    this as RoomRecovered,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return RoomRecoveredMapper.ensureInitialized().stringifyValue(
      this as RoomRecovered,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomRecoveredMapper.ensureInitialized().equalsValue(
      this as RoomRecovered,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomRecoveredMapper.ensureInitialized().hashValue(
      this as RoomRecovered,
    );
  }
}

extension RoomRecoveredValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomRecovered, $Out> {
  RoomRecoveredCopyWith<$R, RoomRecovered, $Out> get $asRoomRecovered =>
      $base.as((v, t, t2) => _RoomRecoveredCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomRecoveredCopyWith<$R, $In extends RoomRecovered, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? reason});
  RoomRecoveredCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomRecoveredCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomRecovered, $Out>
    implements RoomRecoveredCopyWith<$R, RoomRecovered, $Out> {
  _RoomRecoveredCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomRecovered> $mapper =
      RoomRecoveredMapper.ensureInitialized();
  @override
  $R call({String? reason}) =>
      $apply(FieldCopyWithData({if (reason != null) #reason: reason}));
  @override
  RoomRecovered $make(CopyWithData data) =>
      RoomRecovered(reason: data.get(#reason, or: $value.reason));

  @override
  RoomRecoveredCopyWith<$R2, RoomRecovered, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomRecoveredCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomCrashedMapper extends SubClassMapperBase<RoomCrashed> {
  RoomCrashedMapper._();

  static RoomCrashedMapper? _instance;
  static RoomCrashedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomCrashedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RoomCrashed';

  static String _$reason(RoomCrashed v) => v.reason;
  static const Field<RoomCrashed, String> _f$reason = Field('reason', _$reason);

  @override
  final MappableFields<RoomCrashed> fields = const {#reason: _f$reason};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ROOM_CRASHED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static RoomCrashed _instantiate(DecodingData data) {
    return RoomCrashed(reason: data.dec(_f$reason));
  }

  @override
  final Function instantiate = _instantiate;

  static RoomCrashed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomCrashed>(map);
  }

  static RoomCrashed fromJson(String json) {
    return ensureInitialized().decodeJson<RoomCrashed>(json);
  }
}

mixin RoomCrashedMappable {
  String toJson() {
    return RoomCrashedMapper.ensureInitialized().encodeJson<RoomCrashed>(
      this as RoomCrashed,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomCrashedMapper.ensureInitialized().encodeMap<RoomCrashed>(
      this as RoomCrashed,
    );
  }

  RoomCrashedCopyWith<RoomCrashed, RoomCrashed, RoomCrashed> get copyWith =>
      _RoomCrashedCopyWithImpl<RoomCrashed, RoomCrashed>(
        this as RoomCrashed,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RoomCrashedMapper.ensureInitialized().stringifyValue(
      this as RoomCrashed,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomCrashedMapper.ensureInitialized().equalsValue(
      this as RoomCrashed,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomCrashedMapper.ensureInitialized().hashValue(this as RoomCrashed);
  }
}

extension RoomCrashedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomCrashed, $Out> {
  RoomCrashedCopyWith<$R, RoomCrashed, $Out> get $asRoomCrashed =>
      $base.as((v, t, t2) => _RoomCrashedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomCrashedCopyWith<$R, $In extends RoomCrashed, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? reason});
  RoomCrashedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomCrashedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomCrashed, $Out>
    implements RoomCrashedCopyWith<$R, RoomCrashed, $Out> {
  _RoomCrashedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomCrashed> $mapper =
      RoomCrashedMapper.ensureInitialized();
  @override
  $R call({String? reason}) =>
      $apply(FieldCopyWithData({if (reason != null) #reason: reason}));
  @override
  RoomCrashed $make(CopyWithData data) =>
      RoomCrashed(reason: data.get(#reason, or: $value.reason));

  @override
  RoomCrashedCopyWith<$R2, RoomCrashed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomCrashedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RoomExpiredMapper extends SubClassMapperBase<RoomExpired> {
  RoomExpiredMapper._();

  static RoomExpiredMapper? _instance;
  static RoomExpiredMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoomExpiredMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'RoomExpired';

  @override
  final MappableFields<RoomExpired> fields = const {};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ROOM_EXPIRED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static RoomExpired _instantiate(DecodingData data) {
    return RoomExpired();
  }

  @override
  final Function instantiate = _instantiate;

  static RoomExpired fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RoomExpired>(map);
  }

  static RoomExpired fromJson(String json) {
    return ensureInitialized().decodeJson<RoomExpired>(json);
  }
}

mixin RoomExpiredMappable {
  String toJson() {
    return RoomExpiredMapper.ensureInitialized().encodeJson<RoomExpired>(
      this as RoomExpired,
    );
  }

  Map<String, dynamic> toMap() {
    return RoomExpiredMapper.ensureInitialized().encodeMap<RoomExpired>(
      this as RoomExpired,
    );
  }

  RoomExpiredCopyWith<RoomExpired, RoomExpired, RoomExpired> get copyWith =>
      _RoomExpiredCopyWithImpl<RoomExpired, RoomExpired>(
        this as RoomExpired,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RoomExpiredMapper.ensureInitialized().stringifyValue(
      this as RoomExpired,
    );
  }

  @override
  bool operator ==(Object other) {
    return RoomExpiredMapper.ensureInitialized().equalsValue(
      this as RoomExpired,
      other,
    );
  }

  @override
  int get hashCode {
    return RoomExpiredMapper.ensureInitialized().hashValue(this as RoomExpired);
  }
}

extension RoomExpiredValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RoomExpired, $Out> {
  RoomExpiredCopyWith<$R, RoomExpired, $Out> get $asRoomExpired =>
      $base.as((v, t, t2) => _RoomExpiredCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RoomExpiredCopyWith<$R, $In extends RoomExpired, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call();
  RoomExpiredCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RoomExpiredCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RoomExpired, $Out>
    implements RoomExpiredCopyWith<$R, RoomExpired, $Out> {
  _RoomExpiredCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RoomExpired> $mapper =
      RoomExpiredMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  RoomExpired $make(CopyWithData data) => RoomExpired();

  @override
  RoomExpiredCopyWith<$R2, RoomExpired, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RoomExpiredCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PongMapper extends SubClassMapperBase<Pong> {
  PongMapper._();

  static PongMapper? _instance;
  static PongMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PongMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'Pong';

  static int _$t(Pong v) => v.t;
  static const Field<Pong, int> _f$t = Field('t', _$t);

  @override
  final MappableFields<Pong> fields = const {#t: _f$t};
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PONG';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static Pong _instantiate(DecodingData data) {
    return Pong(t: data.dec(_f$t));
  }

  @override
  final Function instantiate = _instantiate;

  static Pong fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Pong>(map);
  }

  static Pong fromJson(String json) {
    return ensureInitialized().decodeJson<Pong>(json);
  }
}

mixin PongMappable {
  String toJson() {
    return PongMapper.ensureInitialized().encodeJson<Pong>(this as Pong);
  }

  Map<String, dynamic> toMap() {
    return PongMapper.ensureInitialized().encodeMap<Pong>(this as Pong);
  }

  PongCopyWith<Pong, Pong, Pong> get copyWith =>
      _PongCopyWithImpl<Pong, Pong>(this as Pong, $identity, $identity);
  @override
  String toString() {
    return PongMapper.ensureInitialized().stringifyValue(this as Pong);
  }

  @override
  bool operator ==(Object other) {
    return PongMapper.ensureInitialized().equalsValue(this as Pong, other);
  }

  @override
  int get hashCode {
    return PongMapper.ensureInitialized().hashValue(this as Pong);
  }
}

extension PongValueCopy<$R, $Out> on ObjectCopyWith<$R, Pong, $Out> {
  PongCopyWith<$R, Pong, $Out> get $asPong =>
      $base.as((v, t, t2) => _PongCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PongCopyWith<$R, $In extends Pong, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({int? t});
  PongCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PongCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Pong, $Out>
    implements PongCopyWith<$R, Pong, $Out> {
  _PongCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Pong> $mapper = PongMapper.ensureInitialized();
  @override
  $R call({int? t}) => $apply(FieldCopyWithData({if (t != null) #t: t}));
  @override
  Pong $make(CopyWithData data) => Pong(t: data.get(#t, or: $value.t));

  @override
  PongCopyWith<$R2, Pong, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PongCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PlayerAwayMapper extends SubClassMapperBase<PlayerAway> {
  PlayerAwayMapper._();

  static PlayerAwayMapper? _instance;
  static PlayerAwayMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlayerAwayMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PlayerAway';

  static String _$playerId(PlayerAway v) => v.playerId;
  static const Field<PlayerAway, String> _f$playerId = Field(
    'playerId',
    _$playerId,
  );
  static int _$seatIndex(PlayerAway v) => v.seatIndex;
  static const Field<PlayerAway, int> _f$seatIndex = Field(
    'seatIndex',
    _$seatIndex,
  );

  @override
  final MappableFields<PlayerAway> fields = const {
    #playerId: _f$playerId,
    #seatIndex: _f$seatIndex,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PLAYER_AWAY';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static PlayerAway _instantiate(DecodingData data) {
    return PlayerAway(
      playerId: data.dec(_f$playerId),
      seatIndex: data.dec(_f$seatIndex),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlayerAway fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlayerAway>(map);
  }

  static PlayerAway fromJson(String json) {
    return ensureInitialized().decodeJson<PlayerAway>(json);
  }
}

mixin PlayerAwayMappable {
  String toJson() {
    return PlayerAwayMapper.ensureInitialized().encodeJson<PlayerAway>(
      this as PlayerAway,
    );
  }

  Map<String, dynamic> toMap() {
    return PlayerAwayMapper.ensureInitialized().encodeMap<PlayerAway>(
      this as PlayerAway,
    );
  }

  PlayerAwayCopyWith<PlayerAway, PlayerAway, PlayerAway> get copyWith =>
      _PlayerAwayCopyWithImpl<PlayerAway, PlayerAway>(
        this as PlayerAway,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PlayerAwayMapper.ensureInitialized().stringifyValue(
      this as PlayerAway,
    );
  }

  @override
  bool operator ==(Object other) {
    return PlayerAwayMapper.ensureInitialized().equalsValue(
      this as PlayerAway,
      other,
    );
  }

  @override
  int get hashCode {
    return PlayerAwayMapper.ensureInitialized().hashValue(this as PlayerAway);
  }
}

extension PlayerAwayValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PlayerAway, $Out> {
  PlayerAwayCopyWith<$R, PlayerAway, $Out> get $asPlayerAway =>
      $base.as((v, t, t2) => _PlayerAwayCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PlayerAwayCopyWith<$R, $In extends PlayerAway, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? playerId, int? seatIndex});
  PlayerAwayCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PlayerAwayCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PlayerAway, $Out>
    implements PlayerAwayCopyWith<$R, PlayerAway, $Out> {
  _PlayerAwayCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PlayerAway> $mapper =
      PlayerAwayMapper.ensureInitialized();
  @override
  $R call({String? playerId, int? seatIndex}) => $apply(
    FieldCopyWithData({
      if (playerId != null) #playerId: playerId,
      if (seatIndex != null) #seatIndex: seatIndex,
    }),
  );
  @override
  PlayerAway $make(CopyWithData data) => PlayerAway(
    playerId: data.get(#playerId, or: $value.playerId),
    seatIndex: data.get(#seatIndex, or: $value.seatIndex),
  );

  @override
  PlayerAwayCopyWith<$R2, PlayerAway, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PlayerAwayCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PresenceCheckMapper extends SubClassMapperBase<PresenceCheck> {
  PresenceCheckMapper._();

  static PresenceCheckMapper? _instance;
  static PresenceCheckMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PresenceCheckMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PresenceCheck';

  static String _$subjectPlayerId(PresenceCheck v) => v.subjectPlayerId;
  static const Field<PresenceCheck, String> _f$subjectPlayerId = Field(
    'subjectPlayerId',
    _$subjectPlayerId,
  );
  static String _$subjectName(PresenceCheck v) => v.subjectName;
  static const Field<PresenceCheck, String> _f$subjectName = Field(
    'subjectName',
    _$subjectName,
  );
  static int _$deadlineMs(PresenceCheck v) => v.deadlineMs;
  static const Field<PresenceCheck, int> _f$deadlineMs = Field(
    'deadlineMs',
    _$deadlineMs,
  );

  @override
  final MappableFields<PresenceCheck> fields = const {
    #subjectPlayerId: _f$subjectPlayerId,
    #subjectName: _f$subjectName,
    #deadlineMs: _f$deadlineMs,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PRESENCE_CHECK';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static PresenceCheck _instantiate(DecodingData data) {
    return PresenceCheck(
      subjectPlayerId: data.dec(_f$subjectPlayerId),
      subjectName: data.dec(_f$subjectName),
      deadlineMs: data.dec(_f$deadlineMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PresenceCheck fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PresenceCheck>(map);
  }

  static PresenceCheck fromJson(String json) {
    return ensureInitialized().decodeJson<PresenceCheck>(json);
  }
}

mixin PresenceCheckMappable {
  String toJson() {
    return PresenceCheckMapper.ensureInitialized().encodeJson<PresenceCheck>(
      this as PresenceCheck,
    );
  }

  Map<String, dynamic> toMap() {
    return PresenceCheckMapper.ensureInitialized().encodeMap<PresenceCheck>(
      this as PresenceCheck,
    );
  }

  PresenceCheckCopyWith<PresenceCheck, PresenceCheck, PresenceCheck>
  get copyWith => _PresenceCheckCopyWithImpl<PresenceCheck, PresenceCheck>(
    this as PresenceCheck,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return PresenceCheckMapper.ensureInitialized().stringifyValue(
      this as PresenceCheck,
    );
  }

  @override
  bool operator ==(Object other) {
    return PresenceCheckMapper.ensureInitialized().equalsValue(
      this as PresenceCheck,
      other,
    );
  }

  @override
  int get hashCode {
    return PresenceCheckMapper.ensureInitialized().hashValue(
      this as PresenceCheck,
    );
  }
}

extension PresenceCheckValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PresenceCheck, $Out> {
  PresenceCheckCopyWith<$R, PresenceCheck, $Out> get $asPresenceCheck =>
      $base.as((v, t, t2) => _PresenceCheckCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PresenceCheckCopyWith<$R, $In extends PresenceCheck, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? subjectPlayerId, String? subjectName, int? deadlineMs});
  PresenceCheckCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PresenceCheckCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PresenceCheck, $Out>
    implements PresenceCheckCopyWith<$R, PresenceCheck, $Out> {
  _PresenceCheckCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PresenceCheck> $mapper =
      PresenceCheckMapper.ensureInitialized();
  @override
  $R call({String? subjectPlayerId, String? subjectName, int? deadlineMs}) =>
      $apply(
        FieldCopyWithData({
          if (subjectPlayerId != null) #subjectPlayerId: subjectPlayerId,
          if (subjectName != null) #subjectName: subjectName,
          if (deadlineMs != null) #deadlineMs: deadlineMs,
        }),
      );
  @override
  PresenceCheck $make(CopyWithData data) => PresenceCheck(
    subjectPlayerId: data.get(#subjectPlayerId, or: $value.subjectPlayerId),
    subjectName: data.get(#subjectName, or: $value.subjectName),
    deadlineMs: data.get(#deadlineMs, or: $value.deadlineMs),
  );

  @override
  PresenceCheckCopyWith<$R2, PresenceCheck, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PresenceCheckCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PresenceResolvedMapper extends SubClassMapperBase<PresenceResolved> {
  PresenceResolvedMapper._();

  static PresenceResolvedMapper? _instance;
  static PresenceResolvedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PresenceResolvedMapper._());
      ServerMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'PresenceResolved';

  static String _$subjectPlayerId(PresenceResolved v) => v.subjectPlayerId;
  static const Field<PresenceResolved, String> _f$subjectPlayerId = Field(
    'subjectPlayerId',
    _$subjectPlayerId,
  );
  static bool _$removed(PresenceResolved v) => v.removed;
  static const Field<PresenceResolved, bool> _f$removed = Field(
    'removed',
    _$removed,
  );

  @override
  final MappableFields<PresenceResolved> fields = const {
    #subjectPlayerId: _f$subjectPlayerId,
    #removed: _f$removed,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'PRESENCE_RESOLVED';
  @override
  late final ClassMapperBase superMapper =
      ServerMessageMapper.ensureInitialized();

  static PresenceResolved _instantiate(DecodingData data) {
    return PresenceResolved(
      subjectPlayerId: data.dec(_f$subjectPlayerId),
      removed: data.dec(_f$removed),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PresenceResolved fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PresenceResolved>(map);
  }

  static PresenceResolved fromJson(String json) {
    return ensureInitialized().decodeJson<PresenceResolved>(json);
  }
}

mixin PresenceResolvedMappable {
  String toJson() {
    return PresenceResolvedMapper.ensureInitialized()
        .encodeJson<PresenceResolved>(this as PresenceResolved);
  }

  Map<String, dynamic> toMap() {
    return PresenceResolvedMapper.ensureInitialized()
        .encodeMap<PresenceResolved>(this as PresenceResolved);
  }

  PresenceResolvedCopyWith<PresenceResolved, PresenceResolved, PresenceResolved>
  get copyWith =>
      _PresenceResolvedCopyWithImpl<PresenceResolved, PresenceResolved>(
        this as PresenceResolved,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PresenceResolvedMapper.ensureInitialized().stringifyValue(
      this as PresenceResolved,
    );
  }

  @override
  bool operator ==(Object other) {
    return PresenceResolvedMapper.ensureInitialized().equalsValue(
      this as PresenceResolved,
      other,
    );
  }

  @override
  int get hashCode {
    return PresenceResolvedMapper.ensureInitialized().hashValue(
      this as PresenceResolved,
    );
  }
}

extension PresenceResolvedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PresenceResolved, $Out> {
  PresenceResolvedCopyWith<$R, PresenceResolved, $Out>
  get $asPresenceResolved =>
      $base.as((v, t, t2) => _PresenceResolvedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PresenceResolvedCopyWith<$R, $In extends PresenceResolved, $Out>
    implements ServerMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? subjectPlayerId, bool? removed});
  PresenceResolvedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PresenceResolvedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PresenceResolved, $Out>
    implements PresenceResolvedCopyWith<$R, PresenceResolved, $Out> {
  _PresenceResolvedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PresenceResolved> $mapper =
      PresenceResolvedMapper.ensureInitialized();
  @override
  $R call({String? subjectPlayerId, bool? removed}) => $apply(
    FieldCopyWithData({
      if (subjectPlayerId != null) #subjectPlayerId: subjectPlayerId,
      if (removed != null) #removed: removed,
    }),
  );
  @override
  PresenceResolved $make(CopyWithData data) => PresenceResolved(
    subjectPlayerId: data.get(#subjectPlayerId, or: $value.subjectPlayerId),
    removed: data.get(#removed, or: $value.removed),
  );

  @override
  PresenceResolvedCopyWith<$R2, PresenceResolved, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PresenceResolvedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

