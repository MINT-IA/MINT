import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_versements_3a/mint_next_versements_3a_screen.dart';
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
    SecureWizardStore.debugCanonicalVersements3aWriteOverride = null;
  });

  final now = DateTime.utc(2026, 8, 11, 9);

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/versements',
      routes: [
        GoRoute(
          path: '/versements',
          builder: (_, __) => MintNextVersements3aScreen(now: () => now),
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

  Future<void> fillEntry(WidgetTester tester,
      {String amount = '3500', String date = '15.03.2026'}) async {
    await tester.enterText(
        find.byType(TextField).at(0), amount);
    await tester.enterText(find.byType(TextField).at(1), date);
    await tester.pump();
  }

  Future<void> continueAndConfirm(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
  }

  test('credit date parsing is strict — 31.02 is rejected, never corrected',
      () {
    expect(MintNextVersements3aScreen.parseCreditDate('15.03.2026'),
        DateTime.utc(2026, 3, 15));
    expect(MintNextVersements3aScreen.parseCreditDate('31.02.2026'), isNull);
    expect(MintNextVersements3aScreen.parseCreditDate('2026-03-15'), isNull);
    expect(MintNextVersements3aScreen.parseCreditDate(''), isNull);
  });

  testWidgets(
      'collect shows amount and credit date as one factual decision and '
      'nothing persists before confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Enregistrer ce versement'), findsOneWidget);
    await fillEntry(tester);
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(find.textContaining("3'500 CHF"), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets,
        reason: 'the pinned tax year is shown at review');
    expect(provider.versements3aFact, isNull,
        reason: 'review is not yet a confirmation');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets('safe exit before confirmation writes nothing', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await fillEntry(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_after_exit')), findsOneWidget);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets(
      'confirm appends the entry and the list shows the derived total',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await fillEntry(tester);
    await continueAndConfirm(tester);

    expect(find.text('Tes versements enregistrés'), findsOneWidget);
    expect(find.textContaining("total 3'500 CHF"), findsOneWidget);
    expect(provider.versements3aFact!.entries.length, 1);
    expect(provider.versements3aFact!.entries.single.taxYear, 2026);

    // Deuxième versement — le total annuel se re-dérive.
    await tester.tap(find.text('Ajouter un versement'));
    await tester.pumpAndSettle();
    await fillEntry(tester, amount: '2000', date: '01.06.2026');
    await continueAndConfirm(tester);
    expect(find.textContaining("total 5'500 CHF"), findsOneWidget);
    expect(provider.versements3aFact!.entries.length, 2);
  });

  testWidgets('editing one entry keeps its id and the others untouched',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();
    await fillEntry(tester);
    await continueAndConfirm(tester);
    await tester.tap(find.text('Ajouter un versement'));
    await tester.pumpAndSettle();
    await fillEntry(tester, amount: '2000', date: '01.06.2026');
    await continueAndConfirm(tester);
    final idBefore = provider.versements3aFact!.entries.first.id;

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '4000');
    await continueAndConfirm(tester);

    expect(provider.versements3aFact!.entries.length, 2,
        reason: 'a correction is never delete + duplicate');
    expect(provider.versements3aFact!.entryById(idBefore)!.amountCents,
        400000);
    expect(find.textContaining("total 6'000 CHF"), findsOneWidget);
  });

  testWidgets('deleting one entry removes only that entry', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();
    await fillEntry(tester);
    await continueAndConfirm(tester);
    await tester.tap(find.text('Ajouter un versement'));
    await tester.pumpAndSettle();
    await fillEntry(tester, amount: '2000', date: '01.06.2026');
    await continueAndConfirm(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce versement ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(provider.versements3aFact!.entries.length, 1);
    expect(find.textContaining("total 2'000 CHF"), findsOneWidget);
  });

  testWidgets('missing amount or date blocks with a visible error',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.text('Indique le montant et la date de crédit pour continuer.'),
      findsOneWidget,
    );

    await fillEntry(tester, date: '31.02.2026');
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.text('Indique le montant et la date de crédit pour continuer.'),
      findsOneWidget,
      reason: 'an impossible date is rejected, never corrected',
    );
    expect(provider.versements3aFact, isNull);
  });

  testWidgets(
      'a persistence failure shows the honest banner and never claims saved',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    SecureWizardStore.debugCanonicalVersements3aWriteOverride =
        () async => false;
    await fillEntry(tester);
    await continueAndConfirm(tester);

    expect(
      find.text("L'enregistrement n'a pas abouti. Tes données n'ont pas "
          'changé. Réessaie.'),
      findsOneWidget,
    );
    expect(find.text('Tes versements enregistrés'), findsNothing);
    expect(provider.versements3aFact, isNull);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });
}
