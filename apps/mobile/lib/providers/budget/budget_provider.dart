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
  final Map<String, double> _overrides = {};

  BudgetPlan? get plan => _currentPlan;
  BudgetInputs? get inputs => _lastInputs;

  /// Initialise ou met à jour le budget avec de nouveaux inputs.
  /// Persiste les inputs et restaure les overrides sauvegardés.
  Future<void> setInputs(BudgetInputs inputs) async {
    _lastInputs = inputs;

    // Persister les inputs pour les retrouver au prochain lancement
    _store.saveInputs(inputs);

    // Récupérer les overrides existants
    final savedFuture = await _store.getOverride('future');
    final savedVariables = await _store.getOverride('variables');

    if (savedFuture != null) _overrides['future'] = savedFuture;
    if (savedVariables != null) _overrides['variables'] = savedVariables;

    _recalculate();
  }

  /// Charge le budget depuis SharedPreferences au démarrage.
  /// Retourne true si des inputs ont été restaurés.
  Future<bool> loadFromStorage() async {
    final savedInputs = await _store.loadInputs();
    if (savedInputs != null) {
      await setInputs(savedInputs);
      return true;
    }
    return false;
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
    _lastInputs = inputs;
    _currentPlan = _service.computePlan(inputs, overrides: _overrides);
    await _store.saveInputs(inputs);
    notifyListeners();
  }

  /// Efface le budget (Reset / Supprimer mes données)
  Future<void> clear() async {
    _lastInputs = null;
    _currentPlan = null;
    _overrides.clear();
    await _store.clear();
    notifyListeners();
  }

  void _recalculate() {
    if (_lastInputs == null) return;
    _currentPlan = _service.computePlan(_lastInputs!, overrides: _overrides);
    notifyListeners();
  }
}
