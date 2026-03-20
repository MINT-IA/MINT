import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
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

  group('CoachLlmService — initial greeting', () {
    test('initial greeting contains firstName', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      expect(greeting, contains('Julien'));
    });

    test('initial greeting uses MINT voice (direct, no jargon)', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      // V5 voice: "Salut {name}. Pose ta question..."
      expect(greeting, contains('Pose ta question'));
    });

    test('initial greeting mentions chiffres as anchor', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      expect(greeting, contains('chiffres'));
    });

    test('initial suggestions are not empty', () {
      final suggestions = CoachLlmService.initialSuggestions;

      expect(suggestions, isNotEmpty);
      expect(suggestions.length, greaterThanOrEqualTo(3));
    });
  });

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

  group('CoachLlmService — suggested actions inference', () {
    test('3a message suggests 3a actions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mon 3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.suggestedActions, isNotNull);
      expect(response.suggestedActions!.any((a) => a.contains('3a')), isTrue);
    });

    test('LPP message suggests LPP actions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'rachat LPP',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.suggestedActions, isNotNull);
      expect(
          response.suggestedActions!.any((a) => a.contains('LPP')), isTrue);
    });

    test('retraite message suggests trajectory actions', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Ma retraite',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.suggestedActions, isNotNull);
      expect(
          response.suggestedActions!.any((a) => a.contains('trajectoire')),
          isTrue);
    });

    test('default message suggests fitness and trajectory', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour !',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.suggestedActions, isNotNull);
      expect(response.suggestedActions!.length, greaterThanOrEqualTo(2));
    });
  });
}
