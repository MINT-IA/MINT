import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart'
    as lifecycle_v2;
import 'package:mint_mobile/services/content_adapter_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/memory/memory_context_builder.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';

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

  /// Active nudges (top-priority first, at most [_maxNudgesInContext]).
  ///
  /// Populated only when a [CoachProfile] is available.
  final List<Nudge> activeNudges;

  /// Top relevant screen entries for this lifecycle phase (at most 5).
  ///
  /// Used to hint Claude about what surfaces to route to.
  final List<ScreenEntry> relevantScreens;

  const EnrichedContext({
    required this.memoryBlock,
    this.lifecyclePhase,
    this.contentAdaptation,
    required this.conversationMemory,
    required this.activeGoalsCount,
    this.activeNudges = const [],
    this.relevantScreens = const [],
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

  /// Maximum nudges surfaced in the memory block.
  static const int _maxNudgesInContext = 2;

  /// Maximum relevant screens listed in the memory block.
  static const int _maxScreensInContext = 5;

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

    // Load cross-session insights from the new CoachMemoryService (S58).
    // These complement the conversation memory with structured topic insights.
    String crossSessionBlock = '';
    try {
      crossSessionBlock = await MemoryContextBuilder.buildContext(prefs: sp);
    } catch (_) {
      // Graceful degradation: old memory still works without new insights.
    }

    // ── Nudges (JITAI) ─────────────────────────────────────────
    // Evaluate active nudges for lifecycle-aware coaching context.
    // Pure function — uses NudgePersistence for dismissed ids only.
    List<Nudge> activeNudges = const [];
    String nudgesBlock = '';
    if (profile != null) {
      try {
        final dismissedIds = await NudgePersistence.getDismissedIds(
          sp,
          now: currentDate,
        );
        final lastActivity = await NudgePersistence.getLastActivityTime(sp);
        final nudges = NudgeEngine.evaluate(
          profile: profile,
          now: currentDate,
          dismissedNudgeIds: dismissedIds,
          lastActivityTime: lastActivity,
        );
        activeNudges = nudges.take(_maxNudgesInContext).toList();
        if (activeNudges.isNotEmpty) {
          nudgesBlock = _buildNudgesBlock(activeNudges);
        }
      } catch (_) {
        // Graceful degradation: coach works without nudge context.
      }
    }

    // ── Relevant screens (ScreenRegistry) ──────────────────────
    // List the top screens relevant to this lifecycle phase so Claude
    // knows which surfaces to route to with route_to_screen.
    List<ScreenEntry> relevantScreens = const [];
    String screensBlock = '';
    if (profile != null && phaseResult != null) {
      try {
        relevantScreens = _buildRelevantScreens(phaseResult);
        if (relevantScreens.isNotEmpty) {
          screensBlock = _buildScreensBlock(relevantScreens);
        }
      } catch (_) {
        // Graceful degradation: coach works without screen hints.
      }
    }

    // ── Regional voice flavor ─────────────────────────────────
    // Inject a subtle regional identity block so the coach adapts
    // its tone, expressions, and cultural references to the user's
    // Swiss linguistic region (Romande / Deutschschweiz / Italiana).
    String regionalBlock = '';
    if (profile != null) {
      final flavor = RegionalVoiceService.forCanton(profile.canton);
      if (flavor.promptAddition.isNotEmpty) {
        regionalBlock = flavor.promptAddition;
      }
    }

    // Build the complete memory block
    final memoryBlock = _buildMemoryBlock(
      lifecycleBlock: lifecycleBlock,
      memory: memory,
      goalsSummary: goalsSummary,
      crossSessionBlock: crossSessionBlock,
      nudgesBlock: nudgesBlock,
      screensBlock: screensBlock,
      regionalBlock: regionalBlock,
    );

    return EnrichedContext(
      memoryBlock: memoryBlock,
      lifecyclePhase: phaseResult,
      contentAdaptation: adaptation,
      conversationMemory: memory,
      activeGoalsCount: activeGoals.length,
      activeNudges: activeNudges,
      relevantScreens: relevantScreens,
    );
  }

  /// Build the formatted nudges block for the memory block.
  ///
  /// Nudge title keys are stored (not resolved) — the block uses the
  /// trigger name for the LLM, not the i18n string (it's internal).
  static String _buildNudgesBlock(List<Nudge> nudges) {
    final lines = <String>['NUDGES ACTIFS\u00a0:'];
    for (final n in nudges) {
      final priorityLabel = _priorityLabel(n.priority);
      // Use the intentTag (route slug) as the topic descriptor for the LLM.
      lines.add('- ${n.intentTag} (priorité\u00a0$priorityLabel)');
    }
    return lines.join('\n');
  }

  static String _priorityLabel(NudgePriority priority) {
    switch (priority) {
      case NudgePriority.high:
        return 'haute';
      case NudgePriority.medium:
        return 'moyenne';
      case NudgePriority.low:
        return 'basse';
    }
  }

  /// Convert a [LifecyclePhase] from the legacy `lifecycle_phase_service.dart`
  /// to the V2 enum in `lifecycle/lifecycle_phase.dart`.
  ///
  /// Both enums share the same value names — this bridges the two types.
  static lifecycle_v2.LifecyclePhase _toV2Phase(LifecyclePhase legacyPhase) {
    switch (legacyPhase) {
      case LifecyclePhase.demarrage:
        return lifecycle_v2.LifecyclePhase.demarrage;
      case LifecyclePhase.construction:
        return lifecycle_v2.LifecyclePhase.construction;
      case LifecyclePhase.acceleration:
        return lifecycle_v2.LifecyclePhase.acceleration;
      case LifecyclePhase.consolidation:
        return lifecycle_v2.LifecyclePhase.consolidation;
      case LifecyclePhase.transition:
        return lifecycle_v2.LifecyclePhase.transition;
      case LifecyclePhase.retraite:
        return lifecycle_v2.LifecyclePhase.retraite;
      case LifecyclePhase.transmission:
        return lifecycle_v2.LifecyclePhase.transmission;
    }
  }

  /// Build the relevant screens block from lifecycle phase priorities.
  ///
  /// Uses [LifecycleDetector.adapt] to get priority screens for the phase,
  /// then resolves them via [MintScreenRegistry] to get routes.
  static List<ScreenEntry> _buildRelevantScreens(
    LifecyclePhaseResult phaseResult,
  ) {
    // Convert legacy LifecyclePhase to V2 for LifecycleDetector.adapt().
    final v2Phase = _toV2Phase(phaseResult.phase);
    final adaptation = LifecycleDetector.adapt(v2Phase);
    final relevantIntentTags = adaptation.relevantScreens;

    final screens = <ScreenEntry>[];
    for (final tag in relevantIntentTags) {
      final entry = MintScreenRegistry.findByIntentStatic(tag);
      if (entry != null && entry.preferFromChat) {
        screens.add(entry);
      }
      if (screens.length >= _maxScreensInContext) break;
    }

    // If the phase adaptation lists fewer than _maxScreensInContext, fill from
    // the full chat-routable list filtered to decisionCanvas behavior.
    if (screens.length < _maxScreensInContext) {
      for (final entry in MintScreenRegistry.entries) {
        if (!entry.preferFromChat) continue;
        if (entry.behavior != ScreenBehavior.decisionCanvas) continue;
        if (screens.any((e) => e.intentTag == entry.intentTag)) continue;
        screens.add(entry);
        if (screens.length >= _maxScreensInContext) break;
      }
    }

    return screens;
  }

  static String _buildScreensBlock(List<ScreenEntry> screens) {
    final lines = <String>['SURFACES PERTINENTES\u00a0:'];
    for (final s in screens) {
      lines.add('- ${s.intentTag} \u2192 ${s.route}');
    }
    return lines.join('\n');
  }

  /// Build the formatted memory block for system prompt injection.
  ///
  /// Pure function — deterministic, no side effects.
  static String _buildMemoryBlock({
    required String lifecycleBlock,
    required ConversationMemory memory,
    required String goalsSummary,
    String crossSessionBlock = '',
    String nudgesBlock = '',
    String screensBlock = '',
    String regionalBlock = '',
  }) {
    final parts = <String>[];

    parts.add('--- MÉMOIRE MINT ---');

    // Privacy + compliance reminders at TOP of memory block (LLM primacy effect)
    parts.add('RAPPEL\u00a0: Ne jamais mentionner de données personnelles '
        '(salaire exact, IBAN, nom, employeur). Utilise des approximations '
        'et des fourchettes.');
    parts.add('Tu es un outil éducatif\u00a0: ne constitue pas un conseil financier '
        '(LSFin). Propose toujours des actions concrètes et des étapes '
        'que l\'utilisateur peut entreprendre.');

    // Lifecycle context
    if (lifecycleBlock.isNotEmpty) {
      parts.add('');
      parts.add(lifecycleBlock);
    }

    // Regional voice flavor (Swiss linguistic identity)
    if (regionalBlock.isNotEmpty) {
      parts.add('');
      parts.add(regionalBlock);
    }

    // Active nudges (JITAI — timely topics to reinforce)
    if (nudgesBlock.isNotEmpty) {
      parts.add('');
      parts.add(nudgesBlock);
    }

    // Relevant screens for this phase (route_to_screen hints)
    if (screensBlock.isNotEmpty) {
      parts.add('');
      parts.add(screensBlock);
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

    // Cross-session insights (CoachMemoryService S58)
    if (crossSessionBlock.isNotEmpty) {
      parts.add('');
      parts.add(crossSessionBlock);
    }

    parts.add('--- FIN MÉMOIRE ---');

    return parts.join('\n');
  }
}
