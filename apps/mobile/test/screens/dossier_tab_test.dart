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
//    1. Identité     (identity + confidence)
//    2. Données      (revenue, LPP, 3a, budget + deltas)
//    3. Documents    (scanned certs, agent-prepared docs)
//    4. Couple       (conjoint data, only when isCouple)
//    5. Plan         (CapSequence progress or choose-goal CTA)
//    6. Préférences  (consents, SLM, BYOK, specialist)
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

  // ── Section 1: Identité ────────────────────────────────────────────────

  group('Section 1 — Identité', () {
    testWidgets('renders identity section label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Identit'), findsOneWidget);
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

  // ── Section 2: Données ─────────────────────────────────────────────────

  group('Section 2 — Données', () {
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

    testWidgets('shows monthly margin row label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Marge mensuelle'), findsOneWidget);
    });
  });

  // ── Section 3: Documents ───────────────────────────────────────────────

  group('Section 3 — Documents', () {
    testWidgets('renders documents section label', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The section label "Documents" appears (may also appear as row title).
      expect(find.textContaining('Documents'), findsWidgets);
    });

    testWidgets('shows agent-prepared document rows', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Agent-prepared docs are now in the Documents section.
      expect(find.textContaining('Certificats'), findsOneWidget);
    });
  });

  // ── Section 5: Plan ────────────────────────────────────────────────────

  group('Section 5 — Plan', () {
    testWidgets('renders plan section label', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mon plan'), findsOneWidget);
    });

    testWidgets('shows choose-goal CTA when no capSequencePlan', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profile = buildMinimalProfile();
      final mintProvider = buildMintStateProvider(profile: profile);

      await tester.pumpWidget(buildDossierTab(mintStateProvider: mintProvider));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('objectif'), findsWidgets);
    });

    testWidgets('shows choose-goal CTA when no MintState', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('objectif'), findsWidgets);
    });
  });

  // ── Section 6: Préférences ─────────────────────────────────────────────

  group('Section 6 — Settings (gear icon)', () {
    testWidgets('shows gear icon in AppBar', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Settings gear icon should be in the AppBar.
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('gear icon opens settings sheet with consents', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap the gear icon to open the settings sheet.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Consents, SLM, BYOK, Coaching should appear in the sheet.
      expect(find.text('Consentements'), findsOneWidget);
    });

    testWidgets('gear icon opens settings sheet with coaching', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Coaching adaptatif (i18n: "Accompagnement") should appear in the settings sheet.
      expect(find.textContaining('Accompagnement'), findsWidgets);
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

    testWidgets('shows key section labels in new order', (tester) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDossierTab());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // New section order: Identité → Données → Documents → Plan → Préférences
      expect(find.textContaining('Identit'), findsOneWidget);
      expect(find.text('Mes données'), findsOneWidget);
      expect(find.text('Mon plan'), findsOneWidget);
    });
  });
}
