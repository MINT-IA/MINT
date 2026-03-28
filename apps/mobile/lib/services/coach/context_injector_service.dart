import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart'
    as lifecycle_v2;
import 'package:mint_mobile/services/content_adapter_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/memory/memory_context_builder.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/models/coaching_preference.dart';

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
//   5. Plan / CapSequence — active multi-step plan progress
//
// The injected block follows this format:
//   --- MÉMOIRE MINT ---
//   [Lifecycle context]
//   [Conversation memory]
//   [User goals]
//   [Plan / CapSequence]
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

  /// The user's active CapSequence plan, if a goal is selected.
  ///
  /// Null when no goal is selected or when the sequence is empty.
  /// Injected into the memory block as PLAN EN COURS.
  final CapSequence? capSequencePlan;

  const EnrichedContext({
    required this.memoryBlock,
    this.lifecyclePhase,
    this.contentAdaptation,
    required this.conversationMemory,
    required this.activeGoalsCount,
    this.activeNudges = const [],
    this.relevantScreens = const [],
    this.capSequencePlan,
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
    MintUserState? mintState,
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
      // Append literacy level directive so Claude adapts language complexity.
      final literacyDirective = _literacyDirective(profile.financialLiteracyLevel);
      lifecycleBlock = adaptation.coachSystemPromptAddition +
          (literacyDirective.isNotEmpty ? '\n$literacyDirective' : '');
    }

    // Load cross-session insights from the new CoachMemoryService (S58).
    // These complement the conversation memory with structured topic insights.
    String crossSessionBlock = '';
    try {
      crossSessionBlock = await MemoryContextBuilder.buildContext(prefs: sp);
    } catch (_) {
      // Graceful degradation: old memory still works without new insights.
    }

    // ── Mémoire récente (visible memory references) ───────────
    // List the 3 most recent insights with dates so Claude can
    // naturally reference past topics in its responses.
    String recentInsightsBlock = '';
    try {
      final recentInsights = await CoachMemoryService.getInsights(prefs: sp);
      if (recentInsights.isNotEmpty) {
        final coachingPref = CoachingPreference.load(sp);
        recentInsightsBlock = _buildRecentInsightsBlock(
          recentInsights,
          maxDepth: coachingPref.maxRecallDepth,
          now: currentDate,
        );
      }
    } catch (_) {
      // Graceful degradation: coach works without recent insights block.
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

    // ── Plan / CapSequence ────────────────────────────────────
    // Inject the user's active multi-step plan so Claude is plan-aware.
    // Uses GoalSelectionService + CapSequenceEngine (pure functions).
    // Graceful degradation: coach works without plan context.
    CapSequence? capSequencePlan;
    String planBlock = '';
    if (profile != null) {
      try {
        final goalTag = await GoalSelectionService.getSelectedGoal(sp);
        if (goalTag != null) {
          final capMemory = await CapMemoryStore.load();
          final frL10n = SFr();
          final sequence = CapSequenceEngine.build(
            profile: profile,
            memory: capMemory,
            goalIntentTag: goalTag,
            l: frL10n,
          );
          if (sequence.steps.isNotEmpty) {
            capSequencePlan = sequence;
            planBlock = _buildPlanBlock(sequence, goalTag);
          }
        }
      } catch (_) {
        // Graceful degradation: coach works without plan context.
      }
    }

    // ── EVI Bridge — Enrichment priorities ─────────────────────
    // Inject the top enrichment prompts ranked by Expected Value of
    // Information so the coach can propose the most impactful next
    // data capture action (scan, question, document).
    String enrichmentBlock = '';
    if (profile != null) {
      enrichmentBlock = _buildEnrichmentBlock(profile);
    }

    // ── Budget Vivant ─────────────────────────────────────────
    // Inject the BudgetSnapshot into the memory block so Claude can
    // reason about the user's real numbers (margin, retirement gap,
    // cap impacts in CHF/month).
    String budgetBlock = '';
    if (mintState?.budgetSnapshot != null) {
      final snap = mintState!.budgetSnapshot!;
      final lines = <String>['BUDGET VIVANT\u00a0:'];
      lines.add('Marge libre\u00a0: CHF\u00a0${snap.present.monthlyFree.round()}/mois');
      lines.add('Charges fixes\u00a0: CHF\u00a0${snap.present.monthlyCharges.round()}/mois');

      if (snap.hasFullGap) {
        final isEstimated = profile?.prevoyance.isLppEstimated ?? true;
        if (isEstimated) {
          lines.add('ATTENTION\u00a0: Les projections retraite ci-dessous sont bas\u00e9es sur '
              'les minimums l\u00e9gaux LPP (pas le plan de caisse r\u00e9el). '
              'Le taux r\u00e9el pourrait \u00eatre significativement plus \u00e9lev\u00e9. '
              'Propose \u00e0 l\'utilisateur de scanner son certificat LPP pour des chiffres pr\u00e9cis.');
        }
        lines.add('Revenu retraite estim\u00e9\u00a0: CHF\u00a0${snap.retirement!.monthlyNet.round()}/mois');
        lines.add('Taux de remplacement\u00a0: ${snap.gap!.replacementRate.round()}\u00a0%');
        lines.add('\u00c9cart mensuel\u00a0: CHF\u00a0${snap.gap!.monthlyGap.round()}/mois');
      }
      if (snap.capImpacts.isNotEmpty) {
        for (final cap in snap.capImpacts.take(2)) {
          lines.add('Levier\u00a0: ${cap.capId} \u2192 +CHF\u00a0${cap.monthlyDelta.round()}/mois');
        }
      }
      budgetBlock = lines.join('\n');
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
      planBlock: planBlock,
      recentInsightsBlock: recentInsightsBlock,
      budgetBlock: budgetBlock,
      enrichmentBlock: enrichmentBlock,
    );

    return EnrichedContext(
      memoryBlock: memoryBlock,
      lifecyclePhase: phaseResult,
      contentAdaptation: adaptation,
      conversationMemory: memory,
      activeGoalsCount: activeGoals.length,
      activeNudges: activeNudges,
      relevantScreens: relevantScreens,
      capSequencePlan: capSequencePlan,
    );
  }

  /// Maximum enrichment prompts surfaced in the memory block.
  static const int _maxEnrichmentInContext = 3;

  /// Build the EVI-ranked enrichment block for the coach system prompt.
  ///
  /// Uses [ConfidenceScorer] to get the top enrichment prompts ranked by
  /// impact, then formats them so the coach can proactively propose
  /// the most valuable next data capture action.
  ///
  /// The block tells Claude:
  /// - Current confidence level
  /// - Top 3 actions to improve it (with expected gain in points)
  /// - Whether to route to /scan or ask a question
  static String _buildEnrichmentBlock(CoachProfile profile) {
    final confidence = ConfidenceScorer.score(profile);
    final topPrompts = confidence.prompts.take(_maxEnrichmentInContext).toList();

    if (topPrompts.isEmpty) return '';

    final lines = <String>['ENRICHISSEMENT PRIORITAIRE\u00a0:'];
    lines.add('Score de confiance actuel\u00a0: ${confidence.score.round()}/100 '
        '(${confidence.level})');

    if (confidence.score < ConfidenceScorer.minConfidenceForProjection) {
      lines.add('IMPORTANT\u00a0: La confiance est trop basse pour des projections fiables. '
          'Propose activement la meilleure action ci-dessous.');
    }

    for (final prompt in topPrompts) {
      final route = _enrichmentRoute(prompt.category);
      lines.add('- ${prompt.label} (+${prompt.impact}\u00a0pts) '
          '\u2192 ${prompt.action}${route != null ? ' [route\u00a0: $route]' : ''}');
    }

    // Bayesian EVI ranking if available (more precise than component weights)
    final bayesian = confidence.bayesianResult;
    if (bayesian != null && bayesian.rankedPrompts.isNotEmpty) {
      final topEvi = bayesian.rankedPrompts.first;
      if (topEvi.field != topPrompts.first.category) {
        // EVI suggests a different top priority — add a hint
        lines.add('EVI prioritaire\u00a0: ${topEvi.label} '
            '(incertitude actuelle\u00a0: \u00b1CHF\u00a0${topEvi.currentUncertainty.round()})');
      }
    }

    return lines.join('\n');
  }

  /// Map enrichment category to the best route for data capture.
  static String? _enrichmentRoute(String category) {
    return switch (category) {
      'lpp' => '/scan',
      'avs' => '/scan/avs-guide',
      '3a' => '/scan',
      'patrimoine' => null, // Coach asks conversationally
      'menage' => null, // Coach asks conversationally
      'income' => null, // Coach asks conversationally
      'objectif_retraite' => null, // Coach asks conversationally
      'foreign_pension' => null,
      _ => null,
    };
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

  /// Build the PLAN EN COURS block for a CapSequence.
  ///
  /// Resolves ARB title keys using the French fallback (service layer context).
  /// Format:
  /// Build the literacy level directive for the coach system prompt.
  ///
  /// Adapts the coach's language complexity to the user's financial literacy.
  /// See VOICE_SYSTEM.md §Axe 2 for the full spec.
  static String _literacyDirective(FinancialLiteracyLevel level) {
    switch (level) {
      case FinancialLiteracyLevel.beginner:
        return 'NIVEAU DE MAÎTRISE\u00a0: novice\n'
            'Phrases courtes. Pas de sigle sans explication (LPP = "2e pilier"). '
            'Métaphores concrètes. Pas de pourcentages abstraits sans ancrage CHF. '
            'Explique chaque concept comme si c\'était la première fois.';
      case FinancialLiteracyLevel.intermediate:
        return 'NIVEAU DE MAÎTRISE\u00a0: autonome\n'
            'Sigles OK (LPP, AVS, 3a). Chiffres directs. Moins de contexte. '
            'L\'utilisateur comprend le système suisse — va droit au fait.';
      case FinancialLiteracyLevel.advanced:
        return 'NIVEAU DE MAÎTRISE\u00a0: expert\n'
            'Références légales (LAVS art. 35, LIFD art. 38). '
            'Scénarios avancés. Hypothèses éditables. Sensibilité. '
            'L\'utilisateur veut de la profondeur, pas de la vulgarisation.';
    }
  }

  ///   PLAN EN COURS : <goalId> (<completed>/<total> étapes)
  ///   Étape actuelle : <currentStep title>
  ///   Prochaine étape : <nextStep title>
  ///   Progression : <percent>%
  static String _buildPlanBlock(CapSequence sequence, String goalTag) {
    final frL10n = SFr();
    final lines = <String>[
      'PLAN EN COURS\u00a0: $goalTag'
          ' (${sequence.completedCount}/${sequence.totalCount}'
          ' \u00e9tapes)',
    ];

    final current = sequence.currentStep;
    if (current != null) {
      final title = _resolveStepTitle(current.titleKey, frL10n);
      lines.add('\u00c9tape actuelle\u00a0: $title');
    }

    final next = sequence.nextStep;
    if (next != null) {
      final title = _resolveStepTitle(next.titleKey, frL10n);
      lines.add('Prochaine \u00e9tape\u00a0: $title');
    }

    final pct = (sequence.progressPercent * 100).round();
    lines.add('Progression\u00a0: $pct\u00a0%');

    return lines.join('\n');
  }

  /// Resolve an ARB title key to its French localised string.
  ///
  /// Falls through to the raw key when no match is found so there is
  /// always a non-empty label in the plan block.
  static String _resolveStepTitle(String titleKey, SFr l) {
    switch (titleKey) {
      // Retirement steps
      case 'capStepRetirement01Title':
        return l.capStepRetirement01Title;
      case 'capStepRetirement02Title':
        return l.capStepRetirement02Title;
      case 'capStepRetirement03Title':
        return l.capStepRetirement03Title;
      case 'capStepRetirement04Title':
        return l.capStepRetirement04Title;
      case 'capStepRetirement05Title':
        return l.capStepRetirement05Title;
      case 'capStepRetirement06Title':
        return l.capStepRetirement06Title;
      case 'capStepRetirement07Title':
        return l.capStepRetirement07Title;
      case 'capStepRetirement08Title':
        return l.capStepRetirement08Title;
      case 'capStepRetirement09Title':
        return l.capStepRetirement09Title;
      case 'capStepRetirement10Title':
        return l.capStepRetirement10Title;
      // Budget steps
      case 'capStepBudget01Title':
        return l.capStepBudget01Title;
      case 'capStepBudget02Title':
        return l.capStepBudget02Title;
      case 'capStepBudget03Title':
        return l.capStepBudget03Title;
      case 'capStepBudget04Title':
        return l.capStepBudget04Title;
      case 'capStepBudget05Title':
        return l.capStepBudget05Title;
      case 'capStepBudget06Title':
        return l.capStepBudget06Title;
      // Housing steps
      case 'capStepHousing01Title':
        return l.capStepHousing01Title;
      case 'capStepHousing02Title':
        return l.capStepHousing02Title;
      case 'capStepHousing03Title':
        return l.capStepHousing03Title;
      case 'capStepHousing04Title':
        return l.capStepHousing04Title;
      case 'capStepHousing05Title':
        return l.capStepHousing05Title;
      case 'capStepHousing06Title':
        return l.capStepHousing06Title;
      case 'capStepHousing07Title':
        return l.capStepHousing07Title;
      default:
        return titleKey;
    }
  }

  /// Build the MÉMOIRE RÉCENTE block for the 3 most recent insights.
  ///
  /// Gives Claude explicit awareness of what was discussed recently so
  /// it can naturally reference past topics without hallucinating.
  ///
  /// Format:
  ///   MÉMOIRE RÉCENTE :
  ///   - [goal] lpp : rachat envisagé (il y a 3 jours)
  ///   - [fact] retraite : projection revue (il y a 12 jours)
  ///   - [concern] budget : inquiétude inflation (il y a 1 mois)
  static String _buildRecentInsightsBlock(
    List<CoachInsight> insights, {
    required DateTime now,
    int maxDepth = 3,
  }) {
    final top = insights.take(maxDepth).toList();
    if (top.isEmpty) return '';

    final lines = <String>['MÉMOIRE RÉCENTE\u00a0:'];
    for (final insight in top) {
      final days = now.difference(insight.createdAt).inDays;
      final ageText = _insightAgeText(days);
      // Sanitize: strip control chars, truncate to 80 chars.
      final summary = insight.summary
          .replaceAll(RegExp(r'[\n\r\t\x00-\x1F]'), ' ')
          .replaceAll(RegExp(r' {2,}'), ' ')
          .trim();
      final safeSum = summary.length > 80
          ? '${summary.substring(0, 77)}\u2026'
          : summary;
      lines.add(
        '  - [${insight.type.name}] ${insight.topic}\u00a0: $safeSum ($ageText)',
      );
    }
    return lines.join('\n');
  }

  /// Format a day count as a compact French age string.
  static String _insightAgeText(int days) {
    if (days == 0) return "aujourd\u2019hui";
    if (days == 1) return 'hier';
    if (days < 7) return 'il y a $days jours';
    final weeks = (days / 7).round();
    if (weeks == 1) return 'il y a 1 semaine';
    if (weeks < 5) return 'il y a $weeks semaines';
    final months = (days / 30).round();
    if (months == 1) return 'il y a 1 mois';
    return 'il y a $months mois';
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
    String planBlock = '',
    String recentInsightsBlock = '',
    String budgetBlock = '',
    String enrichmentBlock = '',
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

    // Plan / CapSequence — user's active multi-step plan
    if (planBlock.isNotEmpty) {
      parts.add('');
      parts.add(planBlock);
    }

    // Budget Vivant — present, retirement, gap, levers
    if (budgetBlock.isNotEmpty) {
      parts.add('');
      parts.add(budgetBlock);
    }

    // EVI-ranked enrichment priorities (coach should propose these)
    if (enrichmentBlock.isNotEmpty) {
      parts.add('');
      parts.add(enrichmentBlock);
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

    // Recent insights — visible memory for Claude to reference naturally
    if (recentInsightsBlock.isNotEmpty) {
      parts.add('');
      parts.add(recentInsightsBlock);
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
