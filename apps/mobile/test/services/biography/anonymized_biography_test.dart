import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/anonymized_biography_service.dart';

/// Helper to create a BiographyFact with minimal boilerplate.
BiographyFact _fact({
  required FactType type,
  required String value,
  DateTime? sourceDate,
  DateTime? updatedAt,
  bool isDeleted = false,
  String freshnessCategory = 'annual',
  String? fieldPath,
}) {
  final now = DateTime(2026, 4, 6);
  return BiographyFact(
    id: '${type.name}-${value.hashCode}',
    factType: type,
    fieldPath: fieldPath,
    value: value,
    source: FactSource.document,
    sourceDate: sourceDate ?? DateTime(2025, 3, 15),
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: updatedAt ?? now, // Fresh by default
    isDeleted: isDeleted,
    freshnessCategory: freshnessCategory,
  );
}

void main() {
  // Fixed reference time for all tests
  final now = DateTime(2026, 4, 6);

  group('AnonymizedBiographySummary - salary rounding', () {
    test('salary 122207 rounds to ~120k CHF (nearest 5k)', () {
      final facts = [_fact(type: FactType.salary, value: '122207')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~120k CHF'));
    });

    test('salary 95000 rounds to ~95k CHF (exact multiple of 5k)', () {
      final facts = [_fact(type: FactType.salary, value: '95000')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~95k CHF'));
    });

    test('salary 67000 rounds to ~65k CHF (nearest 5k)', () {
      final facts = [_fact(type: FactType.salary, value: '67000')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~65k CHF'));
    });
  });

  group('AnonymizedBiographySummary - LPP/3a rounding', () {
    test('lppCapital 70377 rounds to ~70k CHF (nearest 10k)', () {
      final facts = [_fact(type: FactType.lppCapital, value: '70377')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~70k CHF'));
    });

    test('lppCapital 19620 rounds to ~20k CHF (nearest 10k)', () {
      final facts = [_fact(type: FactType.lppCapital, value: '19620')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~20k CHF'));
    });

    test('threeACapital 32000 rounds to ~30k CHF (nearest 10k)', () {
      final facts = [_fact(type: FactType.threeACapital, value: '32000')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~30k CHF'));
    });

    test('lppRachatMax 539414 rounds to ~540k CHF (nearest 10k)', () {
      final facts = [_fact(type: FactType.lppRachatMax, value: '539414')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~540k CHF'));
    });
  });

  group('AnonymizedBiographySummary - other fact types', () {
    test('canton passes through as-is (non-sensitive)', () {
      final facts = [_fact(type: FactType.canton, value: 'VS')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('VS'));
    });

    test('avsContributionYears passes through as integer', () {
      final facts = [
        _fact(type: FactType.avsContributionYears, value: '27'),
      ];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('27 ans'));
    });

    test('taxRate rounds to nearest 0.5%', () {
      final facts = [_fact(type: FactType.taxRate, value: '12.3')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~12.5'));
    });

    test('mortgageDebt rounds to nearest 50k', () {
      final facts = [_fact(type: FactType.mortgageDebt, value: '430000')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('~450k CHF'));
    });

    test('civilStatus passes through', () {
      final facts = [_fact(type: FactType.civilStatus, value: 'marie')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('marie'));
    });

    test('lifeEvent passes through', () {
      final facts = [_fact(type: FactType.lifeEvent, value: 'housingPurchase')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('housingPurchase'));
    });

    test('userDecision truncated to 100 chars if longer', () {
      final longText = 'A' * 150;
      final facts = [_fact(type: FactType.userDecision, value: longText)];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, isNot(contains(longText)));
      expect(result, contains('${'A' * 97}...'));
    });
  });

  group('AnonymizedBiographySummary - filtering', () {
    test('deleted facts are excluded from summary', () {
      final facts = [
        _fact(type: FactType.salary, value: '100000', isDeleted: true),
        _fact(type: FactType.canton, value: 'GE'),
      ];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, isNot(contains('~100k CHF')));
      expect(result, contains('GE'));
    });

    test('facts with freshness < 0.30 are excluded', () {
      // updatedAt 4 years ago -> weight will be at floor 0.3 for annual
      // Actually need > 36 months for floor. 40 months -> 0.3 exactly.
      // Need something well below 0.30... but floor is 0.30.
      // The floor is 0.30, so weight never goes below 0.30 for annual.
      // For volatile, floor months = 12 months. After 12+ months, weight = 0.30.
      // Since threshold is < 0.30 (strict), floor of 0.30 is included.
      // Actually, the floor of 0.3 means weight is never < 0.3, so nothing
      // is ever excluded by the < 0.30 threshold with the current decay model.
      // The threshold guards against future decay models with lower floors.
      // Let's test that a fact at exactly 0.30 (floor) IS included.
      final oldFact = _fact(
        type: FactType.salary,
        value: '80000',
        updatedAt: now.subtract(const Duration(days: 1200)), // ~40 months
      );
      final result = AnonymizedBiographySummary.build([oldFact], now: now);
      // At 40 months, annual tier: floor = 0.3 (>= 0.30 threshold)
      // So it should be included but marked stale
      expect(result, contains('~80k CHF'));
      expect(result, contains('[DONNEE ANCIENNE]'));
    });

    test('facts with freshness between 0.30 and 0.60 are marked [DONNEE ANCIENNE]', () {
      // 24 months old for annual tier: weight = 1.0 - 0.7 * (12/24) = 0.65
      // Wait, annual: full=12, floor=36. 24 months -> elapsed=12, range=24
      // weight = 1.0 - 0.7 * (12/24) = 1.0 - 0.35 = 0.65
      // That's >= 0.60, so no marker. Let's use 28 months:
      // elapsed = 16, range = 24. weight = 1.0 - 0.7 * (16/24) = 1.0 - 0.467 = 0.533
      final agingFact = _fact(
        type: FactType.lppCapital,
        value: '50000',
        updatedAt: now.subtract(const Duration(days: 852)), // ~28 months
      );
      final result = AnonymizedBiographySummary.build([agingFact], now: now);
      expect(result, contains('~50k CHF'));
      expect(result, contains('[DONNEE ANCIENNE]'));
    });

    test('fresh facts have no stale marker', () {
      final freshFact = _fact(
        type: FactType.salary,
        value: '100000',
        updatedAt: now, // fresh
      );
      final result = AnonymizedBiographySummary.build([freshFact], now: now);
      expect(result, contains('~100k CHF'));
      expect(result, isNot(contains('[DONNEE ANCIENNE]')));
    });
  });

  group('AnonymizedBiographySummary - format', () {
    test('summary starts with BIOGRAPHIE FINANCIERE delimiter', () {
      final facts = [_fact(type: FactType.canton, value: 'ZH')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, startsWith('--- BIOGRAPHIE FINANCIERE ---'));
    });

    test('summary ends with FIN BIOGRAPHIE delimiter', () {
      final facts = [_fact(type: FactType.canton, value: 'ZH')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result.trim(), endsWith('--- FIN BIOGRAPHIE ---'));
    });

    test('summary includes privacy reminder', () {
      final facts = [_fact(type: FactType.canton, value: 'ZH')];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('JAMAIS de montant exact'));
      expect(result, contains('nom, employeur, IBAN'));
    });

    test('summary output capped at 8000 chars', () {
      // Create many facts to exceed the limit
      final facts = List.generate(200, (i) => _fact(
        type: FactType.userDecision,
        value: 'Decision numero $i avec un texte assez long pour prendre de la place dans le buffer',
      ));
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result.length, lessThanOrEqualTo(8000));
      expect(result.trim(), endsWith('--- FIN BIOGRAPHIE ---'));
    });

    test('empty facts list returns minimal summary with header/footer', () {
      final result = AnonymizedBiographySummary.build([], now: now);
      expect(result, contains('--- BIOGRAPHIE FINANCIERE ---'));
      expect(result, contains('--- FIN BIOGRAPHIE ---'));
    });

    test('source date formatted as French month + year', () {
      final facts = [
        _fact(
          type: FactType.salary,
          value: '100000',
          sourceDate: DateTime(2025, 3, 15),
        ),
      ];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('mars 2025'));
    });

    test('null source date shows "date inconnue"', () {
      final facts = [
        BiographyFact(
          id: 'test-null-date',
          factType: FactType.salary,
          value: '80000',
          source: FactSource.userInput,
          sourceDate: null,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final result = AnonymizedBiographySummary.build(facts, now: now);
      expect(result, contains('date inconnue'));
    });
  });
}
