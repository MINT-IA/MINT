/// White-Label Configuration — Sprint S71-S72.
///
/// Allows B2B organizations to customize MINT branding:
/// colors, logo, welcome message, and feature visibility.
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────

/// SharedPreferences key for white-label config.
const String kWhiteLabelKey = '_white_label_config';

/// White-label configuration for a B2B organization.
///
/// Controls branding, hidden features, and custom messaging.
class WhiteLabelConfig {
  final String organizationName;
  final String? logoAssetPath;
  final Color primaryColor;
  final Color accentColor;
  final String welcomeMessage;
  final List<String> hiddenFeatures;
  final String supportEmail;

  const WhiteLabelConfig({
    required this.organizationName,
    this.logoAssetPath,
    required this.primaryColor,
    required this.accentColor,
    required this.welcomeMessage,
    this.hiddenFeatures = const [],
    required this.supportEmail,
  });

  /// Default MINT branding (no white-label).
  static const WhiteLabelConfig defaultConfig = WhiteLabelConfig(
    organizationName: 'MINT',
    primaryColor: MintColors.primary,
    accentColor: MintColors.accent,
    welcomeMessage: 'Bienvenue sur MINT\u00a0— ton compagnon financier.',
    supportEmail: 'support@mint-app.ch',
  );

  /// Features that can NEVER be hidden (compliance-critical).
  ///
  /// White-label branding must NOT override legal disclaimers,
  /// privacy notices, or compliance-mandated screens.
  static const Set<String> kProtectedFeatures = {
    'disclaimer',
    'privacy_notice',
    'compliance_banner',
    'lsfin_notice',
    'data_sources',
    'confidence_score',
  };

  /// Whether a given feature should be visible.
  ///
  /// Protected compliance features are ALWAYS visible regardless
  /// of [hiddenFeatures] configuration (LSFin, nLPD compliance).
  bool isFeatureVisible(String featureId) {
    if (kProtectedFeatures.contains(featureId)) return true;
    return !hiddenFeatures.contains(featureId);
  }

  /// Serialize to JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'organizationName': organizationName,
        if (logoAssetPath != null) 'logoAssetPath': logoAssetPath,
        // ignore: deprecated_member_use
        'primaryColor': primaryColor.value,
        // ignore: deprecated_member_use
        'accentColor': accentColor.value,
        'welcomeMessage': welcomeMessage,
        'hiddenFeatures': hiddenFeatures,
        'supportEmail': supportEmail,
      };

  /// Deserialize from JSON map.
  factory WhiteLabelConfig.fromJson(Map<String, dynamic> json) {
    return WhiteLabelConfig(
      organizationName: json['organizationName'] as String? ?? 'MINT',
      logoAssetPath: json['logoAssetPath'] as String?,
      primaryColor: Color(json['primaryColor'] as int? ?? 0xFF1D1D1F),
      accentColor: Color(json['accentColor'] as int? ?? 0xFF00382E),
      welcomeMessage: json['welcomeMessage'] as String? ??
          'Bienvenue sur MINT\u00a0— ton compagnon financier.',
      hiddenFeatures: (json['hiddenFeatures'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      supportEmail:
          json['supportEmail'] as String? ?? 'support@mint-app.ch',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Persistence
  // ═══════════════════════════════════════════════════════════════

  /// Load white-label config from SharedPreferences.
  /// Returns [defaultConfig] if none is stored.
  static Future<WhiteLabelConfig> load({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final raw = sp.getString(kWhiteLabelKey);
    if (raw == null) return defaultConfig;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WhiteLabelConfig.fromJson(json);
    } catch (_) {
      return defaultConfig;
    }
  }

  /// Persist white-label config to SharedPreferences.
  Future<void> save({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setString(kWhiteLabelKey, jsonEncode(toJson()));
  }

  /// Clear white-label config (revert to default MINT branding).
  static Future<void> clear({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(kWhiteLabelKey);
  }
}
