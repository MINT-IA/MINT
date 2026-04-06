import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';

void main() {
  group('IntentRouter', () {
    test('forChipKey returns IntentMapping for intentChip3a', () {
      final mapping = IntentRouter.forChipKey('intentChip3a');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.stressType, equals('stress_budget'));
      expect(mapping.suggestedRoute, equals('/pilier-3a'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('forChipKey returns IntentMapping for intentChipBilan', () {
      final mapping = IntentRouter.forChipKey('intentChipBilan');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.stressType, equals('stress_retraite'));
      expect(mapping.suggestedRoute, equals('/bilan-retraite'));
    });

    test('forChipKey returns IntentMapping for intentChipPrevoyance', () {
      final mapping = IntentRouter.forChipKey('intentChipPrevoyance');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.stressType, equals('stress_retraite'));
      expect(mapping.suggestedRoute, equals('/prevoyance-overview'));
    });

    test('forChipKey returns IntentMapping for intentChipFiscalite', () {
      final mapping = IntentRouter.forChipKey('intentChipFiscalite');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.stressType, equals('stress_impots'));
      expect(mapping.suggestedRoute, equals('/fiscalite-overview'));
    });

    test('forChipKey returns IntentMapping for intentChipProjet', () {
      final mapping = IntentRouter.forChipKey('intentChipProjet');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('housing_purchase'));
      expect(mapping.stressType, equals('stress_patrimoine'));
      expect(mapping.suggestedRoute, equals('/achat-immobilier'));
    });

    test('forChipKey returns IntentMapping for intentChipChangement', () {
      final mapping = IntentRouter.forChipKey('intentChipChangement');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.stressType, equals('stress_budget'));
      expect(mapping.suggestedRoute, equals('/life-events'));
    });

    test(
        'forChipKey returns IntentMapping for intentChipAutre (fallback per D-02)',
        () {
      final mapping = IntentRouter.forChipKey('intentChipAutre');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.stressType, equals('stress_retraite'));
      expect(mapping.suggestedRoute, equals('/bilan-retraite'));
    });

    test('forChipKey returns null for unknown chip key', () {
      final mapping = IntentRouter.forChipKey('nonExistentKey');
      expect(mapping, isNull);
    });

    test('all 7 chip keys return non-null IntentMapping', () {
      for (final key in IntentRouter.allChipKeys) {
        final mapping = IntentRouter.forChipKey(key);
        expect(mapping, isNotNull, reason: 'Key $key returned null');
      }
    });

    test('all 7 chip keys return non-empty suggestedRoute starting with /', () {
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

    test('allChipKeys returns exactly 9 entries', () {
      expect(IntentRouter.allChipKeys.length, equals(9));
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

    test('forChipKey returns IntentMapping for intentChipPremierEmploi', () {
      final mapping = IntentRouter.forChipKey('intentChipPremierEmploi');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('first_job'));
      expect(mapping.stressType, equals('stress_budget'));
      expect(mapping.suggestedRoute, equals('/premier-emploi'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('forChipKey returns IntentMapping for intentChipNouvelEmploi', () {
      final mapping = IntentRouter.forChipKey('intentChipNouvelEmploi');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('new_job'));
      expect(mapping.stressType, equals('stress_budget'));
      expect(mapping.suggestedRoute, equals('/rente-vs-capital'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('IntentMapping fields are non-empty strings', () {
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

    test('forChipKey is case-sensitive (mixed case returns null)', () {
      expect(IntentRouter.forChipKey('IntentChip3a'), isNull);
      expect(IntentRouter.forChipKey('INTENTCHIP3A'), isNull);
    });

    test('forChipKey returns null for empty string', () {
      expect(IntentRouter.forChipKey(''), isNull);
    });
  });
}
