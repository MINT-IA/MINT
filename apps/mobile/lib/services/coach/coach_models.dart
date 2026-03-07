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
  scenario,          // max 150 words
  enrichmentGuide,   // max 150 words — data block conversational guide
  general,           // max 200 words
}

/// Word limits per component type.
const Map<ComponentType, int> componentWordLimits = {
  ComponentType.greeting: 30,
  ComponentType.scoreSummary: 80,
  ComponentType.tip: 120,
  ComponentType.chiffreChoc: 100,
  ComponentType.scenario: 150,
  ComponentType.enrichmentGuide: 150,
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

/// Context passed to compliance guard and narrative generation.
///
/// Contains financial_core outputs — NEVER raw amounts.
/// All values are pre-computed by financial_core calculators.
///
/// Extended in S35 with archetype, behavioral, and temporal fields
/// to support the Coach Narrative Service.
class CoachContext {
  final String firstName;
  final String archetype;
  final int age;
  final String canton;
  // Financial state (aggregated, never raw)
  final double friTotal;
  final double friDelta;
  final String primaryFocus;
  final double replacementRatio;
  final double monthsLiquidity;
  final double taxSavingPotential;
  final double confidenceScore;
  // Temporal
  final int daysSinceLastVisit;
  final String fiscalSeason;
  final String upcomingEvent;
  // Behavioral
  final int checkInStreak;
  final String lastMilestone;
  // Known numerical values for hallucination detection
  final Map<String, double> knownValues;
  // Data reliability by field: 'certified', 'userInput', or 'estimated'
  // e.g. {'avoirLpp': 'certified', 'patrimoine': 'estimated'}
  final Map<String, String> dataReliability;

  const CoachContext({
    this.firstName = 'utilisateur',
    this.archetype = 'swiss_native',
    this.age = 30,
    this.canton = 'VD',
    this.friTotal = 0.0,
    this.friDelta = 0.0,
    this.primaryFocus = '',
    this.replacementRatio = 0.0,
    this.monthsLiquidity = 0.0,
    this.taxSavingPotential = 0.0,
    this.confidenceScore = 0.0,
    this.daysSinceLastVisit = 0,
    this.fiscalSeason = '',
    this.upcomingEvent = '',
    this.checkInStreak = 0,
    this.lastMilestone = '',
    this.knownValues = const {},
    this.dataReliability = const {},
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
