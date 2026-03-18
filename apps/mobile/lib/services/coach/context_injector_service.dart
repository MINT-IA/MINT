import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/content_adapter_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXT INJECTOR SERVICE — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Combines all context sources into a single enriched block
// for injection into the coach AI system prompt.
//
// Context sources:
//   1. Lifecycle phase (S57) — tone, complexity, priorities
//   2. Conversation memory (S58) — past topics, continuity
//   3. User goals (S58) — declared objectives, deadlines
//   4. Profile context (existing) — financial data, archetype
//
// The injected block follows this format:
//   --- MÉMOIRE MINT ---
//   [Lifecycle context]
//   [Conversation memory]
//   [User goals]
//   --- FIN MÉMOIRE ---
//
// Privacy rules:
//   - NO exact salary, IBAN, name, SSN, employer
//   - Topics only (not full message content)
//   - Goals in user's words (anonymized by LLM extraction)
//
// Pure function for block building. Async for data loading.
// ────────────────────────────────────────────────────────────

/// Full enriched context for coach AI injection.
class EnrichedContext {
  /// The complete memory block for system prompt injection.
  final String memoryBlock;

  /// Lifecycle phase result (for UI adaptation).
  final LifecyclePhaseResult? lifecyclePhase;

  /// Content adaptation (for feature gating).
  final ContentAdaptation? contentAdaptation;

  /// Conversation memory (for display).
  final ConversationMemory conversationMemory;

  /// Active goals count.
  final int activeGoalsCount;

  const EnrichedContext({
    required this.memoryBlock,
    this.lifecyclePhase,
    this.contentAdaptation,
    required this.conversationMemory,
    required this.activeGoalsCount,
  });

  /// Empty context (no profile).
  static const empty = EnrichedContext(
    memoryBlock: '',
    conversationMemory: ConversationMemory.empty,
    activeGoalsCount: 0,
  );
}

/// Builds enriched context for coach AI system prompt injection.
class ContextInjectorService {
  ContextInjectorService._();

  /// Build the full enriched context from all sources.
  ///
  /// [profile] — user profile (null if not onboarded).
  /// [prefs] — injectable for tests.
  /// [now] — override for testing.
  static Future<EnrichedContext> buildContext({
    CoachProfile? profile,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final currentDate = now ?? DateTime.now();

    // Load all context sources in parallel
    final memoryFuture = ConversationMemoryService.buildMemory(
      now: currentDate,
    );
    final goalsFuture = GoalTrackerService.buildGoalsSummary(
      prefs: sp,
      now: currentDate,
    );
    final activeGoalsFuture = GoalTrackerService.activeGoals(prefs: sp);

    final results = await Future.wait([
      memoryFuture,
      goalsFuture,
      activeGoalsFuture,
    ]);

    final memory = results[0] as ConversationMemory;
    final goalsSummary = results[1] as String;
    final activeGoals = results[2] as List<UserGoal>;

    // Build lifecycle context if profile available
    LifecyclePhaseResult? phaseResult;
    ContentAdaptation? adaptation;
    String lifecycleBlock = '';

    if (profile != null) {
      phaseResult = LifecyclePhaseService.detect(profile, now: currentDate);
      adaptation = ContentAdapterService.adapt(phaseResult, profile);
      lifecycleBlock = adaptation.coachSystemPromptAddition;
    }

    // Build the complete memory block
    final memoryBlock = _buildMemoryBlock(
      lifecycleBlock: lifecycleBlock,
      memory: memory,
      goalsSummary: goalsSummary,
    );

    return EnrichedContext(
      memoryBlock: memoryBlock,
      lifecyclePhase: phaseResult,
      contentAdaptation: adaptation,
      conversationMemory: memory,
      activeGoalsCount: activeGoals.length,
    );
  }

  /// Build the formatted memory block for system prompt injection.
  ///
  /// Pure function — deterministic, no side effects.
  static String _buildMemoryBlock({
    required String lifecycleBlock,
    required ConversationMemory memory,
    required String goalsSummary,
  }) {
    final parts = <String>[];

    parts.add('--- MÉMOIRE MINT ---');

    // Privacy reminder at TOP of memory block (LLM primacy effect)
    parts.add('RAPPEL\u00a0: Ne jamais mentionner de données personnelles '
        '(salaire exact, IBAN, nom, employeur). Utilise des approximations '
        'et des fourchettes.');

    // Lifecycle context
    if (lifecycleBlock.isNotEmpty) {
      parts.add('');
      parts.add(lifecycleBlock);
    }

    // Conversation memory
    if (!memory.isEmpty) {
      parts.add('');
      parts.add('HISTORIQUE DE CONVERSATION\u00a0:');
      parts.add(memory.summary);
    }

    // User goals
    if (goalsSummary.isNotEmpty) {
      parts.add('');
      parts.add(goalsSummary);
    }

    parts.add('--- FIN MÉMOIRE ---');

    return parts.join('\n');
  }
}
