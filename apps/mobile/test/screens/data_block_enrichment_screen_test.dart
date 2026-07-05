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
