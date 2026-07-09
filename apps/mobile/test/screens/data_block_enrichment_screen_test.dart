import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {CoachProfileProvider? coachProfileProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => coachProfileProvider ?? CoachProfileProvider(),
      ),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
    child: MaterialApp(locale: const Locale('fr'), localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ], supportedLocales: S.supportedLocales, home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('revenue block captures canonical first salary facts only',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('canton_picker')), 'ge');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(find.byKey(const Key('birth_year_input')), '2001');
    await tester.tap(find.byKey(const Key('has_pension_fund_switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect((answers['q_gross_salary_annual'] as num).toDouble(), 96000);
    expect(answers['q_canton'], 'GE');
    expect(answers['q_birth_year'], 2001);
    expect(answers['q_has_pension_fund'], true);
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);

    expect(provider.profile?.revenuBrutAnnuel, 96000);
    expect(provider.profile?.canton, 'GE');
    expect(provider.profile?.birthYear, 2001);
  });

  testWidgets('revenue block inputKey collects only the requested canton fact',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'canton',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canton_picker')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);
    expect(find.byKey(const Key('birth_year_input')), findsNothing);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsNothing);

    await tester.enterText(find.byKey(const Key('canton_picker')), 'ge');
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_canton', 'GE'));
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(answers.containsKey('q_has_pension_fund'), isFalse);
    expect(provider.profile?.canton, 'GE');
  });

  testWidgets('revenue block does not treat monthly income as annual input',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'incomeGrossMonthly',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('salary_input')), findsOneWidget);
    expect(find.byKey(const Key('canton_picker')), findsOneWidget);
    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);
  });

  testWidgets('revenue block birth-year inputKey requires a value',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'birthYear',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('birth_year_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(provider.profile, isNull);
    expect(find.text('Les informations saisies sont invalides.'), findsOneWidget);
  });

  testWidgets('revenue block pension inputKey can persist default false',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'revenu',
        initialInputKey: 'has2ndPillar',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('has_pension_fund_switch')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_pension_fund', false));
    expect(provider.profile, isNotNull);
  });

  testWidgets('patrimoine block inputKey collects only liquid savings',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(
        blockType: 'patrimoine',
        initialInputKey: 'totalSavings',
      ),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savings_input')), findsOneWidget);
    expect(find.byKey(const Key('salary_input')), findsNothing);

    await tester.enterText(find.byKey(const Key('savings_input')), '120000');
    await tester.tap(find.byKey(const Key('patrimoine_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 120000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(provider.profile?.patrimoine.epargneLiquide, 120000);
  });

  testWidgets('revenue block seeds pension switch from existing profile',
      (tester) async {
    final provider = CoachProfileProvider()
      ..updateFromAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_birth_year': 1990,
        'q_has_pension_fund': true,
      });

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('has_pension_fund_switch'));
    expect(tester.widget<SwitchListTile>(tile).value, true);
  });

  testWidgets('revenue block rejects underage birth year', (tester) async {
    final provider = CoachProfileProvider();
    final underageBirthYear = DateTime.now().year - 17;

    await tester.pumpWidget(_wrap(
      const DataBlockEnrichmentScreen(blockType: 'revenu'),
      coachProfileProvider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('canton_picker')), 'GE');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.enterText(
      find.byKey(const Key('birth_year_input')),
      '$underageBirthYear',
    );

    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_gross_salary_annual'), isFalse);
    expect(answers.containsKey('q_canton'), isFalse);
    expect(answers.containsKey('q_birth_year'), isFalse);
    expect(provider.profile, isNull);
  });

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
}
