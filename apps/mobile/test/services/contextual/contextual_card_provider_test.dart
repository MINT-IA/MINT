import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

void main() {
  group('ContextualCardProvider', () {
    late ContextualCardProvider provider;
    final now = DateTime(2026, 4, 6);

    setUp(() {
      provider = ContextualCardProvider();
    });

    CoachProfile _makeProfile({
      double salaireBrutMensuel = 10000,
    }) {
      return CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: salaireBrutMensuel,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );
    }

    test('evaluateOnSessionStart called twice -> second call is no-op',
        () async {
      final profile = _makeProfile();

      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      expect(provider.evaluated, isTrue);
      final firstCards = List.of(provider.visibleCards);
      final firstOpener = provider.coachOpener;

      // Second call should be a no-op
      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      expect(provider.visibleCards.length, equals(firstCards.length));
      expect(provider.coachOpener, equals(firstOpener));
    });

    test('provider exposes visibleCards from ranking result', () async {
      final profile = _makeProfile();

      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      // Should always have at least a hero card
      expect(provider.visibleCards, isNotEmpty);
      expect(provider.visibleCards.first, isA<ContextualHeroCard>());
    });

    test('provider exposes coachOpener string', () async {
      final profile = _makeProfile();

      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      expect(provider.coachOpener, isNotEmpty);
    });

    test('resetSession allows re-evaluation', () async {
      final profile = _makeProfile();

      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      expect(provider.evaluated, isTrue);

      provider.resetSession();

      expect(provider.evaluated, isFalse);

      // Can evaluate again
      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      expect(provider.evaluated, isTrue);
    });

    test('overflowCard getter works', () async {
      final profile = _makeProfile();

      await provider.evaluateOnSessionStart(
        profile: profile,
        facts: [],
        anticipationVisible: [],
        anticipationOverflow: [],
        now: now,
      );

      final overflow = provider.overflowCard;
      expect(overflow == null || overflow is ContextualOverflowCard, isTrue);
    });
  });
}
