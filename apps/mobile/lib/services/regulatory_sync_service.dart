/// Syncs regulatory constants from the backend RegulatoryRegistry.
///
/// Architecture:
///   - Backend = single source of truth (RegulatoryRegistry)
///   - This service fetches constants via /regulatory/constants API
///   - Falls back to local social_insurance.dart if backend is unavailable
///   - Called at app startup to keep Flutter constants fresh
///
/// Sources:
///   - services/backend/app/api/v1/endpoints/regulatory.py
///   - services/backend/app/services/regulatory/registry.py
///   - CLAUDE.md §2 (Architecture), §4 (Backend = source of truth)
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs regulatory constants from the backend.
/// Falls back to local social_insurance.dart if backend unavailable.
class RegulatorySyncService {
  /// SharedPreferences key for persisted regulatory cache.
  static const String _spKey = 'regulatory_cache';

  /// Cached constants from last successful sync.
  static Map<String, double>? _cachedConstants;

  /// Timestamp of last successful sync.
  static DateTime? _lastSyncAt;

  /// Load cached constants from SharedPreferences (disk).
  ///
  /// Call this BEFORE [fetchConstants] at app startup so that [reg()]
  /// has access to last-synced values immediately, even before the
  /// network call completes.
  static Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_spKey);
      if (raw != null) {
        _cachedConstants = Map<String, double>.from(
          (jsonDecode(raw) as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        );
      }
    } catch (e) {
      debugPrint('RegulatorySyncService: loadFromDisk failed — $e');
    }
  }

  /// Fetch all regulatory constants from the backend API.
  ///
  /// Returns a map of key -> value for all active parameters.
  /// Returns empty map on failure (callers should fall back to local constants).
  static Future<Map<String, double>> fetchConstants() async {
    try {
      final response = await ApiService.get('/regulatory/constants');
      final constants = _parseConstants(response);
      if (constants.isNotEmpty) {
        _cachedConstants = constants;
        _lastSyncAt = DateTime.now();

        // Persist to SharedPreferences for cold-start access.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_spKey, jsonEncode(constants));
        } catch (e) {
          debugPrint('RegulatorySyncService: persist to SP failed — $e');
        }
      }
      return constants;
    } catch (e) {
      debugPrint('RegulatorySyncService: fetch failed, using fallback — $e');
      return _cachedConstants ?? {};
    }
  }

  /// Fetch a single constant by key.
  ///
  /// Returns null if the key is not found or the backend is unavailable.
  static Future<double?> fetchConstant(String key) async {
    // Try cache first
    if (_cachedConstants != null && _cachedConstants!.containsKey(key)) {
      return _cachedConstants![key];
    }

    try {
      final response = await ApiService.get('/regulatory/constants/$key');
      final value = response['value'] as num?;
      return value?.toDouble();
    } catch (e) {
      debugPrint('RegulatorySyncService: fetch "$key" failed — $e');
      return null;
    }
  }

  /// Get a constant from the cache (synchronous).
  ///
  /// Returns null if constants have not been fetched yet.
  /// Use [fetchConstants] to populate the cache first.
  static double? getCached(String key) {
    return _cachedConstants?[key];
  }

  /// Whether constants have been synced at least once.
  static bool get hasSynced => _cachedConstants != null;

  /// Timestamp of last successful sync (null if never synced).
  static DateTime? get lastSyncAt => _lastSyncAt;

  /// Check freshness of the regulatory data.
  ///
  /// Returns list of stale parameter keys, or empty list if all fresh.
  static Future<List<String>> checkFreshness({int maxAgeDays = 90}) async {
    try {
      final response = await ApiService.get(
        '/regulatory/freshness?max_age_days=$maxAgeDays',
      );
      final staleParams = response['stale_parameters'] as List<dynamic>? ?? [];
      return staleParams
          .map((p) => (p as Map<String, dynamic>)['key'] as String? ?? '')
          .where((k) => k.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('RegulatorySyncService: freshness check failed — $e');
      return [];
    }
  }

  /// Clear the cache (useful for testing).
  @visibleForTesting
  static void clearCache() {
    _cachedConstants = null;
    _lastSyncAt = null;
  }

  /// Parse the /regulatory/constants response into a flat key -> value map.
  static Map<String, double> _parseConstants(Map<String, dynamic> response) {
    final constants = <String, double>{};
    final list = response['constants'] as List<dynamic>? ?? [];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final key = item['key'] as String?;
        final value = item['value'] as num?;
        if (key != null && value != null) {
          constants[key] = value.toDouble();
        }
      }
    }
    return constants;
  }
}
