import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider central pour le suivi d'activite utilisateur inter-tab.
///
/// Gere:
/// - Simulateurs explores (migration depuis ReportPersistenceService)
/// - Evenements de vie explores
/// - Tips dismisses (coach Agir)
/// - Tips snoozed (reporter 30j)
///
/// Fondation Wave 2B — utilise par Dashboard, Agir, Apprendre.
class UserActivityProvider extends ChangeNotifier {
  static const String _exploredSimulatorsKey = 'explored_simulators_v1';
  static const String _exploredLifeEventsKey = 'explored_life_events_v1';
  static const String _dismissedTipsKey = 'dismissed_tips_v1';
  static const String _snoozedTipsKey = 'snoozed_tips_v1';

  Set<String> _exploredSimulators = {};
  Set<String> _exploredLifeEvents = {};
  Set<String> _dismissedTips = {};
  Map<String, DateTime> _snoozedTips = {};

  bool _loaded = false;

  // ═══════════════════════════════════════════════════════════
  //  GETTERS
  // ═══════════════════════════════════════════════════════════

  Set<String> get exploredSimulators => Set.unmodifiable(_exploredSimulators);
  Set<String> get exploredLifeEvents => Set.unmodifiable(_exploredLifeEvents);
  Set<String> get dismissedTips => Set.unmodifiable(_dismissedTips);
  Map<String, DateTime> get snoozedTips => Map.unmodifiable(_snoozedTips);
  bool get isLoaded => _loaded;

  bool isSimulatorExplored(String id) => _exploredSimulators.contains(id);
  bool isLifeEventExplored(String id) => _exploredLifeEvents.contains(id);

  /// Un tip est actif s'il n'est ni dismiss ni snooze (ou snooze expire).
  bool isTipActive(String id) {
    if (_dismissedTips.contains(id)) return false;
    final snoozedUntil = _snoozedTips[id];
    if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil)) {
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  //  MUTATIONS
  // ═══════════════════════════════════════════════════════════

  /// Marque un simulateur comme explore.
  Future<void> markSimulatorExplored(String id) async {
    if (_exploredSimulators.contains(id)) return;
    _exploredSimulators.add(id);
    notifyListeners();
    await _saveStringSet(_exploredSimulatorsKey, _exploredSimulators);
  }

  /// Marque un evenement de vie comme explore.
  Future<void> markLifeEventExplored(String id) async {
    if (_exploredLifeEvents.contains(id)) return;
    _exploredLifeEvents.add(id);
    notifyListeners();
    await _saveStringSet(_exploredLifeEventsKey, _exploredLifeEvents);
  }

  /// Dismiss un tip (definitif — ne reapparait plus).
  Future<void> dismissTip(String id) async {
    if (_dismissedTips.contains(id)) return;
    _dismissedTips.add(id);
    // Retirer du snooze si present
    _snoozedTips.remove(id);
    notifyListeners();
    await _saveStringSet(_dismissedTipsKey, _dismissedTips);
    await _saveSnoozedTips();
  }

  /// Snooze un tip pour [duration] (reapparait apres expiration).
  Future<void> snoozeTip(String id, Duration duration) async {
    _snoozedTips[id] = DateTime.now().add(duration);
    notifyListeners();
    await _saveSnoozedTips();
  }

  // ═══════════════════════════════════════════════════════════
  //  HYDRATATION
  // ═══════════════════════════════════════════════════════════

  /// Charge toutes les donnees depuis SharedPreferences.
  /// Appele une seule fois au demarrage (idempotent).
  Future<void> loadAll() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Simulateurs explores (meme cle que ReportPersistenceService)
      _exploredSimulators =
          (prefs.getStringList(_exploredSimulatorsKey) ?? []).toSet();

      // Evenements de vie explores
      _exploredLifeEvents =
          (prefs.getStringList(_exploredLifeEventsKey) ?? []).toSet();

      // Tips dismisses
      _dismissedTips =
          (prefs.getStringList(_dismissedTipsKey) ?? []).toSet();

      // Tips snoozed (JSON map: {tipId: isoDate})
      final snoozedJson = prefs.getString(_snoozedTipsKey);
      if (snoozedJson != null) {
        try {
          final decoded = Map<String, dynamic>.from(json.decode(snoozedJson));
          _snoozedTips = {};
          for (final entry in decoded.entries) {
            final date = DateTime.tryParse(entry.value.toString());
            if (date != null) {
              // Ne charger que les snoozes non expires
              if (DateTime.now().isBefore(date)) {
                _snoozedTips[entry.key] = date;
              }
            }
          }
        } catch (e, stack) {
          dev.log('Failed to decode snoozed tips',
              error: e, stackTrace: stack, name: 'UserActivity');
          _snoozedTips = {};
        }
      }

      _loaded = true;
      notifyListeners();
    } catch (e, stack) {
      dev.log('Failed to load user activity',
          error: e, stackTrace: stack, name: 'UserActivity');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PERSISTENCE HELPERS
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveStringSet(String key, Set<String> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, data.toList());
    } catch (e, stack) {
      dev.log('Failed to save $key',
          error: e, stackTrace: stack, name: 'UserActivity');
    }
  }

  Future<void> _saveSnoozedTips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, String>{};
      for (final entry in _snoozedTips.entries) {
        encoded[entry.key] = entry.value.toIso8601String();
      }
      await prefs.setString(_snoozedTipsKey, json.encode(encoded));
    } catch (e, stack) {
      dev.log('Failed to save snoozed tips',
          error: e, stackTrace: stack, name: 'UserActivity');
    }
  }

  /// Efface toutes les donnees d'activite (logout/reset).
  Future<void> clearAll() async {
    _exploredSimulators = {};
    _exploredLifeEvents = {};
    _dismissedTips = {};
    _snoozedTips = {};
    _loaded = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_exploredLifeEventsKey);
      await prefs.remove(_dismissedTipsKey);
      await prefs.remove(_snoozedTipsKey);
      // Note: _exploredSimulatorsKey partage avec ReportPersistenceService
      // (clearCoachHistory s'en charge deja)
    } catch (e, stack) {
      dev.log('Failed to clear user activity',
          error: e, stackTrace: stack, name: 'UserActivity');
    }
  }
}
