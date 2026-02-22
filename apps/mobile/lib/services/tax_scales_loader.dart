import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/models/tax_scale.dart';

class TaxScalesLoader {
  static const String _path = 'assets/config/tax_scales.json';
  static Map<String, List<TaxScale>> _cache = {};
  static bool _isLoaded = false;

  /// Canton code → JSON key name mapping (tax_scales.json uses full names)
  static const Map<String, String> _codeToName = {
    'ZH': 'Zurich',
    'BE': 'Bern',
    'LU': 'Lucerne',
    'UR': 'Uri',
    'SZ': 'Schwyz',
    'OW': 'Obwalden',
    'NW': 'Nidwalden',
    'GL': 'Glarus',
    'ZG': 'Zug',
    'FR': 'Fribourg',
    'SO': 'Solothurn',
    'BS': 'Basel-Stadt',
    'BL': 'Basel-Landschaft',
    // AR/AI/SG rates are 2024 estimates pending official data verification
    'AR': 'Appenzell Ausserrhoden',
    'AI': 'Appenzell Innerrhoden',
    'SG': 'St. Gallen',
    'SH': 'Schaffhausen',
    'GR': 'Graubünden',
    'AG': 'Aargau',
    'TG': 'Thurgau',
    'TI': 'Ticino',
    'VD': 'Vaud',
    'VS': 'Valais',
    'NE': 'Neuchâtel',
    'GE': 'Geneva',
    'JU': 'Jura',
  };

  /// Resolves a canton code ('VD') or full name ('Vaud') to the cache key.
  static String _resolveCantonKey(String canton) {
    // If already a full name in cache, use directly
    if (_cache.containsKey(canton)) return canton;
    // Try code → name mapping
    return _codeToName[canton] ?? canton;
  }

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
    _convertCumulativeThresholds();
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

      _convertCumulativeThresholds();
      _isLoaded = true;
      if (kDebugMode) {
        debugPrint('Tax scales loaded for ${_cache.length} cantons.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load tax scales: $e');
      }
      // Fallback or empty cache
    }
  }

  /// Returns brackets for a specific canton and tariff.
  /// Canton can be a code ('VD') or a full name ('Vaud').
  static List<TaxScale> getBrackets(String canton, String tariff) {
    if (!_isLoaded) {
      if (kDebugMode) {
        debugPrint('Tax scales not loaded. Call load() first.');
      }
      return [];
    }

    final cantonKey = _resolveCantonKey(canton);
    final cantonScales = _cache[cantonKey];
    if (cantonScales == null) return [];

    // Normalisation des tarifs par canton (noms hétérogènes dans le JSON scrapé)
    String normalizedTariff = tariff;

    // VD : noms spécifiques dans le JSON
    if (cantonKey == 'Vaud') {
      if (tariff == 'Single, no children') {
        normalizedTariff = 'Single, with / no children';
      } else if (tariff == 'Married/Single, with children') {
        normalizedTariff = 'Married';
      }
    }

    // Tentative avec le tarif (normalisé ou original)
    final result =
        cantonScales.where((s) => s.tariff == normalizedTariff).toList();
    if (result.isNotEmpty) return result;

    // Fallback: cantons à tarif unique "All" (GE, UR, OW, NW, GL, SO, SH, GR, AG, TG, VS, NE)
    return cantonScales.where((s) => s.tariff == 'All').toList();
  }

  /// Cantons whose JSON data uses cumulative income thresholds
  /// (e.g. BS: 0, 212500, 316300 = "up to 212500 CHF") instead of
  /// bracket widths (e.g. ZH: 6900, 4900 = "for the next 6900 CHF").
  /// These are converted to bracket widths at load time so that
  /// _calculateFromScales() works uniformly.
  /// Both full names (JSON keys) and codes (test fixtures) are listed.
  ///
  /// Band-width cantons (NOT cumulative): ZH, BE, VD, AG, JU, NW, SZ, OW, UR.
  static const Set<String> _cumulativeCantons = {
    'Appenzell Ausserrhoden', 'AR',
    'Appenzell Innerrhoden', 'AI',
    'Basel-Landschaft', 'BL',
    'Basel-Stadt', 'BS',
    'Fribourg', 'FR',
    'Geneva', 'GE',
    'Glarus', 'GL',
    'Graubünden', 'GR',
    'Lucerne', 'LU',
    'Neuchâtel', 'NE',
    'Schaffhausen', 'SH',
    'Solothurn', 'SO',
    'St. Gallen', 'SG',
    'Thurgau', 'TG',
    'Ticino', 'TI',
    'Valais', 'VS',
    'Zug', 'ZG',
  };

  /// Detects cantons whose JSON uses cumulative income thresholds
  /// and converts them to bracket widths.
  static void _convertCumulativeThresholds() {
    for (final canton in _cumulativeCantons) {
      final scales = _cache[canton];
      if (scales == null || scales.length < 2) continue;

      // Group by tariff
      final tariffs = <String>{};
      for (final s in scales) {
        tariffs.add(s.tariff);
      }

      // Convert all tariff groups for this canton
      final List<TaxScale> converted = [];
      for (final tariff in tariffs) {
        final group = scales.where((s) => s.tariff == tariff).toList();
        converted.addAll(_convertGroupToWidths(group));
      }
      _cache[canton] = converted;
    }
  }

  /// Converts a group of TaxScale entries from cumulative thresholds to
  /// bracket widths. E.g. [0, 212500, 316300] -> [212500, 103800].
  static List<TaxScale> _convertGroupToWidths(List<TaxScale> group) {
    if (group.length < 2) return group;

    final List<TaxScale> result = [];
    for (int i = 0; i < group.length; i++) {
      final double width;
      if (i == 0) {
        // First bracket: if threshold is 0, width = next threshold (or a large number)
        if (i + 1 < group.length) {
          width = group[i + 1].incomeThreshold - group[i].incomeThreshold;
        } else {
          width = group[i].incomeThreshold;
        }
      } else if (i < group.length - 1) {
        width = group[i + 1].incomeThreshold - group[i].incomeThreshold;
      } else {
        // Last bracket: use a very large width (catch-all)
        width = 999999999;
      }

      result.add(TaxScale(
        canton: group[i].canton,
        tariff: group[i].tariff,
        incomeThreshold: width > 0 ? width : 0,
        rate: group[i].rate,
      ));
    }
    return result;
  }
}
