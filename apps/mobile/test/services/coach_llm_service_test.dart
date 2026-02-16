import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH LLM SERVICE TESTS — Sprint C8
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
    test('responds to "3a" keyword with 3a content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Parle-moi de mon 3a',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('7\'258'));
      expect(response.message, contains('3a'));
      expect(response.suggestedActions, isNotNull);
      expect(response.suggestedActions, isNotEmpty);
    });

    test('responds to "lpp" keyword with LPP content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Que penses-tu de ma LPP ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('rachat'));
      expect(response.message, contains('LPP'));
      expect(response.suggestedActions, isNotNull);
    });

    test('responds to "rachat" keyword with LPP buyback content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Je veux faire un rachat',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('lacune LPP'));
      expect(response.message, contains('impots'));
    });

    test('responds to "retraite" keyword with retirement data', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Comment se presente ma retraite ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('taux de remplacement'));
      expect(response.message, contains('%'));
      // Should contain the actual computed rate, not a placeholder
      expect(response.message, isNot(contains('{tauxRemplacement}')));
    });

    test('responds to "impot" keyword with tax content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Aide-moi avec mes impots',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('declaration'));
      expect(response.message, contains('canton'));
      expect(response.message, contains('VS'));
    });

    test('responds to "fiscal" keyword with tax content', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Quelles deductions fiscales ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('3a'));
      expect(response.message, contains('rachats LPP'));
    });

    test('responds to "lauren" keyword with FATCA context', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Et pour Lauren ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('Lauren'));
      expect(response.message, contains('FATCA'));
      expect(response.message, contains('specialiste'));
    });

    test('responds to "conjoint" keyword with FATCA context', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Mon conjoint aussi ?',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('Lauren'));
      expect(response.message, contains('americaine'));
    });

    test('responds with default for unknown input', () async {
      final response = await CoachLlmService.chat(
        userMessage: 'Bonjour',
        profile: profile,
        history: emptyHistory,
        config: config,
      );

      expect(response.message, contains('situation financiere'));
      expect(response.suggestedActions, isNotNull);
      expect(response.suggestedActions!.length, greaterThan(0));
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

      expect(response.disclaimer, contains('educatif'));
      expect(response.disclaimer, contains('conseil financier'));
      expect(response.disclaimer, contains('LSFin'));
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

      for (final keyword in keywords) {
        final response = await CoachLlmService.chat(
          userMessage: keyword,
          profile: profile,
          history: emptyHistory,
          config: config,
        );

        final lower = response.message.toLowerCase();
        expect(lower, isNot(contains('garanti')), reason: 'keyword: $keyword');
        expect(lower, isNot(contains('certain')), reason: 'keyword: $keyword');
        expect(lower, isNot(contains('sans risque')),
            reason: 'keyword: $keyword');
        expect(lower, isNot(contains('optimal')), reason: 'keyword: $keyword');
        expect(lower, isNot(contains('parfait')), reason: 'keyword: $keyword');
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
  });

  group('CoachLlmService — initial greeting', () {
    test('initial greeting contains firstName', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      expect(greeting, contains('Julien'));
    });

    test('initial greeting contains coach identity', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      expect(greeting, contains('coach financier MINT'));
    });

    test('initial greeting asks what to explore', () {
      final greeting = CoachLlmService.initialGreeting(profile);

      expect(greeting, contains('explorer'));
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
      final config = LlmConfig(
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
      expect(models, contains('claude-3-sonnet-20240229'));
      expect(models, isNotEmpty);
    });

    test('copyWith creates new config with updated fields', () {
      final original = LlmConfig.defaultOpenAI;
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
  });
}
