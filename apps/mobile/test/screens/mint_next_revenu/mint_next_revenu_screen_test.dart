import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_revenu/mint_next_revenu_screen.dart';
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
    SecureWizardStore.debugCanonicalRevenuWriteOverride = null;
  });

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/revenu',
      routes: [
        GoRoute(
          path: '/revenu',
          builder: (_, __) => MintNextRevenuScreen(
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

  MintNextRevenuFact monthlyFact({int amountCents = 650000}) =>
      MintNextRevenuFact(
        amountCents: amountCents,
        period: MintNextRevenuPeriod.monthly,
        assertedAt: DateTime.utc(2026, 8, 10),
        source: MintNextRevenuFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> fillAndContinue(WidgetTester tester,
      {String amount = '6500', String period = 'Par mois'}) async {
    await tester.enterText(find.byType(TextField), amount);
    await tester.ensureVisible(find.text(period));
    await tester.tap(find.text(period));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'collect shows amount entry and two period cards none preselected and '
      'nothing persists before confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Combien reçois-tu ?'), findsOneWidget);
    expect(find.text("Ton revenu net, tel qu'il arrive sur ton compte."),
        findsOneWidget);
    expect(find.text('Par mois'), findsOneWidget);
    expect(find.text('Par an'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing,
        reason: 'no period is preselected');

    await fillAndContinue(tester);

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(find.textContaining("6'500 CHF"), findsOneWidget);
    expect(provider.revenuFact, isNull,
        reason: 'review is not yet a confirmation');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets('safe exit before confirmation writes nothing', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '6500');
    await tester.tap(find.text('Par mois'));
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

    await fillAndContinue(tester);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Revenu enregistré'), findsOneWidget);
    expect(find.textContaining("6'500 CHF"), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(provider.revenuFact?.amountCents, 650000);
    expect(provider.revenuFact?.period, MintNextRevenuPeriod.monthly);
    expect(provider.revenuFact?.needsConfirmation, isFalse);
  });

  testWidgets('an existing fact opens directly on the saved summary',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveRevenuFact(monthlyFact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Revenu enregistré'), findsOneWidget);
    expect(find.textContaining("6'500 CHF"), findsOneWidget);
  });

  testWidgets('delete asks for confirmation then returns to collect',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveRevenuFact(monthlyFact());
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ton revenu ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(provider.revenuFact, isNull);
    expect(find.text('Combien reçois-tu ?'), findsOneWidget);
  });

  testWidgets('missing amount or period blocks with a visible error',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.text('Indique ton montant et choisis une période pour continuer.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Par mois'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.text('Indique ton montant et choisis une période pour continuer.'),
      findsOneWidget,
      reason: 'a zero amount is not a valid income',
    );
    expect(provider.revenuFact, isNull);
  });

  test('amount parsing is lexical, exact and never silently corrected', () {
    expect(MintNextRevenuScreen.parseAmountCents("6'500.50"), 650050);
    expect(MintNextRevenuScreen.parseAmountCents('6,5'), 650);
    expect(MintNextRevenuScreen.parseAmountCents('6500'), 650000);
    expect(MintNextRevenuScreen.parseAmountCents(''), isNull);
    expect(MintNextRevenuScreen.parseAmountCents('0'), isNull);
    expect(MintNextRevenuScreen.parseAmountCents('0.004'), isNull,
        reason: 'more than two decimals is invalid, never rounded');
    expect(MintNextRevenuScreen.parseAmountCents('1e9'), isNull,
        reason: 'scientific notation is rejected, never corrected to 19 CHF');
    expect(MintNextRevenuScreen.parseAmountCents('-500'), isNull);
    expect(MintNextRevenuScreen.parseAmountCents('999999999.99'), 99999999999,
        reason: 'the explicit ceiling is exact in integer cents');
    expect(MintNextRevenuScreen.parseAmountCents('1000000000'), isNull,
        reason: 'above the ceiling is invalid — far below 2^53, always exact');
  });

  testWidgets(
      'a persistence failure shows the honest banner and never claims saved',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    SecureWizardStore.debugCanonicalRevenuWriteOverride = () async => false;
    await fillAndContinue(tester, period: 'Par an', amount: '78000');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      find.text("L'enregistrement n'a pas abouti. Tes données n'ont pas "
          'changé. Réessaie.'),
      findsOneWidget,
    );
    expect(find.text('Revenu enregistré'), findsNothing,
        reason: 'a failed save never claims success');
    expect(provider.revenuFact, isNull);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty,
        reason: 'no half-written fact survives the failure');
  });
}
