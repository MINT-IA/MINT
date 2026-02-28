import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

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
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
    int? targetRetirementAge,
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

    // Estimate LPP balance from age-weighted bonifications since age 25
    final effectiveLpp = existingLpp ?? _estimateLppBalance(age, grossSalary);
    if (existingLpp == null) estimatedFields.add('existingLpp');

    final effectiveRetAge = targetRetirementAge ?? 65;

    // --- AVS monthly rente (financial_core) ---
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: effectiveRetAge,
      grossAnnualSalary: grossSalary,
    );

    // --- LPP projection (financial_core) ---
    final lppAnnualRente = LppCalculator.projectToRetirement(
      currentBalance: effectiveLpp,
      currentAge: age,
      retirementAge: effectiveRetAge,
      grossAnnualSalary: grossSalary,
      caisseReturn: lppTauxInteretMin / 100,
      conversionRate: lppTauxConversionMin / 100,
    );
    final lppMonthly = lppAnnualRente / 12;

    // --- Total retirement income ---
    final totalMonthlyRetirement = avsMonthly + lppMonthly;
    final grossMonthlySalary = grossSalary / 12;
    final replacementRate =
        grossMonthlySalary > 0 ? totalMonthlyRetirement / grossMonthlySalary : 0.0;
    final retirementGapMonthly = max(0.0, grossMonthlySalary - totalMonthlyRetirement);

    // --- Tax saving 3a (financial_core via FiscalService for marginal rate) ---
    final marginalRate = _estimateMarginalRate(grossSalary, canton, effectiveHousehold);
    final taxSaving3a = marginalRate * pilier3aPlafondAvecLpp;

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
      liquidityMonths: liquidityMonths,
      canton: canton,
      age: age,
      grossAnnualSalary: grossSalary,
      householdType: effectiveHousehold,
      isPropertyOwner: effectivePropertyOwner,
      existing3a: effective3a,
      existingLpp: effectiveLpp,
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

  /// Estimate marginal tax rate using FiscalService.
  ///
  /// Computes effective rate at current income, then adds 1 CHF bracket
  /// to approximate the marginal rate.
  static double _estimateMarginalRate(
    double grossAnnualSalary,
    String canton,
    String householdType,
  ) {
    final etatCivil = (householdType == 'couple' || householdType == 'family')
        ? 'marie'
        : 'celibataire';
    final nombreEnfants = householdType == 'family' ? 1 : 0;

    final result = FiscalService.estimateTax(
      revenuBrut: grossAnnualSalary,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );

    final tauxEffectif = (result['tauxEffectif'] as double) / 100;

    // Marginal rate is typically 1.3-1.5x the effective rate in Swiss
    // progressive tax system. Use 1.4x as a reasonable approximation.
    return (tauxEffectif * 1.4).clamp(0.05, 0.45);
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
    // Approximate net income (~75% of gross for employee)
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
