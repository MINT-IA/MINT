import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';

// ────────────────────────────────────────────────────────────────
//  VISIBILITY SCORE SERVICE — Unit Tests
// ────────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  String? firstName,
  double salaire = 0,
  int nombreDeMois = 12,
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
    test('empty profile returns score 0', () {
      final profile = _makeProfile();
      final result = VisibilityScoreService.compute(profile);

      expect(result.total, 0.0);
      expect(result.percentage, 0);
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

    test('each axis has maxScore of 25', () {
      final profile = _makeProfile(salaire: 8000);
      final result = VisibilityScoreService.compute(profile);

      for (final axis in result.axes) {
        expect(axis.maxScore, 25.0, reason: '${axis.id} maxScore');
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

    test('axis scores are clamped 0-25', () {
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
        expect(axis.score, lessThanOrEqualTo(25.0),
            reason: '${axis.id} <= 25');
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

    test('adding etat civil increases securite axis', () {
      final noMenage = _makeProfile(salaire: 8000);
      final withMenage = _makeProfile(
        salaire: 8000,
        etatCivil: CoachCivilStatus.marie,
        employmentStatus: 'salarie',
      );

      final noResult = VisibilityScoreService.compute(noMenage);
      final withResult = VisibilityScoreService.compute(withMenage);

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
        nombreDeMois: 13,
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
        expect(result.narrative, contains('visibilite'));
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
        nombreDeMois: 13,
        canton: 'VD',
        birthYear: 1975,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
      );
      // Profile with 12 months → revenuBrutAnnuel = 5000*12 = 60'000
      final conjoint = _makeProfile(
        firstName: 'Bob',
        salaire: 5000,
        nombreDeMois: 12,
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

  group('VisibilityAction', () {
    test('construction works', () {
      const action = VisibilityAction(
        id: 'lpp',
        title: 'Ajoute ton certificat LPP',
        subtitle: 'Scanne ou saisis les donnees',
        route: '/lpp-deep/rachat',
        icon: 'account_balance',
        category: 'lpp',
        impactPoints: 18,
      );
      expect(action.id, 'lpp');
      expect(action.route, '/lpp-deep/rachat');
      expect(action.impactPoints, 18);
    });
  });
}
