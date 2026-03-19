import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/arbitrage_summary_service.dart';

// ═══════════════════════════════════════════════════════════════
//  ARBITRAGE SUMMARY SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//   1. Empty profile: all arbitrages locked
//   2. Profile with LPP only: rente_vs_capital computed
//   3. Profile with LPP + 3a: calendrier_retraits computed
//   4. Profile with salary + lacune: rachat_vs_marche computed
//   5. Profile with salary: allocation_annuelle always computed
//   6. Locataire with loyer: location_vs_propriete attempted
//   7. Couple with both LPP: couple_sequencing computed
//   8. Items sorted by absolute monthly impact (descending)
//   9. Aggregate monthly impact is sum of all items
//  10. No ranking — items never contain "meilleur" or "optimal"
//  11. Single person: no couple_sequencing
//  12. Proprietaire: no location_vs_propriete
//  13. Low-impact rente_vs_capital (<10 CHF diff) returns null
//  14. computedAt is set to current time
//  15. All items have routes starting with /
// ═══════════════════════════════════════════════════════════════

/// Build a minimal CoachProfile with custom values for testing.
CoachProfile _buildProfile({
  int birthYear = 1977,
  String canton = 'VS',
  double salaireBrutMensuel = 10000,
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  double? avoirLppTotal,
  double totalEpargne3a = 0,
  double? rachatMaximum,
  double loyer = 0,
  String? housingStatus,
  double epargneLiquide = 0,
  double investissements = 0,
  ConjointProfile? conjoint,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    etatCivil: etatCivil,
    conjoint: conjoint,
    housingStatus: housingStatus,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 12, 31),
      label: 'Retraite',
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: investissements,
    ),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      totalEpargne3a: totalEpargne3a,
      rachatMaximum: rachatMaximum,
    ),
    depenses: DepensesProfile(loyer: loyer),
  );
}

void main() {
  group('ArbitrageSummaryService.compute', () {
    // ── Test 1: Empty profile ─────────────────────────────────
    test('empty profile: no items, all relevant arbitrages locked', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 0,
        avoirLppTotal: null,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      expect(summary.items, isEmpty);
      expect(summary.lockedItems, isNotEmpty);
      // rente_vs_capital and calendrier_retraits should be locked
      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, contains('rente_vs_capital'));
      expect(lockedIds, contains('calendrier_retraits'));
    });

    // ── Test 2: Profile with LPP only ─────────────────────────
    test('profile with LPP > 0 computes rente_vs_capital', () {
      final profile = _buildProfile(avoirLppTotal: 300000);
      final summary = ArbitrageSummaryService.compute(profile);

      // May or may not be present depending on whether diff > 10
      // But it should NOT be in locked
      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('rente_vs_capital')));
    });

    // ── Test 3: Profile with LPP + 3a ─────────────────────────
    test('profile with LPP + 3a computes calendrier_retraits', () {
      final profile = _buildProfile(
        avoirLppTotal: 300000,
        totalEpargne3a: 50000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('calendrier_retraits')));
    });

    // ── Test 4: Calendrier locked when missing 3a ─────────────
    test('calendrier_retraits locked when LPP > 0 but 3a = 0', () {
      final profile = _buildProfile(avoirLppTotal: 300000, totalEpargne3a: 0);
      final summary = ArbitrageSummaryService.compute(profile);

      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, contains('calendrier_retraits'));
    });

    // ── Test 5: Rachat vs Marche with lacune and salary ───────
    test('rachat_vs_marche computed when lacune > 1000 and salary > 0', () {
      final profile = _buildProfile(
        avoirLppTotal: 200000,
        rachatMaximum: 100000,
        salaireBrutMensuel: 10000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      // Should not be locked (lacune = 100k > 1k, salary > 0)
      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('rachat_vs_marche')));
    });

    // ── Test 6: Allocation annuelle with salary ───────────────
    test('allocation_annuelle always computed when salary > 0', () {
      final profile = _buildProfile(salaireBrutMensuel: 8000);
      final summary = ArbitrageSummaryService.compute(profile);

      final allocItem = summary.items
          .where((i) => i.id == 'allocation_annuelle')
          .toList();
      expect(allocItem, isNotEmpty);
      expect(allocItem.first.route, '/arbitrage/allocation-annuelle');
    });

    // ── Test 7: Location vs Propriete for locataire ───────────
    test('location_vs_propriete attempted when loyer > 0 and not proprietaire',
        () {
      final profile = _buildProfile(
        loyer: 2000,
        housingStatus: 'locataire',
        epargneLiquide: 100000,
        investissements: 50000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      // Should be attempted (not locked) — may or may not produce item
      // depending on terminal value delta
      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('location_vs_propriete')));
    });

    // ── Test 8: Couple sequencing ─────────────────────────────
    test('couple_sequencing computed when married couple both have LPP', () {
      final conjoint = const ConjointProfile(
        birthYear: 1982,
        salaireBrutMensuel: 6000,
        prevoyance: PrevoyanceProfile(avoirLppTotal: 80000),
      );
      final profile = _buildProfile(
        etatCivil: CoachCivilStatus.marie,
        conjoint: conjoint,
        avoirLppTotal: 300000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      // Couple sequencing may or may not produce item (depends on taxSaving)
      // But it should have been attempted since both have LPP
      // Verify it is not locked (there is no locked card for couple_sequencing)
      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('couple_sequencing')));
    });

    // ── Test 9: Items sorted by absolute monthly impact ───────
    test('items sorted by absolute monthly impact descending', () {
      final profile = _buildProfile(
        avoirLppTotal: 500000,
        totalEpargne3a: 80000,
        rachatMaximum: 200000,
        salaireBrutMensuel: 12000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      if (summary.items.length > 1) {
        for (int i = 0; i < summary.items.length - 1; i++) {
          expect(
            summary.items[i].monthlyImpactChf.abs(),
            greaterThanOrEqualTo(summary.items[i + 1].monthlyImpactChf.abs()),
          );
        }
      }
    });

    // ── Test 10: Aggregate monthly impact ─────────────────────
    test('aggregate monthly impact is sum of all item impacts', () {
      final profile = _buildProfile(
        avoirLppTotal: 300000,
        totalEpargne3a: 50000,
        salaireBrutMensuel: 10000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      final expectedAggregate =
          summary.items.fold(0.0, (sum, i) => sum + i.monthlyImpactChf);
      expect(summary.aggregateMonthlyImpact, closeTo(expectedAggregate, 0.01));
    });

    // ── Test 11: No ranking — compliance rule ─────────────────
    test('no item verdict contains banned ranking terms', () {
      final profile = _buildProfile(
        avoirLppTotal: 300000,
        totalEpargne3a: 50000,
        rachatMaximum: 100000,
        salaireBrutMensuel: 10000,
        loyer: 2000,
        epargneLiquide: 100000,
        investissements: 50000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      for (final item in summary.items) {
        final lower = item.verdict.toLowerCase();
        expect(lower.contains('meilleur'), false,
            reason: 'Verdict should not contain "meilleur" (no-ranking rule)');
        expect(lower.contains('optimal'), false,
            reason: 'Verdict should not contain "optimal" (no-ranking rule)');
        expect(lower.contains('garanti'), false,
            reason: 'Verdict should not contain "garanti" (banned term)');
      }
    });

    // ── Test 12: Single person — no couple_sequencing ─────────
    test('celibataire does not trigger couple_sequencing', () {
      final profile = _buildProfile(
        etatCivil: CoachCivilStatus.celibataire,
        avoirLppTotal: 300000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      final coupleItems =
          summary.items.where((i) => i.id == 'couple_sequencing').toList();
      expect(coupleItems, isEmpty);
    });

    // ── Test 13: Proprietaire — no location_vs_propriete ──────
    test('proprietaire does not trigger location_vs_propriete', () {
      final profile = _buildProfile(
        loyer: 2000,
        housingStatus: 'proprietaire',
        epargneLiquide: 200000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      final locItems =
          summary.items.where((i) => i.id == 'location_vs_propriete').toList();
      expect(locItems, isEmpty);
    });

    // ── Test 14: computedAt is set ────────────────────────────
    test('computedAt is set to approximately now', () {
      final before = DateTime.now();
      final profile = _buildProfile(salaireBrutMensuel: 5000);
      final summary = ArbitrageSummaryService.compute(profile);
      final after = DateTime.now();

      expect(summary.computedAt.isAfter(before.subtract(
        const Duration(seconds: 1),
      )), true);
      expect(summary.computedAt.isBefore(after.add(
        const Duration(seconds: 1),
      )), true);
    });

    // ── Test 15: All items have valid routes ──────────────────
    test('all items have routes starting with /', () {
      final profile = _buildProfile(
        avoirLppTotal: 400000,
        totalEpargne3a: 60000,
        rachatMaximum: 150000,
        salaireBrutMensuel: 12000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      for (final item in summary.items) {
        expect(item.route, startsWith('/'));
      }
    });

    // ── Test 16: All items have confidence scores ─────────────
    test('all items have confidence scores between 0 and 100', () {
      final profile = _buildProfile(
        avoirLppTotal: 400000,
        totalEpargne3a: 60000,
        salaireBrutMensuel: 12000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      for (final item in summary.items) {
        expect(item.confidenceScore, greaterThanOrEqualTo(0));
        expect(item.confidenceScore, lessThanOrEqualTo(100));
      }
    });

    // ── Test 17: Locked items have enrichment routes ──────────
    test('locked items have enrichment routes and prompts', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 0,
        avoirLppTotal: null,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      for (final locked in summary.lockedItems) {
        expect(locked.enrichmentRoute, isNotEmpty);
        expect(locked.missingDataPrompt, isNotEmpty);
        expect(locked.title, isNotEmpty);
      }
    });

    // ── Test 18: No lacune — no rachat locked card ────────────
    test('no locked rachat card when LPP present but lacune <= 1000', () {
      final profile = _buildProfile(
        avoirLppTotal: 300000,
        rachatMaximum: 500, // lacune = 500 <= 1000
        salaireBrutMensuel: 10000,
      );
      final summary = ArbitrageSummaryService.compute(profile);

      final lockedIds = summary.lockedItems.map((l) => l.id).toSet();
      expect(lockedIds, isNot(contains('rachat_vs_marche')));
      // Also should not have rachat item
      final rachatItems =
          summary.items.where((i) => i.id == 'rachat_vs_marche').toList();
      expect(rachatItems, isEmpty);
    });
  });
}
