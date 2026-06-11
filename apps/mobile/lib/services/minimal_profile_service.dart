import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

/// Minimal profile computation service (Sprint S31 — Onboarding Redesign).
///
/// ARCHITECTURE: Local computation engine for onboarding.
/// Used as fallback when backend API is unavailable.
/// The backend MinimalProfileService is the authoritative source.
/// Constants are synced via reg() from RegulatoryRegistry.
///
/// Computes a financial snapshot from as few as 3 inputs (age, salary, canton).
/// All calculations delegate to [financial_core] — NEVER duplicates formulas.
///
/// Legal basis: LAVS art. 21-40, LPP art. 7-16, OPP3 art. 7, LIFD art. 38.
class MinimalProfileService {
  MinimalProfileService._();

  /// Compute a minimal financial profile from basic inputs.
  ///
  /// Required: [age], [grossSalary] (annual), [canton].
  /// Optional fields are estimated when not provided and tracked in
  /// [MinimalProfileResult.estimatedFields].
  static MinimalProfileResult compute({
    required int age,
    required double grossSalary,
    required String canton,
    String? employmentStatus,
    String? nationalityGroup,
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
    int? targetRetirementAge,
    String? lppCaisseType,
    double? totalDebts,
    double? monthlyDebtService,
    /// Gender: 'M', 'F', or null. Passed to AvsCalculator for AVS21
    /// reference age (LAVS art. 21 al. 1). Null defaults to male (65).
    String? gender,
    /// Birth year — used with [gender] for AVS21 transitional cohorts.
    int? birthYear,
    /// Age d'arrivée en Suisse (si expat). Plumbé jusqu'à l'estimation LPP
    /// pour démarrer l'accumulation à l'arrivée, pas toujours à 25 (LPP art. 7).
    int? arrivalAge,
  }) {
    final estimatedFields = <String>[];

    // --- Apply defaults with estimation tracking ---
    final effectiveHousehold = householdType ?? 'single';
    if (householdType == null) estimatedFields.add('householdType');

    final effectivePropertyOwner = isPropertyOwner ?? false;
    if (isPropertyOwner == null) estimatedFields.add('isPropertyOwner');

    // Estimate savings: (age - 25) * gross * 5% (conservative assumption)
    final effectiveSavings =
        currentSavings ?? max(0.0, (age - 25) * grossSalary * 0.05);
    if (currentSavings == null) estimatedFields.add('currentSavings');

    final effective3a = existing3a ?? 0.0;
    if (existing3a == null) estimatedFields.add('existing3a');

    // --- Employment status impact ---
    // Independant sans LPP: LPP = 0, 3a max = 36'288 CHF (OPP3 art. 7)
    // Sans emploi: reduced AVS, no LPP contributions
    final effectiveEmployment = employmentStatus ?? 'salarie';
    final isIndependantNoLpp = effectiveEmployment == 'independant';
    final isSansEmploi = effectiveEmployment == 'sans_emploi';

    // Estimate LPP balance from age-weighted bonifications since arrival/25.
    // Independent without LPP declaration → 0 balance
    final effectiveLpp = existingLpp
        ?? (isIndependantNoLpp
            ? 0.0
            : _estimateLppBalance(age, grossSalary, arrivalAge: arrivalAge));
    if (existingLpp == null) estimatedFields.add('existingLpp');

    // F7-2: Use gender-aware retirement age when gender + birth year are provided.
    // Falls back to male reference age (65) when gender is unknown.
    final effectiveBirthYear = birthYear ?? (DateTime.now().year - age);
    final effectiveRetAge = targetRetirementAge
        ?? (gender != null
            ? avsReferenceAge(birthYear: effectiveBirthYear, isFemale: gender == 'F')
            : avsAgeReferenceHomme);

    // --- AVS monthly rente (financial_core) ---
    // Sans emploi: use minimum AVS contribution salary
    final avsGrossSalary = isSansEmploi
        ? reg('lpp.entry_threshold', lppSeuilEntree) // minimum contribution base
        : grossSalary;
    // F7-2: Pass gender and birthYear when available so AvsCalculator
    // uses AVS21 reference age (64F / 65M — LAVS art. 21 al. 1).
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: effectiveRetAge,
      grossAnnualSalary: avsGrossSalary,
      isFemale: gender != null ? gender == 'F' : null,
      birthYear: gender != null ? effectiveBirthYear : null,
    );

    // --- LPP projection (financial_core) ---
    double lppAnnualRente;
    if (isIndependantNoLpp || isSansEmploi) {
      // No LPP for independants without caisse or unemployed
      lppAnnualRente = 0.0;
    } else {
      // Caisse complémentaire uses a blended conversion rate (~5.8%)
      // vs standard minimum 6.8% (LPP art. 14 al. 2). Les deux branches
      // utilisent les constantes nommées du registry — plus de littéral inline.
      final effectiveConversionRate = lppCaisseType == 'complementaire'
          ? reg('lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal)
          : reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal);
      lppAnnualRente = LppCalculator.projectToRetirement(
        currentBalance: effectiveLpp,
        currentAge: age,
        retirementAge: effectiveRetAge,
        grossAnnualSalary: grossSalary,
        caisseReturn: reg('lpp.min_interest_rate', lppTauxInteretMin) / 100,
        conversionRate: effectiveConversionRate,
      );
    }
    final lppMonthly = lppAnnualRente / 12;

    // --- Debt service impact (donnée budget, surfacée pour l'affichage) ---
    // Le service de la dette est une donnée *budget*, PAS un revenu de retraite.
    // Il n'est plus soustrait du revenu de retraite total (composition canonique
    // = AVS + LPP, alignée sur response_card et retirement_projection_service).
    // Voir financial_core/replacement_rate.dart + matrice D3.
    final effectiveDebtService = monthlyDebtService
        ?? (totalDebts != null ? totalDebts * 0.005 : 0.0);

    // --- Total retirement income (composition canonique : AVS + LPP) ---
    final totalMonthlyRetirement = max(0.0, avsMonthly + lppMonthly);
    final grossMonthlySalary = grossSalary / 12;
    // --- Taux de remplacement : dénominateur NET courant (lock CONTEXT W1) ---
    // Source canonique unique ReplacementRate (financial_core L1) : dénominateur
    // = revenu NET via NetIncomeBreakdown (canton + âge aware), plus le brut.
    // Champ conservé en fraction (0-1) pour les consommateurs historiques.
    final netMonthlyIncome = NetIncomeBreakdown.compute(
      grossSalary: grossSalary,
      canton: canton.isNotEmpty ? canton : 'ZH',
      age: age,
    ).monthlyNetPayslip;
    final replacementRate = ReplacementRate.fraction(
      totalMonthlyRetirement: totalMonthlyRetirement,
      netMonthlyIncome: netMonthlyIncome,
    );
    final retirementGapMonthly = max(0.0, grossMonthlySalary - totalMonthlyRetirement);

    // --- Tax saving 3a (financial_core) ---
    final resolvedCanton = resolveCanton(canton);
    final taxImpact = resolvedCanton.isResolved && grossSalary > 0
        ? RetirementTaxCalculator.estimate3aTaxImpact(
            grossAnnualSalary: grossSalary,
            canton: resolvedCanton.code,
            hasLpp: !isIndependantNoLpp,
          )
        : Pillar3aTaxImpactEstimate.unavailable;
    final marginalRate =
        taxImpact.confidence == Pillar3aTaxImpactConfidence.unavailable
            ? 0.0
            : taxImpact.marginalRate;
    final plafond3a =
        taxImpact.confidence == Pillar3aTaxImpactConfidence.unavailable
            ? (isIndependantNoLpp
                ? min(grossSalary * 0.20,
                    reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp))
                : reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp))
            : taxImpact.annualCeiling;
    final taxSaving3a = taxImpact.estimatedTaxSaving;

    // --- Liquidity analysis (base nette canonique, plus de ratio plat) ---
    final estimatedMonthlyExpenses = _estimateMonthlyExpenses(
      netMonthlyIncome,
      effectiveHousehold,
      effectivePropertyOwner,
    );
    final liquidityMonths =
        estimatedMonthlyExpenses > 0 ? effectiveSavings / estimatedMonthlyExpenses : 0.0;

    return MinimalProfileResult(
      avsMonthlyRente: avsMonthly,
      lppAnnualRente: lppAnnualRente,
      lppMonthlyRente: lppMonthly,
      totalMonthlyRetirement: totalMonthlyRetirement,
      grossMonthlySalary: grossMonthlySalary,
      replacementRate: replacementRate,
      retirementGapMonthly: retirementGapMonthly,
      taxSaving3a: taxSaving3a,
      marginalTaxRate: marginalRate,
      currentSavings: effectiveSavings,
      estimatedMonthlyExpenses: estimatedMonthlyExpenses,
      monthlyDebtImpact: effectiveDebtService,
      liquidityMonths: liquidityMonths,
      canton: resolvedCanton.isResolved ? resolvedCanton.code : canton,
      age: age,
      grossAnnualSalary: grossSalary,
      householdType: effectiveHousehold,
      isPropertyOwner: effectivePropertyOwner,
      existing3a: effective3a,
      existingLpp: effectiveLpp,
      employmentStatus: employmentStatus ?? effectiveEmployment,
      nationalityGroup: nationalityGroup,
      plafond3a: plafond3a,
      estimatedFields: estimatedFields,
    );
  }

  /// Estimate LPP balance from age and salary using cumulative bonifications.
  ///
  /// Façade qui délègue à la source canonique [LppCalculator.accumulateAvoir]
  /// (financial_core L1) — CLAUDE.md NEVER #3 : pas de calcul dupliqué L1.
  /// [arrivalAge]: démarre l'accumulation à l'arrivée (LPP art. 7), pas
  /// toujours à 25, pour les profils arrivés tardivement en Suisse.
  static double _estimateLppBalance(int age, double grossAnnualSalary,
      {int? arrivalAge}) {
    return LppCalculator.accumulateAvoir(
      currentAge: age,
      grossAnnualSalary: grossAnnualSalary,
      startAge: arrivalAge,
    );
  }

  /// Estimate monthly expenses from canonical NET income and household type.
  ///
  /// Uses typical Swiss expense ratios applied to the canonical monthly NET
  /// ([NetIncomeBreakdown.compute], canton + âge aware) — plus de ratio plat
  /// 0.75 comme proxy de net (base nette unique app-wide, matrice §2 « Marge
  /// libre »). Seuls les ratios de *dépense* par type de ménage restent ici.
  static double _estimateMonthlyExpenses(
    double monthlyNet,
    String householdType,
    bool isPropertyOwner,
  ) {
    // Expense ratio depends on household type (ratio de dépense, pas un proxy
    // de net) : housing 25-30% + LAMal 8-12% + vie courante 30-40%.
    final expenseRatio = switch (householdType) {
      'single' => 0.80,
      'couple' => 0.75,
      'family' => 0.85,
      _ => 0.80,
    };

    return monthlyNet * expenseRatio;
  }
}
