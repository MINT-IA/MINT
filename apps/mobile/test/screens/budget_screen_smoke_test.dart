import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('BudgetScreen smoke test - renders correctly',
      (WidgetTester tester) async {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_gross_salary_annual': 60000.0,
      'q_housing_cost_period_chf': 1500.0,
      'q_lamal_premium_monthly_chf': 400.0,
    });
    final provider = BudgetProvider()..rehydrateFromProfile(profile);
    final inputs = provider.inputs!;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: provider,
          child: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(provider.plan?.available, greaterThan(0));
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('BudgetScreen Stop Rule triggers warning',
      (WidgetTester tester) async {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_gross_salary_annual': 24000.0,
      'q_housing_cost_period_chf': 2000.0,
      'q_lamal_premium_monthly_chf': 400.0,
    });
    final provider = BudgetProvider()..rehydrateFromProfile(profile);
    final inputs = provider.inputs!;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: provider,
          child: BudgetScreen(inputs: inputs),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(provider.plan?.stopRuleTriggered, isTrue);
    expect(find.textContaining('Stop Rule Triggered'), findsOneWidget);
  });
}
