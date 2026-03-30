import 'dart:math';

import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

/// Selects the most impactful "chiffre choc" to show the user.
///
/// Sprint S57 — ChiffreChoc V2: intention × lifecycle × confidence × available data.
///
/// Selection hierarchy:
/// 1. Critical archetype alerts (indep no LPP, expat low AVS)
/// 2. Stress-aligned selection (if stressType declared, data supports it)
/// 3. Universal priorities (liquidity crisis, retirement gap, tax saving)
///    — gated by lifecycle relevance and data confidence
/// 4. Lifecycle-aware fallback (age-driven, always valid)
///
/// Confidence gating:
/// - If the chiffre choc's key data is estimated → [ChiffreChocConfidence.pedagogical]
/// - If based on provided data or pure math → [ChiffreChocConfidence.factual]
///
/// Legal basis: LAVS art. 21-40, LPP art. 7-16, OPP3 art. 7, LIFD art. 38.
class ChiffreChocSelector {
  ChiffreChocSelector._();

  /// Select the most impactful chiffre choc for the given profile.
  ///
  /// [stressType] — user's declared intention from StepStressSelector.
  /// When set and not 'stress_general', influences which type of chiffre
  /// choc is selected (if the data supports it).
  static ChiffreChoc select(
    MinimalProfileResult profile, {
    String? stressType,
  }) {
    // Phase 0: Critical archetype alerts — always override
    final archetypeChoc = _selectByArchetype(profile);
    if (archetypeChoc != null) return _withConfidence(archetypeChoc, profile);

    // Phase 1: Stress-aligned selection (NEW)
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

    // Retirement gap: relevant from age 30+ (below that, it's too abstract)
    if (profile.age >= 30 &&
        profile.replacementRate < 0.55 &&
        profile.grossMonthlySalary > 0) {
      return _withConfidence(_buildRetirementGapChoc(profile), profile);
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

  /// Try to produce a chiffre choc aligned with the user's declared intention.
  ///
  /// Returns null if the data doesn't support a meaningful choc for this stress.
  static ChiffreChoc? _selectByStress(
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
        // Retirement: show gap or income depending on data quality
        if (profile.grossMonthlySalary > 0) {
          if (profile.replacementRate < 0.55) {
            return _buildRetirementGapChoc(profile);
          }
          return _buildRetirementIncomeChoc(profile);
        }
        return null;

      case 'stress_patrimoine':
        // Patrimoine: only if we have real data — don't estimate fortune
        // Without real patrimoine data, fall through to lifecycle
        return null;

      case 'stress_couple':
        // Couple: no couple data at onboarding — fall through
        return null;

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
  static ChiffreChoc _selectByLifecycle(MinimalProfileResult profile) {
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
    // 38+: retirement income/gap is relevant
    if (profile.replacementRate < 0.55 && profile.grossMonthlySalary > 0) {
      return _buildRetirementGapChoc(profile);
    }
    return _buildRetirementIncomeChoc(profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Archetype alerts (unchanged priority 0)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Archetype-specific chiffre choc (highest priority when applicable).
  static ChiffreChoc? _selectByArchetype(MinimalProfileResult profile) {
    // Independent without LPP: massive retirement gap alert
    if (profile.employmentStatus == 'independant' &&
        profile.lppMonthlyRente <= 0 &&
        profile.grossMonthlySalary > 0) {
      final gapFormatted = chf.formatChfWithPrefix(profile.retirementGapMonthly);
      final plafondStr = profile.plafond3a != null
          ? chf.formatChf(profile.plafond3a!)
          : '?';
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$gapFormatted/mois',
        rawValue: profile.retirementGapMonthly,
        title: 'Sans 2e pilier, ton gap de retraite',
        subtitle:
            'En tant qu\'independant\u00b7e sans LPP, seule l\'AVS te couvre. '
            'Il te manquerait $gapFormatted chaque mois a la retraite. '
            'Le 3e pilier (max CHF\u00A0$plafondStr/an) et '
            'une LPP facultative peuvent combler cet ecart.',
        iconName: 'warning_amber',
        colorKey: 'error',
      );
    }

    // Non-Swiss expat: AVS gap warning (only when nationality is known)
    if (profile.nationalityGroup != null &&
        profile.nationalityGroup != 'CH' &&
        profile.avsMonthlyRente < 1500) {
      final avsFormatted = chf.formatChfWithPrefix(profile.avsMonthlyRente);
      final subtitle = profile.nationalityGroup == 'EU'
          ? 'Tes annees de cotisation en Europe comptent aussi grace aux '
              'accords bilateraux. Avec $avsFormatted/mois d\'AVS estime, '
              'verifie ta rente avec ton releve de compte individuel (CI).'
          : 'Avec $avsFormatted/mois d\'AVS estime, ta rente pourrait etre '
              'reduite par des lacunes de cotisation. Demande ton releve CI '
              'a ta caisse de compensation.';
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$avsFormatted/mois',
        rawValue: profile.avsMonthlyRente,
        title: 'Ta rente AVS estimee',
        subtitle: subtitle,
        iconName: 'public',
        colorKey: 'warning',
      );
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Chiffre choc builders
  // ═══════════════════════════════════════════════════════════════════════════

  static ChiffreChoc _buildLiquidityChoc(MinimalProfileResult profile) {
    return ChiffreChoc(
      type: ChiffreChocType.liquidityAlert,
      value: '${profile.liquidityMonths.toStringAsFixed(1)} mois',
      rawValue: profile.liquidityMonths,
      title: 'Ta reserve de liquidite',
      subtitle: profile.liquidityMonths < 1
          ? 'Moins d\'un mois de reserves. '
              'Les experts recommandent 3 a 6 mois de depenses en epargne de securite.'
          : '${profile.liquidityMonths.toStringAsFixed(1)} mois de reserves. '
              'Les experts recommandent 3 a 6 mois de depenses en epargne de securite.',
      iconName: 'warning_amber',
      colorKey: 'error',
    );
  }

  static ChiffreChoc _buildRetirementGapChoc(MinimalProfileResult profile) {
    final gapFormatted = chf.formatChfWithPrefix(profile.retirementGapMonthly);
    final pct = (profile.replacementRate * 100).round();
    final isIndep = profile.employmentStatus == 'independant';
    final plafond = profile.plafond3a;
    final subtitle = isIndep && plafond != null
        ? 'Sans 2e pilier obligatoire, ton ecart de retraite est plus important. '
            'Avec seulement $pct% de remplacement, il te manquerait $gapFormatted/mois. '
            'Le 3e pilier (max CHF\u00A0${chf.formatChf(plafond)}/an) est ton principal levier.'
        : '\u00c0 la retraite, tu pourrais recevoir environ $pct% de ton revenu actuel. '
            'Il te manquerait $gapFormatted chaque mois. '
            'Decouvre comment reduire cet ecart.';
    return ChiffreChoc(
      type: ChiffreChocType.retirementGap,
      value: '$gapFormatted/mois',
      rawValue: profile.retirementGapMonthly,
      title: 'Ton ecart de retraite',
      subtitle: subtitle,
      iconName: 'trending_down',
      colorKey: 'warning',
    );
  }

  static ChiffreChoc _buildTaxSaving3aChoc(MinimalProfileResult profile) {
    final savingFormatted = chf.formatChfWithPrefix(profile.taxSaving3a);
    final plafondText = profile.plafond3a != null
        ? chf.formatChf(profile.plafond3a!)
        : '?';
    return ChiffreChoc(
      type: ChiffreChocType.taxSaving3a,
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

  static ChiffreChoc _buildRetirementIncomeChoc(MinimalProfileResult profile) {
    final retirementFormatted = chf.formatChfWithPrefix(profile.totalMonthlyRetirement);
    final pct = (profile.replacementRate * 100).round();
    return ChiffreChoc(
      type: ChiffreChocType.retirementIncome,
      value: '$retirementFormatted/mois',
      rawValue: profile.totalMonthlyRetirement,
      title: 'Ton revenu estime a la retraite',
      subtitle: 'Avec l\'AVS et la LPP, tu pourrais recevoir environ '
          '$retirementFormatted par mois, soit $pct% de ton salaire actuel.',
      iconName: 'account_balance',
      colorKey: 'info',
    );
  }

  /// Compound growth advantage for young users.
  ///
  /// Pure math: compares starting now vs starting at 35.
  /// Always [ChiffreChocConfidence.factual] — no estimation involved.
  static ChiffreChoc _buildCompoundGrowthChoc(MinimalProfileResult profile) {
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
    final futureAt35 = monthlyContrib *
        ((pow(1 + monthlyRate, monthsAt35) - 1) / monthlyRate);

    final advantage = futureValue - futureAt35;
    final advantageFormatted = chf.formatChfWithPrefix(advantage);

    return ChiffreChoc(
      type: ChiffreChocType.compoundGrowth,
      value: advantageFormatted,
      rawValue: advantage,
      title: 'Ton avantage temps',
      subtitle: '200 CHF/mois des maintenant = $advantageFormatted de plus '
          'a 65\u00A0ans qu\'en commencant a 35. '
          'Le temps est ton plus grand atout.',
      iconName: 'trending_up',
      colorKey: 'success',
      confidenceMode: ChiffreChocConfidence.factual, // Pure math
    );
  }

  /// Net hourly rate breakdown.
  ///
  /// Pure math from provided salary — always factual.
  /// Shows what the user really earns per hour, making abstract salary concrete.
  static ChiffreChoc _buildHourlyRateChoc(MinimalProfileResult profile) {
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

    return ChiffreChoc(
      type: ChiffreChocType.hourlyRate,
      value: '$hourlyFormatted/h',
      rawValue: hourlyNet,
      title: 'Ton salaire reel',
      subtitle: 'Apres charges sociales et impots, tu gagnes environ '
          '$hourlyFormatted de l\'heure. '
          'Ton loyer te coute ~$rentHours heures de travail par mois.',
      iconName: 'schedule',
      colorKey: 'info',
      confidenceMode: ChiffreChocConfidence.factual, // Derived from provided salary
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Confidence gating
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply confidence mode based on whether key data for this choc is estimated.
  ///
  /// Rules:
  /// - [compoundGrowth] and [hourlyRate] are always factual (pure math)
  /// - [liquidityAlert] is pedagogical if currentSavings is estimated
  /// - [retirementGap] / [retirementIncome] are pedagogical if LPP is estimated
  /// - [taxSaving3a] is factual (derived from salary + canton, both provided)
  static ChiffreChoc _withConfidence(
    ChiffreChoc choc,
    MinimalProfileResult profile,
  ) {
    // Already set explicitly (e.g. compoundGrowth, hourlyRate)
    if (choc.confidenceMode != ChiffreChocConfidence.factual) return choc;

    final estimated = profile.estimatedFields;
    final ChiffreChocConfidence mode;

    switch (choc.type) {
      case ChiffreChocType.compoundGrowth:
      case ChiffreChocType.hourlyRate:
      case ChiffreChocType.taxSaving3a:
        mode = ChiffreChocConfidence.factual;
      case ChiffreChocType.liquidityAlert:
        mode = estimated.contains('currentSavings')
            ? ChiffreChocConfidence.pedagogical
            : ChiffreChocConfidence.factual;
      case ChiffreChocType.retirementGap:
      case ChiffreChocType.retirementIncome:
        mode = estimated.contains('existingLpp')
            ? ChiffreChocConfidence.pedagogical
            : ChiffreChocConfidence.factual;
    }

    if (mode == choc.confidenceMode) return choc;

    return ChiffreChoc(
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
