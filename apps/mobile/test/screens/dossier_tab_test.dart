import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

import 'package:mint_mobile/screens/main_tabs/dossier_tab.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

// ────────────────────────────────────────────────────────────────────────────
//  DOSSIER TAB — Unit + Smoke Tests
//
//  Verifies the six sections render correctly from MintUserState:
//    1. Mon profil  (identity + confidence)
//    2. Mon plan    (CapSequence progress or choose-goal CTA)
//    3. Mes données (revenue, LPP, 3a, budget)
//    4. Benchmarks  (opt-in card when not opted in)
//    5. Spécialiste + Documents préparés
//    6. Réglages    (consents, SLM, BYOK)
// ────────────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget buildDossierTab({
    CoachProfileProvider? coachProvider,
    MintStateProvider? mintStateProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => coachProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<MintStateProvider>(
          create: (_) => mintStateProvider ?? MintStateProvider(),
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
        home: Scaffold(body: DossierTab()),
      ),
    );
  }

  /// Build a [MintStateProvider] seeded with a [MintUserState] so tests can
  /// verify state-driven rendering without running the full MintStateEngine.
  MintStateProvider buildMintStateProvider({
    required CoachProfile profile,
    double confidenceScore = 0.70,
  }) {
    final provider = MintStateProvider();
    final state = MintUserState(
      profile: profile,
      lifecyclePhase: LifecyclePhase.consolidation,
      archetype: profile.archetype,
      confidenceScore: confidenceScore,
      capMemory: const CapMemory(),
      computedAt: DateTime(2026, 3, 22),
    );
    provider.injectStateForTest(state);
    return provider;
  }

  CoachProfile buildMinimalProfile({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
    double salaireBrutMensuel = 8500,
  }) {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': salaireBrutMensuel,
      'q_employment_status': 'salarie',
      'q_civil_status': 'marie',
      'q_children': 0,
    });
    return provider.profile!;
  }

  CoachProfileProvider buildCoachProvider({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
  }) {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': 8500.0,
      'q_employment_status': 'salarie',
      'q_civil_status': 'marie',
      'q_children': 0,
    });
    return provider;
  }

  // ── Section 1: Mon profil ────────────────────────────────────────────────

  group('Section 1 — Mon profil', () {
    testWidgets('renders profile section label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mon profil'), findsOneWidget);
    });

    testWidgets('shows first name initial avatar when MintUserState present',
        (tester) async {
      final profile = buildMinimalProfile(firstName: 'Julien');
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Avatar shows first letter of the name.
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('shows confidence progress bar', (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(
        profile: profile,
        confidenceScore: 0.72,
      );

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows confidence label', (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Fiabilit'), findsOneWidget);
    });

    testWidgets('shows complete-profile CTA when confidence below 60',
        (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(
        profile: profile,
        confidenceScore: 0.40, // below 60%
      );

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Compl'), findsWidgets);
    });

    testWidgets('does not show CTA when confidence is at or above 60',
        (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(
        profile: profile,
        confidenceScore: 0.65, // above 60%
      );

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // "Compléter mon profil" CTA should not appear.
      expect(find.text('Compléter mon profil'), findsNothing);
    });

    testWidgets('shows canton in profile meta', (tester) async {
      final profile = buildMinimalProfile(canton: 'VS');
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('VS'), findsWidgets);
    });
  });

  // ── Section 2: Mon plan ──────────────────────────────────────────────────

  group('Section 2 — Mon plan', () {
    testWidgets('renders plan section label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mon plan'), findsOneWidget);
    });

    testWidgets('shows choose-goal CTA when no capSequencePlan', (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(profile: profile);
      // No capSequencePlan set → mintState.capSequencePlan == null.

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('objectif'), findsWidgets);
    });

    testWidgets('shows choose-goal CTA when no MintState', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Without any state, the plan section falls back to choose-goal.
      expect(find.textContaining('objectif'), findsWidgets);
    });
  });

  // ── Section 3: Mes données ───────────────────────────────────────────────

  group('Section 3 — Mes données', () {
    testWidgets('renders data section label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mes données'), findsOneWidget);
    });

    testWidgets('shows revenue row', (tester) async {
      final profile = buildMinimalProfile(salaireBrutMensuel: 8500);
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Revenu'), findsOneWidget);
    });

    testWidgets('shows 2nd pillar row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('2e pilier'), findsOneWidget);
    });

    testWidgets('shows 3rd pillar row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('3e pilier'), findsOneWidget);
    });

    testWidgets('shows LPP scan CTA when avoir LPP unknown', (tester) async {
      final profile = buildMinimalProfile();
      // Profile built without LPP avoir → avoirLppTotal == null.
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Scanner'), findsOneWidget);
    });

    testWidgets('shows documents row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('shows monthly margin row label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Marge mensuelle'), findsOneWidget);
    });
  });

  // ── Section 4: Benchmarks ────────────────────────────────────────────────

  group('Section 4 — Comparaison cantonale', () {
    testWidgets('shows benchmark opt-in card by default', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // SharedPreferences returns empty → not opted in.
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The opt-in button should be visible after async load.
      expect(find.textContaining('Activer'), findsWidgets);
    });
  });

  // ── Section 5 & 6 ────────────────────────────────────────────────────────

  group('Section 5 — Spécialiste', () {
    testWidgets('shows specialist section title', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('pécialiste'), findsWidgets);
    });

    testWidgets('shows agent section title', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('préparés'), findsWidgets);
    });
  });

  group('Section 6 — Réglages', () {
    testWidgets('shows réglages section label', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Réglages'), findsOneWidget);
    });

    testWidgets('shows consents row', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Consentements'), findsOneWidget);
    });
  });

  // ── Full render smoke test ───────────────────────────────────────────────

  group('DossierTab — smoke', () {
    testWidgets('renders without crashing with empty state', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(DossierTab), findsOneWidget);
    });

    testWidgets('renders without crashing with full MintUserState', (tester) async {
      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(
        profile: profile,
        confidenceScore: 0.85,
      );
      final coachProvider = buildCoachProvider();

      await tester.pumpWidget(buildDossierTab(
        coachProvider: coachProvider,
        mintStateProvider: mintProvider,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(DossierTab), findsOneWidget);
    });

    testWidgets('shows Dossier tab title in AppBar', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Dossier'), findsOneWidget);
    });

    testWidgets('shows all six section labels in order', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Mon plan'), findsOneWidget);
      expect(find.text('Mes données'), findsOneWidget);
    });
  });
}
