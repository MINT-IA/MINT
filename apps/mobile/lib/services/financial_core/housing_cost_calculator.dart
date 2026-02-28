import 'dart:math';

import 'package:mint_mobile/services/feature_flags.dart';

/// Housing cost calculator for retirement projections (P2).
///
/// Computes the net monthly housing cost at retirement based on housing
/// status, property value, mortgage balance, and rental costs.
///
/// This is the SINGLE SOURCE OF TRUTH for housing costs — consumed by both
/// RetirementProjectionService and MonteCarloService.
///
/// Legal basis:
///   - LIFD art. 21 al. 1 let. b (valeur locative)
///   - LIFD art. 32 (deductions entretien)
///   - CO art. 253ss (bail a loyer)
///
/// Note: les taux de valeur locative par canton sont des estimations
/// moyennes a titre educatif. La valeur locative reelle depend de
/// l'evaluation cadastrale cantonale (methode hedoniste, valeur venale,
/// ou valeur de rendement selon le canton).
class HousingCostCalculator {
  HousingCostCalculator._();

  /// Annual inflation rate for rent indexation.
  static const double _rentInflationRate = 0.015;

  /// Annual property maintenance as fraction of property value.
  static const double _maintenanceRate = 0.01;

  /// Annual PPE (charges de copropriete) as fraction of property value.
  static const double _ppeRate = 0.003;

  /// LTV threshold above which amortization is required (ASB/FINMA).
  static const double _ltvAmortizationThreshold = 0.65;

  /// Estimated valeur locative rates by canton (LIFD art. 21 al. 1 let. b).
  ///
  /// These are APPROXIMATE rates for educational purposes only.
  /// The actual valeur locative depends on cantonal assessment methods
  /// (cadastral value, hedonic, market value) which vary by canton.
  static const Map<String, double> _tauxValeurLocative = {
    'ZH': 0.035,
    'BE': 0.038,
    'VD': 0.040,
    'GE': 0.045,
    'LU': 0.033,
    'AG': 0.036,
    'SG': 0.034,
    'BS': 0.042,
    'TI': 0.037,
    'VS': 0.035,
    'FR': 0.038,
    'NE': 0.040,
    'JU': 0.039,
    'SO': 0.036,
    'BL': 0.037,
    'GR': 0.034,
    'TG': 0.033,
    'SZ': 0.030,
    'ZG': 0.028,
    'NW': 0.031,
    'OW': 0.032,
    'UR': 0.033,
    'SH': 0.035,
    'AR': 0.034,
    'AI': 0.032,
    'GL': 0.033,
  };

  /// Compute housing cost at retirement.
  ///
  /// Returns a [HousingCostResult] with the net monthly cost, fiscal impact,
  /// available equity, and assumptions used.
  ///
  /// Three cases:
  /// 1. **Renter**: rent indexed by inflation until retirement
  /// 2. **Owner with mortgage**: interest + amortization + PPE + valeur locative
  /// 3. **Owner without mortgage**: PPE + maintenance + valeur locative
  static HousingCostResult compute({
    required String housingStatus,
    required String canton,
    required int currentAge,
    required int targetRetirementAge,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    double? monthlyRent,
    double marginalTaxRate = 0.25,
  }) {
    final yearsToRetirement = max(0, targetRetirementAge - currentAge);
    final assumptions = <String>[];

    // ── Renter ──────────────────────────────────────────────────────────
    if (housingStatus == 'renter' || housingStatus == 'locataire') {
      final rent = monthlyRent ?? 0.0;
      // Index rent by inflation until retirement
      final indexedRent =
          rent * pow(1 + _rentInflationRate, yearsToRetirement);

      if (monthlyRent == null || monthlyRent == 0) {
        assumptions.add('Loyer non renseigne, estime a 0 CHF');
      }
      assumptions.add(
        'Loyer indexe a ${(_rentInflationRate * 100).toStringAsFixed(1)}%/an '
        'sur $yearsToRetirement ans',
      );

      return HousingCostResult(
        monthlyNetCost: indexedRent,
        fiscalImpact: 0.0,
        equityAvailable: 0.0,
        assumptions: assumptions,
      );
    }

    // ── Owner (with or without mortgage) ────────────────────────────────
    final propValue = propertyMarketValue ?? 0.0;
    final mortgage = mortgageBalance ?? 0.0;
    final rate = mortgageRate ?? 0.015; // default 1.5%

    if (propertyMarketValue == null || propertyMarketValue == 0) {
      assumptions.add('Valeur du bien non renseignee');
    }

    // Monthly mortgage interest (if any)
    final monthlyInterest = (mortgage * rate) / 12;

    // Monthly amortization: if LTV > 65%, amortize excess over
    // min(yearsToRetirement, 15) years (ASB/FINMA auto-regulation).
    double monthlyAmortization = 0;
    if (mortgage > propValue * _ltvAmortizationThreshold &&
        propValue > 0 &&
        yearsToRetirement > 0) {
      final excessMortgage = mortgage - propValue * _ltvAmortizationThreshold;
      final amortYears = min(yearsToRetirement, 15);
      monthlyAmortization = excessMortgage / (amortYears * 12);
      assumptions.add(
        'Amortissement 2e rang: CHF ${excessMortgage.toStringAsFixed(0)} '
        'sur $amortYears ans (LTV > 65%)',
      );
    }

    // Monthly PPE / entretien forfaitaire
    final monthlyMaintenance = (propValue * _maintenanceRate) / 12;
    final monthlyPpe = (propValue * _ppeRate) / 12;

    // ── Valeur locative (fiscal impact) ─────────────────────────────────
    double fiscalImpact = 0.0;

    if (!FeatureFlags.valeurLocative2028Reform) {
      // Current law: valeur locative is taxable income
      final tauxCanton =
          _tauxValeurLocative[canton.toUpperCase()] ?? 0.035;
      final valeurLocativeAnnuelle = propValue * tauxCanton;

      // Deductions: mortgage interest + maintenance (forfait 20% of VL
      // for property > 10 years, which is conservative default at retirement)
      final deductionEntretien = valeurLocativeAnnuelle * 0.20;
      final deductionInterets = mortgage * rate;
      final totalDeductions = deductionEntretien + deductionInterets;

      final netTaxableIncome = valeurLocativeAnnuelle - totalDeductions;
      // Fiscal impact = net taxable income * marginal tax rate / 12
      fiscalImpact = (netTaxableIncome * marginalTaxRate) / 12;

      assumptions.add(
        'Valeur locative estimee: ${(tauxCanton * 100).toStringAsFixed(1)}% '
        'de la valeur venale (LIFD art. 21, taux moyen cantonal)',
      );
    } else {
      // 2028 reform: valeur locative = 0, deductions = 0
      assumptions.add('Reforme 2028: valeur locative supprimee');
    }

    // ── Net monthly housing cost ────────────────────────────────────────
    // For owner: real cash outflows + amortization + fiscal impact
    final monthlyCost = monthlyInterest +
        monthlyAmortization +
        monthlyMaintenance +
        monthlyPpe +
        max(0, fiscalImpact);

    // Equity available (property value minus mortgage)
    final equity = max(0.0, propValue - mortgage);

    if (mortgage > 0) {
      assumptions.add(
        'Hypotheque CHF ${mortgage.toStringAsFixed(0)} '
        'a ${(rate * 100).toStringAsFixed(1)}%',
      );
    } else {
      assumptions.add('Proprietaire sans hypotheque');
    }

    return HousingCostResult(
      monthlyNetCost: monthlyCost,
      fiscalImpact: fiscalImpact,
      equityAvailable: equity,
      assumptions: assumptions,
    );
  }

  /// Compute the CURRENT monthly housing cost (not indexed, no retirement
  /// adjustments). Used to remove housing from base expenses before applying
  /// the retirement housing model.
  static double _currentHousingCost({
    required String housingStatus,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    double? monthlyRent,
  }) {
    if (housingStatus == 'renter' || housingStatus == 'locataire') {
      return monthlyRent ?? 0.0;
    }
    // Owner: interest + PPE + maintenance (same components, no indexation)
    final propValue = propertyMarketValue ?? 0.0;
    final mortgage = mortgageBalance ?? 0.0;
    final rate = mortgageRate ?? 0.015;
    final interest = (mortgage * rate) / 12;
    final maintenance = (propValue * _maintenanceRate) / 12;
    final ppe = (propValue * _ppeRate) / 12;
    return interest + maintenance + ppe;
  }

  /// Estimate retirement expenses with housing adjustment.
  ///
  /// This is the SINGLE SOURCE for retirement expense estimation.
  /// Both RetirementProjectionService and MonteCarloService MUST call this.
  ///
  /// Logic:
  /// 1. Compute base expenses (85% current or 75% net income fallback)
  /// 2. Subtract current housing cost from base (avoid double-counting)
  /// 3. Add retirement housing cost from [compute()]
  static double estimateRetirementExpenses({
    required double salaireBrutMensuel,
    required double conjointSalaireBrutMensuel,
    required double currentExpenses,
    String? housingStatus,
    String canton = 'ZH',
    int currentAge = 50,
    int targetRetirementAge = 65,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    double? monthlyRent,
    double marginalTaxRate = 0.25,
  }) {
    final householdNet = salaireBrutMensuel * 0.87 +
        conjointSalaireBrutMensuel * 0.87;
    // Income-based floor: 70% of household net
    final incomeFloor = householdNet * 0.70;

    double baseExpenses;
    if (currentExpenses > 0) {
      // 85% of current expenses (retirement rule), floored by income estimate
      baseExpenses = max(currentExpenses * 0.85, incomeFloor);
    } else {
      // No expense data: 75% of household net income
      baseExpenses = householdNet > 0 ? householdNet * 0.75 : 5000;
    }

    // Without housing data, return base estimate (backward compatible)
    if (housingStatus == null) {
      return baseExpenses;
    }

    // Compute housing cost at retirement
    final housingResult = compute(
      housingStatus: housingStatus,
      canton: canton,
      currentAge: currentAge,
      targetRetirementAge: targetRetirementAge,
      propertyMarketValue: propertyMarketValue,
      mortgageBalance: mortgageBalance,
      mortgageRate: mortgageRate,
      monthlyRent: monthlyRent,
      marginalTaxRate: marginalTaxRate,
    );

    // Compute current housing cost to subtract from base (anti-double-counting).
    // For renters: current rent. For owners: current interest + PPE + maintenance.
    // This removes the housing portion already embedded in depenses.totalMensuel.
    final currentHousingCost = _currentHousingCost(
      housingStatus: housingStatus,
      propertyMarketValue: propertyMarketValue,
      mortgageBalance: mortgageBalance,
      mortgageRate: mortgageRate,
      monthlyRent: monthlyRent,
    );

    // Adjust: remove current housing from base, add retirement housing
    final adjustedExpenses =
        baseExpenses - currentHousingCost + housingResult.monthlyNetCost;

    // Floor at income-based minimum
    return max(adjustedExpenses, incomeFloor);
  }
}

/// Result of housing cost computation at retirement.
class HousingCostResult {
  /// Net monthly housing cost at retirement (CHF).
  final double monthlyNetCost;

  /// Monthly fiscal impact from valeur locative (CHF, can be negative).
  final double fiscalImpact;

  /// Equity available in property (value - mortgage, CHF).
  final double equityAvailable;

  /// Assumptions used in the computation.
  final List<String> assumptions;

  const HousingCostResult({
    required this.monthlyNetCost,
    required this.fiscalImpact,
    required this.equityAvailable,
    required this.assumptions,
  });
}
