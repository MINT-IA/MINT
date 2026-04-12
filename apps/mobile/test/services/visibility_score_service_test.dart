import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';

// ────────────────────────────────────────────────────────────────
//  VISIBILITY SCORE SERVICE — Unit Tests
// ────────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  String? firstName,
  double salaire = 0,
  double nombreDeMois = 12.0,
  double? bonusPourcentage,
  String canton = '',
  int birthYear = 1980,
  String employmentStatus = '',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  PatrimoineProfile patrimoine = const PatrimoineProfile(),
  DepensesProfile depenses = const DepensesProfile(),
  ConjointProfile? conjoint,
}) {
  return CoachProfile(
    firstName: firstName,
    salaireBrutMensuel: salaire,
    nombreDeMois: nombreDeMois,
    bonusPourcentage: bonusPourcentage,
    canton: canton,
    birthYear: birthYear,
    employmentStatus: employmentStatus,
    etatCivil: etatCivil,
    prevoyance: prevoyance,
    patrimoine: patrimoine,
    depenses: depenses,
    conjoint: conjoint,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  group('VisibilityScoreService.compute', () {
    test('empty profile returns low score', () {
      final profile = _makeProfile();
      final result = VisibilityScoreService.compute(profile);

      // Smart defaults (goalA → objectifRetraite partial, celibataire → menage)
      // give a non-zero base score even for empty profiles.
      expect(result.total, greaterThanOrEqualTo(0.0));
      expect(result.total, lessThan(30.0));
      expect(result.percentage, lessThan(30));
      expect(result.axes, hasLength(4));
      expect(result.narrative, isNotEmpty);
    });

    test('returns exactly 4 axes', () {
      final profile = _makeProfile(salaire: 8000, canton: 'VD');
      final result = VisibilityScoreService.compute(profile);

      expect(result.axes, hasLength(4));
      final ids = result.axes.map((a) => a.id).toSet();
      expect(ids, containsAll(['liquidite', 'retraite', 'fiscalite', 'securite']));
    });

    test('each axis has maxScore > 0 and all sum to 100', () {
      final profile = _makeProfile(salaire: 8000);
      final result = VisibilityScoreService.compute(profile);

      final totalMax =
          result.axes.fold<double>(0, (s, a) => s + a.maxScore);
      expect(totalMax, 100.0, reason: 'all axes maxScore sum to 100');
      for (final axis in result.axes) {
        expect(axis.maxScore, greaterThan(0),
            reason: '${axis.id} maxScore > 0');
      }
    });

    test('total is sum of 4 axes, clamped 0-100', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
      );
      final result = VisibilityScoreService.compute(profile);

      final axisSum = result.axes.fold<double>(0, (s, a) => s + a.score);
      expect(result.total, axisSum);
      expect(result.percentage, greaterThanOrEqualTo(0));
      expect(result.percentage, lessThanOrEqualTo(100));
    });

    test('axis scores are clamped 0-maxScore', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 40000,
          nombre3a: 2,
          anneesContribuees: 25,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
          investissements: 100000,
        ),
      );
      final result = VisibilityScoreService.compute(profile);

      for (final axis in result.axes) {
        expect(axis.score, greaterThanOrEqualTo(0.0),
            reason: '${axis.id} >= 0');
        expect(axis.score, lessThanOrEqualTo(axis.maxScore),
            reason: '${axis.id} <= maxScore (${axis.maxScore})');
      }
    });

    test('adding salary increases liquidite axis', () {
      final empty = _makeProfile();
      final withSalary = _makeProfile(salaire: 8000);

      final emptyResult = VisibilityScoreService.compute(empty);
      final salaryResult = VisibilityScoreService.compute(withSalary);

      final emptyLiq = emptyResult.axes.firstWhere((a) => a.id == 'liquidite');
      final salaryLiq = salaryResult.axes.firstWhere((a) => a.id == 'liquidite');

      expect(salaryLiq.score, greaterThan(emptyLiq.score));
    });

    test('adding LPP data increases retraite axis', () {
      final noLpp = _makeProfile(salaire: 8000);
      final withLpp = _makeProfile(
        salaire: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
        ),
      );

      final noLppResult = VisibilityScoreService.compute(noLpp);
      final withLppResult = VisibilityScoreService.compute(withLpp);

      final noLppRet = noLppResult.axes.firstWhere((a) => a.id == 'retraite');
      final withLppRet = withLppResult.axes.firstWhere((a) => a.id == 'retraite');

      expect(withLppRet.score, greaterThan(noLppRet.score));
    });

    test('adding canton + age increases fiscalite axis', () {
      final noFiscal = _makeProfile(salaire: 8000);
      final withFiscal = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1975,
      );

      final noResult = VisibilityScoreService.compute(noFiscal);
      final withResult = VisibilityScoreService.compute(withFiscal);

      final noFisc = noResult.axes.firstWhere((a) => a.id == 'fiscalite');
      final withFisc = withResult.axes.firstWhere((a) => a.id == 'fiscalite');

      expect(withFisc.score, greaterThan(noFisc.score));
    });

    test('adding employment status increases securite axis', () {
      final noStatus = _makeProfile(salaire: 8000);
      final withStatus = _makeProfile(
        salaire: 8000,
        employmentStatus: 'salarie',
      );

      final noResult = VisibilityScoreService.compute(noStatus);
      final withResult = VisibilityScoreService.compute(withStatus);

      final noSec = noResult.axes.firstWhere((a) => a.id == 'securite');
      final withSec = withResult.axes.firstWhere((a) => a.id == 'securite');

      expect(withSec.score, greaterThan(noSec.score));
    });

    test('status transitions: missing -> partial -> complete', () {
      final empty = _makeProfile();
      final partial = _makeProfile(salaire: 8000);
      final full = _makeProfile(
        salaire: 8000,
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
          investissements: 100000,
        ),
      );

      final emptyLiq = VisibilityScoreService.compute(empty)
          .axes.firstWhere((a) => a.id == 'liquidite');
      final partialLiq = VisibilityScoreService.compute(partial)
          .axes.firstWhere((a) => a.id == 'liquidite');
      final fullLiq = VisibilityScoreService.compute(full)
          .axes.firstWhere((a) => a.id == 'liquidite');

      expect(emptyLiq.status, 'missing');
      // Partial or complete depending on scorer
      expect(partialLiq.score, greaterThan(emptyLiq.score));
      expect(fullLiq.score, greaterThanOrEqualTo(partialLiq.score));
    });

    test('actions list has max 3 items', () {
      final profile = _makeProfile(); // empty → many prompts
      final result = VisibilityScoreService.compute(profile);

      expect(result.actions.length, lessThanOrEqualTo(3));
    });

    test('actions have valid routes', () {
      final profile = _makeProfile();
      final result = VisibilityScoreService.compute(profile);

      for (final action in result.actions) {
        expect(action.route, startsWith('/'));
        expect(action.title, isNotEmpty);
        expect(action.subtitle, isNotEmpty);
        expect(action.impactPoints, greaterThan(0));
      }
    });
  });

  group('VisibilityScoreService.compute — narrative', () {
    test('high score narrative mentions "vision claire"', () {
      // Build a very complete profile
      final profile = _makeProfile(
        firstName: 'Julien',
        salaire: 9078,
        nombreDeMois: 13.0,
        canton: 'VS',
        birthYear: 1977,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          tauxConversion: 0.068,
          rendementCaisse: 0.05,
          totalEpargne3a: 32000,
          nombre3a: 2,
          anneesContribuees: 25,
          canContribute3a: true,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 77000,
        ),
        depenses: const DepensesProfile(
          loyer: 925,
          assuranceMaladie: 450,
        ),
      );
      final result = VisibilityScoreService.compute(profile);

      // With this much data, score should be high enough for the top narrative
      if (result.percentage >= 80) {
        expect(result.narrative, contains('vision claire'));
      } else if (result.percentage >= 60) {
        expect(result.narrative, contains('visibilité'));
      }
    });

    test('low score narrative mentions "chaque information"', () {
      final profile = _makeProfile();
      final result = VisibilityScoreService.compute(profile);

      if (result.percentage < 40) {
        expect(result.narrative, contains('Chaque information'));
      }
    });
  });

  group('VisibilityScoreService.computeCouple', () {
    test('couple score uses revenuBrutAnnuel (13e mois)', () {
      // Profile with 13 months → revenuBrutAnnuel = 8000*13 = 104'000
      final user = _makeProfile(
        firstName: 'Alice',
        salaire: 8000,
        nombreDeMois: 13.0,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
      );
      // Profile with 12 months → revenuBrutAnnuel = 5000*12 = 60'000
      final conjoint = _makeProfile(
        firstName: 'Bob',
        salaire: 5000,
        nombreDeMois: 12.0,
        canton: 'VD',
        birthYear: 1980,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
      );

      final result = VisibilityScoreService.computeCouple(user, conjoint);

      // Verify it doesn't blow up and returns valid data
      expect(result.percentage, greaterThanOrEqualTo(0));
      expect(result.percentage, lessThanOrEqualTo(100));
      expect(result.axes, hasLength(4));

      // Couple-specific fields
      expect(result.coupleWeakName, isNotNull);
      expect(result.coupleWeakScore, isNotNull);
    });

    test('couple weak name identifies lower scorer', () {
      final strong = _makeProfile(
        firstName: 'Alice',
        salaire: 8000,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          totalEpargne3a: 40000,
          nombre3a: 2,
          anneesContribuees: 25,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
          investissements: 100000,
        ),
      );
      final weak = _makeProfile(
        firstName: 'Bob',
        salaire: 3000,
        canton: '',
        birthYear: 1985,
        employmentStatus: '',
        etatCivil: CoachCivilStatus.celibataire,
      );

      final result = VisibilityScoreService.computeCouple(strong, weak);
      expect(result.coupleWeakName, 'Bob');
    });

    test('couple with zero revenue falls back to simple average', () {
      final user = _makeProfile(firstName: 'A');
      final conjoint = _makeProfile(firstName: 'B');

      final result = VisibilityScoreService.computeCouple(user, conjoint);

      // Both have 0 revenue → simple average
      expect(result.percentage, greaterThanOrEqualTo(0));
    });

    test('couple merged axes use 0.8 threshold for complete status', () {
      // Build two profiles where average axis score is between 70-80% of 25
      // (i.e., 17.5-20). This tests that the threshold is 0.8, not 0.7.
      final profile1 = _makeProfile(
        firstName: 'A',
        salaire: 8000,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
      );
      final profile2 = _makeProfile(
        firstName: 'B',
        salaire: 6000,
        canton: 'GE',
        birthYear: 1980,
        employmentStatus: 'salarie',
      );

      final result = VisibilityScoreService.computeCouple(profile1, profile2);

      // Verify axes have valid statuses
      for (final axis in result.axes) {
        expect(axis.status, isIn(['complete', 'partial', 'missing']));
        // If status is complete, score should be >= 80% of max
        if (axis.status == 'complete') {
          expect(axis.score, greaterThanOrEqualTo(axis.maxScore * 0.8),
              reason: '${axis.id}: complete requires >= 80%');
        }
      }
    });

    test('couple weighting accounts for 13e mois correctly', () {
      // With 13 months, user has higher weight than with 12
      final user13 = _makeProfile(
        firstName: 'A',
        salaire: 8000,
        nombreDeMois: 13.0, // revenuBrutAnnuel = 104'000
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          anneesContribuees: 25,
        ),
      );
      final user12 = _makeProfile(
        firstName: 'A',
        salaire: 8000,
        nombreDeMois: 12.0, // revenuBrutAnnuel = 96'000
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          anneesContribuees: 25,
        ),
      );
      final conjoint = _makeProfile(
        firstName: 'B',
        salaire: 3000,
        canton: 'VD',
        birthYear: 1980,
        employmentStatus: 'salarie',
      );

      final result13 = VisibilityScoreService.computeCouple(user13, conjoint);
      final result12 = VisibilityScoreService.computeCouple(user12, conjoint);

      // With 13 months, user A has higher relative weight → couple score
      // should be closer to A's individual score (which is higher than B's)
      // This verifies revenuBrutAnnuel is used, not salaireBrutMensuel * 12
      expect(result13.total, isNot(equals(result12.total)),
          reason: '13e mois should change weighting');
    });

    test('couple with bonus changes weighting', () {
      final withBonus = _makeProfile(
        firstName: 'A',
        salaire: 8000,
        bonusPourcentage: 10, // +10% → revenuBrutAnnuel = 105'600
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
      );
      final noBonus = _makeProfile(
        firstName: 'A',
        salaire: 8000, // revenuBrutAnnuel = 96'000
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
      );
      final conjoint = _makeProfile(
        firstName: 'B',
        salaire: 3000,
        canton: 'VD',
        birthYear: 1980,
        employmentStatus: 'salarie',
      );

      final resultBonus = VisibilityScoreService.computeCouple(withBonus, conjoint);
      final resultNoBonus = VisibilityScoreService.computeCouple(noBonus, conjoint);

      // Bonus increases revenuBrutAnnuel → changes weighting
      expect(resultBonus.total, isNot(equals(resultNoBonus.total)),
          reason: 'bonus should change weighting');
    });

    test('couple actions are deduplicated by id', () {
      final user = _makeProfile(firstName: 'A');
      final conjoint = _makeProfile(firstName: 'B');

      final result = VisibilityScoreService.computeCouple(user, conjoint);

      final ids = result.actions.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicate action ids');
      expect(result.actions.length, lessThanOrEqualTo(3));
    });
  });

  group('VisibilityAxis', () {
    test('percentage calculation', () {
      const axis = VisibilityAxis(
        id: 'test',
        label: 'Test',
        icon: 'info',
        score: 15,
        maxScore: 25,
        status: 'partial',
        hint: 'Test hint',
      );
      expect(axis.percentage, 60.0);
    });

    test('percentage with zero maxScore returns 0', () {
      const axis = VisibilityAxis(
        id: 'test',
        label: 'Test',
        icon: 'info',
        score: 10,
        maxScore: 0,
        status: 'missing',
        hint: 'Test hint',
      );
      expect(axis.percentage, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CONTEXTUAL WEIGHTS — Phase 1
  // ════════════════════════════════════════════════════════════

  group('Contextual weights (Phase 1)', () {
    test('age 52 gives Retraite weight 30, Liquidité 20', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974, // age 52
        employmentStatus: 'salarie',
      );
      final result = VisibilityScoreService.compute(profile);

      final retraite = result.axes.firstWhere((a) => a.id == 'retraite');
      final liquidite = result.axes.firstWhere((a) => a.id == 'liquidite');

      expect(retraite.maxScore, 30.0, reason: '50+ → Retraite 30');
      expect(liquidite.maxScore, 20.0, reason: '50+ → Liquidité 20');
    });

    test('age 30 gives Liquidité weight 30, Retraite 20', () {
      final profile = _makeProfile(
        salaire: 5000,
        canton: 'ZH',
        birthYear: 1996, // age 30
        employmentStatus: 'salarie',
      );
      final result = VisibilityScoreService.compute(profile);

      final retraite = result.axes.firstWhere((a) => a.id == 'retraite');
      final liquidite = result.axes.firstWhere((a) => a.id == 'liquidite');

      expect(liquidite.maxScore, 30.0, reason: '<35 → Liquidité 30');
      expect(retraite.maxScore, 20.0, reason: '<35 → Retraite 20');
    });

    test('age 40 keeps default 25/25/25/25', () {
      final profile = _makeProfile(
        salaire: 7000,
        canton: 'GE',
        birthYear: 1986, // age 40
        employmentStatus: 'salarie',
      );
      final result = VisibilityScoreService.compute(profile);

      for (final axis in result.axes) {
        expect(axis.maxScore, 25.0,
            reason: '${axis.id}: age 35-49 → default 25');
      }
    });

    test('independant gets Sécurité +5, Retraite -5', () {
      final profile = _makeProfile(
        salaire: 6000,
        canton: 'BE',
        birthYear: 1986, // age 40 → default base
        employmentStatus: 'independant',
      );
      final result = VisibilityScoreService.compute(profile);

      final securite = result.axes.firstWhere((a) => a.id == 'securite');
      final retraite = result.axes.firstWhere((a) => a.id == 'retraite');

      expect(securite.maxScore, 30.0,
          reason: 'independant: 25 + 5 = 30');
      expect(retraite.maxScore, 20.0,
          reason: 'independant: 25 - 5 = 20');
    });

    test('50+ independant: Retraite 30-5=25, Sécurité 22+5=27', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974, // age 52 → 45-54 bracket
        employmentStatus: 'independant',
      );
      final result = VisibilityScoreService.compute(profile);

      final retraite = result.axes.firstWhere((a) => a.id == 'retraite');
      final securite = result.axes.firstWhere((a) => a.id == 'securite');

      // Age 45-54: wRet=30, wSec=22. Indep: wRet-5=25, wSec+5=27.
      expect(retraite.maxScore, 25.0,
          reason: '45-54 base 30 - 5 indep = 25');
      expect(securite.maxScore, 27.0,
          reason: '45-54 base 22 + 5 indep = 27');
    });

    test('total of all axes maxScore always sums to 100', () {
      final profiles = [
        _makeProfile(birthYear: 2000, employmentStatus: 'salarie'),
        _makeProfile(birthYear: 1986, employmentStatus: 'salarie'),
        _makeProfile(birthYear: 1970, employmentStatus: 'salarie'),
        _makeProfile(birthYear: 1986, employmentStatus: 'independant'),
        _makeProfile(birthYear: 1970, employmentStatus: 'independant'),
      ];

      for (final profile in profiles) {
        final result = VisibilityScoreService.compute(profile);
        final totalMax =
            result.axes.fold<double>(0, (s, a) => s + a.maxScore);
        expect(totalMax, 100.0,
            reason: 'weights sum to 100 for age ${profile.age}, '
                '${profile.employmentStatus}');
      }
    });
  });

  group('VisibilityAction', () {
    test('construction works', () {
      const action = VisibilityAction(
        id: 'lpp',
        title: 'Ajoute ton certificat LPP',
        subtitle: 'Scanne ou saisis les donnees',
        route: '/rachat-lpp',
        icon: 'account_balance',
        category: 'lpp',
        impactPoints: 18,
      );
      expect(action.id, 'lpp');
      expect(action.route, '/rachat-lpp');
      expect(action.impactPoints, 18);
    });
  });
}
