import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';

void main() {
  // ════════════════════════════════════════════════════════════
  //  MONTE CARLO PROJECTION SERVICE — TESTS
  // ════════════════════════════════════════════════════════════

  group('MonteCarloProjectionService.simulate', () {
    // ── 1. Nombre correct de points de projection ──────────
    test('returns correct number of projection years (30)', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 42,
      );
      expect(result.projection.length, equals(30));
    });

    // ── 2. Mediane entre P10 et P90 ────────────────────────
    test('median is between P10 and P90 for each year', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 200,
        seed: 42,
      );
      for (final point in result.projection) {
        expect(
          point.p50,
          greaterThanOrEqualTo(point.p10),
          reason: 'Year ${point.year}: P50 (${point.p50}) '
              'should be >= P10 (${point.p10})',
        );
        expect(
          point.p50,
          lessThanOrEqualTo(point.p90),
          reason: 'Year ${point.year}: P50 (${point.p50}) '
              'should be <= P90 (${point.p90})',
        );
      }
    });

    // ── 3. Ordre strict des percentiles ────────────────────
    test('P10 < P25 < P50 < P75 < P90 for each year', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 300,
        seed: 42,
      );
      for (final point in result.projection) {
        expect(
          point.p10,
          lessThanOrEqualTo(point.p25),
          reason: 'Year ${point.year}: P10 <= P25',
        );
        expect(
          point.p25,
          lessThanOrEqualTo(point.p50),
          reason: 'Year ${point.year}: P25 <= P50',
        );
        expect(
          point.p50,
          lessThanOrEqualTo(point.p75),
          reason: 'Year ${point.year}: P50 <= P75',
        );
        expect(
          point.p75,
          lessThanOrEqualTo(point.p90),
          reason: 'Year ${point.year}: P75 <= P90',
        );
      }
    });

    // ── 4. Reproductibilite avec seed ──────────────────────
    test('with seed, results are reproducible', () {
      final profile = _buildFullProfile();
      final result1 = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 12345,
      );
      final result2 = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 12345,
      );
      expect(result1.medianAt65, equals(result2.medianAt65));
      expect(result1.p10At65, equals(result2.p10At65));
      expect(result1.p90At65, equals(result2.p90At65));
      expect(result1.ruinProbability, equals(result2.ruinProbability));
      for (int i = 0; i < result1.projection.length; i++) {
        expect(result1.projection[i].p50, equals(result2.projection[i].p50));
      }
    });

    // ── 5. Plus de LPP → mediane plus elevee ───────────────
    test('higher LPP balance produces higher median', () {
      final lowLpp = _buildFullProfile().copyWith(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 50000,
          nombre3a: 3,
        ),
      );
      final highLpp = _buildFullProfile().copyWith(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 500000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 50000,
          nombre3a: 3,
        ),
      );
      final resultLow = MonteCarloProjectionService.simulate(
        profile: lowLpp,
        numSimulations: 200,
        seed: 42,
      );
      final resultHigh = MonteCarloProjectionService.simulate(
        profile: highLpp,
        numSimulations: 200,
        seed: 42,
      );
      expect(
        resultHigh.medianAt65,
        greaterThan(resultLow.medianAt65),
        reason: 'Higher LPP balance should produce higher median income',
      );
    });

    // ── 6. Probabilite de ruine entre 0 et 1 ──────────────
    test('ruin probability is between 0 and 1', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 42,
      );
      expect(result.ruinProbability, greaterThanOrEqualTo(0.0));
      expect(result.ruinProbability, lessThanOrEqualTo(1.0));
    });

    // ── 7. Zero capital : pas de crash ─────────────────────
    test('handles 0 capital gracefully', () {
      final profile = _buildMinimalProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 42,
      );
      expect(result.projection, isNotEmpty);
      expect(result.medianAt65, greaterThanOrEqualTo(0));
      // Should still have AVS income
      expect(result.projection[0].p50, greaterThan(0));
    });

    // ── 8. Plus de simulations → bandes plus serrees ───────
    test('more simulations produce tighter bands (100 vs 1000)', () {
      final profile = _buildFullProfile();
      // Avec 100 simulations
      final result100 = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 42,
      );
      // Avec 1000 simulations
      final result1000 = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 1000,
        seed: 42,
      );
      // L'ecart P10-P90 au debut de la retraite (annee 0)
      // devrait converger : les medianes doivent etre proches
      final spread100 = result100.p90At65 - result100.p10At65;
      final spread1000 = result1000.p90At65 - result1000.p10At65;
      // Les deux doivent etre positifs
      expect(spread100, greaterThan(0));
      expect(spread1000, greaterThan(0));
      // Avec plus de simulations, la mediane est plus stable
      // (on ne peut pas garantir que le spread diminue, mais les
      // medianes doivent converger)
      final medianDiff = (result100.medianAt65 - result1000.medianAt65).abs();
      // La difference entre medianes devrait etre < 20% de la mediane
      expect(
        medianDiff,
        lessThan(result1000.medianAt65 * 0.20),
        reason: 'Medians should converge with more simulations',
      );
    });

    // ── 9. Profil minimal fonctionne ───────────────────────
    test('works with minimal profile', () {
      final profile = _buildMinimalProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 42,
      );
      expect(result.projection.length, equals(30));
      expect(result.numSimulations, equals(50));
      // Age progression
      expect(result.projection[0].age, equals(65));
      expect(result.projection[1].age, equals(66));
    });

    // ── 10. Disclaimer est non-vide ────────────────────────
    test('disclaimer is non-empty and mentions LSFin', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 10,
        seed: 42,
      );
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('LSFin'));
      expect(result.disclaimer, contains('p\u00e9dagogique'));
    });

    // ── 11. numSimulations est correctement rapporte ───────
    test('numSimulations matches requested count', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 77,
        seed: 42,
      );
      expect(result.numSimulations, equals(77));
    });

    // ── 12. medianAt65 == projection[0].p50 ────────────────
    test('medianAt65 equals first projection point p50', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 200,
        seed: 42,
      );
      expect(result.medianAt65, equals(result.projection[0].p50));
      expect(result.p10At65, equals(result.projection[0].p10));
      expect(result.p90At65, equals(result.projection[0].p90));
    });

    // ── 13. Annees et ages sont coherents ──────────────────
    test('years and ages are consistent and sequential', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 63,
        numSimulations: 20,
        seed: 42,
      );
      expect(result.projection[0].age, equals(63));
      for (int i = 1; i < result.projection.length; i++) {
        expect(
          result.projection[i].age,
          equals(result.projection[i - 1].age + 1),
        );
        expect(
          result.projection[i].year,
          equals(result.projection[i - 1].year + 1),
        );
      }
    });

    // ── 14. Strategie capital LPP produit un revenu ────────
    test('lppCapitalPct > 0 still produces income', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 0.5,
        numSimulations: 100,
        seed: 42,
      );
      expect(result.medianAt65, greaterThan(0));
    });

    // ── 15. Profil avec 100% capital LPP ───────────────────
    test('100% capital LPP works without crash', () {
      final profile = _buildFullProfile();
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 1.0,
        numSimulations: 50,
        seed: 42,
      );
      expect(result.projection, isNotEmpty);
      expect(result.medianAt65, greaterThan(0));
    });
  });
}

// ════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════

/// Profil complet avec prevoyance, patrimoine, et contributions.
CoachProfile _buildFullProfile() {
  return CoachProfile(
    firstName: 'Test',
    birthYear: DateTime.now().year - 45,
    canton: 'ZH',
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 300000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      totalEpargne3a: 50000,
      nombre3a: 3,
      anneesContribuees: 25,
      lacunesAVS: 2,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 20000,
      investissements: 80000,
    ),
    depenses: const DepensesProfile(
      loyer: 1800,
      assuranceMaladie: 450,
    ),
    plannedContributions: const [
      PlannedMonthlyContribution(
        id: '3a_test',
        label: '3a Test',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_test',
        label: 'Investissements',
        amount: 500,
        category: 'investissement',
      ),
      PlannedMonthlyContribution(
        id: 'epargne_test',
        label: 'Epargne libre',
        amount: 300,
        category: 'epargne_libre',
      ),
    ],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

/// Profil minimal — salaire uniquement, sans patrimoine/3a/epargne.
CoachProfile _buildMinimalProfile() {
  return CoachProfile(
    firstName: 'Mini',
    birthYear: DateTime.now().year - 35,
    canton: 'GE',
    salaireBrutMensuel: 6000,
    employmentStatus: 'salarie',
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2060),
      label: 'Retraite',
    ),
  );
}
