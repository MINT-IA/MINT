import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
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

  Future<CoachProfileProvider> providerWithVersements() async {
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await provider.saveVersements3aFact(
        MintNextVersements3aFact.empty(at: DateTime.utc(2026, 8, 11))
            .withEntryAdded(
                MintNextVersement3aEntry(
                  id: 'v1',
                  amountCents: 350000,
                  creditedAt: DateTime.utc(2026, 3, 15),
                  taxYear: 2026,
                ),
                DateTime.utc(2026, 8, 11)));
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

  testWidgets('mon argent shows the versements totals with provenance',
      (tester) async {
    final coachProvider = await providerWithVersements();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('mon_argent_versements_3a_fact')), findsOneWidget);
    expect(find.textContaining("total 3'500 CHF"), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('mon_argent_versements_3a_total_2026_350000'),
      findsOneWidget,
      reason: 'la preuve runtime asserte cet id porteur de valeur — le '
          'format année_centimes est un contrat, pas un détail',
    );
    expect(
      find.byKey(const Key('mon_argent_versements_3a_fact_provenance')),
      findsOneWidget,
    );
  });

  testWidgets('mon argent delete-all removes the versements after confirmation',
      (tester) async {
    final coachProvider = await providerWithVersements();
    await tester.pumpWidget(wrap(coachProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Tout supprimer'));
    await tester.tap(find.text('Tout supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer tous tes versements ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(coachProvider.versements3aFact, isNull);
    expect(find.byKey(const Key('mon_argent_versements_3a_fact')), findsNothing);
  });
}
