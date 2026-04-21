/// SEC-10: Secure storage for sensitive wizard keys (PII financial data).
///
/// Sensitive financial values (salary, LPP, 3a, debts, patrimoine) are
/// stored in platform-encrypted storage (Keychain/EncryptedSharedPreferences)
/// instead of plain SharedPreferences.
///
/// References:
///   - nLPD art. 6 (data protection)
///   - FINMA circular 2023/1 (operational risk)
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureWizardStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Keys containing sensitive financial PII that must not be stored
  /// in plain SharedPreferences.
  static const _sensitiveKeys = {
    'q_gross_salary',
    'q_net_income_period_chf',
    'q_lpp_avoir',
    'q_3a_capital',
    'q_partner_salary',
    'q_patrimoine_liquide',
    'q_dettes_total',
  };

  /// Whether a key should be stored in secure storage.
  static bool isSensitive(String key) => _sensitiveKeys.contains(key);

  /// Write a sensitive value to encrypted storage.
  static Future<void> write(String key, String value) async {
    if (_sensitiveKeys.contains(key)) {
      await _storage.write(key: key, value: value);
    }
  }

  /// Read a sensitive value from encrypted storage.
  ///
  /// On iOS simulator without a valid keychain-access-groups entitlement
  /// (the usual case during dev sim builds — PlatformException `-34018`),
  /// returning `null` keeps the non-sensitive answer map intact. Without
  /// this guard, every `restoreSensitiveKeys` call threw and
  /// `ReportPersistenceService.loadAnswers` fell into its outer catch,
  /// silently returning `{}` — meaning freshly-scanned LPP data never
  /// hydrated the profile at app launch (deep-walk root cause for the
  /// « opener re-appears after scan » regression).
  static Future<String?> read(String key) async {
    if (!_sensitiveKeys.contains(key)) return null;
    try {
      return await _storage.read(key: key);
    } on Exception {
      return null;
    }
  }

  /// Delete all sensitive keys from encrypted storage.
  static Future<void> deleteAll() async {
    for (final key in _sensitiveKeys) {
      await _storage.delete(key: key);
    }
  }

  /// Extract sensitive values from an answers map and store them securely.
  /// Returns the map with sensitive values replaced by a placeholder.
  static Future<Map<String, dynamic>> secureSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final cleaned = Map<String, dynamic>.from(answers);
    for (final key in _sensitiveKeys) {
      if (cleaned.containsKey(key) && cleaned[key] != null) {
        await write(key, cleaned[key].toString());
        cleaned[key] = '__secure__';
      }
    }
    return cleaned;
  }

  /// Restore sensitive values from secure storage into an answers map.
  static Future<Map<String, dynamic>> restoreSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final restored = Map<String, dynamic>.from(answers);
    for (final key in _sensitiveKeys) {
      final value = await read(key);
      if (value != null) {
        // Try to parse as number if it looks like one
        final asNum = num.tryParse(value);
        restored[key] = asNum ?? value;
      }
    }
    return restored;
  }
}
