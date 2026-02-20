import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_essentials.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_goal.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_income.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_stress.dart';

void main() {
  testWidgets('OnboardingStepStress smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingStepStress(
            selected: null,
            onSelected: (_) {},
            onContinue: () {},
          ),
        ),
      ),
    );

    expect(find.byType(OnboardingStepStress), findsOneWidget);
  });

  testWidgets('OnboardingStepEssentials smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingStepEssentials(
            birthYearController: TextEditingController(text: '1990'),
            canton: 'VD',
            birthYearError: null,
            onBirthYearChanged: (_) {},
            onCantonChanged: (_) {},
            onContinue: () {},
          ),
        ),
      ),
    );

    expect(find.byType(OnboardingStepEssentials), findsOneWidget);
  });

  testWidgets('OnboardingStepIncome smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingStepIncome(
            incomeController: TextEditingController(text: '6000'),
            taxController: TextEditingController(),
            lamalController: TextEditingController(),
            otherFixedController: TextEditingController(),
            employmentStatus: 'employee',
            householdType: 'single',
            incomeQuickPicks: const [4000, 6000],
            onIncomeChanged: (_) {},
            onIncomeQuickPick: (_) {},
            onEmploymentChanged: (_) {},
            onHouseholdChanged: (_) {},
            onContinue: () {},
          ),
        ),
      ),
    );

    expect(find.byType(OnboardingStepIncome), findsOneWidget);
  });

  testWidgets('OnboardingStepGoal smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingStepGoal(
            selectedGoal: 'retirement',
            preview: const {
              'targetLabel': 'Retraite',
              'prudent': 100000.0,
              'base': 140000.0,
              'optimiste': 190000.0,
            },
            onComplete: () {},
            onGoalSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(OnboardingStepGoal), findsOneWidget);
  });
}
