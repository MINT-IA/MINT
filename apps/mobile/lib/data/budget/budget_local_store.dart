import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/budget/budget_inputs.dart';

/// Persistance locale du budget via SharedPreferences.
///
/// Stocke les overrides des sliders (future/variables) et les BudgetInputs
/// pour que le budget survive au redemarrage de l'app.
class BudgetLocalStore {
  static const String _overridePrefix = 'budget_override_';
  static const String _inputsKey = 'budget_inputs_v1';

  // ── Overrides (sliders) ─────────────────────────────────────

  Future<void> saveOverride(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_overridePrefix$key', value);
  }

  Future<double?> getOverride(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_overridePrefix$key');
  }

  // ── BudgetInputs ───────────────────────────────────────────

  Future<void> saveInputs(BudgetInputs inputs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inputsKey, json.encode(inputs.toMap()));
  }

  Future<BudgetInputs?> loadInputs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inputsKey);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(json.decode(raw));
      return BudgetInputs(
        payFrequency: PayFrequency.values.firstWhere(
          (e) => e.name == map['q_pay_frequency'],
          orElse: () => PayFrequency.monthly,
        ),
        netIncome: (map['q_net_income_period_chf'] as num?)?.toDouble() ?? 0.0,
        housingCost:
            (map['q_housing_cost_period_chf'] as num?)?.toDouble() ?? 0.0,
        debtPayments:
            (map['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0.0,
        taxProvision:
            (map['q_tax_provision_monthly_chf'] as num?)?.toDouble() ?? 0.0,
        healthInsurance:
            (map['q_lamal_premium_monthly_chf'] as num?)?.toDouble() ?? 0.0,
        otherFixedCosts:
            (map['q_other_fixed_costs_monthly_chf'] as num?)?.toDouble() ?? 0.0,
        style: BudgetStyle.values.firstWhere(
          (e) => e.name == map['q_budget_style'],
          orElse: () => BudgetStyle.envelopes3,
        ),
        emergencyFundMonths:
            (map['emergency_fund_months'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Clear ──────────────────────────────────────────────────

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_overridePrefix}future');
    await prefs.remove('${_overridePrefix}variables');
    await prefs.remove(_inputsKey);
  }
}
