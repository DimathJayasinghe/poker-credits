import 'package:flutter/foundation.dart';

/// The version of the terms and safety notice the player has to accept. Raise it when the notice
/// changes in a way people must see again.
const int currentTermsVersion = 1;

/// Which theme the app uses. [system] follows the operating system.
enum ThemeChoice { system, light, dark }

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
  });

  static const AppSettings defaults = AppSettings();

  /// Same rule as the join form, so a saved name always passes it.
  static final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

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
  };

  /// Anything that is not a JSON object, and any field of the wrong type, falls back to the
  /// default for that field.
  static AppSettings fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return defaults;
    bool flag(String key, bool fallback) => json[key] is bool ? json[key]! as bool : fallback;
    final theme = ThemeChoice.values.asNameMap()[json['theme']] ?? defaults.theme;
    final rawName = json['defaultName'];
    final name = rawName is String && _nameRule.hasMatch(rawName.trim()) ? rawName.trim() : '';
    final rawTerms = json['acceptedTerms'];
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
      introDone: flag('introDone', defaults.introDone),
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
      other.introDone == introDone;

  @override
  int get hashCode => Object.hash(theme, texture, sound, vibration, keepAwake, fourColourDeck, cardsFaceUp, defaultName, acceptedTerms, introDone);
}
