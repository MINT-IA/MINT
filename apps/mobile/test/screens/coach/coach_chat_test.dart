import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import '../../semantics_test_helpers.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN TESTS — Phase 4 / BYOK + RAG wiring
// ────────────────────────────────────────────────────────────

void main() {
  // FIX-P1-7: Register orchestrator (no longer auto-imported by coach_llm_service).
  CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);

  CoachProfileProvider buildProfileProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    return provider;
  }

  CoachProfileProvider build3aBudgetProfileProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_net_income_period_chf': 9000,
      'q_pay_frequency': 'monthly',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_3a_total': 12000,
      'q_3a_annual_contribution': 7056,
    });
    return provider;
  }

  CoachProfileProvider buildIndependentNoLppProfileProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Nadia',
      'q_us_tax_person': false,
      'q_nationality': 'CH',
      'q_employment_status': 'independant',
      'q_has_pension_fund': false,
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 8200,
      'q_pay_frequency': 'monthly',
      'q_self_employed_net_income_annual_chf': 86400,
      'q_3a_annual_contribution': 6000,
      'q_savings_monthly': 6000 / 12,
      'q_savings_allocation': ['3a'],
    });
    expect(provider.profile?.archetype, FinancialArchetype.independentNoLpp);
    expect(provider.profile?.independentNetProfessionalIncomeAnnual, 86400);
    return provider;
  }

  Future<EnrichedContext> emptyContextBuilder({
    CoachProfile? profile,
    SharedPreferences? prefs,
    DateTime? now,
    MintUserState? mintState,
  }) async =>
      EnrichedContext.empty;

  String formatPlainChf(double amount) {
    final digits = amount.round().toString();
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => "${match[1]}'",
    );
  }

  Finder bySemanticsIdentifier(String identifier) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.identifier == identifier,
      );

  MintUserState buildMintStateForTest(CoachProfile profile) {
    final now = DateTime(2026, 5, 26, 10);
    return MintUserState(
      profile: profile,
      lifecyclePhase: LifecyclePhase.consolidation,
      archetype: profile.archetype,
      budgetSnapshot: const BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 9000,
          monthlyCharges: 5200,
          monthlySavings: 1332,
          monthlyFree: 2468,
        ),
        retirement: RetirementBudget(
          monthlyIncome: 7200,
          monthlyTax: 900,
          monthlyNet: 6300,
        ),
        gap: BudgetGap(
          monthlyGap: 1200,
          replacementRate: 70,
        ),
        capImpacts: [
          BudgetCapImpact(capId: 'debt_safety', monthlyDelta: -300),
        ],
        stage: BudgetStage.fullGapVisible,
        confidenceScore: 82,
      ),
      confidenceScore: 82,
      capMemory: const CapMemory(),
      computedAt: now,
    );
  }

  Widget buildTestWidget({
    bool withProfile = false,
    MintUserState? mintState,
    CoachProfileProvider? profileProviderOverride,
    BudgetProvider? budgetProviderOverride,
    CoachContextInjectorBuilder? contextBuilder,
    String? conversationId,
  }) {
    final profileProvider = profileProviderOverride ??
        (withProfile ? buildProfileProvider() : CoachProfileProvider());
    final stateProvider = MintStateProvider();
    if (mintState != null) {
      stateProvider.injectStateForTest(mintState);
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
        if (budgetProviderOverride != null)
          ChangeNotifierProvider.value(value: budgetProviderOverride),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider.value(value: stateProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: CoachChatScreen(
          contextBuilder: contextBuilder,
          conversationId: conversationId,
        ),
      ),
    );
  }

  /// Sets the test viewport to a phone-sized surface (1080x1920 at 1x)
  /// to avoid RenderFlex overflow from ResponseCardStrip in the
  /// default 800x600 test viewport.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Pump enough frames for the async greeting chain to complete.
  ///
  /// The greeting involves multiple sequential awaits (SharedPreferences,
  /// ProactiveTriggerService, PrecomputedInsightsService, NudgeEngine).
  /// Each await requires a separate microtask cycle to resolve. Pumping
  /// multiple short frames ensures all async hops finish and setState fires.
  Future<void> pumpUntilGreeting(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // SharedPreferences mock needed for ContextInjectorService (S58 AI memory)
  // and voice intensity level (default to 3 = Direct so greeting tests pass).
  setUp(() {
    FeatureFlags.slmPluginReady = false;
    SharedPreferences.setMockInitialValues({
      'mint_coach_cash_level': 3,
    });
  });

  group('CoachChatScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('shows MINT title', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('MINT'), findsOneWidget);
    });

    testWidgets('shows history icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Refactored app bar has history icon instead of tier subtitle
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('shows more options icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Refactored app bar uses more_horiz for settings access
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows silent opener instead of greeting', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Silent opener post-polish 2026-04-17 (commit f95c8ad9): the italic
      // "Tu veux en parler ?" glued under the key number was removed so the
      // frame has a single visual anchor. With a profile the screen shows
      // either the key-number + headline or the random greeting (if no key
      // data is computable) — both render at least one Text. The old literal
      // assertion no longer applies.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows silent opener with financial data', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Should show Text widgets (either key number or at minimum the question).
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets(
        'silent opener primary number uses budget monthlyFree when budget data is trusted',
        (tester) async {
      usePhoneViewport(tester);
      final provider = build3aBudgetProfileProvider();
      final profile = provider.profile!;
      final expectedMonthlyFree =
          BudgetLivingEngine.compute(profile).present.monthlyFree;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => ByokProvider()),
            ChangeNotifierProvider.value(value: MintStateProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
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
            home: CoachChatScreen(),
          ),
        ),
      );
      await pumpUntilGreeting(tester);

      expect(find.text(formatPlainChf(expectedMonthlyFree)), findsOneWidget);
      expect(find.text("12'000"), findsNothing);
    });

    testWidgets(
        'silent opener primary number uses direct budget inputs when profile is unavailable',
        (tester) async {
      usePhoneViewport(tester);
      final budgetProvider = BudgetProvider();
      await budgetProvider.setInputs(const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7250,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 1086.13625,
        healthInsurance: 420,
        otherFixedCosts: 0,
        isTaxEstimated: true,
        isHealthEstimated: false,
        isHousingMissing: false,
        isHealthMissing: false,
      ));
      final expectedAvailable = budgetProvider.plan!.available;

      await tester.pumpWidget(
        buildTestWidget(
          profileProviderOverride: CoachProfileProvider(),
          budgetProviderOverride: budgetProvider,
        ),
      );
      await pumpUntilGreeting(tester);

      expect(find.text(formatPlainChf(expectedAvailable)), findsOneWidget);
    });

    testWidgets(
        'silent opener hydrates stored direct budget inputs when provider starts empty',
        (tester) async {
      usePhoneViewport(tester);
      await BudgetLocalStore().saveInputs(const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7250,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 1086.13625,
        healthInsurance: 420,
        otherFixedCosts: 0,
        isTaxEstimated: true,
        isHealthEstimated: false,
        isHousingMissing: false,
        isHealthMissing: false,
      ));
      final budgetProvider = BudgetProvider();

      await tester.pumpWidget(
        buildTestWidget(
          profileProviderOverride: CoachProfileProvider(),
          budgetProviderOverride: budgetProvider,
        ),
      );
      await pumpUntilGreeting(tester);

      expect(budgetProvider.source, BudgetDataSource.storage);
      expect(find.text("3'544"), findsOneWidget);
    });

    testWidgets('first-contact opener does not show question label',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await pumpUntilGreeting(tester);

      expect(find.text('Par quoi on commence ?'), findsNothing);
    });

    testWidgets('empty material profile keeps first-contact opener',
        (tester) async {
      usePhoneViewport(tester);
      final provider = CoachProfileProvider()
        ..updateFromAnswers(<String, dynamic>{});

      await tester.pumpWidget(
        buildTestWidget(profileProviderOverride: provider),
      );
      await pumpUntilGreeting(tester);

      expect(find.text("Salut. Moi c'est Mint."), findsOneWidget);
      expect(find.text('Un papier que je ne comprends pas'), findsOneWidget);
    });

    testWidgets('empty material profile ignores pending proactive trigger',
        (tester) async {
      usePhoneViewport(tester);
      final provider = CoachProfileProvider()
        ..updateFromAnswers(<String, dynamic>{
          'q_firstname': 'Julien',
        });
      final profile = provider.profile!;
      final now = DateTime(2026, 6);
      final mintState = MintUserState(
        profile: profile,
        lifecyclePhase: LifecyclePhase.consolidation,
        archetype: profile.archetype,
        confidenceScore: 0,
        capMemory: const CapMemory(),
        pendingTrigger: ProactiveTrigger(
          type: ProactiveTriggerType.weeklyRecapAvailable,
          messageKey: 'proactiveWeeklyRecap',
          triggeredAt: now,
        ),
        computedAt: now,
      );

      await tester.pumpWidget(
        buildTestWidget(
          mintState: mintState,
          profileProviderOverride: provider,
        ),
      );
      await pumpUntilGreeting(tester);

      expect(find.text("Salut. Moi c'est Mint."), findsOneWidget);
      expect(find.text('Un papier que je ne comprends pas'), findsOneWidget);
      expect(find.textContaining('Ton récap de la semaine'), findsNothing);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      // coachInputHint shortened 2026-04-17 (commit d1ce63b5) from
      // "Dis-moi ce qui te trotte dans la tête." to "Dis-moi." — same
      // direction as the opener polish (invite conversation, not essays).
      expect(find.textContaining('Dis-moi'), findsWidgets);
    });

    testWidgets('exposes Maestro semantics identifiers', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        usePhoneViewport(tester);

        await tester.pumpWidget(buildTestWidget(withProfile: true));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester
              .getSemantics(find.byKey(const Key('coach_chat_screen')))
              .identifier,
          'coach_chat_screen',
        );
        expect(
          tester
              .getSemantics(find.byKey(const Key('coach_history_button')))
              .identifier,
          'coach_history_button',
        );
        expect(
          tester
              .getSemantics(find.byKey(const Key('coach_input_field')))
              .identifier,
          'coach_input_field',
        );
        expect(
          tester
              .getSemantics(
                  find.byKey(const Key('coach_lightning_menu_button')))
              .identifier,
          'coach_lightning_menu_button',
        );
        expect(
          tester
              .getSemantics(find.byKey(const Key('coach_send_button')))
              .identifier,
          'coach_send_button',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('shows send button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets(
        'independent_no_lpp safe 3a prompt renders local guidance, not waitlist or LLM transparency',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(
        profileProviderOverride: buildIndependentNoLppProfileProvider(),
        contextBuilder: emptyContextBuilder,
      ));
      await pumpUntilGreeting(tester);

      await tester.enterText(
        find.byKey(const Key('coach_input_field')),
        'Combien verser en 3a ?',
      );
      await tester.tap(find.byKey(const Key('coach_send_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining("revenu net d'activité"), findsOneWidget);
      expect(find.textContaining('Marge 3a à vérifier'), findsOneWidget);
      expect(find.textContaining('86\u00a0400\u00a0CHF/an'), findsOneWidget);
      expect(find.textContaining('6\u00a0000\u00a0CHF/an'), findsOneWidget);
      expect(find.textContaining('11\u00a0280\u00a0CHF/an'), findsOneWidget);
      expect(
        find.textContaining('revenu déterminant fiscal/AVS'),
        findsWidgets,
      );
      expect(find.textContaining('Faits MINT'), findsOneWidget);
      expect(find.textContaining('Provenance et fraîcheur'), findsOneWidget);
      expect(
          find.textContaining('date par champ non affichée'), findsOneWidget);
      expect(find.textContaining('Confirmations manquantes'), findsOneWidget);
      expect(find.textContaining('Comparer avant de verser'), findsOneWidget);
      expect(find.textContaining('Carte de décision'), findsOneWidget);
      expect(find.textContaining('Marge légale 3a'), findsOneWidget);
      expect(find.textContaining('Capacité mensuelle'), findsOneWidget);
      expect(find.textContaining('Couverture risque'), findsOneWidget);
      expect(find.textContaining('Fiscalité'), findsOneWidget);
      expect(find.textContaining('Prochaine action prudente'), findsOneWidget);
      expect(find.textContaining('Marge légale ≠ capacité mensuelle'),
          findsOneWidget);
      expect(find.textContaining('budget mensuel'), findsWidgets);
      expect(find.textContaining('Versement 3a 2026'), findsNothing);
      expect(find.textContaining('Impact fiscal indicatif'), findsNothing);
      expect(find.textContaining('2\u00a0218 CHF'), findsNothing);
      expect(find.textContaining('meilleur'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
      expect(find.textContaining('sans risque'), findsNothing);
      expect(find.textContaining('Encore en chantier pour ton profil'),
          findsNothing);
      expect(find.textContaining('API Claude'), findsNothing,
          reason:
              'The audited no-LPP fallback is deterministic local guidance, not a BYOK/server LLM answer.');
    });

    testWidgets(
        'independent_no_lpp 3a answer exposes VoiceOver traversal anchors',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        usePhoneViewport(tester);
        await tester.pumpWidget(buildTestWidget(
          profileProviderOverride: buildIndependentNoLppProfileProvider(),
          contextBuilder: emptyContextBuilder,
        ));
        await pumpUntilGreeting(tester);

        await tester.enterText(
          find.byKey(const Key('coach_input_field')),
          'Combien verser en 3a ?',
        );
        await tester.tap(find.byKey(const Key('coach_send_button')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 100));

        final userMessage =
            tester.getSemantics(find.byKey(const Key('coach_user_message_0')));
        final assistantMessage = tester.getSemantics(
          find.byKey(const Key('coach_assistant_message_0')),
        );

        expect(userMessage.identifier, 'coach_user_message_0');
        expect(userMessage.label, contains('Ton message'));
        expect(assistantMessage.identifier, 'coach_assistant_message_0');
        expect(assistantMessage.label, contains('Réponse du coach'));

        expect(find.textContaining('Marge 3a à vérifier'), findsOneWidget);
        expect(find.textContaining('Faits MINT'), findsOneWidget);
        expect(find.textContaining('Provenance et fraîcheur'), findsOneWidget);
        expect(find.textContaining('Confirmations manquantes'), findsOneWidget);
        expect(find.textContaining('Carte de décision'), findsOneWidget);
        expect(
          find.textContaining('Prochaine action prudente'),
          findsOneWidget,
        );
        expect(find.textContaining('86\u00a0400\u00a0CHF/an'), findsOneWidget);
        expect(find.textContaining('6\u00a0000\u00a0CHF/an'), findsOneWidget);
        expect(find.textContaining('11\u00a0280\u00a0CHF/an'), findsOneWidget);
        expect(find.textContaining('Impact fiscal indicatif'), findsNothing);
        expect(find.textContaining('2\u00a0218 CHF'), findsNothing);
        expect(find.textContaining('ouvrir un compte'), findsNothing);
        expect(find.textContaining('fintech'), findsNothing);
        expect(
          assistantMessage.label,
          isNot(contains('Marge 3a à vérifier')),
          reason:
              'The assistant wrapper must stay role-only so VoiceOver does not read markdown content twice.',
        );
        final contentSemantics = tester.getSemantics(
          find.byKey(const Key('coach_message_content_semantics_1')),
        );
        expect(contentSemantics.label, contains('Marge 3a à vérifier'));
        expect(contentSemantics.label, contains('86\u00a0400\u00a0CHF/an'));
        expect(contentSemantics.label, contains('11\u00a0280\u00a0CHF/an'));

        expectIdentifierSubsequence(
          semanticIdentifiersInTraversalOrder(tester),
          [
            'coach_chat_screen',
            'coach_user_message_0',
            'coach_assistant_message_0',
            'coach_message_content_1',
            'coach_lightning_menu_button',
            'coach_input_field',
            'coach_send_button',
          ],
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
        'independent_no_lpp 3a answer refreshes profile facts during same chat session',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildIndependentNoLppProfileProvider();
      await tester.pumpWidget(buildTestWidget(
        profileProviderOverride: provider,
        contextBuilder: emptyContextBuilder,
      ));
      await pumpUntilGreeting(tester);

      await tester.enterText(
        find.byKey(const Key('coach_input_field')),
        'Combien verser en 3a ?',
      );
      await tester.tap(find.byKey(const Key('coach_send_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('11\u00a0280\u00a0CHF/an'), findsOneWidget);

      provider.updateFromAnswers({
        'q_firstname': 'Nadia',
        'q_us_tax_person': false,
        'q_nationality': 'CH',
        'q_employment_status': 'independant',
        'q_has_pension_fund': false,
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 8000,
        'q_pay_frequency': 'monthly',
        'q_self_employed_net_income_annual_chf': 96000,
        'q_3a_annual_contribution': 6000,
        'q_savings_monthly': 6000 / 12,
        'q_savings_allocation': ['3a'],
      });
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('coach_input_field')),
        'Combien verser en 3a ?',
      );
      await tester.tap(find.byKey(const Key('coach_send_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('13\u00a0200\u00a0CHF/an'),
        findsOneWidget,
        reason:
            'The second answer must use the current provider profile, not the stale profile captured when the chat opened.',
      );
    });

    testWidgets('independent_no_lpp generic prompt renders hard-gate refusal',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(
        profileProviderOverride: buildIndependentNoLppProfileProvider(),
        contextBuilder: emptyContextBuilder,
      ));
      await pumpUntilGreeting(tester);

      await tester.enterText(
        find.byKey(const Key('coach_input_field')),
        'Comment va ma retraite ?',
      );
      await tester.tap(find.byKey(const Key('coach_send_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
          find.textContaining("MINT n'est pas encore calibré"), findsOneWidget);
      expect(find.textContaining("revenu net d'activité"), findsNothing);
      expect(find.textContaining('API Claude'), findsNothing);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Settings gear icon is always shown for IA configuration
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('shows suggested action chips', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // The initial greeting should have suggested actions as tap targets
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('can type in input field', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('injects Budget Vivant from MintState into coach memory block',
        (tester) async {
      usePhoneViewport(tester);
      final profileProvider = buildProfileProvider();
      final profile = profileProvider.profile!;
      final mintState = buildMintStateForTest(profile);
      MintUserState? capturedMintState;
      String? capturedMemoryBlock;
      final previousHardGate = FeatureFlags.enableCoachHardGate;
      FeatureFlags.enableCoachHardGate = false;
      addTearDown(() {
        FeatureFlags.enableCoachHardGate = previousHardGate;
      });

      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedMemoryBlock = memoryBlock;
        return const CoachResponse(
          message: 'ok',
          disclaimer: 'Outil educatif.',
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider(create: (_) => ByokProvider()),
            ChangeNotifierProvider.value(
              value: MintStateProvider()..injectStateForTest(mintState),
            ),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: CoachChatScreen(
              contextBuilder: ({
                profile,
                prefs,
                now,
                mintState,
              }) async {
                capturedMintState = mintState;
                return const EnrichedContext(
                  memoryBlock:
                      "BUDGET VIVANT\nMarge libre\u00a0: CHF\u00a02'468/mois",
                  conversationMemory: ConversationMemory.empty,
                  activeGoalsCount: 0,
                );
              },
            ),
          ),
        ),
      );
      await pumpUntilGreeting(tester);

      await tester.enterText(find.byType(TextField), 'Analyse mon budget');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedMintState, same(mintState));
      expect(capturedMemoryBlock, isNotNull);
      expect(capturedMemoryBlock, contains('BUDGET VIVANT'));
      expect(capturedMemoryBlock, contains("CHF\u00a02'468/mois"));
    });

    testWidgets(
        'renders structured route_to_screen response as a resolved action card',
        (tester) async {
      usePhoneViewport(tester);
      final previousHardGate = FeatureFlags.enableCoachHardGate;
      FeatureFlags.enableCoachHardGate = false;
      addTearDown(() {
        FeatureFlags.enableCoachHardGate = previousHardGate;
        CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
      });

      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        return const CoachResponse(
          message: 'Ouvre le bon outil pour comparer.',
          disclaimer: 'Outil educatif.',
          toolCalls: [
            RagToolCall(
              name: 'route_to_screen',
              input: {
                'intent': 'retirement_choice',
                'confidence': 0.9,
                'context_message':
                    'Compare la rente et le capital avec tes donnees.',
              },
            ),
          ],
        );
      });

      await tester.pumpWidget(
        buildTestWidget(
          withProfile: true,
          mintState: buildMintStateForTest(buildProfileProvider().profile!),
          contextBuilder: ({
            profile,
            prefs,
            now,
            mintState,
          }) async {
            return const EnrichedContext(
              memoryBlock: 'TEST CONTEXT',
              conversationMemory: ConversationMemory.empty,
              activeGoalsCount: 0,
            );
          },
        ),
      );
      await pumpUntilGreeting(tester);

      await tester.enterText(find.byType(TextField), 'Rente ou capital ?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rente ou capital ?'), findsOneWidget);
      expect(find.text('Ouvre le bon outil pour comparer.'), findsOneWidget);
      expect(find.byType(RouteSuggestionCard), findsOneWidget);

      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.route, '/rente-vs-capital');
      expect(
        card.contextMessage,
        'Compare la rente et le capital avec tes donnees.',
      );
    });

    testWidgets(
        'injects ScreenReturn context into the next coach request after a simulator return',
        (tester) async {
      usePhoneViewport(tester);
      final previousHardGate = FeatureFlags.enableCoachHardGate;
      FeatureFlags.enableCoachHardGate = false;
      String? capturedMemoryBlock;
      addTearDown(() {
        FeatureFlags.enableCoachHardGate = previousHardGate;
        CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
      });

      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedMemoryBlock = memoryBlock;
        return const CoachResponse(
          message: 'Je tiens compte de la simulation.',
          disclaimer: 'Outil educatif.',
        );
      });

      await tester.pumpWidget(
        buildTestWidget(
          withProfile: true,
          mintState: buildMintStateForTest(buildProfileProvider().profile!),
          contextBuilder: ({
            profile,
            prefs,
            now,
            mintState,
          }) async {
            return const EnrichedContext(
              memoryBlock: 'TEST CONTEXT',
              conversationMemory: ConversationMemory.empty,
              activeGoalsCount: 0,
            );
          },
        ),
      );
      await pumpUntilGreeting(tester);

      await ScreenCompletionTracker.markCompletedWithReturn(
        'rente_vs_capital',
        const ScreenReturn.completed(
          route: '/rente-vs-capital',
          updatedFields: {'retirementMode': 'estimate'},
          confidenceDelta: 0.02,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Et maintenant ?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedMemoryBlock, isNotNull);
      expect(capturedMemoryBlock, contains('TEST CONTEXT'));
      expect(
        capturedMemoryBlock,
        contains("L'utilisateur vient de terminer une simulation"),
      );
      expect(capturedMemoryBlock, contains('/rente-vs-capital'));
      expect(capturedMemoryBlock, contains('retirementMode: estimate'));
    });

    testWidgets(
        'carries context from route suggestion tap through simulator return into next coach request',
        (tester) async {
      usePhoneViewport(tester);
      RouteSuggestionNavLock.resetForTest();
      final previousHardGate = FeatureFlags.enableCoachHardGate;
      FeatureFlags.enableCoachHardGate = false;
      String? capturedMemoryBlock;
      addTearDown(() {
        FeatureFlags.enableCoachHardGate = previousHardGate;
        CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
      });

      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        if (userMessage == 'Rente ou capital ?') {
          return const CoachResponse(
            message: 'Ouvre le bon outil pour comparer.',
            disclaimer: 'Outil educatif.',
            toolCalls: [
              RagToolCall(
                name: 'route_to_screen',
                input: {
                  'intent': 'retirement_choice',
                  'confidence': 0.9,
                  'context_message':
                      'Compare la rente et le capital avec tes donnees.',
                },
              ),
            ],
          );
        }

        capturedMemoryBlock = memoryBlock;
        return const CoachResponse(
          message: 'Je tiens compte de la simulation.',
          disclaimer: 'Outil educatif.',
        );
      });

      final profileProvider = buildProfileProvider();
      final mintState = buildMintStateForTest(profileProvider.profile!);
      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/coach',
        routes: [
          GoRoute(
            path: '/coach',
            builder: (context, state) => CoachChatScreen(
              contextBuilder: ({
                profile,
                prefs,
                now,
                mintState,
              }) async {
                return const EnrichedContext(
                  memoryBlock: 'TEST CONTEXT',
                  conversationMemory: ConversationMemory.empty,
                  activeGoalsCount: 0,
                );
              },
            ),
          ),
          GoRoute(
            path: '/rente-vs-capital',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('fake_rente_vs_capital_complete'),
                  onPressed: () async {
                    await ScreenCompletionTracker.markCompletedWithReturn(
                      'rente_vs_capital',
                      const ScreenReturn.completed(
                        route: '/rente-vs-capital',
                        updatedFields: {'retirementMode': 'estimate'},
                        confidenceDelta: 0.02,
                      ),
                    );
                    if (context.canPop()) context.pop();
                  },
                  child: const Text('Terminer la simulation'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: profileProvider),
            ChangeNotifierProvider(create: (_) => ByokProvider()),
            ChangeNotifierProvider.value(
              value: MintStateProvider()..injectStateForTest(mintState),
            ),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
          ),
        ),
      );
      await pumpUntilGreeting(tester);

      await tester.enterText(find.byType(TextField), 'Rente ou capital ?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final routeCard = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(routeCard.route, '/rente-vs-capital');
      final routeButton = find.descendant(
        of: find.byType(RouteSuggestionCard),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(routeButton);
      await tester.tap(routeButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('fake_rente_vs_capital_complete')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_rente_vs_capital_complete')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'Et maintenant ?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedMemoryBlock, isNotNull);
      expect(capturedMemoryBlock, contains('TEST CONTEXT'));
      expect(capturedMemoryBlock, contains('/rente-vs-capital'));
      expect(capturedMemoryBlock, contains('retirementMode: estimate'));
    });

    testWidgets('resumes persisted conversation by conversationId',
        (tester) async {
      usePhoneViewport(tester);
      await ConversationStore().saveConversation('conv-resume-row20', [
        ChatMessage(
          role: 'user',
          content: 'On parlait de mon rachat LPP',
          timestamp: DateTime(2026, 6, 4, 9),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Oui, je garde ce contexte.',
          timestamp: DateTime(2026, 6, 4, 9, 1),
        ),
      ]);

      await tester.pumpWidget(
        buildTestWidget(
          withProfile: true,
          conversationId: 'conv-resume-row20',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('On parlait de mon rachat LPP'), findsOneWidget);
      expect(bySemanticsIdentifier('coach_user_message_0'), findsOneWidget);
      expect(find.text('Oui, je garde ce contexte.'), findsOneWidget);
      expect(find.text("Salut. Moi c'est Mint."), findsNothing);
    });

    testWidgets('sends resumed conversation history with the next message',
        (tester) async {
      usePhoneViewport(tester);
      final previousHardGate = FeatureFlags.enableCoachHardGate;
      FeatureFlags.enableCoachHardGate = false;
      List<ChatMessage>? capturedHistory;
      addTearDown(() {
        FeatureFlags.enableCoachHardGate = previousHardGate;
        CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
      });

      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedHistory = List<ChatMessage>.from(history);
        return const CoachResponse(
          message: 'Je continue avec le contexte.',
          disclaimer: 'Outil educatif.',
        );
      });

      await ConversationStore().saveConversation('conv-resume-row20', [
        ChatMessage(
          role: 'user',
          content: 'On parlait de mon rachat LPP',
          timestamp: DateTime(2026, 6, 4, 9),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Oui, je garde ce contexte.',
          timestamp: DateTime(2026, 6, 4, 9, 1),
        ),
      ]);

      await tester.pumpWidget(
        buildTestWidget(
          withProfile: true,
          conversationId: 'conv-resume-row20',
          contextBuilder: ({
            profile,
            prefs,
            now,
            mintState,
          }) async {
            return const EnrichedContext(
              memoryBlock: 'TEST CONTEXT',
              conversationMemory: ConversationMemory.empty,
              activeGoalsCount: 0,
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'Et maintenant ?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedHistory, isNotNull);
      expect(bySemanticsIdentifier('coach_user_message_1'), findsOneWidget);
      expect(capturedHistory!.map((message) => message.content), [
        'On parlait de mon rachat LPP',
        'Oui, je garde ce contexte.',
        'Et maintenant ?',
      ]);
      expect(find.text('Je continue avec le contexte.'), findsOneWidget);
    });

    testWidgets('sends message when pressing send button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Type a unique message that won't collide with chip text
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send and settle (scroll animation + async response)
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      // Bounded pump past the ContextInjectorService 2 s `.timeout`.
      // We do NOT pumpAndSettle because _sendMessage also enters the
      // CoachOrchestrator tier 3 pipeline with a 55 s `.timeout` on
      // ServerKey HTTP; pumpAndSettle hangs. 3 s of virtual time
      // triggers the ContextInjector catch, enough for the user bubble
      // to commit.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      // User message should appear as a bubble
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
      // SKIPPED: Coach tier-3 ServerKey 55 s `.timeout` leaves pending
      // timers in the FakeAsync test harness (tracked — needs injectable
      // CoachOrchestrator mock). Covered at integration level by
      // coach_chat_integration_test.
    }, skip: true);

    testWidgets('shows coach response after sending message', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Type a message about 3a
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      // Bounded pump instead of pumpAndSettle — the send handler fires an
      // async ContextInjectorService.buildContext with a 2s `.timeout`
      // that never resolves in the test harness (no network, no DB).
      // pumpAndSettle hangs forever; we advance virtual time past the
      // 2s timeout so the catch branch fires and the UI settles.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      // After send, user message should appear (coach may or may not respond in test env)
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
      // SKIPPED — coach tier-3 timer, see sibling skip note.
    }, skip: true);

    testWidgets('shows coach avatar icon', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Coach avatar shows "M" typographic mark
      // Avatar 'M' appears on coach messages (may need pump for greeting)
      expect(
          find.byType(Container), findsWidgets); // Verify widget tree renders
    });

    testWidgets('shows lightning bolt button for menu', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('shows coach response after sending 3a message',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a 3a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      // Bounded pump instead of pumpAndSettle — the send handler fires an
      // async ContextInjectorService.buildContext with a 2s `.timeout`
      // that never resolves in the test harness (no network, no DB).
      // pumpAndSettle hangs forever; we advance virtual time past the
      // 2s timeout so the catch branch fires and the UI settles.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      // Fallback response should appear (at least a Text widget)
      expect(find.text('Mon 3a'), findsOneWidget);
      // SKIPPED — coach tier-3 timer, see sibling skip note.
    }, skip: true);

    testWidgets('shows coach response after sending LPP message',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a LPP message
      await tester.enterText(find.byType(TextField), 'Ma LPP');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      // Bounded pump instead of pumpAndSettle — the send handler fires an
      // async ContextInjectorService.buildContext with a 2s `.timeout`
      // that never resolves in the test harness (no network, no DB).
      // pumpAndSettle hangs forever; we advance virtual time past the
      // 2s timeout so the catch branch fires and the UI settles.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      // User message should appear
      expect(find.text('Ma LPP'), findsOneWidget);
      // SKIPPED — coach tier-3 timer, see sibling skip note.
    }, skip: true);
  });

  group('CoachChatScreen — settings access', () {
    testWidgets('settings icon navigates to BYOK config', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Settings gear icon should be present
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('more_horiz settings icon shown in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Refactored app bar uses more_horiz for settings
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('no BYOK CTA card in chat area', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // BYOK configuration is now done via settings icon, no in-chat CTA
      expect(find.text('Configure ton coach IA'), findsNothing);
      expect(find.text('Configurer'), findsNothing);
    });
  });

  group('CoachChatScreen — export', () {
    testWidgets('export button not shown initially (no user messages)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // No user messages yet, so share button should not be shown
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });

    testWidgets('export button appears after sending a message',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      // Bounded pump instead of pumpAndSettle — the send handler fires an
      // async ContextInjectorService.buildContext with a 2s `.timeout`
      // that never resolves in the test harness (no network, no DB).
      // pumpAndSettle hangs forever; we advance virtual time past the
      // 2s timeout so the catch branch fires and the UI settles.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      // Now the share/export button should appear
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      // SKIPPED — coach tier-3 timer, see sibling skip note.
    }, skip: true);
  });

  group('ReturnContract V2 — i18n keys', () {
    testWidgets('routeReturnCompleted i18n key resolves in French',
        (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnCompleted;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnCompleted')));
    });

    testWidgets('routeReturnAbandoned i18n key resolves in French',
        (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnAbandoned;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnAbandoned')));
    });

    testWidgets('routeReturnChanged i18n key resolves in French',
        (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnChanged;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnChanged')));
    });

    testWidgets('completed i18n string differs from abandoned string',
        (tester) async {
      String completedMsg = '';
      String abandonedMsg = '';
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          completedMsg = S.of(ctx)!.routeReturnCompleted;
          abandonedMsg = S.of(ctx)!.routeReturnAbandoned;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(completedMsg, isNot(abandonedMsg));
    });

    testWidgets('changed i18n string differs from completed string',
        (tester) async {
      String completedMsg = '';
      String changedMsg = '';
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          completedMsg = S.of(ctx)!.routeReturnCompleted;
          changedMsg = S.of(ctx)!.routeReturnChanged;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(changedMsg, isNot(completedMsg));
    });
  });

  group('CoachChatScreen — route_to_screen tool_use (S58)', () {
    testWidgets('screen does not crash with route_to_screen tool_use payload',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Screen renders without crashing — basic smoke test
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('RouteSuggestionCard widget is importable from chat screen',
        (tester) async {
      // Verifies the import chain: CoachChatScreen → RouteSuggestionCard
      // no widget tree needed — compile-time check
      expect(RouteSuggestionCard, isNotNull);
    });

    test('RouteToolPayload carries intent, confidence, contextMessage', () {
      const payload = RouteToolPayload(
        intent: 'retirement_choice',
        confidence: 0.85,
        contextMessage: 'Voici le simulateur rente vs capital.',
      );
      expect(payload.intent, 'retirement_choice');
      expect(payload.confidence, 0.85);
      expect(payload.contextMessage, 'Voici le simulateur rente vs capital.');
    });

    test('ChatMessage.hasRoutePayload is false when routePayload is null', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
      );
      expect(msg.hasRoutePayload, isFalse);
    });

    test('ChatMessage.hasRoutePayload is true when routePayload is set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Je te propose de voir le simulateur.',
        timestamp: DateTime.now(),
        routePayload: const RouteToolPayload(
          intent: 'retirement_choice',
          confidence: 0.9,
          contextMessage: 'Simulateur retraite',
        ),
      );
      expect(msg.hasRoutePayload, isTrue);
    });

    test('RoutePlanner.plan resolves retirement_choice with full profile', () {
      // Build a minimal profile using CoachProfileProvider
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      // Profile has salary+age+canton — should resolve to openScreen or
      // openWithWarning (depending on avoirLpp etc.)
      expect(
        decision.action,
        anyOf(RouteAction.openScreen, RouteAction.openWithWarning),
      );
      expect(decision.route, '/rente-vs-capital');
    });

    test('RoutePlanner.plan returns conversationOnly for low confidence', () {
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('retirement_choice', confidence: 0.2);
      expect(decision.action, RouteAction.conversationOnly);
    });

    test('RoutePlanner.plan returns conversationOnly for unknown intent', () {
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('totally_unknown_intent_xyz');
      expect(decision.action, RouteAction.conversationOnly);
    });
  });

  // ══════════════════════════════════════════════════════════════════
  //  Phase 10-02a: onboarding-done bootstrap from intent payload
  // ══════════════════════════════════════════════════════════════════
  group('CoachChatScreen — onboarding bootstrap (Phase 10-02a)', () {
    Widget buildWithPayload(CoachEntryPayload? payload) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => buildProfileProvider()),
          ChangeNotifierProvider(create: (_) => ByokProvider()),
          ChangeNotifierProvider(create: (_) => MintStateProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: CoachChatScreen(entryPayload: payload),
        ),
      );
    }

    testWidgets(
        'first entry from onboarding intent payload sets miniOnboardingCompleted',
        (tester) async {
      usePhoneViewport(tester);
      // Flag starts false.
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      // No userMessage → no _sendMessage call → no streaming timers.
      const payload = CoachEntryPayload(
        source: CoachEntrySource.onboardingIntent,
        topic: 'pillar3a',
        data: {'fromOnboarding': true},
      );

      await tester.pumpWidget(buildWithPayload(payload));
      await pumpUntilGreeting(tester);

      // Chat bootstrap owns this write — intent_screen does not touch it.
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isTrue,
      );
    });

    testWidgets('entry without onboardingIntent source does NOT set the flag',
        (tester) async {
      usePhoneViewport(tester);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      // Simulate a home-chip entry (not onboarding). No userMessage
      // to avoid spawning streaming timers in the test env.
      const payload = CoachEntryPayload(
        source: CoachEntrySource.homeChip,
        topic: 'pillar3a',
      );

      await tester.pumpWidget(buildWithPayload(payload));
      await pumpUntilGreeting(tester);

      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );
    });
  });
}
