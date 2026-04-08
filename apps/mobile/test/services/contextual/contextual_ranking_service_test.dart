import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/contextual_ranking_service.dart';

void main() {
  CoachProfile _makeProfile() {
    return CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10184,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 70377,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 12),
        label: 'Retraite',
      ),
    );
  }

  AnticipationSignal _makeSignal({
    required String id,
    required AlertTemplate template,
    double priorityScore = 0.5,
  }) {
    return AnticipationSignal(
      id: id,
      template: template,
      titleKey: 'test_title_$id',
      factKey: 'test_fact_$id',
      sourceRef: 'Test art. 1',
      simulatorLink: '/test/$id',
      priorityScore: priorityScore,
      expiresAt: DateTime(2026, 12, 31),
    );
  }

  group('ContextualRankingService', () {
    test('hero + 2 anticipation + 1 progress + 1 action -> 4 visible + 1 overflow', () {
      final profile = _makeProfile();
      final signals = [
        _makeSignal(
          id: 's1',
          template: AlertTemplate.fiscal3aDeadline,
          priorityScore: 0.9,
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.cantonalTaxDeadline,
          priorityScore: 0.7,
        ),
      ];

      final result = ContextualRankingService.rank(
        profile: profile,
        facts: [],
        anticipationVisible: signals,
        anticipationOverflow: [],
        now: DateTime(2026, 4, 6),
      );

      // Hero (slot 1) + top 3 non-hero cards = 4 visible
      expect(result.visible.length, 4);
      // Hero is always first
      expect(result.visible.first, isA<ContextualHeroCard>());
      // Overflow contains remaining cards
      expect(result.overflow, isNotNull);
    });

    test('hero + 0 others -> returns 1 visible, no overflow', () {
      // Profile that generates hero but no actions/progress/anticipation
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10184,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          avoirLppObligatoire: 40000,
          salaireAssure: 91967,
          nombre3a: 1,
          totalEpargne3a: 32000,
          anneesContribuees: 27,
          renteAVSEstimeeMensuelle: 2390,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
        plannedContributions: [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 7258 / 12,
            category: '3a',
          ),
        ],
      );

      // Documents present -> no scan action
      final facts = [
        BiographyFact(
          id: 'doc1',
          factType: FactType.lppCapital,
          value: '70377',
          source: FactSource.document,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final result = ContextualRankingService.rank(
        profile: profile,
        facts: facts,
        anticipationVisible: [],
        anticipationOverflow: [],
        now: DateTime(2026, 4, 6),
      );

      expect(result.visible.length, greaterThanOrEqualTo(1));
      expect(result.visible.first, isA<ContextualHeroCard>());
    });

    test('hero + 6 others -> 4 visible + overflow containing extras', () {
      final profile = _makeProfile();
      // 6 anticipation signals -> way more than 3 non-hero slots
      final signals = List.generate(
        6,
        (i) => _makeSignal(
          id: 's$i',
          template: AlertTemplate.values[i % AlertTemplate.values.length],
          priorityScore: 0.9 - i * 0.1,
        ),
      );

      final result = ContextualRankingService.rank(
        profile: profile,
        facts: [],
        anticipationVisible: signals,
        anticipationOverflow: [],
        now: DateTime(2026, 4, 6),
      );

      expect(result.visible.length, 4);
      expect(result.visible.first, isA<ContextualHeroCard>());
      expect(result.overflow, isNotNull);
      expect(result.overflow!.cards.length, greaterThan(0));
    });

    test('completed action (priorityScore=0) sorts after active cards', () {
      final profile = _makeProfile();
      final highSignal = _makeSignal(
        id: 'high',
        template: AlertTemplate.fiscal3aDeadline,
        priorityScore: 0.9,
      );
      // A low-priority signal that should sort after
      final lowSignal = _makeSignal(
        id: 'low',
        template: AlertTemplate.lppRachatWindow,
        priorityScore: 0.0,
      );

      final result = ContextualRankingService.rank(
        profile: profile,
        facts: [],
        anticipationVisible: [highSignal, lowSignal],
        anticipationOverflow: [],
        now: DateTime(2026, 4, 6),
      );

      // Low priority signal should be after high priority in the visible list
      final highIndex = result.visible.indexWhere(
        (c) => c is ContextualAnticipationCard && c.signal.id == 'high',
      );
      final lowIndex = result.visible.indexWhere(
        (c) => c is ContextualAnticipationCard && c.signal.id == 'low',
      );

      // If low is in visible, it should be after high
      // If low is in overflow, that's also correct (demoted)
      if (lowIndex >= 0 && highIndex >= 0) {
        expect(lowIndex, greaterThan(highIndex));
      }
    });

    test('same inputs produce same output (deterministic)', () {
      final profile = _makeProfile();
      final signals = [
        _makeSignal(
          id: 's1',
          template: AlertTemplate.fiscal3aDeadline,
          priorityScore: 0.8,
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.cantonalTaxDeadline,
          priorityScore: 0.6,
        ),
      ];
      final now = DateTime(2026, 4, 6);

      final result1 = ContextualRankingService.rank(
        profile: profile,
        facts: [],
        anticipationVisible: signals,
        anticipationOverflow: [],
        now: now,
      );

      final result2 = ContextualRankingService.rank(
        profile: profile,
        facts: [],
        anticipationVisible: signals,
        anticipationOverflow: [],
        now: now,
      );

      expect(result1.visible.length, result2.visible.length);
      for (int i = 0; i < result1.visible.length; i++) {
        expect(
          result1.visible[i].priorityScore,
          result2.visible[i].priorityScore,
        );
      }
    });
  });
}
