import 'package:dart_mappable/dart_mappable.dart';

/// `SCREAMING_SNAKE_CASE`, the spelling of message types, enum values and action kinds on the
/// wire. Field names stay `camelCase`.
const CaseStyle screamingSnake = CaseStyle(head: TextTransform.upperCase, tail: TextTransform.upperCase, separator: '_');
