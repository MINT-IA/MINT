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
import 'package:mint_mobile/screens/mint_next_versements_3a/mint_next_versements_3a_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/mint_next_marge_3a_calculator.dart';
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
    FeatureFlags.enableMintNextMarge3a = true;
  });

  tearDown(() {
    FeatureFlags.enableMintNextMarge3a = false;
    SecureWizardStore.resetSealFallbackForTest();
  });

  final now = DateTime.utc(2026, 8, 12, 9);

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/versements',
      routes: [
        GoRoute(
          path: '/versements',
          builder: (_, __) => MintNextVersements3aScreen(now: () => now),
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

  MintNextVersement3aEntry entry({
    String id = 'v1',
    int amountCents = 550000,
  }) =>
      MintNextVersement3aEntry(
        id: id,
        amountCents: amountCents,
        creditedAt: DateTime.utc(2026, 3, 15),
        taxYear: 2026,
      );

  Future<CoachProfileProvider> providerWith({
    int? versedCents = 550000,
    bool? affiliated = true,
    int? revenuCents,
  }) async {
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
      await provider.saveVersements3aFact(MintNextVersements3aFact.empty(at: now)
          .withEntryAdded(entry(amountCents: versedCents), now));
    }
    return provider;
  }

  testWidgets(
      'the vertical shows versé, plafond and signed marge above the annual '
      'list', (tester) async {
    final provider = await providerWith();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Versé en 2026'), findsOneWidget);
    expect(find.text('Plafond 2026'), findsOneWidget);
    expect(find.text('Marge restante'), findsOneWidget);
    expect(find.text("1'758 CHF"), findsOneWidget,
        reason: '725800 − 550000 = 175800 cents — exact, attesté');
    expect(
      find.bySemanticsIdentifier('mint_next_marge_3a_marge_175800'),
      findsOneWidget,
      reason: 'id porteur de valeur — la preuve runtime asserte le montant',
    );
  });

  testWidgets('an overshoot reads plafond dépassé de X CHF, never zero',
      (tester) async {
    final provider = await providerWith(versedCents: 1100000);
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text("Plafond dépassé de 3'742 CHF"), findsOneWidget);
    expect(find.text('Marge restante'), findsNothing);
    expect(
      find.bySemanticsIdentifier('mint_next_marge_3a_marge_-374200'),
      findsOneWidget,
      reason: 'marge SIGNÉE — le dépassement est un fait, jamais un zéro',
    );
  });

  testWidgets(
      'each fail-closed state renders as a factual invitation, never an error',
      (tester) async {
    final unknownLpp = await providerWith(affiliated: null);
    await tester.pumpWidget(wrap(unknownLpp));
    await tester.pumpAndSettle();
    expect(
      find.text('Indique si tu es affilié·e à une caisse de pension pour '
          'voir ton plafond 3a.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(
          'mint_next_marge_3a_state_lppAffiliationUnknown'),
      findsOneWidget,
    );

    final noIncome = await providerWith(affiliated: false);
    await tester.pumpWidget(wrap(noIncome));
    await tester.pumpAndSettle();
    expect(
      find.text('Indique ton revenu pour calculer ton plafond 3a sans '
          'caisse de pension.'),
      findsOneWidget,
      reason: 'invitation factuelle — jamais un écran d\'erreur',
    );

    // Sans aucun versement, la liste bascule vers collect : l'état
    // contributions_missing doit y être VISIBLE (REJET Codex T2).
    // Reset des mocks — les sous-cas précédents ont persisté des versements.
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
    final noContributions = await providerWith(versedCents: null);
    await tester.pumpWidget(wrap(noContributions));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer ce versement'), findsOneWidget,
        reason: 'sans versements, la liste bascule vers collect');
    expect(
      find.text('Enregistre tes versements pour voir ta marge 3a.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(
          'mint_next_marge_3a_state_contributionsMissing'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a year outside the attested registry renders the unattested invitation',
      (tester) async {
    final provider = await providerWith();
    final router = GoRouter(
      initialLocation: '/versements',
      routes: [
        GoRoute(
          path: '/versements',
          builder: (_, __) => MintNextVersements3aScreen(
              now: () => DateTime.utc(2027, 2, 1)),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CoachProfileProvider>.value(
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
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Le plafond 2027 n'est pas encore attesté dans MINT."),
      findsOneWidget,
      reason: 'année hors registre = état honnête, jamais une reprise 2026',
    );
    expect(
      find.bySemanticsIdentifier('mint_next_marge_3a_state_unsupportedTaxYear'),
      findsOneWidget,
    );
  });

  testWidgets(
      'every fail-closed state maps to a distinct factual invitation',
      (tester) async {
    late S l10n;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Builder(builder: (context) {
        l10n = S.of(context)!;
        return const SizedBox.shrink();
      }),
    ));

    expect(
        mintNextMarge3aInvitationText(
            l10n, MintNextMarge3aStatus.available, 2026),
        isNull);
    final invitations = {
      for (final status in MintNextMarge3aStatus.values)
        if (status != MintNextMarge3aStatus.available)
          status: mintNextMarge3aInvitationText(l10n, status, 2026)!
    };
    expect(invitations, hasLength(6),
        reason: 'chaque état revendiqué au contrat a une invitation — '
            'y compris unattested et stale, inatteignables sans altérer '
            'le registre');
    for (final text in invitations.values) {
      expect(text, isNotEmpty);
      expect(text.toLowerCase(), isNot(contains('erreur')),
          reason: 'invitation factuelle, jamais un vocabulaire d\'erreur');
    }
    expect(invitations[MintNextMarge3aStatus.unsupportedTaxYear],
        invitations[MintNextMarge3aStatus.regulatoryConstantsUnattested],
        reason: 'les états techniques partagent la même invitation honnête');
  });

  testWidgets(
      'the plafond provenance (source, year, set version) is reachable from '
      'the surface', (tester) async {
    final provider = await providerWith();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    final version =
        MintNextMarge3aRegistry.set2026.snapshotHash.substring(0, 8);
    expect(
      find.text('OPP3 art. 7 · plafond 2026 · jeu $version'),
      findsOneWidget,
      reason: 'source + année + version du jeu réglementaire, visibles',
    );
  });

  test('mon argent never imports the calculator nor re-implements the formula',
      () {
    final source =
        File('lib/screens/mon_argent/mon_argent_screen.dart').readAsStringSync();
    for (final marker in [
      'MintNextMarge3aCalculator',
      'mint_next_marge_3a_calculator',
      'pillar3a_room_calculator',
    ]) {
      expect(source.contains(marker), isFalse,
          reason: 'le vertical est l\'unique point d\'entrée UI du calcul — '
              'doublé par le guard commit-gate journey_os_check');
    }
  });
}
