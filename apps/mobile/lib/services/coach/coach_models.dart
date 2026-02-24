/// Coach shared models — Sprint S34.
///
/// Data classes for compliance validation, coach context,
/// and hallucination detection.
library;

/// Type of coach output component, each with length constraints.
enum ComponentType {
  greeting,      // max 30 words
  scoreSummary,  // max 80 words
  tip,           // max 120 words
  chiffreChoc,   // max 100 words
  scenario,      // max 150 words
  general,       // max 200 words
}

/// Word limits per component type.
const Map<ComponentType, int> componentWordLimits = {
  ComponentType.greeting: 30,
  ComponentType.scoreSummary: 80,
  ComponentType.tip: 120,
  ComponentType.chiffreChoc: 100,
  ComponentType.scenario: 150,
  ComponentType.general: 200,
};

/// Result of compliance validation on LLM output.
class ComplianceResult {
  final bool isCompliant;
  final String sanitizedText;
  final List<String> violations;
  final bool useFallback;

  const ComplianceResult({
    required this.isCompliant,
    required this.sanitizedText,
    this.violations = const [],
    this.useFallback = false,
  });
}

/// Context passed to compliance guard for number verification.
///
/// Contains financial_core outputs — NEVER raw amounts.
class CoachContext {
  final String firstName;
  final double friTotal;
  final double friDelta;
  final String primaryFocus;
  final int daysSinceLastVisit;
  final String fiscalSeason;
  final Map<String, double> knownValues;

  const CoachContext({
    this.firstName = 'utilisateur',
    this.friTotal = 0.0,
    this.friDelta = 0.0,
    this.primaryFocus = '',
    this.daysSinceLastVisit = 0,
    this.fiscalSeason = '',
    this.knownValues = const {},
  });
}

/// A number found in LLM output that doesn't match known values.
class HallucinatedNumber {
  final String foundText;
  final double foundValue;
  final String closestKey;
  final double closestValue;
  final double deviationPct;

  const HallucinatedNumber({
    required this.foundText,
    required this.foundValue,
    required this.closestKey,
    required this.closestValue,
    required this.deviationPct,
  });
}
