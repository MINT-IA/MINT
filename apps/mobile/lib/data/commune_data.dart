import 'dart:convert';
import 'package:flutter/services.dart';

/// Service de données communales — coefficients fiscaux par commune.
///
/// Charge les multiplicateurs fiscaux communaux depuis le fichier JSON
/// et fournit des fonctions de recherche et lookup par NPA ou nom.
///
/// Sources: Publications officielles cantonales, LHID art. 2 al. 1.
class CommuneData {
  static const String _path = 'assets/config/commune_multipliers.json';
  static Map<String, dynamic>? _data;
  static bool _isLoaded = false;

  // NPA reverse index: NPA -> {canton, commune, multiplier}
  static final Map<int, Map<String, dynamic>> _npaIndex = {};

  /// Load commune data from JSON asset.
  static Future<void> load() async {
    if (_isLoaded) return;
    try {
      final String jsonString = await rootBundle.loadString(_path);
      _data = json.decode(jsonString);
      _buildNpaIndex();
      _isLoaded = true;
    } catch (e) {
      // Silently fail — commune data is optional enhancement
    }
  }

  /// Initialize from a map (for testing).
  static void init(Map<String, dynamic> jsonMap) {
    _data = jsonMap;
    _buildNpaIndex();
    _isLoaded = true;
  }

  /// Build reverse NPA index for fast lookup.
  static void _buildNpaIndex() {
    _npaIndex.clear();
    final cantons = _data?['cantons'] as Map<String, dynamic>?;
    if (cantons == null) return;
    for (final entry in cantons.entries) {
      final cantonCode = entry.key;
      final cantonData = entry.value as Map<String, dynamic>;
      final communes = cantonData['communes'] as Map<String, dynamic>?;
      if (communes == null) continue;
      for (final communeEntry in communes.entries) {
        final communeName = communeEntry.key;
        final communeData = communeEntry.value as Map<String, dynamic>;
        final npas = communeData['npa'] as List?;
        final multiplier = (communeData['multiplier'] as num?)?.toDouble() ?? 0.0;
        if (npas == null) continue;
        for (final npa in npas) {
          _npaIndex[npa as int] = {
            'canton': cantonCode,
            'commune': communeName,
            'multiplier': multiplier,
          };
        }
      }
    }
  }

  /// Get multiplier for a specific commune in a canton.
  /// Returns null if commune not found (caller should fall back to canton-level).
  static double? getCommuneMultiplier(String cantonCode, String communeName) {
    if (!_isLoaded || _data == null) return null;
    final cantons = _data!['cantons'] as Map<String, dynamic>?;
    if (cantons == null) return null;
    final cantonData = cantons[cantonCode] as Map<String, dynamic>?;
    if (cantonData == null) return null;
    final communes = cantonData['communes'] as Map<String, dynamic>?;
    if (communes == null) return null;

    // Try exact match first
    final commune = communes[communeName] as Map<String, dynamic>?;
    if (commune != null) {
      return (commune['multiplier'] as num?)?.toDouble();
    }

    // Try case-insensitive match
    for (final entry in communes.entries) {
      if (entry.key.toLowerCase() == communeName.toLowerCase()) {
        return ((entry.value as Map<String, dynamic>)['multiplier'] as num?)?.toDouble();
      }
    }

    return null;
  }

  /// Look up commune data by NPA (postal code).
  /// Returns null if NPA not found.
  static Map<String, dynamic>? getByNpa(int npa) {
    if (!_isLoaded) return null;
    return _npaIndex[npa];
  }

  /// Get the chef-lieu multiplier for a canton (fallback).
  static double? getChefLieuMultiplier(String cantonCode) {
    if (!_isLoaded || _data == null) return null;
    final cantons = _data!['cantons'] as Map<String, dynamic>?;
    if (cantons == null) return null;
    final cantonData = cantons[cantonCode] as Map<String, dynamic>?;
    if (cantonData == null) return null;
    return (cantonData['chef_lieu_multiplier'] as num?)?.toDouble();
  }

  /// List all commune names for a canton, sorted by multiplier ascending.
  static List<Map<String, dynamic>> listCommunes(String cantonCode) {
    if (!_isLoaded || _data == null) return [];
    final cantons = _data!['cantons'] as Map<String, dynamic>?;
    if (cantons == null) return [];
    final cantonData = cantons[cantonCode] as Map<String, dynamic>?;
    if (cantonData == null) return [];
    final communes = cantonData['communes'] as Map<String, dynamic>?;
    if (communes == null) return [];

    final result = <Map<String, dynamic>>[];
    for (final entry in communes.entries) {
      final data = entry.value as Map<String, dynamic>;
      result.add({
        'name': entry.key,
        'multiplier': (data['multiplier'] as num?)?.toDouble() ?? 0.0,
        'steuerfuss': data['steuerfuss'],
        'npa': data['npa'],
      });
    }
    result.sort((a, b) => (a['multiplier'] as double).compareTo(b['multiplier'] as double));
    return result;
  }

  /// Search communes by name (case-insensitive, partial match).
  static List<Map<String, dynamic>> search(String query, {String? canton}) {
    if (!_isLoaded || _data == null || query.isEmpty) return [];
    final queryLower = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    final cantons = _data!['cantons'] as Map<String, dynamic>?;
    if (cantons == null) return [];

    for (final cantonEntry in cantons.entries) {
      if (canton != null && cantonEntry.key != canton) continue;
      final cantonData = cantonEntry.value as Map<String, dynamic>;
      final communes = cantonData['communes'] as Map<String, dynamic>?;
      if (communes == null) continue;

      for (final communeEntry in communes.entries) {
        if (communeEntry.key.toLowerCase().contains(queryLower)) {
          final data = communeEntry.value as Map<String, dynamic>;
          results.add({
            'canton': cantonEntry.key,
            'name': communeEntry.key,
            'multiplier': (data['multiplier'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }
    }
    return results;
  }

  /// Whether commune data is loaded and available.
  static bool get isLoaded => _isLoaded;

  /// Total number of communes in the database.
  static int get communeCount => _npaIndex.isNotEmpty ? _npaIndex.values.map((v) => v['commune']).toSet().length : 0;
}
