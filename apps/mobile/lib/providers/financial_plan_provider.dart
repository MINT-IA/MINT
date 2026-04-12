import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';

// ────────────────────────────────────────────────────────────────────────────
//  FinancialPlanProvider — Reactive state for the current financial plan
//
//  Exposes:
//    - currentPlan: the current persisted FinancialPlan (or null)
//    - hasPlan: true if a plan is loaded
//    - isPlanStale: true if the CoachProfile hash has changed since generation
//
//  Staleness detection uses computeProfileHash() — a deterministic polynomial
//  hash that does NOT use Object.hash (unstable across sessions).
//
//  setState-during-build is avoided by calling notifyListeners() inside
//  SchedulerBinding.addPostFrameCallback when triggered from a profile listener.
// ────────────────────────────────────────────────────────────────────────────

class FinancialPlanProvider extends ChangeNotifier {
  FinancialPlan? _currentPlan;
  bool _isStale = false;

  // ── Public getters ──────────────────────────────────────────────────────

  /// The currently loaded plan, or null if no plan exists.
  FinancialPlan? get currentPlan => _currentPlan;

  /// True if a plan is loaded.
  bool get hasPlan => _currentPlan != null;

  /// True if the CoachProfile has changed since the plan was generated.
  bool get isPlanStale => _isStale;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Load the newest persisted plan from SharedPreferences.
  Future<void> loadFromPersistence() async {
    _currentPlan = await FinancialPlanService.loadCurrent();
    notifyListeners();
  }

  /// Save [plan] via [FinancialPlanService], set as current, and clear stale flag.
  Future<void> setPlan(FinancialPlan plan) async {
    await FinancialPlanService.save(plan);
    _currentPlan = plan;
    _isStale = false;
    notifyListeners();
  }

  /// Clear the current plan and reset stale state. Does not delete persistence.
  void clearPlan() {
    _currentPlan = null;
    _isStale = false;
    notifyListeners();
  }

  /// Mark the current plan as stale (profile changed).
  void markStale() {
    if (!_isStale) {
      _isStale = true;
      notifyListeners();
    }
  }

  // ── Profile staleness detection ─────────────────────────────────────────

  /// Attach to a [CoachProfileProvider] to auto-detect staleness.
  ///
  /// Each time the profile changes, [_checkStaleness] is called.
  /// notifyListeners is deferred to postFrameCallback to avoid
  /// setState-during-build errors.
  void attachProfileProvider(CoachProfileProvider profileProvider) {
    profileProvider.addListener(() {
      _checkStaleness(profileProvider.profile);
    });
  }

  /// Compare current profile hash to [_currentPlan.profileHashAtGeneration].
  ///
  /// If mismatch and not already stale, set _isStale and notify listeners
  /// inside SchedulerBinding.addPostFrameCallback.
  void _checkStaleness(CoachProfile? profile) {
    if (_currentPlan == null || profile == null) return;

    final currentHash = computeProfileHash(profile);
    if (currentHash != _currentPlan!.profileHashAtGeneration && !_isStale) {
      _isStale = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // ── Test helpers ─────────────────────────────────────────────────────────

  /// Set plan directly without persistence. Used in tests only.
  @visibleForTesting
  void setPlanDirect(FinancialPlan plan) {
    _currentPlan = plan;
    _isStale = false;
    notifyListeners();
  }

  /// Synchronously trigger staleness check. Used in tests only.
  @visibleForTesting
  void checkStalenessForTest(CoachProfile? profile) {
    if (_currentPlan == null || profile == null) return;
    final currentHash = computeProfileHash(profile);
    if (currentHash != _currentPlan!.profileHashAtGeneration && !_isStale) {
      _isStale = true;
    }
  }
}
