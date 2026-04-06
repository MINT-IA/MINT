import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/hero_stat_resolver.dart';

void main() {
  // Helper to build a minimal CoachProfile for testing.
  CoachProfile _makeProfile({
    double salaireBrutMensuel = 10184, // ~122'207 / 12
    String employmentStatus = 'salarie',
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    double nombreDeMois = 12.0,
  }) {
    return CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: salaireBrutMensuel,
      nombreDeMois: nombreDeMois,
      employmentStatus: employmentStatus,
      prevoyance: prevoyance,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 12),
        label: 'Retraite',
      ),
    );
  }

  group('HeroStatResolver', () {
    test('profile with salary and no 3a -> resolves to 3a gap hero', () {
      // Julien: 122'207 CHF/an, salarie with LPP, no 3a contribution
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
        ),
      );

      final card = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
      );

      expect(card, isA<ContextualHeroCard>());
      expect(card.priorityScore, 1.0);
      // 3a gap for salarie with LPP = 7258
      expect(card.value, contains('7'));
      expect(card.value, contains('258'));
      expect(card.route, contains('3a'));
    });

    test('profile with 3a maxed -> resolves to retirement income hero', () {
      // Profile where 3a is maxed out but LPP projection available
      final profile = _makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          projectedRenteLpp: 33892,
          totalEpargne3a: 32000,
          nombre3a: 1,
        ),
      );

      // Simulate that contribution is maxed via planned contributions
      final profileWithContribution = profile.copyWith(
        plannedContributions: [
          PlannedMonthlyContribution(
            amount: 7258 / 12,
            category: '3a',
            startDate: DateTime(2025, 1, 1),
          ),
        ],
      );

      final card = HeroStatResolver.resolve(
        profile: profileWithContribution,
        facts: [],
      );

      expect(card, isA<ContextualHeroCard>());
      expect(card.priorityScore, 1.0);
      expect(card.route, contains('retire'));
    });

    test('profile with very low completeness (<40%) -> profile completeness hero', () {
      // Minimal profile: no LPP, no 3a, no salary data
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 0,
        employmentStatus: 'salarie',
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 1, 1),
          label: 'Retraite',
        ),
      );

      final card = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
      );

      expect(card, isA<ContextualHeroCard>());
      expect(card.priorityScore, 1.0);
      expect(card.route, contains('onboarding'));
    });

    test('always returns priorityScore = 1.0 (hero always slot 1)', () {
      final profile = _makeProfile();
      final card = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
      );

      expect(card.priorityScore, 1.0);
    });

    test('independent without LPP -> 3a max is 36288', () {
      final profile = _makeProfile(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(),
      );

      final card = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
      );

      expect(card, isA<ContextualHeroCard>());
      // Independent without LPP gets higher 3a limit
      expect(card.value, contains('36'));
    });

    test('is pure static (no DateTime.now() usage)', () {
      // Verify resolve accepts injectable DateTime
      final profile = _makeProfile();
      final now = DateTime(2026, 4, 6);

      final card1 = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
        now: now,
      );
      final card2 = HeroStatResolver.resolve(
        profile: profile,
        facts: [],
        now: now,
      );

      // Same inputs -> same output
      expect(card1.value, card2.value);
      expect(card1.label, card2.label);
    });
  });
}
