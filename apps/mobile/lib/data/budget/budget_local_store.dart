import 'package:shared_preferences/shared_preferences.dart';

/// Persistance locale du budget via SharedPreferences.
///
/// Stores only user-owned envelope overrides. Base inputs are derived from the
/// canonical CoachProfile and must never be restored from a local cache.
class BudgetLocalStore {
  static const String _overridePrefix = 'budget_override_';
  static const String _legacyInputsKey = 'budget_inputs_v1';

  // ── Overrides (sliders) ─────────────────────────────────────

  Future<void> saveOverride(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_overridePrefix$key', value);
  }

  Future<double?> getOverride(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_overridePrefix$key');
  }

  Future<void> discardLegacyInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyInputsKey);
  }

  // ── Clear ──────────────────────────────────────────────────

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_overridePrefix}future');
    await prefs.remove('${_overridePrefix}variables');
    await prefs.remove(_legacyInputsKey);
  }
}
