import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoachProfile _profile({double salary = 10000, String canton = 'VS'}) {
  return CoachProfile(
    birthYear: 1977,
    canton: canton,
    salaireBrutMensuel: salary,
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2028, 6),
      label: 'Achat logement',
    ),
  );
}

MonthlyCheckIn _checkIn(Map<String, double> versements) {
  return MonthlyCheckIn(
    month: DateTime(2026, 6),
    versements: versements,
    completedAt: DateTime(2026, 6, 30),
  );
}

void main() {
  group('financial plan follow-up integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'generates saved plan, detects stale profile, and evaluates check-in gap',
      () async {
        final originalProfile = _profile();
        final generatedPlan = await PlanGenerationService.generate(
          goalDescription: 'Acheter un logement',
          goalCategory: 'goal_house',
          targetDate: DateTime.now().add(const Duration(days: 365 * 3)),
          profile: originalProfile,
          goalAmount: 85000,
          coachNarrative: 'Plan educatif pour suivre les versements mensuels.',
        );

        final restartedProvider = FinancialPlanProvider();
        await restartedProvider.loadFromPersistence();

        expect(restartedProvider.hasPlan, isTrue);
        expect(restartedProvider.currentPlan!.id, generatedPlan.id);
        expect(
          restartedProvider.currentPlan!.monthlyTarget,
          closeTo(generatedPlan.monthlyTarget, 0.01),
        );

        restartedProvider.checkStalenessForTest(originalProfile);
        expect(restartedProvider.isPlanStale, isFalse);

        final updatedProfile = _profile(salary: 12000);
        restartedProvider.checkStalenessForTest(updatedProfile);
        expect(restartedProvider.isPlanStale, isTrue);

        final firstTarget = generatedPlan.monthlyTarget * 0.55;
        final secondTarget = generatedPlan.monthlyTarget * 0.45;
        final secondActual = secondTarget * 0.5;
        final expectedGap = secondTarget - secondActual;

        final contributions = [
          PlannedMonthlyContribution(
            id: '3a_julien',
            label: '3a Julien',
            amount: firstTarget,
            category: '3a',
          ),
          PlannedMonthlyContribution(
            id: 'lpp_buyback',
            label: 'Rachat LPP',
            amount: secondTarget,
            category: 'lpp_buyback',
          ),
        ];

        final status = PlanTrackingService.evaluate(
          checkIns: [
            _checkIn({
              '3a_julien': firstTarget,
              'lpp_buyback': secondActual,
            }),
          ],
          contributions: contributions,
        );

        expect(status.completedActions, 1);
        expect(status.totalActions, 2);
        expect(status.score, 50);
        expect(
          status.averageMonthlyActual,
          closeTo(firstTarget + secondActual, 0.01),
        );
        expect(status.monthlyGapChf, closeTo(expectedGap, 0.01));
        expect(status.nextActions.single, startsWith('Rachat LPP : +'));

        final impact = PlanTrackingService.compoundProjectedImpact(
          status: status,
          monthsToRetirement: 120,
          annualReturn: 0.02,
        );

        expect(impact, greaterThan(30000));
      },
    );
  });
}
