import 'package:poker_protocol/poker_protocol.dart';

/// What this build can do, sent with every `JOIN_ROOM` and `RESUME` so a server can refuse to
/// seat an app that lacks a feature its room needs (`UPDATE_REQUIRED`).
const List<String> appFeatures = <String>[featureVirtualCards];
