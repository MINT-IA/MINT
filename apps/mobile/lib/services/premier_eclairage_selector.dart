import 'dart:math';

import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

/// Selects the most impactful "premier éclairage" to show the user.
///
/// Sprint S57 — PremierEclairage V2: intention × lifecycle × confidence × available data.
///
/// Selection hierarchy:
/// 1. Stress-aligned selection (if stressType declared, data supports it)
/// 2. Universal priorities (liquidity crisis, tax saving)
///    — gated by lifecycle relevance and data confidence
/// 3. Lifecycle-aware fallback (age-driven, always valid)
///
/// AVS-dependent insights are quarantined because this model carries no
/// reviewed field-level provenance.
///
/// Confidence gating:
/// - If the premier éclairage's key data is estimated → [PremierEclairageConfidence.pedagogical]
/// - If based on provided data or pure math → [PremierEclairageConfidence.factual]
///
/// Legal basis: LAVS art. 21-40, LPP art. 7-16, OPP3 art. 7, LIFD art. 38.
class PremierEclairageSelector {
  PremierEclairageSelector._();

  /// Select the most impactful premier éclairage for the given profile.
  ///
  /// [stressType] — user's declared intention from StepStressSelector.
  /// When set and not 'stress_general', influences which type of chiffre
  /// choc is selected (if the data supports it).
  static PremierEclairage select(
    MinimalProfileResult profile, {
    String? stressType,
  }) {
    // Phase 1: Stress-aligned selection
    if (stressType != null && stressType != 'stress_general') {
      final stressChoc = _selectByStress(stressType, profile);
      if (stressChoc != null) return _withConfidence(stressChoc, profile);
    }

    // Phase 2: Universal priorities — gated by lifecycle relevance
    // Liquidity alert: only when savings data is REAL (not estimated)
    // OR when the crisis is severe (< 1 month even with estimation)
    final savingsEstimated = profile.estimatedFields.contains('currentSavings');
    if (profile.liquidityMonths < 2 &&
        profile.currentSavings >= 0 &&
        (!savingsEstimated || profile.liquidityMonths < 1)) {
      return _withConfidence(_buildLiquidityChoc(profile), profile);
    }

    // Tax saving 3a: always relevant if applicable
    if (profile.existing3a <= 0 && profile.taxSaving3a > 1500) {
      return _withConfidence(_buildTaxSaving3aChoc(profile), profile);
    }

    // Phase 3: Lifecycle-aware fallback (NEW)
    return _withConfidence(_selectByLifecycle(profile), profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 1: Stress-aligned selection
  // ═══════════════════════════════════════════════════════════════════════════

  /// Try to produce a premier éclairage aligned with the user's declared intention.
  ///
  /// Returns null if the data doesn't support a meaningful choc for this stress.
  static PremierEclairage? _selectByStress(
    String stressType,
    MinimalProfileResult profile,
  ) {
    switch (stressType) {
      case 'stress_budget':
        // Budget: show hourly rate (pure math from salary — always factual)
        if (profile.grossMonthlySalary > 0) {
          return _buildHourlyRateChoc(profile);
        }
        return null;

      case 'stress_impots':
        // Tax: show 3a tax saving if applicable
        if (profile.taxSaving3a > 500) {
          return _buildTaxSaving3aChoc(profile);
        }
        return null;

      case 'stress_retraite':
        // MinimalProfileResult has no reviewed-provenance contract. Legacy
        // doubles must never reactivate an AVS-dependent insight.
        return _selectNonRetirementAlternative(profile);

      case 'stress_patrimoine':
        // Patrimoine: only if we have real data — don't estimate fortune
        // Without real patrimoine data, fall through to lifecycle
        return null;

      case 'stress_couple':
        // Couple: no couple data at onboarding — fall through
        return null;

      case 'stress_prevoyance':
        // First job / prevoyance: show 3a tax saving or compound growth
        if (profile.taxSaving3a > 500) {
          return _buildTaxSaving3aChoc(profile);
        }
        if (profile.age < 35) {
          return _buildCompoundGrowthChoc(profile);
        }
        return _selectNonRetirementAlternative(profile);

      default:
        return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 3: Lifecycle-aware fallback
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lifecycle-aware fallback when no stress/universal priority matched.
  ///
  /// Uses pure math or well-grounded calculations per age group.
  /// Avoids showing retirement projections to users under 28.
  static PremierEclairage _selectByLifecycle(MinimalProfileResult profile) {
    if (profile.age < 28) {
      // Young: compound growth advantage (pure math, no estimation)
      return _buildCompoundGrowthChoc(profile);
    }
    if (profile.age < 38) {
      // Construction: tax saving 3a is the most actionable lever
      if (profile.existing3a <= 0 && profile.taxSaving3a > 1500) {
        return _buildTaxSaving3aChoc(profile);
      }
      // Else: compound growth still meaningful
      return _buildCompoundGrowthChoc(profile);
    }
    // This model cannot carry reviewed AVS provenance, so later lifecycle
    // stages remain on non-retirement alternatives too.
    return _selectNonRetirementAlternative(profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Chiffre choc builders
  // ═══════════════════════════════════════════════════════════════════════════

  static PremierEclairage _buildLiquidityChoc(MinimalProfileResult profile) {
    return PremierEclairage(
      type: PremierEclairageType.liquidityAlert,
      value: '${profile.liquidityMonths.toStringAsFixed(1)} mois',
      rawValue: profile.liquidityMonths,
      title: 'Ta reserve de liquidite',
      subtitle: profile.liquidityMonths < 1
          ? 'Moins d\'un mois de reserves. '
              'Les experts recommandent 3 a 6 mois de depenses en epargne de sécurité.' // lint-ignore: legacy selector has no l10n boundary
          : '${profile.liquidityMonths.toStringAsFixed(1)} mois de reserves. '
              'Les experts recommandent 3 a 6 mois de depenses en epargne de sécurité.', // lint-ignore: legacy selector has no l10n boundary
      iconName: 'warning_amber',
      colorKey: 'error',
    );
  }

  static PremierEclairage _buildTaxSaving3aChoc(MinimalProfileResult profile) {
    final savingFormatted = chf.formatChfWithPrefix(profile.taxSaving3a);
    final plafondText =
        profile.plafond3a != null ? chf.formatChf(profile.plafond3a!) : '?';
    return PremierEclairage(
      type: PremierEclairageType.taxSaving3a,
      value: '$savingFormatted/an',
      rawValue: profile.taxSaving3a,
      title: 'Ton economie d\'impot potentielle',
      subtitle: 'En cotisant au 3e pilier (max CHF\u00A0$plafondText/an), '
          'tu pourrais economiser environ $savingFormatted d\'impots chaque annee. '
          'Et tu prepares ta retraite en meme temps.',
      iconName: 'savings',
      colorKey: 'success',
    );
  }

  /// Compound growth advantage for young users.
  ///
  /// Pure math: compares starting now vs starting at 35.
  /// Always [PremierEclairageConfidence.factual] — no estimation involved.
  static PremierEclairage _buildCompoundGrowthChoc(
      MinimalProfileResult profile) {
    final years = 65 - profile.age;
    const monthlyContrib = 200.0;
    const annualRate = 0.03;
    const monthlyRate = annualRate / 12;
    final totalMonths = years * 12;

    // Future value of annuity: PMT × ((1 + r)^n - 1) / r
    final futureValue = monthlyContrib *
        ((pow(1 + monthlyRate, totalMonths) - 1) / monthlyRate);

    // Compare to starting at 35
    const referenceAge = 35;
    const yearsAt35 = 65 - referenceAge;
    const monthsAt35 = yearsAt35 * 12;
    final futureAt35 =
        monthlyContrib * ((pow(1 + monthlyRate, monthsAt35) - 1) / monthlyRate);

    final advantage = futureValue - futureAt35;
    final advantageFormatted = chf.formatChfWithPrefix(advantage);

    return PremierEclairage(
      type: PremierEclairageType.compoundGrowth,
      value: advantageFormatted,
      rawValue: advantage,
      title: 'Ton avantage temps',
      subtitle: '200 CHF/mois des maintenant = $advantageFormatted de plus '
          'a 65\u00A0ans qu\'en commencant a 35. '
          'Le temps est ton plus grand atout.',
      iconName: 'trending_up',
      colorKey: 'success',
      confidenceMode: PremierEclairageConfidence.factual, // Pure math
    );
  }

  /// Net hourly rate breakdown.
  ///
  /// Pure math from provided salary — always factual.
  /// Shows what the user really earns per hour, making abstract salary concrete.
  static PremierEclairage _buildHourlyRateChoc(MinimalProfileResult profile) {
    // Swiss standard: 42h/week × 52 weeks = 2'184h, minus 5 weeks vacation
    // → ~1'974 working hours/year. Simplified: 174h/month × 12 = 2'088h.
    const workingHoursPerYear = 2088.0;
    // Approximate net = 75% of gross (social charges + taxes)
    final netAnnual = profile.grossAnnualSalary * 0.75;
    final hourlyNet = netAnnual / workingHoursPerYear;
    final hourlyFormatted = 'CHF\u00A0${hourlyNet.round()}';

    // Housing cost in hours
    final monthlyExpenses = profile.estimatedMonthlyExpenses;
    // Estimate rent ~30% of expenses for budget-focused insight
    final rentEstimate = monthlyExpenses * 0.30;
    final rentHours = (rentEstimate / (hourlyNet)).round();

    return PremierEclairage(
      type: PremierEclairageType.hourlyRate,
      value: '$hourlyFormatted/h',
      rawValue: hourlyNet,
      title: 'Ton salaire reel',
      subtitle: 'Apres charges sociales et impots, tu gagnes environ '
          '$hourlyFormatted de l\'heure. '
          'Ton loyer te coute ~$rentHours heures de travail par mois.',
      iconName: 'schedule',
      colorKey: 'info',
      confidenceMode:
          PremierEclairageConfidence.factual, // Derived from provided salary
    );
  }

  static PremierEclairage _selectNonRetirementAlternative(
    MinimalProfileResult profile,
  ) {
    if (profile.existing3a <= 0 && profile.taxSaving3a > 500) {
      return _buildTaxSaving3aChoc(profile);
    }
    if (profile.age < 35) return _buildCompoundGrowthChoc(profile);
    if (profile.grossMonthlySalary > 0) return _buildHourlyRateChoc(profile);
    return _buildCompoundGrowthChoc(profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Confidence gating
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply confidence mode based on whether key data for this choc is estimated.
  ///
  /// Rules:
  /// - [compoundGrowth] and [hourlyRate] are always factual (pure math)
  /// - [liquidityAlert] is pedagogical if currentSavings is estimated
  /// - [taxSaving3a] is factual (derived from salary + canton, both provided)
  /// Retirement enum cases remain exhaustive for the wire model but are not
  /// produced by this selector while reviewed AVS provenance is unavailable.
  static PremierEclairage _withConfidence(
    PremierEclairage choc,
    MinimalProfileResult profile,
  ) {
    // Already set explicitly (e.g. compoundGrowth, hourlyRate)
    if (choc.confidenceMode != PremierEclairageConfidence.factual) return choc;

    final estimated = profile.estimatedFields;
    final PremierEclairageConfidence mode;

    switch (choc.type) {
      case PremierEclairageType.compoundGrowth:
      case PremierEclairageType.hourlyRate:
      case PremierEclairageType.taxSaving3a:
        mode = PremierEclairageConfidence.factual;
      case PremierEclairageType.liquidityAlert:
        mode = estimated.contains('currentSavings')
            ? PremierEclairageConfidence.pedagogical
            : PremierEclairageConfidence.factual;
      case PremierEclairageType.retirementGap:
      case PremierEclairageType.retirementIncome:
        mode = estimated.contains('existingLpp')
            ? PremierEclairageConfidence.pedagogical
            : PremierEclairageConfidence.factual;
    }

    if (mode == choc.confidenceMode) return choc;

    return PremierEclairage(
      type: choc.type,
      value: choc.value,
      rawValue: choc.rawValue,
      title: choc.title,
      subtitle: choc.subtitle,
      iconName: choc.iconName,
      colorKey: choc.colorKey,
      confidenceMode: mode,
    );
  }

  // F3: _formatChf / _formatChfPlain removed — use centralized chf_formatter.dart
}
