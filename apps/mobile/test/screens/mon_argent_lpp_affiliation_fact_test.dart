import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  });

  tearDown(SecureWizardStore.resetSealFallbackForTest);

  Future<CoachProfileProvider> providerWithLpp() async {
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await provider.saveLppAffiliationFact(MintNextLppAffiliationFact(
      affiliated: true,
      assertedAt: DateTime.utc(2026, 8, 11),
      source: MintNextLppAffiliationFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    return provider;
  }

  Widget wrap(CoachProfileProvider coachProvider) => MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coachProvider,
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
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
          home: MonArgentScreen(initialSection: 'today'),
        ),
      );

  testWidgets('mon argent shows the saved lpp affiliation with provenance',
      (tester) async {
    final coachProvider = await providerWithLpp();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('mon_argent_lpp_affiliation_fact')), findsOneWidget);
    expect(find.text('Affilié·e à une caisse de pension'), findsOneWidget);
    expect(
      find.byKey(const Key('mon_argent_lpp_affiliation_fact_provenance')),
      findsOneWidget,
    );
  });

  testWidgets('mon argent delete removes the lpp affiliation after confirmation',
      (tester) async {
    final coachProvider = await providerWithLpp();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ta réponse ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(coachProvider.lppAffiliationFact, isNull);
    expect(find.byKey(const Key('mon_argent_lpp_affiliation_fact')), findsNothing);
  });
}
