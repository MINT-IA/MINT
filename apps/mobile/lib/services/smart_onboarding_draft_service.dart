import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists Smart Onboarding draft locally only after explicit consent.
class SmartOnboardingDraftService {
  static const String _consentKey = 'mint_onboarding_consent';
  static const String _draftKey = 'smart_onboarding_draft_v1';

  /// P2-17: Prevent concurrent read-modify-write on SharedPreferences.
  static bool _writing = false;

  static Future<bool> isConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) == true;
  }

  static Future<void> setConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, value);
    if (!value) {
      await prefs.remove(_draftKey);
    }
  }

  static Future<Map<String, dynamic>> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_consentKey) != true) return {};
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDraft({
    required int age,
    required double grossSalary,
    required String? canton,
    /// P1-Onboarding: Additional fields the user may enter during onboarding.
    String? firstName,
    String? nationalityGroup,
    String? nationalityCountry,
    String? employmentStatus,
    bool? hasLivedAbroad,
    int? arrivalYear,
    String? primaryFocus,
  }) async {
    // P2-17: Skip if another write is in progress
    if (_writing) return;
    _writing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_consentKey) != true) return;
      final payload = <String, dynamic>{
        'age': age,
        'grossSalary': grossSalary,
        if (canton != null && canton.isNotEmpty) 'canton': canton,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (nationalityGroup != null && nationalityGroup.isNotEmpty)
          'nationalityGroup': nationalityGroup,
        if (nationalityCountry != null && nationalityCountry.isNotEmpty)
          'nationalityCountry': nationalityCountry,
        if (employmentStatus != null && employmentStatus.isNotEmpty)
          'employmentStatus': employmentStatus,
        if (hasLivedAbroad != null) 'hasLivedAbroad': hasLivedAbroad,
        if (arrivalYear != null) 'arrivalYear': arrivalYear,
        if (primaryFocus != null && primaryFocus.isNotEmpty)
          'primaryFocus': primaryFocus,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_draftKey, jsonEncode(payload));
    } finally {
      _writing = false;
    }
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
