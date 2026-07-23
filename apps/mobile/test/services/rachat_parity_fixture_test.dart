// ────────────────────────────────────────────────────────────
//  PARITÉ CROISÉE RACHAT ÉCHELONNÉ — côté mobile (beads -81n/-97h)
//  Pendant backend : services/backend/tests/test_rachat_parity_fixture.py.
// ────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';

void main() {
  final data = jsonDecode(
          File('../../tools/fixtures/rachat_parity_v1.json')
              .readAsStringSync())
      as Map<String, dynamic>;
  final tol = (data['tolerance_chf'] as num).toDouble();

  for (final c in (data['cases'] as List).cast<Map<String, dynamic>>()) {
    test('miroir rachat == goldens partagés (${c['id']})', () {
      final inp = c['inputs'] as Map<String, dynamic>;
      final r = RachatEchelonneSimulator.compare(
        avoirActuel: 300000,
        rachatMax: (inp['rachat_max'] as num).toDouble(),
        revenuImposable: (inp['revenu_imposable'] as num).toDouble(),
        canton: inp['canton'] as String,
        civilStatus: inp['civil_status'] as String,
        horizon: inp['horizon'] as int,
        age: 45,
      );
      final exp = c['expected'] as Map<String, dynamic>;
      expect(r.economieBlocTotal,
          closeTo((exp['economie_bloc'] as num).toDouble(), tol));
      expect(r.economieEchelonneTotal,
          closeTo((exp['economie_echelonnee'] as num).toDouble(), tol));
      expect(r.delta > 0, exp['delta_positif_etale_gagne'],
          reason: 'anti-inversion : même conclusion sur toutes les surfaces');
    });
  }
}
