import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cross_validation_service.dart';

/// Helper to build CoachProfile instances for testing.
///
/// Defaults to a 50-year-old (born 1976) salaried employee in Zurich
/// with 100k CHF annual salary (~8333/month) and no red flags.
CoachProfile _makeProfile({
  int birthYear = 1976,
  String canton = 'ZH',
  double salaireBrutMensuel = 8333,
  String employmentStatus = 'salarie',
  PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  PatrimoineProfile patrimoine = const PatrimoineProfile(),
  int? arrivalAge,
  int? targetRetirementAge,
  List<PlannedMonthlyContribution> plannedContributions = const [],
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    employmentStatus: employmentStatus,
    prevoyance: prevoyance,
    patrimoine: patrimoine,
    arrivalAge: arrivalAge,
    targetRetirementAge: targetRetirementAge,
    plannedContributions: plannedContributions,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2041),
      label: 'Retraite',
    ),
  );
}

void main() {
  // ════════════════════════════════════════════════════════════════
  // Baseline: clean profile produces no alerts
  // ════════════════════════════════════════════════════════════════

  test('validate returns empty for clean profile with LPP', () {
    // A 50yo salarié at 100k with some LPP → no flags.
    final profile = _makeProfile(
      prevoyance: const PrevoyanceProfile(avoirLppTotal: 300000),
    );
    final alerts = CrossValidationService.validate(profile);
    expect(alerts, isEmpty);
  });

  test('clean employee without LPP triggers employment coherence info', () {
    // A 50yo salarié at 100k with NO LPP → Rule 6 info.
    final profile = _makeProfile();
    final alerts = CrossValidationService.validate(profile);
    expect(alerts.length, 1);
    expect(alerts.first.block, 'lpp');
    expect(alerts.first.severity, AlertSeverity.info);
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 1: LPP plausibility (avoir vs age/salary)
  // ════════════════════════════════════════════════════════════════

  group('Rule 1 — LPP plausibility', () {
    test('LPP too low triggers warning', () {
      // 50-year-old earning 100k, with only 10k LPP declared.
      // Theoretical LPP for 25 years of contributions at this salary
      // should be well above 10k, so ratio < 0.3 => warning.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 10000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final lppAlerts = alerts.where((a) => a.block == 'lpp').toList();
      expect(lppAlerts, isNotEmpty);
      expect(
        lppAlerts.any((a) => a.severity == AlertSeverity.warning),
        isTrue,
        reason: 'Should flag very low LPP as a warning',
      );
      expect(
        lppAlerts.first.message,
        contains('tres bas'),
      );
    });

    test('LPP too high triggers info', () {
      // 50-year-old earning 100k, declaring 2M LPP — suggests big buybacks.
      // ratio > 2.0 => info alert.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 2000000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final lppAlerts = alerts.where((a) => a.block == 'lpp').toList();
      expect(lppAlerts, isNotEmpty);
      expect(
        lppAlerts.any((a) => a.severity == AlertSeverity.info),
        isTrue,
        reason: 'Should flag very high LPP as informational',
      );
      expect(
        lppAlerts.first.message,
        contains('rachats'),
      );
    });

    test('LPP normal = no alert', () {
      // 50-year-old earning 100k, with ~300k LPP is plausible.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 300000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final lppPlausibilityAlerts = alerts.where(
        (a) =>
            a.block == 'lpp' &&
            (a.message.contains('tres bas') || a.message.contains('rachats')),
      );
      expect(lppPlausibilityAlerts, isEmpty,
          reason: 'Normal LPP should not trigger plausibility alerts');
    });

    test('LPP plausibility skipped for independants', () {
      // Independent with low LPP should not trigger plausibility warning
      // (Rule 1 only applies to employees).
      final profile = _makeProfile(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 5000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final plausibilityAlerts = alerts.where(
        (a) => a.block == 'lpp' && a.message.contains('tres bas'),
      );
      expect(plausibilityAlerts, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 2: 3a ceiling vs employment status
  // ════════════════════════════════════════════════════════════════

  group('Rule 2 — 3a ceiling', () {
    test('3a planned exceeds ceiling for employee (7258)', () {
      // Employee with LPP: plafond = 7258 CHF/an.
      // Planning 700/month = 8400/year > 7258 * 1.05 => error.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          nombre3a: 1,
          totalEpargne3a: 50000,
          avoirLppTotal: 200000,
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_main',
            label: '3a Julien',
            amount: 700,
            category: '3a',
          ),
        ],
      );
      final alerts = CrossValidationService.validate(profile);
      final a3aAlerts = alerts.where((a) => a.block == '3a').toList();
      expect(a3aAlerts, isNotEmpty);
      expect(a3aAlerts.first.severity, AlertSeverity.error);
      expect(a3aAlerts.first.message, contains('depassent le plafond'));
      expect(a3aAlerts.first.message, contains('OPP3'));
    });

    test('3a planned exceeds ceiling for independant without LPP (36288)', () {
      // Independent without LPP: plafond = min(20% revenu, 36288).
      // Revenue = 200k => 20% = 40k, capped to 36288.
      // Planning 3200/month = 38400/year > 36288 * 1.05 => error.
      final profile = _makeProfile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 16667, // ~200k/year
        prevoyance: const PrevoyanceProfile(
          nombre3a: 1,
          totalEpargne3a: 100000,
          // No LPP declared (independant sans LPP)
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_indep',
            label: '3a Independant',
            amount: 3200,
            category: '3a',
          ),
        ],
      );
      final alerts = CrossValidationService.validate(profile);
      final a3aAlerts = alerts.where((a) => a.block == '3a').toList();
      expect(a3aAlerts, isNotEmpty);
      expect(a3aAlerts.first.severity, AlertSeverity.error);
      expect(a3aAlerts.first.message, contains('depassent le plafond'));
    });

    test('3a under ceiling = no alert', () {
      // Employee with 3a at 600/month = 7200/year, under 7258 ceiling.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          nombre3a: 1,
          totalEpargne3a: 30000,
          avoirLppTotal: 200000,
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_ok',
            label: '3a Julien',
            amount: 600,
            category: '3a',
          ),
        ],
      );
      final alerts = CrossValidationService.validate(profile);
      final a3aAlerts = alerts.where((a) => a.block == '3a').toList();
      expect(a3aAlerts, isEmpty,
          reason: '3a contribution under ceiling should not alert');
    });

    test('3a check skipped when no planned contributions', () {
      // Even with nombre3a > 0 and totalEpargne3a > 0,
      // no planned contributions means nothing to check.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          nombre3a: 2,
          totalEpargne3a: 80000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final a3aAlerts = alerts.where((a) => a.block == '3a').toList();
      expect(a3aAlerts, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 3: Mortgage Tragbarkeit (FINMA/ASB)
  // ════════════════════════════════════════════════════════════════

  group('Rule 3 — Mortgage Tragbarkeit', () {
    test('Mortgage over 33% Tragbarkeit triggers alert', () {
      // 100k salary, 800k mortgage, 1M property.
      // Charges: 800k * 5% + 800k * 1% + 1M * 1% = 40k + 8k + 10k = 58k.
      // Ratio: 58k / 100k = 58% => well over 33%.
      final profile = _makeProfile(
        patrimoine: const PatrimoineProfile(
          mortgageBalance: 800000,
          propertyMarketValue: 1000000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final patrimoineAlerts =
          alerts.where((a) => a.block == 'patrimoine').toList();
      expect(patrimoineAlerts, isNotEmpty);
      expect(
        patrimoineAlerts.first.message,
        contains('taux d\'effort'),
      );
      // 58% > 40% => error severity
      expect(patrimoineAlerts.first.severity, AlertSeverity.error);
    });

    test('Mortgage 34-40% triggers warning (not error)', () {
      // Need ratio between 33% and 40%.
      // 200k couple salary, 800k mortgage, 1M property.
      // Charges: 800k * 5% + 800k * 1% + 1M * 1% = 40k + 8k + 10k = 58k.
      // Ratio: 58k / 200k = 29% => under 33%. Need to adjust.
      // Try: 150k salary, 600k mortgage, 700k property.
      // Charges: 600k * 5% + 600k * 1% + 700k * 1% = 30k + 6k + 7k = 43k.
      // Ratio: 43k / 150k = 28.7% => still under 33%.
      // Try: 120k salary, 600k mortgage, 700k property.
      // Charges: 30k + 6k + 7k = 43k. Ratio: 43k / 120k = 35.8% => warning.
      final profile = _makeProfile(
        salaireBrutMensuel: 10000, // 120k/year
        patrimoine: const PatrimoineProfile(
          mortgageBalance: 600000,
          propertyMarketValue: 700000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final patrimoineAlerts =
          alerts.where((a) => a.block == 'patrimoine').toList();
      expect(patrimoineAlerts, isNotEmpty);
      expect(patrimoineAlerts.first.severity, AlertSeverity.warning);
    });

    test('Mortgage under 33% = no alert', () {
      // 200k salary, 400k mortgage, 600k property.
      // Charges: 400k * 5% + 400k * 1% + 600k * 1% = 20k + 4k + 6k = 30k.
      // Ratio: 30k / 200k = 15% => well under 33%.
      final profile = _makeProfile(
        salaireBrutMensuel: 16667, // ~200k/year
        patrimoine: const PatrimoineProfile(
          mortgageBalance: 400000,
          propertyMarketValue: 600000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final patrimoineAlerts =
          alerts.where((a) => a.block == 'patrimoine').toList();
      expect(patrimoineAlerts, isEmpty,
          reason: 'Mortgage under 33% should not trigger an alert');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 4: AVS years coherence
  // ════════════════════════════════════════════════════════════════

  group('Rule 4 — AVS years coherence', () {
    test('AVS years exceed max possible triggers warning', () {
      // 50-year-old (born 1976), no arrival age => started at 20.
      // Max possible = 50 - 20 = 30 years.
      // Declaring 35 years > 30 + 1 => warning.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          anneesContribuees: 35,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final avsAlerts = alerts.where((a) => a.block == 'avs').toList();
      expect(avsAlerts, isNotEmpty);
      expect(
        avsAlerts.any((a) => a.severity == AlertSeverity.warning),
        isTrue,
      );
      expect(
        avsAlerts.first.message,
        contains('maximum'),
      );
    });

    test('AVS years exceed max for expat (arrival age considered)', () {
      // 50-year-old who arrived at 30 => max possible = 50 - 30 = 20 years.
      // Declaring 25 years > 20 + 1 => warning.
      final profile = _makeProfile(
        arrivalAge: 30,
        prevoyance: const PrevoyanceProfile(
          anneesContribuees: 25,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final avsAlerts = alerts
          .where(
              (a) => a.block == 'avs' && a.severity == AlertSeverity.warning)
          .toList();
      expect(avsAlerts, isNotEmpty);
      expect(avsAlerts.first.message, contains('arrive a 30 ans'));
    });

    test('AVS gap detected (too few years, no arrival age)', () {
      // 50-year-old, no arrival age => max possible = 30 years.
      // Declaring 20 years => gap of 10 > 5 => info.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          anneesContribuees: 20,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final gapAlerts = alerts
          .where((a) => a.block == 'avs' && a.severity == AlertSeverity.info)
          .toList();
      expect(gapAlerts, isNotEmpty);
      expect(gapAlerts.first.message, contains('lacune'));
    });

    test('AVS years coherent = no alert', () {
      // 50-year-old, no arrival => max = 30 years. Declaring 28 is fine.
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          anneesContribuees: 28,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final avsAlerts = alerts.where((a) => a.block == 'avs').toList();
      expect(avsAlerts, isEmpty,
          reason: 'Coherent AVS years should produce no alert');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 5: Retirement age bounds
  // ════════════════════════════════════════════════════════════════

  group('Rule 5 — Retirement age bounds', () {
    test('Retirement age < 58 = error', () {
      final profile = _makeProfile(targetRetirementAge: 55);
      final alerts = CrossValidationService.validate(profile);
      final retAlerts =
          alerts.where((a) => a.block == 'objectifRetraite').toList();
      expect(retAlerts, isNotEmpty);
      expect(retAlerts.first.severity, AlertSeverity.error);
      expect(retAlerts.first.message, contains('55 ans'));
      expect(retAlerts.first.message, contains('58 ans'));
    });

    test('Retirement age > 70 = error', () {
      final profile = _makeProfile(targetRetirementAge: 72);
      final alerts = CrossValidationService.validate(profile);
      final retAlerts =
          alerts.where((a) => a.block == 'objectifRetraite').toList();
      expect(retAlerts, isNotEmpty);
      expect(retAlerts.first.severity, AlertSeverity.error);
      expect(retAlerts.first.message, contains('72 ans'));
      expect(retAlerts.first.message, contains('70 ans'));
    });

    test('Retirement age 58-62 = info (LPP only, no AVS)', () {
      final profile = _makeProfile(targetRetirementAge: 60);
      final alerts = CrossValidationService.validate(profile);
      final retAlerts =
          alerts.where((a) => a.block == 'objectifRetraite').toList();
      expect(retAlerts, isNotEmpty);
      expect(retAlerts.first.severity, AlertSeverity.info);
      expect(retAlerts.first.message, contains('60 ans'));
      expect(retAlerts.first.message, contains('63 ans'));
    });

    test('Retirement age 63-70 = no alert', () {
      final profile = _makeProfile(targetRetirementAge: 65);
      final alerts = CrossValidationService.validate(profile);
      final retAlerts =
          alerts.where((a) => a.block == 'objectifRetraite').toList();
      expect(retAlerts, isEmpty,
          reason: 'Standard retirement age should not trigger any alert');
    });

    test('Retirement age null = no alert (default 65)', () {
      final profile = _makeProfile(targetRetirementAge: null);
      final alerts = CrossValidationService.validate(profile);
      final retAlerts =
          alerts.where((a) => a.block == 'objectifRetraite').toList();
      expect(retAlerts, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Rule 6: LPP vs employment status coherence
  // ════════════════════════════════════════════════════════════════

  group('Rule 6 — LPP employment coherence', () {
    test('Employee without LPP = info', () {
      // 50-year-old employee earning 100k (above seuil 22680) with no LPP.
      final profile = _makeProfile(
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          // avoirLppTotal is null by default
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final coherenceAlerts = alerts
          .where(
            (a) =>
                a.block == 'lpp' && a.message.contains('salarie') &&
                a.message.contains('prevoyance'),
          )
          .toList();
      expect(coherenceAlerts, isNotEmpty);
      expect(coherenceAlerts.first.severity, AlertSeverity.info);
    });

    test('Employee without LPP but below seuil = no alert', () {
      // Employee earning below 22680/year => not subject to LPP.
      final profile = _makeProfile(
        salaireBrutMensuel: 1500, // 18000/year < 22680
        prevoyance: const PrevoyanceProfile(),
      );
      final alerts = CrossValidationService.validate(profile);
      final coherenceAlerts = alerts.where(
        (a) =>
            a.block == 'lpp' &&
            a.message.contains('salarie') &&
            a.message.contains('prevoyance'),
      );
      expect(coherenceAlerts, isEmpty,
          reason: 'Below LPP threshold, no LPP expected');
    });

    test('Independent with high LPP = info', () {
      // Independent with 250k LPP (>200k threshold) => info.
      final profile = _makeProfile(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 250000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final coherenceAlerts = alerts
          .where(
            (a) =>
                a.block == 'lpp' &&
                a.message.contains('independant') &&
                a.severity == AlertSeverity.info,
          )
          .toList();
      expect(coherenceAlerts, isNotEmpty);
      expect(coherenceAlerts.first.message, contains('affiliation facultative'));
    });

    test('Independent with moderate LPP = no coherence alert', () {
      // Independent with 150k LPP (<=200k) => no flag.
      final profile = _makeProfile(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
        ),
      );
      final alerts = CrossValidationService.validate(profile);
      final coherenceAlerts = alerts.where(
        (a) =>
            a.block == 'lpp' &&
            a.message.contains('independant') &&
            a.message.contains('affiliation'),
      );
      expect(coherenceAlerts, isEmpty);
    });

    test('Young employee (< 25) without LPP = no alert', () {
      // 23-year-old employee: not yet subject to LPP bonifications.
      final currentYear = DateTime.now().year;
      final profile = _makeProfile(
        birthYear: currentYear - 23,
        prevoyance: const PrevoyanceProfile(),
      );
      final alerts = CrossValidationService.validate(profile);
      final coherenceAlerts = alerts.where(
        (a) =>
            a.block == 'lpp' &&
            a.message.contains('salarie') &&
            a.message.contains('prevoyance'),
      );
      expect(coherenceAlerts, isEmpty,
          reason: 'Employee under 25 not required to have LPP avoir');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Integration: multiple alerts can fire simultaneously
  // ════════════════════════════════════════════════════════════════

  test('Multiple rules can fire at once', () {
    // Employee with very low LPP (Rule 1 warning),
    // 3a over ceiling (Rule 2 error),
    // and retirement age 55 (Rule 5 error).
    final profile = _makeProfile(
      targetRetirementAge: 55,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 5000,
        nombre3a: 1,
        totalEpargne3a: 40000,
      ),
      plannedContributions: const [
        PlannedMonthlyContribution(
          id: '3a_over',
          label: '3a Trop',
          amount: 700,
          category: '3a',
        ),
      ],
    );
    final alerts = CrossValidationService.validate(profile);
    final blocks = alerts.map((a) => a.block).toSet();
    expect(blocks, contains('lpp'), reason: 'Rule 1 should fire');
    expect(blocks, contains('3a'), reason: 'Rule 2 should fire');
    expect(blocks, contains('objectifRetraite'), reason: 'Rule 5 should fire');
  });
}
