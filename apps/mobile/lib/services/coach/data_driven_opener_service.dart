// ────────────────────────────────────────────────────────────
//  DATA-DRIVEN OPENER SERVICE — S52 / Phase 1 "Le Conversationnel"
// ────────────────────────────────────────────────────────────
//
// Generates a data-driven opening line from the user's current
// financial state. Inspired by Cleo 3.0's personalised openers,
// adapted for Swiss financial education (LSFin compliant).
//
// Design:
//  - Pure function — no side effects, deterministic, testable.
//  - Returns null when no interesting data point is found.
//  - Always surfaces a REAL CHF number from the user's profile.
//  - Priority: deficit > deadline > gap > savings > celebration > plan.
//
// Compliance:
//  - No banned terms (garanti, certain, assuré, sans risque,
//    optimal, meilleur, parfait, conseiller).
//  - No social comparison.
//  - All user-facing text via ARB keys.
//  - Non-breaking space (\u00a0) before !, ?, :, ;, %.
//  - Educational tone — conditional language only.
// ────────────────────────────────────────────────────────────
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// The type of data-driven opener to display.
enum DataOpenerType {
  /// Monthly spending deficit detected.
  budgetAlert,

  /// December and 3a has not been maxed this year.
  deadlineUrgency,

  /// Replacement rate below 60 % — significant retirement gap.
  gapWarning,

  /// 3a balance is CHF 0 and salary > 0 — missed tax saving.
  savingsOpportunity,

  /// Confidence score improved by 5+ points since last session.
  progressCelebration,

  /// A CapSequence step was just completed.
  planProgress,
}

// ════════════════════════════════════════════════════════════════
//  MODEL
// ════════════════════════════════════════════════════════════════

/// A data-driven coach opening line with an optional follow-up intent.
class DataDrivenOpener {
  /// Fully resolved, i18n-ready message containing real CHF/% numbers.
  final String message;

  /// Optional GoRouter intent tag to offer as the first suggestion chip.
  /// Null when no direct follow-up route applies.
  final String? intentTag;

  /// The type of opener for classification and analytics.
  final DataOpenerType type;

  const DataDrivenOpener({
    required this.message,
    this.intentTag,
    required this.type,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Generates data-driven coach opening lines from [MintUserState].
///
/// Priority order (highest first):
///  1. [DataOpenerType.budgetAlert]       — monthly deficit
///  2. [DataOpenerType.deadlineUrgency]   — December, 3a not maxed
///  3. [DataOpenerType.gapWarning]        — replacement rate < 60%
///  4. [DataOpenerType.savingsOpportunity]— 3a = 0 and salary > 0
///  5. [DataOpenerType.progressCelebration] — confidence +5 pts
///  6. [DataOpenerType.planProgress]      — CapSequence step completed
///
/// Returns null when no condition produces a meaningful data point.
///
/// Pure function — all side effects belong to the caller.
class DataDrivenOpenerService {
  DataDrivenOpenerService._();

  // ── Thresholds ────────────────────────────────────────────

  /// Replacement rate below this percentage triggers [DataOpenerType.gapWarning].
  static const double _gapWarningThreshold = 60.0;

  /// Confidence score delta (points) that triggers [DataOpenerType.progressCelebration].
  static const double _confidenceDeltaThreshold = 5.0;

  /// Minimum salary (annual, CHF) to consider 3a savings opportunity.
  static const double _minSalaryForSavings = 1.0;

  /// 3a plafond for salariés with LPP access (OPP3 2025/2026).
  static double get _plafond3aSalarie => reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);

  // ── Public API ────────────────────────────────────────────

  /// Generate a data-driven opening line from the user's current state.
  ///
  /// [state]  — unified user state (from [MintStateProvider]).
  /// [l]      — resolved localizations (call [S.of(context)!] before passing).
  /// [now]    — override for deterministic testing (defaults to [DateTime.now]).
  /// [previousConfidenceScore] — confidence score from last session to compute delta.
  ///
  /// Returns null when no interesting data point exists.
  static DataDrivenOpener? generate({
    required MintUserState state,
    required S l,
    DateTime? now,
    double? previousConfidenceScore,
  }) {
    final currentDate = now ?? DateTime.now();

    // Priority 1: Budget deficit
    final deficitOpener = _checkBudgetDeficit(state, l);
    if (deficitOpener != null) return deficitOpener;

    // Priority 2: 3a deadline (December)
    final deadlineOpener = _checkDeadlineUrgency(state, l, currentDate);
    if (deadlineOpener != null) return deadlineOpener;

    // Priority 3: Gap warning
    final gapOpener = _checkGapWarning(state, l);
    if (gapOpener != null) return gapOpener;

    // Priority 4: Savings opportunity (3a = 0)
    final savingsOpener = _checkSavingsOpportunity(state, l);
    if (savingsOpener != null) return savingsOpener;

    // Priority 5: Progress celebration
    final celebrationOpener =
        _checkProgressCelebration(state, l, previousConfidenceScore);
    if (celebrationOpener != null) return celebrationOpener;

    // Priority 6: Plan progress
    final planOpener = _checkPlanProgress(state, l);
    if (planOpener != null) return planOpener;

    return null;
  }

  // ── Priority 1: Budget deficit ─────────────────────────────

  static DataDrivenOpener? _checkBudgetDeficit(
    MintUserState state,
    S l,
  ) {
    final snapshot = state.budgetSnapshot;
    if (snapshot == null) return null;
    if (!snapshot.present.isDeficit) return null;

    final deficit = snapshot.present.monthlyFree.abs().round();
    if (deficit <= 0) return null;

    return DataDrivenOpener(
      message: l.openerBudgetDeficit(deficit.toString()),
      intentTag: '/budget',
      type: DataOpenerType.budgetAlert,
    );
  }

  // ── Priority 2: 3a deadline (December) ────────────────────

  static DataDrivenOpener? _checkDeadlineUrgency(
    MintUserState state,
    S l,
    DateTime now,
  ) {
    // Only fires in December (days 1–31).
    if (now.month != DateTime.december) return null;

    // Only fires if 3a has not been maxed.
    final epargne3a = state.profile.prevoyance.totalEpargne3a;
    // We check yearly contributions rather than total balance.
    // If total savings < plafond, the user likely has room this year.
    // (More precise: check YTD contributions, but we use totalEpargne3a as proxy.)
    // Trigger if user has salary and 3a savings look un-contributed this year.
    final hasSalary = state.profile.revenuBrutAnnuel > _minSalaryForSavings;
    if (!hasSalary) return null;

    // Check canContribute3a flag (FATCA compliance: US persons may be blocked).
    if (!state.profile.prevoyance.canContribute3a) return null;

    // Use plafond based on employment status.
    final isIndepNoLpp = state.archetype ==
            FinancialArchetype.independentNoLpp;
    final plafond = isIndepNoLpp
        ? reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp)
        : _plafond3aSalarie;

    // If this year's balance already looks full, skip.
    // Heuristic: if 3a total is a round multiple of plafond this year is done.
    // We cannot know YTD contributions precisely without bank data, so we
    // surface the reminder and let the user confirm.
    // Always surface if epargne3a == 0 (handled by savings opportunity above).
    // Here we handle the partial case: 0 < epargne3a < plafond.
    if (epargne3a >= plafond) return null;

    final daysLeft = DateTime(now.year, 12, 31).difference(now).inDays + 1;
    if (daysLeft <= 0) return null;

    return DataDrivenOpener(
      message: l.opener3aDeadline(
        daysLeft.toString(),
        plafond.round().toString(),
      ),
      intentTag: '/pilier-3a',
      type: DataOpenerType.deadlineUrgency,
    );
  }

  // ── Priority 3: Gap warning ────────────────────────────────

  static DataDrivenOpener? _checkGapWarning(
    MintUserState state,
    S l,
  ) {
    final rate = state.replacementRate;
    if (rate == null) return null;
    if (rate >= _gapWarningThreshold) return null;

    final gap = state.budgetSnapshot?.gap?.monthlyGap;
    if (gap == null || gap <= 0) return null;

    return DataDrivenOpener(
      message: l.openerGapWarning(
        rate.round().toString(),
        gap.round().toString(),
      ),
      intentTag: '/retraite',
      type: DataOpenerType.gapWarning,
    );
  }

  // ── Priority 4: Savings opportunity ───────────────────────

  static DataDrivenOpener? _checkSavingsOpportunity(
    MintUserState state,
    S l,
  ) {
    final epargne3a = state.profile.prevoyance.totalEpargne3a;
    if (epargne3a > 0) return null;

    final hasSalary = state.profile.revenuBrutAnnuel > _minSalaryForSavings;
    if (!hasSalary) return null;

    if (!state.profile.prevoyance.canContribute3a) return null;

    final isIndepNoLpp = state.archetype ==
            FinancialArchetype.independentNoLpp;
    final plafond = isIndepNoLpp
        ? reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp)
        : _plafond3aSalarie;

    return DataDrivenOpener(
      message: l.openerSavingsOpportunity(plafond.round().toString()),
      intentTag: '/pilier-3a',
      type: DataOpenerType.savingsOpportunity,
    );
  }

  // ── Priority 5: Progress celebration ──────────────────────

  static DataDrivenOpener? _checkProgressCelebration(
    MintUserState state,
    S l,
    double? previousConfidenceScore,
  ) {
    if (previousConfidenceScore == null) return null;

    final delta = state.confidenceScore - previousConfidenceScore;
    if (delta < _confidenceDeltaThreshold) return null;

    return DataDrivenOpener(
      message: l.openerProgressCelebration(delta.round().toString()),
      intentTag: '/profile',
      type: DataOpenerType.progressCelebration,
    );
  }

  // ── Priority 6: Plan progress ──────────────────────────────

  static DataDrivenOpener? _checkPlanProgress(
    MintUserState state,
    S l,
  ) {
    final sequence = state.capSequencePlan;
    if (sequence == null) return null;
    if (!sequence.hasSteps) return null;
    if (sequence.completedCount == 0) return null;

    final nextStep = _resolveNextStepLabel(sequence, l);
    if (nextStep == null) return null;

    return DataDrivenOpener(
      message: l.openerPlanProgress(
        sequence.completedCount.toString(),
        sequence.totalCount.toString(),
        nextStep,
      ),
      intentTag: sequence.currentStep?.intentTag,
      type: DataOpenerType.planProgress,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Resolve the next step title key from [sequence] using [l].
  ///
  /// Returns null if no next step exists or the key cannot be resolved.
  static String? _resolveNextStepLabel(CapSequence sequence, S l) {
    final next = sequence.currentStep ?? sequence.nextStep;
    if (next == null) return null;
    // Resolution via switch on known step title keys.
    // Unknown keys fall back to the step id (non-user-facing, developer signal).
    return _resolveCapStepTitleKey(next.titleKey, l) ?? next.id;
  }

  /// Resolve a CapStep [titleKey] ARB key to a human-readable label.
  ///
  /// Public so [PrecomputedInsightsService] can resolve stored titleKeys at
  /// display time using the real locale without re-importing private helpers.
  ///
  /// This method handles a representative subset of known cap step title keys.
  /// Keys that are not explicitly matched return null — callers should handle
  /// null gracefully (e.g. fall back to the step id).
  static String? resolveCapStepTitle(String key, S l) =>
      _resolveCapStepTitleKey(key, l);

  static String? _resolveCapStepTitleKey(String key, S l) {
    // Use a try/catch per switch branch since ARB methods are non-nullable;
    // any missing key would throw rather than return null.
    try {
      switch (key) {
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
        case 'capStepRetirement08Title':
          return l.capStepRetirement08Title;
        case 'capStepRetirement09Title':
          return l.capStepRetirement09Title;
        case 'capStepRetirement10Title':
          return l.capStepRetirement10Title;
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
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
