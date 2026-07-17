import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import '../../domain/budget/budget_inputs.dart';
import '../../domain/budget/budget_plan.dart';
import '../../domain/budget/budget_service.dart';
import '../../data/budget/budget_local_store.dart';
import '../../services/session_epoch.dart';

class BudgetProvider with ChangeNotifier {
  BudgetProvider({SessionEpoch? sessionEpoch})
      : _sessionEpoch = sessionEpoch ?? SessionEpoch();

  final BudgetService _service = BudgetService();
  final BudgetLocalStore _store = BudgetLocalStore();
  final SessionEpoch _sessionEpoch;

  BudgetPlan? _currentPlan;
  BudgetInputs? _lastInputs;
  CoachProfile? _boundProfile;
  final Map<String, double> _overrides = {};

  BudgetPlan? get plan => _currentPlan;
  BudgetInputs? get inputs => _lastInputs;

  /// Restore UI-only envelope overrides without replacing ledger inputs.
  ///
  /// `budget_inputs_v1` is a legacy derived cache, never a source of truth.
  /// The linked [CoachProfile] remains authoritative across cold starts.
  Future<bool> loadFromStorage() async {
    try {
      final guard = _sessionEpoch.capture();
      return await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _loadFromStorage(guard),
      );
    } on SessionEpochInvalidated {
      return false;
    }
  }

  Future<bool> _loadFromStorage(SessionEpochGuard guard) async {
    final savedFuture = await _store.getOverride('future');
    final savedVariables = await _store.getOverride('variables');
    bool changed;
    if (savedFuture != null && savedVariables != null) {
      // Legacy pairs used future precedence. Preserve that visible result
      // once, then normalize storage to the single-winner invariant.
      changed = (_overrides.remove('variables') != null) |
          _setStoredOverride('future', savedFuture);
      await _store.saveExclusiveOverride('future', savedFuture);
    } else {
      changed = _setStoredOverride('future', savedFuture) |
          _setStoredOverride('variables', savedVariables);
    }
    await _store.discardLegacyInputs();
    guard.assertCurrent();
    if (changed && _lastInputs != null) {
      _recalculate();
    }
    return _lastInputs != null;
  }

  Future<void> waitForOverridePersistence() {
    final guard = _sessionEpoch.capture();
    return _sessionEpoch.runGuardedPersistence(
      guard,
      _store.waitForOverridePersistence,
    );
  }

  void updateOverride(String key, double value) {
    final guard = _sessionEpoch.capture();
    final opposite = key == 'future' ? 'variables' : 'future';
    _overrides.remove(opposite);
    _overrides[key] = value;
    _recalculate();
    // The last edited envelope owns the split; contradictory pairs are
    // purged from storage instead of relying on BudgetService precedence.
    _sessionEpoch
        .runGuardedPersistence(
          guard,
          () => _store.saveExclusiveOverride(key, value),
        )
        .ignore();
  }

  /// Rehydrate synchronously from the canonical profile.
  ///
  /// The production proxy calls this on every profile publication. Repeated
  /// notifications carrying the same immutable profile are idempotent.
  void rehydrateFromProfile(CoachProfile profile) {
    if (_sessionEpoch.isTerminationBlocked) return;
    if (identical(_boundProfile, profile)) return;
    _boundProfile = profile;
    final inputs = BudgetInputs.fromCoachProfile(profile);
    _lastInputs = inputs;
    _currentPlan = _service.computePlan(inputs, overrides: _overrides);
    notifyListeners();
  }

  /// Efface le budget (Reset / Supprimer mes données)
  Future<void> clear() async {
    await purgeSessionPersistence();
    clearSessionMemoryAfterPurge();
  }

  Future<void> purgeSessionPersistence() => _store.clear();

  void clearSessionMemoryAfterPurge() {
    _lastInputs = null;
    _currentPlan = null;
    _boundProfile = null;
    _overrides.clear();
    notifyListeners();
  }

  void _recalculate() {
    if (_lastInputs == null) return;
    _currentPlan = _service.computePlan(_lastInputs!, overrides: _overrides);
    notifyListeners();
  }

  bool _setStoredOverride(String key, double? value) {
    if (value == null) return false;
    if (_overrides[key] == value) return false;
    _overrides[key] = value;
    return true;
  }
}
