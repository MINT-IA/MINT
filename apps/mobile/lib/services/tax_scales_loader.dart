import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mint_mobile/models/tax_scale.dart';

class TaxScalesLoader {
  static const String _path = 'assets/config/tax_scales.json';
  static Map<String, List<TaxScale>> _cache = {};
  static bool _isLoaded = false;

  /// Manually initializes the cache (for testing).
  static void init(Map<String, dynamic> jsonMap) {
    _cache = {};
    jsonMap.forEach((canton, rows) {
      if (rows is List) {
        _cache[canton] = rows
            .map((row) => TaxScale.fromCsvRow(canton, row as List))
            .toList();
      }
    });
    _isLoaded = true;
  }

  /// Loads the tax scales from the JSON asset.
  static Future<void> load() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString(_path);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      _cache = {};
      jsonMap.forEach((canton, rows) {
        if (rows is List) {
          _cache[canton] = rows
              .map((row) => TaxScale.fromCsvRow(canton, row as List))
              .toList();
        }
      });

      _isLoaded = true;
      print('✅ Tax scales loaded for ${_cache.length} cantons.');
    } catch (e) {
      print('❌ Failed to load tax scales: $e');
      // Fallback or empty cache
    }
  }

  /// Returns brackets for a specific canton and tariff
  static List<TaxScale> getBrackets(String canton, String tariff) {
    if (!_isLoaded) {
      print('⚠️ Tax scales not loaded. Call load() first.');
      return [];
    }

    final cantonScales = _cache[canton];
    if (cantonScales == null) return [];

    // Filter by tariff (exact match)
    // Note: Tariff string in JSON comes from scraper ("Single, no children", "Married/Single, with children")
    // We might need fuzzy matching or normalization
    return cantonScales.where((s) => s.tariff == tariff).toList();
  }
}
