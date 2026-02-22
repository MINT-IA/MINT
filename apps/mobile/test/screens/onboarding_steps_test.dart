import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_essentials.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_goal.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_income.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_stress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithProvider(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingProvider(),
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('OnboardingStepStress smoke', (tester) async {
    await tester.pumpWidget(
      wrapWithProvider(
        OnboardingStepStress(
          firstNameController: TextEditingController(),
          onContinue: () {},
        ),
      ),
    );

    expect(find.byType(OnboardingStepStress), findsOneWidget);
  });

  testWidgets('OnboardingStepEssentials smoke', (tester) async {
    await tester.pumpWidget(
      wrapWithProvider(
        OnboardingStepEssentials(
          birthYearController: TextEditingController(text: '1990'),
          onContinue: () {},
        ),
      ),
    );

    expect(find.byType(OnboardingStepEssentials), findsOneWidget);
  });

  testWidgets('OnboardingStepIncome smoke', (tester) async {
    await tester.pumpWidget(
      wrapWithProvider(
          OnboardingStepIncome(
            incomeController: TextEditingController(text: '6000'),
            housingController: TextEditingController(text: '1800'),
            debtPaymentsController: TextEditingController(text: '0'),
            cashSavingsController: TextEditingController(),
            investmentsController: TextEditingController(),
            pillar3aTotalController: TextEditingController(),
            taxController: TextEditingController(),
          lamalController: TextEditingController(),
          otherFixedController: TextEditingController(),
          partnerIncomeController: TextEditingController(),
          partnerBirthYearController: TextEditingController(),
          partnerFirstNameController: TextEditingController(),
          onIncomeQuickPick: (_) {},
          onContinue: () {},
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
