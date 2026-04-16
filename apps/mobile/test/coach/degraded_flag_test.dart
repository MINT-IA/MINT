// Phase 27-01 / Task 8: parse response_meta.degraded from backend.
//
// Verifies that CoachChatApiResponse.fromJson correctly reads the new
// responseMeta { degraded, modelUsed, budgetTier } envelope added in
// backend v2.7. The subtle "Réponse rapide" chip in CoachChatScreen is
// driven by this flag.
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';

void main() {
  group('CoachChatApiResponse responseMeta', () {
    test('parses degraded=true from responseMeta', () {
      final r = CoachChatApiResponse.fromJson({
        'message': 'hello',
        'responseMeta': {
          'degraded': true,
          'modelUsed': 'claude-haiku-4-5-20251001',
          'budgetTier': 'soft_cap',
        },
      });
      expect(r.degraded, isTrue);
      expect(r.modelUsed, 'claude-haiku-4-5-20251001');
      expect(r.budgetTier, 'soft_cap');
    });

    test('defaults degraded=false when responseMeta missing', () {
      final r = CoachChatApiResponse.fromJson({
        'message': 'hello',
      });
      expect(r.degraded, isFalse);
      expect(r.modelUsed, isNull);
      expect(r.budgetTier, isNull);
    });

    test('defaults degraded=false when field missing from meta', () {
      final r = CoachChatApiResponse.fromJson({
        'message': 'hello',
        'responseMeta': {
          'modelUsed': 'claude-sonnet-4-5-20250929',
        },
      });
      expect(r.degraded, isFalse);
      expect(r.modelUsed, 'claude-sonnet-4-5-20250929');
    });

    test('hard_cap tier with degraded=true is parsed', () {
      final r = CoachChatApiResponse.fromJson({
        'message': 'On a deja bien avance aujourd\'hui.',
        'responseMeta': {
          'degraded': true,
          'budgetTier': 'hard_cap',
        },
      });
      expect(r.degraded, isTrue);
      expect(r.budgetTier, 'hard_cap');
    });
  });
}
