// ────────────────────────────────────────────────────────────
//  PARITÉ CROISÉE RvC — côté mobile (beads MINT_nosync-axj)
//
//  La fixture partagée tools/fixtures/rvc_parity_v1.json pine les sorties
//  du moteur canonique backend (rente_vs_capital.py, L2 comparer) ; ce test
//  vérifie que le miroir fallback offline (arbitrage_engine.dart) produit
//  LES MÊMES chiffres au centime. Le pendant backend est
//  services/backend/tests/test_rvc_parity_fixture.py. Toute dérive
//  unilatérale casse la suite du côté qui dérive.
// ────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

void main() {
  final fixture = File('../../tools/fixtures/rvc_parity_v1.json');
  final data =
      jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  final tol = (data['tolerance_chf'] as num).toDouble();
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();

  for (final c in cases) {
    test('miroir Dart == goldens partagés (${c['id']})', () {
      final inp = c['inputs'] as Map<String, dynamic>;
      final horizon = inp['horizon'] as int?;
      final ArbitrageResult r = horizon == null
          ? ArbitrageEngine.compareRenteVsCapital(
              capitalLppTotal: (inp['capital_lpp_total'] as num).toDouble(),
              capitalObligatoire:
                  (inp['capital_obligatoire'] as num).toDouble(),
              capitalSurobligatoire:
                  (inp['capital_surobligatoire'] as num).toDouble(),
              renteAnnuelleProposee:
                  (inp['rente_annuelle_proposee'] as num).toDouble(),
              canton: inp['canton'] as String,
              isMarried: inp['is_married'] as bool,
            )
          : ArbitrageEngine.compareRenteVsCapital(
              capitalLppTotal: (inp['capital_lpp_total'] as num).toDouble(),
              capitalObligatoire:
                  (inp['capital_obligatoire'] as num).toDouble(),
              capitalSurobligatoire:
                  (inp['capital_surobligatoire'] as num).toDouble(),
              renteAnnuelleProposee:
                  (inp['rente_annuelle_proposee'] as num).toDouble(),
              canton: inp['canton'] as String,
              horizon: horizon,
              isMarried: inp['is_married'] as bool,
            );

      final expected = c['expected'] as Map<String, dynamic>;
      expect(r.breakevenYear, expected['breakeven_year'],
          reason: 'breakeven relatif (années après retraite) — '
              'sémantique unifiée -axj (l\'écran affichait « 141 ans »)');

      final byId = {for (final o in r.options) o.id: o};
      for (final oid in ['full_rente', 'full_capital', 'mixed']) {
        final exp = expected[oid] as Map<String, dynamic>;
        expect(
          byId[oid]!.terminalValue,
          closeTo((exp['terminal_value'] as num).toDouble(), tol),
          reason: '$oid.terminalValue doit égaler le canonique backend',
        );
        expect(
          byId[oid]!.cumulativeTaxImpact,
          closeTo((exp['cumulative_tax_impact'] as num).toDouble(), tol),
          reason: '$oid.cumulativeTaxImpact doit égaler le canonique backend',
        );
      }
    });
  }
}
