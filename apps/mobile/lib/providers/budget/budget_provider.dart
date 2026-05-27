import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import '../../domain/budget/budget_inputs.dart';
import '../../domain/budget/budget_plan.dart';
import '../../domain/budget/budget_service.dart';
import '../../data/budget/budget_local_store.dart';

enum BudgetDataSource { none, storage, directInput, profile }

class BudgetProvider with ChangeNotifier {
  final BudgetService _service = BudgetService();
  final BudgetLocalStore _store = BudgetLocalStore();

  BudgetPlan? _currentPlan;
  BudgetInputs? _lastInputs;
  BudgetDataSource _source = BudgetDataSource.none;
  final Map<String, double> _overrides = {};

  BudgetPlan? get plan => _currentPlan;
  BudgetInputs? get inputs => _lastInputs;
  BudgetDataSource get source => _source;
  bool get hasFreshInputs {
    final inputs = _lastInputs;
    if (inputs == null) return false;
    if (_source == BudgetDataSource.directInput) return true;
    if (_source != BudgetDataSource.profile) return false;
    return inputs.netIncome > 0 &&
        !inputs.isHousingMissing &&
        !inputs.isHealthMissing;
  }

  /// Initialise ou met à jour le budget avec de nouveaux inputs.
  /// Persiste les inputs et restaure les overrides sauvegardés.
  Future<void> setInputs(BudgetInputs inputs) async {
    await _applyInputs(
      inputs,
      source: BudgetDataSource.directInput,
      persist: true,
    );
  }

  /// Charge le budget depuis SharedPreferences au démarrage.
  /// Retourne true si des inputs ont été restaurés.
  Future<bool> loadFromStorage() async {
    final savedInputs = await _store.loadInputs();
    if (savedInputs != null) {
      await _applyInputs(
        savedInputs,
        source: BudgetDataSource.storage,
        persist: false,
      );
      return true;
    }
    return false;
  }

  /// Hydrate the read model from the freshest reliable budget source.
  ///
  /// A complete profile is canonical. A partial profile can seed a budget only
  /// when there is no richer locally saved budget yet.
  Future<void> hydrateFromProfileState({
    required CoachProfile? profile,
    required bool isPartialProfile,
  }) async {
    if (profile == null) {
      await loadFromStorage();
      return;
    }

    if (isPartialProfile) {
      final restored = await loadFromStorage();
      if (!restored) await refreshFromProfile(profile);
      return;
    }

    await refreshFromProfile(profile);
  }

  void updateOverride(String key, double value) {
    _overrides[key] = value;
    _recalculate();
    // Sauvegarde "fire and forget"
    _store.saveOverride(key, value);
  }

  /// Recalcule le budget a partir d'un CoachProfile mis a jour.
  ///
  /// Appele automatiquement quand le profil change (wizard, annual refresh).
  /// Reconstruit les BudgetInputs depuis le profil et persiste.
  Future<void> refreshFromProfile(CoachProfile profile) async {
    final inputs = BudgetInputs.fromCoachProfile(profile);
    await _applyInputs(
      inputs,
      source: BudgetDataSource.profile,
      persist: true,
    );
  }

  /// Efface le budget (Reset / Supprimer mes données)
  Future<void> clear() async {
    _lastInputs = null;
    _currentPlan = null;
    _source = BudgetDataSource.none;
    _overrides.clear();
    await _store.clear();
    notifyListeners();
  }

  Future<void> _applyInputs(
    BudgetInputs inputs, {
    required BudgetDataSource source,
    required bool persist,
  }) async {
    _lastInputs = inputs;
    _source = source;

    if (persist) await _store.saveInputs(inputs);

    final savedFuture = await _store.getOverride('future');
    final savedVariables = await _store.getOverride('variables');

    if (savedFuture != null) _overrides['future'] = savedFuture;
    if (savedVariables != null) _overrides['variables'] = savedVariables;

    _recalculate();
  }

  void _recalculate() {
    if (_lastInputs == null) return;
    _currentPlan = _service.computePlan(_lastInputs!, overrides: _overrides);
    notifyListeners();
  }
}
