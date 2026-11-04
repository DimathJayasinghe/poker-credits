import 'package:flutter/foundation.dart';

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
    this.defaultName = '',
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

  /// Prefills the name field when joining. Empty = none.
  final String defaultName;

  AppSettings copyWith({ThemeChoice? theme, bool? texture, bool? sound, bool? vibration, bool? keepAwake, String? defaultName}) => AppSettings(
    theme: theme ?? this.theme,
    texture: texture ?? this.texture,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    keepAwake: keepAwake ?? this.keepAwake,
    defaultName: defaultName ?? this.defaultName,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'v': 1,
    'theme': theme.name,
    'texture': texture,
    'sound': sound,
    'vibration': vibration,
    'keepAwake': keepAwake,
    'defaultName': defaultName,
  };

  /// Anything that is not a JSON object, and any field of the wrong type, falls back to the
  /// default for that field.
  static AppSettings fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return defaults;
    bool flag(String key, bool fallback) => json[key] is bool ? json[key]! as bool : fallback;
    final theme = ThemeChoice.values.asNameMap()[json['theme']] ?? defaults.theme;
    final rawName = json['defaultName'];
    final name = rawName is String && _nameRule.hasMatch(rawName.trim()) ? rawName.trim() : '';
    return AppSettings(
      theme: theme,
      texture: flag('texture', defaults.texture),
      sound: flag('sound', defaults.sound),
      vibration: flag('vibration', defaults.vibration),
      keepAwake: flag('keepAwake', defaults.keepAwake),
      defaultName: name,
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
      other.defaultName == defaultName;

  @override
  int get hashCode => Object.hash(theme, texture, sound, vibration, keepAwake, defaultName);
}
