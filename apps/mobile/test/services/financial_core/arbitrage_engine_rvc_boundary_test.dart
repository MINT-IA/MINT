import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';

Object? _receiptOf(Object result) {
  try {
    return (result as dynamic).calculationReceipt;
  } on NoSuchMethodError {
    return null;
  }
}

Object? _receiptValue(Object receipt, String field) {
  try {
    final dynamic value = receipt;
    return switch (field) {
      'calculationOrigin' => value.calculationOrigin,
      'calculationVersion' => value.calculationVersion,
      'constantsVersionHash' => value.constantsVersionHash,
      'unit' => value.unit,
      'assumptions' => value.assumptions,
      'sources' => value.sources,
      'readiness' => value.readiness,
      'confidenceScore' => value.confidenceScore,
      'missingRequiredInputs' => value.missingRequiredInputs,
      _ => null,
    };
  } on NoSuchMethodError {
    return null;
  }
}

ArbitrageResult _completeRvcResult() {
  return ArbitrageEngine.compareRenteVsCapital(
    capitalLppTotal: 650000,
    capitalObligatoire: 500000,
    capitalSurobligatoire: 150000,
    renteAnnuelleProposee: 37000,
    tauxConversionObligatoire: 0.068,
    tauxConversionSurobligatoire: 0.05,
    canton: 'VD',
    ageRetraite: 65,
    tauxRetrait: 0.04,
    rendementCapital: 0.03,
    inflation: 0.02,
    horizon: 30,
    isMarried: true,
    currentAge: 50,
  );
}

Map<String, dynamic> _completeBackendReceiptMap({
  Map<String, Object?>? assumptions,
  List<String>? sources,
  String constantsVersionHash = regulatoryConstantsVersionHash,
  Object? missingRequiredInputs = const <String>[],
  Object? confidenceScore = 82,
  String unit = 'CHF/mois; CHF; percent; years',
}) {
  return {
    'calculation_origin': 'backend_rvc',
    'calculation_version': 'backend-rvc-v1',
    'constants_version_hash': constantsVersionHash,
    'unit': unit,
    'assumptions': assumptions ??
        const <String, Object?>{
          'safe_withdrawal_rate': 0.04,
          'expected_return': 0.03,
          'inflation': 0.02,
          'horizon_years': 30,
          'canton': 'VD',
          'current_age': 50,
          'conversion_rate_obligatory': 0.068,
          'conversion_rate_surobligatory': 0.05,
        },
    'sources': sources ?? const ['LPP art. 14', 'LIFD art. 22', 'LIFD art. 38'],
    'readiness': 'ready',
    if (confidenceScore != null) 'confidence_score': confidenceScore,
    if (missingRequiredInputs != null)
      'missing_required_inputs': missingRequiredInputs,
  };
}

void main() {
  group('ArbitrageEngine.compareRenteVsCapital receipt boundary', () {
    test('exposes first-class mobile L1 receipt metadata', () {
      final result = _completeRvcResult();

      final receipt = _receiptOf(result);
      expect(
        receipt,
        isNotNull,
        reason:
            'RvC live result must expose a first-class calculation receipt.',
      );

      expect(
        _receiptValue(receipt!, 'calculationOrigin'),
        'mobile_l1_arbitrage_engine',
      );
      expect(_receiptValue(receipt, 'calculationVersion'), isNot(isEmpty));
      expect(
        _receiptValue(receipt, 'constantsVersionHash'),
        regulatoryConstantsVersionHash,
      );
      expect(_receiptValue(receipt, 'unit'), contains('CHF/mois'));
      expect(_receiptValue(receipt, 'readiness'), 'ready');
      expect(_receiptValue(receipt, 'confidenceScore'), result.confidenceScore);
      expect(_receiptValue(receipt, 'missingRequiredInputs'), isEmpty);
    });

    test('receipt carries keyed assumptions and legal sources', () {
      final result = _completeRvcResult();
      final receipt = _receiptOf(result);
      expect(receipt, isNotNull);

      final assumptions = Map<String, Object?>.from(
        (_receiptValue(receipt!, 'assumptions') as Map?) ?? const {},
      );
      expect(
        assumptions.keys,
        containsAll(<String>[
          'safe_withdrawal_rate',
          'expected_return',
          'inflation',
          'horizon_years',
          'canton',
          'current_age',
          'conversion_rate_obligatory',
          'conversion_rate_surobligatory',
        ]),
      );
      expect(assumptions['safe_withdrawal_rate'], 0.04);
      expect(assumptions['expected_return'], 0.03);
      expect(assumptions['inflation'], 0.02);
      expect(assumptions['horizon_years'], 30);
      expect(assumptions['canton'], 'VD');
      expect(assumptions['current_age'], 50);
      expect(assumptions['conversion_rate_obligatory'], 0.068);
      expect(assumptions['conversion_rate_surobligatory'], 0.05);

      final sources = List<String>.from(
        (_receiptValue(receipt, 'sources') as Iterable?) ?? const [],
      );
      expect(sources.any((s) => s.contains('LPP art. 14')), isTrue);
      expect(sources.any((s) => s.contains('LIFD art. 22')), isTrue);
      expect(sources.any((s) => s.contains('LIFD art. 38')), isTrue);
    });

    test('incomplete inputs are explicit in readiness and missing inputs', () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 0,
        capitalObligatoire: 0,
        capitalSurobligatoire: 0,
        renteAnnuelleProposee: 0,
        canton: '',
      );

      final receipt = _receiptOf(result);
      expect(receipt, isNotNull);
      expect(_receiptValue(receipt!, 'readiness'), 'missing_required_inputs');
      expect(
        _receiptValue(receipt, 'missingRequiredInputs'),
        containsAll(<String>[
          'capital_lpp_total',
          'rente_annuelle_proposee',
          'canton',
          'current_age',
        ]),
      );
    });

    test('zero surobligatory rate is complete when no surobligatory capital',
        () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 0,
        renteAnnuelleProposee: 34000,
        tauxConversionObligatoire: 0.068,
        tauxConversionSurobligatoire: 0,
        canton: 'VD',
        currentAge: 50,
      );

      final receipt = result.calculationReceipt;
      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isTrue);
      expect(
          receipt.missingRequiredInputs, isNot(contains('capital_lpp_total')));
      expect(
        receipt.missingRequiredInputs,
        isNot(contains('conversion_rate_surobligatory')),
      );
    });

    test('mobile L1 receipt confidence is finite and within percent bounds',
        () {
      final result = _completeRvcResult();
      final receipt = result.calculationReceipt;

      expect(receipt, isNotNull);
      expect(receipt!.confidenceScore.isFinite, isTrue);
      expect(receipt.confidenceScore, inInclusiveRange(0, 100));
      expect(receipt.isComplete, isTrue);
    });

    test('backend receipt parser accepts snake_case constants_version_hash',
        () {
      final receipt =
          ArbitrageCalculationReceipt.fromMap(_completeBackendReceiptMap());

      expect(receipt, isNotNull);
      expect(receipt!.constantsVersionHash, regulatoryConstantsVersionHash);
      expect(receipt.isComplete, isTrue);
    });

    test('backend receipt with divergent constants hash is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(constantsVersionHash: 'stale-hash'),
      );

      expect(receipt, isNotNull);
      expect(receipt!.constantsVersionHash, 'stale-hash');
      expect(receipt.isComplete, isFalse);
    });

    test('backend receipt without confidence is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(confidenceScore: null),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt without missing-inputs metadata is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(missingRequiredInputs: null),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt without current age assumption is incomplete', () {
      final assumptions = Map<String, Object?>.from(
        _completeBackendReceiptMap()['assumptions'] as Map,
      )..remove('current_age');
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(assumptions: assumptions),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with malformed missing-inputs metadata is incomplete',
        () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(missingRequiredInputs: 'none'),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with incomplete RvC assumptions is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(
          assumptions: const <String, Object?>{'canton': 'VD'},
        ),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with null RvC assumption value is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(
          assumptions: const <String, Object?>{
            'safe_withdrawal_rate': 0.04,
            'expected_return': null,
            'inflation': 0.02,
            'horizon_years': 30,
            'canton': 'VD',
            'current_age': 50,
            'conversion_rate_obligatory': 0.068,
            'conversion_rate_surobligatory': 0.05,
          },
        ),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with mistyped RvC assumption value is incomplete',
        () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(
          assumptions: const <String, Object?>{
            'safe_withdrawal_rate': '4%',
            'expected_return': 0.03,
            'inflation': 0.02,
            'horizon_years': 30,
            'canton': 'VD',
            'current_age': 50,
            'conversion_rate_obligatory': 0.068,
            'conversion_rate_surobligatory': 0.05,
          },
        ),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with invalid RvC assumption domain is incomplete',
        () {
      final receipts = <ArbitrageCalculationReceipt?>[
        ArbitrageCalculationReceipt.fromMap(
          _completeBackendReceiptMap(
            assumptions: const <String, Object?>{
              'safe_withdrawal_rate': 0,
              'expected_return': 0.03,
              'inflation': 0.02,
              'horizon_years': 30,
              'canton': 'VD',
              'current_age': 50,
              'conversion_rate_obligatory': 0.068,
              'conversion_rate_surobligatory': 0.05,
            },
          ),
        ),
        ArbitrageCalculationReceipt.fromMap(
          _completeBackendReceiptMap(
            assumptions: const <String, Object?>{
              'safe_withdrawal_rate': 0.04,
              'expected_return': 0.03,
              'inflation': 0.02,
              'horizon_years': 0,
              'canton': 'VD',
              'current_age': 50,
              'conversion_rate_obligatory': 0.068,
              'conversion_rate_surobligatory': 0.05,
            },
          ),
        ),
        ArbitrageCalculationReceipt.fromMap(
          _completeBackendReceiptMap(
            assumptions: const <String, Object?>{
              'safe_withdrawal_rate': 0.04,
              'expected_return': 0.03,
              'inflation': 0.02,
              'horizon_years': 30,
              'canton': 'VD',
              'current_age': 0,
              'conversion_rate_obligatory': 0.068,
              'conversion_rate_surobligatory': 0.05,
            },
          ),
        ),
      ];

      for (final receipt in receipts) {
        expect(receipt, isNotNull);
        expect(receipt!.isComplete, isFalse);
      }
    });

    test('backend receipt without required legal sources is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(sources: const ['LIFD art. 22']),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt without rente taxation source is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(
          sources: const ['LPP art. 14', 'LIFD art. 38'],
        ),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt without CHF monthly unit is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(unit: 'CHF; percent; years'),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('backend receipt with out-of-range confidence is incomplete', () {
      final receipt = ArbitrageCalculationReceipt.fromMap(
        _completeBackendReceiptMap(confidenceScore: 140),
      );

      expect(receipt, isNotNull);
      expect(receipt!.isComplete, isFalse);
    });

    test('no production caller uses legacy computeRenteVsCapital directly', () {
      final offenders = <String>[];
      final root = Directory('lib');
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.endsWith('domain/rente_vs_capital_calculator.dart')) {
          continue;
        }
        final content = entity.readAsStringSync();
        if (RegExp(r'(^|[^A-Za-z0-9_])computeRenteVsCapital\(')
            .hasMatch(content)) {
          offenders.add(normalized);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Production RvC callers must use ArbitrageEngine as the mobile L1 boundary.',
      );
    });
  });
}
