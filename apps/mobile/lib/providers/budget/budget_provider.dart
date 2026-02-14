import 'package:flutter/foundation.dart';
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
  /// Tente de récupérer les overrides sauvegardés si c'est la première charge.
  Future<void> setInputs(BudgetInputs inputs) async {
    _lastInputs = inputs;

    // Tentative de récupération des overrides existants
    // Note: Dans une version avancée, on lierait ça à un ID de session ou de user.
    // Ici c'est local device global.
    final savedFuture = await _store.getOverride('future');
    final savedVariables = await _store.getOverride('variables');

    if (savedFuture != null) _overrides['future'] = savedFuture;
    if (savedVariables != null) _overrides['variables'] = savedVariables;

    _recalculate();
  }

  void updateOverride(String key, double value) {
    _overrides[key] = value;
    _recalculate();
    // Sauvegarde "fire and forget"
    _store.saveOverride(key, value);
  }

  void _recalculate() {
    if (_lastInputs == null) return;
    _currentPlan = _service.computePlan(_lastInputs!, overrides: _overrides);
    notifyListeners();
  }
}
