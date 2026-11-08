import 'package:flutter/foundation.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The version of the terms and safety notice the player has to accept. Raise it when the notice
/// changes in a way people must see again.
const int currentTermsVersion = 2;

/// Which theme the app uses. [system] follows the operating system.
enum ThemeChoice { system, light, dark }

/// How a player has done against one kind of table: a number of opponents at one skill level.
@immutable
class SoloRecord {
  const SoloRecord({this.played = 0, this.wins = 0, this.bestPlace = 0});

  /// Games finished (won or lost). Leaving a game early does not count.
  final int played;
  final int wins;

  /// Best finishing place (1 = won); 0 = none yet.
  final int bestPlace;

  /// This record after one more finished game in which the player took [place].
  SoloRecord after(int place) => SoloRecord(
    played: played + 1,
    wins: wins + (place == 1 ? 1 : 0),
    bestPlace: bestPlace == 0 || place < bestPlace ? place : bestPlace,
  );

  Map<String, Object?> toJson() => <String, Object?>{'played': played, 'wins': wins, 'bestPlace': bestPlace};

  static SoloRecord? fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    int count(String key) => json[key] is int && (json[key]! as int) > 0 ? json[key]! as int : 0;
    final record = SoloRecord(played: count('played'), wins: count('wins'), bestPlace: count('bestPlace'));
    // A record that contradicts itself is dropped rather than shown.
    if (record.wins > record.played || record.played == 0) return null;
    return record;
  }

  @override
  bool operator ==(Object other) => other is SoloRecord && other.played == played && other.wins == wins && other.bestPlace == bestPlace;

  @override
  int get hashCode => Object.hash(played, wins, bestPlace);
}

/// Key of a [SoloRecord] in [AppSettings.soloRecords].
String soloRecordKey(int bots, BotSkill skill) => '$bots-${skill.name}';

/// The player's preferences, kept on this device (docs/UI_DESIGN.md section 5, Settings).
///
/// Reading is tolerant on purpose: a missing, truncated or hand-edited file gives defaults for
/// whatever cannot be understood and never stops the app from starting.
@immutable
class AppSettings {
  const AppSettings({
    this.theme = ThemeChoice.system,
    this.texture = true,
    this.sound = true,
    this.vibration = true,
    this.keepAwake = true,
    this.fourColourDeck = false,
    this.cardsFaceUp = false,
    this.defaultName = '',
    this.acceptedTerms = 0,
    this.introDone = false,
    this.nameAsked = false,
    this.soloBots = 4,
    this.soloSkill = BotSkill.normal,
    this.soloLength = SoloLength.standard,
    this.soloRecords = const <String, SoloRecord>{},
  });

  static const AppSettings defaults = AppSettings();

  /// Same rule as the join form, so a saved name always passes it.
  static final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

  /// Whether [name] (trimmed) is a name the server accepts.
  static bool isValidName(String name) => _nameRule.hasMatch(name.trim());

  final ThemeChoice theme;

  /// Paper grain behind the screens.
  final bool texture;

  /// Audible "your turn" cue.
  final bool sound;

  /// Vibration cues.
  final bool vibration;

  /// Keep the display on while a table or player screen is open.
  final bool keepAwake;

  /// Clubs green and diamonds blue, so the four suits differ by colour as well as shape.
  final bool fourColourDeck;

  /// Your own cards start face up. Off by default: a glance from the next seat shows nothing.
  final bool cardsFaceUp;

  /// Prefills the name field when joining. Empty = none.
  final String defaultName;

  /// The version of the terms notice accepted on this device; 0 = never.
  final int acceptedTerms;

  /// The first-run intro (the offer of a tour) has been answered, taken or skipped.
  final bool introDone;

  /// The first-run question for a default name has been answered or skipped, so it is not asked
  /// again. Someone who already finished the intro before this question existed counts as asked.
  final bool nameAsked;

  /// What the single-player setup shows the next time: opponents, skill and game length.
  final int soloBots;
  final BotSkill soloSkill;
  final SoloLength soloLength;

  /// Finished single-player games by table kind ([soloRecordKey]). Kept on this device only.
  final Map<String, SoloRecord> soloRecords;

  /// The record for [bots] opponents at [skill], if any game was finished there.
  SoloRecord? recordFor(int bots, BotSkill skill) => soloRecords[soloRecordKey(bots, skill)];

  /// Whether the notice the app is showing now has been accepted.
  bool get termsAccepted => acceptedTerms >= currentTermsVersion;

  AppSettings copyWith({
    ThemeChoice? theme,
    bool? texture,
    bool? sound,
    bool? vibration,
    bool? keepAwake,
    bool? fourColourDeck,
    bool? cardsFaceUp,
    String? defaultName,
    int? acceptedTerms,
    bool? introDone,
    bool? nameAsked,
    int? soloBots,
    BotSkill? soloSkill,
    SoloLength? soloLength,
    Map<String, SoloRecord>? soloRecords,
  }) => AppSettings(
    theme: theme ?? this.theme,
    texture: texture ?? this.texture,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    keepAwake: keepAwake ?? this.keepAwake,
    fourColourDeck: fourColourDeck ?? this.fourColourDeck,
    cardsFaceUp: cardsFaceUp ?? this.cardsFaceUp,
    defaultName: defaultName ?? this.defaultName,
    acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    introDone: introDone ?? this.introDone,
    nameAsked: nameAsked ?? this.nameAsked,
    soloBots: soloBots ?? this.soloBots,
    soloSkill: soloSkill ?? this.soloSkill,
    soloLength: soloLength ?? this.soloLength,
    soloRecords: soloRecords ?? this.soloRecords,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'v': 1,
    'theme': theme.name,
    'texture': texture,
    'sound': sound,
    'vibration': vibration,
    'keepAwake': keepAwake,
    'fourColourDeck': fourColourDeck,
    'cardsFaceUp': cardsFaceUp,
    'defaultName': defaultName,
    'acceptedTerms': acceptedTerms,
    'introDone': introDone,
    'nameAsked': nameAsked,
    'soloBots': soloBots,
    'soloSkill': soloSkill.name,
    'soloLength': soloLength.ladderHands,
    'soloRecords': <String, Object?>{for (final e in soloRecords.entries) e.key: e.value.toJson()},
  };

  /// Anything that is not a JSON object, and any field of the wrong type, falls back to the
  /// default for that field.
  static AppSettings fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return defaults;
    bool flag(String key, bool fallback) => json[key] is bool ? json[key]! as bool : fallback;
    final theme = ThemeChoice.values.asNameMap()[json['theme']] ?? defaults.theme;
    final rawName = json['defaultName'];
    final name = rawName is String && _nameRule.hasMatch(rawName.trim()) ? rawName.trim() : '';
    final introDone = flag('introDone', defaults.introDone);
    final rawTerms = json['acceptedTerms'];
    final rawBots = json['soloBots'];
    final rawLength = json['soloLength'];
    final rawRecords = json['soloRecords'];
    final records = <String, SoloRecord>{};
    if (rawRecords is Map<Object?, Object?>) {
      for (final entry in rawRecords.entries) {
        final record = SoloRecord.fromJson(entry.value);
        if (entry.key is String && record != null) records[entry.key! as String] = record;
      }
    }
    return AppSettings(
      theme: theme,
      texture: flag('texture', defaults.texture),
      sound: flag('sound', defaults.sound),
      vibration: flag('vibration', defaults.vibration),
      keepAwake: flag('keepAwake', defaults.keepAwake),
      fourColourDeck: flag('fourColourDeck', defaults.fourColourDeck),
      cardsFaceUp: flag('cardsFaceUp', defaults.cardsFaceUp),
      defaultName: name,
      // Only a whole, positive number counts. Anything else means "not accepted".
      acceptedTerms: rawTerms is int && rawTerms > 0 ? rawTerms : 0,
      introDone: introDone,
      nameAsked: flag('nameAsked', introDone || name.isNotEmpty),
      soloBots: rawBots is int && rawBots >= minSoloBots && rawBots <= maxSoloBots ? rawBots : defaults.soloBots,
      soloSkill: BotSkill.values.asNameMap()[json['soloSkill']] ?? defaults.soloSkill,
      soloLength: rawLength is int ? SoloLength.fromHands(rawLength) : defaults.soloLength,
      soloRecords: records,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.texture == texture &&
      other.sound == sound &&
      other.vibration == vibration &&
      other.keepAwake == keepAwake &&
      other.fourColourDeck == fourColourDeck &&
      other.cardsFaceUp == cardsFaceUp &&
      other.defaultName == defaultName &&
      other.acceptedTerms == acceptedTerms &&
      other.introDone == introDone &&
      other.nameAsked == nameAsked &&
      other.soloBots == soloBots &&
      other.soloSkill == soloSkill &&
      other.soloLength == soloLength &&
      mapEquals(other.soloRecords, soloRecords);

  @override
  int get hashCode => Object.hash(
    Object.hash(theme, texture, sound, vibration, keepAwake, fourColourDeck, cardsFaceUp, defaultName, acceptedTerms, introDone, nameAsked),
    soloBots,
    soloSkill,
    soloLength,
    // Order of the entries must not matter, as it does not for equality.
    soloRecords.entries.fold<int>(0, (sum, e) => sum ^ Object.hash(e.key, e.value)),
  );
}
