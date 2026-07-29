// ────────────────────────────────────────────────────────────
//  PARITÉ CROISÉE MoneyTruthReceipt v1 — côté mobile (Tranche firstJob PR-B)
//
//  La fixture partagée tools/fixtures/money_truth_receipt_v1.json est GELÉE
//  depuis le producteur backend réel (onboarding_service.py). Ce test vérifie
//  que le miroir Dart (first_job_service.dart::buildNetSalaryReceipt) produit,
//  pour les MÊMES inputs :
//    1. le MÊME inputsHash (octet pour octet — compute_inputs_hash /
//       computeInputsHash) ;
//    2. le MÊME net après arrondi au 1 CHF.
//  Le pendant backend est
//  services/backend/tests/test_money_truth_receipt_parity.py. Toute dérive
//  unilatérale casse la suite du côté qui dérive (SPEC §4.1 / §4.4, A7).
// ────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';

void main() {
  final fixture = File('../../tools/fixtures/money_truth_receipt_v1.json');
  final data = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();

  test('la fixture porte >= 10 cas cross-language', () {
    expect(cases.length, greaterThanOrEqualTo(10));
  });

  for (final c in cases) {
    test('miroir Dart == goldens partagés (${c['id']})', () {
      final inp = c['inputs'] as Map<String, dynamic>;
      final receipt = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: (inp['salaireBrutMensuel'] as num).toDouble(),
        age: inp['age'] as int,
        canton: inp['canton'] as String,
        tauxActivite: (inp['tauxActivite'] as num).toDouble(),
        etatCivil: inp['etatCivil'] as String,
        receiptId: 'fixed',
        computedAt: '2026-07-29T00:00:00+00:00',
      );

      // 1. inputsHash byte-identique au backend.
      expect(
        receipt.inputsHash,
        c['expectedInputsHash'] as String,
        reason: 'inputsHash Dart doit égaler compute_inputs_hash backend '
            '(même algorithme RFC 8785 + quantize, mêmes champs)',
      );

      // 2. même net après arrondi au 1 CHF (SPEC : « même valeur après arrondi »).
      expect(
        receipt.value.round(),
        c['expectedNetRounded'] as int,
        reason: 'net Dart arrondi doit égaler le net backend arrondi '
            '(${c['backendNetChf']})',
      );

      // Le claim et la base restent stables (contrat v1).
      expect(receipt.claimId, kFirstJobNetSalaryClaimId);
      expect(receipt.base, 'net');
    });
  }
}
