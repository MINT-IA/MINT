import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';

/// Wave 7 A7 — regression guard for ATF 142 II 399 / 148 II 189.
///
/// Rachat LPP followed by any capital withdrawal (EPL, retraite anticipée,
/// départ CH, retrait 3e pilier) within 3 years is treated as abuse by
/// the Tribunal fédéral: the AFC reverses the LIFD art. 33 al. 1 let. g
/// déduction. `ArbitrageEngine.compareRachatVsMarche` must:
///   (a) emit an `alertes` entry naming ATF 142 II 399 when the new
///       `plannedCapitalWithdrawalYearsFromNow` parameter falls within
///       the 3-year window;
///   (b) zero out `taxSavingRachat` so the simulated trajectory reflects
///       the reality of the reversed déduction;
///   (c) cite the ATF in the `sources` list only in that breach path;
///   (d) leave the default behaviour unchanged when no planned withdrawal
///       is supplied (backwards-compatible).
void main() {
  group('compareRachatVsMarche — rachat+EPL 3-year anti-abuse', () {
    test('no planned withdrawal: no alerte, déduction preserved', () {
      final result = ArbitrageEngine.compareRachatVsMarche(
        montant: 50000,
        tauxMarginal: 0.25,
        anneesAvantRetraite: 20,
        canton: 'VS',
      );
      expect(result.alertes, isEmpty);
      expect(result.sources.any((s) => s.contains('ATF')), isFalse);
      // Rachat option should carry a positive terminal value (déduction
      // taxSavingRachat = 50000 × 0.25 = 12'500 baked into the math).
      final rachatOption =
          result.options.firstWhere((o) => o.id == 'rachat_lpp');
      expect(rachatOption.terminalValue, greaterThan(0));
    });

    test('planned EPL in 2 years: alerte surfaced, ATF 142 II 399 cited', () {
      final result = ArbitrageEngine.compareRachatVsMarche(
        montant: 50000,
        tauxMarginal: 0.25,
        anneesAvantRetraite: 20,
        canton: 'VS',
        plannedCapitalWithdrawalYearsFromNow: 2,
      );
      expect(result.alertes, isNotEmpty);
      final alerte = result.alertes.first;
      expect(alerte.contains('LPP art. 79b al. 3'), isTrue);
      expect(alerte.contains('ATF 142 II 399'), isTrue);
      expect(result.sources.any((s) => s.contains('ATF 142 II 399')), isTrue);
      expect(result.premierEclairage.contains('annulée'), isTrue);
    });

    test('planned withdrawal at year 3 is outside breach (boundary)', () {
      final result = ArbitrageEngine.compareRachatVsMarche(
        montant: 50000,
        tauxMarginal: 0.25,
        anneesAvantRetraite: 20,
        canton: 'VS',
        plannedCapitalWithdrawalYearsFromNow: 3,
      );
      // Year 3 = déduction preserved (LPP art. 79b al. 3 cites "3 ans"
      // exclusive: a retrait le jour anniversaire des 3 ans est accepté).
      expect(result.alertes, isEmpty);
    });

    test('breach path removes the taxSavingRachat from terminal value', () {
      final normal = ArbitrageEngine.compareRachatVsMarche(
        montant: 50000,
        tauxMarginal: 0.30,
        anneesAvantRetraite: 20,
        canton: 'VS',
      );
      final breach = ArbitrageEngine.compareRachatVsMarche(
        montant: 50000,
        tauxMarginal: 0.30,
        anneesAvantRetraite: 20,
        canton: 'VS',
        plannedCapitalWithdrawalYearsFromNow: 1,
      );
      final normalRachat =
          normal.options.firstWhere((o) => o.id == 'rachat_lpp');
      final breachRachat =
          breach.options.firstWhere((o) => o.id == 'rachat_lpp');
      // The delta should be at least ~taxSavingRachat = 50000 × 0.30 = 15'000.
      expect(normalRachat.terminalValue - breachRachat.terminalValue,
          greaterThan(14000));
    });
  });
}
