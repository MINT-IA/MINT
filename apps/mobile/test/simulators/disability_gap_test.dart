import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';

void main() {
  // SALVAGE-01-02 / def-03/mlf-03: the screen used to seed _age from the raw
  // `now.year - profile.birthYear`, which on the birthYear==0 sentinel
  // produced 2026 -> clamp(18,64) = 64. Now it routes through ageOrNull and
  // skips seeding when age is unknown, leaving the editable default (45).
  group('DisabilityGapScreen — sentinel-age skip (def-03/mlf-03)', () {
    Widget buildScreen(CoachProfileProvider coach) {
      return ChangeNotifierProvider<CoachProfileProvider>.value(
        value: coach,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DisabilityGapScreen(),
        ),
      );
    }

    testWidgets('no-age profile (birthYear==0) does not seed age 64',
        (tester) async {
      final coach = CoachProfileProvider();
      // No q_birth_year -> birthYear==0 -> ageOrNull == null -> skip seeding.
      coach.updateFromAnswers(<String, dynamic>{
        'q_canton': 'VD',
        'q_monthly_gross': 6000,
      });
      await tester.pumpWidget(buildScreen(coach));
      await tester.pump();
      // The fabricated near-retirement age (64 ans) must NOT appear; the
      // editable default (45 ans) is shown instead.
      expect(find.textContaining('64 ans'), findsNothing);
      expect(find.textContaining('45 ans'), findsWidgets);
    });
  });

  group('DisabilityGapCalculator', () {
    test('Marc: ZH employee, 3y seniority, 8000 CHF, IJM, 100% disability', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 3,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );

      // Phase 1: ZH échelle zurichoise, 3 years = 8 weeks
      expect(result.phase1DurationWeeks, 8.0);
      expect(result.phase1MonthlyBenefit, 8000.0); // 100% salary
      expect(result.phase1Gap, 0.0);

      // Phase 2: IJM = 80% salary
      expect(result.phase2MonthlyBenefit, 6400.0); // 80% of 8000
      expect(result.phase2Gap, 1600.0);

      // Phase 3: AI full rente + no LPP (AVS/AI 2520 CHF, commit 750286b)
      expect(result.aiRenteMensuelle, 2520.0);
      expect(result.phase3MonthlyBenefit, 2520.0);
      expect(result.phase3Gap, 5480.0);

      // Risk level: has IJM but gap > 3000 → medium
      expect(result.riskLevel, 'medium');
    });

    test('Sophie: VD employee, 8y seniority, 6000 CHF, IJM, 100% disability', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 6000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'VD',
        anneesAnciennete: 8,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );

      // Phase 1: VD échelle bernoise, 8 years = 13 weeks
      expect(result.phase1DurationWeeks, 13.0);
      expect(result.phase1MonthlyBenefit, 6000.0);
      expect(result.phase1Gap, 0.0);

      // Phase 2: IJM = 80% salary
      expect(result.phase2MonthlyBenefit, 4800.0); // 80% of 6000
      expect(result.phase2Gap, 1200.0);

      // Phase 3: AI full rente (AVS/AI 2520 CHF)
      expect(result.aiRenteMensuelle, 2520.0);
      expect(result.phase3MonthlyBenefit, 2520.0);
      expect(result.phase3Gap, 3480.0);

      // Risk level: has IJM but gap > 3000 → medium
      expect(result.riskLevel, 'medium');
    });

    test('Pierre: GE self-employed, 10000 CHF, NO IJM, 100% disability', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 10000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'GE',
        anneesAnciennete: 0,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );

      // Phase 1: Self-employed = no employer coverage
      expect(result.phase1DurationWeeks, 0.0);
      expect(result.phase1MonthlyBenefit, 0.0);
      expect(result.phase1Gap, 10000.0);

      // Phase 2: No IJM
      expect(result.phase2MonthlyBenefit, 0.0);
      expect(result.phase2Gap, 10000.0);

      // Phase 3: AI full rente (AVS/AI 2520 CHF)
      expect(result.aiRenteMensuelle, 2520.0);
      expect(result.phase3MonthlyBenefit, 2520.0);
      expect(result.phase3Gap, 7480.0);

      // Risk level: self-employed without IJM → critical
      expect(result.riskLevel, 'critical');
      expect(result.alerts, contains(contains('CRITIQUE')));
    });

    test('Anna: BS employee, 1y seniority, 4500 CHF, NO IJM, 100% disability',
        () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 4500,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BS',
        anneesAnciennete: 0, // 1st year of service
        hasIjmCollective: false,
        degreInvalidite: 100,
      );

      // Phase 1: BS échelle bâloise, 1st year = 3 weeks
      expect(result.phase1DurationWeeks, 3.0);
      expect(result.phase1MonthlyBenefit, 4500.0);
      expect(result.phase1Gap, 0.0);

      // Phase 2: No IJM
      expect(result.phase2MonthlyBenefit, 0.0);
      expect(result.phase2Gap, 4500.0);

      // Phase 3: AI full rente (AVS/AI 2520 CHF)
      expect(result.aiRenteMensuelle, 2520.0);
      expect(result.phase3MonthlyBenefit, 2520.0);
      expect(result.phase3Gap, 1980.0);

      // Risk level: employee without IJM → high
      expect(result.riskLevel, 'high');
      expect(result.alerts, contains(contains('HAUT RISQUE')));
    });

    test('Partial disability (50%): check AI rente = 1260 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 50,
      );

      // AI rente at 50% disability = 1/2 rente (2520 * 0.5 = 1260)
      expect(result.aiRenteMensuelle, 1260.0);
      expect(result.phase3MonthlyBenefit, 1260.0);
      expect(result.phase3Gap, 6740.0);
    });

    test('Self-employed always gets risk level critical without IJM', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 5000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'LU',
        anneesAnciennete: 0,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );

      expect(result.riskLevel, 'critical');
      expect(result.alerts, isNotEmpty);
      // Check that at least one alert contains 'CRITIQUE'
      expect(result.alerts.any((a) => a.contains('CRITIQUE')), isTrue);
    });

    test('Employee with IJM and small gap gets low risk', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 3000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 10,
        hasIjmCollective: true,
        degreInvalidite: 100,
        lppDisabilityBenefit: 1000.0, // Additional LPP benefit
      );

      // Phase 3: AI + LPP (2520 + 1000)
      expect(result.phase3MonthlyBenefit, 3520.0);

      // Risk level: has IJM and gap < 3000 at phase 3
      // Gap = 3000 - 3450 = -450 (no gap!)
      expect(result.riskLevel, 'low');
    });

    test('ZH échelle zurichoise: 2nd year = 8 weeks', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 5000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );

      expect(result.phase1DurationWeeks, 8.0);
    });

    test('BS échelle bâloise: 2nd year = 9 weeks', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 5000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BS',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );

      expect(result.phase1DurationWeeks, 9.0);
    });

    test('BE échelle bernoise: 2nd year = 4 weeks', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 5000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BE',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );

      expect(result.phase1DurationWeeks, 4.0);
    });

    test('40% disability = 1/4 rente = 630 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 40,
      );

      expect(result.aiRenteMensuelle, 630.0); // 2520 * 0.25
    });

    test('60% disability = 3/4 rente = 1890 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 60,
      );

      expect(result.aiRenteMensuelle, 1890.0); // 2520 * 0.75
    });

    test('25+ years of service = 26 weeks in all cantons', () {
      for (final canton in supportedDisabilityCantons) {
        final result = computeDisabilityGap(
          revenuMensuelNet: 8000,
          statutProfessionnel: EmploymentStatusType.employee,
          canton: canton,
          anneesAnciennete: 25,
          hasIjmCollective: true,
          degreInvalidite: 100,
        );

        expect(result.phase1DurationWeeks, 26.0,
            reason: 'Canton $canton should have 26 weeks at 25+ years');
      }
    });

    test('Throws ArgumentError for unsupported canton', () {
      // All 26 Swiss cantons (including FR) are now supported.
      // Use a non-existent canton code to trigger ArgumentError.
      expect(
        () => computeDisabilityGap(
          revenuMensuelNet: 8000,
          statutProfessionnel: EmploymentStatusType.employee,
          canton: 'XX', // Non-existent canton
          anneesAnciennete: 5,
          hasIjmCollective: true,
          degreInvalidite: 100,
        ),
        throwsArgumentError,
      );
    });
  });
}
