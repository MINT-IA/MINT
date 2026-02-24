/// Coach Context Builder — Sprint S35 (Coach Narrative).
///
/// Builds a [CoachContext] from profile data for use by
/// [FallbackTemplates], [CoachNarrativeService], and [ComplianceGuard].
///
/// All values in [knownValues] come from financial_core calculators
/// (never raw user input) to ensure ComplianceGuard hallucination
/// detection works correctly.
library;

import 'coach_models.dart';

class CoachContextBuilder {
  CoachContextBuilder._();

  /// Build a [CoachContext] from profile-derived values.
  ///
  /// All numeric values should originate from financial_core calculators
  /// or derived computations — never from raw user text input.
  ///
  /// Parameters:
  ///   - [firstName]: User's first name (default: 'utilisateur')
  ///   - [age]: User's age
  ///   - [canton]: Swiss canton code (e.g. 'VD', 'ZH')
  ///   - [archetype]: Financial archetype (see ADR-20260223)
  ///   - [friTotal]: Current Financial Resilience Index score (0-100)
  ///   - [friDelta]: Change in FRI since last check-in
  ///   - [primaryFocus]: Current coaching focus area
  ///   - [replacementRatio]: Estimated retirement replacement ratio (0.0-1.0)
  ///   - [monthsLiquidity]: Months of expenses covered by liquid savings
  ///   - [taxSavingPotential]: Estimated tax savings from 3a/LPP actions (CHF)
  ///   - [confidenceScore]: Projection confidence (0-100)
  ///   - [daysSinceLastVisit]: Days since last app visit
  ///   - [fiscalSeason]: Current fiscal season code (e.g. '3a_deadline', 'tax_declaration', '')
  ///   - [checkInStreak]: Consecutive months of check-ins
  ///   - [lastMilestone]: Last achieved milestone label
  static CoachContext build({
    String firstName = 'utilisateur',
    int age = 30,
    String canton = 'VD',
    String archetype = 'swiss_native',
    double friTotal = 0,
    double friDelta = 0,
    String primaryFocus = '',
    double replacementRatio = 0,
    double monthsLiquidity = 0,
    double taxSavingPotential = 0,
    double confidenceScore = 0,
    int daysSinceLastVisit = 0,
    String fiscalSeason = '',
    int checkInStreak = 0,
    String lastMilestone = '',
  }) {
    return CoachContext(
      firstName: firstName,
      friTotal: friTotal,
      friDelta: friDelta,
      primaryFocus: primaryFocus,
      daysSinceLastVisit: daysSinceLastVisit,
      fiscalSeason: fiscalSeason,
      knownValues: {
        'fri_total': friTotal,
        'replacement_ratio': replacementRatio * 100,
        'months_liquidity': monthsLiquidity,
        'tax_saving': taxSavingPotential,
        'confidence_score': confidenceScore,
      },
    );
  }
}
