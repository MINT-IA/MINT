import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
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

  Future<CoachProfileProvider> providerWithCivilStatus() async {
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await provider.saveCivilStatusFact(MintNextCivilStatusFact(
      status: MintNextCivilStatus.partenariatEnregistre,
      assertedAt: DateTime.utc(2026, 8, 11),
      source: MintNextCivilStatusFact.userDeclarationSource,
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

  testWidgets('mon argent shows the saved civil status with provenance',
      (tester) async {
    final coachProvider = await providerWithCivilStatus();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('mon_argent_etat_civil_fact')), findsOneWidget);
    expect(find.text('En partenariat enregistré'), findsOneWidget);
    expect(
      find.byKey(const Key('mon_argent_etat_civil_fact_provenance')),
      findsOneWidget,
    );
  });

  testWidgets('mon argent delete removes the civil status after confirmation',
      (tester) async {
    final coachProvider = await providerWithCivilStatus();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ton état civil ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(coachProvider.civilStatusFact, isNull);
    expect(find.byKey(const Key('mon_argent_etat_civil_fact')), findsNothing);
  });
}
