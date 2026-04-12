import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/gamification/milestone_v2_service.dart';

// ═══════════════════════════════════════════════════════════════
//  MILESTONE V2 SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//  1.  evaluate() returns exactly 20 milestones
//  2.  All 20 milestone ids are unique
//  3.  New user (all zeros) → only no milestone unlocked
//  4.  1 action → Premier pas unlocked
//  5.  4-week streak → Flamme vive unlocked (but not Flamme éternelle)
//  6.  2-week streak → Flamme naissante unlocked
//  7.  12-week streak → Flamme éternelle unlocked
//  8.  5 insights → Curieux unlocked
//  9.  50 insights → Expert unlocked (Curieux + Éclairé too)
// 10.  confidence >= 70 → Profil de confiance unlocked
// 11.  6 completed challenges → milestoneConsistencyChallenges unlocked
// 12.  20 actions → Maître de son destin unlocked
// 13.  90 days active → Citoyen MINT unlocked
// 14.  unlocked() returns only unlocked milestones
// 15.  forCategory() filters by category correctly
// 16.  Milestone categories cover all 4 types
// 17.  totalCount returns 20
// 18.  All milestones have non-empty titleKey and descriptionKey
// 19.  No duplicate milestone ids across the 20 milestones
// 20.  COMPLIANCE: no ranking/comparison terms in milestone keys
// ═══════════════════════════════════════════════════════════════

/// Minimal CoachProfile for testing.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite',
    ),
  );
}

/// Evaluate with all-zero metrics (new user).
List<Milestone> _newUserMilestones() {
  return MilestoneV2Service.evaluate(
    profile: _minimalProfile(),
    completedChallenges: 0,
    streakWeeks: 0,
    insightCount: 0,
    confidenceScore: 0.0,
    actionCount: 0,
    daysActive: 0,
  );
}

void main() {
  // ── Total count & structure ──────────────────────────────────

  group('MilestoneV2Service — structure', () {
    test('evaluate() returns exactly 20 milestones', () {
      final milestones = _newUserMilestones();
      expect(milestones.length, 20);
    });

    test('totalCount returns 20', () {
      expect(MilestoneV2Service.totalCount, 20);
    });

    test('all 20 milestone ids are unique', () {
      final milestones = _newUserMilestones();
      final ids = milestones.map((m) => m.id).toSet();
      expect(ids.length, 20, reason: 'Every milestone must have a unique id');
    });

    test('all milestones have non-empty titleKey', () {
      final milestones = _newUserMilestones();
      for (final m in milestones) {
        expect(
          m.titleKey,
          isNotEmpty,
          reason: 'Milestone ${m.id} must have a titleKey',
        );
      }
    });

    test('all milestones have non-empty descriptionKey', () {
      final milestones = _newUserMilestones();
      for (final m in milestones) {
        expect(
          m.descriptionKey,
          isNotEmpty,
          reason: 'Milestone ${m.id} must have a descriptionKey',
        );
      }
    });

    test('all 4 MilestoneCategory types are present', () {
      final milestones = _newUserMilestones();
      final categories = milestones.map((m) => m.category).toSet();
      expect(categories, contains(MilestoneCategory.engagement));
      expect(categories, contains(MilestoneCategory.knowledge));
      expect(categories, contains(MilestoneCategory.action));
      expect(categories, contains(MilestoneCategory.consistency));
    });
  });

  // ── New user state ────────────────────────────────────────────

  group('MilestoneV2Service — new user (all zeros)', () {
    test('new user has no milestones unlocked', () {
      final milestones = _newUserMilestones();
      final unlockedCount = milestones.where((m) => m.unlocked).length;
      expect(unlockedCount, 0);
    });
  });

  // ── Engagement milestones ─────────────────────────────────────

  group('MilestoneV2Service — engagement milestones', () {
    test('7 days active → Première semaine unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        daysActive: 7,
      );
      final firstWeek = milestones.firstWhere(
        (m) => m.id == 'engagement_first_week',
      );
      expect(firstWeek.unlocked, isTrue);
    });

    test('30 days active → Un mois fidèle unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        daysActive: 30,
      );
      final oneMonth = milestones.firstWhere(
        (m) => m.id == 'engagement_one_month',
      );
      expect(oneMonth.unlocked, isTrue);
    });

    test('90 days active → Citoyen MINT unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        daysActive: 90,
      );
      final citoyen = milestones.firstWhere(
        (m) => m.id == 'engagement_citoyen_mint',
      );
      expect(citoyen.unlocked, isTrue);
    });

    test('6 days active → Première semaine NOT yet unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        daysActive: 6,
      );
      final firstWeek = milestones.firstWhere(
        (m) => m.id == 'engagement_first_week',
      );
      expect(firstWeek.unlocked, isFalse);
    });
  });

  // ── Knowledge milestones ──────────────────────────────────────

  group('MilestoneV2Service — knowledge milestones', () {
    test('5 insights → Curieux unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 5,
        confidenceScore: 0,
      );
      final curieux = milestones.firstWhere(
        (m) => m.id == 'knowledge_curieux',
      );
      expect(curieux.unlocked, isTrue);
    });

    test('50 insights → Expert unlocked (and Curieux + Éclairé)', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 50,
        confidenceScore: 0,
      );
      final curieux = milestones.firstWhere((m) => m.id == 'knowledge_curieux');
      final eclaire = milestones.firstWhere(
        (m) => m.id == 'knowledge_eclaire',
      );
      final expert = milestones.firstWhere((m) => m.id == 'knowledge_expert');

      expect(curieux.unlocked, isTrue);
      expect(eclaire.unlocked, isTrue);
      expect(expert.unlocked, isTrue);
    });

    test('4 insights → Curieux NOT yet unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 4,
        confidenceScore: 0,
      );
      final curieux = milestones.firstWhere(
        (m) => m.id == 'knowledge_curieux',
      );
      expect(curieux.unlocked, isFalse);
    });

    test('seuilExpert public getter returns 50', () {
      expect(MilestoneV2Service.seuilExpert, 50);
    });
  });

  // ── Action milestones ─────────────────────────────────────────

  group('MilestoneV2Service — action milestones', () {
    test('1 action → Premier pas unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        actionCount: 1,
      );
      final premierPas = milestones.firstWhere(
        (m) => m.id == 'action_premier_pas',
      );
      expect(premierPas.unlocked, isTrue);
    });

    test('5 actions → Acteur unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        actionCount: 5,
      );
      final acteur = milestones.firstWhere((m) => m.id == 'action_acteur');
      expect(acteur.unlocked, isTrue);
    });

    test('20 actions → Maître de son destin unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        actionCount: 20,
      );
      final maitre = milestones.firstWhere(
        (m) => m.id == 'action_maitre_destin',
      );
      expect(maitre.unlocked, isTrue);
    });

    test('0 actions → Premier pas NOT unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
        actionCount: 0,
      );
      final premierPas = milestones.firstWhere(
        (m) => m.id == 'action_premier_pas',
      );
      expect(premierPas.unlocked, isFalse);
    });
  });

  // ── Consistency milestones ────────────────────────────────────

  group('MilestoneV2Service — consistency milestones', () {
    test('2-week streak → Flamme naissante unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 2,
        insightCount: 0,
        confidenceScore: 0,
      );
      final flamme = milestones.firstWhere(
        (m) => m.id == 'consistency_flamme_naissante',
      );
      expect(flamme.unlocked, isTrue);
    });

    test('4-week streak → Flamme vive unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 4,
        insightCount: 0,
        confidenceScore: 0,
      );
      final flammeVive = milestones.firstWhere(
        (m) => m.id == 'consistency_flamme_vive',
      );
      expect(flammeVive.unlocked, isTrue);
    });

    test('4-week streak → Flamme éternelle NOT unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 4,
        insightCount: 0,
        confidenceScore: 0,
      );
      final flammeEternelle = milestones.firstWhere(
        (m) => m.id == 'consistency_flamme_eternelle',
      );
      expect(flammeEternelle.unlocked, isFalse);
    });

    test('12-week streak → Flamme éternelle unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 12,
        insightCount: 0,
        confidenceScore: 0,
      );
      final flammeEternelle = milestones.firstWhere(
        (m) => m.id == 'consistency_flamme_eternelle',
      );
      expect(flammeEternelle.unlocked, isTrue);
    });

    test('confidence >= 70 → Profil de confiance unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 70.0,
      );
      final confiance = milestones.firstWhere(
        (m) => m.id == 'consistency_confiance',
      );
      expect(confiance.unlocked, isTrue);
    });

    test('confidence < 70 → Profil de confiance NOT unlocked', () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 69.9,
      );
      final confiance = milestones.firstWhere(
        (m) => m.id == 'consistency_confiance',
      );
      expect(confiance.unlocked, isFalse);
    });

    test('6 completed challenges → milestoneConsistencyChallenges unlocked',
        () {
      final milestones = MilestoneV2Service.evaluate(
        profile: _minimalProfile(),
        completedChallenges: 6,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
      );
      final challenges = milestones.firstWhere(
        (m) => m.id == 'consistency_challenges_accomplis',
      );
      expect(challenges.unlocked, isTrue);
    });

    test('seuilFlammeVive public getter returns 4', () {
      expect(MilestoneV2Service.seuilFlammeVive, 4);
    });

    test('seuilFlammeNaissante public getter returns 2', () {
      expect(MilestoneV2Service.seuilFlammeNaissante, 2);
    });

    test('seuilFlammeEternelle public getter returns 12', () {
      expect(MilestoneV2Service.seuilFlammeEternelle, 12);
    });
  });

  // ── Helper methods ────────────────────────────────────────────

  group('MilestoneV2Service — helper methods', () {
    test('unlocked() returns only unlocked milestones', () {
      final unlocked = MilestoneV2Service.unlocked(
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 4,
        insightCount: 5,
        confidenceScore: 0,
        actionCount: 1,
        daysActive: 7,
      );

      expect(unlocked.every((m) => m.unlocked), isTrue);
      // Should include: flamme naissante, flamme vive, curieux, premier pas,
      // premiere semaine — at minimum 5
      expect(unlocked.length, greaterThanOrEqualTo(5));
    });

    test('forCategory() returns only milestones of that category', () {
      final consistency = MilestoneV2Service.forCategory(
        category: MilestoneCategory.consistency,
        profile: _minimalProfile(),
        completedChallenges: 0,
        streakWeeks: 0,
        insightCount: 0,
        confidenceScore: 0,
      );

      expect(
        consistency.every((m) => m.category == MilestoneCategory.consistency),
        isTrue,
      );
      expect(consistency.length, greaterThan(0));
    });

    test('each category has exactly 5 milestones', () {
      for (final category in MilestoneCategory.values) {
        final categoryMilestones = MilestoneV2Service.forCategory(
          category: category,
          profile: _minimalProfile(),
          completedChallenges: 0,
          streakWeeks: 0,
          insightCount: 0,
          confidenceScore: 0,
        );
        expect(
          categoryMilestones.length,
          5,
          reason: 'Category $category should have exactly 5 milestones',
        );
      }
    });
  });

  // ── COMPLIANCE ────────────────────────────────────────────────

  group('MilestoneV2Service — COMPLIANCE', () {
    test('no milestone titleKey or descriptionKey contains banned terms', () {
      final bannedTerms = [
        'top',
        'classement',
        'rang',
        'leaderboard',
        'mieux que',
        'pire que',
        'meilleur que',
        'optimal',
        'garanti',
      ];

      final milestones = _newUserMilestones();
      for (final m in milestones) {
        for (final term in bannedTerms) {
          expect(
            m.titleKey.toLowerCase(),
            isNot(contains(term)),
            reason:
                'Milestone ${m.id} titleKey must not contain banned term "$term"',
          );
          expect(
            m.descriptionKey.toLowerCase(),
            isNot(contains(term)),
            reason:
                'Milestone ${m.id} descriptionKey must not contain banned term "$term"',
          );
        }
      }
    });
  });
}
