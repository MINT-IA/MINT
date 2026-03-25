import 'dart:math' show max;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ALL tax calculations MUST use RetirementTaxCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateTax() or similar methods.

/// Decomposition du revenu net — remplace * 0.87.
///
/// Two levels of "net":
/// - [netPayslip] = brut - charges sociales - LPP employe (what arrives on the payslip)
/// - [disposableIncome] = netPayslip - impot sur le revenu (what's left to live on)
///
/// ZERO hardcoded values. All constants come from:
/// - social_insurance.dart (cotisationsSalarieTotal, getLppBonificationRate, lppDeductionCoordination)
/// - fiscal_service.dart (estimateTax)
class NetIncomeBreakdown {
  final double grossSalary;
  final double socialCharges;
  final double lppEmployee;
  final double incomeTaxEstimate;
  final String canton;
  final int age;

  const NetIncomeBreakdown({
    required this.grossSalary,
    required this.socialCharges,
    required this.lppEmployee,
    required this.incomeTaxEstimate,
    required this.canton,
    required this.age,
  });

  /// Salaire net (fiche de paie) = brut - charges sociales - LPP employe.
  double get netPayslip => grossSalary - socialCharges - lppEmployee;

  /// Revenu disponible = net fiche de paie - impot sur le revenu.
  double get disposableIncome => netPayslip - incomeTaxEstimate;

  /// Ratio net/brut (replaces 0.87).
  double get netRatio => grossSalary > 0 ? netPayslip / grossSalary : 0;

  /// Ratio disponible/brut.
  double get disposableRatio =>
      grossSalary > 0 ? disposableIncome / grossSalary : 0;

  /// Monthly net payslip (convenience for the many monthly callers).
  double get monthlyNetPayslip => netPayslip / 12;

  /// Factory: compute dynamically from gross, canton, age.
  ///
  /// Formulas:
  /// - socialCharges = brut * cotisationsSalarieTotal (6.4%)
  /// - salaireCoord = clamp(brut - lppDeductionCoordination, lppSalaireCoordMin, lppSalaireCoordMax)
  /// - lppEmployee = salaireCoord * getLppBonificationRate(age) / 2
  ///   (LPP art. 66: employeur paie min 50%, employe ~50%)
  /// - incomeTax = FiscalService.estimateTax(brut, canton).chargeTotale
  factory NetIncomeBreakdown.compute({
    required double grossSalary,
    required String canton,
    required int age,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    if (grossSalary <= 0) {
      return NetIncomeBreakdown(
        grossSalary: 0,
        socialCharges: 0,
        lppEmployee: 0,
        incomeTaxEstimate: 0,
        canton: canton,
        age: age,
      );
    }

    // 1. Charges sociales (AVS/AI/APG combined + AC) — hors LPP
    final socialCharges = grossSalary * cotisationsSalarieTotal;

    // 2. LPP employe (~50% de la bonification totale sur salaire coordonne)
    double lppEmployee = 0;
    if (grossSalary >= lppSeuilEntree && age >= 25 && age <= avsAgeReferenceHomme) {
      final salaireCoord = (grossSalary - lppDeductionCoordination)
          .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      final totalBonif = getLppBonificationRate(age);
      lppEmployee =
          salaireCoord * totalBonif / 2; // ~50% part employe (LPP art. 66)
    }

    // 3. Impot sur le revenu (via FiscalService, 26 cantons)
    final taxResult = FiscalService.estimateTax(
      revenuBrut: grossSalary,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );
    final incomeTax = (taxResult['chargeTotale'] as double?) ?? 0;

    return NetIncomeBreakdown(
      grossSalary: grossSalary,
      socialCharges: socialCharges,
      lppEmployee: lppEmployee,
      incomeTaxEstimate: incomeTax,
      canton: canton,
      age: age,
    );
  }

  /// Estimate brut from net payslip using Newton-Raphson iteration.
  ///
  /// Iterates over [NetIncomeBreakdown.compute] to find the gross salary
  /// that produces the target net payslip. Converges in 3-5 iterations
  /// to within ±1 CHF accuracy.
  ///
  /// Much more accurate than the old linear approximation because it
  /// correctly accounts for the LPP coordination deduction (26'460 CHF)
  /// and the coordinated salary clamp (3'780–64'260 CHF).
  static double estimateBrutFromNet(
    double netAnnual, {
    int age = 45,
    String canton = 'ZH',
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
    int maxIterations = 10,
    double tolerance = 1.0,
  }) {
    if (netAnnual <= 0) return 0;

    // Initial guess using linear approximation
    final lppRate = getLppBonificationRate(age);
    final approxDeductionRate = cotisationsSalarieTotal + lppRate / 2;
    double guess = netAnnual / max(0.5, 1 - approxDeductionRate);

    for (int i = 0; i < maxIterations; i++) {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: guess,
        canton: canton,
        age: age,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      );
      final error = breakdown.netPayslip - netAnnual;
      if (error.abs() < tolerance) break;

      // Numerical derivative: d(netPayslip)/d(gross) ≈ Δnet/Δgross
      const delta = 100.0;
      final breakdownPlus = NetIncomeBreakdown.compute(
        grossSalary: guess + delta,
        canton: canton,
        age: age,
        etatCivil: etatCivil,
        nombreEnfants: nombreEnfants,
      );
      final derivative =
          (breakdownPlus.netPayslip - breakdown.netPayslip) / delta;
      if (derivative.abs() < 0.01) break; // Safeguard against division by ~0

      guess -= error / derivative;
      if (guess < 0) guess = netAnnual; // Reset if diverged
    }

    return guess;
  }

  Map<String, dynamic> toJson() => {
        'grossSalary': grossSalary,
        'socialCharges': socialCharges,
        'lppEmployee': lppEmployee,
        'incomeTaxEstimate': incomeTaxEstimate,
        'netPayslip': netPayslip,
        'disposableIncome': disposableIncome,
        'netRatio': netRatio,
        'canton': canton,
        'age': age,
      };
}

/// Retirement tax calculator — pure static functions.
///
/// Legal basis: LIFD art. 22 (rente taxation), LIFD art. 38 (capital withdrawal).
/// All computations are deterministic and stateless.
class RetirementTaxCalculator {
  RetirementTaxCalculator._();

  /// Disclaimer: LPP rente is taxable income (LIFD art. 22).
  ///
  /// Capital withdrawal is taxed separately at withdrawal (LIFD art. 38).
  /// SWR drawdown from withdrawn capital is consumption of own patrimony —
  /// NOT taxable income. Never double-tax capital.
  static const String renteLppTaxDisclaimer =
      'La rente LPP est imposee comme revenu (LIFD art. 22). '
      'Consulte un·e specialiste fiscal·e pour une estimation personnalisee.';

  /// Progressive capital withdrawal tax (LIFD art. 38).
  ///
  /// Brackets: 0-100k (1.0×), 100k-200k (1.15×), 200k-500k (1.30×),
  /// 500k-1M (1.50×), 1M+ (1.70×).
  /// Married couples get ~15% discount per cantonal splitting rules.
  static double capitalWithdrawalTax({
    required double capitalBrut,
    required String canton,
    bool isMarried = false,
  }) {
    if (capitalBrut <= 0) return 0;
    final cantonCode = canton.isNotEmpty ? canton.toUpperCase() : 'ZH';
    final baseRate = tauxImpotRetraitCapital[cantonCode] ?? 0.065;
    final effectiveRate =
        isMarried ? baseRate * marriedCapitalTaxDiscount : baseRate;
    return progressiveTax(capitalBrut, effectiveRate);
  }

  /// Progressive tax on a given amount (LIFD art. 38).
  ///
  /// Brackets: 0-100k (1.0×), 100k-200k (1.15×), 200k-500k (1.30×),
  /// 500k-1M (1.50×), 1M+ (1.70×).
  static double progressiveTax(double montant, double baseRate) {
    if (montant <= 0) return 0.0;
    const brackets = [
      [0, 100000, 1.0],
      [100000, 200000, 1.15],
      [200000, 500000, 1.30],
      [500000, 1000000, 1.50],
    ];
    const lastMultiplier = 1.70;

    double totalTax = 0;
    double remaining = montant;
    for (final bracket in brackets) {
      final tranche = bracket[1] - bracket[0];
      final taxable = remaining < tranche ? remaining : tranche;
      if (taxable <= 0) break;
      totalTax += taxable * baseRate * bracket[2];
      remaining -= taxable;
    }
    if (remaining > 0) {
      totalTax += remaining * baseRate * lastMultiplier;
    }
    return totalTax;
  }

  /// Effective tax rates by canton (single, 100k income, chef-lieu).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Mirrors: services/backend/app/services/fiscal/cantonal_comparator.py
  static const Map<String, double> _effectiveRates100k = {
    'ZG': 0.0823, 'NW': 0.0891, 'OW': 0.0934, 'AI': 0.0956,
    'AR': 0.1012, 'SZ': 0.1034, 'UR': 0.1067, 'LU': 0.1089,
    'GL': 0.1102, 'TG': 0.1145, 'SH': 0.1167, 'AG': 0.1189,
    'GR': 0.1203, 'BL': 0.1256, 'SG': 0.1278, 'ZH': 0.1290,
    'FR': 0.1312, 'SO': 0.1334, 'TI': 0.1356, 'BE': 0.1389,
    'NE': 0.1423, 'VS': 0.1456, 'VD': 0.1489, 'JU': 0.1512,
    'GE': 0.1545, 'BS': 0.1578,
  };

  /// Income level adjustment factors (relative to 100k baseline).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Mirrors: services/backend/app/services/fiscal/cantonal_comparator.py
  static const Map<int, double> _incomeAdjustment = {
    50000: 0.75, 80000: 0.90, 100000: 1.00,
    150000: 1.10, 200000: 1.18, 300000: 1.25, 500000: 1.32,
  };

  /// Family situation adjustment (splitting + deductions).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Mirrors: services/backend/app/services/fiscal/cantonal_comparator.py
  static const Map<String, double> _familyAdjustment = {
    'celibataire': 1.00,
    'marie_sans_enfant': 0.85,
    'marie_1_enfant': 0.78,
    'marie_2_enfants': 0.72,
    'marie_3_enfants': 0.66,
  };

  /// Marginal tax rate by canton, income, and family situation.
  ///
  /// Uses real AFC 2024 cantonal effective rates with income-level
  /// interpolation and family adjustment. Converts effective rate to
  /// marginal rate via ×1.3 factor (marginal > effective for progressive
  /// tax systems).
  ///
  /// Source: AFC — Charge fiscale en Suisse 2024.
  /// Used for chiffre-choc estimates — NOT for precise tax returns.
  static double estimateMarginalRate(
    double revenuBrutAnnuel,
    String canton, {
    bool isMarried = false,
    int children = 0,
  }) {
    final cantonCode = canton.toUpperCase();

    // Base rate from real cantonal data (fallback = Swiss average ~13%)
    final baseRate = _effectiveRates100k[cantonCode] ?? 0.13;

    // Income adjustment via linear interpolation
    final incomeAdj = _interpolateIncomeAdjustment(revenuBrutAnnuel);

    // Family adjustment
    String familyKey;
    if (!isMarried) {
      familyKey = 'celibataire';
    } else if (children >= 3) {
      familyKey = 'marie_3_enfants';
    } else if (children == 2) {
      familyKey = 'marie_2_enfants';
    } else if (children == 1) {
      familyKey = 'marie_1_enfant';
    } else {
      familyKey = 'marie_sans_enfant';
    }
    final familyAdj = _familyAdjustment[familyKey] ?? 1.0;

    // Marginal rate ~ effective rate × 1.3 (marginal > effective for
    // progressive taxes). This factor converts the effective rate into
    // a marginal rate approximation suitable for deduction impact.
    final effectiveRate = baseRate * incomeAdj * familyAdj;
    final marginalRate = effectiveRate * 1.3;

    return marginalRate.clamp(0.05, 0.45);
  }

  /// Linear interpolation between income adjustment brackets.
  ///
  /// Clamps to boundary values for incomes below 50k or above 500k.
  static double _interpolateIncomeAdjustment(double income) {
    final sortedKeys = _incomeAdjustment.keys.toList()..sort();

    if (income <= sortedKeys.first) return _incomeAdjustment[sortedKeys.first]!;
    if (income >= sortedKeys.last) return _incomeAdjustment[sortedKeys.last]!;

    // Find the two bracket bounds and interpolate
    for (int i = 0; i < sortedKeys.length - 1; i++) {
      final lower = sortedKeys[i];
      final upper = sortedKeys[i + 1];
      if (income >= lower && income <= upper) {
        final ratio = (income - lower) / (upper - lower);
        final lowerAdj = _incomeAdjustment[lower]!;
        final upperAdj = _incomeAdjustment[upper]!;
        return lowerAdj + (upperAdj - lowerAdj) * ratio;
      }
    }
    return 1.0; // fallback
  }

  /// Estimate tax saving from a deduction using numerical integration
  /// over canton-aware marginal rates.
  ///
  /// Slices the deduction into 10 steps and sums marginal tax saved at each
  /// income level. Used by buyback simulators to estimate fiscal benefit.
  static double estimateTaxSaving({
    required double income,
    required double deduction,
    required String canton,
    bool isMarried = false,
    int children = 0,
    int steps = 10,
  }) {
    if (deduction <= 0) return 0.0;

    final double stepSize = deduction / steps;
    double currentIncome = income;
    double totallySaved = 0.0;

    for (int i = 0; i < steps; i++) {
      final double midPoint = currentIncome - (stepSize / 2);
      final double rate = estimateMarginalRate(
        midPoint,
        canton,
        isMarried: isMarried,
        children: children,
      );
      totallySaved += stepSize * rate;
      currentIncome -= stepSize;
    }

    return totallySaved;
  }

  /// Estimate retirement income tax (annual → monthly).
  ///
  /// CRITICAL: revenuAnnuelImposable must EXCLUDE capital SWR withdrawals.
  /// Capital is already taxed at withdrawal (LIFD art. 38).
  /// SWR drawdown is consumption of own patrimony — NOT taxable income.
  static double estimateMonthlyIncomeTax({
    required double revenuAnnuelImposable,
    required String canton,
    String etatCivil = 'celibataire',
    int nombreEnfants = 0,
  }) {
    if (revenuAnnuelImposable <= 0) return 0;
    final result = FiscalService.estimateTax(
      revenuBrut: revenuAnnuelImposable,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );
    return ((result['chargeTotale'] as double?) ?? 0) / 12;
  }
}
