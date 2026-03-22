/// Unified user state — single source of truth for all MINT surfaces.
///
/// Computed from [CoachProfile] + services by [MintStateEngine].
/// Immutable. Recomputed on data change via [MintStateProvider].
///
/// All surfaces (Pulse tab, Coach, Explorer widgets, Dossier) read from
/// this object rather than querying individual services independently.
///
/// Sources assembled here:
///   - [CoachProfile]               → profile, archetype
///   - [LifecycleDetector]          → lifecyclePhase
///   - [CapEngine] + [CapMemory]    → currentCap, capSequence, capMemory
///   - [ConfidenceScorer]           → confidenceScore
///   - [FriComputationService]      → friScore
///   - [RetirementProjectionService]→ replacementRate, budgetGap
///   - [NudgeEngine]                → activeNudges
///   - [ProactiveTriggerService]    → pendingTrigger
library;

import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// The unified user state.
///
/// Created only by [MintStateEngine.compute]. Never construct directly
/// in production code — use [MintStateProvider] to access the current state.
class MintUserState {
  // ── Identity ─────────────────────────────────────────────────────────────

  /// Full financial profile. Always present.
  final CoachProfile profile;

  /// Detected lifecycle phase (demarrage → transmission).
  final LifecyclePhase lifecyclePhase;

  /// Detected financial archetype (e.g. swissNative, expatUs).
  ///
  /// Delegates to [CoachProfile.archetype] — stored here so consumers
  /// do not need to import coach_profile.dart for archetype logic.
  final FinancialArchetype archetype;

  // ── Budget Vivant ─────────────────────────────────────────────────────────

  /// Retirement budget gap (A vs B). Null until profile has enough data for
  /// a meaningful projection (see [hasProjections]).
  final RetirementBudgetGap? budgetGap;

  /// Full budget snapshot — present + retirement + gap + cap impacts.
  ///
  /// Computed once by [MintStateEngine] via [BudgetLivingEngine.compute].
  /// Single source of truth consumed by PulseScreen, BudgetScreen, and
  /// any widget displaying budget/gap figures. Null when profile lacks
  /// sufficient data (e.g. no salary).
  final BudgetSnapshot? budgetSnapshot;

  // ── Plan ─────────────────────────────────────────────────────────────────

  /// Today's highest-priority cap. Always computed when profile is present.
  final CapDecision? currentCap;

  /// Ordered IDs of the next caps in queue (after [currentCap]).
  ///
  /// Used by the Plan / CapSequence layer to show "what comes next".
  /// Empty list if no additional caps are ready.
  final List<String> capSequence;

  /// User's declared goal intent tag from [CapMemory.declaredGoals].
  ///
  /// First declared goal, or null if none declared yet.
  /// Format: 'retraite' | 'achat_immo' | etc.
  final String? activeGoalIntentTag;

  // ── Confidence & Progress ─────────────────────────────────────────────────

  /// Projection confidence score (0–100).
  ///
  /// Derived from [ConfidenceScorer.score]. Surfaces data quality to the
  /// user on Pulse and within the Coach context.
  final double confidenceScore;

  /// Financial Resilience Index score (0–100). Null until [hasProjections].
  ///
  /// Measures structural resilience (liquidity, flexibility, replacement,
  /// stability). Distinct from FFS (which measures habits/behavior).
  final double? friScore;

  /// Retirement income replacement rate as a percentage (0–100).
  ///
  /// Computed by [RetirementProjectionService]. Null until [hasProjections].
  final double? replacementRate;

  // ── Memory ────────────────────────────────────────────────────────────────

  /// CapEngine persistent memory (served caps, completed actions, friction).
  final CapMemory capMemory;

  /// Active proactive nudges sorted by priority (high first).
  ///
  /// Pre-filtered for dismissed/expired nudges by [MintStateEngine].
  final List<Nudge> activeNudges;

  /// Proactive trigger to present when Coach tab opens. Null if none applies.
  ///
  /// Evaluated with a per-day cooldown by [ProactiveTriggerService].
  final ProactiveTrigger? pendingTrigger;

  // ── Metadata ─────────────────────────────────────────────────────────────

  /// When this state snapshot was assembled.
  final DateTime computedAt;

  // ── Constructor ──────────────────────────────────────────────────────────

  const MintUserState({
    required this.profile,
    required this.lifecyclePhase,
    required this.archetype,
    this.budgetGap,
    this.budgetSnapshot,
    this.currentCap,
    this.capSequence = const [],
    this.activeGoalIntentTag,
    required this.confidenceScore,
    this.friScore,
    this.replacementRate,
    required this.capMemory,
    this.activeNudges = const [],
    this.pendingTrigger,
    required this.computedAt,
  });

  // ── Derived flags ─────────────────────────────────────────────────────────

  /// True when a full [BudgetSnapshot] has been computed.
  bool get hasBudgetSnapshot => budgetSnapshot != null;

  /// Convenience: monthly free margin from [BudgetSnapshot.present.monthlyFree].
  ///
  /// Null when [budgetSnapshot] is null (no salary or degraded computation).
  double? get monthlyFree => budgetSnapshot?.present.monthlyFree;

  /// True when a budget gap projection is available.
  ///
  /// Requires: salary + LPP avoir + AVS estimate computed.
  bool get hasProjections => budgetGap != null;

  /// True when a retirement income projection has been computed.
  ///
  /// Alias for [hasProjections] — both require the same data.
  bool get hasRetirement => budgetGap != null;

  /// True when the budget gap is computed and has meaningful data.
  bool get hasGap => budgetGap != null;

  /// True when the user has an active cap to surface.
  bool get hasCap => currentCap != null;

  /// True when there are active nudges to display.
  bool get hasNudges => activeNudges.isNotEmpty;

  /// True when a proactive trigger is waiting to fire.
  bool get hasPendingTrigger => pendingTrigger != null;

  /// True when confidence is high enough for projections to be meaningful.
  ///
  /// Threshold: 45 pts (same as CapEngine §1 blocking threshold).
  bool get isConfidenceSufficient => confidenceScore >= 45.0;

  /// True when a replacement rate below 80% signals a significant gap.
  ///
  /// Rule of thumb: 80% replacement preserves living standard (Swiss norm).
  bool get hasSignificantGap {
    final rate = replacementRate;
    return rate != null && rate < 80.0;
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  /// Sentinel for distinguishing "not provided" from "explicitly set to null".
  static const _undefined = Object();

  /// Return a copy with selected fields replaced.
  ///
  /// To reset a nullable field to null, pass `null` explicitly.
  /// Uses sentinel pattern to distinguish "not provided" from "set to null".
  MintUserState copyWith({
    CoachProfile? profile,
    LifecyclePhase? lifecyclePhase,
    FinancialArchetype? archetype,
    Object? budgetGap = _undefined,
    Object? budgetSnapshot = _undefined,
    Object? currentCap = _undefined,
    List<String>? capSequence,
    Object? activeGoalIntentTag = _undefined,
    double? confidenceScore,
    Object? friScore = _undefined,
    Object? replacementRate = _undefined,
    CapMemory? capMemory,
    List<Nudge>? activeNudges,
    Object? pendingTrigger = _undefined,
    DateTime? computedAt,
  }) {
    return MintUserState(
      profile: profile ?? this.profile,
      lifecyclePhase: lifecyclePhase ?? this.lifecyclePhase,
      archetype: archetype ?? this.archetype,
      budgetGap: budgetGap == _undefined
          ? this.budgetGap
          : budgetGap as RetirementBudgetGap?,
      budgetSnapshot: budgetSnapshot == _undefined
          ? this.budgetSnapshot
          : budgetSnapshot as BudgetSnapshot?,
      currentCap: currentCap == _undefined
          ? this.currentCap
          : currentCap as CapDecision?,
      capSequence: capSequence ?? this.capSequence,
      activeGoalIntentTag: activeGoalIntentTag == _undefined
          ? this.activeGoalIntentTag
          : activeGoalIntentTag as String?,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      friScore: friScore == _undefined
          ? this.friScore
          : friScore as double?,
      replacementRate: replacementRate == _undefined
          ? this.replacementRate
          : replacementRate as double?,
      capMemory: capMemory ?? this.capMemory,
      activeNudges: activeNudges ?? this.activeNudges,
      pendingTrigger: pendingTrigger == _undefined
          ? this.pendingTrigger
          : pendingTrigger as ProactiveTrigger?,
      computedAt: computedAt ?? this.computedAt,
    );
  }
}
