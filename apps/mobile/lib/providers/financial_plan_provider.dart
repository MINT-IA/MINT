import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/financial_plan_calculator.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

// ────────────────────────────────────────────────────────────────────────────
//  FinancialPlanProvider — persisted plan + live ledger staleness boundary
// ────────────────────────────────────────────────────────────────────────────

class FinancialPlanProvider extends ChangeNotifier with WidgetsBindingObserver {
  FinancialPlanProvider({
    DateTime Function()? clock,
    Timer Function(Duration, void Function())? timerFactory,
    SessionEpoch? sessionEpoch,
    Future<FinancialPlan?> Function()? loadAction,
    Future<void> Function(FinancialPlan)? saveAction,
  })  : _clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new,
        _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _loadAction = loadAction ?? FinancialPlanService.loadCurrent,
        _saveAction = saveAction ?? FinancialPlanService.save {
    WidgetsBinding.instance.addObserver(this);
  }

  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _timerFactory;
  final SessionEpoch _sessionEpoch;
  final Future<FinancialPlan?> Function() _loadAction;
  final Future<void> Function(FinancialPlan) _saveAction;
  FinancialPlan? _currentPlan;
  bool _isStale = false;
  bool _disposed = false;
  Timer? _expiryTimer;

  CoachProfileProvider? _profileProvider;
  ValueListenable<int>? _regulatoryRevisionListenable;
  int _regulatoryRevision = 0;
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

  @visibleForTesting
  bool get debugHasRegulatoryRevisionListener =>
      _regulatoryRevisionListenable != null;

  /// Captured by multi-await confirmation UI before its first await.
  SessionEpochGuard captureAccountSession() => _sessionEpoch.capture();

  /// Hydrates the newest persisted plan exactly once for this provider.
  ///
  /// A plan written after hydration starts wins over the late disk read. Once
  /// loaded, the persisted fingerprint is immediately reconciled with the
  /// currently bound profile, including on cold start.
  Future<void> loadFromPersistence() {
    return _loadFuture ??= _hydrateFromPersistence(_sessionEpoch.capture());
  }

  Future<void> _hydrateFromPersistence(SessionEpochGuard sessionGuard) async {
    final revisionAtStart = _stateRevision;
    final persisted = await _loadAction();
    try {
      sessionGuard.assertCurrent();
    } on SessionEpochInvalidated {
      return;
    }
    if (_disposed || revisionAtStart != _stateRevision) return;

    _currentPlan = persisted;
    _isStale = _isMismatchWithBoundLedger(persisted);
    _scheduleExpiryIfFresh(persisted);
    _notifyImmediately();
  }

  /// Persists [plan], then publishes it only if no newer plan operation won.
  ///
  /// Saves are serialized so concurrent generations cannot leave an older
  /// invocation as the newest record on disk. The bound ledger is checked
  /// again after the write, because profile facts may change during generation.
  Future<void> setPlan(FinancialPlan plan) async {
    final sessionGuard = _sessionEpoch.capture();
    if (_isMismatchWithBoundLedger(plan)) {
      throw StateError('financial plan dependency authority mismatch');
    }
    final operationRevision = ++_stateRevision;
    final previousSave = _saveQueue;
    final operation = _persistAndPublishAfter(
      previousSave,
      plan,
      operationRevision,
      sessionGuard,
    );
    _saveQueue = operation;
    await operation;
  }

  Future<void> _persistAndPublishAfter(
    Future<void> previousSave,
    FinancialPlan plan,
    int operationRevision,
    SessionEpochGuard sessionGuard,
  ) async {
    try {
      await previousSave;
    } catch (_) {
      // A failed older write must not permanently poison the save queue.
    }
    if (_isMismatchWithBoundLedger(plan)) {
      throw StateError('financial plan dependency changed before persistence');
    }
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => _saveAction(plan),
    );

    // The encrypted-slot service guarantees error+A or success+B. Once B is
    // durable, a ledger change cannot be represented as a failed transaction:
    // a fallible rollback could itself leave thrown+B. Recheck twice around
    // the publication boundary and expose B only through the existing stale
    // gate, which hides every amount and narrative in product surfaces.
    final changedDuringPersistence = _isMismatchWithBoundLedger(plan);
    final changedBeforePublication =
        changedDuringPersistence || _isMismatchWithBoundLedger(plan);

    sessionGuard.assertCurrent();
    if (_disposed || operationRevision != _stateRevision) return;
    _currentPlan = plan;
    _isStale = changedBeforePublication;
    _scheduleExpiryIfFresh(plan);
    _notifyImmediately();
  }

  /// Clear the in-memory plan and reset stale state.
  ///
  /// Persistence remains intact for backward compatibility with existing
  /// callers; a future provider instance may hydrate it again.
  void clearPlan() {
    _stateRevision++;
    _currentPlan = null;
    _isStale = false;
    _expiryTimer?.cancel();
    _expiryTimer = null;
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

  void attachRegulatoryRevision(ValueListenable<int> revisionListenable) {
    if (_disposed) return;
    if (identical(_regulatoryRevisionListenable, revisionListenable)) {
      _regulatoryRevision = revisionListenable.value;
      _reconcileWithBoundProfile();
      return;
    }
    _regulatoryRevisionListenable?.removeListener(_handleRegulatoryRevision);
    _regulatoryRevisionListenable = revisionListenable;
    _regulatoryRevision = revisionListenable.value;
    revisionListenable.addListener(_handleRegulatoryRevision);
    _reconcileWithBoundProfile();
  }

  void detachRegulatoryRevision() {
    _regulatoryRevisionListenable?.removeListener(_handleRegulatoryRevision);
    _regulatoryRevisionListenable = null;
  }

  void _handleRegulatoryRevision() {
    final source = _regulatoryRevisionListenable;
    if (source == null || source.value <= _regulatoryRevision) return;
    _regulatoryRevision = source.value;
    debugPrint('[FinancialPlan] regulatory_revision=$_regulatoryRevision');
    _reconcileWithBoundProfile();
  }

  void _handleProfileChanged() => _reconcileWithBoundProfile();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileWithBoundProfile();
    }
  }

  void _reconcileWithBoundProfile() {
    final stale = _isMismatchWithBoundLedger(_currentPlan);
    if (stale == _isStale) {
      _scheduleExpiryIfFresh(_currentPlan);
      return;
    }
    _isStale = stale;
    _scheduleExpiryIfFresh(_currentPlan);
    _scheduleNotification();
  }

  bool _isMismatchWithBoundLedger(FinancialPlan? plan) {
    if (plan == null) return false;
    final profileProvider = _profileProvider;
    if (profileProvider == null || !profileProvider.isLoaded) return true;
    return _isMismatchWithProfile(plan, profileProvider);
  }

  bool _isMismatchWithProfile(
    FinancialPlan? plan,
    CoachProfileProvider profileProvider,
  ) {
    if (plan == null) return false;
    final profile = profileProvider.profile;
    if (profile == null) return true;
    final owner = profileProvider.canonicalProfileOwnerId;
    final amount = plan.goalAmount;
    final expires = plan.validUntil;
    final now = _clock().toUtc();
    if (!plan.hasValidDependencyEnvelope ||
        !_hasValidFinalConfirmation(plan, now) ||
        owner == null ||
        plan.profileOwnerId != owner ||
        amount == null ||
        expires == null ||
        !now.isBefore(expires.toUtc())) {
      return true;
    }
    try {
      final current = FinancialPlanDependencySnapshot.fromProfile(
        profile,
        profileOwnerId: owner,
        goalCategory: plan.goalCategory,
        goalAmount: amount,
        targetDate: plan.targetDate,
        prospectiveLppReturn: plan.projectionAssumptions?.caisseReturnBase,
        selfLppSnapshot: profileProvider.currentLppSnapshot(
          LppEvidenceOwnerKind.self,
        ),
        now: now,
      );
      final liveMismatch = current.profileOwnerId != plan.profileOwnerId ||
          current.schemaVersion != plan.dependencySchemaVersion ||
          current.branch.wireName != plan.dependencyBranch ||
          current.basis.wireName != plan.dependencyBasis ||
          current.fingerprint != plan.dependencyHash ||
          current.validUntil.toUtc() != expires.toUtc() ||
          current.confidenceLevel != plan.confidenceLevel ||
          (current.branch == FinancialPlanDependencyBranch.retirementLpp &&
              current.grossAnnualSalary !=
                  plan.projectionAssumptions?.salaryBasis.annualChf);
      if (liveMismatch) {
        return true;
      }

      final inputAsOf = plan.inputAsOf!.toUtc();
      final original = FinancialPlanDependencySnapshot.fromProfile(
        profile,
        profileOwnerId: owner,
        goalCategory: plan.goalCategory,
        goalAmount: amount,
        targetDate: plan.targetDate,
        prospectiveLppReturn: plan.projectionAssumptions?.caisseReturnBase,
        selfLppSnapshot: profileProvider.currentLppSnapshot(
          LppEvidenceOwnerKind.self,
        ),
        now: inputAsOf,
      );
      if (original.fingerprint != plan.dependencyHash ||
          original.validUntil.toUtc() != expires.toUtc()) {
        return true;
      }
      final replay = FinancialPlanCalculator.calculate(
        goalCategory: plan.goalCategory,
        goalAmount: amount,
        targetDate: plan.targetDate,
        now: inputAsOf,
        inputs: original,
        prospectiveLppReturn: original.prospectiveLppReturn,
      );
      return !_matchesReplay(plan, replay);
    } on ArgumentError {
      return true;
    } on StateError {
      return true;
    }
  }

  bool _matchesReplay(
    FinancialPlan plan,
    FinancialPlanCalculation replay,
  ) {
    return plan.monthlyTarget == replay.monthlyTarget &&
        plan.projectedOutcome == replay.projectedOutcome &&
        plan.projectedLow == replay.projectedLow &&
        plan.projectedHigh == replay.projectedHigh &&
        _milestonesMatch(plan.milestones, replay.milestones) &&
        _stringsMatch(plan.sources, replay.sources) &&
        _assumptionsMatch(
          plan.projectionAssumptions,
          replay.projectionAssumptions,
        );
  }

  bool _milestonesMatch(
    List<PlanMilestone> persisted,
    List<PlanMilestone> replayed,
  ) {
    if (persisted.length != replayed.length) return false;
    for (var index = 0; index < persisted.length; index++) {
      final left = persisted[index];
      final right = replayed[index];
      if (left.targetDate.toUtc() != right.targetDate.toUtc() ||
          left.targetAmount != right.targetAmount ||
          left.description != right.description) {
        return false;
      }
    }
    return true;
  }

  bool _stringsMatch(List<String> persisted, List<String> replayed) {
    if (persisted.length != replayed.length) return false;
    for (var index = 0; index < persisted.length; index++) {
      if (persisted[index] != replayed[index]) return false;
    }
    return true;
  }

  bool _assumptionsMatch(
    FinancialPlanProjectionAssumptions? persisted,
    FinancialPlanProjectionAssumptions? replayed,
  ) {
    if (persisted == null || replayed == null) {
      return persisted == null && replayed == null;
    }
    return persisted.caisseReturnBase == replayed.caisseReturnBase &&
        persisted.caisseReturnLow == replayed.caisseReturnLow &&
        persisted.caisseReturnHigh == replayed.caisseReturnHigh &&
        persisted.supplementalMonthlySavingsReturn ==
            replayed.supplementalMonthlySavingsReturn &&
        persisted.salaryBasis.kind == replayed.salaryBasis.kind &&
        persisted.salaryBasis.annualChf == replayed.salaryBasis.annualChf &&
        persisted.bonificationBasis.kind == replayed.bonificationBasis.kind &&
        persisted.bonificationBasis.annualRate ==
            replayed.bonificationBasis.annualRate &&
        persisted.annualProjectionUsesWholeYears ==
            replayed.annualProjectionUsesWholeYears &&
        persisted.requiresFundAuthorizationBefore63 ==
            replayed.requiresFundAuthorizationBefore63 &&
        persisted.assumesPostReferenceGainfulActivity ==
            replayed.assumesPostReferenceGainfulActivity &&
        persisted.projectionAsOf.toUtc() == replayed.projectionAsOf.toUtc();
  }

  bool _hasValidFinalConfirmation(FinancialPlan plan, DateTime now) {
    final confirmedAt = plan.confirmedAt?.toUtc();
    final inputAsOf = plan.inputAsOf?.toUtc();
    final validUntil = plan.validUntil?.toUtc();
    final generatedAt = plan.generatedAt.toUtc();
    return confirmedAt != null &&
        inputAsOf != null &&
        validUntil != null &&
        !confirmedAt.isBefore(generatedAt) &&
        !confirmedAt.isBefore(inputAsOf) &&
        !confirmedAt.isAfter(now) &&
        confirmedAt.isBefore(validUntil);
  }

  void _scheduleExpiryIfFresh(FinancialPlan? plan) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final deadline = plan?.validUntil?.toUtc();
    if (_disposed || plan == null || _isStale || deadline == null) return;
    final delay = deadline.difference(_clock().toUtc());
    _expiryTimer = _timerFactory(
      delay.isNegative ? Duration.zero : delay,
      () => _handleExpiryTimer(plan, deadline),
    );
  }

  void _handleExpiryTimer(FinancialPlan expectedPlan, DateTime deadline) {
    _expiryTimer = null;
    if (_disposed || !identical(_currentPlan, expectedPlan)) return;
    if (_clock().toUtc().isBefore(deadline)) {
      _scheduleExpiryIfFresh(expectedPlan);
      return;
    }
    if (!_isStale) {
      _isStale = true;
      _notifyImmediately();
    }
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
    _scheduleExpiryIfFresh(plan);
    _notifyImmediately();
  }

  /// Synchronously reconcile against [profile]. Used in tests only.
  @visibleForTesting
  void checkStalenessForTest(CoachProfile? profile) {
    final profileProvider = _profileProvider;
    _isStale = profileProvider == null || profileProvider.profile != profile
        ? true
        : _isMismatchWithProfile(_currentPlan, profileProvider);
    _scheduleExpiryIfFresh(_currentPlan);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notificationGeneration++;
    _notificationScheduled = false;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _profileProvider?.removeListener(_handleProfileChanged);
    _profileProvider = null;
    detachRegulatoryRevision();
    super.dispose();
  }
}
