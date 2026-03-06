/// Coach Context Builder — Sprint S35 (Coach Narrative).
///
/// Builds a [CoachContext] from profile data for use by
/// [FallbackTemplates], [CoachNarrativeService], and [ComplianceGuard].
///
/// ## Numeric Grounding Contract
///
/// All values in [knownValues] MUST come from financial_core calculators
/// (never raw user input) to ensure [HallucinationDetector] can verify
/// LLM output against ground truth.
///
/// ### Grounding keys (registered in [knownValues]):
///
/// | Key                  | Source                       | Unit    | Tolerance |
/// |----------------------|------------------------------|---------|-----------|
/// | `fri_total`          | FinancialFitnessService      | 0-100   | ±2 pts   |
/// | `replacement_ratio`  | ForecasterService            | %       | ±2 pts   |
/// | `months_liquidity`   | derived (liquid / expenses)  | months  | ±5%      |
/// | `tax_saving`         | TaxCalculator                | CHF     | ±5%      |
/// | `confidence_score`   | ConfidenceScorer             | 0-100   | ±2 pts   |
/// | `capital_final`      | ForecasterService            | CHF     | ±5%      |
/// | `epargne_3a`         | Profile (verified)           | CHF     | ±5%      |
/// | `avoir_lpp`          | Profile (verified)           | CHF     | ±5%      |
/// | `salaire_brut`       | Profile (verified)           | CHF/an  | ±5%      |
///
/// Adding a value here means [HallucinationDetector] will flag any LLM
/// output containing a number that deviates beyond tolerance from these
/// ground-truth values. Only add values that are **computed or verified**
/// — never raw user text input.
///
/// References:
///   - FINMA circular 2008/21 (operational risk)
///   - LSFin art. 8 (quality of financial information)
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
  ///   - [capitalFinal]: Projected retirement capital (CHF)
  ///   - [epargne3a]: Current 3a savings balance (CHF)
  ///   - [avoirLpp]: Current LPP balance (CHF)
  ///   - [salaireBrut]: Annual gross salary (CHF)
  ///   - [daysSinceLastVisit]: Days since last app visit
  ///   - [fiscalSeason]: Current fiscal season code
  ///   - [checkInStreak]: Consecutive months of check-ins
  ///   - [lastMilestone]: Last achieved milestone label
  /// [dataSources]: Map from profile field key to source enum name
  ///   (e.g. {'prevoyance.avoirLppTotal': 'certificate'}).
  ///   Passed through as simplified dataReliability map for SLM prompting.
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
    double capitalFinal = 0,
    double epargne3a = 0,
    double avoirLpp = 0,
    double salaireBrut = 0,
    int daysSinceLastVisit = 0,
    String fiscalSeason = '',
    int checkInStreak = 0,
    String lastMilestone = '',
    String upcomingEvent = '',
    Map<String, String> dataSources = const {},
  }) {
    // Build grounding values map — only include non-zero values
    // so HallucinationDetector doesn't false-positive on missing data.
    final knownValues = <String, double>{};
    if (friTotal > 0) knownValues['fri_total'] = friTotal;
    if (replacementRatio > 0) {
      knownValues['replacement_ratio'] = replacementRatio * 100;
    }
    if (monthsLiquidity > 0) knownValues['months_liquidity'] = monthsLiquidity;
    if (taxSavingPotential > 0) knownValues['tax_saving'] = taxSavingPotential;
    if (confidenceScore > 0) knownValues['confidence_score'] = confidenceScore;
    if (capitalFinal > 0) knownValues['capital_final'] = capitalFinal;
    if (epargne3a > 0) knownValues['epargne_3a'] = epargne3a;
    if (avoirLpp > 0) knownValues['avoir_lpp'] = avoirLpp;
    if (salaireBrut > 0) knownValues['salaire_brut'] = salaireBrut;

    return CoachContext(
      firstName: firstName,
      archetype: archetype,
      age: age,
      canton: canton,
      friTotal: friTotal,
      friDelta: friDelta,
      primaryFocus: primaryFocus,
      replacementRatio: replacementRatio,
      monthsLiquidity: monthsLiquidity,
      taxSavingPotential: taxSavingPotential,
      confidenceScore: confidenceScore,
      daysSinceLastVisit: daysSinceLastVisit,
      fiscalSeason: fiscalSeason,
      upcomingEvent: upcomingEvent,
      checkInStreak: checkInStreak,
      lastMilestone: lastMilestone,
      knownValues: knownValues,
      dataReliability: dataSources,
    );
  }
}
