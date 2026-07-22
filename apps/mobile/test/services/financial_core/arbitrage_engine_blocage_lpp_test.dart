import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// beads MINT_nosync-okl — blocage LPP 3 ans (art. 79b al. 3) dans
/// l'option « Rachat LPP » de compareAllocationAnnuelle.
///
/// Loi : un retrait en capital dans les 3 ans qui suivent un rachat entraine
/// le refus/la reprise de la deduction fiscale (art. 79b al. 3 LPP,
/// ATF 142 II 399). Le moteur recevait `blocageYears` (le label UI annonce
/// meme « blocage 3 ans ») mais ne le lisait JAMAIS : les rachats des 3
/// dernieres annees etaient credites d'une economie d'impot inexistante.
void main() {
  group('compareAllocationAnnuelle — rachat LPP et blocage 3 ans', () {
    ArbitrageResult run() => ArbitrageEngine.compareAllocationAnnuelle(
          montantDisponible: 10000,
          tauxMarginal: 0.30,
          a3aMaxed: true, // isole l'option rachat_lpp
          potentielRachatLpp: 100000,
          anneesAvantRetraite: 10,
          rendementLpp: 0.0, // arithmetique exacte
          canton: 'ZH',
        );

    test('les rachats des 3 dernieres annees ne creditent AUCUNE economie', () {
      final rachat =
          run().options.firstWhere((o) => o.id == 'rachat_lpp');
      // Annees creditees : 1..7 seulement (8,9,10 dans la fenetre de blocage).
      // Snapshot y=9 (avant l'ajustement terminal) : 7 x 10'000 x 30% = 21'000.
      expect(
        rachat.trajectory[9].cumulativeTaxDelta,
        closeTo(-21000, 0.01),
        reason: 'Deductions des annees 8-10 reprises par l\'AFC '
            '(retrait capital < 3 ans apres rachat).',
      );
    });

    test('valeur terminale coherente avec la reprise AFC', () {
      final rachat =
          run().options.firstWhere((o) => o.id == 'rachat_lpp');
      const balance = 10 * 10000.0; // rendement 0
      final wTax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: balance,
        canton: 'ZH',
      );
      const savings = 7 * 10000.0 * 0.30; // 21'000, pas 30'000
      expect(
        rachat.trajectory.last.netPatrimony,
        closeTo((balance - wTax) + savings, 0.01),
      );
    });
  });
}
