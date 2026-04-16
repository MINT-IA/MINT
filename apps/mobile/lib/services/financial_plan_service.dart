import 'dart:convert';

import 'package:mint_mobile/models/financial_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────────────────
//  FinancialPlanService — SharedPreferences CRUD for financial plans
//
//  Follows the GoalTrackerService static pattern.
//  Max 3 plans stored; oldest evicted on overflow.
//
//  Threat T-04-03: loadAll() wraps jsonDecode in try/catch — returns empty
//  list on corruption, never propagates.
// ────────────────────────────────────────────────────────────────────────────

class FinancialPlanService {
  FinancialPlanService._();

  /// SharedPreferences key for persisted plan list.
  static const String _plansKey = 'financial_plan_v1';

  /// Maximum number of plans retained (oldest evicted on overflow).
  static const int _maxPlans = 3;

  /// Load all persisted plans (newest first).
  ///
  /// Returns empty list on corruption or missing key (never throws).
  static Future<List<FinancialPlan>> loadAll({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final raw = sp.getString(_plansKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FinancialPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Threat T-04-03: corruption silently returns empty list.
      return [];
    }
  }

  /// Return the first (newest) plan, or null if none saved.
  static Future<FinancialPlan?> loadCurrent({
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all.isEmpty ? null : all.first;
  }

  /// Upsert a plan by id (insert at position 0).
  ///
  /// If a plan with the same id exists, it is removed first.
  /// If after insert the list exceeds [_maxPlans], the last (oldest) plan is
  /// evicted.
  static Future<void> save(
    FinancialPlan plan, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final plans = await loadAll(prefs: sp);

    // Remove existing plan with same id (upsert semantics).
    plans.removeWhere((p) => p.id == plan.id);

    // Insert newest first.
    plans.insert(0, plan);

    // Evict oldest if over limit.
    while (plans.length > _maxPlans) {
      plans.removeLast();
    }

    await _save(sp, plans);
  }

  /// Delete a plan by id. No-op if not found.
  static Future<void> delete(
    String planId, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final plans = await loadAll(prefs: sp);
    plans.removeWhere((p) => p.id == planId);
    await _save(sp, plans);
  }

  /// Remove all persisted plans.
  static Future<void> clear({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(_plansKey);
  }

  // ── Private helpers ─────────────────────────────────────────

  static Future<void> _save(
    SharedPreferences sp,
    List<FinancialPlan> plans,
  ) async {
    final json = jsonEncode(plans.map((p) => p.toJson()).toList());
    await sp.setString(_plansKey, json);
  }
}
