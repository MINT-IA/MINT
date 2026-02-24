import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ALL LPP calculations MUST use LppCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateLpp() or similar methods.

/// LPP (2nd pillar) projection calculator — pure static functions.
///
/// Legal basis: LPP art. 7, 8, 14, 15, 16 / LIFD art. 38.
/// All computations are deterministic and stateless.
class LppCalculator {
  LppCalculator._();

  /// Safe withdrawal rate (Trinity Study, 4%).
  static const double safeWithdrawalRate = 0.04;

  /// Project LPP balance to retirement with bonifications.
  ///
  /// Returns the projected annual rente (balance × conversionRate).
  /// Bonifications by age (LPP art. 16): 7/10/15/18%.
  /// Below seuil entree (22'680): no bonifications, only return on existing capital.
  static double projectToRetirement({
    required double currentBalance,
    required int currentAge,
    required int retirementAge,
    required double grossAnnualSalary,
    required double caisseReturn,
    required double conversionRate,
    double monthlyBuyback = 0,
    double buybackCap = 0,
  }) {
    final belowThreshold = grossAnnualSalary < lppSeuilEntree;
    final salaireCoord = belowThreshold
        ? 0.0
        : (grossAnnualSalary - lppDeductionCoordination)
            .clamp(lppSalaireCoordMin, lppSalaireCoordMax);

    double balance = currentBalance;
    double buybackDone = 0;

    for (int a = currentAge; a < retirementAge && a < 70; a++) {
      balance *= (1 + caisseReturn);
      balance += salaireCoord * getLppBonificationRate(a);
      if (!belowThreshold && monthlyBuyback > 0 && buybackDone < buybackCap) {
        final yearly =
            (monthlyBuyback * 12).clamp(0, buybackCap - buybackDone);
        balance += yearly;
        buybackDone += yearly;
      }
    }

    return balance * conversionRate;
  }

  /// Single month LPP projection step (for ForecasterService monthly loop).
  ///
  /// Returns new balance after one month of return + bonification.
  /// Use this inside a monthly loop to get intermediate projection points.
  static double projectOneMonth({
    required double currentBalance,
    required int age,
    required double grossAnnualSalary,
    required double monthlyReturn,
  }) {
    double newBalance = currentBalance * (1 + monthlyReturn);
    if (grossAnnualSalary < lppSeuilEntree) return newBalance;
    final salaireCoord = (grossAnnualSalary - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    final bonifRate = getLppBonificationRate(age);
    return newBalance + salaireCoord * bonifRate / 12;
  }

  /// Compute monthly LPP income blending rente and capital withdrawal.
  ///
  /// [lppCapitalPct]: 0.0 = 100% rente, 0.5 = mixte, 1.0 = 100% capital.
  /// Capital portion: withdrawal tax (LIFD art. 38) + 4% SWR (Trinity Study).
  /// Married couples get ~15% capital tax discount per cantonal rules.
  static double blendedMonthly({
    required double annualRente,
    required double conversionRate,
    required double lppCapitalPct,
    required String canton,
    bool isMarried = false,
  }) {
    if (lppCapitalPct <= 0 || annualRente <= 0) return annualRente / 12;

    // Back-calculate projected balance from annual rente
    final effectiveRate = conversionRate > 0 ? conversionRate : 0.068;
    final projectedBalance = annualRente / effectiveRate;

    // Rente portion
    final renteMonthly = annualRente * (1 - lppCapitalPct) / 12;

    // Capital portion: progressive withdrawal tax + SWR
    final capitalBrut = projectedBalance * lppCapitalPct;
    final cantonCode = canton.isNotEmpty ? canton.toUpperCase() : 'ZH';
    final baseRate = tauxImpotRetraitCapital[cantonCode] ?? 0.065;
    final effectiveBaseRate =
        isMarried ? baseRate * marriedCapitalTaxDiscount : baseRate;
    final tax = RetirementTaxCalculator.progressiveTax(
        capitalBrut, effectiveBaseRate);
    final capitalNet = capitalBrut - tax;
    final capitalMonthly = capitalNet * safeWithdrawalRate / 12;

    return renteMonthly + capitalMonthly;
  }

  /// Compute salaire coordonne from gross annual salary (LPP art. 8).
  static double computeSalaireCoordonne(double grossAnnualSalary) {
    if (grossAnnualSalary < lppSeuilEntree) return 0;
    return (grossAnnualSalary - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
  }
}
