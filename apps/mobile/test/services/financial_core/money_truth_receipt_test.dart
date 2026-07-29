// ────────────────────────────────────────────────────────────
//  MoneyTruthReceipt v1 — contrat + producteur, côté mobile (firstJob PR-B)
//
//  Tests unitaires du miroir Dart : algorithme de hash (vecteurs gelés
//  calculés par compute_inputs_hash côté Python) + producteur
//  FirstJobService.buildNetSalaryReceipt. La parité cross-language de bout en
//  bout est verrouillée par money_truth_receipt_parity_test.dart.
// ────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';

void main() {
  group('computeInputsHash (miroir de compute_inputs_hash)', () {
    // Vecteurs gelés depuis Python (app.services.coach.inputs_hash).
    test('objet vide', () {
      expect(
        computeInputsHash(<String, dynamic>{}),
        '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
      );
    });

    test('int et double entier canonicalisent identiquement', () {
      const expected =
          '5041bf1f713df204784353e82f6a4a535931cb64f1f4b4a5aeaffcb720918b22';
      expect(computeInputsHash(<String, dynamic>{'x': 1}), expected);
      expect(computeInputsHash(<String, dynamic>{'x': 1.0}), expected);
    });

    test('quantification 2 décimales ROUND_HALF_UP (0.005 -> 0.01)', () {
      expect(
        computeInputsHash(<String, dynamic>{'x': 0.005}),
        'b17bfc0a327352805056c74fb46ac46c0eb6b2635203d09bbebe536885f450f7',
      );
    });

    test('clés triées + string + int', () {
      expect(
        computeInputsHash(<String, dynamic>{'canton': 'ZH', 'age': 30}),
        '0daa2bc07dc468bc177a658a89deb98f16d02691266ab6a337d0af297271abd2',
      );
    });

    test('déterministe entre appels', () {
      final a = computeInputsHash(<String, dynamic>{'canton': 'VD', 'age': 25});
      final b = computeInputsHash(<String, dynamic>{'age': 25, 'canton': 'VD'});
      expect(a, b); // l'ordre d'insertion n'importe pas (clés triées)
      expect(a.length, 64);
    });
  });

  group('FirstJobService.buildNetSalaryReceipt', () {
    test('value == net de l\'écran (aucune divergence intra-écran)', () {
      final screen = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
      );
      final r = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
      );
      expect(r.value, screen.netEstime);
      expect(r.claimId, kFirstJobNetSalaryClaimId);
      expect(r.base, 'net');
    });

    test('bande non dégénérée encadrant la valeur', () {
      final r = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6788,
        age: 30,
        canton: 'GE',
      );
      expect(r.range, isNotNull);
      expect(r.range!.low < r.value, isTrue);
      expect(r.value < r.range!.high, isTrue);
    });

    test('canton normalisé en majuscules + jurisdiction', () {
      final r = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'vd',
        etatCivil: 'Celibataire',
      );
      expect(r.inputs['canton'], 'VD');
      expect(r.inputs['etatCivil'], 'celibataire');
      expect(r.jurisdiction, 'CH-VD');
    });

    test('confidence : 4 axes dans [0,1] + score = moyenne géométrique', () {
      final r = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
      );
      final c = r.confidence!;
      for (final axis in [
        c.completeness,
        c.accuracy,
        c.freshness,
        c.understanding,
        c.score,
      ]) {
        expect(axis, inInclusiveRange(0.0, 1.0));
      }
      final expected =
          _geomMean4(c.completeness, c.accuracy, c.freshness, c.understanding);
      expect((c.score - expected).abs() < 1e-9, isTrue);
    });

    test('toJson porte les clés camelCase du contrat', () {
      final r = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
      );
      final j = r.toJson();
      for (final k in [
        'claimId',
        'receiptId',
        'inputsHash',
        'taxYear',
        'civilStatus',
        'engineVersion',
        'computedAt',
        'range',
        'confidence',
      ]) {
        expect(j.containsKey(k), isTrue, reason: 'clé manquante : $k');
      }
    });

    test('completeness dégrade avec moins de champs fournis', () {
      final full = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
        userProvidedFields: const {'salaireBrutMensuel', 'age', 'canton'},
      );
      final partial = FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6500,
        age: 30,
        canton: 'VD',
        userProvidedFields: const {'salaireBrutMensuel'},
      );
      expect(full.confidence!.completeness, 1.0);
      expect(partial.confidence!.completeness < 1.0, isTrue);
    });
  });
}

double _geomMean4(double a, double b, double c, double d) {
  // moyenne géométrique 4 axes (== EnhancedConfidence.combined / producteur).
  return math.pow(a * b * c * d, 0.25).toDouble();
}
