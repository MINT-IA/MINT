import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/job_comparison_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper factories
  // ---------------------------------------------------------------------------

  /// Builds a default LPPPlanInput for a mid-career employee (age ~35-44).
  LPPPlanInput makePlan({
    double salaireBrut = 90000,
    double? salaireAssure,
    double? deductionCoordination,
    double tauxCotisationEmploye = 0.0,
    double tauxCotisationEmployeur = 0.0,
    double partEmployeurPct = 50.0,
    double avoirVieillesse = 100000,
    double tauxConversionObligatoire = 6.8,
    double tauxConversionSurobligatoire = 5.2,
    double renteInvaliditePct = 40.0,
    double capitalDeces = 150000,
    double rachatMaximum = 50000,
    bool hasIjm = true,
  }) =>
      LPPPlanInput(
        salaireBrut: salaireBrut,
        salaireAssure: salaireAssure,
        deductionCoordination: deductionCoordination,
        tauxCotisationEmploye: tauxCotisationEmploye,
        tauxCotisationEmployeur: tauxCotisationEmployeur,
        partEmployeurPct: partEmployeurPct,
        avoirVieillesse: avoirVieillesse,
        tauxConversionObligatoire: tauxConversionObligatoire,
        tauxConversionSurobligatoire: tauxConversionSurobligatoire,
        renteInvaliditePct: renteInvaliditePct,
        capitalDeces: capitalDeces,
        rachatMaximum: rachatMaximum,
        hasIjm: hasIjm,
      );

  // ---------------------------------------------------------------------------
  // LPPPlanInput — coordinated salary
  // ---------------------------------------------------------------------------

  group('LPPPlanInput — effectiveSalaireAssure', () {
    test('uses explicit salaireAssure when provided', () {
      final plan = makePlan(salaireAssure: 42000);
      expect(plan.effectiveSalaireAssure, 42000);
    });

    test('applies default coordination deduction (26460)', () {
      final plan = makePlan(salaireBrut: 90000);
      // 90000 - 26460 = 63540
      expect(plan.effectiveSalaireAssure, closeTo(63540, 0.01));
    });

    test('applies custom coordination deduction, capped at max (LPP art. 8)', () {
      final plan = makePlan(salaireBrut: 90000, deductionCoordination: 20000);
      // 90000 - 20000 = 70000, capped at lppSalaireCoordMax = 64260
      expect(plan.effectiveSalaireAssure, closeTo(lppSalaireCoordMax, 0.01));
    });

    test('floors to zero when salary below LPP entry threshold (LPP art. 7)', () {
      final plan = makePlan(salaireBrut: 20000);
      // 20000 < lppSeuilEntree (22680) -> no LPP coverage -> 0
      expect(plan.effectiveSalaireAssure, 0.0);
    });

    test('minimum coordinated salary edge — exactly at coordination deduction', () {
      // Salary exactly equals coordination deduction (26460 > 22680 seuil)
      // 26460 - 26460 = 0, but clamped to lppSalaireCoordMin = 3780 (LPP art. 8 al. 2)
      final plan = makePlan(salaireBrut: lppDeductionCoordination);
      expect(plan.effectiveSalaireAssure, lppSalaireCoordMin);
    });

    test('salary just above coordination deduction clamps to min coordinated', () {
      final plan = makePlan(salaireBrut: lppDeductionCoordination + 100);
      // 26560 - 26460 = 100, but clamped to lppSalaireCoordMin = 3780
      expect(plan.effectiveSalaireAssure, lppSalaireCoordMin);
    });
  });

  // ---------------------------------------------------------------------------
  // LPPPlanInput — contributions
  // ---------------------------------------------------------------------------

  group('LPPPlanInput — cotisations', () {
    test('uses provided employee rate when > 0', () {
      final plan = makePlan(
        salaireBrut: 90000,
        tauxCotisationEmploye: 7.0,
        tauxCotisationEmployeur: 7.0,
      );
      // effectiveSalaireAssure = 90000 - 26460 = 63540
      // total = 63540 * (7 + 7) / 100 = 63540 * 0.14 = 8895.6
      expect(plan.totalCotisationAnnuelle, closeTo(8895.6, 0.01));
    });

    test('employee-only contribution is half of total at 50% split', () {
      final plan = makePlan(
        salaireBrut: 90000,
        tauxCotisationEmploye: 5.0,
        tauxCotisationEmployeur: 5.0,
      );
      expect(plan.cotisationEmployeAnnuelle,
          closeTo(plan.totalCotisationAnnuelle / 2, 0.01));
    });

    test('estimated cotisation uses mid-career rate (10% total) with 50% split',
        () {
      // No explicit rates -> _estimateCotisationRate => 10 * (100-50)/100 = 5%
      final plan = makePlan(salaireBrut: 90000, partEmployeurPct: 50.0);
      // effectiveSalaireAssure = 63540
      // Employee rate estimated at 5%, employer also 5% (50/50 split)
      // Total = 63540 * 10% = 6354
      expect(plan.totalCotisationAnnuelle, closeTo(6354, 0.01));
    });

    test('employer pays 60% of contribution', () {
      // _estimateCotisationRate => 10 * (100-60)/100 = 4%
      // employer = 4 * (60 / 40) = 6%
      // total = 10%
      final plan = makePlan(salaireBrut: 90000, partEmployeurPct: 60.0);
      final insured = plan.effectiveSalaireAssure; // 63540
      expect(plan.totalCotisationAnnuelle, closeTo(insured * 0.10, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // LPPPlanInput — pension & net salary
  // ---------------------------------------------------------------------------

  group('LPPPlanInput — rente & net salary', () {
    test('annual pension = avoir * taux surobligatoire', () {
      final plan = makePlan(
        avoirVieillesse: 500000,
        tauxConversionSurobligatoire: 5.2,
      );
      // 500000 * 5.2% = 26000
      expect(plan.renteAnnuelle, closeTo(26000, 0.01));
    });

    test('monthly pension = annual / 12', () {
      final plan = makePlan(
        avoirVieillesse: 500000,
        tauxConversionSurobligatoire: 5.2,
      );
      expect(plan.renteMensuelle, closeTo(26000 / 12, 0.01));
    });

    test('net monthly salary deducts social charges + LPP employee share', () {
      final plan = makePlan(
        salaireBrut: 120000,
        tauxCotisationEmploye: 5.0,
      );
      final grossMonthly = 120000.0 / 12;
      final socialCharges = grossMonthly * 0.064;
      final lppMonthly = plan.cotisationEmployeAnnuelle / 12;
      expect(plan.salaireNetMensuel,
          closeTo(grossMonthly - socialCharges - lppMonthly, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // JobComparisonService.compare — verdict logic
  // ---------------------------------------------------------------------------

  group('JobComparisonService.compare — verdict', () {
    test('nouveauMeilleur when new job clearly better', () {
      final current = makePlan(
        salaireBrut: 80000,
        avoirVieillesse: 50000,
        capitalDeces: 100000,
        rachatMaximum: 20000,
      );
      final newJob = makePlan(
        salaireBrut: 120000,
        avoirVieillesse: 80000,
        capitalDeces: 200000,
        rachatMaximum: 80000,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      expect(result.verdict, ComparisonVerdict.nouveauMeilleur);
    });

    test('actuelMeilleur when current job clearly better', () {
      final current = makePlan(
        salaireBrut: 120000,
        avoirVieillesse: 200000,
        capitalDeces: 300000,
        rachatMaximum: 100000,
      );
      final newJob = makePlan(
        salaireBrut: 60000,
        avoirVieillesse: 30000,
        capitalDeces: 50000,
        rachatMaximum: 10000,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      expect(result.verdict, ComparisonVerdict.actuelMeilleur);
    });

    test('identical plans yields nouveauMeilleur (zero deltas count as positive)', () {
      // When all deltas are exactly 0, isPositive = (0 >= 0) = true for all 7 axes,
      // so positiveCount = 7 >= 5 => nouveauMeilleur.
      final plan = makePlan();
      final result =
          JobComparisonService.compare(current: plan, newJob: plan, age: 40);
      expect(result.verdict, ComparisonVerdict.nouveauMeilleur);
    });

    test('comparable when some axes better, some worse, no clear winner', () {
      // New job: significantly higher salary/cotisations/capital but worse
      // deces, invalidite, and rachat -- 4 positive, 3 negative.
      final current = makePlan(
        salaireBrut: 85000,
        avoirVieillesse: 100000,
        capitalDeces: 250000,
        rachatMaximum: 100000,
        tauxConversionSurobligatoire: 5.2,
        renteInvaliditePct: 60.0,
      );
      final newJob = makePlan(
        salaireBrut: 110000,
        avoirVieillesse: 100000,
        capitalDeces: 180000,
        rachatMaximum: 60000,
        tauxConversionSurobligatoire: 5.2,
        renteInvaliditePct: 35.0,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      // Axes expected positive: salaire net, capital retraite, rente/mois
      // (higher salary -> higher insured -> more contributions -> more capital -> more rente)
      // Cotis LPP: deltaCotisation = current-new, new pays more -> negative
      // Deces: 180k < 250k -> negative
      // Invalidite: new insured * 35% vs current insured * 60% -> negative
      // Rachat: 60k < 100k -> negative
      // Count: 3 positive, 4 negative -> neither >= 5, so comparable
      expect(result.verdict, ComparisonVerdict.comparable);
    });

    test('always returns exactly 7 comparison axes', () {
      final result = JobComparisonService.compare(
        current: makePlan(),
        newJob: makePlan(salaireBrut: 95000),
        age: 35,
      );
      expect(result.axes.length, 7);
    });
  });

  // ---------------------------------------------------------------------------
  // JobComparisonService.compare — alerts
  // ---------------------------------------------------------------------------

  group('JobComparisonService.compare — alerts', () {
    test('alert when losing IJM coverage', () {
      final current = makePlan(hasIjm: true);
      final newJob = makePlan(hasIjm: false);
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      expect(result.alerts,
          contains(contains('IJM')));
    });

    test('alert when salary gain hides pension loss', () {
      // Higher salary but lower conversion rate and lower avoir -> smaller rente
      final current = makePlan(
        salaireBrut: 80000,
        avoirVieillesse: 500000,
        tauxConversionSurobligatoire: 6.0,
      );
      final newJob = makePlan(
        salaireBrut: 110000,
        avoirVieillesse: 200000,
        tauxConversionSurobligatoire: 4.0,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 50);

      // The net salary should be higher for new job, but rente lower
      final salaireAxis = result.axes.firstWhere((a) => a.nameKey == 'jobCompareSalaireNet');
      expect(salaireAxis.delta, greaterThan(0));

      // Should trigger the "gain salarial cache une perte de rente" alert
      expect(result.alerts, contains(contains('perte de rente')));
    });

    test('alert when capital loss exceeds 50k', () {
      final current = makePlan(
        salaireBrut: 90000,
        avoirVieillesse: 500000,
      );
      final newJob = makePlan(
        salaireBrut: 90000,
        avoirVieillesse: 100000,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 55);
      expect(result.alerts, contains(contains('capital retraite')));
    });

    test('alert when invalidite coverage is reduced', () {
      final current = makePlan(
        salaireBrut: 100000,
        renteInvaliditePct: 60.0,
      );
      final newJob = makePlan(
        salaireBrut: 100000,
        renteInvaliditePct: 30.0,
      );
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      expect(result.alerts, contains(contains('invalidite')));
    });

    test('alert when conversion rate is lower', () {
      final current = makePlan(tauxConversionSurobligatoire: 5.8);
      final newJob = makePlan(tauxConversionSurobligatoire: 4.5);
      final result =
          JobComparisonService.compare(current: current, newJob: newJob, age: 40);
      expect(result.alerts, contains(contains('Taux de conversion')));
    });

    test('no alerts when both plans identical', () {
      final plan = makePlan();
      final result =
          JobComparisonService.compare(current: plan, newJob: plan, age: 40);
      expect(result.alerts, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // JobComparisonService.compare — edge cases
  // ---------------------------------------------------------------------------

  group('JobComparisonService.compare — edge cases', () {
    test('age 65 — zero years to retirement', () {
      final result = JobComparisonService.compare(
        current: makePlan(avoirVieillesse: 300000),
        newJob: makePlan(avoirVieillesse: 400000),
        age: 65,
      );
      // With 0 years to retirement, capital = just avoirVieillesse
      final capitalAxis =
          result.axes.firstWhere((a) => a.nameKey == 'jobCompareCapitalRetraite');
      expect(capitalAxis.currentValue, closeTo(300000, 1));
      expect(capitalAxis.newValue, closeTo(400000, 1));
    });

    test('age above 65 — no negative years', () {
      final result = JobComparisonService.compare(
        current: makePlan(),
        newJob: makePlan(),
        age: 70,
      );
      // Should still work, years = max(0, 65-70) = 0
      expect(result.axes.length, 7);
    });

    test('salary below LPP threshold — zero insured salary', () {
      final plan = makePlan(salaireBrut: 20000);
      expect(plan.effectiveSalaireAssure, 0);
      expect(plan.totalCotisationAnnuelle, 0);
      expect(plan.cotisationEmployeAnnuelle, 0);
    });

    test('pension delta computed over 20 years', () {
      final current = makePlan(avoirVieillesse: 100000, tauxConversionSurobligatoire: 5.0);
      final newJob = makePlan(avoirVieillesse: 200000, tauxConversionSurobligatoire: 5.0);
      final result = JobComparisonService.compare(
        current: current,
        newJob: newJob,
        age: 65,
      );
      // With age 65, capital = avoir itself. Rente monthly = capital * 5% / 12
      // Delta rente annual = deltaRente * 12
      // Lifetime = annual * 20
      final renteAxis = result.axes.firstWhere((a) => a.nameKey == 'jobCompareRenteMois');
      expect(result.annualPensionDelta, closeTo(renteAxis.delta * 12, 0.01));
      expect(result.lifetimePensionDelta, closeTo(result.annualPensionDelta * 20, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // Compliance fields
  // ---------------------------------------------------------------------------

  group('JobComparisonService — compliance', () {
    test('disclaimer is present and mentions outil educatif', () {
      expect(JobComparisonService.disclaimer, contains('outil'));
      expect(JobComparisonService.disclaimer, contains('ducatif'));
    });

    test('disclaimer mentions ne constitue pas un conseil', () {
      expect(JobComparisonService.disclaimer, contains('ne constitue pas un conseil'));
    });

    test('disclaimer uses inclusive language (un-e specialiste)', () {
      expect(JobComparisonService.disclaimer, contains('un\u00B7e sp'));
    });

    test('sources list references LPP articles', () {
      expect(
          JobComparisonService.sources.any((s) => s.contains('LPP art.')), true);
    });

    test('sources list references LIFD', () {
      expect(
          JobComparisonService.sources.any((s) => s.contains('LIFD')), true);
    });

    test('sources list references LFLP (libre passage)', () {
      expect(
          JobComparisonService.sources.any((s) => s.contains('LFLP')), true);
    });

    test('checklist always has 8 items', () {
      final result = JobComparisonService.compare(
        current: makePlan(),
        newJob: makePlan(),
        age: 40,
      );
      expect(result.checklist.length, 8);
    });
  });
}
