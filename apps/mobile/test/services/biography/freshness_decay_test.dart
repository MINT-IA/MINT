import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

// ────────────────────────────────────────────────────────────
//  FRESHNESS DECAY TESTS — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Tests for the two-tier freshness decay model:
// - Annual: full weight for 12 months, linear decay to 0.3 at 36 months
// - Volatile: full weight for 3 months, linear decay to 0.3 at 12 months
//
// All tests use fixed DateTime for deterministic assertions.
// See: BIO-06, BIO-08 requirements.
// ────────────────────────────────────────────────────────────

/// Helper: create a BiographyFact with a specific updatedAt for decay testing.
BiographyFact _factAt({
  required DateTime updatedAt,
  String freshnessCategory = 'annual',
  FactType factType = FactType.salary,
}) {
  return BiographyFact(
    id: 'test-${updatedAt.toIso8601String()}',
    factType: factType,
    value: '100000',
    source: FactSource.document,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    freshnessCategory: freshnessCategory,
  );
}

void main() {
  // Fixed reference time for all tests.
  final now = DateTime(2026, 4, 6);

  // ── Annual Tier Tests ──────────────────────────────────────

  group('Annual freshness decay', () {
    test('0 months old -> weight 1.0', () {
      final fact = _factAt(
        updatedAt: now,
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.weight(fact, now), 1.0);
    });

    test('6 months old -> weight 1.0 (within full-weight window)', () {
      final fact = _factAt(
        updatedAt: DateTime(2025, 10, 6),
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.weight(fact, now), 1.0);
    });

    test('12 months old -> weight 1.0 (boundary of full-weight window)', () {
      final fact = _factAt(
        updatedAt: DateTime(2025, 4, 6),
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.weight(fact, now), closeTo(1.0, 0.02));
    });

    test('24 months old -> weight ~0.65 (midpoint of linear decay)', () {
      final fact = _factAt(
        updatedAt: DateTime(2024, 4, 6),
        freshnessCategory: 'annual',
      );
      final w = FreshnessDecayService.weight(fact, now);
      expect(w, closeTo(0.65, 0.05));
    });

    test('36 months old -> weight 0.3 (floor)', () {
      final fact = _factAt(
        updatedAt: DateTime(2023, 4, 6),
        freshnessCategory: 'annual',
      );
      final w = FreshnessDecayService.weight(fact, now);
      expect(w, closeTo(0.3, 0.02));
    });

    test('48 months old -> weight 0.3 (capped at floor)', () {
      final fact = _factAt(
        updatedAt: DateTime(2022, 4, 6),
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.weight(fact, now), 0.3);
    });
  });

  // ── Volatile Tier Tests ────────────────────────────────────

  group('Volatile freshness decay', () {
    test('0 months old -> weight 1.0', () {
      final fact = _factAt(
        updatedAt: now,
        freshnessCategory: 'volatile',
      );
      expect(FreshnessDecayService.weight(fact, now), 1.0);
    });

    test('3 months old -> weight 1.0 (boundary of full-weight window)', () {
      final fact = _factAt(
        updatedAt: DateTime(2026, 1, 6),
        freshnessCategory: 'volatile',
      );
      final w = FreshnessDecayService.weight(fact, now);
      expect(w, closeTo(1.0, 0.02));
    });

    test('7.5 months old -> weight ~0.65 (midpoint of linear decay)', () {
      // 7.5 months before April 6, 2026 = ~August 21, 2025
      final fact = _factAt(
        updatedAt: DateTime(2025, 8, 21),
        freshnessCategory: 'volatile',
      );
      final w = FreshnessDecayService.weight(fact, now);
      expect(w, closeTo(0.65, 0.08));
    });

    test('12 months old -> weight 0.3 (floor)', () {
      final fact = _factAt(
        updatedAt: DateTime(2025, 4, 6),
        freshnessCategory: 'volatile',
      );
      final w = FreshnessDecayService.weight(fact, now);
      expect(w, closeTo(0.3, 0.02));
    });
  });

  // ── needsRefresh Tests ─────────────────────────────────────

  group('needsRefresh', () {
    test('returns true when weight < 0.60', () {
      // 30 months old annual -> well into decay zone
      final fact = _factAt(
        updatedAt: DateTime(2023, 10, 6),
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.needsRefresh(fact, now), isTrue);
    });

    test('returns false when weight >= 0.60', () {
      // 6 months old annual -> weight 1.0
      final fact = _factAt(
        updatedAt: DateTime(2025, 10, 6),
        freshnessCategory: 'annual',
      );
      expect(FreshnessDecayService.needsRefresh(fact, now), isFalse);
    });
  });

  // ── categoryFor Tests ──────────────────────────────────────

  group('categoryFor', () {
    test('salary returns annual', () {
      expect(FreshnessDecayService.categoryFor(FactType.salary), 'annual');
    });

    test('lppCapital returns annual', () {
      expect(
          FreshnessDecayService.categoryFor(FactType.lppCapital), 'annual');
    });

    test('threeACapital returns annual', () {
      expect(FreshnessDecayService.categoryFor(FactType.threeACapital),
          'annual');
    });

    test('mortgageDebt returns volatile', () {
      expect(FreshnessDecayService.categoryFor(FactType.mortgageDebt),
          'volatile');
    });

    test('lifeEvent returns annual (default)', () {
      expect(
          FreshnessDecayService.categoryFor(FactType.lifeEvent), 'annual');
    });
  });
}
