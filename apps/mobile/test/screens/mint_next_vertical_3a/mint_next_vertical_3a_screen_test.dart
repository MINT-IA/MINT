import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_vertical_3a/mint_next_vertical_3a_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void resetStores() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  }

  setUp(resetStores);
  tearDown(SecureWizardStore.resetSealFallbackForTest);

  final now = DateTime.utc(2026, 8, 12, 15);

  Widget wrap(CoachProfileProvider provider,
      {DateTime Function()? clock, Set<String>? allowlistOverride}) {
    final router = GoRouter(
      initialLocation: '/vertical',
      routes: [
        GoRoute(
          path: '/vertical',
          builder: (_, __) => MintNextVertical3aScreen(
              now: clock ?? () => now,
              allowlistOverride: allowlistOverride),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: SizedBox(key: ValueKey('home_stub'))),
        ),
        GoRoute(
          path: '/mint-next/lpp-affiliation',
          builder: (_, __) =>
              const Scaffold(body: SizedBox(key: ValueKey('lpp_stub'))),
        ),
        GoRoute(
          path: '/mint-next/revenu',
          builder: (_, __) =>
              const Scaffold(body: SizedBox(key: ValueKey('revenu_stub'))),
        ),
        GoRoute(
          path: '/mint-next/versements-3a',
          builder: (_, __) => const Scaffold(
              body: SizedBox(key: ValueKey('versements_stub'))),
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

  MintNextVersement3aEntry entry(int amountCents) => MintNextVersement3aEntry(
        id: 'v1',
        amountCents: amountCents,
        creditedAt: DateTime.utc(2026, 3, 15),
        taxYear: 2026,
      );

  Future<CoachProfileProvider> providerWith({
    int? versedCents = 550000,
    bool? affiliated = true,
    int? revenuCents,
  }) async {
    resetStores();
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    if (affiliated != null) {
      await provider.saveLppAffiliationFact(MintNextLppAffiliationFact(
        affiliated: affiliated,
        assertedAt: now,
        source: 'user_declaration',
        schemaVersion: 1,
        needsConfirmation: false,
      ));
    }
    if (revenuCents != null) {
      await provider.saveRevenuFact(MintNextRevenuFact(
        amountCents: revenuCents,
        period: MintNextRevenuPeriod.yearly,
        assertedAt: now,
        source: 'user_declaration',
        schemaVersion: 1,
        needsConfirmation: false,
      ));
    }
    if (versedCents != null) {
      await provider.saveVersements3aFact(
          MintNextVersements3aFact.empty(at: now)
              .withEntryAdded(entry(versedCents), now));
    }
    return provider;
  }

  testWidgets(
      'a positive, zero and negative marge each render with year, freshness '
      'and provenance', (tester) async {
    final positive = await providerWith();
    await tester.pumpWidget(wrap(positive));
    await tester.pumpAndSettle();
    expect(find.text("Il te reste 1'758 CHF de marge."), findsOneWidget);
    expect(find.text('ANNÉE FISCALE 2026'), findsOneWidget);
    expect(find.byKey(const Key('vertical_3a_provenance')), findsOneWidget);
    expect(find.byKey(const Key('vertical_3a_freshness')), findsOneWidget,
        reason: 'la fraîcheur des faits est affichée, pas seulement promise');
    expect(find.textContaining('Faits au'), findsOneWidget);
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_175800'),
        findsOneWidget);

    final zero = await providerWith(versedCents: 725800);
    await tester.pumpWidget(wrap(zero));
    await tester.pumpAndSettle();
    expect(find.text('Il te reste 0 CHF de marge.'), findsOneWidget,
        reason: 'marge nulle = constat exact, ni écart ni dépassement');
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_0'),
        findsOneWidget);

    final negative = await providerWith(versedCents: 1100000);
    await tester.pumpWidget(wrap(negative));
    await tester.pumpAndSettle();
    expect(find.text("Plafond dépassé de 3'742 CHF."), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('mint_next_vertical_3a_marge_-374200'),
        findsOneWidget,
        reason: 'marge SIGNÉE — jamais clampée à zéro');
  });

  testWidgets(
      'every fail-closed state of the engine has a reachable public rendering',
      (tester) async {
    final lppUnknown = await providerWith(affiliated: null);
    await tester.pumpWidget(wrap(lppUnknown));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_lppAffiliationUnknown'),
        findsOneWidget);

    final incomeMissing = await providerWith(affiliated: false);
    await tester.pumpWidget(wrap(incomeMissing));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_incomeMissing'),
        findsOneWidget);

    final noContributions = await providerWith(versedCents: null);
    await tester.pumpWidget(wrap(noContributions));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_contributionsMissing'),
        findsOneWidget);

    final unsupported = await providerWith();
    await tester.pumpWidget(
        wrap(unsupported, clock: () => DateTime.utc(2027, 2, 1)));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_unsupportedTaxYear'),
        findsOneWidget,
        reason: 'année hors registre = état honnête, jamais une reprise 2026');

    final unattested = await providerWith();
    await tester.pumpWidget(
        wrap(unattested, allowlistOverride: {'not-a-real-hash'}));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_regulatoryConstantsUnattested'),
        findsOneWidget,
        reason: 'hash hors allowlist = état atteint et rendu, pas déclaré');

    // staleInputs est structurellement impossible (recalcul à chaque build)
    // — l'écran le traite en invariant, prouvé au calculateur (revalidate).
  });

  testWidgets(
      'loading, read failure and missing data render as three distinct states',
      (tester) async {
    // Chargement : provider pas encore rechargé — aucun état métier affirmé.
    final loading = CoachProfileProvider();
    await tester.pumpWidget(wrap(loading));
    await tester.pump();
    expect(find.bySemanticsIdentifier('node:vertical_3a.loading'),
        findsOneWidget);
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_lppAffiliationUnknown'),
        findsNothing,
        reason: 'le chargement ne se déguise jamais en fait manquant');

    // Fait manquant : provider chargé, fait absent — état métier nommé.
    final missing = await providerWith(affiliated: null);
    await tester.pumpWidget(wrap(missing));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_lppAffiliationUnknown'),
        findsOneWidget);

    // Échec de lecture : état DISTINCT — aucun état métier n'est affirmé
    // sur des faits que MINT n'a pas pu relire.
    CoachProfileProvider.debugForceLoadFailureForTest = true;
    addTearDown(
        () => CoachProfileProvider.debugForceLoadFailureForTest = false);
    final failed = CoachProfileProvider();
    await failed.loadFromWizard();
    await tester.pumpWidget(wrap(failed));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('node:vertical_3a.read_failure'),
        findsOneWidget);
    expect(
        find.bySemanticsIdentifier(
            'mint_next_vertical_3a_state_lppAffiliationUnknown'),
        findsNothing,
        reason: 'une lecture en échec ne se déguise jamais en fait manquant');
  });

  testWidgets(
      'lpp, income and contributions blocking states each navigate to the '
      'canonical edit screen of their fact', (tester) async {
    final lppUnknown = await providerWith(affiliated: null);
    await tester.pumpWidget(wrap(lppUnknown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Répondre à la question caisse de pension'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lpp_stub')), findsOneWidget);

    final incomeMissing = await providerWith(affiliated: false);
    await tester.pumpWidget(wrap(incomeMissing));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indiquer mon revenu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('revenu_stub')), findsOneWidget);

    final noContributions = await providerWith(versedCents: null);
    await tester.pumpWidget(wrap(noContributions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer un versement'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('versements_stub')), findsOneWidget);
  });

  testWidgets(
      'unsupported year and unattested constants render as non editable '
      'factual states without any CTA', (tester) async {
    final provider = await providerWith();
    await tester.pumpWidget(
        wrap(provider, clock: () => DateTime.utc(2027, 2, 1)));
    await tester.pumpAndSettle();
    expect(find.text("Le plafond 2027 n’est pas encore attesté dans MINT."),
        findsOneWidget);
    expect(find.byType(FilledButton), findsNothing,
        reason: 'aucun faux CTA — il n\'y a aucun fait utilisateur à corriger');
  });

  testWidgets(
      'returning from a correction re-derives the displayed marge without '
      'any write', (tester) async {
    final provider = await providerWith();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_175800'),
        findsOneWidget);

    final before = await ReportPersistenceService.loadAnswers();
    await provider.saveVersements3aFact(provider.versements3aFact!
        .withEntryUpdated('v1', entry(600000), now));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_125800'),
        findsOneWidget,
        reason: 'une marge périmée ne survit jamais à la correction');
    final after = await ReportPersistenceService.loadAnswers();
    expect(
        after.keys.where((k) => !k.startsWith('q_versements_3a')).toSet(),
        before.keys.where((k) => !k.startsWith('q_versements_3a')).toSet(),
        reason: 'le vertical n\'écrit RIEN — seule la correction du fait '
            'a bougé ses propres clés');
  });

  testWidgets('the vertical shows the same attested result after a cold '
      'relaunch', (tester) async {
    final provider = await providerWith();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_175800'),
        findsOneWidget);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    await tester.pumpWidget(wrap(reloaded));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('mint_next_vertical_3a_marge_175800'),
        findsOneWidget,
        reason: 'même vérité depuis les faits scellés');
  });

  test('the vertical consumes the canonical calculator only and holds no '
      'local formula', () {
    final source = File(
            'lib/screens/mint_next_vertical_3a/mint_next_vertical_3a_screen.dart')
        .readAsStringSync();
    expect(source.contains('MintNextMarge3aCalculator'), isTrue,
        reason: 'le calculateur canonique est l\'UNIQUE voie');
    for (final marker in [
      RegExp(r'\b7258\b'),
      RegExp(r'\b725800\b'),
      RegExp(r'\b3628800\b'),
      RegExp(r'\*\s*20\b'),
      RegExp(r'~/\s*100\b'),
    ]) {
      expect(marker.hasMatch(source), isFalse,
          reason: 'aucune formule locale — doublé par le guard commit-gate');
    }
  });

  test('no parallel writer nor bare key exists in the vertical', () {
    final source = File(
            'lib/screens/mint_next_vertical_3a/mint_next_vertical_3a_screen.dart')
        .readAsStringSync();
    for (final marker in [
      'mergeAnswers(',
      'saveVersements3aFact',
      'saveRevenuFact',
      'saveLppAffiliationFact',
      'saveAnswers(',
    ]) {
      expect(source.contains(marker), isFalse,
          reason: 'surface de lecture pure — aucun writer');
    }
  });
}
