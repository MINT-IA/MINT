import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saving housing costs does not overwrite income pay frequency',
      (tester) async {
    await ReportPersistenceService.saveAnswers(const {
      'q_net_income_period_chf': 120000,
      'q_pay_frequency': 'yearly',
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: BudgetSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '2000');
    await tester.enterText(fields.at(1), '400');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_pay_frequency'], 'yearly');
    expect(answers['q_housing_cost_frequency'], 'monthly');
    expect(answers['q_housing_cost_period_chf'], 2000);
    expect(answers['q_lamal_premium_monthly_chf'], 400);
  });
}
