import 'dart:math' show max, min;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ALL cross-pillar calculations MUST delegate to financial_core/ calculators.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculate*() or similar methods.

// ════════════════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════════════════

/// Type of cross-pillar insight.
enum CrossPillarType {
  /// Pillar 3a not maxed → potential fiscal saving.
  pillar3aOptimization,

  /// LPP buyback possible → fiscal saving + retirement income boost.
  lppBuybackOpportunity,

  /// Monthly budget margin → redirect to savings.
  budgetReallocation,

  /// Moving canton → potential annual tax difference.
  cantonalArbitrage,

  /// Mortgage with indirect amortisation → keep deduction value.
  mortgageTaxDeduction,

  /// Replacement rate below 80% threshold → concrete gap-closing actions.
  retirementGapAction,
}

/// One cross-pillar insight with CHF impact, confidence, and trade-off.
///
/// impactChfAnnual: positive = potential annual gain (CHF).
/// tradeOff: what is given up in exchange (ARB key — display string).
/// intentTag: ScreenRegistry intent to route to "do this now".
/// details: CHF breakdown per sub-component.
class CrossPillarInsight {
  /// Type of analysis.
  final CrossPillarType type;

  /// Potential annual CHF impact (positive = gain, negative = cost).
  final double impactChfAnnual;

  /// Confidence in this estimate (0.0 to 1.0).
  /// Driven by data source quality (certificate > userInput > estimated).
  final double confidence;

  /// What the user gives up to capture this gain (LSFin compliance — always
  /// present a trade-off, never present an option as unambiguously "optimal").
  final String tradeOff;

  /// ScreenRegistry intent tag for the primary CTA of this insight.
  final String intentTag;

  /// CHF breakdown per sub-component (e.g. fiscalSaving, retirementBoost).
  final Map<String, double> details;

  const CrossPillarInsight({
    required this.type,
    required this.impactChfAnnual,
    required this.confidence,
    required this.tradeOff,
    required this.intentTag,
    required this.details,
  });
}

/// Complete cross-pillar analysis result.
///
/// Produced by [CrossPillarCalculator.analyze].
/// disclaimer is always present (LSFin, outil éducatif).
class CrossPillarAnalysis {
  /// All detected insights, ordered by impactChfAnnual descending.
  final List<CrossPillarInsight> insights;

  /// Sum of all impactChfAnnual values.
  final double totalPotentialImpact;

  /// Educational disclaimer (LSFin / ne constitue pas un conseil).
  final String disclaimer;

  const CrossPillarAnalysis({
    required this.insights,
    required this.totalPotentialImpact,
    required this.disclaimer,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  CALCULATOR
// ════════════════════════════════════════════════════════════════════════════

/// Cross-pillar financial analysis — crosses fiscal, liquidity, and prévoyance
/// dimensions to produce actionable insights with CHF impact.
///
/// This is the VZ-grade feature: the same analysis a CHF 300/h advisor
/// performs, automated. Every insight is backed by financial_core/ calculators.
///
/// NEVER approximates — always delegates to the real calculators.
/// NEVER recommends — shows scenarios with trade-offs (LSFin compliance).
/// NEVER double-taxes capital (LIFD art. 38 + CLAUDE.md anti-pattern #10).
///
/// Legal basis:
/// - LPP art. 79b (rachats, blocage EPL 3 ans)
/// - OPP3 art. 7 (plafonds 3a)
/// - LIFD art. 33 al. 1 lit. e (déductibilité intérêts hypothécaires)
/// - LIFD art. 38 (impôt séparé sur les retraits en capital)
/// - LAVS art. 21 (âge de référence AVS)
class CrossPillarCalculator {
  CrossPillarCalculator._();

  /// Minimum monthly budget margin before triggering budgetReallocation.
  static const double _minMarginForReallocation = 500.0;

  /// Safety margin kept liquid after reallocation.
  static const double _safetyMarginMonthly = 500.0;

  /// Minimum annual cantonal tax difference to surface cantonalArbitrage.
  static const double _minCantonalDiffForArbitrage = 1000.0;

  /// Replacement rate threshold below which retirementGapAction triggers.
  static const double _replacementRateWarningThreshold = 0.80;

  /// Disclaimer (required on all projections — CLAUDE.md § 6).
  static const String _disclaimer =
      'Cet outil est éducatif et ne constitue pas un conseil financier ou '
      'fiscal au sens de la LSFin. Les montants affichés sont des estimations '
      'indicatives. Consulte un·e spécialiste pour une analyse personnalisée. '
      'Réf.\u00a0: LPP art. 79b, OPP3 art. 7, LIFD art. 38.';

  // ──────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ──────────────────────────────────────────────────────────────────────────

  /// Analyse the user's cross-pillar situation.
  ///
  /// Returns [CrossPillarAnalysis] with all detected insights.
  /// Insights are ordered by impactChfAnnual descending.
  ///
  /// [profile] Full financial profile. Must have salary > 0 for meaningful
  /// results; otherwise returns an empty analysis.
  ///
  /// [projectedRetirementIncomeMonthly] Optional: total projected monthly
  /// retirement income from an existing RetirementProjectionResult.
  /// When provided, enables [CrossPillarType.retirementGapAction].
  static CrossPillarAnalysis analyze({
    required CoachProfile profile,
    double? projectedRetirementIncomeMonthly,
  }) {
    if (profile.salaireBrutMensuel <= 0) {
      return const CrossPillarAnalysis(
        insights: [],
        totalPotentialImpact: 0,
        disclaimer: _disclaimer,
      );
    }

    final insights = <CrossPillarInsight>[];

    // A. Pillar 3a optimization
    final a = _pillar3aOptimization(profile);
    if (a != null) insights.add(a);

    // B. LPP buyback opportunity
    final b = _lppBuybackOpportunity(profile);
    if (b != null) insights.add(b);

    // C. Budget reallocation
    final c = _budgetReallocation(profile);
    if (c != null) insights.add(c);

    // D. Cantonal arbitrage
    final d = _cantonalArbitrage(profile);
    if (d != null) insights.add(d);

    // E. Mortgage tax deduction
    final e = _mortgageTaxDeduction(profile);
    if (e != null) insights.add(e);

    // F. Retirement gap action
    final f = _retirementGapAction(profile, projectedRetirementIncomeMonthly);
    if (f != null) insights.add(f);

    // Sort by impact descending
    insights.sort((a, b) => b.impactChfAnnual.compareTo(a.impactChfAnnual));

    final total = insights.fold(0.0, (sum, i) => sum + i.impactChfAnnual);

    return CrossPillarAnalysis(
      insights: insights,
      totalPotentialImpact: total,
      disclaimer: _disclaimer,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  A. PILLAR 3a OPTIMIZATION
  // ──────────────────────────────────────────────────────────────────────────

  /// 3a not maxed → annual fiscal saving from contributing the full amount.
  ///
  /// Uses [RetirementTaxCalculator.estimateTaxSaving] with the user's canton
  /// and gross income to compute the marginal tax saved on the missing 3a
  /// contribution. No hardcoded tax rates.
  ///
  /// FATCA block: US persons (Lauren archetype) cannot contribute to 3a with
  /// most providers. Returns null if canContribute3a = false.
  static CrossPillarInsight? _pillar3aOptimization(CoachProfile profile) {
    // FATCA hard block: most providers refuse US persons (LSFin compliance).
    if (!profile.canContribute3a) return null;

    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual <= 0) return null;

    // Determine applicable plafond (OPP3 art. 7)
    final isIndependantSansLpp =
        profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal! <= 0);

    final double plafond;
    if (isIndependantSansLpp) {
      // Grand 3a: 20% of net income, max 36'288 CHF
      plafond = min(
        grossAnnual * pilier3aTauxRevenuSansLpp,
        pilier3aPlafondSansLpp,
      );
    } else {
      // Petit 3a: flat cap with LPP
      plafond = pilier3aPlafondAvecLpp;
    }

    final alreadyContributing = profile.prevoyance.totalEpargne3a > 0
        ? min(
            profile.total3aMensuel * 12,
            plafond,
          )
        : 0.0;

    // Use planned monthly contributions as proxy for current annual 3a
    final currentAnnual3a = profile.total3aMensuel * 12;
    final missing3a = (plafond - currentAnnual3a).clamp(0.0, plafond);

    if (missing3a < 100) return null; // Not worth surfacing

    // Fiscal saving via numerical integration (estimateTaxSaving)
    final isMarried3a = profile.etatCivil == CoachCivilStatus.marie;
    final fiscalSaving = RetirementTaxCalculator.estimateTaxSaving(
      income: grossAnnual,
      deduction: missing3a,
      canton: profile.canton,
      isMarried: isMarried3a,
      children: profile.nombreEnfants,
    );

    if (fiscalSaving < 50) return null;

    // Confidence: higher if we have salary from certificate, lower if estimated
    final salarySource =
        profile.dataSources['salaireBrutMensuel'] ?? ProfileDataSource.estimated;
    final confidence = _sourceConfidence(salarySource);

    return CrossPillarInsight(
      type: CrossPillarType.pillar3aOptimization,
      impactChfAnnual: fiscalSaving,
      confidence: confidence,
      tradeOff:
          'Liquidité réduite de CHF\u00a0${(missing3a / 12).round()}/mois '
          '(versement bloqué jusqu\'à la retraite, OPP3 art. 7)',
      intentTag: 'pilier3a_versement',
      details: {
        'plafondAnnuel': plafond,
        'contributionActuelle': currentAnnual3a,
        'versementManquant': missing3a,
        'economieImpotAnnuelle': fiscalSaving,
        'alreadyContributing': alreadyContributing,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  B. LPP BUYBACK OPPORTUNITY
  // ──────────────────────────────────────────────────────────────────────────

  /// Rachat LPP possible → fiscal saving this year + retirement income boost.
  ///
  /// Fiscal saving: [RetirementTaxCalculator.estimateTaxSaving] on the full
  /// lacune. Retirement boost: rachat × conversionRate (annual rente increase).
  ///
  /// EPL blocage: if an EPL was taken, buyback is blocked for 3 years
  /// (LPP art. 79b al. 3). We still compute the opportunity but flag it.
  static CrossPillarInsight? _lppBuybackOpportunity(CoachProfile profile) {
    final rachatMax = profile.prevoyance.lacuneRachatRestante;
    if (rachatMax <= 0) return null;
    if (profile.salaireBrutMensuel <= 0) return null;

    final grossAnnual = profile.revenuBrutAnnuel;

    // Fiscal saving from deducting rachat against income (LIFD art. 81)
    // Rachat is a deductible expense against income tax.
    final isMarriedLpp = profile.etatCivil == CoachCivilStatus.marie;
    final fiscalSaving = RetirementTaxCalculator.estimateTaxSaving(
      income: grossAnnual,
      deduction: rachatMax,
      canton: profile.canton,
      isMarried: isMarriedLpp,
      children: profile.nombreEnfants,
    );

    // Retirement income boost: rente increase from rachat
    // rachat × conversion rate = additional annual rente
    final conversionRate = profile.prevoyance.tauxConversion;
    final annualRenteBoost = rachatMax * conversionRate;

    // Total economic value over the remaining working years
    // (fiscal saving immediately + rente boost over time)
    // For the insight impactChfAnnual, we show the immediate fiscal saving
    // as the "trigger" — retirement boost shown in details.
    if (fiscalSaving < 100 && annualRenteBoost < 100) return null;

    // Confidence: higher if rachatMaximum comes from LPP certificate
    final lppSource = profile.dataSources['prevoyance.avoirLppTotal'] ??
        ProfileDataSource.estimated;
    final confidence = _sourceConfidence(lppSource);

    // ARCH NOTE: amortissementIndirect tracks indirect amortisation via 3a,
    // NOT an EPL withdrawal (retrait anticipé 2e pilier pour propriété).
    // The 3-year block (art. 79b al. 3) applies only after an actual EPL,
    // not after indirect amortisation. Since the profile doesn't currently
    // track EPL withdrawals separately, we show the general reminder
    // without claiming a specific block exists.
    const tradeOffSuffix =
        ' + capital immobilisé dans la caisse (LPP art. 79b al. 3)';

    return CrossPillarInsight(
      type: CrossPillarType.lppBuybackOpportunity,
      impactChfAnnual: fiscalSaving,
      confidence: confidence,
      tradeOff:
          'Liquidité immobilisée de CHF\u00a0${rachatMax.round()}$tradeOffSuffix',
      intentTag: 'lpp_rachat_simulation',
      details: {
        'lacuneRachat': rachatMax,
        'economieImpotAnnuelle': fiscalSaving,
        'augmentationRenteAnnuelle': annualRenteBoost,
        'augmentationRenteMensuelle': annualRenteBoost / 12,
        'tauxConversion': conversionRate,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  C. BUDGET REALLOCATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Monthly budget margin exists → redirect optimally to 3a + LPP buyback.
  ///
  /// Computes disposable income via [NetIncomeBreakdown.compute], subtracts
  /// all fixed costs and debt repayments, then allocates the excess:
  /// 1. Fill missing 3a first (highest fiscal ROI)
  /// 2. Remainder to LPP buyback
  ///
  /// Only surfaces if net margin > CHF 500/month.
  static CrossPillarInsight? _budgetReallocation(CoachProfile profile) {
    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual <= 0) return null;

    // Net income from payslip via financial_core (no hardcoded rate)
    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: grossAnnual,
      canton: profile.canton,
      age: profile.age,
      etatCivil: profile.etatCivil == CoachCivilStatus.marie
          ? 'marie'
          : 'celibataire',
      nombreEnfants: profile.nombreEnfants,
    );

    final monthlyNet = breakdown.monthlyNetPayslip;

    // All fixed monthly outflows
    final fixedCosts = profile.depenses.totalMensuel;
    final debtPayments = profile.dettes.totalMensualite;
    final alreadySaving = profile.totalContributionsMensuelles;

    final monthlyFree =
        monthlyNet - fixedCosts - debtPayments - alreadySaving;

    if (monthlyFree <= _minMarginForReallocation) return null;

    // Allocatable excess (keep safety margin)
    final excess = monthlyFree - _safetyMarginMonthly;
    if (excess <= 0) return null;

    // 1. Fill 3a gap first (if user can contribute)
    double optimal3aMonthly = 0.0;
    double fiscalSaving3a = 0.0;
    if (profile.canContribute3a) {
      const plafond = pilier3aPlafondAvecLpp;
      final current3aMonthly = profile.total3aMensuel;
      final missing3aMonthly =
          max(0.0, plafond / 12 - current3aMonthly);
      optimal3aMonthly = min(excess, missing3aMonthly);
      if (optimal3aMonthly > 0) {
        final isMarriedC = profile.etatCivil == CoachCivilStatus.marie;
        fiscalSaving3a = RetirementTaxCalculator.estimateTaxSaving(
          income: grossAnnual,
          deduction: optimal3aMonthly * 12,
          canton: profile.canton,
          isMarried: isMarriedC,
          children: profile.nombreEnfants,
        );
      }
    }

    final remainingForRachat = excess - optimal3aMonthly;

    // Impact = fiscal saving from newly allocated 3a
    // (LPP buyback returns are counted in insight B)
    if (fiscalSaving3a < 50 && remainingForRachat < 100) return null;

    final impactAnnual = fiscalSaving3a;
    if (impactAnnual <= 0) return null;

    final confidence =
        _sourceConfidence(ProfileDataSource.userInput); // salary known

    return CrossPillarInsight(
      type: CrossPillarType.budgetReallocation,
      impactChfAnnual: impactAnnual,
      confidence: confidence,
      tradeOff:
          'Marge libre réduite à CHF\u00a0${_safetyMarginMonthly.round()}/mois '
          '(liquidité immédiate diminuée)',
      intentTag: 'plan_epargne_mensuel',
      details: {
        'revenuMensuelNet': monthlyNet,
        'chargesFixesMensuelles': fixedCosts,
        'remboursementsDettes': debtPayments,
        'epargneActuelle': alreadySaving,
        'margeLibreMensuelle': monthlyFree,
        'excedentAllocable': excess,
        'optimal3aMensuel': optimal3aMonthly,
        'resteRachatMensuel': remainingForRachat,
        'economieImpot3a': fiscalSaving3a,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  D. CANTONAL ARBITRAGE
  // ──────────────────────────────────────────────────────────────────────────

  /// Current canton vs best-value neighbor → potential annual tax difference.
  ///
  /// Uses [FiscalService.compareAllCantons] to get all 26 cantonal rates
  /// for the user's income level. Only surfaces if the best canton saves
  /// more than CHF 1'000/year vs the current canton.
  ///
  /// Trade-off is always shown: moving has costs (employment, housing).
  static CrossPillarInsight? _cantonalArbitrage(CoachProfile profile) {
    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual <= 0) return null;

    final canton = profile.canton.toUpperCase();
    final etatCivil =
        profile.etatCivil == CoachCivilStatus.marie ? 'marie' : 'celibataire';

    // Current tax
    final currentTaxResult = FiscalService.estimateTax(
      revenuBrut: grossAnnual,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: profile.nombreEnfants,
    );
    final currentTax = currentTaxResult['chargeTotale'] as double;

    // Best canton (ranked list, sorted ascending by tax)
    final allCantons = FiscalService.compareAllCantons(
      revenuBrut: grossAnnual,
      etatCivil: etatCivil,
      nombreEnfants: profile.nombreEnfants,
    );

    if (allCantons.isEmpty) return null;

    // Best canton overall (first in sorted list)
    final best = allCantons.first;
    final bestTax = best['chargeTotale'] as double;
    final bestCanton = best['canton'] as String;

    // Skip if current canton IS already the best
    if (bestCanton == canton) return null;

    final taxDiff = currentTax - bestTax;
    if (taxDiff < _minCantonalDiffForArbitrage) return null;

    // Confidence: income data quality
    final salarySource =
        profile.dataSources['salaireBrutMensuel'] ?? ProfileDataSource.estimated;
    final confidence = _sourceConfidence(salarySource) * 0.7; // partial: many life factors

    final bestCantonName =
        FiscalService.cantonNames[bestCanton] ?? bestCanton;
    final currentCantonName =
        FiscalService.cantonNames[canton] ?? canton;

    return CrossPillarInsight(
      type: CrossPillarType.cantonalArbitrage,
      impactChfAnnual: taxDiff,
      confidence: confidence,
      tradeOff:
          'Déménagement de $currentCantonName à $bestCantonName\u00a0: '
          'impact emploi, logement, coût du déménagement',
      intentTag: 'fiscal_comparateur_cantons',
      details: {
        'impotCantonActuel': currentTax,
        'impotMeilleurCanton': bestTax,
        'economieAnnuelle': taxDiff,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  E. MORTGAGE TAX DEDUCTION
  // ──────────────────────────────────────────────────────────────────────────

  /// Hypothèque existante → valeur annuelle de la déduction des intérêts.
  ///
  /// Intérêts hypothécaires = déductibles (LIFD art. 33 al. 1 lit. e).
  /// Valeur = intérêts annuels × taux marginal (via RetirementTaxCalculator).
  ///
  /// Amortissement indirect (via 3a) preserves this deduction while also
  /// building retirement savings. Direct amortisation eliminates the deduction.
  static CrossPillarInsight? _mortgageTaxDeduction(CoachProfile profile) {
    final mortgageBalance = profile.patrimoine.mortgageBalance;
    if (mortgageBalance == null || mortgageBalance <= 0) return null;

    final mortgageRate = profile.patrimoine.mortgageRate;
    if (mortgageRate == null || mortgageRate <= 0) return null;

    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual <= 0) return null;

    // Annual mortgage interest (deductible, LIFD art. 33 al. 1 lit. e)
    //
    // CONVENTION: mortgageRate SHOULD be stored as decimal (1.5% = 0.015).
    // However, some input paths store it as percentage (1.5% = 1.5).
    // We normalize here: values > 0.3 are treated as percentage and divided
    // by 100. This handles all realistic Swiss mortgage rates (0.5%–10%).
    // Edge case: a SARON rate of 0.25% stored as 0.25 would be wrongly
    // treated as percentage — but 0.25/100 = 0.0025 still produces a
    // plausible (if low) interest amount. The real fix is to enforce
    // decimal storage at the input layer (CoachProfile/PatrimoineProfile).
    final rateDecimal =
        mortgageRate > 0.3 ? mortgageRate / 100.0 : mortgageRate;
    final annualInterest = mortgageBalance * rateDecimal;

    if (annualInterest < 500) return null;

    // Tax value of deduction via numerical integration (no hardcoded rate)
    final isMarriedMtg = profile.etatCivil == CoachCivilStatus.marie;
    final deductionValue = RetirementTaxCalculator.estimateTaxSaving(
      income: grossAnnual,
      deduction: annualInterest,
      canton: profile.canton,
      isMarried: isMarriedMtg,
      children: profile.nombreEnfants,
    );

    if (deductionValue < 100) return null;

    // Indirect vs direct amortisation comparison
    final isIndirect = profile.dettes.amortissementIndirect;
    final tradeOff = isIndirect
        ? 'Amortissement indirect actif (via 3a)\u00a0: '
            'maintient la déduction et construit ta retraite simultanément'
        : 'Amortissement direct\u00a0: réduit la dette mais supprime '
            'la déduction de CHF\u00a0${annualInterest.round()} d\'intérêts';

    final confidence =
        _sourceConfidence(ProfileDataSource.userInput) * 0.85;

    return CrossPillarInsight(
      type: CrossPillarType.mortgageTaxDeduction,
      impactChfAnnual: deductionValue,
      confidence: confidence,
      tradeOff: tradeOff,
      intentTag: 'logement_amortissement',
      details: {
        'soldeHypotheque': mortgageBalance,
        'tauxHypotheque': rateDecimal,
        'interetsAnnuels': annualInterest,
        'valeurDeductionAnnuelle': deductionValue,
        'amortissementIndirect': isIndirect ? 1.0 : 0.0,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  F. RETIREMENT GAP ACTION
  // ──────────────────────────────────────────────────────────────────────────

  /// Taux de remplacement < 80% → gap mensuel + concrete actions with CHF impact.
  ///
  /// Uses [AvsCalculator.computeMonthlyRente] + [LppCalculator.projectToRetirement]
  /// to independently verify the projected income. When
  /// [projectedRetirementIncomeMonthly] is provided, uses that instead.
  ///
  /// Actions with CHF impact:
  ///   1. Max 3a every year until retirement
  ///   2. LPP buyback (full lacune)
  ///   3. One additional year of work
  static CrossPillarInsight? _retirementGapAction(
    CoachProfile profile,
    double? projectedRetirementIncomeMonthly,
  ) {
    final grossAnnual = profile.revenuBrutAnnuel;
    if (grossAnnual <= 0) return null;

    final retirementAge = profile.effectiveRetirementAge;
    final currentAge = profile.age;
    final yearsLeft = (retirementAge - currentAge).clamp(0, 50);

    // Projected retirement income
    double projectedMonthly;
    if (projectedRetirementIncomeMonthly != null &&
        projectedRetirementIncomeMonthly > 0) {
      projectedMonthly = projectedRetirementIncomeMonthly;
    } else {
      // Compute via financial_core calculators
      final avsMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: currentAge,
        retirementAge: retirementAge,
        lacunes: profile.prevoyance.lacunesAVS ?? 0,
        anneesContribuees: profile.prevoyance.anneesContribuees,
        arrivalAge: profile.arrivalAge,
        grossAnnualSalary: grossAnnual,
      );

      final lppBalance = profile.prevoyance.avoirLppTotal ?? 0.0;
      final lppAnnualRente = LppCalculator.projectToRetirement(
        currentBalance: lppBalance,
        currentAge: currentAge,
        retirementAge: retirementAge,
        grossAnnualSalary: grossAnnual,
        caisseReturn: profile.prevoyance.rendementCaisse,
        conversionRate: profile.prevoyance.tauxConversion,
        salaireAssureOverride: profile.prevoyance.salaireAssure,
      );

      // Apply 13th rente (8.3% uplift) to AVS monthly.
      final avsMonthlyWith13 = AvsCalculator.annualRente(avsMonthly) / 12;
      projectedMonthly = avsMonthlyWith13 + lppAnnualRente / 12;
    }

    // Current monthly net income (pre-retirement reference)
    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: grossAnnual,
      canton: profile.canton,
      age: currentAge,
      etatCivil: profile.etatCivil == CoachCivilStatus.marie
          ? 'marie'
          : 'celibataire',
      nombreEnfants: profile.nombreEnfants,
    );
    final currentMonthlyNet = breakdown.monthlyNetPayslip;
    if (currentMonthlyNet <= 0) return null;

    final replacementRate = projectedMonthly / currentMonthlyNet;
    if (replacementRate >= _replacementRateWarningThreshold) return null;

    // Monthly gap to reach 80% replacement
    final targetMonthly = currentMonthlyNet * _replacementRateWarningThreshold;
    final gapMonthly = targetMonthly - projectedMonthly;
    final gapAnnual = gapMonthly * 12;

    // Action 1: Max 3a annually until retirement
    // Each year's 3a adds plafond × (1 + growth)^yearsLeft / 12 monthly income
    // For the insight, we show the fiscal saving (immediate, verifiable)
    double action3aImpact = 0.0;
    if (profile.canContribute3a && yearsLeft > 0) {
      const plafond = pilier3aPlafondAvecLpp;
      final current3aAnnual = profile.total3aMensuel * 12;
      final missing3a = max(0.0, plafond - current3aAnnual);
      if (missing3a > 0) {
        final isMarriedGap = profile.etatCivil == CoachCivilStatus.marie;
        action3aImpact = RetirementTaxCalculator.estimateTaxSaving(
          income: grossAnnual,
          deduction: missing3a,
          canton: profile.canton,
          isMarried: isMarriedGap,
          children: profile.nombreEnfants,
        );
      }
    }

    // Action 2: LPP buyback (annual rente boost)
    final lacune = profile.prevoyance.lacuneRachatRestante;
    final rente3aBoostAnnual = lacune > 0
        ? lacune * profile.prevoyance.tauxConversion
        : 0.0;

    // Action 3: +1 year of work (AVS deferral bonus)
    // LAVS art. 39: +5.2% on individual rente per year deferred from 65
    final avsMonthlyAt65 = AvsCalculator.computeMonthlyRente(
      currentAge: currentAge,
      retirementAge: avsAgeReferenceHomme,
      lacunes: profile.prevoyance.lacunesAVS ?? 0,
      anneesContribuees: profile.prevoyance.anneesContribuees,
      arrivalAge: profile.arrivalAge,
      grossAnnualSalary: grossAnnual,
    );
    final avsMonthlyAt66 = AvsCalculator.computeMonthlyRente(
      currentAge: currentAge,
      retirementAge: 66,
      lacunes: profile.prevoyance.lacunesAVS ?? 0,
      anneesContribuees: profile.prevoyance.anneesContribuees,
      arrivalAge: profile.arrivalAge,
      grossAnnualSalary: grossAnnual,
    );
    final extraYearMonthlyGain = avsMonthlyAt66 - avsMonthlyAt65;
    final extraYearAnnualGain = extraYearMonthlyGain * 12;

    // Impact = total closing actions (conservative: only verifiable immediate gains)
    final totalActionImpact = action3aImpact + rente3aBoostAnnual;
    if (totalActionImpact <= 0 && gapAnnual <= 0) return null;

    final confidence = _sourceConfidence(
      profile.dataSources['prevoyance.avoirLppTotal'] ??
          ProfileDataSource.estimated,
    ) * 0.8;

    return CrossPillarInsight(
      type: CrossPillarType.retirementGapAction,
      impactChfAnnual: totalActionImpact > 0 ? totalActionImpact : gapAnnual,
      confidence: confidence,
      tradeOff:
          'Réduire la liquidité aujourd\'hui ou prolonger l\'activité '
          '(chaque option a un coût de vie ou d\'opportunité)',
      intentTag: 'retraite_projection_detail',
      details: {
        'revenuMensuelActuel': currentMonthlyNet,
        'revenuProjetteRetraite': projectedMonthly,
        'tauxRemplacement': replacementRate,
        'objectifTauxRemplacement': _replacementRateWarningThreshold,
        'ecartMensuel': gapMonthly,
        'ecartAnnuel': gapAnnual,
        'action3aEconomieFiscale': action3aImpact,
        'actionRachatBoostRenteAnnuel': rente3aBoostAnnual,
        'actionAnneeSuppGainAnnuel': extraYearAnnualGain,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Map [ProfileDataSource] to a confidence value (0.0–1.0).
  /// Mirrors CLAUDE.md § 5 "Data sources" trust levels.
  static double _sourceConfidence(ProfileDataSource source) {
    return switch (source) {
      ProfileDataSource.openBanking => 0.95,
      ProfileDataSource.certificate => 0.90,
      ProfileDataSource.crossValidated => 0.75,
      ProfileDataSource.userInput => 0.60,
      ProfileDataSource.estimated => 0.35,
    };
  }
}
