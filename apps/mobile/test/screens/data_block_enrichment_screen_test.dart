import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {CoachProfileProvider? coachProfileProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => coachProfileProvider ?? CoachProfileProvider(),
      ),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
    child: MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.supportedLocales,home: child),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPatrimoine(WidgetTester tester, CoachProfileProvider provider) async {
    await tester.pumpWidget(_wrap(const DataBlockEnrichmentScreen(blockType: 'patrimoine'), coachProfileProvider: provider));
    await tester.pumpAndSettle();
  }

  testWidgets('maps pension alias to LPP block metadata', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'pension')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('maps accented prevoyance alias to LPP block metadata',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'Prévoyance-LPP')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('unknown block shows migration-safe fallback', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'legacy_unknown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Données'), findsWidgets);
    expect(find.textContaining('n’est plus à jour'), findsOneWidget);
    expect(find.text('Ouvrir le diagnostic'), findsOneWidget);
  });

  testWidgets('revenue block captures canonical first salary facts only',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(
      _wrap(
        const DataBlockEnrichmentScreen(blockType: 'revenu'),
        coachProfileProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canton_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('canton_input')), 'GE');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(find.byKey(const Key('birth_year_input')), '2001');
    await tester.ensureVisible(
      find.byKey(const Key('has_pension_fund_switch')),
    );
    await tester.tap(find.byKey(const Key('has_pension_fund_switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 96000);
    expect(answers['q_canton'], 'GE');
    expect(answers['q_birth_year'], 2001);
    expect(answers['q_has_pension_fund'], true);
    expect(
      answers.keys.where((key) => key.startsWith('q_')).toSet(),
      {
        'q_gross_salary_annual',
        'q_canton',
        'q_birth_year',
        'q_has_pension_fund',
      },
    );
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
    expect(provider.profile?.revenuBrutAnnuel, 96000);
    expect(provider.profile?.canton, 'GE');
    expect(provider.profile?.birthYear, 2001);
  });

  testWidgets('patrimoine block captures mortgage project facts only', (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    expect(find.byKey(const Key('savings_input')), findsOneWidget);
    expect(find.byKey(const Key('target_property_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('canton_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('savings_input')), '250000');
    await tester.enterText(find.byKey(const Key('target_property_input')), '950000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 250000);
    expect(answers['q_target_property_value'], 950000);
    expect(answers.keys.where((key) => key.startsWith('q_')).toSet(), {'q_cash_total', 'q_target_property_value'});
    expect(answers.containsKey('q_property_market_value'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 250000);
    expect(provider.profile?.patrimoine.targetPropertyValue, 950000);
    expect(provider.profile?.patrimoine.propertyMarketValue, isNull);
  });

  testWidgets('patrimoine block saves liquid assets without target price', (tester) async {
    final provider = CoachProfileProvider();
    await pumpPatrimoine(tester, provider);

    await tester.enterText(find.byKey(const Key('savings_input')), '250000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 250000);
    expect(answers.containsKey('q_target_property_value'), isFalse);
  });

  testWidgets('patrimoine block does not seed estimated liquid assets', (tester) async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers(const {
      'q_canton': 'GE',
      'q_gross_salary_annual': 96000,
      'q_housing_cost_period_chf': 2000,
      'q_lamal_premium_monthly_chf': 400,
      'q_emergency_fund': 'yes_6months',
    });
    expect(provider.profile?.patrimoine.epargneLiquide, greaterThan(0));

    await pumpPatrimoine(tester, provider);

    final savingsField = tester.widget<TextField>(find.byKey(const Key('savings_input')));
    expect(savingsField.controller?.text, isEmpty);

    await tester.enterText(find.byKey(const Key('target_property_input')), '950000');
    await tester.ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_target_property_value'], 950000);
    expect(answers.containsKey('q_cash_total'), isFalse);
  });
}
