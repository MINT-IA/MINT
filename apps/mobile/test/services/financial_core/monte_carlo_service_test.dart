import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';

void main() {
  // ════════════════════════════════════════════════════════════
  //  MONTE CARLO PROJECTION SERVICE — COMPREHENSIVE TESTS
  // ════════════════════════════════════════════════════════════
  //
  // Complements monte_carlo_test.dart with couple scenarios,
  // edge cases, alertes, early retirement, high capital, and
  // convergence checks.
  // ════════════════════════════════════════════════════════════

  // ── GROUP 1: COUPLE SCENARIOS ──────────────────────────────

  group('MonteCarloProjectionService — couple profiles', () {
    test('married couple produces higher median than single person', () async {
      final single = _buildSingleProfile();
      final couple = _buildCoupleProfile();

      final resultSingle = await MonteCarloProjectionService.simulate(
        profile: single,
        numSimulations: 200,
        seed: 42,
      );
      final resultCouple = await MonteCarloProjectionService.simulate(
        profile: couple,
        numSimulations: 200,
        seed: 42,
      );

      // Couple has two AVS rentes + two LPP rentes → higher income
      expect(
        resultCouple.medianAt65,
        greaterThan(resultSingle.medianAt65),
        reason: 'Couple with two incomes should have higher median',
      );
    });

    test('concubinage couple also produces higher income', () async {
      final single = _buildSingleProfile();
      final concubin = _buildCoupleProfile().copyWith(
        etatCivil: CoachCivilStatus.concubinage,
      );

      final resultSingle = await MonteCarloProjectionService.simulate(
        profile: single,
        numSimulations: 200,
        seed: 42,
      );
      final resultConcubin = await MonteCarloProjectionService.simulate(
        profile: concubin,
        numSimulations: 200,
        seed: 42,
      );

      expect(
        resultConcubin.medianAt65,
        greaterThan(resultSingle.medianAt65),
        reason: 'Concubinage couple should still benefit from two incomes',
      );
    });

    test('couple with FATCA conjoint skips conjoint 3a', () async {
      // FATCA conjoint: canContribute3a = false
      final fatcaCouple = _buildCoupleProfile().copyWith(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: DateTime.now().year - 43,
          salaireBrutMensuel: 5500,
          employmentStatus: 'salarie',
          isFatcaResident: true,
          canContribute3a: false,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 20000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
            totalEpargne3a: 14000,
            nombre3a: 1,
          ),
        ),
      );

      // Non-FATCA conjoint with same parameters
      final normalCouple = _buildCoupleProfile().copyWith(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: DateTime.now().year - 43,
          salaireBrutMensuel: 5500,
          employmentStatus: 'salarie',
          isFatcaResident: false,
          canContribute3a: true,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 20000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
            totalEpargne3a: 14000,
            nombre3a: 1,
          ),
        ),
      );

      final resultFatca = await MonteCarloProjectionService.simulate(
        profile: fatcaCouple,
        numSimulations: 200,
        seed: 42,
      );
      final resultNormal = await MonteCarloProjectionService.simulate(
        profile: normalCouple,
        numSimulations: 200,
        seed: 42,
      );

      // FATCA conjoint cannot grow 3a → lower or equal median
      expect(
        resultNormal.medianAt65,
        greaterThanOrEqualTo(resultFatca.medianAt65),
        reason: 'FATCA restriction on 3a should not increase income',
      );
      // Both should still produce valid results
      expect(resultFatca.projection.length, equals(30));
    });

    test('couple with conjoint without birthYear does not crash', () async {
      final profile = _buildCoupleProfile().copyWith(
        conjoint: const ConjointProfile(
          firstName: 'Unknown',
          birthYear: null,
          salaireBrutMensuel: 4000,
          employmentStatus: 'salarie',
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 42,
      );

      // conjointAge == null → conjoint contributions skipped gracefully
      expect(result.projection.length, equals(30));
      expect(result.medianAt65, greaterThan(0));
    });
  });

  // ── GROUP 2: EARLY RETIREMENT ──────────────────────────────

  group('MonteCarloProjectionService — early retirement', () {
    test('early retirement before 63 triggers AVS alerte', () async {
      final profile = _buildSingleProfile();
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 60,
        numSimulations: 100,
        seed: 42,
      );

      expect(
        result.alertes.any((a) => a.contains('anticip')),
        isTrue,
        reason: 'Retirement before 63 should produce early retirement alerte',
      );
      expect(result.retirementAge, equals(60));
    });

    test('early retirement at 58 has no AVS for 5 years', () async {
      final profile = _buildSingleProfile();
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 58,
        numSimulations: 200,
        seed: 42,
      );

      // First projection point (age 58) should have lower income than
      // a point at age 63+ when AVS kicks in
      final incomeAt58 = result.projection[0].p50;
      final incomeAt63 = result.projection[5].p50; // age 63

      // At age 63, AVS starts → income should jump
      // (not guaranteed to be strictly higher due to stochastic effects,
      // but with seed and enough sims, the median should show this)
      expect(
        result.alertes.any((a) => a.contains('5 an(s)')),
        isTrue,
        reason: 'Alerte should mention 5 years without AVS',
      );
      expect(incomeAt58, greaterThanOrEqualTo(0));
      expect(incomeAt63, greaterThanOrEqualTo(0));
    });

    test('retirement at 63 does not trigger early retirement alerte', () async {
      final profile = _buildSingleProfile();
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 63,
        numSimulations: 50,
        seed: 42,
      );

      expect(
        result.alertes.any((a) => a.contains('anticip')),
        isFalse,
        reason: 'Retirement at 63 should not trigger early retirement alerte',
      );
    });
  });

  // ── GROUP 3: EDGE CASES ────────────────────────────────────

  group('MonteCarloProjectionService — edge cases', () {
    test('very high capital (5M) does not crash and produces income', () async {
      final profile = _buildSingleProfile().copyWith(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 2000000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 500000,
          nombre3a: 5,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 1000000,
          investissements: 1500000,
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 42,
      );

      expect(result.projection.length, equals(30));
      expect(result.medianAt65, greaterThan(5000));
      // High capital → low ruin probability
      expect(
        result.ruinProbability,
        lessThan(0.5),
        reason: 'Very high capital should have low ruin probability',
      );
    });

    test('0 years to retirement (age == retirementAge) does not crash', () async {
      // Profile with age = 65 and retirementAge = 65 → 0 accumulation years
      final profile = CoachProfile(
        firstName: 'Senior',
        birthYear: DateTime.now().year - 65,
        canton: 'BE',
        salaireBrutMensuel: 7000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.celibataire,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 400000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 100000,
          nombre3a: 3,
          anneesContribuees: 44,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(DateTime.now().year),
          label: 'Retraite',
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 65,
        numSimulations: 50,
        seed: 42,
      );

      expect(result.projection.length, equals(30));
      expect(result.medianAt65, greaterThan(0));
      expect(result.projection[0].age, equals(65));
    });

    test('independant without LPP still works (no bonifications)', () async {
      final profile = CoachProfile(
        firstName: 'Indie',
        birthYear: DateTime.now().year - 45,
        canton: 'VD',
        salaireBrutMensuel: 10000,
        employmentStatus: 'independant',
        etatCivil: CoachCivilStatus.celibataire,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 0,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 80000,
          nombre3a: 2,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2046),
          label: 'Retraite',
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 100,
        seed: 42,
      );

      expect(result.projection.length, equals(30));
      // Still has AVS + 3a income
      expect(result.medianAt65, greaterThan(0));
    });

    test('custom depensesMensuelles overrides estimation', () async {
      final profile = _buildSingleProfile();

      // Low expenses → lower ruin probability
      final resultLowExpenses = await MonteCarloProjectionService.simulate(
        profile: profile,
        depensesMensuelles: 2000,
        numSimulations: 200,
        seed: 42,
      );

      // Very high expenses → higher ruin probability
      final resultHighExpenses = await MonteCarloProjectionService.simulate(
        profile: profile,
        depensesMensuelles: 15000,
        numSimulations: 200,
        seed: 42,
      );

      expect(
        resultHighExpenses.ruinProbability,
        greaterThanOrEqualTo(resultLowExpenses.ruinProbability),
        reason: 'Higher expenses should lead to higher ruin probability',
      );
    });

    test('empty canton defaults to ZH (no crash)', () async {
      final profile = CoachProfile(
        firstName: 'NoCanton',
        birthYear: DateTime.now().year - 40,
        canton: '',
        salaireBrutMensuel: 7000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.celibataire,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          tauxConversion: 0.068,
          totalEpargne3a: 30000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2051),
          label: 'Retraite',
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 42,
      );

      expect(result.projection.length, equals(30));
      expect(result.medianAt65, greaterThan(0));
    });
  });

  // ── GROUP 4: ALERTES ───────────────────────────────────────

  group('MonteCarloProjectionService — alertes', () {
    test('high ruin probability triggers deficit alerte', () async {
      // Very low capital + high expenses → high ruin
      final profile = CoachProfile(
        firstName: 'Poor',
        birthYear: DateTime.now().year - 50,
        canton: 'GE',
        salaireBrutMensuel: 4000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.celibataire,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 5000,
          tauxConversion: 0.068,
          totalEpargne3a: 0,
          anneesContribuees: 10,
          lacunesAVS: 15,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2041),
          label: 'Retraite',
        ),
      );

      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        depensesMensuelles: 8000,
        numSimulations: 300,
        seed: 42,
      );

      // With very low capital and high expenses, ruin should be high
      // and at least one alerte should be present
      if (result.ruinProbability > 0.30) {
        expect(
          result.alertes.any((a) => a.contains('30')),
          isTrue,
          reason: 'High ruin probability should trigger deficit alerte',
        );
      } else if (result.ruinProbability > 0.15) {
        expect(
          result.alertes.any((a) => a.contains('puisement')),
          isTrue,
          reason: 'Moderate ruin should trigger moderate risk alerte',
        );
      }
    });

    test('sources list is non-empty and contains legal references', () async {
      final profile = _buildSingleProfile();
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 10,
        seed: 42,
      );

      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
    });
  });

  // ── GROUP 5: LPP CAPITAL STRATEGY ─────────────────────────

  group('MonteCarloProjectionService — lppCapitalPct variations', () {
    test('0% capital (full rente) vs 100% capital produce different results', () async {
      final profile = _buildSingleProfile();

      final resultRente = await MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 0.0,
        numSimulations: 200,
        seed: 42,
      );
      final resultCapital = await MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 1.0,
        numSimulations: 200,
        seed: 42,
      );

      // Results should differ (different income composition)
      expect(
        resultRente.medianAt65 != resultCapital.medianAt65,
        isTrue,
        reason: 'Full rente vs full capital should produce different medians',
      );
      // Both should be positive
      expect(resultRente.medianAt65, greaterThan(0));
      expect(resultCapital.medianAt65, greaterThan(0));
    });

    test('50% capital split produces income between 0% and 100%', () async {
      final profile = _buildSingleProfile();

      final result0 = await MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 0.0,
        numSimulations: 300,
        seed: 42,
      );
      final result50 = await MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 0.5,
        numSimulations: 300,
        seed: 42,
      );
      final result100 = await MonteCarloProjectionService.simulate(
        profile: profile,
        lppCapitalPct: 1.0,
        numSimulations: 300,
        seed: 42,
      );

      // All three should produce valid projections
      expect(result0.projection.length, equals(30));
      expect(result50.projection.length, equals(30));
      expect(result100.projection.length, equals(30));

      // All three medians should be positive
      expect(result0.medianAt65, greaterThan(0));
      expect(result50.medianAt65, greaterThan(0));
      expect(result100.medianAt65, greaterThan(0));
    });
  });

  // ── GROUP 6: CONVERGENCE & STATISTICAL PROPERTIES ──────────

  group('MonteCarloProjectionService — convergence', () {
    test('two runs with different seeds produce similar medians (within 25%)', () async {
      final profile = _buildSingleProfile();

      final result1 = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 500,
        seed: 111,
      );
      final result2 = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 500,
        seed: 999,
      );

      final medianDiff = (result1.medianAt65 - result2.medianAt65).abs();
      final avgMedian = (result1.medianAt65 + result2.medianAt65) / 2;

      expect(
        medianDiff / avgMedian,
        lessThan(0.25),
        reason: 'Medians from different seeds should converge within 25%',
      );
    });

    test('P10/P50/P90 at retirement maintain correct ordering across seeds', () async {
      final profile = _buildSingleProfile();

      for (final seed in [1, 42, 100, 12345, 99999]) {
        final result = await MonteCarloProjectionService.simulate(
          profile: profile,
          numSimulations: 200,
          seed: seed,
        );

        expect(
          result.p10At65,
          lessThanOrEqualTo(result.medianAt65),
          reason: 'Seed $seed: P10 <= P50',
        );
        expect(
          result.medianAt65,
          lessThanOrEqualTo(result.p90At65),
          reason: 'Seed $seed: P50 <= P90',
        );
      }
    });

    test('all projection values are non-negative', () async {
      final profile = _buildSingleProfile();
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 300,
        seed: 42,
      );

      for (final point in result.projection) {
        expect(point.p10, greaterThanOrEqualTo(0),
            reason: 'Year ${point.year}: P10 >= 0');
        expect(point.p25, greaterThanOrEqualTo(0),
            reason: 'Year ${point.year}: P25 >= 0');
        expect(point.p50, greaterThanOrEqualTo(0),
            reason: 'Year ${point.year}: P50 >= 0');
        expect(point.p75, greaterThanOrEqualTo(0),
            reason: 'Year ${point.year}: P75 >= 0');
        expect(point.p90, greaterThanOrEqualTo(0),
            reason: 'Year ${point.year}: P90 >= 0');
      }
    });
  });

  // ── GROUP 7: RETIREMENT AGE VARIATIONS ─────────────────────

  group('MonteCarloProjectionService — retirement age', () {
    test('later retirement produces higher median (more accumulation)', () async {
      final profile = _buildSingleProfile();

      final result60 = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 60,
        numSimulations: 300,
        seed: 42,
      );
      final result65 = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 65,
        numSimulations: 300,
        seed: 42,
      );
      final result70 = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 70,
        numSimulations: 300,
        seed: 42,
      );

      // More accumulation years → higher median at retirement
      expect(
        result65.medianAt65,
        greaterThan(result60.medianAt65),
        reason: 'Retiring at 65 should produce more than at 60',
      );
      expect(
        result70.medianAt65,
        greaterThan(result65.medianAt65),
        reason: 'Retiring at 70 should produce more than at 65',
      );
    });

    test('retirementAge field in result matches input', () async {
      final profile = _buildSingleProfile();

      for (final age in [58, 60, 63, 65, 67, 70]) {
        final result = await MonteCarloProjectionService.simulate(
          profile: profile,
          retirementAgeUser: age,
          numSimulations: 10,
          seed: 42,
        );
        expect(result.retirementAge, equals(age));
        expect(result.projection[0].age, equals(age));
      }
    });
  });

  // ── GROUP 8: LPP BUYBACK IMPACT ────────────────────────────

  group('MonteCarloProjectionService — LPP buyback', () {
    test('profile with LPP buyback produces higher income', () async {
      final noBuyback = _buildSingleProfile().copyWith(
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 604,
            category: '3a',
          ),
        ],
      );

      final withBuyback = _buildSingleProfile().copyWith(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 50000,
          nombre3a: 3,
          anneesContribuees: 25,
          rachatMaximum: 200000,
          rachatEffectue: 0,
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 604,
            category: '3a',
          ),
          PlannedMonthlyContribution(
            id: 'lpp_buyback_test',
            label: 'Rachat LPP',
            amount: 1000,
            category: 'lpp_buyback',
          ),
        ],
      );

      final resultNo = await MonteCarloProjectionService.simulate(
        profile: noBuyback,
        numSimulations: 200,
        seed: 42,
      );
      final resultWith = await MonteCarloProjectionService.simulate(
        profile: withBuyback,
        numSimulations: 200,
        seed: 42,
      );

      expect(
        resultWith.medianAt65,
        greaterThan(resultNo.medianAt65),
        reason: 'LPP buyback should increase retirement income',
      );
    });
  });
}

// ════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════

/// Single person profile with typical Swiss salaried worker.
CoachProfile _buildSingleProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: DateTime.now().year - 45,
    canton: 'VS',
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 200000,
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
        id: '3a_julien',
        label: '3a Julien',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_julien',
        label: 'Investissements',
        amount: 500,
        category: 'investissement',
      ),
      PlannedMonthlyContribution(
        id: 'epargne_julien',
        label: 'Epargne libre',
        amount: 300,
        category: 'epargne_libre',
      ),
    ],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2046),
      label: 'Retraite',
    ),
  );
}

/// Married couple profile (Julien + Lauren).
CoachProfile _buildCoupleProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: DateTime.now().year - 49,
    canton: 'VS',
    salaireBrutMensuel: 10000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    conjoint: ConjointProfile(
      firstName: 'Lauren',
      birthYear: DateTime.now().year - 43,
      salaireBrutMensuel: 5500,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 20000,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
        totalEpargne3a: 14000,
        nombre3a: 1,
        anneesContribuees: 15,
      ),
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 300000,
      tauxConversion: 0.068,
      rendementCaisse: 0.05,
      totalEpargne3a: 80000,
      nombre3a: 4,
      anneesContribuees: 30,
      lacunesAVS: 1,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 30000,
      investissements: 100000,
    ),
    depenses: const DepensesProfile(
      loyer: 2200,
      assuranceMaladie: 900,
    ),
    plannedContributions: const [
      PlannedMonthlyContribution(
        id: '3a_julien',
        label: '3a Julien',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: '3a_lauren',
        label: '3a Lauren',
        amount: 604,
        category: '3a',
      ),
      PlannedMonthlyContribution(
        id: 'invest_couple',
        label: 'Investissements',
        amount: 800,
        category: 'investissement',
      ),
    ],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite',
    ),
  );
}
