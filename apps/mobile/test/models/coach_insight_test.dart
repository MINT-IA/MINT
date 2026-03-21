import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_insight.dart';

// ────────────────────────────────────────────────────────────
//  CoachInsight MODEL TESTS — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Tests: construction, JSON roundtrip, InsightType enum,
// encodeList/decodeList, equality, sanitization edge cases.
// ────────────────────────────────────────────────────────────

void main() {
  final baseDate = DateTime(2026, 3, 18, 12, 0);

  CoachInsight makeInsight({
    String id = 'i1',
    String topic = 'lpp',
    String summary = 'Rachat LPP discuté — avoir ~70k CHF',
    InsightType type = InsightType.fact,
    Map<String, dynamic>? metadata,
  }) {
    return CoachInsight(
      id: id,
      createdAt: baseDate,
      topic: topic,
      summary: summary,
      type: type,
      metadata: metadata,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CONSTRUCTION
  // ════════════════════════════════════════════════════════════

  group('CoachInsight — construction', () {
    test('creates with required fields', () {
      final insight = makeInsight();

      expect(insight.id, equals('i1'));
      expect(insight.topic, equals('lpp'));
      expect(insight.summary, equals('Rachat LPP discuté — avoir ~70k CHF'));
      expect(insight.type, equals(InsightType.fact));
      expect(insight.createdAt, equals(baseDate));
      expect(insight.metadata, isNull);
    });

    test('creates with optional metadata', () {
      final insight = makeInsight(metadata: {'lppAmount': 70000, 'canton': 'VS'});

      expect(insight.metadata, isNotNull);
      expect(insight.metadata!['lppAmount'], equals(70000));
      expect(insight.metadata!['canton'], equals('VS'));
    });

    test('all InsightType values are distinct', () {
      const values = InsightType.values;
      expect(values.toSet().length, equals(values.length));
      expect(values, containsAll([
        InsightType.goal,
        InsightType.decision,
        InsightType.concern,
        InsightType.fact,
      ]));
    });

    test('equality based on id only', () {
      final a = makeInsight(id: 'x');
      final b = makeInsight(id: 'x', topic: 'retraite'); // different topic
      final c = makeInsight(id: 'y');

      expect(a, equals(b)); // same id
      expect(a, isNot(equals(c))); // different id
    });

    test('toString contains id and topic', () {
      final insight = makeInsight(id: 'abc', topic: 'housing');
      final s = insight.toString();
      expect(s, contains('abc'));
      expect(s, contains('housing'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  JSON SERIALIZATION
  // ════════════════════════════════════════════════════════════

  group('CoachInsight — JSON roundtrip', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final original = CoachInsight(
        id: 'rt1',
        createdAt: DateTime(2026, 1, 15, 9, 30),
        topic: '3a',
        summary: 'Décidé de maximiser le 3a chaque année',
        type: InsightType.decision,
        metadata: {'amount': 7258, 'year': 2026},
      );

      final json = original.toJson();
      final restored = CoachInsight.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.topic, equals(original.topic));
      expect(restored.summary, equals(original.summary));
      expect(restored.type, equals(original.type));
      expect(restored.metadata, equals(original.metadata));
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'min1',
        'createdAt': '2026-03-18T00:00:00.000',
        'summary': 'Un fait simple',
      };

      final insight = CoachInsight.fromJson(json);

      expect(insight.id, equals('min1'));
      expect(insight.topic, equals('general')); // default
      expect(insight.type, equals(InsightType.fact)); // default
      expect(insight.metadata, isNull);
    });

    test('fromJson handles unknown InsightType gracefully', () {
      final json = {
        'id': 'unk1',
        'createdAt': '2026-03-18T00:00:00.000',
        'summary': 'Insight',
        'type': 'unknown_future_type',
      };

      final insight = CoachInsight.fromJson(json);
      expect(insight.type, equals(InsightType.fact)); // fallback
    });

    test('null metadata is not included in toJson output', () {
      final insight = makeInsight(metadata: null);
      final json = insight.toJson();
      expect(json.containsKey('metadata'), isFalse);
    });

    test('insight without metadata roundtrips cleanly', () {
      final original = makeInsight(
        id: 'no-meta',
        type: InsightType.concern,
        summary: "S'inquiète de l'inflation sur la rente",
      );

      final restored = CoachInsight.fromJson(original.toJson());
      expect(restored.metadata, isNull);
      expect(restored.type, equals(InsightType.concern));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  encodeList / decodeList
  // ════════════════════════════════════════════════════════════

  group('CoachInsight — encodeList / decodeList', () {
    test('empty list encodes and decodes to empty list', () {
      final encoded = CoachInsight.encodeList([]);
      final decoded = CoachInsight.decodeList(encoded);
      expect(decoded, isEmpty);
    });

    test('list of insights roundtrips via encode/decode', () {
      final insights = [
        makeInsight(id: 'a', topic: 'lpp', type: InsightType.fact),
        makeInsight(id: 'b', topic: '3a', type: InsightType.goal),
        makeInsight(id: 'c', topic: 'retraite', type: InsightType.decision),
      ];

      final encoded = CoachInsight.encodeList(insights);
      final decoded = CoachInsight.decodeList(encoded);

      expect(decoded.length, equals(3));
      expect(decoded[0].id, equals('a'));
      expect(decoded[1].id, equals('b'));
      expect(decoded[2].id, equals('c'));
      expect(decoded[1].type, equals(InsightType.goal));
    });

    test('decodeList returns empty list on invalid JSON', () {
      final decoded = CoachInsight.decodeList('not valid json {{{');
      expect(decoded, isEmpty);
    });

    test('decodeList returns empty list on empty string', () {
      final decoded = CoachInsight.decodeList('');
      expect(decoded, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  copyWith
  // ════════════════════════════════════════════════════════════

  group('CoachInsight — copyWith', () {
    test('copyWith preserves unchanged fields', () {
      final original = makeInsight(id: 'cw1', topic: 'lpp');
      final copy = original.copyWith(topic: 'retraite');

      expect(copy.id, equals('cw1')); // unchanged
      expect(copy.createdAt, equals(original.createdAt)); // unchanged
      expect(copy.topic, equals('retraite')); // changed
      expect(copy.summary, equals(original.summary)); // unchanged
    });

    test('copyWith with metadata replaces metadata', () {
      final original = makeInsight(metadata: {'old': true});
      final copy = original.copyWith(metadata: {'new': 42});

      expect(copy.metadata!['new'], equals(42));
      expect(copy.metadata!.containsKey('old'), isFalse);
    });
  });
}
