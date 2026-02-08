import 'dart:convert';
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

  /// Returns brackets for a specific canton and tariff.
  /// Canton can be a code ('VD') or a full name ('Vaud').
  static List<TaxScale> getBrackets(String canton, String tariff) {
    if (!_isLoaded) {
      print('⚠️ Tax scales not loaded. Call load() first.');
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
}
