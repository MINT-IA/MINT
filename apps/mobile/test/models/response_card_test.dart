// Plan 08a-01: round-trip tests for the new ResponseCard.confidence field.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

ResponseCard _baseCard({EnhancedConfidence? confidence}) {
  return ResponseCard(
    id: 'rc-1',
    type: ResponseCardType.lppBuyback,
    title: 'Rachat LPP',
    subtitle: 'Économie fiscale estimée',
    premierEclairage: const PremierEclairage(
      value: 12450,
      unit: 'CHF',
      explanation: 'Économie fiscale estimée',
    ),
    cta: const CardCta(label: 'Simuler un rachat', route: '/rachat-lpp'),
    urgency: CardUrgency.medium,
    disclaimer: 'Outil éducatif — ne constitue pas un conseil (LSFin).',
    sources: const ['LPP art. 14'],
    impactPoints: 10,
    category: 'prevoyance',
    impactChf: 12450,
    confidence: confidence,
  );
}

EnhancedConfidence _sampleConfidence() {
  return const EnhancedConfidence(
    completeness: 80,
    accuracy: 90,
    freshness: 70,
    understanding: 60,
    combined: 74,
    level: 'high',
    baseResult: ProjectionConfidence(
      score: 74,
      level: 'high',
      prompts: [],
      assumptions: [],
    ),
  );
}

void main() {
  group('ResponseCard.confidence (Plan 08a-01)', () {
    test('defaults to null and toJson omits the key', () {
      final card = _baseCard();
      expect(card.confidence, isNull);
      expect(card.toJson().containsKey('confidence'), isFalse);
    });

    test('toJson emits the locked D-05 wire shape when present', () {
      final card = _baseCard(confidence: _sampleConfidence());
      final json = card.toJson();
      expect(json['confidence'], isA<Map<String, dynamic>>());
      final conf = json['confidence'] as Map<String, dynamic>;
      expect(conf.keys.toSet(), {
        'completeness',
        'accuracy',
        'freshness',
        'understanding',
        'score',
      });
      expect(conf['completeness'], closeTo(0.80, 1e-9));
      expect(conf['accuracy'], closeTo(0.90, 1e-9));
      expect(conf['freshness'], closeTo(0.70, 1e-9));
      expect(conf['understanding'], closeTo(0.60, 1e-9));
      expect(conf['score'], closeTo(0.74, 1e-9));
    });

    test('fromJson tolerates a missing confidence key', () {
      final card = _baseCard();
      final json = card.toJson();
      final rebuilt = ResponseCard.fromJson(json);
      expect(rebuilt.confidence, isNull);
    });

    test('fromJson tolerates an explicit null confidence', () {
      final card = _baseCard();
      final json = card.toJson();
      json['confidence'] = null;
      final rebuilt = ResponseCard.fromJson(json);
      expect(rebuilt.confidence, isNull);
    });

    test('round-trip preserves all 4 axes + score', () {
      final card = _baseCard(confidence: _sampleConfidence());
      final json = card.toJson();
      final rebuilt = ResponseCard.fromJson(json);
      expect(rebuilt.confidence, isNotNull);
      expect(rebuilt.confidence!.completeness, closeTo(80, 1e-9));
      expect(rebuilt.confidence!.accuracy, closeTo(90, 1e-9));
      expect(rebuilt.confidence!.freshness, closeTo(70, 1e-9));
      expect(rebuilt.confidence!.understanding, closeTo(60, 1e-9));
      expect(rebuilt.confidence!.combined, closeTo(74, 1e-9));
      // Re-serialize is byte-stable.
      expect(rebuilt.toJson()['confidence'], json['confidence']);
    });

    test('decodes a backend-style payload (axes already in [0,1])', () {
      final payload = <String, dynamic>{
        'id': 'rc-2',
        'type': 'pillar3a',
        'title': 'Versement 3a',
        'subtitle': 'Avant le 31.12',
        'premierEclairage': {
          'value': 7258.0,
          'unit': 'CHF',
          'explanation': 'Plafond annuel salarié LPP',
        },
        'cta': {'label': 'Planifier', 'route': '/3a/versement'},
        'urgency': 'high',
        'disclaimer': 'Outil éducatif — ne constitue pas un conseil (LSFin).',
        'sources': ['OPP3 art. 7'],
        'alertes': [],
        'impactPoints': 5,
        'category': 'fiscalite',
        'impactChf': 1800.0,
        'confidence': {
          'completeness': 0.5,
          'accuracy': 0.6,
          'freshness': 0.7,
          'understanding': 0.4,
          'score': 0.55,
        },
      };
      final card = ResponseCard.fromJson(payload);
      expect(card.confidence, isNotNull);
      expect(card.confidence!.completeness, closeTo(50, 1e-9));
      expect(card.confidence!.understanding, closeTo(40, 1e-9));
      expect(card.confidence!.combined, closeTo(55, 1e-9));
      // Re-serialize matches the backend wire shape.
      expect(card.toJson()['confidence'], payload['confidence']);
    });
  });
}
