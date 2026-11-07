import 'package:dart_mappable/dart_mappable.dart';

/// Leaves fields out of a class's JSON while they hold their default value.
///
/// The Rust server skips the same fields, so frames of rooms without virtual cards stay
/// byte-for-byte what they were before the fields existed. Put it on the class:
/// `@MappableClass(hook: OmitWhenDefault({'features': <Object?>[]}))`.
class OmitWhenDefault extends MappingHook {
  const OmitWhenDefault(this.defaults);

  /// Encoded field name to the encoded value that means "nothing to say".
  final Map<String, Object?> defaults;

  @override
  Object? afterEncode(Object? value) {
    if (value is Map<String, dynamic>) {
      defaults.forEach((key, fallback) {
        if (_same(value[key], fallback)) {
          value.remove(key);
        }
      });
    }
    return value;
  }

  static bool _same(Object? a, Object? b) {
    if (a is List<Object?> && b is List<Object?>) {
      return a.length == b.length;
    }
    return a == b;
  }
}
