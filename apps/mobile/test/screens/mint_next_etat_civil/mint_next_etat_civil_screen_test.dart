import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_etat_civil/mint_next_etat_civil_screen.dart';
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

  tearDown(() {
    SecureWizardStore.resetSealFallbackForTest();
    SecureWizardStore.debugCanonicalCivilStatusWriteOverride = null;
  });

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/etat-civil',
      routes: [
        GoRoute(
          path: '/etat-civil',
          builder: (_, __) => MintNextEtatCivilScreen(
            now: () => DateTime.utc(2026, 8, 11, 9),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(
            body: SizedBox(key: ValueKey('home_after_exit')),
          ),
        ),
      ],
    );
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  Future<CoachProfileProvider> loadedProvider() async {
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    return provider;
  }

  MintNextCivilStatusFact marieFact() => MintNextCivilStatusFact(
        status: MintNextCivilStatus.marie,
        assertedAt: DateTime.utc(2026, 8, 10),
        source: MintNextCivilStatusFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> pickAndContinue(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'collect shows six civil status cards none preselected and nothing '
      'persists before confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Quelle est ta situation ?'), findsOneWidget);
    expect(
      find.text('Pour la fiscalité, ta situation au 31 décembre fait foi.'),
      findsOneWidget,
    );
    for (final label in [
      'Célibataire',
      'Marié·e',
      'En partenariat enregistré',
      'En concubinage',
      'Divorcé·e',
      'Veuf·ve',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.check_circle), findsNothing,
        reason: 'no card is preselected');
    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing,
        reason: 'six cards, no dropdown');

    await pickAndContinue(tester, 'Marié·e');

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(provider.civilStatusFact, isNull,
        reason: 'review is not yet a confirmation');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets('safe exit before confirmation writes nothing', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('En concubinage'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_after_exit')), findsOneWidget);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets(
      'confirm persists the fact and the saved summary offers edit and delete',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await pickAndContinue(tester, 'En partenariat enregistré');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('État civil enregistré'), findsOneWidget);
    expect(find.text('En partenariat enregistré'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(provider.civilStatusFact?.status,
        MintNextCivilStatus.partenariatEnregistre);
    expect(provider.civilStatusFact?.needsConfirmation, isFalse);
    expect(provider.civilStatusFact?.status.jointTaxation, isTrue,
        reason: 'registered partnership is taxed jointly, never as '
            'concubinage');
  });

  testWidgets('an existing fact opens directly on the saved summary',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveCivilStatusFact(marieFact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('État civil enregistré'), findsOneWidget);
    expect(find.text('Marié·e'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation then returns to collect',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveCivilStatusFact(marieFact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ton état civil ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(provider.civilStatusFact, isNull);
    expect(find.text('Quelle est ta situation ?'), findsOneWidget);
  });

  testWidgets('missing selection blocks with a visible error',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();

    expect(find.text('Choisis ta situation pour continuer.'), findsOneWidget);
    expect(provider.civilStatusFact, isNull);
  });

  testWidgets(
      'a persistence failure shows the honest banner and never claims saved',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    SecureWizardStore.debugCanonicalCivilStatusWriteOverride =
        () async => false;
    await pickAndContinue(tester, 'Divorcé·e');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      find.text("L'enregistrement n'a pas abouti. Tes données n'ont pas "
          'changé. Réessaie.'),
      findsOneWidget,
    );
    expect(find.text('État civil enregistré'), findsNothing,
        reason: 'a failed save never claims success');
    expect(provider.civilStatusFact, isNull);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty,
        reason: 'no half-written fact survives the failure');
  });
}
