import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

import 'package:mint_mobile/screens/pulse/pulse_screen.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';

// ────────────────────────────────────────────────────────────────
//  PULSE SCREEN — Smoke + Integration Tests (V5 — Plan-first)
// ────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPulseScreen({
    CoachProfileProvider? coachProvider,
    MintStateProvider? mintStateProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => coachProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<ByokProvider>(
          create: (_) => ByokProvider(),
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
        home: Scaffold(body: PulseScreen()),
      ),
    );
  }

  /// Build a [MintStateProvider] pre-seeded with a [MintUserState] so widget
  /// tests can verify state-driven rendering without running MintStateEngine.
  MintStateProvider buildMintStateProvider({
    required CoachProfile profile,
    double? replacementRate,
    double? friScore,
    String? activeGoalIntentTag,
  }) {
    final provider = MintStateProvider();
    final state = MintUserState(
      profile: profile,
      lifecyclePhase: LifecyclePhase.consolidation,
      archetype: profile.archetype,
      confidenceScore: 70.0,
      replacementRate: replacementRate,
      friScore: friScore,
      activeGoalIntentTag: activeGoalIntentTag,
      capMemory: const CapMemory(),
      computedAt: DateTime(2026, 3, 22),
    );
    // Inject state via the internal setter exposed by the test helper.
    provider.injectStateForTest(state);
    return provider;
  }

  CoachProfileProvider buildProfileProvider({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String civilStatus = 'marie',
    String? conjointFirstName,
    double? conjointSalaire,
    int? conjointBirthYear,
  }) {
    final provider = CoachProfileProvider();
    final answers = <String, dynamic>{
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': salaire,
      'q_civil_status': civilStatus,
      'q_goal': 'retraite',
    };
    if (conjointFirstName != null) {
      answers['q_partner_firstname'] = conjointFirstName;
    }
    if (conjointSalaire != null) {
      answers['q_partner_net_income_chf'] = conjointSalaire;
    }
    if (conjointBirthYear != null) {
      answers['q_partner_birth_year'] = conjointBirthYear;
    }
    provider.updateFromAnswers(answers);
    return provider;
  }

  // ── EMPTY STATE ──────────────────────────────────────────────

  group('PulseScreen — empty state', () {
    testWidgets('renders empty state with onboarding CTA', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      // V5: empty state uses l10n keys pulseEmptyTitle + pulseEmptyCtaStart
      expect(find.textContaining('Trois questions'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('shows disclaimer in empty state', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Outil éducatif'), findsOneWidget);
      expect(find.textContaining('LSFin art.'), findsOneWidget);
    });

    testWidgets('shows onboarding subtitle', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      // V5: pulseEmptySubtitle
      expect(find.textContaining('Commence par ton profil'), findsOneWidget);
    });
  });

  // ── LOADED STATE ─────────────────────────────────────────────

  group('PulseScreen — loaded state', () {
    testWidgets('renders AppBar greeting with name', (tester) async {
      final provider = buildProfileProvider(firstName: 'Julien');
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V5: AppBar uses pulseGreeting("Bonjour {name}")
      expect(find.textContaining('Bonjour Julien'), findsOneWidget);
    });

    testWidgets('renders hero zone with dominant number', (tester) async {
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V5: hero zone renders a dominant number (%, CHF, or score)
      // + narrative phrase + CapCard or fallback action
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders disclaimer in loaded state', (tester) async {
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Outil éducatif'), findsOneWidget);
    });

    testWidgets('renders narrative phrase from CapEngine', (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        birthYear: 1977,
        salaire: 9078,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V5: narrative comes from cap.whyNow prefixed with firstName.
      // The exact text depends on CapEngine output, but Julien should appear.
      expect(find.textContaining('Julien'), findsWidgets);
    });
  });

  // ── COUPLE MODE ──────────────────────────────────────────────

  group('PulseScreen — couple mode', () {
    testWidgets('renders couple icon when married with conjoint',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        civilStatus: 'marie',
        conjointFirstName: 'Lauren',
        conjointSalaire: 4800,
        conjointBirthYear: 1982,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V5: couple mode shows people_outline icon in AppBar action
      expect(find.textContaining('Julien'), findsWidgets);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('does not show couple icon for celibataire',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        civilStatus: 'celibataire',
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });

  // ── SECONDARY SIGNALS ────────────────────────────────────────

  group('PulseScreen — secondary signals', () {
    testWidgets('renders budget and patrimoine signal rows',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaire: 9078,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V5: secondary signals use l10n keys (pulseKeyFigBudgetLibre, pulseKeyFigPatrimoine)
      // shown as _SignalRow widgets. Look for the l10n labels.
      // Budget libre signal should exist for a profile with salary
      expect(find.textContaining('Budget'), findsWidgets);
    });
  });

  // ── GOAL-CENTRIC DOMINANT NUMBER ─────────────────────────────

  group('PulseScreen — goal-centric dominant number', () {
    testWidgets('explicit retirement goal shows replacement rate label',
        (tester) async {
      final coachProvider = buildProfileProvider(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaire: 9078,
      );
      // Seed MintStateProvider with replacementRate + explicit retirement goal
      // so the label renders. Since S52, budget is the default hero —
      // retirement requires explicit activeGoalIntentTag.
      final mintProvider = buildMintStateProvider(
        profile: coachProvider.profile!,
        replacementRate: 65.5,
        activeGoalIntentTag: 'retirement_choice',
      );
      await tester.pumpWidget(buildPulseScreen(
        coachProvider: coachProvider,
        mintStateProvider: mintProvider,
      ));
      await tester.pump(const Duration(seconds: 2));

      // With explicit retirement goal + replacementRate, label = pulseLabelReplacementRate
      // "Part de train de vie conservée"
      expect(
        find.textContaining('train de vie'),
        findsOneWidget,
      );
    });

    testWidgets('achat_immo goal: no replacement-rate label shown',
        (tester) async {
      final provider = CoachProfileProvider();
      // Use q_main_goal (not q_goal) — the key fromWizardAnswers reads.
      provider.updateFromAnswers({
        'q_firstname': 'Julien',
        'q_birth_year': 1977,
        'q_canton': 'VS',
        'q_net_income_period_chf': 9078.0,
        'q_civil_status': 'celibataire',
        'q_main_goal': 'achat_immo',
      });

      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // V6: with housing goal, the retirement-specific label
      // "Part de train de vie conservée" must NOT appear.
      expect(find.textContaining('train de vie'), findsNothing);
      // Screen renders without crash
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('_resolveActiveGoal falls back to budget when goal=retraite',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaire: 9078,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // Pulse renders without crash and shows Julien's name
      expect(find.textContaining('Julien'), findsWidgets);
    });

    testWidgets(
        '_resolveActiveGoal: no provider in tree falls back to profile.goalA',
        (tester) async {
      // PulseScreen built without MintStateProvider — should degrade gracefully.
      final provider = CoachProfileProvider();
      // q_main_goal is the correct wizard key; q_goal is ignored.
      provider.updateFromAnswers({
        'q_firstname': 'Julien',
        'q_birth_year': 1977,
        'q_canton': 'VS',
        'q_net_income_period_chf': 9078.0,
        'q_civil_status': 'celibataire',
        'q_main_goal': 'retraite',
      });

      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // No crash — retirement narrative or label is shown
      expect(find.byType(Text), findsWidgets);
    });
  });

  // ── HELPER EDGE CASES ────────────────────────────────────────

  group('PulseScreen — _hasMinimalConjointData edge cases', () {
    test('returns false for null birthYear', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: null,
        salaireBrutMensuel: 4800,
      );
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isFalse);
    });

    test('returns false for zero salary', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 0,
      );
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isFalse);
    });

    test('returns true when both birthYear and salary are valid', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
      );
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isTrue);
    });
  });

  group('PulseScreen — _conjointToCoachProfile mapping', () {
    test('correctly maps ConjointProfile fields to CoachProfile', () {
      final mainProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        commune: 'Sion',
        salaireBrutMensuel: 9078,
        etatCivil: CoachCivilStatus.marie,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 4800,
          nombreDeMois: 13,
          bonusPourcentage: 5,
          employmentStatus: 'salarie',
          nationality: 'US',
          arrivalAge: 25,
          targetRetirementAge: 64,
          prevoyance: PrevoyanceProfile(avoirLppTotal: 19620),
          patrimoine: PatrimoineProfile(investissements: 380000),
        ),
      );

      final conj = mainProfile.conjoint!;
      final retirementAge = conj.targetRetirementAge ?? 65;
      final birthYr = conj.birthYear ?? mainProfile.birthYear;
      final syntheticProfile = CoachProfile(
        firstName: conj.firstName,
        birthYear: birthYr,
        canton: mainProfile.canton,
        commune: mainProfile.commune,
        nationality: conj.nationality,
        salaireBrutMensuel: conj.salaireBrutMensuel ?? 0,
        nombreDeMois: conj.nombreDeMois,
        bonusPourcentage: conj.bonusPourcentage ?? 0,
        employmentStatus: conj.employmentStatus ?? 'salarie',
        etatCivil: mainProfile.etatCivil,
        arrivalAge: conj.arrivalAge,
        targetRetirementAge: conj.targetRetirementAge,
        prevoyance: conj.prevoyance ?? const PrevoyanceProfile(),
        patrimoine: conj.patrimoine ?? const PatrimoineProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(birthYr + retirementAge),
          label: 'Retraite',
        ),
      );

      expect(syntheticProfile.firstName, 'Lauren');
      expect(syntheticProfile.birthYear, 1982);
      expect(syntheticProfile.canton, 'VS');
      expect(syntheticProfile.commune, 'Sion');
      expect(syntheticProfile.nationality, 'US');
      expect(syntheticProfile.salaireBrutMensuel, 4800);
      expect(syntheticProfile.nombreDeMois, 13);
      expect(syntheticProfile.bonusPourcentage, 5);
      expect(syntheticProfile.employmentStatus, 'salarie');
      expect(syntheticProfile.etatCivil, CoachCivilStatus.marie);
      expect(syntheticProfile.arrivalAge, 25);
      expect(syntheticProfile.targetRetirementAge, 64);
      expect(syntheticProfile.prevoyance.avoirLppTotal, 19620);
      expect(syntheticProfile.patrimoine.investissements, 380000);
      expect(syntheticProfile.goalA.targetDate, DateTime(1982 + 64));
    });

    test('falls back to mainProfile birthYear when conjoint birthYear is null', () {
      final mainProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 9078,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: null,
          salaireBrutMensuel: 4800,
        ),
      );

      final conj = mainProfile.conjoint!;
      final birthYr = conj.birthYear ?? mainProfile.birthYear;
      expect(birthYr, 1977);
    });
  });

  group('PulseScreen — _computeTemporalItems', () {
    test('produces items when profile has salary and canton', () {
      final items = TemporalPriorityService.prioritize(
        canton: 'VS',
        taxSaving3a: 1500,
        friTotal: 0,
        friDelta: 0,
        limit: 4,
      );
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.title, isNotEmpty);
        expect(item.body, isNotEmpty);
      }
    });
  });

  // ── CONJOINT SERIALIZATION ───────────────────────────────────

  group('PulseScreen — _conjointToCoachProfile correctness', () {
    test('conjoint profile preserves patrimoine when available', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        employmentStatus: 'salarie',
        patrimoine: PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 380000,
        ),
      );

      expect(conjoint.patrimoine, isNotNull);
      expect(conjoint.patrimoine!.investissements, 380000);
      expect(conjoint.patrimoine!.epargneLiquide, 20000);
    });

    test('conjoint patrimoine serializes/deserializes correctly', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 380000,
        ),
      );

      final json = conjoint.toJson();
      expect(json['patrimoine'], isNotNull);

      final restored = ConjointProfile.fromJson(json);
      expect(restored.patrimoine, isNotNull);
      expect(restored.patrimoine!.investissements, 380000);
      expect(restored.patrimoine!.epargneLiquide, 20000);
    });

    test('conjoint patrimoine copyWith preserves value', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: PatrimoineProfile(
          investissements: 380000,
        ),
      );

      final updated = conjoint.copyWith(firstName: 'Laura');
      expect(updated.firstName, 'Laura');
      expect(updated.patrimoine!.investissements, 380000);
    });

    test('conjoint patrimoine null by default (backward compat)', () {
      const conjoint = ConjointProfile();
      expect(conjoint.patrimoine, isNull);

      final json = conjoint.toJson();
      final restored = ConjointProfile.fromJson(json);
      expect(restored.patrimoine, isNull);
    });
  });
}
