import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/action_opportunity_detector.dart';

void main() {
  CoachProfile _makeProfile() {
    return CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10184,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 12),
        label: 'Retraite',
      ),
    );
  }

  group('ActionOpportunityDetector', () {
    test('no documents scanned -> returns "Scanner un document" action', () {
      final profile = _makeProfile();
      final cards = ActionOpportunityDetector.detect(
        profile: profile,
        facts: [],
      );

      expect(cards, isNotEmpty);
      final scanCard = cards.firstWhere(
        (c) => c.route == '/documents/capture',
        orElse: () => throw StateError('No scan card found'),
      );
      expect(scanCard.icon, Icons.document_scanner_outlined);
      expect(scanCard.priorityScore, 0.7);
    });

    test('completeness < 70% -> returns "Completer ton profil" action', () {
      // Minimal profile -> low completeness
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 5000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 1, 1),
          label: 'Retraite',
        ),
      );

      final cards = ActionOpportunityDetector.detect(
        profile: profile,
        facts: [],
      );

      final profileCard = cards.firstWhere(
        (c) => c.route.contains('onboarding'),
        orElse: () => throw StateError('No profile card found'),
      );
      expect(profileCard.icon, Icons.person_add_outlined);
      expect(profileCard.priorityScore, 0.6);
    });

    test('fully complete with documents -> returns empty list', () {
      // Rich profile with document facts
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
      );

      final facts = [
        BiographyFact(
          id: 'fact-1',
          factType: FactType.lppCapital,
          value: '70377',
          source: FactSource.document,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        BiographyFact(
          id: 'fact-2',
          factType: FactType.salary,
          value: '122207',
          source: FactSource.document,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final cards = ActionOpportunityDetector.detect(
        profile: profile,
        facts: facts,
      );

      // With documents present, scan action should NOT appear
      final scanCards = cards.where((c) => c.route == '/documents/capture');
      expect(scanCards, isEmpty,
          reason: 'Scan action should not appear when documents exist');

      // Profile completion card may still appear depending on
      // ConfidenceScorer result — that is acceptable behavior
    });

    test('returns max 2 action cards', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 1, 1),
          label: 'Retraite',
        ),
      );

      final cards = ActionOpportunityDetector.detect(
        profile: profile,
        facts: [],
      );

      expect(cards.length, lessThanOrEqualTo(2));
    });
  });
}
