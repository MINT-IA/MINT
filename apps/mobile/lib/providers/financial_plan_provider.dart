import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';

// ────────────────────────────────────────────────────────────────────────────
//  FinancialPlanProvider — persisted plan + live ledger staleness boundary
// ────────────────────────────────────────────────────────────────────────────

class FinancialPlanProvider extends ChangeNotifier {
  FinancialPlan? _currentPlan;
  bool _isStale = false;
  bool _disposed = false;

  CoachProfileProvider? _profileProvider;
  Future<void>? _loadFuture;
  Future<void> _saveQueue = Future<void>.value();
  int _stateRevision = 0;
  int _notificationGeneration = 0;
  bool _notificationScheduled = false;

  /// The currently loaded plan, or null if no plan exists.
  FinancialPlan? get currentPlan => _currentPlan;

  /// True if a plan is loaded.
  bool get hasPlan => _currentPlan != null;

  /// True if the plan fingerprint differs from the bound ledger snapshot.
  bool get isPlanStale => _isStale;

  /// Hydrates the newest persisted plan exactly once for this provider.
  ///
  /// A plan written after hydration starts wins over the late disk read. Once
  /// loaded, the persisted fingerprint is immediately reconciled with the
  /// currently bound profile, including on cold start.
  Future<void> loadFromPersistence() {
    return _loadFuture ??= _hydrateFromPersistence();
  }

  Future<void> _hydrateFromPersistence() async {
    final revisionAtStart = _stateRevision;
    final persisted = await FinancialPlanService.loadCurrent();
    if (_disposed || revisionAtStart != _stateRevision) return;

    _currentPlan = persisted;
    _isStale = _isMismatchWithBoundLedger(persisted);
    _notifyImmediately();
  }

  /// Persists [plan], then publishes it only if no newer plan operation won.
  ///
  /// Saves are serialized so concurrent generations cannot leave an older
  /// invocation as the newest record on disk. The bound ledger is checked
  /// again after the write, because profile facts may change during generation.
  Future<void> setPlan(FinancialPlan plan) async {
    final operationRevision = ++_stateRevision;
    final previousSave = _saveQueue;
    final operation = _persistAfter(previousSave, plan);
    _saveQueue = operation;

    await operation;
    if (_disposed || operationRevision != _stateRevision) return;

    _currentPlan = plan;
    _isStale = _isMismatchWithBoundLedger(plan);
    _notifyImmediately();
  }

  Future<void> _persistAfter(
    Future<void> previousSave,
    FinancialPlan plan,
  ) async {
    try {
      await previousSave;
    } catch (_) {
      // A failed older write must not permanently poison the save queue.
    }
    await FinancialPlanService.save(plan);
  }

  /// Clear the in-memory plan and reset stale state.
  ///
  /// Persistence remains intact for backward compatibility with existing
  /// callers; a future provider instance may hydrate it again.
  void clearPlan() {
    _stateRevision++;
    _currentPlan = null;
    _isStale = false;
    _notifyImmediately();
  }

  /// Explicitly fail closed for a loaded plan.
  void markStale() {
    if (_currentPlan != null && !_isStale) {
      _isStale = true;
      _notifyImmediately();
    }
  }

  /// Bind staleness detection to one canonical ledger provider.
  ///
  /// Binding is immediate and idempotent. Rebinding removes the exact previous
  /// listener before attaching the new provider, so old ledgers cannot mutate
  /// this provider and disposal cannot leave an orphaned callback.
  void attachProfileProvider(CoachProfileProvider profileProvider) {
    if (_disposed) return;
    if (identical(_profileProvider, profileProvider)) {
      _reconcileWithBoundProfile();
      return;
    }

    _profileProvider?.removeListener(_handleProfileChanged);
    _profileProvider = profileProvider;
    profileProvider.addListener(_handleProfileChanged);
    _reconcileWithBoundProfile();
  }

  void _handleProfileChanged() => _reconcileWithBoundProfile();

  void _reconcileWithBoundProfile() {
    final stale = _isMismatchWithBoundLedger(_currentPlan);
    if (stale == _isStale) return;
    _isStale = stale;
    _scheduleNotification();
  }

  bool _isMismatchWithBoundLedger(FinancialPlan? plan) {
    if (plan == null) return false;
    final profileProvider = _profileProvider;
    if (profileProvider == null || !profileProvider.isLoaded) return true;
    return _isMismatchWithProfile(plan, profileProvider.profile);
  }

  bool _isMismatchWithProfile(FinancialPlan? plan, CoachProfile? profile) {
    if (plan == null) return false;
    if (profile == null) return true;
    return plan.profileHashAtGeneration != computeProfileHash(profile);
  }

  void _scheduleNotification() {
    if (_disposed || _notificationScheduled) return;
    _notificationScheduled = true;
    final generation = ++_notificationGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _notificationGeneration) return;
      _notificationScheduled = false;
      notifyListeners();
    });
  }

  void _notifyImmediately() {
    if (_disposed) return;
    _notificationGeneration++;
    _notificationScheduled = false;
    notifyListeners();
  }

  /// Set plan directly without persistence. Used in tests only.
  @visibleForTesting
  void setPlanDirect(FinancialPlan plan) {
    _stateRevision++;
    _currentPlan = plan;
    // This test-only setter predates ledger binding. Preserve its isolated
    // setup behavior; attaching a provider immediately reconciles authority.
    _isStale =
        _profileProvider == null ? false : _isMismatchWithBoundLedger(plan);
    _notifyImmediately();
  }

  /// Synchronously reconcile against [profile]. Used in tests only.
  @visibleForTesting
  void checkStalenessForTest(CoachProfile? profile) {
    _isStale = _isMismatchWithProfile(_currentPlan, profile);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notificationGeneration++;
    _notificationScheduled = false;
    _profileProvider?.removeListener(_handleProfileChanged);
    _profileProvider = null;
    super.dispose();
  }
}
