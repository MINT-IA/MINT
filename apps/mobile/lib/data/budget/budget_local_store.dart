import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/budget/budget_inputs.dart';

enum StoredBudgetInputsOrigin { directInput, profileDerived }

/// Persistance locale du budget via SharedPreferences.
///
/// Stocke les overrides des sliders (future/variables) et les BudgetInputs
/// directs pour que le budget survive au redemarrage sans profil canonique.
class BudgetLocalStore {
  static const String _overridePrefix = 'budget_override_';
  static const String _inputsKey = 'budget_inputs_v1';
  static const String _inputsOriginKey = 'budget_inputs_v1_origin';

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

  Future<void> saveInputs(
    BudgetInputs inputs, {
    StoredBudgetInputsOrigin origin = StoredBudgetInputsOrigin.directInput,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inputsKey, json.encode(inputs.toMap()));
    await prefs.setString(_inputsOriginKey, origin.name);
  }

  Future<BudgetInputs?> loadInputs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inputsKey);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(json.decode(raw));
      return BudgetInputs.fromMap(map);
    } catch (e) {
      // STAB-16 (07-04): corrupt prefs entry — log so the forensics are
      // visible, return null so the caller re-initialises from defaults.
      debugPrint('[budget_local_store] load failed (corrupt prefs?): $e');
      return null;
    }
  }

  Future<StoredBudgetInputsOrigin?> loadInputsOrigin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inputsOriginKey);
    if (raw == null) return null;
    for (final origin in StoredBudgetInputsOrigin.values) {
      if (origin.name == raw) return origin;
    }
    return null;
  }

  Future<bool> hasAnyData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().any((key) => key.startsWith(_overridePrefix)) ||
        prefs.containsKey(_inputsKey) ||
        prefs.containsKey(_inputsOriginKey);
  }

  Future<void> clearInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inputsKey);
    await prefs.remove(_inputsOriginKey);
  }

  // ── Clear ──────────────────────────────────────────────────

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final overrideKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_overridePrefix))
        .toList(growable: false);
    for (final key in overrideKeys) {
      await prefs.remove(key);
    }
    await prefs.remove(_inputsKey);
    await prefs.remove(_inputsOriginKey);
  }
}
