// Phase 96 D-12 — SerializedCardContext Dart mirror tests.
//
// Mirror of backend Pydantic SerializedCardContext (lands in Plan 96-02).
// 7 fields, camelCase JSON, no PII surface.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/serialized_card_context.dart';

void main() {
  group('SerializedCardContext', () {
    test('toJson/fromJson round-trips byte-equal with all fields populated',
        () {
      const fixture = SerializedCardContext(
        cardId: 'mon_3a_2026',
        cardType: 'pillar_3a',
        computedFacts: <String, dynamic>{
          'annualContribution': '7056.00',
          'projectedValueAt65': '485000.00',
        },
        groundingKeys: <String>['avs_rente_max_2026', 'lpp_taux_2026'],
        lifeEvent: 'retirement',
        canton: 'VD',
        archetype: 'swiss_native',
      );

      final json = fixture.toJson();
      final round = SerializedCardContext.fromJson(json);

      expect(round.cardId, fixture.cardId);
      expect(round.cardType, fixture.cardType);
      expect(round.computedFacts, fixture.computedFacts);
      expect(round.groundingKeys, fixture.groundingKeys);
      expect(round.lifeEvent, fixture.lifeEvent);
      expect(round.canton, fixture.canton);
      expect(round.archetype, fixture.archetype);
      expect(round.toJson(), json);
    });

    test('round-trips with optional fields absent', () {
      const fixture = SerializedCardContext(
        cardId: 'tax_marge_2026',
        cardType: 'tax_optimization',
      );

      final json = fixture.toJson();
      expect(json.containsKey('lifeEvent'), isFalse);
      expect(json.containsKey('canton'), isFalse);
      expect(json.containsKey('archetype'), isFalse);
      expect(json['computedFacts'], isEmpty);
      expect(json['groundingKeys'], isEmpty);

      final round = SerializedCardContext.fromJson(json);
      expect(round.cardId, fixture.cardId);
      expect(round.cardType, fixture.cardType);
      expect(round.lifeEvent, isNull);
      expect(round.canton, isNull);
      expect(round.archetype, isNull);
    });

    test('fromJson silently drops unknown extra fields', () {
      final round = SerializedCardContext.fromJson(<String, dynamic>{
        'cardId': 'lpp_projection',
        'cardType': 'lpp_retirement',
        'computedFacts': <String, dynamic>{},
        'groundingKeys': <String>[],
        // Unknown field — must be ignored gracefully.
        'piiSmuggling': 'attacker@example.com',
      });

      expect(round.cardId, 'lpp_projection');
      expect(round.cardType, 'lpp_retirement');
      // The unknown field is gone — no extras carrier on the Dart class.
      expect(round.toJson().containsKey('piiSmuggling'), isFalse);
    });
  });
}
