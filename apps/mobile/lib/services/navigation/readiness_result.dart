/// ReadinessResult and ReadinessLevel — shared types used by both
/// ReadinessGate (readiness_gate.dart) and the custom gate functions
/// declared alongside ScreenEntry in screen_registry.dart.
///
/// Extracted to avoid a circular import between the two files.
library;

// ════════════════════════════════════════════════════════════════
//  READINESS LEVEL
// ════════════════════════════════════════════════════════════════

/// The three readiness levels for opening a surface from the chat.
enum ReadinessLevel {
  /// All [requiredFields] are present. Open the screen directly.
  ready,

  /// Some [requiredFields] are missing, but the screen can operate in
  /// estimation mode. Open with a bandeau d'avertissement and enrichment CTA.
  partial,

  /// A critical field is absent without which the screen has no meaning.
  /// The RoutePlanner should ask 1–2 questions before routing.
  blocked,
}

// ════════════════════════════════════════════════════════════════
//  READINESS RESULT
// ════════════════════════════════════════════════════════════════

/// The result of a ReadinessGate check for a specific surface and profile.
class ReadinessResult {
  /// The computed readiness level.
  final ReadinessLevel level;

  /// All fields from [ScreenEntry.requiredFields] that are absent.
  ///
  /// May include both critical and non-critical missing fields.
  /// Empty when [level] is [ReadinessLevel.ready].
  final List<String> missingFields;

  /// Subset of [missingFields] that are blocking (critical).
  ///
  /// These are fields without which the screen has no meaningful content.
  /// Non-empty only when [level] is [ReadinessLevel.blocked].
  final List<String> missingCritical;

  const ReadinessResult({
    required this.level,
    this.missingFields = const [],
    this.missingCritical = const [],
  });

  /// Convenience: ready with no missing fields.
  const ReadinessResult.ready()
      : level = ReadinessLevel.ready,
        missingFields = const [],
        missingCritical = const [];

  /// Convenience: partial — at least one non-critical field is missing.
  const ReadinessResult.partial(List<String> missing)
      : level = ReadinessLevel.partial,
        missingFields = missing,
        missingCritical = const [];

  /// Convenience: blocked — one or more critical fields are absent.
  const ReadinessResult.blocked(
      List<String> allMissing, List<String> critical)
      : level = ReadinessLevel.blocked,
        missingFields = allMissing,
        missingCritical = critical;

  @override
  String toString() => 'ReadinessResult('
      'level: $level, '
      'missingFields: $missingFields, '
      'missingCritical: $missingCritical)';
}
