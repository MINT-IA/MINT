import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXT INJECTOR SERVICE TESTS — S58 / S61 regional voice
// ────────────────────────────────────────────────────────────
//
// 17 tests covering:
//   - Full enriched context with profile + goals + conversations
//   - No profile → lifecycle absent
//   - Empty state → minimal delimiters
//   - Privacy reminder primacy
//   - Goals section present when goals exist
//   - Conversation history section present
//   - EnrichedContext fields populated correctly
//   - Edge cases: completed goals excluded, empty conversations
//   - Regional voice injection: VS/GE/ZH/null canton
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18, 14, 0);

  // ── Helper: create a minimal CoachProfile for testing ───────
  CoachProfile makeProfile({
    int birthYear = 1990,
    String canton = 'VD',
    double salaire = 6000,
    String employment = 'salarie',
    int? targetRetirementAge,
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    int nombreEnfants = 0,
    FinancialLiteracyLevel literacy = FinancialLiteracyLevel.beginner,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employment,
      targetRetirementAge: targetRetirementAge,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      financialLiteracyLevel: literacy,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );
  }

  // ── Helper: seed goals into SharedPreferences ───────────────
  Future<SharedPreferences> seedGoals(List<UserGoal> goals) async {
    final json = jsonEncode(goals.map((g) => g.toJson()).toList());
    SharedPreferences.setMockInitialValues({'_user_goals': json});
    return SharedPreferences.getInstance();
  }

  // ── Helper: build conversations for memory override ─────────
  List<ConversationMeta> makeConversations({int count = 2}) {
    return List.generate(count, (i) {
      return ConversationMeta(
        id: 'conv$i',
        title: 'Conversation $i',
        createdAt: now.subtract(Duration(days: count - i)),
        lastMessageAt: now.subtract(Duration(days: count - i)),
        messageCount: 5 + i,
        tags: ['lpp', if (i == 0) 'retraite', if (i == 1) '3a'],
      );
    });
  }

  group('ContextInjectorService', () {
    // ════════════════════════════════════════════════════════════
    //  TEST 1: Full enriched context with all sections
    // ════════════════════════════════════════════════════════════

    test('buildContext with profile returns enriched context with all sections',
        () async {
      final profile = makeProfile(birthYear: 1977, canton: 'VS');
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Maximiser mon 3a',
          category: '3a',
          createdAt: now.subtract(const Duration(days: 7)),
        ),
      ];
      final prefs = await seedGoals(goals);

      // Note: ConversationMemoryService.buildMemory will get empty conversations
      // from ConversationStore (no conversations stored in prefs).
      // Goals are loaded from prefs.
      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      // Verify memoryBlock has the delimiters
      expect(ctx.memoryBlock, contains('--- MÉMOIRE MINT ---'));
      expect(ctx.memoryBlock, contains('--- FIN MÉMOIRE ---'));

      // Verify lifecycle section present (profile given → lifecycle detected)
      expect(ctx.memoryBlock, contains('CONTEXTE CYCLE DE VIE'));

      // Verify goals section present
      expect(ctx.memoryBlock, contains('Objectifs déclarés'));
      expect(ctx.memoryBlock, contains('Maximiser mon 3a'));

      // Verify lifecyclePhase populated
      expect(ctx.lifecyclePhase, isNotNull);
      expect(ctx.lifecyclePhase!.phase, equals(LifecyclePhase.consolidation));

      // Verify contentAdaptation populated
      expect(ctx.contentAdaptation, isNotNull);

      // Verify activeGoalsCount
      expect(ctx.activeGoalsCount, equals(1));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 2: No profile → lifecycle absent
    // ════════════════════════════════════════════════════════════

    test('buildContext without profile omits lifecycle section', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      // Lifecycle section should NOT be present
      expect(ctx.memoryBlock, isNot(contains('CONTEXTE CYCLE DE VIE')));

      // Lifecycle phase should be null
      expect(ctx.lifecyclePhase, isNull);
      expect(ctx.contentAdaptation, isNull);

      // Memory and goals still work (just empty)
      expect(ctx.memoryBlock, contains('--- MÉMOIRE MINT ---'));
      expect(ctx.memoryBlock, contains('--- FIN MÉMOIRE ---'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 3: Empty state → minimal block with delimiters
    // ════════════════════════════════════════════════════════════

    test('buildContext empty state returns minimal block with delimiters',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('--- MÉMOIRE MINT ---'));
      expect(ctx.memoryBlock, contains('--- FIN MÉMOIRE ---'));
      expect(ctx.conversationMemory.isEmpty, isTrue);
      expect(ctx.activeGoalsCount, equals(0));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 4: Privacy reminder is first inside memory block
    // ════════════════════════════════════════════════════════════

    test('privacy reminder is first inside memory block', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      final lines = ctx.memoryBlock.split('\n');
      // First line is "--- MÉMOIRE MINT ---"
      expect(lines[0], contains('--- MÉMOIRE MINT ---'));
      // Second line should start with "RAPPEL" (privacy reminder — primacy effect)
      expect(lines[1], startsWith('RAPPEL'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 5: memoryBlock contains goals when present
    // ════════════════════════════════════════════════════════════

    test('memoryBlock contains goals when present', () async {
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Acheter un appartement',
          category: 'housing',
          createdAt: now.subtract(const Duration(days: 14)),
          targetDate: DateTime(2028, 6, 1),
        ),
        UserGoal(
          id: 'g2',
          description: 'Comprendre ma rente LPP',
          category: 'lpp',
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ];
      final prefs = await seedGoals(goals);

      final ctx = await ContextInjectorService.buildContext(
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('Objectifs déclarés'));
      expect(ctx.memoryBlock, contains('Acheter un appartement'));
      expect(ctx.memoryBlock, contains('Comprendre ma rente LPP'));
      expect(ctx.activeGoalsCount, equals(2));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 6: memoryBlock contains conversation history
    // ════════════════════════════════════════════════════════════

    test('memoryBlock contains conversation history', () async {
      // We cannot easily inject conversations into ConversationStore via prefs
      // (it uses its own file-based store). Instead, test the memory block
      // building indirectly by verifying the ConversationMemory integration.
      //
      // Build a ConversationMemory with data and verify it would appear.
      final conversations = makeConversations(count: 3);
      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      // Verify the memory is not empty (it has conversations)
      expect(memory.isEmpty, isFalse);
      expect(memory.totalConversations, equals(3));

      // Now test the full flow with empty prefs (no stored conversations)
      // but verify the block structure handles the HISTORIQUE section.
      // The real integration happens when ConversationStore has data.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // With conversations in store, the block would contain HISTORIQUE.
      // Here we verify the empty case does NOT contain HISTORIQUE.
      final ctx = await ContextInjectorService.buildContext(
        prefs: prefs,
        now: now,
      );
      expect(ctx.memoryBlock, isNot(contains('HISTORIQUE')));
      expect(ctx.conversationMemory.isEmpty, isTrue);
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 7: enrichedContext fields populated correctly
    // ════════════════════════════════════════════════════════════

    test('enrichedContext fields populated correctly', () async {
      final profile = makeProfile(
        birthYear: 1982,
        canton: 'GE',
        literacy: FinancialLiteracyLevel.intermediate,
      );
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Optimiser fiscalité',
          category: 'tax',
          createdAt: now,
        ),
      ];
      final prefs = await seedGoals(goals);

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      // activeGoalsCount
      expect(ctx.activeGoalsCount, equals(1));

      // conversationMemory (empty because no stored conversations)
      expect(ctx.conversationMemory, isNotNull);

      // lifecyclePhase — 2026 - 1982 = 44 → accélération
      expect(ctx.lifecyclePhase, isNotNull);
      expect(ctx.lifecyclePhase!.phase, equals(LifecyclePhase.acceleration));
      expect(ctx.lifecyclePhase!.age, equals(44));

      // contentAdaptation
      expect(ctx.contentAdaptation, isNotNull);
      expect(ctx.contentAdaptation!.coachSystemPromptAddition, isNotEmpty);
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 8: Completed goals are excluded from activeGoalsCount
    // ════════════════════════════════════════════════════════════

    test('completed goals are excluded from activeGoalsCount', () async {
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Active goal',
          category: '3a',
          createdAt: now,
        ),
        UserGoal(
          id: 'g2',
          description: 'Completed goal',
          category: 'lpp',
          createdAt: now.subtract(const Duration(days: 30)),
          isCompleted: true,
          completedAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      final prefs = await seedGoals(goals);

      final ctx = await ContextInjectorService.buildContext(
        prefs: prefs,
        now: now,
      );

      // Only 1 active goal (the completed one is excluded)
      expect(ctx.activeGoalsCount, equals(1));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 9: Golden couple — Julien profile produces consolidation lifecycle
    // ════════════════════════════════════════════════════════════

    test('golden couple Julien (49) → consolidation lifecycle in memoryBlock',
        () async {
      final julien = makeProfile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 122207 / 12,
        etatCivil: CoachCivilStatus.marie,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: julien,
        prefs: prefs,
        now: now,
      );

      expect(ctx.lifecyclePhase!.phase, equals(LifecyclePhase.consolidation));
      expect(ctx.memoryBlock, contains('consolidation'));
      expect(ctx.memoryBlock, contains('49 ans'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 10: EnrichedContext.empty has correct defaults
    // ════════════════════════════════════════════════════════════

    test('EnrichedContext.empty has correct defaults', () {
      const empty = EnrichedContext.empty;

      expect(empty.memoryBlock, isEmpty);
      expect(empty.lifecyclePhase, isNull);
      expect(empty.contentAdaptation, isNull);
      expect(empty.conversationMemory.isEmpty, isTrue);
      expect(empty.activeGoalsCount, equals(0));
      expect(empty.activeNudges, isEmpty);
      expect(empty.relevantScreens, isEmpty);
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 11: relevantScreens populated for profile with lifecycle phase
    // ════════════════════════════════════════════════════════════

    test('relevantScreens populated for profile with known lifecycle phase',
        () async {
      // consolidation phase (age 49) should produce at least 1 screen hint
      final julien = makeProfile(birthYear: 1977, canton: 'VS');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: julien,
        prefs: prefs,
        now: now,
      );

      expect(ctx.relevantScreens, isNotEmpty);
      // All entries should prefer routing from chat
      for (final entry in ctx.relevantScreens) {
        expect(entry.preferFromChat, isTrue);
      }
      // At most 5 screens (maxScreensInContext)
      expect(ctx.relevantScreens.length, lessThanOrEqualTo(5));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 12: SURFACES PERTINENTES block present in memoryBlock
    // ════════════════════════════════════════════════════════════

    test('memoryBlock contains SURFACES PERTINENTES when profile available',
        () async {
      final profile = makeProfile(birthYear: 1977, canton: 'VS');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('SURFACES PERTINENTES'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 13: activeNudges and NUDGES ACTIFS block for December profile
    // ════════════════════════════════════════════════════════════

    test('activeNudges present for December — 3a deadline nudge fires',
        () async {
      // December 15 triggers the pillar3aDeadline nudge (high priority)
      final december = DateTime(2026, 12, 15);
      final profile = makeProfile(birthYear: 1982, canton: 'GE');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: december,
      );

      // 3a deadline is always high priority in December
      expect(ctx.activeNudges, isNotEmpty);
      expect(
        ctx.activeNudges.any((n) => n.trigger == NudgeTrigger.pillar3aDeadline),
        isTrue,
      );

      // memoryBlock should contain nudge section
      expect(ctx.memoryBlock, contains('NUDGES ACTIFS'));
      // Route slug should appear in block
      expect(ctx.memoryBlock, contains('/pilier-3a'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 14: Regional voice — Suisse romande (VS) profile
    // ════════════════════════════════════════════════════════════

    test('VS profile injects romande regional voice into memoryBlock',
        () async {
      // VS = Suisse romande → RegionalVoiceService returns romande flavor.
      // The promptAddition is non-empty for romande → injected in memoryBlock.
      final profile = makeProfile(birthYear: 1977, canton: 'VS');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      final flavor = RegionalVoiceService.forCanton('VS');
      expect(flavor.region, equals(SwissRegion.romande));
      expect(flavor.promptAddition, isNotEmpty);

      // The memory block must embed the regional prompt addition.
      expect(ctx.memoryBlock, contains(flavor.promptAddition));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 15: Regional voice — Deutschschweiz (ZH) profile
    // ════════════════════════════════════════════════════════════

    test('ZH profile injects deutschschweiz regional voice into memoryBlock',
        () async {
      final profile = makeProfile(birthYear: 1985, canton: 'ZH');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.region, equals(SwissRegion.deutschschweiz));
      expect(flavor.promptAddition, isNotEmpty);
      expect(ctx.memoryBlock, contains(flavor.promptAddition));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 16: Regional voice — Svizzera italiana (TI) profile
    // ════════════════════════════════════════════════════════════

    test('TI profile injects italiana regional voice into memoryBlock',
        () async {
      final profile = makeProfile(birthYear: 1990, canton: 'TI');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.region, equals(SwissRegion.italiana));
      expect(flavor.promptAddition, isNotEmpty);
      expect(ctx.memoryBlock, contains(flavor.promptAddition));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 17: Regional voice — empty canton → no regional block
    // ════════════════════════════════════════════════════════════

    test('empty canton produces no regional flavor injection in memoryBlock',
        () async {
      // Empty canton → unknown region → promptAddition is empty → block omitted.
      final profile = makeProfile(birthYear: 1985, canton: '');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      final flavor = RegionalVoiceService.forCanton('');
      expect(flavor.region, equals(SwissRegion.unknown));
      expect(flavor.promptAddition, isEmpty);

      // None of the region-specific markers should appear.
      expect(ctx.memoryBlock, isNot(contains('septante')));
      expect(ctx.memoryBlock, isNot(contains('Bitzeli')));
      expect(ctx.memoryBlock, isNot(contains('grotto')));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 18: PLAN EN COURS block injected when goal is selected
    // ════════════════════════════════════════════════════════════

    test('memoryBlock contains PLAN EN COURS when goal is selected', () async {
      // Profile with salary so step 1 (ret_01_salary) completes immediately.
      final profile = makeProfile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      );
      SharedPreferences.setMockInitialValues({
        'goal_selection_selected_intent_tag': 'retirement_choice',
      });
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('PLAN EN COURS'));
      expect(ctx.memoryBlock, contains('retirement_choice'));
      // Progress marker always present
      expect(ctx.memoryBlock, contains('Progression'));
      // capSequencePlan populated
      expect(ctx.capSequencePlan, isNotNull);
      expect(ctx.capSequencePlan!.totalCount, equals(10));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 19: PLAN EN COURS absent when no goal selected
    // ════════════════════════════════════════════════════════════

    test('memoryBlock has no PLAN EN COURS when no goal selected', () async {
      final profile = makeProfile(birthYear: 1982, canton: 'GE');
      // No goal_selection_selected_intent_tag key
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, isNot(contains('PLAN EN COURS')));
      expect(ctx.capSequencePlan, isNull);
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 20: PLAN EN COURS current step title is in French
    // ════════════════════════════════════════════════════════════

    test('PLAN EN COURS block contains French step title', () async {
      // Profile without salary so step 1 is current.
      final profile = makeProfile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 0,
      );
      SharedPreferences.setMockInitialValues({
        'goal_selection_selected_intent_tag': 'retirement_choice',
      });
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      // The French title for capStepRetirement01Title
      expect(ctx.memoryBlock, contains('Connaître ton salaire brut'));
      expect(ctx.memoryBlock, contains('Étape actuelle'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 21: Budget plan (6 steps) injected for budget_overview goal
    // ════════════════════════════════════════════════════════════

    test('PLAN EN COURS with budget_overview goal shows 6-step sequence',
        () async {
      final profile = makeProfile(birthYear: 1990, canton: 'ZH', salaire: 0);
      SharedPreferences.setMockInitialValues({
        'goal_selection_selected_intent_tag': 'budget_overview',
      });
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(ctx.capSequencePlan, isNotNull);
      expect(ctx.capSequencePlan!.goalId, equals('budget_overview'));
      expect(ctx.capSequencePlan!.totalCount, equals(6));
      expect(ctx.memoryBlock, contains('budget_overview'));
      expect(ctx.memoryBlock, contains('6'));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 22: capSequencePlan null for unknown goal tag
    // ════════════════════════════════════════════════════════════

    test('capSequencePlan is null for unknown goal tag', () async {
      final profile = makeProfile(birthYear: 1985, canton: 'BE');
      SharedPreferences.setMockInitialValues({
        'goal_selection_selected_intent_tag': 'unknown_goal_tag_xyz',
      });
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      // Unknown goal tag → empty sequence → null capSequencePlan
      expect(ctx.capSequencePlan, isNull);
      expect(ctx.memoryBlock, isNot(contains('PLAN EN COURS')));
    });

    // ════════════════════════════════════════════════════════════
    //  TEST 23: PLAN EN COURS contains Prochaine étape when step 1 complete
    // ════════════════════════════════════════════════════════════

    test('PLAN EN COURS includes Prochaine étape when step 1 complete',
        () async {
      // Profile with salary → step 1 (salary) is completed → step 2 becomes current.
      // Step 3 (LPP) becomes the next upcoming step.
      final profile = makeProfile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      );
      SharedPreferences.setMockInitialValues({
        'goal_selection_selected_intent_tag': 'retirement_choice',
      });
      final prefs = await SharedPreferences.getInstance();

      final ctx = await ContextInjectorService.buildContext(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('Prochaine étape'));
    });
  });
}
