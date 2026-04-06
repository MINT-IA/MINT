import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/biography_refresh_detector.dart';

/// Helper to create a BiographyFact with minimal boilerplate.
BiographyFact _fact({
  required FactType type,
  required String value,
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
    sourceDate: DateTime(2025, 3, 15),
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: updatedAt ?? now,
    isDeleted: isDeleted,
    freshnessCategory: freshnessCategory,
  );
}

void main() {
  final now = DateTime(2026, 4, 6);

  group('BiographyRefreshDetector.detectStaleFields', () {
    test('returns stale fields when freshness < 0.60', () {
      // 28 months old for annual tier:
      // weight = 1.0 - 0.7 * (16/24) = ~0.533 (< 0.60)
      final staleFact = _fact(
        type: FactType.lppCapital,
        value: '50000',
        updatedAt: now.subtract(const Duration(days: 852)),
        fieldPath: 'prevoyance.avoirLppTotal',
      );
      final result = BiographyRefreshDetector.detectStaleFields(
        [staleFact],
        now: now,
      );
      expect(result, hasLength(1));
      expect(result.first.factType, FactType.lppCapital);
      expect(result.first.monthsOld, greaterThan(20));
      expect(result.first.suggestedAction, contains('certificat LPP'));
    });

    test('returns empty list when all facts are fresh', () {
      final freshFact = _fact(
        type: FactType.salary,
        value: '100000',
        updatedAt: now, // fresh
      );
      final result = BiographyRefreshDetector.detectStaleFields(
        [freshFact],
        now: now,
      );
      expect(result, isEmpty);
    });

    test('excludes deleted facts from stale detection', () {
      final deletedStale = _fact(
        type: FactType.salary,
        value: '80000',
        updatedAt: now.subtract(const Duration(days: 900)),
        isDeleted: true,
      );
      final result = BiographyRefreshDetector.detectStaleFields(
        [deletedStale],
        now: now,
      );
      expect(result, isEmpty);
    });

    test('sorts stale fields by most stale first', () {
      final older = _fact(
        type: FactType.salary,
        value: '80000',
        updatedAt: now.subtract(const Duration(days: 900)),
      );
      final newer = _fact(
        type: FactType.lppCapital,
        value: '50000',
        updatedAt: now.subtract(const Duration(days: 800)), // ~26 months -> stale
      );
      final result = BiographyRefreshDetector.detectStaleFields(
        [newer, older],
        now: now,
      );
      expect(result, hasLength(2));
      expect(result.first.factType, FactType.salary);
      expect(result.last.factType, FactType.lppCapital);
    });
  });

  group('BiographyRefreshDetector.buildRefreshNudge', () {
    test('generates French nudge text with specific document type', () {
      final staleFields = [
        const StaleField(
          factType: FactType.lppCapital,
          fieldPath: 'prevoyance.avoirLppTotal',
          monthsOld: 28,
          suggestedAction: 'Rescanner ton certificat LPP',
        ),
      ];
      final result = BiographyRefreshDetector.buildRefreshNudge(staleFields);
      expect(result, contains('DONNEES A ACTUALISER'));
      expect(result, contains('Capital LPP'));
      expect(result, contains('28 mois'));
      expect(result, contains('certificat LPP'));
    });

    test('returns empty string when no stale fields', () {
      final result = BiographyRefreshDetector.buildRefreshNudge([]);
      expect(result, isEmpty);
    });

    test('limits output to 3 stale fields', () {
      final staleFields = List.generate(
        5,
        (i) => StaleField(
          factType: FactType.salary,
          monthsOld: 20 + i,
          suggestedAction: 'Action $i',
        ),
      );
      final result = BiographyRefreshDetector.buildRefreshNudge(staleFields);
      // Count occurrences of "Suggestion" — max 3
      final count = 'Suggestion'.allMatches(result).length;
      expect(count, 3);
    });
  });
}
