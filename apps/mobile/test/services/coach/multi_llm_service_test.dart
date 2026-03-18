import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach/local_fallback_service.dart';
import 'package:mint_mobile/services/coach/multi_llm_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart' as legacy;

// ────────────────────────────────────────────────────────────
//  MULTI-LLM SERVICE TESTS — Sprint S64
// ────────────────────────────────────────────────────────────
//
// 25+ tests covering:
//   - MultiLlmService: failover chain, health tracking, recovery
//   - ComplianceGuard (S64 additions): banned terms, IBAN, ranking, PII
//   - LocalFallbackService: topic templates, disclaimers, compliance
//
// References: LSFin art. 3/8, FINMA circular 2008/21
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // MultiLlmService — Provider Management
  // ═══════════════════════════════════════════════════════════

  group('MultiLlmService — provider management', () {
    setUp(() {
      MultiLlmService.resetHealth();
    });

    test('providers are ordered by priority (claude=1, gpt4o=2, local=3)',
        () {
      final providers = MultiLlmService.providers;
      expect(providers.length, 3);
      expect(providers[0].provider, LlmProvider.claude);
      expect(providers[0].priority, 1);
      expect(providers[1].provider, LlmProvider.gpt4o);
      expect(providers[1].priority, 2);
      expect(providers[2].provider, LlmProvider.localFallback);
      expect(providers[2].priority, 3);
    });

    test('all providers start as healthy', () {
      for (final p in LlmProvider.values) {
        expect(MultiLlmService.healthOf(p), LlmHealthStatus.healthy);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // MultiLlmService — Health Tracking
  // ═══════════════════════════════════════════════════════════

  group('MultiLlmService — health tracking', () {
    setUp(() {
      MultiLlmService.resetHealth();
    });

    test('provider stays healthy after 1-2 failures', () {
      MultiLlmService.reportFailure(LlmProvider.claude, 'timeout');
      expect(MultiLlmService.healthOf(LlmProvider.claude),
          LlmHealthStatus.healthy);

      MultiLlmService.reportFailure(LlmProvider.claude, 'timeout');
      expect(MultiLlmService.healthOf(LlmProvider.claude),
          LlmHealthStatus.healthy);
    });

    test('provider degrades after 3 consecutive failures', () {
      for (var i = 0; i < 3; i++) {
        MultiLlmService.reportFailure(LlmProvider.claude, 'timeout');
      }
      expect(MultiLlmService.healthOf(LlmProvider.claude),
          LlmHealthStatus.degraded);
    });

    test('provider goes down after 5 consecutive failures', () {
      for (var i = 0; i < 5; i++) {
        MultiLlmService.reportFailure(LlmProvider.claude, 'error');
      }
      expect(
          MultiLlmService.healthOf(LlmProvider.claude), LlmHealthStatus.down);
    });

    test('success resets health to healthy', () {
      for (var i = 0; i < 4; i++) {
        MultiLlmService.reportFailure(LlmProvider.gpt4o, 'error');
      }
      expect(MultiLlmService.healthOf(LlmProvider.gpt4o),
          LlmHealthStatus.degraded);

      MultiLlmService.reportSuccess(
          LlmProvider.gpt4o, const Duration(milliseconds: 500));
      expect(MultiLlmService.healthOf(LlmProvider.gpt4o),
          LlmHealthStatus.healthy);
    });

    test('different providers track independently', () {
      for (var i = 0; i < 5; i++) {
        MultiLlmService.reportFailure(LlmProvider.claude, 'error');
      }
      expect(
          MultiLlmService.healthOf(LlmProvider.claude), LlmHealthStatus.down);
      expect(MultiLlmService.healthOf(LlmProvider.gpt4o),
          LlmHealthStatus.healthy);
      expect(MultiLlmService.healthOf(LlmProvider.localFallback),
          LlmHealthStatus.healthy);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // MultiLlmService — Failover (unit tests, no network)
  // ═══════════════════════════════════════════════════════════

  group('MultiLlmService — failover chain', () {
    setUp(() {
      MultiLlmService.resetHealth();
    });

    test('falls back to local when no API key is provided', () async {
      final response = await MultiLlmService.chat(
        systemPrompt: 'System prompt',
        messages: [
          legacy.ChatMessage(
            role: 'user',
            content: 'Parle-moi du 3a',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.provider, LlmProvider.localFallback);
      expect(response.content, isNotEmpty);
      expect(response.passedCompliance, true);
    });

    test(
        'falls back to local when all cloud providers are down (no config)',
        () async {
      for (var i = 0; i < 5; i++) {
        MultiLlmService.reportFailure(LlmProvider.claude, 'error');
        MultiLlmService.reportFailure(LlmProvider.gpt4o, 'error');
      }

      final response = await MultiLlmService.chat(
        systemPrompt: 'Test',
        messages: [
          legacy.ChatMessage(
            role: 'user',
            content: 'Question sur la LPP',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.provider, LlmProvider.localFallback);
      expect(response.content, contains('LPP'));
    });

    test('local fallback always provides content even on empty message',
        () async {
      final response = await MultiLlmService.chat(
        systemPrompt: 'Test',
        messages: [
          legacy.ChatMessage(
            role: 'user',
            content: '',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.provider, LlmProvider.localFallback);
      expect(response.content, isNotEmpty);
    });

    test('latency is tracked for local fallback as zero', () async {
      final response = await MultiLlmService.chat(
        systemPrompt: 'Test',
        messages: [
          legacy.ChatMessage(
            role: 'user',
            content: 'retraite',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.provider, LlmProvider.localFallback);
      expect(response.latency, Duration.zero);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // MultiLlmService — Health Check API
  // ═══════════════════════════════════════════════════════════

  group('MultiLlmService — healthCheck API', () {
    setUp(() {
      MultiLlmService.resetHealth();
    });

    test('healthCheck returns status for all providers', () async {
      final status = await MultiLlmService.healthCheck();
      expect(status.length, LlmProvider.values.length);
      for (final p in LlmProvider.values) {
        expect(status.containsKey(p), true);
      }
    });

    test('healthCheck reflects degraded state', () async {
      for (var i = 0; i < 3; i++) {
        MultiLlmService.reportFailure(LlmProvider.claude, 'timeout');
      }
      final status = await MultiLlmService.healthCheck();
      expect(status[LlmProvider.claude], LlmHealthStatus.degraded);
      expect(status[LlmProvider.gpt4o], LlmHealthStatus.healthy);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // MultiLlmService — Quality Scoring
  // ═══════════════════════════════════════════════════════════

  group('MultiLlmService — quality scoring', () {
    test('quality score computes geometric mean correctly', () {
      final score = QualityScore.compute(
        relevance: 1.0,
        compliance: 1.0,
        frenchQuality: 1.0,
      );
      expect(score.overall, closeTo(1.0, 0.01));
    });

    test('quality score penalizes low axes via geometric mean', () {
      final score = QualityScore.compute(
        relevance: 1.0,
        compliance: 0.0,
        frenchQuality: 1.0,
      );
      expect(score.overall, closeTo(0.0, 0.01));
    });

    test('scoreResponse returns valid quality for local fallback', () async {
      final response = LlmResponse(
        content: 'Le 3e pilier (pilier 3a) est un outil d\'épargne-retraite '
            'avec avantage fiscal. Le plafond est de 7\u00a0258\u00a0CHF.',
        provider: LlmProvider.localFallback,
        latency: Duration.zero,
      );

      final quality = await MultiLlmService.scoreResponse(response);
      expect(quality.overall, greaterThan(0));
      expect(quality.relevance, greaterThan(0));
      expect(quality.compliance, greaterThanOrEqualTo(0));
      expect(quality.frenchQuality, greaterThanOrEqualTo(0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ComplianceGuard — S64 enhanced checks
  // ═══════════════════════════════════════════════════════════

  group('ComplianceGuard — S64 compliance checks', () {
    test('clean educational response passes', () {
      final result = ComplianceGuard.validate(
        'Ton taux de remplacement pourrait atteindre environ 65\u00a0% '
        'selon ces hypothèses. Il serait utile de consulter un\u00b7e '
        'spécialiste pour affiner.',
      );
      expect(result.isCompliant, true);
      expect(result.useFallback, false);
    });

    test('banned term "garanti" detected', () {
      final result = ComplianceGuard.validate(
        'Ce rendement est garanti à 5\u00a0% par an.',
      );
      expect(result.violations, anyElement(contains('garanti')));
    });

    test('banned term "optimal" detected', () {
      final result = ComplianceGuard.validate(
        'La stratégie optimale serait de verser le maximum en 3a.',
      );
      expect(result.violations, anyElement(contains('optimal')));
    });

    test('guarantee phrase with "certain" triggers violation', () {
      final result = ComplianceGuard.validate(
        'Tu auras certain une rente plus élevée.',
      );
      expect(result.violations, isNotEmpty);
    });

    test('IBAN-like input does not crash compliance guard', () {
      final result = ComplianceGuard.validate(
        'Ton IBAN est CH93 0076 2011 6238 5295 7.',
      );
      expect(result, isNotNull);
    });

    test('ranking pattern "top 20%" detected', () {
      final result = ComplianceGuard.validate(
        'Tu es dans le top 20% des épargnants suisses.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, true);
    });

    test('auto-sanitize replaces "garanti" with softer term', () {
      final result = ComplianceGuard.validate(
        'Ton rendement est garanti. Pas d\'inquiétude.',
      );
      expect(result.sanitizedText.toLowerCase(), isNot(contains('garanti')));
    });

    test('multiple violations in one response trigger fallback', () {
      final result = ComplianceGuard.validate(
        'Ce rendement garanti est certain et sans risque. '
        'C\'est la meilleure option possible.',
      );
      expect(result.violations.length, greaterThan(2));
      expect(result.useFallback, true);
    });

    test('empty response handled gracefully', () {
      final result = ComplianceGuard.validate('');
      expect(result.isCompliant, false);
      expect(result.useFallback, true);
      expect(result.violations, contains('Sortie vide'));
    });

    test('prescriptive "investis dans" detected and rejected', () {
      final result = ComplianceGuard.validate(
        'Investis dans des ETF pour ton 3a.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LocalFallbackService
  // ═══════════════════════════════════════════════════════════

  group('LocalFallbackService', () {
    test('3a topic returns relevant template response', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment fonctionne le 3a ?',
      );
      expect(response, contains('3'));
      expect(response, contains('pilier'));
      expect(response, contains('OPP3'));
    });

    test('LPP topic returns relevant template response', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Explique-moi la LPP et le rachat',
      );
      expect(response, contains('LPP'));
      expect(response, contains('prévoyance'));
    });

    test('AVS topic returns relevant template response', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Quelle sera ma rente AVS ?',
      );
      expect(response, contains('AVS'));
      expect(response, contains('rente'));
    });

    test('impots topic returns relevant template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment réduire mes impôts ?',
      );
      expect(response, anyOf(contains('impôt'), contains('déduction')));
    });

    test('retraite topic returns relevant template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Quand est-ce que je peux prendre ma retraite ?',
      );
      expect(response, contains('retraite'));
      expect(response, contains('pilier'));
    });

    test('dette topic returns empathetic template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'J\'ai beaucoup de dettes, que faire ?',
      );
      expect(response, contains('dette'));
      expect(response, anyOf(contains('Caritas'), contains('dettes.ch')));
    });

    test('unknown topic returns generic educational response', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Bonjour, quel temps fait-il ?',
      );
      expect(response, contains('simulateur'));
    });

    test('response always contains disclaimer', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'N\'importe quoi',
      );
      expect(
        response,
        anyOf(
          contains('éducatif'),
          contains('LSFin'),
          contains('spécialiste'),
        ),
      );
    });

    test('response always contains retry message', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Question quelconque',
      );
      expect(response, contains('réessaie'));
    });

    test('response contains no banned terms across all topics', () {
      final topics = [
        'Parle-moi du 3a',
        'Explique la LPP',
        'Ma rente AVS',
        'Mes impôts',
        'Mon budget',
        'Acheter un appartement',
        'Ma retraite',
        'Mon assurance maladie',
        'La succession',
        'Mes dettes',
        'Autre chose',
      ];

      for (final msg in topics) {
        final response = LocalFallbackService.generateFallback(
          userMessage: msg,
        );
        final lower = response.toLowerCase();
        expect(lower, isNot(contains('sans risque')),
            reason: 'Banned "sans risque" found for "$msg"');
        // "garanti" should not appear with word boundary.
        expect(RegExp(r'\bgaranti\b').hasMatch(lower), false,
            reason: 'Banned "garanti" found for "$msg"');
      }
    });

    test('detectedTopics parameter overrides keyword matching', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Bonjour',
        detectedTopics: ['lpp'],
      );
      expect(response, contains('LPP'));
    });

    test('immobilier topic returns relevant template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Je veux acheter une maison',
      );
      expect(response, anyOf(contains('immobilier'), contains('hypothè')));
    });

    test('succession topic returns relevant template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment fonctionne l\'héritage en Suisse ?',
      );
      expect(response, anyOf(contains('successoral'), contains('héréditaires')));
    });

    test('assurances topic returns relevant template', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Mon assurance maladie coûte cher',
      );
      expect(response, anyOf(contains('LAMal'), contains('assurance')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LlmProviderConfig — data class
  // ═══════════════════════════════════════════════════════════

  group('LlmProviderConfig', () {
    test('default complianceValidated is true', () {
      const config = LlmProviderConfig(
        provider: LlmProvider.claude,
        priority: 1,
        timeout: Duration(seconds: 20),
        maxRetries: 2,
      );
      expect(config.complianceValidated, true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // LlmResponse — data class
  // ═══════════════════════════════════════════════════════════

  group('LlmResponse', () {
    test('stores all fields correctly', () {
      final response = LlmResponse(
        content: 'Test content',
        provider: LlmProvider.claude,
        latency: const Duration(milliseconds: 500),
        tokensUsed: 150,
        passedCompliance: true,
        quality: QualityScore.compute(
          relevance: 0.9,
          compliance: 0.95,
          frenchQuality: 0.88,
        ),
      );
      expect(response.content, 'Test content');
      expect(response.provider, LlmProvider.claude);
      expect(response.latency.inMilliseconds, 500);
      expect(response.tokensUsed, 150);
      expect(response.passedCompliance, true);
      expect(response.quality!.overall, greaterThan(0));
    });
  });
}
