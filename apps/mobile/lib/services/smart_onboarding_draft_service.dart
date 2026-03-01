import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists Smart Onboarding draft locally only after explicit consent.
class SmartOnboardingDraftService {
  static const String _consentKey = 'mint_onboarding_consent';
  static const String _draftKey = 'smart_onboarding_draft_v1';

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_consentKey) != true) return;
    final payload = <String, dynamic>{
      'age': age,
      'grossSalary': grossSalary,
      if (canton != null && canton.isNotEmpty) 'canton': canton,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_draftKey, jsonEncode(payload));
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
