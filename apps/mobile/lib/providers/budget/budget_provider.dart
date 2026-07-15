import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import '../../domain/budget/budget_inputs.dart';
import '../../domain/budget/budget_plan.dart';
import '../../domain/budget/budget_service.dart';
import '../../data/budget/budget_local_store.dart';

class BudgetProvider with ChangeNotifier {
  final BudgetService _service = BudgetService();
  final BudgetLocalStore _store = BudgetLocalStore();

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
    final savedFuture = await _store.getOverride('future');
    final savedVariables = await _store.getOverride('variables');
    final changed = _setStoredOverride('future', savedFuture) |
        _setStoredOverride('variables', savedVariables);
    await _store.discardLegacyInputs();
    if (changed && _lastInputs != null) {
      _recalculate();
    }
    return _lastInputs != null;
  }

  void updateOverride(String key, double value) {
    _overrides[key] = value;
    _recalculate();
    // Sauvegarde "fire and forget"
    _store.saveOverride(key, value);
  }

  /// Rehydrate synchronously from the canonical profile.
  ///
  /// The production proxy calls this on every profile publication. Repeated
  /// notifications carrying the same immutable profile are idempotent.
  void rehydrateFromProfile(CoachProfile profile) {
    if (identical(_boundProfile, profile)) return;
    _boundProfile = profile;
    final inputs = BudgetInputs.fromCoachProfile(profile);
    _lastInputs = inputs;
    _currentPlan = _service.computePlan(inputs, overrides: _overrides);
    notifyListeners();
  }

  /// Efface le budget (Reset / Supprimer mes données)
  Future<void> clear() async {
    _lastInputs = null;
    _currentPlan = null;
    _boundProfile = null;
    _overrides.clear();
    await _store.clear();
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
