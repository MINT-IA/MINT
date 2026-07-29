import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

/// beads MINT_nosync-1px — RvC Option C (mixte) : double-déflation de l'impôt.
///
/// Invariant anti-façade : quand le capital surobligatoire vaut 0, l'option
/// « Mixte » se réduit EXACTEMENT à l'option « 100 % Rente » (même base de
/// rente, aucun capital à retirer). Le cashflow réel annuel des deux options
/// doit donc être identique année par année.
///
/// Bug prouvé sur dev (arbitrage_engine.dart:2005-2013) :
/// `_buildMixedTrajectory` calcule `renteTax` sur la rente RÉELLE
/// (realRente = renteObligatoire / (1+inflation)^y) puis re-déflate tout le
/// `totalNominalCashflow` par (1+inflation)^y. L'impôt est donc déflaté deux
/// fois -> le cashflow mixte est sur-estimé et diverge de l'option Rente, qui
/// fait correctement `netAnnual = realRente - annualTax` sans re-déflation
/// (arbitrage_engine.dart:1857-1866). Le biais pousse l'arbitrage vers le
/// capital.
void main() {
  // Rente obligatoire de l'option mixte = effectiveCapitalOblig * tauxConv.
  // 500000 * 0.068 = 34000, égal à renteAnnuelleProposee -> Option A (Rente)
  // et Option C (Mixte) partagent la même base de rente.
  const capitalOblig = 500000.0;
  const tauxConv = 0.068; // lppTauxConversionMinDecimal
  const renteBase = capitalOblig * tauxConv; // 34000
  const inflation = 0.02;
  const canton = 'VD';
  const horizon = 30;

  ArbitrageResult run() => ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: capitalOblig,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: 0.0, // collapse mixte -> rente pure
        renteAnnuelleProposee: renteBase,
        tauxConversionObligatoire: tauxConv,
        canton: canton,
        inflation: inflation,
        horizon: horizon,
        isMarried: false,
      );

  TrajectoireOption optionById(ArbitrageResult r, String id) =>
      r.options.firstWhere((o) => o.id == id);

  group('RvC Option C mixte — pas de double-déflation de l\'impôt', () {
    test('Mixte (surob=0) == 100% Rente sur le cashflow réel annuel', () {
      final result = run();
      final rente = optionById(result, 'full_rente');
      final mixte = optionById(result, 'mixed');

      expect(mixte.trajectory.length, rente.trajectory.length);

      for (var y = 1; y <= horizon; y++) {
        final a = rente.trajectory[y].annualCashflow;
        final c = mixte.trajectory[y].annualCashflow;
        expect(
          c,
          closeTo(a, 0.50),
          reason:
              'Année $y : cashflow mixte ($c) doit égaler le cashflow rente '
              '($a) quand surobligatoire=0. Écart observé = impôt déflaté '
              'deux fois dans _buildMixedTrajectory.',
        );
      }
    });

    test('Le cashflow mixte soustrait l\'impôt RÉEL (non re-déflaté)', () {
      final result = run();
      final mixte = optionById(result, 'mixed');

      // Valeur correcte reconstruite depuis le calculateur d'impôt public.
      const y = 20;
      final realRente = renteBase / math.pow(1 + inflation, y);
      // -axj : l'impôt rente RvC vient du miroir backend canonique, plus
      // du calculateur fiscal générique (parité rvc_parity_v1.json).
      final realTax = ArbitrageEngine.estimateIncomeTaxOnRenteRvc(
        realRente,
        canton,
        false,
      );
      final expected = realRente - realTax; // capitalWithdrawal = 0

      expect(
        mixte.trajectory[y].annualCashflow,
        closeTo(expected, 0.50),
        reason:
            'Le cashflow mixte doit valoir realRente - realTax, pas '
            'realRente - realTax/(1+inflation)^y (double-déflation).',
      );
    });
  });
}
