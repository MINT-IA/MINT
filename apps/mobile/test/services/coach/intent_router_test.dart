import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';

void main() {
  group('IntentRouter', () {
    test('forChipKey returns null for unknown chip key', () {
      expect(IntentRouter.forChipKey('nonExistentKey'), isNull);
    });

    test('forChipKey returns null for empty string', () {
      expect(IntentRouter.forChipKey(''), isNull);
    });

    test('forChipKey is case-sensitive', () {
      expect(IntentRouter.forChipKey('IntentChip3a'), isNull);
      expect(IntentRouter.forChipKey('INTENTCHIP3A'), isNull);
    });

    test('all chip keys return non-null IntentMapping', () {
      for (final key in IntentRouter.allChipKeys) {
        final mapping = IntentRouter.forChipKey(key);
        expect(mapping, isNotNull, reason: 'Key $key returned null');
      }
    });

    test('all chip keys return suggestedRoute starting with /', () {
      for (final key in IntentRouter.allChipKeys) {
        final mapping = IntentRouter.forChipKey(key)!;
        expect(
          mapping.suggestedRoute,
          isNotEmpty,
          reason: 'Key $key has empty suggestedRoute',
        );
        expect(
          mapping.suggestedRoute,
          startsWith('/'),
          reason: 'Key $key suggestedRoute does not start with /',
        );
      }
    });

    test('IntentMapping fields are all non-empty strings', () {
      for (final key in IntentRouter.allChipKeys) {
        final mapping = IntentRouter.forChipKey(key)!;
        expect(mapping.goalIntentTag, isNotEmpty,
            reason: '$key goalIntentTag is empty');
        expect(mapping.stressType, isNotEmpty,
            reason: '$key stressType is empty');
        expect(mapping.suggestedRoute, isNotEmpty,
            reason: '$key suggestedRoute is empty');
        expect(mapping.lifeEventFamily, isNotEmpty,
            reason: '$key lifeEventFamily is empty');
      }
    });

    test('allChipKeys contains all expected chip identifiers', () {
      final keys = IntentRouter.allChipKeys;
      expect(keys, contains('intentChip3a'));
      expect(keys, contains('intentChipBilan'));
      expect(keys, contains('intentChipPrevoyance'));
      expect(keys, contains('intentChipFiscalite'));
      expect(keys, contains('intentChipProjet'));
      expect(keys, contains('intentChipChangement'));
      expect(keys, contains('intentChipAutre'));
      expect(keys, contains('intentChipPremierEmploi'));
      expect(keys, contains('intentChipNouvelEmploi'));
    });
  });
}
