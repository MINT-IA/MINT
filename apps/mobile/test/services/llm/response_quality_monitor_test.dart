// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/llm/response_quality_monitor.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE QUALITY MONITOR TESTS — Sprint S64
// ────────────────────────────────────────────────────────────
//
// 16 tests covering:
//   - Good response → high composite score
//   - Banned terms → low compliance
//   - Very short response → low length score
//   - Empty response → zero scores
//   - Record and retrieve averages
//   - Empty history returns empty map
//   - Disclaimer present → compliance boost
//   - Relevance calculation (keyword overlap)
//   - Length scoring boundaries
//   - Composite formula (0.4×rel + 0.4×comp + 0.2×len)
//   - Sliding window (max 50 per provider)
//   - clearAll
//
// References: LSFin art. 3/8
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  // QualityScore — data model
  // ═══════════════════════════════════════════════════════════

  group('QualityScore', () {
    test('stores all fields correctly', () {
      final score = QualityScore(
        provider: 'claude',
        relevance: 0.8,
        compliance: 0.9,
        length: 1.0,
        composite: 0.86,
        timestamp: DateTime(2026, 3, 21),
      );

      expect(score.provider, 'claude');
      expect(score.relevance, 0.8);
      expect(score.compliance, 0.9);
      expect(score.length, 1.0);
      expect(score.composite, 0.86);
    });

    test('round-trip JSON serialisation preserves all fields', () {
      final original = QualityScore(
        provider: 'openai',
        relevance: 0.75,
        compliance: 0.95,
        length: 1.0,
        composite: 0.88,
        timestamp: DateTime.utc(2026, 3, 21, 10, 0, 0),
      );

      final json = original.toJson();
      final restored = QualityScore.fromJson(json);

      expect(restored.provider, original.provider);
      expect(restored.relevance, original.relevance);
      expect(restored.compliance, original.compliance);
      expect(restored.length, original.length);
      expect(restored.composite, original.composite);
      expect(restored.timestamp, original.timestamp);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Relevance scoring (pure function)
  // ═══════════════════════════════════════════════════════════

  group('Relevance scoring', () {
    test('response containing user message keywords → high relevance', () {
      const userMessage = 'Comment fonctionne la LPP';
      const response = 'La LPP (prévoyance professionnelle) fonctionne selon '
          'le principe de la capitalisation individuelle.';

      final rel =
          ResponseQualityMonitor.scoreRelevance(response, userMessage);
      // "comment", "fonctionne", "lpp" — at least some overlap
      expect(rel, greaterThan(0.0));
    });

    test('response completely off-topic → low relevance', () {
      const userMessage = 'Quelle est ma rente AVS estimée';
      const response = 'Voici une recette de cuisine traditionnelle suisse.';

      final rel =
          ResponseQualityMonitor.scoreRelevance(response, userMessage);
      expect(rel, lessThan(0.5));
    });

    test('empty response → relevance = 0.0', () {
      final rel = ResponseQualityMonitor.scoreRelevance('', 'user message');
      expect(rel, 0.0);
    });

    test('empty user message → relevance = 0.5 (open-ended)', () {
      final rel = ResponseQualityMonitor.scoreRelevance('Some response', '');
      expect(rel, 0.5);
    });

    test('short user message words (<4 chars) → relevance = 0.5', () {
      // "Ma LPP" → all words < 4 chars except none, so all filtered
      final rel =
          ResponseQualityMonitor.scoreRelevance('La LPP est importante', 'ma');
      expect(rel, 0.5); // no content words in message
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Compliance scoring (pure function)
  // ═══════════════════════════════════════════════════════════

  group('Compliance scoring', () {
    test('clean response with disclaimer → compliance near 1.0', () {
      const response =
          'Tu pourrais envisager un versement 3a. Consulte un·e spécialiste.';
      final comp = ResponseQualityMonitor.scoreCompliance(response);
      expect(comp, greaterThanOrEqualTo(0.8));
    });

    test('response with "garanti" → reduced compliance', () {
      const response = 'Ce rendement est garanti à 5%.';
      final comp = ResponseQualityMonitor.scoreCompliance(response);
      expect(comp, lessThan(1.0));
    });

    test('response with multiple banned terms → lower compliance', () {
      const response =
          'Ce placement est garanti, certain et sans risque. C\'est le meilleur.';
      final comp = ResponseQualityMonitor.scoreCompliance(response);
      // Multiple banned terms accumulate -0.15 each
      expect(comp, lessThan(0.5));
    });

    test('empty response → compliance = 0.0', () {
      final comp = ResponseQualityMonitor.scoreCompliance('');
      expect(comp, 0.0);
    });

    test('response without disclaimer → penalty applied', () {
      const withDisclaimer =
          'Info éducative — ne constitue pas un conseil financier.';
      const withoutDisclaimer = 'Voici les informations sur la LPP.';

      final withComp =
          ResponseQualityMonitor.scoreCompliance(withDisclaimer);
      final withoutComp =
          ResponseQualityMonitor.scoreCompliance(withoutDisclaimer);

      expect(withComp, greaterThan(withoutComp));
    });

    test('response with "optimal" → reduced compliance', () {
      const response =
          'La stratégie optimale est de verser le maximum annuel.';
      final comp = ResponseQualityMonitor.scoreCompliance(response);
      expect(comp, lessThan(1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Length scoring (pure function)
  // ═══════════════════════════════════════════════════════════

  group('Length scoring', () {
    test('< 5 chars → 0.0', () {
      final len = ResponseQualityMonitor.scoreLength('Oui');
      expect(len, 0.0);
    });

    test('< 20 chars → 0.5', () {
      final len = ResponseQualityMonitor.scoreLength('Court message.');
      expect(len, 0.5);
    });

    test('20-49 chars → 0.75', () {
      // Exactly 30 chars
      final len =
          ResponseQualityMonitor.scoreLength('A' * 30);
      expect(len, 0.75);
    });

    test('50-500 chars → 1.0 (ideal range)', () {
      final len =
          ResponseQualityMonitor.scoreLength('A' * 200);
      expect(len, 1.0);
    });

    test('501-2000 chars → 0.75 (long but acceptable)', () {
      final len =
          ResponseQualityMonitor.scoreLength('A' * 1000);
      expect(len, 0.75);
    });

    test('> 2000 chars → 0.5 (excessively long)', () {
      final len =
          ResponseQualityMonitor.scoreLength('A' * 2500);
      expect(len, 0.5);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Composite scoring
  // ═══════════════════════════════════════════════════════════

  group('Composite scoring', () {
    test('formula: 0.4×relevance + 0.4×compliance + 0.2×length', () {
      const rel = 0.8;
      const comp = 0.9;
      const len = 1.0;
      const expected = 0.4 * rel + 0.4 * comp + 0.2 * len;

      final actual =
          ResponseQualityMonitor.computeComposite(rel, comp, len);
      expect(actual, closeTo(expected, 0.001));
    });

    test('all axes = 1.0 → composite = 1.0', () {
      final actual =
          ResponseQualityMonitor.computeComposite(1.0, 1.0, 1.0);
      expect(actual, closeTo(1.0, 0.001));
    });

    test('all axes = 0.0 → composite = 0.0', () {
      final actual =
          ResponseQualityMonitor.computeComposite(0.0, 0.0, 0.0);
      expect(actual, closeTo(0.0, 0.001));
    });

    test('composite is clamped to [0.0, 1.0]', () {
      // Even if inputs are valid fractions, result must stay in range
      final actual =
          ResponseQualityMonitor.computeComposite(1.0, 1.0, 1.0);
      expect(actual, inInclusiveRange(0.0, 1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // score() — integrated scoring
  // ═══════════════════════════════════════════════════════════

  group('ResponseQualityMonitor.score()', () {
    test('good response → high composite score', () {
      const userMessage = 'Comment optimiser mon 3a fiscal';
      const response =
          'Pour ton 3a, tu pourrais envisager de verser le plafond annuel '
          'de 7\'258 CHF. Cela réduit ton revenu imposable. '
          'Consulte un·e spécialiste pour un conseil personnalisé. '
          'Outil éducatif — ne constitue pas un conseil financier (LSFin).';

      final s = ResponseQualityMonitor.score(
        response,
        userMessage,
        provider: 'claude',
      );

      expect(s.composite, greaterThan(0.5));
      expect(s.provider, 'claude');
    });

    test('banned terms → low compliance axis', () {
      const response =
          'Ce placement est garanti, certain, sans risque. Optimal.';
      final s = ResponseQualityMonitor.score(
        response,
        'Question',
        provider: 'openai',
      );

      expect(s.compliance, lessThan(0.5));
    });

    test('very short response → low length score', () {
      final s = ResponseQualityMonitor.score(
        'Non.',
        'Oui ou non ?',
        provider: 'claude',
      );

      expect(s.length, lessThanOrEqualTo(0.5));
    });

    test('timestamp is set to approximately now', () {
      final before = DateTime.now();
      final s = ResponseQualityMonitor.score(
        'Response text',
        'User message',
        provider: 'claude',
      );
      final after = DateTime.now();

      expect(s.timestamp.isAfter(before) || s.timestamp.isAtSameMomentAs(before), true);
      expect(s.timestamp.isBefore(after) || s.timestamp.isAtSameMomentAs(after), true);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // record() and averageByProvider()
  // ═══════════════════════════════════════════════════════════

  group('record() and averageByProvider()', () {
    test('record a score and retrieve average', () async {
      final prefs = await SharedPreferences.getInstance();

      final s = QualityScore(
        provider: 'claude',
        relevance: 0.8,
        compliance: 0.9,
        length: 1.0,
        composite: 0.88,
        timestamp: DateTime.now(),
      );

      await ResponseQualityMonitor.record(s, prefs);
      final averages = await ResponseQualityMonitor.averageByProvider(prefs);

      expect(averages.containsKey('claude'), true);
      expect(averages['claude']!, closeTo(0.88, 0.001));
    });

    test('multiple records → average computed correctly', () async {
      final prefs = await SharedPreferences.getInstance();

      final scores = [
        QualityScore(
            provider: 'claude',
            relevance: 0.8,
            compliance: 0.8,
            length: 0.8,
            composite: 0.8,
            timestamp: DateTime.now()),
        QualityScore(
            provider: 'claude',
            relevance: 0.6,
            compliance: 0.6,
            length: 0.6,
            composite: 0.6,
            timestamp: DateTime.now()),
      ];

      for (final s in scores) {
        await ResponseQualityMonitor.record(s, prefs);
      }

      final averages = await ResponseQualityMonitor.averageByProvider(prefs);
      expect(averages['claude']!, closeTo(0.7, 0.001));
    });

    test('different providers tracked independently', () async {
      final prefs = await SharedPreferences.getInstance();

      await ResponseQualityMonitor.record(
        QualityScore(
            provider: 'claude',
            relevance: 1.0,
            compliance: 1.0,
            length: 1.0,
            composite: 1.0,
            timestamp: DateTime.now()),
        prefs,
      );

      await ResponseQualityMonitor.record(
        QualityScore(
            provider: 'openai',
            relevance: 0.5,
            compliance: 0.5,
            length: 0.5,
            composite: 0.5,
            timestamp: DateTime.now()),
        prefs,
      );

      final averages = await ResponseQualityMonitor.averageByProvider(prefs);
      expect(averages['claude'], closeTo(1.0, 0.001));
      expect(averages['openai'], closeTo(0.5, 0.001));
    });

    test('empty history returns empty map', () async {
      final prefs = await SharedPreferences.getInstance();
      final averages = await ResponseQualityMonitor.averageByProvider(prefs);
      expect(averages, isEmpty);
    });

    test('clearAll removes all scores', () async {
      final prefs = await SharedPreferences.getInstance();

      await ResponseQualityMonitor.record(
        QualityScore(
            provider: 'claude',
            relevance: 0.9,
            compliance: 0.9,
            length: 1.0,
            composite: 0.92,
            timestamp: DateTime.now()),
        prefs,
      );

      await ResponseQualityMonitor.clearAll(prefs);
      final averages = await ResponseQualityMonitor.averageByProvider(prefs);
      expect(averages, isEmpty);
    });

    test('loadScoresForProvider returns empty list before any records', () async {
      final prefs = await SharedPreferences.getInstance();
      final scores =
          ResponseQualityMonitor.loadScoresForProvider(prefs, 'claude');
      expect(scores, isEmpty);
    });

    test('sliding window keeps max 50 scores per provider', () async {
      final prefs = await SharedPreferences.getInstance();

      // Record 60 scores
      for (var i = 0; i < 60; i++) {
        await ResponseQualityMonitor.record(
          QualityScore(
              provider: 'claude',
              relevance: 0.5,
              compliance: 0.5,
              length: 0.5,
              composite: 0.5,
              timestamp: DateTime.now()),
          prefs,
        );
      }

      final stored =
          ResponseQualityMonitor.loadScoresForProvider(prefs, 'claude');
      expect(stored.length, ResponseQualityMonitor.maxScoresPerProvider);
    });
  });
}
