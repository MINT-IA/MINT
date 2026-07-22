import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

/// beads MINT_nosync-t5r (a) — audit T01-F31.
///
/// Bug prouvé sur dev (arbitrage_engine.dart:383-398) : `capitalEpuiseAge`
/// est détecté par l'heuristique « cashflow annuel < 10 % du cashflow de
/// l'an 1 » au lieu de lire l'épuisement réel du capital. Deux conséquences :
///  1. off-by-one : quand le dernier retrait partiel vaut ≥ 10 % du retrait
///     initial, l'heuristique ne se déclenche que l'année SUIVANTE (cashflow
///     tombé à 0) — l'âge annoncé est un an trop tard ;
///  2. faux négatif : si l'épuisement tombe sur la dernière année de
///     l'horizon, aucune année « cashflow ≈ 0 » n'existe dans la trajectoire
///     et l'engine annonce « jamais épuisé ».
/// La trajectoire (`_buildCapitalTrajectory`) plafonne déjà le retrait au
/// capital restant : `netPatrimony` atteint exactement 0 l'année de
/// l'épuisement — c'est le signal déterministe à lire.
void main() {
  // rendement 0, inflation 0, tauxRetrait 0.5 -> retraits an 1 et an 2 de
  // 0.5*C chacun (le 2e plafonné au restant), capital nul FIN AN 2.
  ArbitrageResult run({required int horizon}) =>
      ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 0,
        renteAnnuelleProposee: 34000,
        canton: 'VD',
        ageRetraite: 65,
        tauxRetrait: 0.5,
        rendementCapital: 0.0,
        inflation: 0.0,
        horizon: horizon,
      );

  group('capitalEpuiseAge — lecture déterministe, pas heuristique cashflow', () {
    test('épuisement an 2 -> âge 67, pas 68 (off-by-one heuristique)', () {
      final r = run(horizon: 30);
      // Preuve structurelle : le capital (netPatrimony) est bien nul dès
      // l'an 2 dans la trajectoire capital.
      final capital = r.options.firstWhere((o) => o.id == 'full_capital');
      expect(capital.trajectory[2].netPatrimony, closeTo(0, 1e-6));
      expect(capital.trajectory[1].netPatrimony, greaterThan(0));
      expect(r.capitalEpuiseAge, 67,
          reason: 'le capital est épuisé fin an 2 (65+2), '
              "l'heuristique cashflow<10% annonçait 68");
    });

    test('épuisement sur la dernière année de l\'horizon -> non-null', () {
      final r = run(horizon: 2);
      final capital = r.options.firstWhere((o) => o.id == 'full_capital');
      expect(capital.trajectory[2].netPatrimony, closeTo(0, 1e-6));
      expect(r.capitalEpuiseAge, 67,
          reason: "épuisement à l'an 2 d'un horizon de 2 : l'heuristique "
              'ne voyait jamais de cashflow≈0 et rendait null');
    });

    test('capital jamais épuisé -> null (pas de faux positif)', () {
      final r = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 0,
        renteAnnuelleProposee: 34000,
        canton: 'VD',
        ageRetraite: 65,
        tauxRetrait: 0.03,
        rendementCapital: 0.05,
        inflation: 0.0,
        horizon: 30,
      );
      final capital = r.options.firstWhere((o) => o.id == 'full_capital');
      expect(capital.trajectory.last.netPatrimony, greaterThan(0));
      expect(r.capitalEpuiseAge, isNull);
    });
  });
}
