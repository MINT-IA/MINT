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

import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureWizardStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _operationTimeout = Duration(seconds: 2);
  static const _strictTaxSnapshotKey = '_coach_tax_snapshots_v1';

  /// Keys containing sensitive financial PII that must not be stored
  /// in plain SharedPreferences.
  static const _sensitiveKeys = {
    // Legacy key retained so old secure placeholders do not leak as plain JSON.
    'q_gross_salary',
    'q_gross_salary_annual',
    'q_self_employed_income',
    'q_company_profit_annual_chf',
    'q_net_income_period_chf',
    'q_lpp_avoir',
    'q_3a_capital',
    'q_partner_salary',
    'q_partner_net_income_chf',
    'q_patrimoine_liquide',
    'q_dettes_total',
    'q_has_consumer_debt',
    '_coach_dettes_hypotheque',
    '_coach_dettes_credit',
    '_coach_dettes_leasing',
    '_coach_dettes_autres',
    'q_cash_total',
    'q_cash_total_unconfirmed_legacy',
    'q_wealth_estimate',
    _strictTaxSnapshotKey,
  };

  /// Whether a key should be stored in secure storage.
  static bool isSensitive(String key) => _sensitiveKeys.contains(key);

  /// Write a sensitive value to encrypted storage.
  ///
  /// Returns false when platform secure storage is unavailable or does not
  /// answer. Dev/local iOS simulators can hit Keychain entitlement failures;
  /// those must never leave the profile save button spinning forever.
  static Future<bool> write(String key, String value) async {
    if (!_sensitiveKeys.contains(key)) return true;
    try {
      await _storage.write(key: key, value: value).timeout(_operationTimeout);
      return true;
    } on Object {
      return false;
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
      return await _storage.read(key: key).timeout(_operationTimeout);
    } on Object {
      return null;
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key).timeout(_operationTimeout);
    } on Object {
      // Best effort: callers still remove the plain placeholder from local
      // answers so stale secure storage cannot block the visible profile.
    }
  }

  /// Delete all sensitive keys from encrypted storage.
  static Future<void> deleteAll() async {
    for (final key in _sensitiveKeys) {
      await _delete(key);
    }
  }

  /// Extract sensitive values from an answers map and store them securely.
  /// Returns the map with sensitive values replaced by a placeholder.
  ///
  /// Local simulator/dev builds keep the plain value when secure storage is
  /// unavailable so product QA can continue. Release builds fail closed: the
  /// sensitive key is not persisted in plain SharedPreferences.
  static Future<Map<String, dynamic>> secureSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final cleaned = Map<String, dynamic>.from(answers);
    for (final key in _sensitiveKeys) {
      if (cleaned.containsKey(key)) {
        if (cleaned[key] == null) {
          await _delete(key);
          cleaned.remove(key);
          continue;
        }
        if (cleaned[key] == '__secure__') continue;
        final stored = await write(key, cleaned[key].toString());
        if (stored) {
          cleaned[key] = '__secure__';
        } else if (key == _strictTaxSnapshotKey) {
          throw StateError('Secure tax snapshot write failed');
        } else if (kReleaseMode) {
          cleaned.remove(key);
        }
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
      if (restored[key] != '__secure__') continue;
      final value = await read(key);
      if (value != null) {
        if (value == 'true') {
          restored[key] = true;
          continue;
        }
        if (value == 'false') {
          restored[key] = false;
          continue;
        }
        // Try to parse as number if it looks like one
        final asNum = num.tryParse(value);
        restored[key] = asNum ?? value;
      }
    }
    return restored;
  }
}
