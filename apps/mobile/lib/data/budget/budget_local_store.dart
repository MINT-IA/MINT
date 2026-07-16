import 'package:shared_preferences/shared_preferences.dart';

/// Persistance locale du budget via SharedPreferences.
///
/// Stores only user-owned envelope overrides. Base inputs are derived from the
/// canonical CoachProfile and must never be restored from a local cache.
class BudgetLocalStore {
  static const String _overridePrefix = 'budget_override_';
  static const String _legacyInputsKey = 'budget_inputs_v1';
  Future<void> _overrideMutationTail = Future<void>.value();

  // ── Overrides (sliders) ─────────────────────────────────────

  Future<void> saveExclusiveOverride(String key, double value) {
    final opposite = key == 'future' ? 'variables' : 'future';
    return _enqueueOverrideMutation(() async {
      final prefs = await SharedPreferences.getInstance();
      // Remove first: a process death may lose the new override, but can
      // never leave a contradictory pair with hidden precedence.
      await prefs.remove('$_overridePrefix$opposite');
      await prefs.setDouble('$_overridePrefix$key', value);
    });
  }

  Future<void> waitForOverridePersistence() => _overrideMutationTail;

  Future<double?> getOverride(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_overridePrefix$key');
  }

  Future<void> discardLegacyInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyInputsKey);
  }

  // ── Clear ──────────────────────────────────────────────────

  Future<void> clear() {
    return _enqueueOverrideMutation(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_overridePrefix}future');
      await prefs.remove('${_overridePrefix}variables');
      await prefs.remove(_legacyInputsKey);
    });
  }

  Future<void> _enqueueOverrideMutation(
    Future<void> Function() mutation,
  ) {
    final queued = _overrideMutationTail.then(
      (_) => mutation(),
      onError: (Object _, StackTrace __) => mutation(),
    );
    _overrideMutationTail = queued;
    return queued;
  }
}
