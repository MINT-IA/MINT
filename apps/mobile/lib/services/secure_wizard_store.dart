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

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureWizardSealResult {
  final Map<String, dynamic> cleaned;
  final bool allSensitiveSealed;

  const SecureWizardSealResult({
    required this.cleaned,
    required this.allSensitiveSealed,
  });
}

class SecureWizardStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _manifestKey = '_mint_wizard_secure_keys_v1';
  static const _heldPrefix = '_mint_held_anonymous_wizard_';
  static const _heldManifestKey = '_mint_held_anonymous_wizard_secure_keys_v1';

  /// Keys containing sensitive financial PII that must not be stored
  /// in plain SharedPreferences.
  static const _sensitiveKeys = {
    'q_firstname',
    'q_date_of_birth',
    'q_birth_year',
    'q_civil_status',
    'q_civil_status_choice',
    'q_household_type',
    'q_commune',
    'q_gender',
    'q_nationality',
    'q_residence_permit',
    'q_us_tax_person',
    'q_employment_status',
    'q_gross_salary',
    'q_gross_salary_annual',
    'q_gross_income',
    'q_gross_income_monthly',
    'q_monthly_gross_salary_chf',
    'q_salary_months',
    'q_annual_bonus',
    'q_avs_contribution_years',
    'q_net_income_period_chf',
    'q_net_income_monthly',
    'q_net_income_range_low',
    'q_net_income_range_high',
    'q_salaire',
    'q_lpp_avoir',
    'q_avoir_lpp',
    'q_lpp_current_capital',
    'q_lpp_buyback_available',
    '_coach_avoir_lpp',
    '_coach_avoir_lpp_oblig',
    '_coach_avoir_lpp_suroblig',
    '_coach_salaire_assure',
    '_coach_rachat_maximum',
    '_coach_rachat_lpp_mensuel',
    '_coach_rendement_caisse',
    'q_3a_capital',
    'q_3a_total',
    'q_total_3a',
    'q_3a_accounts_count',
    'q_3a_annual_contribution',
    '_coach_total_3a',
    'q_partner_salary',
    'q_partner_net_income_chf',
    'q_partner_birth_year',
    'q_partner_employment_status',
    'q_partner_firstname',
    'q_partner_gender',
    'q_partner_nationality',
    'q_partner_canton',
    'q_partner_enfants',
    'q_spouse_birth_year',
    'q_spouse_employment_status',
    'q_spouse_firstname',
    'q_spouse_gender',
    'q_spouse_nationality',
    'q_spouse_canton',
    'q_spouse_enfants',
    'q_patrimoine_liquide',
    'q_epargne_liquide',
    'q_savings_monthly',
    'q_investissements',
    'q_cash_total',
    'q_investments_total',
    'q_dettes_total',
    'q_property_value',
    'q_property_market_value',
    'q_mortgage_balance',
    'q_monthly_rent',
    'q_housing_cost_period_chf',
    'q_lamal_premium_monthly_chf',
    'q_tax_provision_monthly_chf',
    'q_other_fixed_costs_monthly_chf',
    'q_debt_payments_period_chf',
    'q_total_debt_balance_chf',
    'q_bonus_percentage',
    '_coach_depenses_electricite',
    '_coach_depenses_transport',
    '_coach_depenses_telecom',
    '_coach_depenses_frais_medicaux',
    '_coach_depenses_autres',
    '_coach_dettes_hypotheque',
    '_coach_dettes_credit',
    '_coach_dettes_leasing',
    '_coach_dettes_autres',
    '_coach_conjoint_avoir_lpp',
    '_coach_conjoint_taux_conversion',
    '_coach_tax_revenu_imposable',
    '_coach_tax_fortune_imposable',
    '_coach_tax_deductions',
    '_coach_tax_impot_cantonal',
    '_coach_tax_impot_federal',
    '_coach_tax_taux_marginal',
  };

  /// Whether a key should be stored in secure storage.
  static bool isSensitive(String key) =>
      _sensitiveKeys.contains(key) ||
      key.startsWith('_coach_depenses_') ||
      key.startsWith('_coach_dettes_') ||
      key.startsWith('_coach_conjoint_') ||
      key.startsWith('_coach_avs_') ||
      key.startsWith('q_avs_') ||
      key.startsWith('q_partner_') ||
      key.startsWith('q_spouse_') ||
      (key.startsWith('_coach_tax_') && key != '_coach_tax_source');

  /// Write a sensitive value to encrypted storage.
  ///
  /// On iOS simulator without a valid keychain-access-groups entitlement
  /// (the usual case during dev sim builds — PlatformException `-34018`),
  /// swallowing the failure keeps the wizard seal (`saveAnswers` →
  /// `secureSensitiveKeys`) from hard-failing at the flush. Without this
  /// guard a fresh onboarding run on the sim throws at the seal, shows
  /// « Impossible de sceller ton dossier », and never reaches the coach —
  /// even though the same flow succeeds on a provisioned device (where the
  /// keychain write does not throw). Symmetric with [read]'s guard.
  ///
  /// SEC-10 is preserved: a swallowed write means the value is simply not
  /// sealed (a later [read] returns null, the already-accepted degraded
  /// path) — the PII is NEVER demoted to plain SharedPreferences.
  static Future<bool> write(String key, String value) async {
    if (!isSensitive(key)) return false;
    final isStaticKey = _sensitiveKeys.contains(key);
    try {
      await _storage.write(key: key, value: value);
      final remembered = await _rememberKey(key);
      if (!isStaticKey && !remembered) {
        try {
          await _storage.delete(key: key);
        } on Exception {
          // Best-effort rollback; caller still treats the seal as failed.
        }
        return false;
      }
      return true;
    } on Exception {
      // Secure storage unavailable (sim entitlement / locked keychain):
      // degrade gracefully rather than aborting the seal.
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
    if (!isSensitive(key)) return null;
    try {
      return await _storage.read(key: key);
    } on Exception {
      return null;
    }
  }

  static Future<Set<String>> _readManifest() async {
    try {
      final raw = await _storage.read(key: _manifestKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = json.decode(raw);
      if (decoded is! List) return {};
      return decoded.whereType<String>().toSet();
    } on Exception {
      return {};
    }
  }

  static Future<bool> _rememberKey(String key) async {
    try {
      final keys = await _readManifest();
      if (keys.add(key)) {
        await _storage.write(
            key: _manifestKey, value: json.encode(keys.toList()));
      }
      return true;
    } on Exception {
      // Best-effort manifest. The static sensitive key list still covers all
      // canonical keys, and dynamic prefixes are cleaned when the manifest works.
      return false;
    }
  }

  static Future<Set<String>> _readHeldManifest() async {
    try {
      final raw = await _storage.read(key: _heldManifestKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = json.decode(raw);
      if (decoded is! List) return {};
      return decoded.whereType<String>().toSet();
    } on Exception {
      return {};
    }
  }

  static Future<bool> _rememberHeldKey(String key) async {
    try {
      final keys = await _readHeldManifest();
      if (keys.add(key)) {
        await _storage.write(
          key: _heldManifestKey,
          value: json.encode(keys.toList()),
        );
      }
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> holdSensitiveValuesForKeys(Iterable<String> keys) async {
    var heldAll = true;
    for (final key in keys.where(isSensitive).toSet()) {
      final value = await read(key);
      if (value == null) continue;
      try {
        await _storage.write(key: '$_heldPrefix$key', value: value);
        heldAll = await _rememberHeldKey(key) && heldAll;
      } on Exception {
        heldAll = false;
      }
    }
    return heldAll;
  }

  static Future<Map<String, dynamic>> restoreHeldSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final restored = Map<String, dynamic>.from(answers);
    for (final entry in restored.entries.toList()) {
      if (entry.value == '__secure__' && isSensitive(entry.key)) {
        try {
          final value = await _storage.read(key: '$_heldPrefix${entry.key}');
          if (value != null) {
            restored[entry.key] = value;
          }
        } on Exception {
          // Keep placeholder when held secure storage is unavailable.
        }
      }
    }
    return restored;
  }

  static Future<bool> deleteHeldSensitiveValues() async {
    var deletedAll = true;
    final keys = await _readHeldManifest();
    for (final key in keys) {
      try {
        await _storage.delete(key: '$_heldPrefix$key');
      } on Exception {
        deletedAll = false;
      }
    }
    try {
      await _storage.delete(key: _heldManifestKey);
    } on Exception {
      deletedAll = false;
    }
    return deletedAll;
  }

  /// Delete all sensitive keys from encrypted storage.
  static Future<bool> deleteAll() async {
    var deletedAll = true;
    final keys = {..._sensitiveKeys, ...await _readManifest()};
    for (final key in keys) {
      try {
        await _storage.delete(key: key);
      } on Exception {
        deletedAll = false;
        // Best-effort cleanup: do not block logout/reset on keychain state.
      }
    }
    try {
      await _storage.delete(key: _manifestKey);
    } on Exception {
      deletedAll = false;
    }
    return deletedAll;
  }

  static Future<SecureWizardSealResult> sealSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final cleaned = Map<String, dynamic>.from(answers);
    var allSensitiveSealed = true;
    final sensitiveKeys = cleaned.keys.where(isSensitive).toList();
    final previousSecureValues = <String, String?>{};
    final touchedKeys = <String>[];
    for (final key in sensitiveKeys) {
      if (cleaned.containsKey(key) && cleaned[key] != null) {
        previousSecureValues[key] = await read(key);
        final sealed = await write(key, cleaned[key].toString());
        if (sealed) {
          touchedKeys.add(key);
          cleaned[key] = '__secure__';
        } else {
          allSensitiveSealed = false;
          await _rollbackWrites(previousSecureValues, touchedKeys);
          for (final sensitiveKey in sensitiveKeys) {
            cleaned.remove(sensitiveKey);
          }
          break;
        }
      }
    }
    return SecureWizardSealResult(
      cleaned: cleaned,
      allSensitiveSealed: allSensitiveSealed,
    );
  }

  static Future<void> _rollbackWrites(
    Map<String, String?> previousValues,
    List<String> touchedKeys,
  ) async {
    for (final key in touchedKeys.reversed) {
      try {
        final previous = previousValues[key];
        if (previous == null) {
          await _storage.delete(key: key);
        } else {
          await _storage.write(key: key, value: previous);
        }
      } on Exception {
        // Best-effort rollback. saveAnswers still fails closed and keeps the
        // previous SharedPreferences truth instead of publishing a partial map.
      }
    }
  }

  /// Extract sensitive values from an answers map and store them securely.
  /// Returns the map with sensitive values replaced by a placeholder.
  static Future<Map<String, dynamic>> secureSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    return (await sealSensitiveKeys(answers)).cleaned;
  }

  /// Restore sensitive values from secure storage into an answers map.
  static Future<Map<String, dynamic>> restoreSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final restored = Map<String, dynamic>.from(answers);
    for (final key in restored.keys
        .where((key) => restored[key] == '__secure__')
        .toList()) {
      if (!isSensitive(key)) continue;
      final value = await read(key);
      if (value != null) {
        if (value == 'true' || value == 'false') {
          restored[key] = value == 'true';
          continue;
        }
        // Try to parse as number if it looks like one
        final asNum = num.tryParse(value);
        restored[key] = asNum ?? value;
      } else {
        restored[key] = null;
      }
    }
    return restored;
  }
}
