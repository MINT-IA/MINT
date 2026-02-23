import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/fiscal_service.dart';
import 'package:mint_mobile/services/retirement_service.dart';

/// Retirement tax calculator — pure static functions.
///
/// Legal basis: LIFD art. 22 (rente taxation), LIFD art. 38 (capital withdrawal).
/// All computations are deterministic and stateless.
class RetirementTaxCalculator {
  RetirementTaxCalculator._();

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
    return RetirementService.calculateProgressiveTax(
        capitalBrut, effectiveRate);
  }

  /// Raw progressive tax on a given amount.
  ///
  /// Delegates to RetirementService.calculateProgressiveTax.
  static double progressiveTax(double montant, double baseRate) {
    return RetirementService.calculateProgressiveTax(montant, baseRate);
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
