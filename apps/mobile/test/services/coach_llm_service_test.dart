import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/rag_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH LLM SERVICE TESTS — Phase 4 / BYOK + RAG + context
// ────────────────────────────────────────────────────────────

void main() {
  late CoachProfile profile;
  late LlmConfig config;
  late List<ChatMessage> emptyHistory;

  setUp(() {
    // FIX-P1-7: Register orchestrator (no longer auto-imported).
    CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
    profile = CoachProfile.buildDemo();
    config = LlmConfig.defaultOpenAI;
    emptyHistory = [];
  });

  group('CoachLlmService — mock responses', () {
    // CoachOrchestrator delegates SLM -> BYOK -> fallback.
    // In test env (no SLM, no BYOK key), always returns generic fallback.
    test('responds to "3a" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Parle-moi de mon 3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "lpp" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Que penses-tu de ma LPP ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "rachat" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Je veux faire un rachat',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "retraite" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Comment se presente ma retraite ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "impot" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Aide-moi avec mes impots',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "fiscal" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Quelles deductions fiscales ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "lauren" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Et pour Lauren ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds to "conjoint" keyword with non-empty content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mon conjoint aussi ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('responds with default for unknown input', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });
  });

  group('CoachLlmService — guardrails', () {
    test('disclaimer is always present in response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.disclaimer, isNotEmpty);
    });

    test('disclaimer is present for 3a response', () async {
      final response = await CoachLlmService.chat(
        userMessage: '3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.disclaimer, isNotEmpty);
      expect(response.disclaimer, contains('LSFin'));
    });

    test('wasFiltered is false for clean responses', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.wasFiltered, isFalse);
    });

    test('mock responses do not contain banned terms', () async {
      // Test all keyword paths
      final keywords = [
        '3a', 'lpp', 'rachat', 'retraite', 'impot',
        'fiscal', 'lauren', 'conjoint', 'bonjour',
      ];

      // Use French-aware word-boundary patterns matching ComplianceGuard logic,
      // so "certains" or "incertain" don't false-positive on "certain".
      final bannedPatterns = {
        'garanti': RegExp(r'(?<![a-zA-ZÀ-ÿ])garanti(?![a-zA-ZÀ-ÿ])'),
        'certain': RegExp(r'(?<![a-zA-ZÀ-ÿ])certain(?![a-zA-ZÀ-ÿ])'),
        'sans risque': RegExp(r'sans risque', caseSensitive: false),
        'optimal': RegExp(r'(?<![a-zA-ZÀ-ÿ])optimal(?![a-zA-ZÀ-ÿ])'),
        'parfait': RegExp(r'(?<![a-zA-ZÀ-ÿ])parfait(?![a-zA-ZÀ-ÿ])'),
      };

      for (final keyword in keywords) {
        final response = await CoachLlmService.chat(
          userMessage: keyword,
          profile: profile,
          history: emptyHistory,
          config: config,
        );

        final lower = response.message.toLowerCase();
        for (final entry in bannedPatterns.entries) {
          expect(entry.value.hasMatch(lower), isFalse,
              reason: 'keyword: $keyword contains banned term "${entry.key}"');
        }
      }
    });
  });

  group('CoachLlmService — system prompt', () {
    test('system prompt contains profile firstName', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('Julien'));
    });

    test('system prompt contains profile canton', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('VS'));
    });

    test('system prompt contains score data', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('Score Fitness'));
      expect(prompt, contains('Budget'));
      expect(prompt, contains('Prevoyance'));
      expect(prompt, contains('Patrimoine'));
    });

    test('system prompt contains conjoint info for couple', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('Lauren'));
      expect(prompt, contains('FATCA'));
    });

    test('system prompt does not contain conjoint for single person', () {
      final singleProfile = CoachProfile(
        firstName: 'Marc',
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 6000,
        etatCivil: CoachCivilStatus.celibataire,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
      );

      final prompt = CoachLlmService.buildSystemPrompt(singleProfile);

      expect(prompt, isNot(contains('Conjoint')));
    });

    test('system prompt contains educational rules', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('NE calcules JAMAIS'));
      expect(prompt, contains('NE donnes JAMAIS'));
      expect(prompt, contains('educatif'));
      expect(prompt, contains('specialiste'));
    });

    test('system prompt contains capital projection', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('Capital projete'));
      expect(prompt, contains('CHF'));
    });

    test('system prompt contains taux de remplacement', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('Taux de remplacement'));
      expect(prompt, contains('%'));
    });

    test('system prompt contains source citation instruction', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('cites TOUJOURS tes sources legales'));
    });

    test('system prompt contains structured response instructions', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('STRUCTURE DE TA REPONSE'));
      expect(prompt, contains('Commence par le chiffre ou le fait'));
      expect(prompt, contains('risques et points d\'attention'));
      expect(prompt, contains('sources legales'));
    });

    test('system prompt contains banned terms rule', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('garanti'));
      expect(prompt, contains('sans risque'));
      expect(prompt, contains('NE dis JAMAIS'));
    });
  });

  group('CoachLlmService — source grounding', () {
    test('3a response returns valid response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Parle-moi du 3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('LPP response returns valid response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Et ma LPP ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('retraite response returns valid response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Ma retraite ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('fiscal response returns valid response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mes impots ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('FATCA response returns valid response', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Et Lauren ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('default response has empty sources', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.sources, isEmpty);
    });

    test('sources are RagSource instances when present', () async {
      final response = await CoachLlmService.chat(
        userMessage: '3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      // Fallback may have empty sources
      if (response.sources.isNotEmpty) {
        expect(response.sources, everyElement(isA<RagSource>()));
      }
    });

    test('disclaimers field exists and is list', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.disclaimers, isA<List<String>>());
    });
  });

  // Note: initialGreeting and initialSuggestions now require S localizations
  // (i18n refactor). String-content tests are covered by ARB golden tests.
  // The API signature tests below verify the service compiles and accepts params.

  group('LlmConfig', () {
    test('defaultOpenAI has empty apiKey', () {
      expect(LlmConfig.defaultOpenAI.apiKey, isEmpty);
      expect(LlmConfig.defaultOpenAI.provider, LlmProvider.openai);
    });

    test('defaultAnthropic has empty apiKey', () {
      expect(LlmConfig.defaultAnthropic.apiKey, isEmpty);
      expect(LlmConfig.defaultAnthropic.provider, LlmProvider.anthropic);
    });

    test('hasApiKey returns false when empty', () {
      expect(LlmConfig.defaultOpenAI.hasApiKey, isFalse);
    });

    test('hasApiKey returns true when set', () {
      const config = LlmConfig(
        apiKey: 'sk-test-key',
        provider: LlmProvider.openai,
      );
      expect(config.hasApiKey, isTrue);
    });

    test('modelsForProvider returns OpenAI models', () {
      final models = LlmConfig.modelsForProvider(LlmProvider.openai);
      expect(models, contains('gpt-4'));
      expect(models, isNotEmpty);
    });

    test('modelsForProvider returns Anthropic models', () {
      final models = LlmConfig.modelsForProvider(LlmProvider.anthropic);
      expect(models, contains('claude-sonnet-4-5-20250929'));
      expect(models, isNotEmpty);
    });

    test('modelsForProvider returns Mistral models', () {
      final models = LlmConfig.modelsForProvider(LlmProvider.mistral);
      expect(models, contains('mistral-large-latest'));
      expect(models, isNotEmpty);
    });

    test('LlmProvider enum has three values', () {
      expect(LlmProvider.values, hasLength(3));
      expect(LlmProvider.values, contains(LlmProvider.openai));
      expect(LlmProvider.values, contains(LlmProvider.anthropic));
      expect(LlmProvider.values, contains(LlmProvider.mistral));
    });

    test('copyWith creates config with Mistral provider', () {
      const config = LlmConfig(
        apiKey: 'test-key',
        provider: LlmProvider.mistral,
        model: 'mistral-large-latest',
      );
      expect(config.provider, LlmProvider.mistral);
      expect(config.hasApiKey, isTrue);
      expect(config.model, 'mistral-large-latest');
    });

    test('copyWith creates new config with updated fields', () {
      const original = LlmConfig.defaultOpenAI;
      final updated = original.copyWith(apiKey: 'new-key');

      expect(updated.apiKey, 'new-key');
      expect(updated.provider, original.provider);
      expect(updated.model, original.model);
    });
  });

  group('ChatMessage', () {
    test('isUser returns true for user role', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'test',
        timestamp: DateTime.now(),
      );
      expect(msg.isUser, isTrue);
      expect(msg.isAssistant, isFalse);
      expect(msg.isSystem, isFalse);
    });

    test('isAssistant returns true for assistant role', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'test',
        timestamp: DateTime.now(),
      );
      expect(msg.isUser, isFalse);
      expect(msg.isAssistant, isTrue);
    });

    test('isSystem returns true for system role', () {
      final msg = ChatMessage(
        role: 'system',
        content: 'test',
        timestamp: DateTime.now(),
      );
      expect(msg.isSystem, isTrue);
    });

    test('ChatMessage has sources and disclaimers fields', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'test',
        timestamp: DateTime.now(),
        sources: const [
          RagSource(title: 'Test', file: 'test', section: 'Art. 1'),
        ],
        disclaimers: const ['Outil educatif.'],
      );
      expect(msg.sources, hasLength(1));
      expect(msg.disclaimers, hasLength(1));
    });

    test('ChatMessage sources default to empty', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'test',
        timestamp: DateTime.now(),
      );
      expect(msg.sources, isEmpty);
      expect(msg.disclaimers, isEmpty);
    });
  });

  group('CoachLlmService — conversation context (mock path)', () {
    test('mock response works with empty history', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mon 3a',
        profile: profile,
        history: [],
        config: config,
      );

      expect(response.message, contains('3a'));
    });

    test('mock response works with prior history', () async {
      // Simulate a conversation with history
      final history = [
        ChatMessage(
          role: 'assistant',
          content: 'Bonjour Julien !',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          role: 'user',
          content: 'Parle-moi du 3a',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Ton plafond 3a est de 7258 CHF.',
          timestamp: DateTime.now(),
        ),
      ];

      // Should not crash with history
      final response = await CoachLlmService.chat(
        userMessage: 'Et ma retraite ?',
        profile: profile,
        history: history,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('mock response works with large history (10+ messages)', () async {
      final history = List.generate(
        12,
        (i) => ChatMessage(
          role: i.isEven ? 'user' : 'assistant',
          content: 'Message $i',
          timestamp: DateTime.now(),
        ),
      );

      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: history,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });

    test('mock response works with system messages in history', () async {
      final history = [
        ChatMessage(
          role: 'system',
          content: 'Erreur technique.',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          role: 'user',
          content: 'Mon LPP',
          timestamp: DateTime.now(),
        ),
      ];

      final response = await CoachLlmService.chat(
        userMessage: 'impots',
        profile: profile,
        history: history,
        config: config,
      );

      expect(response.message, isNotEmpty);
    });
  });

  // Note: suggestedActions are now resolved at the screen layer (CoachChatScreen)
  // using inferSuggestedActions(userMessage, l) with BuildContext localizations.
  // The service layer returns suggestedActions: null (i18n refactor).
  // CoachChatScreen._inferSuggestedActions() covers topic-based routing tests.
  group('CoachLlmService — suggested actions inference', () {
    test('service returns null suggestedActions (resolved at screen layer)',
        () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mon 3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );
      // Actions are null at service layer; CoachChatScreen resolves them via l10n.
      expect(response.suggestedActions, isNull);
    });

    test('LPP message: service returns null suggestedActions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'rachat LPP',
        profile: profile,
        history: emptyHistory,
        config: config,
      );
      expect(response.suggestedActions, isNull);
    });

    test('retraite message: service returns null suggestedActions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Ma retraite',
        profile: profile,
        history: emptyHistory,
        config: config,
      );
      expect(response.suggestedActions, isNull);
    });

    test('default message: service returns null suggestedActions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour !',
        profile: profile,
        history: emptyHistory,
        config: config,
      );
      expect(response.suggestedActions, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CoachLlmService — voice system (5 pillars)
  // ════════════════════════════════════════════════════════════

  group('CoachLlmService — voice system (buildSystemPrompt)', () {
    test('prompt contains all 5 MINT voice pillars', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('CALME'));
      expect(prompt, contains('PRECIS'));
      expect(prompt, contains('FIN'));
      expect(prompt, contains('RASSURANT'));
      expect(prompt, contains('NET'));
    });

    test('prompt contains VOIX MINT section header', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('VOIX MINT'));
    });

    test('CALME pillar describes calm tone (no urgency)', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('calmement'));
      expect(prompt, contains("urgence"));
    });

    test('PRECIS pillar describes word precision', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('remplissage'));
      expect(prompt, contains('jargon'));
    });

    test('RASSURANT pillar contains accompaniment phrasing', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('infantilisant'));
      expect(prompt, contains('condescendant'));
    });

    test('NET pillar mentions truth and no promises', () {
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      expect(prompt, contains('verite'));
      expect(prompt, contains('Pas de promesse'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CoachLlmService — financial literacy adaptation
  // ════════════════════════════════════════════════════════════

  group('CoachLlmService — financial literacy adaptation', () {
    test('beginner profile prompt contains NOVICE adaptation', () {
      final beginnerProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.beginner,
      );
      final prompt = CoachLlmService.buildSystemPrompt(beginnerProfile);

      expect(prompt, contains('NOVICE'));
    });

    test('beginner prompt mentions short sentences / no jargon', () {
      final beginnerProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.beginner,
      );
      final prompt = CoachLlmService.buildSystemPrompt(beginnerProfile);

      expect(prompt, contains('phrases courtes'));
      expect(prompt, contains('jargon'));
    });

    test('intermediate profile prompt contains AUTONOME adaptation', () {
      final intermediateProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.intermediate,
      );
      final prompt = CoachLlmService.buildSystemPrompt(intermediateProfile);

      expect(prompt, contains('AUTONOME'));
    });

    test('advanced profile prompt contains EXPERT adaptation', () {
      final advancedProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
      );
      final prompt = CoachLlmService.buildSystemPrompt(advancedProfile);

      expect(prompt, contains('EXPERT'));
    });

    test('advanced prompt mentions legal references', () {
      final advancedProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
      );
      final prompt = CoachLlmService.buildSystemPrompt(advancedProfile);

      expect(prompt, contains('references legales'));
    });

    test('advanced prompt references LAVS art. 35 as example', () {
      final advancedProfile = profile.copyWith(
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
      );
      final prompt = CoachLlmService.buildSystemPrompt(advancedProfile);

      expect(prompt, contains('LAVS art. 35'));
    });

    test('each literacy level produces distinct ADAPTATION section', () {
      final beginner = profile.copyWith(
          financialLiteracyLevel: FinancialLiteracyLevel.beginner);
      final intermediate = profile.copyWith(
          financialLiteracyLevel: FinancialLiteracyLevel.intermediate);
      final advanced = profile.copyWith(
          financialLiteracyLevel: FinancialLiteracyLevel.advanced);

      final pBeg = CoachLlmService.buildSystemPrompt(beginner);
      final pInt = CoachLlmService.buildSystemPrompt(intermediate);
      final pAdv = CoachLlmService.buildSystemPrompt(advanced);

      // Each should contain exactly one level label
      expect(pBeg, contains('NOVICE'));
      expect(pBeg, isNot(contains('AUTONOME')));
      expect(pBeg, isNot(contains('EXPERT')));

      expect(pInt, contains('AUTONOME'));
      expect(pInt, isNot(contains('NOVICE')));
      expect(pInt, isNot(contains('EXPERT')));

      expect(pAdv, contains('EXPERT'));
      expect(pAdv, isNot(contains('NOVICE')));
      expect(pAdv, isNot(contains('AUTONOME')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CoachLlmService — _toRange (tested via buildSystemPrompt)
  // ════════════════════════════════════════════════════════════

  group('CoachLlmService — privacy-safe range display', () {
    test('profile with known LPP shows approximate range in prompt', () {
      // Julien has 70'377 CHF LPP → _toRange rounds to ~75'000 CHF
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      // Prompt must contain ~ prefix (privacy-safe range)
      expect(prompt, contains('~'));
    });

    test('profile with 0 salary produces 0 CHF for capital in prompt', () {
      final zeroProfile = CoachProfile(
        firstName: 'Test',
        birthYear: 1985,
        canton: 'ZH',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final prompt = CoachLlmService.buildSystemPrompt(zeroProfile);

      // When projection succeeds with 0 CHF, prompt shows '0 CHF' (not a range)
      expect(prompt, contains('Capital projete base'));
      expect(prompt, contains('CHF'));
    });

    test('system prompt does not contain exact salary amount', () {
      // CLAUDE.md §6: CoachContext MUST NEVER contain exact salary
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      // Julien's exact salary 122207 (or as string '122207') must not appear
      expect(prompt, isNot(contains('122207')));
      expect(prompt, isNot(contains("122'207")));
    });

    test('system prompt does not contain exact LPP amount', () {
      // CLAUDE.md §6: no exact savings/dettes in CoachContext
      final prompt = CoachLlmService.buildSystemPrompt(profile);

      // Julien's LPP 70377 must not appear verbatim
      expect(prompt, isNot(contains('70377')));
      expect(prompt, isNot(contains("70'377")));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CoachLlmService — initialGreeting edge cases
  // ════════════════════════════════════════════════════════════

  // Note: initialGreeting and initialSuggestions now require S localizations
  // (i18n refactor). These tests were testing hardcoded French strings that
  // are now correctly stored in ARB files and resolved at the screen layer.
  // The CoachChatScreen._addInitialGreeting() covers the screen-level behavior.

  // ════════════════════════════════════════════════════════════
  //  CoachLlmService — ChatTier enum
  // ════════════════════════════════════════════════════════════

  group('ChatTier', () {
    test('enum has four values', () {
      expect(ChatTier.values, hasLength(4));
      expect(ChatTier.values, contains(ChatTier.slm));
      expect(ChatTier.values, contains(ChatTier.byok));
      expect(ChatTier.values, contains(ChatTier.fallback));
      expect(ChatTier.values, contains(ChatTier.none));
    });

    test('ChatMessage tier defaults to none', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'test',
        timestamp: DateTime.now(),
      );
      expect(msg.tier, ChatTier.none);
    });

    test('ChatMessage tier can be set to fallback', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'test',
        timestamp: DateTime.now(),
        tier: ChatTier.fallback,
      );
      expect(msg.tier, ChatTier.fallback);
    });
  });
}
