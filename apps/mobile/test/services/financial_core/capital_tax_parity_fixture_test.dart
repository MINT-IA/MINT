// ────────────────────────────────────────────────────────────
//  PARITÉ CROISÉE MODÈLE CAPITAL v2 — côté mobile (beads -2i2)
//  Pendant backend : services/backend/tests/test_capital_tax_parity_fixture.py.
// ────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';

void main() {
  final data = jsonDecode(
          File('../../tools/fixtures/capital_tax_parity_v1.json')
              .readAsStringSync())
      as Map<String, dynamic>;
  final tol = (data['tolerance_chf'] as num).toDouble();

  for (final c in (data['cases'] as List).cast<Map<String, dynamic>>()) {
    test('capital v2 miroir (${c['canton']} ${c['amount']})', () {
      final val = estimateCapitalWithdrawalTaxV2(
        (c['amount'] as num).toDouble(),
        c['canton'] as String,
        isMarried: c['is_married'] as bool,
      );
      expect(val, closeTo((c['expected'] as num).toDouble(), tol));
    });
  }
}
