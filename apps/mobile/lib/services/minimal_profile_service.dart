import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

/// Minimal profile computation service (Sprint S31 — Onboarding Redesign).
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

    // Estimate LPP balance from age-weighted bonifications since age 25
    // Independent without LPP declaration → 0 balance
    final effectiveLpp = existingLpp
        ?? (isIndependantNoLpp ? 0.0 : _estimateLppBalance(age, grossSalary));
    if (existingLpp == null) estimatedFields.add('existingLpp');

    final effectiveRetAge = targetRetirementAge ?? 65;

    // --- AVS monthly rente (financial_core) ---
    // Sans emploi: use minimum AVS contribution salary
    final avsGrossSalary = isSansEmploi
        ? lppSeuilEntree.toDouble() // minimum contribution base
        : grossSalary;
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: effectiveRetAge,
      grossAnnualSalary: avsGrossSalary,
    );

    // --- LPP projection (financial_core) ---
    double lppAnnualRente;
    if (isIndependantNoLpp || isSansEmploi) {
      // No LPP for independants without caisse or unemployed
      lppAnnualRente = 0.0;
    } else {
      // Caisse complémentaire uses a blended conversion rate (~5.8%)
      // vs standard minimum 6.8% (LPP art. 14 al. 2).
      final effectiveConversionRate = lppCaisseType == 'complementaire'
          ? 0.058
          : lppTauxConversionMin / 100;
      lppAnnualRente = LppCalculator.projectToRetirement(
        currentBalance: effectiveLpp,
        currentAge: age,
        retirementAge: effectiveRetAge,
        grossAnnualSalary: grossSalary,
        caisseReturn: lppTauxInteretMin / 100,
        conversionRate: effectiveConversionRate,
      );
    }
    final lppMonthly = lppAnnualRente / 12;

    // --- Debt service impact (anti-double-counting: subtract from income, not expenses) ---
    final effectiveDebtService = monthlyDebtService
        ?? (totalDebts != null ? totalDebts * 0.005 : 0.0);

    // --- Total retirement income (clamped >= 0, aligned with backend) ---
    final totalMonthlyRetirement = max(0.0, avsMonthly + lppMonthly - effectiveDebtService);
    final grossMonthlySalary = grossSalary / 12;
    final replacementRate =
        grossMonthlySalary > 0 ? totalMonthlyRetirement / grossMonthlySalary : 0.0;
    final retirementGapMonthly = max(0.0, grossMonthlySalary - totalMonthlyRetirement);

    // --- Tax saving 3a (financial_core via FiscalService for marginal rate) ---
    // Indépendant sans LPP: plafond 3a = 20% du revenu net, max 36'288 CHF (OPP3 art. 7)
    // Salarié avec LPP: plafond 3a = 7'258 CHF
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(grossSalary, canton);
    final plafond3a = isIndependantNoLpp
        ? min(grossSalary * 0.20, pilier3aPlafondSansLpp)
        : pilier3aPlafondAvecLpp;
    final taxSaving3a = marginalRate * plafond3a;

    // --- Liquidity analysis ---
    final estimatedMonthlyExpenses = _estimateMonthlyExpenses(
      grossSalary,
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
      canton: canton,
      age: age,
      grossAnnualSalary: grossSalary,
      householdType: effectiveHousehold,
      isPropertyOwner: effectivePropertyOwner,
      existing3a: effective3a,
      existingLpp: effectiveLpp,
      employmentStatus: effectiveEmployment,
      nationalityGroup: nationalityGroup ?? 'CH',
      plafond3a: plafond3a,
      estimatedFields: estimatedFields,
    );
  }

  /// Estimate LPP balance from age and salary using cumulative bonifications.
  ///
  /// Applies LPP art. 16 age-dependent bonification rates since age 25.
  /// Returns 0 if below LPP seuil d'entree (LPP art. 7).
  static double _estimateLppBalance(int age, double grossAnnualSalary) {
    if (grossAnnualSalary < lppSeuilEntree) return 0.0;

    final salaireCoord = (grossAnnualSalary - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    double balance = 0;
    for (int a = 25; a < age && a < 65; a++) {
      balance *= (1 + lppTauxInteretMin / 100);
      balance += salaireCoord * getLppBonificationRate(a);
    }
    return balance;
  }

  /// Estimate monthly expenses from gross salary and household type.
  ///
  /// Uses typical Swiss expense ratios:
  /// - Housing: 25-30% of net income
  /// - Insurance (LAMal + other): 8-12%
  /// - Living expenses: 30-40%
  static double _estimateMonthlyExpenses(
    double grossAnnualSalary,
    String householdType,
    bool isPropertyOwner,
  ) {
    // Expense base ≈ 75% of gross — intentionally different from NetIncomeBreakdown
    // (which computes actual net payslip and requires canton + age).
    // Here 0.75 approximates disposable spending capacity as a quick proxy
    // for the minimal profile context where canton may not be reliable yet.
    // Swiss average: social charges ~6.4%, LPP ~5-9%, taxes ~10-15% → net ~70-78%.
    // 0.75 is a reasonable median. For canton-aware precision, use
    // NetIncomeBreakdown.compute() when canton and age are confirmed.
    final netMonthly = grossAnnualSalary * 0.75 / 12;

    // Expense ratio depends on household type
    final expenseRatio = switch (householdType) {
      'single' => 0.80,
      'couple' => 0.75,
      'family' => 0.85,
      _ => 0.80,
    };

    return netMonthly * expenseRatio;
  }
}
