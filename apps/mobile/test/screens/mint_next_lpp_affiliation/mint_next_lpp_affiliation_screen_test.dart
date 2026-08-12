import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_lpp_affiliation/mint_next_lpp_affiliation_screen.dart';
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
    SecureWizardStore.debugCanonicalLppAffiliationWriteOverride = null;
  });

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/lpp',
      routes: [
        GoRoute(
          path: '/lpp',
          builder: (_, __) => MintNextLppAffiliationScreen(
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

  MintNextLppAffiliationFact fact({bool affiliated = true}) =>
      MintNextLppAffiliationFact(
        affiliated: affiliated,
        assertedAt: DateTime.utc(2026, 8, 10),
        source: MintNextLppAffiliationFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  testWidgets(
      'collect shows the single question with two cards none preselected and '
      'nothing persists before confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Es-tu affilié·e à une caisse de pension LPP ?'),
        findsOneWidget);
    expect(find.textContaining('certificat'), findsOneWidget,
        reason: 'the help distinguishes affiliation from certificate');
    expect(find.text('Oui, je cotise actuellement'), findsOneWidget);
    expect(find.text('Non, je ne cotise pas actuellement'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing,
        reason: 'no card is preselected');

    await tester.tap(find.text('Oui, je cotise actuellement'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(provider.lppAffiliationFact, isNull,
        reason: 'review is not yet a confirmation');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets('safe exit before confirmation writes nothing', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Non, je ne cotise pas actuellement'));
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

    await tester.tap(find.text('Non, je ne cotise pas actuellement'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Caisse de pension enregistrée'), findsOneWidget);
    expect(find.text('Pas affilié·e actuellement'), findsOneWidget);
    expect(provider.lppAffiliationFact?.affiliated, isFalse);
    expect(
        MintNextLppAffiliationFact.statusOf(provider.lppAffiliationFact),
        MintNextLppAffiliationStatus.confirmedNo,
        reason: 'a confirmed no is a real answer, distinct from unknown');
  });

  testWidgets('an existing fact opens directly on the saved summary',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveLppAffiliationFact(fact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Caisse de pension enregistrée'), findsOneWidget);
    expect(find.text('Affilié·e à une caisse de pension'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation then returns to collect '
      'and the affiliation becomes unknown', (tester) async {
    final provider = await loadedProvider();
    await provider.saveLppAffiliationFact(fact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ta réponse ?'), findsOneWidget);
    expect(find.textContaining('inconnue'), findsOneWidget,
        reason: 'the dialog says the affiliation becomes unknown — the '
            'tri-state honesty is user-facing');
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(provider.lppAffiliationFact, isNull);
    expect(MintNextLppAffiliationFact.statusOf(provider.lppAffiliationFact),
        MintNextLppAffiliationStatus.unknown);
    expect(find.text('Es-tu affilié·e à une caisse de pension LPP ?'),
        findsOneWidget);
  });

  testWidgets('missing choice blocks with a visible error', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();

    expect(find.text('Choisis Oui ou Non pour continuer.'), findsOneWidget);
    expect(provider.lppAffiliationFact, isNull);
  });

  testWidgets(
      'a persistence failure shows the honest banner and never claims saved',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    SecureWizardStore.debugCanonicalLppAffiliationWriteOverride =
        () async => false;
    await tester.tap(find.text('Oui, je cotise actuellement'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      find.text("L'enregistrement n'a pas abouti. Tes données n'ont pas "
          'changé. Réessaie.'),
      findsOneWidget,
    );
    expect(find.text('Caisse de pension enregistrée'), findsNothing);
    expect(provider.lppAffiliationFact, isNull);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });
}
