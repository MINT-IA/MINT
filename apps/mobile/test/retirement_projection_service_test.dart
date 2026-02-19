import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// Tests for RetirementProjectionService
///
/// Covers: single/couple projection, LPP threshold guard, 3a cap for
/// independants, couple phase-aware early retirement, transition horizon,
/// AVS penalties/bonuses, couple 150% cap, budget gap, indexed projection.
// Default goalA for test profiles
GoalA _testGoalA() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 12, 31),
      label: 'Retraite',
    );

void main() {
  // ── Helper: demo profile (Julien 1977 + Lauren 1981, VS, marie) ───
  late CoachProfile demoProfile;

  setUp(() {
    demoProfile = CoachProfile.buildDemo();
  });

  // ════════════════════════════════════════════════════════════════
  //  BASIC PROJECTION (demo couple)
  // ════════════════════════════════════════════════════════════════

  group('Basic projection — demo couple', () {
    test('returns a valid result with all sections', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      expect(result.phases, isNotEmpty);
      expect(result.earlyRetirementComparisons.length, 8); // ages 63-70
      expect(result.budgetGap, isNotNull);
      expect(result.indexedProjection, isNotEmpty);
      expect(result.disclaimer, isNotEmpty);
      expect(result.sources, isNotEmpty);
    });

    test('demo couple has 2 phases (4-year age gap)', () {
      // Julien 1977 → retire 2042, Lauren 1981 → retire 2046
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      expect(result.phases.length, 2);
      expect(result.phases[0].startYear, 2042); // Julien first
      expect(result.phases[1].startYear, 2046); // Both retired
    });

    test('total monthly revenue at 65 is positive and reasonable', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      // Phase 2 (both retired): AVS + LPP + 3a + libre
      final phase2 = result.phases.last;
      final total =
          phase2.sources.fold(0.0, (sum, s) => sum + s.monthlyAmount);

      // Julien: AVS ~2520 + LPP rente + Lauren: AVS + LPP + 3a + libre
      expect(total, greaterThan(3000)); // At least 3k/month for couple
      expect(total, lessThan(20000)); // Sanity upper bound
    });

    test('replacement rate is between 0% and 150%', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      expect(result.budgetGap.tauxRemplacement, greaterThan(0));
      expect(result.budgetGap.tauxRemplacement, lessThan(150));
    });

    test('indexed projection has 25 points', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      expect(result.indexedProjection.length, greaterThanOrEqualTo(25));
      // Nominal increases over time (AVS indexation)
      final first = result.indexedProjection.first;
      final last = result.indexedProjection.last;
      expect(last.revenuNominal, greaterThanOrEqualTo(first.revenuNominal));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  SINGLE PERSON (no conjoint)
  // ════════════════════════════════════════════════════════════════

  group('Single person projection', () {
    late CoachProfile singleProfile;

    setUp(() {
      singleProfile = CoachProfile(
        firstName: 'Marc',
        birthYear: 1985,
        canton: 'GE',
        commune: 'Geneve',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 7000,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 400,
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 20000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 50000,
        ),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_marc',
            label: '3a Marc',
            amount: 604.83,
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );
    });

    test('single person has exactly 1 phase', () {
      final result = RetirementProjectionService.project(
        profile: singleProfile,
      );

      expect(result.phases.length, 1);
      expect(result.phases[0].label, 'Retraite');
    });

    test('single AVS not capped at 150%', () {
      final result = RetirementProjectionService.project(
        profile: singleProfile,
      );

      final avsSource = result.phases[0].sources.firstWhere(
        (s) => s.id == 'avs_user',
      );
      // Single: max AVS = 2520/month
      expect(avsSource.monthlyAmount, lessThanOrEqualTo(avsRenteMaxMensuelle));
    });

    test('no couple timeline sources', () {
      final result = RetirementProjectionService.project(
        profile: singleProfile,
      );

      // No salary_conjoint or avs_conjoint
      for (final source in result.phases[0].sources) {
        expect(source.id, isNot(contains('conjoint')));
      }
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  FIX 1: LPP THRESHOLD GUARD
  // ════════════════════════════════════════════════════════════════

  group('LPP below seuil entree (< 22680 CHF/an)', () {
    test('salary below threshold → no LPP bonifications accumulated', () {
      // 1500/month × 12 = 18000 < 22680 seuil
      final lowSalary = CoachProfile(
        firstName: 'Anna',
        birthYear: 1990,
        canton: 'ZH',
        commune: 'Zurich',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 1500,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 800, assuranceMaladie: 300),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 5000, // existing small balance
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 0,
        ),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
      );

      expect(lowSalary.revenuBrutAnnuel, lessThan(lppSeuilEntree));

      final result = RetirementProjectionService.project(
        profile: lowSalary,
      );

      final lppSource = result.phases[0].sources.where(
        (s) => s.id == 'lpp_user',
      );
      // LPP rente should be very small — only existing 5000 × compound
      // interest × conversion rate, NO new bonifications.
      if (lppSource.isNotEmpty) {
        // 5000 compounded at 2% for 25 years ≈ 8200 → × 0.068 = ~560/yr ≈ 47/month
        expect(lppSource.first.monthlyAmount, lessThan(100));
      }
    });

    test('salary at threshold → LPP bonifications apply', () {
      final atThreshold = CoachProfile(
        firstName: 'Bob',
        birthYear: 1990,
        canton: 'ZH',
        commune: 'Zurich',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 1890, // 1890 × 12 = 22680 exactly
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 800, assuranceMaladie: 300),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 5000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 0,
        ),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
      );

      expect(atThreshold.revenuBrutAnnuel, greaterThanOrEqualTo(lppSeuilEntree));

      final result = RetirementProjectionService.project(
        profile: atThreshold,
      );

      final lppSource = result.phases[0].sources.firstWhere(
        (s) => s.id == 'lpp_user',
      );
      // With bonifications, LPP rente should be significantly higher
      // than the below-threshold case
      expect(lppSource.monthlyAmount, greaterThan(100));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  FIX 2: 3A CAP FOR INDEPENDANTS SANS LPP
  // ════════════════════════════════════════════════════════════════

  group('3a cap — independant sans LPP vs salarie', () {
    test('independant sans LPP uses higher 3a cap (36288 CHF/an)', () {
      // Independant with high 3a contributions
      final indep = CoachProfile(
        firstName: 'Sophie',
        birthYear: 1985,
        canton: 'VD',
        commune: 'Lausanne',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 1500, // Low → below LPP threshold
        nombreDeMois: 12,
        employmentStatus: 'independant',
        depenses: const DepensesProfile(loyer: 1200, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 0,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 50000,
        ),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_sophie',
            label: '3a Sophie',
            amount: 2500, // 2500 × 12 = 30000/yr (within 36288 limit)
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );

      expect(indep.revenuBrutAnnuel, lessThan(lppSeuilEntree));

      final resultIndep = RetirementProjectionService.project(
        profile: indep,
      );

      // Same profile but as salarie
      final salarie = CoachProfile(
        firstName: 'Sophie',
        birthYear: 1985,
        canton: 'VD',
        commune: 'Lausanne',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 1500,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1200, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 0,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 50000,
        ),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_sophie',
            label: '3a Sophie',
            amount: 2500,
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );

      final resultSalarie = RetirementProjectionService.project(
        profile: salarie,
      );

      // Independant 3a should be higher because cap is 36288 vs 14516
      final threeAIndep = resultIndep.phases[0].sources
          .where((s) => s.id == '3a')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);
      final threeASalarie = resultSalarie.phases[0].sources
          .where((s) => s.id == '3a')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);

      // The independant should accumulate more 3a capital
      expect(threeAIndep, greaterThan(threeASalarie));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  FIX 3: TRANSITION PHASE HORIZON
  // ════════════════════════════════════════════════════════════════

  group('Transition phase — correct projection horizon', () {
    test('conjoint-first retirement projects 3a to conjoint horizon', () {
      // Build couple where conjoint retires first
      // User born 1985 (retire 2050 at 65), Conjoint born 1975 (retire 2040 at 65)
      final coupleCfirst = CoachProfile(
        firstName: 'Tom',
        birthYear: 1985,
        canton: 'GE',
        commune: 'Geneve',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
        conjoint: const ConjointProfile(
          firstName: 'Marie',
          birthYear: 1975,
          salaireBrutMensuel: 6000,
          nombreDeMois: 12,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 200000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
            totalEpargne3a: 10000,
          ),
        ),
        salaireBrutMensuel: 8000,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 700),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 30000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 50000,
        ),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_tom',
            label: '3a Tom',
            amount: 604.83,
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );

      final result = RetirementProjectionService.project(
        profile: coupleCfirst,
      );

      // Should have 2 phases: conjoint retires 2040, user retires 2050
      expect(result.phases.length, 2);
      expect(result.phases[0].startYear, 2040); // Marie retires first
      expect(result.phases[1].startYear, 2050); // Both retired

      // Phase 1 should include user salary (still working)
      final phase1SalaryUser = result.phases[0].sources
          .where((s) => s.id == 'salary_user')
          .toList();
      expect(phase1SalaryUser, isNotEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  FIX 4: EARLY RETIREMENT COUPLE COMPARISON
  // ════════════════════════════════════════════════════════════════

  group('Early retirement 63-70 — couple-aware', () {
    test('8 scenarios from age 63 to 70', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      expect(result.earlyRetirementComparisons.length, 8);
      expect(result.earlyRetirementComparisons.first.retirementAge, 63);
      expect(result.earlyRetirementComparisons.last.retirementAge, 70);
    });

    test('age 63 has negative AVS adjustment (penalty)', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final age63 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 63);
      // 2 years early × 6.8% = -13.6%
      expect(age63.adjustmentPct, closeTo(-13.6, 0.1));
    });

    test('age 65 has zero adjustment', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final age65 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 65);
      expect(age65.adjustmentPct, 0);
    });

    test('age 67+ has positive adjustment (deferral bonus)', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final age67 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 67);
      expect(age67.adjustmentPct, greaterThan(0));
    });

    test('revenue increases with later retirement age (user only AVS)', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      // AVS component should increase from 63 → 70 due to penalty/bonus
      final age63 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 63);
      final age70 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 70);

      // User's AVS at 70 should be higher than at 63
      final avsAt63 = age63.sources
          .where((s) => s.id == 'avs_user')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);
      final avsAt70 = age70.sources
          .where((s) => s.id == 'avs_user')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);
      expect(avsAt70, greaterThan(avsAt63));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  AVS COUPLE PLAFONNEMENT 150%
  // ════════════════════════════════════════════════════════════════

  group('AVS couple plafonnement 150%', () {
    test('couple AVS total does not exceed 3780 CHF/month', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      // Phase 2 (both retired): sum of AVS sources
      final phase2 = result.phases.last;
      final avsSources =
          phase2.sources.where((s) => s.id.startsWith('avs_'));
      final avsTotal =
          avsSources.fold(0.0, (sum, s) => sum + s.monthlyAmount);

      expect(avsTotal, lessThanOrEqualTo(avsRenteCoupleMaxMensuelle + 0.01));
    });

    test('transition phase AVS not capped (only one retiree)', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      // Phase 1: only Julien retired, Lauren still working
      final phase1 = result.phases.first;
      final avsPhase1 =
          phase1.sources.where((s) => s.id.startsWith('avs_'));

      // Should have only 1 AVS source (the retiree)
      expect(avsPhase1.length, 1);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  BUDGET GAP
  // ════════════════════════════════════════════════════════════════

  group('Budget gap', () {
    test('budget gap components are coherent', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
        depensesMensuelles: 5000,
      );

      final gap = result.budgetGap;
      expect(gap.depensesMensuelles, 5000);
      expect(gap.totalRevenusMensuel, greaterThan(0));
      expect(gap.impotEstimeMensuel, greaterThanOrEqualTo(0));

      // solde = revenus - impots - depenses
      final expectedSolde = gap.totalRevenusMensuel -
          gap.impotEstimeMensuel -
          gap.depensesMensuelles;
      expect(gap.soldeMensuel, closeTo(expectedSolde, 1));
    });

    test('replacement rate = total revenus / current net income × 100', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final gap = result.budgetGap;
      // Replacement rate should be > 0 and typically 40-120% for Swiss profiles
      expect(gap.tauxRemplacement, greaterThan(0));
    });

    test('high expenses produce negative solde', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
        depensesMensuelles: 15000, // very high
      );

      expect(result.budgetGap.soldeMensuel, lessThan(0));
    });

    test('budget gap has alertes for low replacement rate', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
        depensesMensuelles: 15000,
      );

      // With such high expenses, there should be alerts
      expect(result.budgetGap.alertes, isNotEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  CUSTOM RETIREMENT AGES
  // ════════════════════════════════════════════════════════════════

  group('Custom retirement ages', () {
    test('early retirement at 63 applies AVS penalty', () {
      final result63 = RetirementProjectionService.project(
        profile: demoProfile,
        retirementAgeUser: 63,
      );
      final result65 = RetirementProjectionService.project(
        profile: demoProfile,
        retirementAgeUser: 65,
      );

      // Compare AVS user from phase 1 (user retired, no couple cap)
      final avs63 = result63.phases.first.sources
          .where((s) => s.id == 'avs_user')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);
      final avs65 = result65.phases.first.sources
          .where((s) => s.id == 'avs_user')
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);

      // AVS at 63 should be lower than at 65
      expect(avs63, lessThan(avs65));
    });

    test('deferred retirement at 70 produces higher total revenue', () {
      final result65 = RetirementProjectionService.project(
        profile: demoProfile,
        retirementAgeUser: 65,
      );
      final result70 = RetirementProjectionService.project(
        profile: demoProfile,
        retirementAgeUser: 70,
      );

      // Compare total revenue at retirement (phase where both are retired)
      final total65 = result65.phases.last.sources
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);
      final total70 = result70.phases.last.sources
          .fold(0.0, (sum, s) => sum + s.monthlyAmount);

      // Deferral should yield higher total (AVS bonus + more LPP accumulation)
      expect(total70, greaterThan(total65));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  COMPLIANCE
  // ════════════════════════════════════════════════════════════════

  group('Compliance — disclaimer and sources', () {
    test('disclaimer mentions educational/non-conseil nature', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final d = result.disclaimer.toLowerCase();
      // Must mention educational nature and not being financial advice
      expect(d, contains('educative'));
      expect(d, contains('ne constitue pas'));
    });

    test('sources include LAVS and LPP references', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final allSources = result.sources.join(' ');
      expect(allSources, contains('LAVS'));
      expect(allSources, contains('LPP'));
    });

    test('no banned terms in disclaimer', () {
      final result = RetirementProjectionService.project(
        profile: demoProfile,
      );

      final banned = ['garanti', 'certain', 'assuré', 'sans risque',
                       'optimal', 'meilleur', 'parfait', 'conseiller'];
      for (final term in banned) {
        expect(
          result.disclaimer.toLowerCase().contains(term),
          isFalse,
          reason: 'Disclaimer contains banned term: $term',
        );
      }
    });
  });
}
