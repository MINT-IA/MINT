/// MintStateEngine — assembles [MintUserState] from all service layers.
///
/// This is the ONLY place where CoachProfile + CapEngine + ConfidenceScorer
/// + LifecycleDetector + NudgeEngine + ProactiveTriggerService are combined
/// into a single [MintUserState] snapshot.
///
/// Design principles:
///   - Pure async factory: no singleton state.
///   - Side effects: ProactiveTriggerService.evaluate() writes a cooldown
///     timestamp to SharedPreferences. All other calls are read-only.
///   - Services called defensively: one failure does not abort the whole state.
///   - CapEngine requires `S` (l10n); labels are intentionally left empty
///     strings here — the engine uses them only for CTA labels which are
///     already stored as ARB keys by CapEngine V1.
///   - Projections are skipped when confidence < 30 to avoid surfacing
///     meaningless numbers. The [MintUserState.hasProjections] flag signals
///     this to consumers.
///
/// Compliance:
///   - No banned terms in logs or code comments.
///   - No user-facing strings (all via ARB keys in the services).
///   - No identifiable data logged.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';

/// Minimum confidence score required to run retirement projections.
///
/// Below this threshold, projections are considered too uncertain to surface.
const double _kMinConfidenceForProjections = 30.0;

/// Assembles [MintUserState] from [CoachProfile] and all service layers.
///
/// All methods are static — no instantiation needed.
class MintStateEngine {
  MintStateEngine._();

  /// Compute the unified user state from profile + services.
  ///
  /// [profile] — current financial profile. Required.
  /// [prefs]   — injectable SharedPreferences (for tests: pass a mock).
  /// [now]     — override for deterministic testing. Defaults to [DateTime.now()].
  ///
  /// Never throws. Failures in individual services are caught and result in
  /// null/empty values for the corresponding fields.
  static Future<MintUserState> compute({
    required CoachProfile profile,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();

    // ── 1. Lifecycle phase ─────────────────────────────────────────────────
    final lifecyclePhase = LifecycleDetector.detect(profile, now: currentTime);

    // ── 2. Confidence score ────────────────────────────────────────────────
    double confidenceScore = 0.0;
    try {
      final confidence = ConfidenceScorer.score(profile);
      confidenceScore = confidence.score;
    } catch (_) {
      confidenceScore = 0.0;
    }

    // ── 3. CapMemory ───────────────────────────────────────────────────────
    CapMemory capMemory = const CapMemory();
    try {
      capMemory = await CapMemoryStore.load();
    } catch (_) {
      capMemory = const CapMemory();
    }

    // ── 4. Cap decision ────────────────────────────────────────────────────
    // CapEngine requires an S (l10n) instance for CTA labels.
    // We use the French fallback so the engine runs without BuildContext.
    // Architectural limitation: CapEngine labels use French fallback when
    // computed without BuildContext (service layer). Screen-layer CapEngine
    // calls use proper i18n via the real S instance.
    // CapEngine labels here are used only for internal matching/sorting
    // (capId, tier comparisons), NOT for direct display — so French fallback
    // is acceptable. Screen consumers re-call CapEngine with BuildContext.
    CapDecision? currentCap;
    final frenchL10n = SFr();
    try {
      currentCap = CapEngine.compute(
        profile: profile,
        now: currentTime,
        l: frenchL10n,
        memory: capMemory,
      );
    } catch (_) {
      currentCap = null;
    }

    // ── 5. Active goal intent tag ──────────────────────────────────────────
    // Priority: explicit GoalSelectionService selection > CapMemory declaredGoals.
    String? activeGoalIntentTag;
    try {
      final explicitGoal = await GoalSelectionService.getSelectedGoal(prefs);
      if (explicitGoal != null) {
        activeGoalIntentTag = explicitGoal;
      } else {
        activeGoalIntentTag = capMemory.declaredGoals.isNotEmpty
            ? capMemory.declaredGoals.first
            : null;
      }
    } catch (_) {
      activeGoalIntentTag = capMemory.declaredGoals.isNotEmpty
          ? capMemory.declaredGoals.first
          : null;
    }

    // ── 5b. CapSequence plan ───────────────────────────────────────────────
    // Build the full multi-step plan when a goal is selected.
    // Uses French fallback (service layer) — same pattern as CapEngine above.
    // The widget layer re-resolves labels with a real BuildContext.
    CapSequence? capSequencePlan;
    if (activeGoalIntentTag != null) {
      try {
        final sequence = CapSequenceEngine.build(
          profile: profile,
          memory: capMemory,
          goalIntentTag: activeGoalIntentTag,
          l: frenchL10n,
        );
        if (sequence.steps.isNotEmpty) {
          capSequencePlan = sequence;
        }
      } catch (_) {
        capSequencePlan = null;
      }
    }

    // ── 6. Projections (conditional on confidence) ─────────────────────────
    double? friScore;
    double? replacementRate;
    RetirementBudgetGap? budgetGap;
    BudgetSnapshot? budgetSnapshot;

    if (confidenceScore >= _kMinConfidenceForProjections) {
      // 6a. Forecaster projection (for FRI)
      try {
        final projection = ForecasterService.project(profile: profile);
        replacementRate = projection.tauxRemplacementBase;

        // 6b. FRI score
        try {
          final friBreakdown = FriComputationService.compute(
            profile: profile,
            projection: projection,
            confidenceScore: confidenceScore,
          );
          friScore = friBreakdown.total;
        } catch (_) {
          friScore = null;
        }
      } catch (_) {
        replacementRate = null;
        friScore = null;
      }

      // 6c. Retirement budget gap
      try {
        final retirementResult = RetirementProjectionService.project(
          profile: profile,
          retirementAgeUser: profile.targetRetirementAge ?? 65,
        );
        budgetGap = retirementResult.budgetGap;
        // If replacementRate was not set from forecaster, fall back to
        // the retirement projection's replacement rate.
        replacementRate ??= retirementResult.tauxRemplacement;
      } catch (_) {
        budgetGap = null;
      }

    }

    // 6e. BudgetSnapshot — ALWAYS computed, even with low confidence.
    // Present-day budget (monthlyNet, monthlyCharges, monthlyFree) doesn't
    // require retirement projections. BudgetLivingEngine handles graceful
    // degradation: returns BudgetStage.presentOnly when data is insufficient
    // for retirement projections.
    try {
      budgetSnapshot = BudgetLivingEngine.compute(profile);
    } catch (_) {
      budgetSnapshot = null;
    }

    // ── 7. Active nudges ───────────────────────────────────────────────────
    List<Nudge> activeNudges = const [];
    try {
      final dismissed = await NudgePersistence.getDismissedIds(
        prefs,
        now: currentTime,
      );
      final lastActivity = await NudgePersistence.getLastActivityTime(prefs);
      activeNudges = NudgeEngine.evaluate(
        profile: profile,
        now: currentTime,
        dismissedNudgeIds: dismissed,
        lastActivityTime: lastActivity,
        confidenceScore: confidenceScore,
        goalProgressPct: null,
        lifeEventDate: null,
      );
    } catch (_) {
      activeNudges = const [];
    }

    // ── 8. Proactive trigger ───────────────────────────────────────────────
    ProactiveTrigger? pendingTrigger;
    try {
      pendingTrigger = await ProactiveTriggerService.evaluate(
        profile: profile,
        prefs: prefs,
        now: currentTime,
      );
    } catch (_) {
      pendingTrigger = null;
    }

    // ── 9. Session delta (Wire Spec V2 §3.4) ────────────────────────────
    // Load the previous snapshot and compute delta for "since last visit"
    // display on MintHomeScreen. Never crashes on snapshot failure.
    SessionDelta? sessionDelta;
    try {
      final previousSnapshot = await SessionSnapshotService.load();
      if (previousSnapshot != null) {
        // Monthly retirement income from budgetGap (total revenus at retirement).
        // Falls back to 0 when projections are not yet available.
        final currentRetirementIncome =
            budgetGap?.totalRevenusMensuel ?? 0.0;
        final currentFhs = friScore ?? 0.0;

        sessionDelta = SessionSnapshotService.computeDelta(
          previous: previousSnapshot,
          currentConfidence: confidenceScore,
          currentMonthlyRetirement: currentRetirementIncome,
          currentFhs: currentFhs,
        );
      }
    } catch (_) {
      // Never crash on snapshot failure.
    }

    // ── 10. Assemble ───────────────────────────────────────────────────────
    return MintUserState(
      profile: profile,
      lifecyclePhase: lifecyclePhase,
      archetype: profile.archetype,
      budgetGap: budgetGap,
      budgetSnapshot: budgetSnapshot,
      currentCap: currentCap,
      capSequencePlan: capSequencePlan,
      activeGoalIntentTag: activeGoalIntentTag,
      confidenceScore: confidenceScore,
      friScore: friScore,
      replacementRate: replacementRate,
      capMemory: capMemory,
      activeNudges: activeNudges,
      pendingTrigger: pendingTrigger,
      sessionDelta: sessionDelta,
      computedAt: currentTime,
    );
  }
}
