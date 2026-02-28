import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ALL tax calculations MUST use RetirementTaxCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateTax() or similar methods.

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

  /// Simplified marginal tax rate by canton bracket.
  ///
  /// Source: AFC taux marginaux d'imposition 2025.
  /// Used for chiffre-choc estimates — NOT for precise tax returns.
  static double estimateMarginalRate(double revenuBrutAnnuel, String canton) {
    const highTaxCantons = {'GE', 'VD', 'BS', 'BE', 'NE', 'JU', 'FR', 'VS'};
    const lowTaxCantons = {'ZG', 'SZ', 'NW', 'OW', 'AI', 'AR', 'UR'};

    double baseRate;
    if (revenuBrutAnnuel > 200000) {
      baseRate = 0.38;
    } else if (revenuBrutAnnuel > 120000) {
      baseRate = 0.32;
    } else if (revenuBrutAnnuel > 80000) {
      baseRate = 0.28;
    } else {
      baseRate = 0.22;
    }

    final cantonCode = canton.toUpperCase();
    if (highTaxCantons.contains(cantonCode)) return baseRate * 1.1;
    if (lowTaxCantons.contains(cantonCode)) return baseRate * 0.75;
    return baseRate;
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
    return (result['chargeTotale'] as double) / 12;
  }
}
