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
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';

enum CanonicalHousingStatus { missing, present, deleted, corrupt, unavailable }

class CanonicalHousingRead {
  final CanonicalHousingStatus status;
  final MintNextHousingFact? fact;
  const CanonicalHousingRead(this.status, [this.fact]);
}

class SecureWizardSealResult {
  final Map<String, dynamic> cleaned;
  final bool allSensitiveSealed;

  const SecureWizardSealResult({
    required this.cleaned,
    required this.allSensitiveSealed,
  });
}

class SecureDeleteReconciliation {
  final Map<String, dynamic> answers;
  final bool rewriteRequired;

  const SecureDeleteReconciliation(this.answers, this.rewriteRequired);
}

enum WizardStorageClassification {
  sensitive,
  nonSensitive,
  productPreference,
  unknown,
}

class SecureWizardStore {
  static Completer<void> _canonicalMutationDone = Completer<void>()..complete();
  static int _canonicalResetGeneration = 0;

  static Future<T> runCanonicalHousingTransaction<T>(
      Future<T> Function() action) async {
    final resetAtRequest = _canonicalResetGeneration;
    final previousDone = _canonicalMutationDone;
    final done = Completer<void>();
    _canonicalMutationDone = done;
    if (!previousDone.isCompleted) {
      await previousDone.future;
    }
    if (_canonicalResetGeneration != resetAtRequest) {
      done.complete();
      throw StateError('Secure reset superseded housing transaction');
    }
    try {
      final result = await action();
      if (_canonicalResetGeneration != resetAtRequest) {
        throw StateError('Secure reset superseded housing transaction');
      }
      return result;
    } finally {
      done.complete();
    }
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _manifestKey = '_mint_wizard_secure_keys_v1';
  static const _deleteJournalKey = '_mint_wizard_delete_journal_v2';
  static const _canonicalHousingKey = '_mint_canonical_housing_v1';
  static const _canonicalHousingInitializedKey =
      '_mint_canonical_housing_initialized_v1';
  static int _processEpochCounter = 0;
  static String _processEpoch = _newProcessEpoch();

  static String _newProcessEpoch() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_processEpochCounter++}';
  static const _heldPrefix = '_mint_held_anonymous_wizard_';
  static const _heldManifestKey = '_mint_held_anonymous_wizard_secure_keys_v1';

  // ── E2E SEAL FALLBACK (debug/harness-only, NEVER release) ──────────────────
  //
  // Unsigned iOS-sim builds (`--no-codesign`) have no keychain-access-groups
  // entitlement, so `_storage.write` throws `PlatformException('-34018')`. The
  // real seal then fails, `saveAnswers` writes nothing, and the deliberate
  // privacy contract clears the profile — so any screen that persists sensitive
  // data on entry (e.g. `/retraite` via `_persistInitialSnapshot`) drops to the
  // onboarding empty state (State C) in the E2E harness, even though the exact
  // same flow succeeds on a provisioned device.
  //
  // This fallback lets the harness seal into a process-local in-memory map
  // instead of the keychain, so those screens can be exercised end-to-end
  // WITHOUT weakening the release seal path and WITHOUT relaxing the privacy
  // contract for unit tests:
  //   * Double-gated: `kReleaseMode` short-circuits to false FIRST (the whole
  //     branch is const-false dead-code-eliminated from the release AOT
  //     snapshot), then an explicit, default-false E2E opt-in
  //     (`MINT_E2E_SEAL_FALLBACK` / `debugSealFallbackOverride`).
  //   * OFF by default: unit tests and production stay on the genuine
  //     seal-failure path (the privacy contract in
  //     `coach_profile_provider_secure_failure_test.dart` remains asserted).
  //   * In-memory only: PII is NEVER demoted to plain SharedPreferences, even
  //     in debug — SEC-10 holds in the harness too. The value lives only in
  //     process RAM, exactly as a keychain-resident value would be accessed.
  //   * Missing-entitlement only: activates strictly on `-34018`; every other
  //     storage failure still fails closed.
  //
  // Pattern mirrors `E2eRuntimeFlags` and `coach_profile_seeds.dart`
  // (`forcedArchetypeSlug`), both kReleaseMode-guarded for the same
  // "never leak to production" reason.
  static final Map<String, String> _e2eSealFallbackStore = <String, String>{};

  /// Test seam mirroring `E2eRuntimeFlags.*Override`: forces the fallback on
  /// (or off) in widget/unit tests. Defaults to null -> the compile-time flag.
  @visibleForTesting
  static bool? debugSealFallbackOverride;

  /// Failure-injection seam for atomic deletion tests.
  @visibleForTesting
  static Future<bool> Function(Set<String> keys)? debugDeleteKeysOverride;
  static Future<bool> Function()? debugCommitDeleteOverride;
  static Future<bool> Function()? debugFinalizeDeleteOverride;
  @visibleForTesting
  static Future<void> Function()? debugCanonicalMarkerWriteOverride;

  static Future<void> restoreCanonical3aPayload(String? previous) async {
    if (_sealFallbackEnabled) {
      if (previous == null) {
        _e2eSealFallbackStore.remove('_coach_3a_accounts_v1');
      } else {
        _e2eSealFallbackStore['_coach_3a_accounts_v1'] = previous;
      }
      return;
    }
    if (previous == null) {
      await _storage.delete(key: '_coach_3a_accounts_v1');
    } else {
      await _storage.write(key: '_coach_3a_accounts_v1', value: previous);
    }
  }

  /// True only when the E2E seal fallback is active. Release short-circuits to
  /// false (const), so the fallback branches strip from the release snapshot.
  static bool get _sealFallbackEnabled {
    if (kReleaseMode) return false;
    return debugSealFallbackOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_SEAL_FALLBACK',
          defaultValue: false,
        );
  }

  static bool _isMissingEntitlement(Object error) {
    if (error is! PlatformException) return false;
    // iOS (flutter_secure_storage SwiftFlutterSecureStoragePlugin) surfaces
    // EVERY keychain OSStatus as `code == "Unexpected security result code"`
    // with the numeric status in `details` (and echoed in `message`). The
    // status, NOT the code string, distinguishes -34018 (errSecMissingEntitlement,
    // the unsigned-sim case) from other keychain errors — so we must match the
    // status wherever it lands. `code == '-34018'` also matches older shapes and
    // our own test doubles.
    const missing = -34018;
    if (error.code == '$missing') return true;
    final details = error.details;
    if (details is int && details == missing) return true;
    final message = error.message;
    return message != null && message.contains('$missing');
  }

  /// Resets the E2E fallback test seam (in-memory store + override). Debug-only.
  @visibleForTesting
  static void resetSealFallbackForTest() {
    _e2eSealFallbackStore.clear();
    debugSealFallbackOverride = null;
    debugDeleteKeysOverride = null;
    debugCommitDeleteOverride = null;
    debugFinalizeDeleteOverride = null;
    debugCanonicalMarkerWriteOverride = null;
    _processEpoch = _newProcessEpoch();
  }

  @visibleForTesting
  static void simulateNewProcessForTest() {
    _processEpoch = _newProcessEpoch();
  }

  static const _classifiedSensitiveKeys = {
    'q_employment_rate',
    'q_has_3a',
    'q_has_consumer_debt',
    'q_has_pension_fund',
    'q_net_income_period_source',
    'q_pay_frequency',
    'q_self_employed_net_income_annual_chf',
    'q_target_retirement_age',
    'q_housing_status',
    'q_housing_mortgage_status',
    'q_housing_mortgage_statement_availability',
    'q_housing_mortgage_statement_year',
    'q_housing_mortgage_annual_interest_cents',
    'q_housing_mortgage_debt_balance_cents',
    'q_housing_fact_asserted_at',
    'q_housing_fact_source',
    'q_housing_fact_schema_version',
    'q_housing_fact_needs_confirmation',
  };

  static const _nonSensitiveKeys = {
    'q_canton',
    '_coach_3a_accounts_revision_v1',
  };

  static const _productPreferenceKeys = {
    'q_main_goal',
  };

  /// Keys containing sensitive financial PII that must not be stored
  /// in plain SharedPreferences.
  static const _sensitiveKeys = {
    ..._classifiedSensitiveKeys,
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
    '_coach_3a_accounts_v1',
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

  static WizardStorageClassification classificationForKey(String key) {
    if (_isSensitiveKey(key)) {
      return WizardStorageClassification.sensitive;
    }
    if (_nonSensitiveKeys.contains(key)) {
      return WizardStorageClassification.nonSensitive;
    }
    if (_productPreferenceKeys.contains(key)) {
      return WizardStorageClassification.productPreference;
    }
    return WizardStorageClassification.unknown;
  }

  /// Whether a key should be stored in secure storage.
  static bool isSensitive(String key) =>
      classificationForKey(key) == WizardStorageClassification.sensitive;

  static bool _isSensitiveKey(String key) =>
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
    } on Exception catch (e) {
      if (_sealFallbackEnabled && _isMissingEntitlement(e)) {
        // E2E harness only (kReleaseMode-stripped): seal into a process-local
        // in-memory map so the flush succeeds off-keychain. NEVER reached in
        // release or in a default unit test.
        _e2eSealFallbackStore[key] = value;
        dev.log(
          'E2E seal fallback: sealed "$key" in debug in-memory store '
          '(keychain -34018, NOT a real keychain seal, NOT release)',
          name: 'SecureWizardStore',
        );
        return true;
      }
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
    // E2E harness only (kReleaseMode-stripped): the in-memory fallback is the
    // authoritative store when active — a failed keychain read returns null
    // WITHOUT throwing (so a catch-only guard would silently lose the value),
    // and a live keychain read could return a stale value. Prefer the map.
    if (_sealFallbackEnabled && _e2eSealFallbackStore.containsKey(key)) {
      return _e2eSealFallbackStore[key];
    }
    try {
      final journal = await _readDeleteJournal();
      final targets = _deleteJournalTargets(journal);
      if (journal?['state'] == 'committed' && targets.contains(key)) {
        return null;
      }
      final value = await _storage.read(key: key);
      if (value != null) return value;
      if (journal != null &&
          journal['state'] == 'prepared' &&
          (journal['values'] as Map<String, dynamic>).containsKey(key)) {
        return (journal['values'] as Map<String, dynamic>)[key] as String?;
      }
      return null;
    } on Exception {
      if (_sealFallbackEnabled) return _e2eSealFallbackStore[key];
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _readDeleteJournal() async {
    final raw = await _storage.read(key: _deleteJournalKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = json.decode(raw);
    if (decoded is! Map) return null;
    if (decoded['state'] == 'prepared' && decoded['values'] is Map) {
      return <String, dynamic>{
        'state': 'prepared',
        'values': Map<String, dynamic>.from(decoded['values'] as Map),
      };
    }
    if (decoded['state'] == 'committed' && decoded['keys'] is List) {
      return <String, dynamic>{
        'state': 'committed',
        'keys': (decoded['keys'] as List).whereType<String>().toList(),
        'epoch': decoded['epoch'],
      };
    }
    return null;
  }

  static Set<String> _deleteJournalTargets(Map<String, dynamic>? journal) {
    if (journal == null) return {};
    if (journal['state'] == 'prepared') {
      return (journal['values'] as Map<String, dynamic>).keys.toSet();
    }
    return (journal['keys'] as List<String>).toSet();
  }

  /// Durably stages encrypted copies before any original is removed.
  /// The manifest is written last, making an interrupted prepare harmless.
  static Future<bool> prepareDeleteTransaction(Iterable<String> keys) async {
    final targets = keys.where(isSensitive).toSet();
    try {
      final existing = await _readDeleteJournal();
      if (existing != null) {
        final existingKeys = _deleteJournalTargets(existing);
        if (existing['state'] == 'prepared') {
          return setEquals(existingKeys, targets);
        }
        if (setEquals(existingKeys, targets)) return true;
        if (!await finalizeDeleteTransaction()) return false;
      }
      final values = <String, String?>{};
      for (final key in targets) {
        // Strict reads: an exception is a failed prepare, not "absent".
        values[key] = await _storage.read(key: key);
      }
      await _storage.write(
        key: _deleteJournalKey,
        value: json.encode({'state': 'prepared', 'values': values}),
      );
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> commitDeleteTransaction() async {
    final override = debugCommitDeleteOverride;
    if (override != null) return override();
    try {
      final journal = await _readDeleteJournal();
      if (journal == null) return true;
      final targets = _deleteJournalTargets(journal);
      await _storage.write(
        key: _deleteJournalKey,
        value: json.encode({
          'state': 'committed',
          'keys': targets.toList(),
          'epoch': _processEpoch,
        }),
      );
      return true;
    } on Exception {
      return false;
    }
  }

  /// Removes durable recovery material after the plain answer-map commit.
  static Future<bool> finalizeDeleteTransaction() async {
    final override = debugFinalizeDeleteOverride;
    if (override != null) return override();
    try {
      await _storage.delete(key: _deleteJournalKey);
      return true;
    } on Exception {
      return false;
    }
  }

  /// Uses the durable plain-map truth to resolve a crash between map commit and
  /// journal commit. Presence of any target placeholder means rollback remains
  /// necessary; otherwise deletion committed and only cleanup remains.
  static Future<SecureDeleteReconciliation> reconcileDeleteTransaction(
      Map<String, dynamic> persisted) async {
    try {
      final journal = await _readDeleteJournal();
      if (journal == null) return SecureDeleteReconciliation(persisted, false);
      final targets = _deleteJournalTargets(journal);
      final anyPresent = targets.any(persisted.containsKey);
      if (journal['state'] == 'prepared' && !anyPresent) {
        await commitDeleteTransaction();
        return SecureDeleteReconciliation(persisted, false);
      }
      if (journal['state'] == 'committed') {
        if (!anyPresent) {
          // A second read in the same process can observe SharedPreferences'
          // cleaned cache before NSUserDefaults has flushed it. Only a new
          // process epoch observing an already-clean raw map may retire the
          // tombstone.
          if (journal['epoch'] != _processEpoch) {
            await finalizeDeleteTransaction();
          }
          return SecureDeleteReconciliation(persisted, false);
        }
        final cleaned = Map<String, dynamic>.from(persisted)
          ..removeWhere((key, _) => targets.contains(key));
        await _storage.write(
          key: _deleteJournalKey,
          value: json.encode({
            'state': 'committed',
            'keys': targets.toList(),
            'epoch': _processEpoch,
          }),
        );
        return SecureDeleteReconciliation(cleaned, true);
      }
    } on Exception {
      // A later load retries; never discard recovery material on ambiguity.
    }
    return SecureDeleteReconciliation(persisted, false);
  }

  static Future<Set<String>> committedDeleteTargets() async {
    try {
      final journal = await _readDeleteJournal();
      if (journal?['state'] != 'committed') return {};
      return _deleteJournalTargets(journal)
        ..removeAll(MintNextHousingFact.wizardKeys);
    } on Exception {
      return {};
    }
  }

  static Future<CanonicalHousingRead> readCanonicalHousing() async {
    late final String? raw;
    try {
      raw = await _storage.read(key: _canonicalHousingKey);
    } on Exception {
      return const CanonicalHousingRead(CanonicalHousingStatus.unavailable);
    }
    if (raw == null) {
      return const CanonicalHousingRead(CanonicalHousingStatus.missing);
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return const CanonicalHousingRead(CanonicalHousingStatus.corrupt);
      }
      if (decoded['state'] == 'deleted' && decoded.length == 1) {
        return const CanonicalHousingRead(CanonicalHousingStatus.deleted);
      }
      if (decoded['state'] == 'present' && decoded['fact'] is Map) {
        final fact = MintNextHousingFact.fromWizardAnswers(
          Map<String, dynamic>.from(decoded['fact'] as Map),
        );
        if (fact != null) {
          return CanonicalHousingRead(CanonicalHousingStatus.present, fact);
        }
      }
      return const CanonicalHousingRead(CanonicalHousingStatus.corrupt);
    } on Exception {
      return const CanonicalHousingRead(CanonicalHousingStatus.corrupt);
    }
  }

  static Future<bool> writeCanonicalHousing(MintNextHousingFact fact) async {
    try {
      await _storage.write(
        key: _canonicalHousingKey,
        value:
            json.encode({'state': 'present', 'fact': fact.toWizardAnswers()}),
      );
      try {
        final override = debugCanonicalMarkerWriteOverride;
        if (override != null) {
          await override();
        } else {
          await _storage.write(
              key: _canonicalHousingInitializedKey, value: '1');
        }
      } catch (_) {
        // The single canonical record already closes migration while present.
      }
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> writeCanonicalHousingDeleted() async {
    try {
      await _storage.write(
        key: _canonicalHousingKey,
        value: json.encode({'state': 'deleted'}),
      );
      try {
        final override = debugCanonicalMarkerWriteOverride;
        if (override != null) {
          await override();
        } else {
          await _storage.write(
              key: _canonicalHousingInitializedKey, value: '1');
        }
      } catch (_) {
        // The value-free canonical tombstone is already authoritative.
      }
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<Map<String, dynamic>> canonicalizeHousingAnswers(
      Map<String, dynamic> answers) async {
    final result = Map<String, dynamic>.from(answers)
      ..removeWhere((key, _) => MintNextHousingFact.wizardKeys.contains(key));
    final canonical = await readCanonicalHousing();
    if (canonical.status == CanonicalHousingStatus.present) {
      // The wizard cache still projects secure placeholders, so its per-key
      // encrypted values remain required while the canonical fact is present.
      result.addAll(canonical.fact!.toWizardAnswers());
    } else if (canonical.status == CanonicalHousingStatus.deleted) {
      // Tombstone authority is independent of cleanup success. Retry obsolete
      // legacy PII removal on every load/save until secure storage cooperates.
      await deleteKeys(MintNextHousingFact.wizardKeys);
    } else if (canonical.status == CanonicalHousingStatus.missing) {
      try {
        if (await _storage.read(key: _canonicalHousingInitializedKey) != null) {
          return result;
        }
      } on Exception {
        return result;
      }
      // Legacy answer maps contain `__secure__` placeholders. Only the truly
      // missing-canonical branch may consult their per-key encrypted values.
      final restoredLegacy = await restoreSensitiveKeys(answers);
      final legacy = MintNextHousingFact.fromWizardAnswers(restoredLegacy);
      if (legacy != null && await writeCanonicalHousing(legacy)) {
        result.addAll(legacy.toWizardAnswers());
      }
    }
    return result;
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
    if (deletedAll) {
      try {
        await _storage.delete(key: _heldManifestKey);
      } on Exception {
        deletedAll = false;
      }
    }
    return deletedAll;
  }

  /// Deletes a caller-provided, bounded subset of wizard-owned secure keys.
  /// Non-sensitive keys are ignored so this cannot erase unrelated secrets.
  static Future<bool> deleteKeys(Iterable<String> keys) async {
    var deletedAll = true;
    final sensitiveKeys = keys.where(isSensitive).toSet();
    final override = debugDeleteKeysOverride;
    if (override != null) return override(sensitiveKeys);
    if (!kReleaseMode) {
      for (final key in sensitiveKeys) {
        _e2eSealFallbackStore.remove(key);
      }
    }
    for (final key in sensitiveKeys) {
      try {
        await _storage.delete(key: key);
      } on Exception {
        deletedAll = false;
      }
    }
    if (!deletedAll) return false;

    try {
      final manifest = await _readManifest()
        ..removeAll(sensitiveKeys);
      if (manifest.isEmpty) {
        await _storage.delete(key: _manifestKey);
      } else {
        await _storage.write(
          key: _manifestKey,
          value: json.encode(manifest.toList()),
        );
      }
    } on Exception {
      return false;
    }
    return true;
  }

  /// Captures the encrypted values for a bounded set before a destructive
  /// operation. Callers can use [restoreValues] to roll back a failed commit.
  static Future<Map<String, String?>> backupValues(
      Iterable<String> keys) async {
    final backup = <String, String?>{};
    for (final key in keys.where(isSensitive).toSet()) {
      backup[key] = await read(key);
    }
    return backup;
  }

  /// Best-effort rollback companion to [backupValues].
  static Future<bool> restoreValues(Map<String, String?> backup) async {
    var restoredAll = true;
    for (final entry in backup.entries) {
      if (!isSensitive(entry.key)) continue;
      try {
        if (entry.value == null) {
          await _storage.delete(key: entry.key);
        } else {
          await _storage.write(key: entry.key, value: entry.value);
          restoredAll = await _rememberKey(entry.key) && restoredAll;
        }
      } on Exception {
        restoredAll = false;
      }
    }
    return restoredAll;
  }

  /// Réinitialise la chaîne de mutations canonique pour les tests — même
  /// piège que ReportPersistenceService.debugResetTransactionQueueForTest :
  /// un test de widget terminé pendant une mutation en vol laisse un Completer
  /// jamais complété qui figerait tous les tests suivants du fichier.
  @visibleForTesting
  static void debugResetCanonicalQueueForTest() {
    _canonicalMutationDone = Completer<void>()..complete();
  }

  /// Delete all sensitive keys from encrypted storage.
  static Future<bool> deleteAll() async {
    _canonicalResetGeneration++;
    final previousDone = _canonicalMutationDone;
    final done = Completer<void>();
    _canonicalMutationDone = done;
    if (!previousDone.isCompleted) {
      await previousDone.future;
    }
    try {
      return await deleteAllDuringCoordinatedReset();
    } finally {
      done.complete();
    }
  }

  /// Caller already owns the ReportPersistenceService transaction coordinator.
  static Future<bool> deleteAllDuringCoordinatedReset() async {
    var deletedAll = true;
    // Privacy reset must also purge the E2E in-memory fallback. Gated on
    // `!kReleaseMode` (NOT the E2E flag) so it strips from the release snapshot
    // yet always runs in any debug/harness run — even if the override was
    // flipped off after seals landed — leaving no PII resident.
    if (!kReleaseMode) {
      _e2eSealFallbackStore.clear();
    }
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
    try {
      await _storage.delete(key: _deleteJournalKey);
    } on Exception {
      deletedAll = false;
    }
    try {
      await _storage.delete(key: _canonicalHousingKey);
    } on Exception {
      deletedAll = false;
    }
    return deletedAll;
  }

  static Future<SecureWizardSealResult> sealSensitiveKeys(
    Map<String, dynamic> answers,
  ) async {
    final cleaned = Map<String, dynamic>.from(answers);
    final tombstoned = await committedDeleteTargets();
    cleaned.removeWhere((key, _) => tombstoned.contains(key));
    var allSensitiveSealed = true;
    final sensitiveKeys = cleaned.keys.where(isSensitive).toList();
    final previousSecureValues = <String, String?>{};
    final touchedKeys = <String>[];
    for (final key in sensitiveKeys) {
      if (cleaned.containsKey(key) && cleaned[key] != null) {
        previousSecureValues[key] = await read(key);
        final value = key == '_coach_3a_accounts_v1'
            ? json.encode(cleaned[key])
            : cleaned[key].toString();
        final sealed = await write(key, value);
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
        if (key == '_coach_3a_accounts_v1') {
          try {
            final decoded = json.decode(value);
            restored[key] = decoded is List ? decoded : const <dynamic>[];
          } on FormatException {
            restored[key] = const <dynamic>[];
          }
          continue;
        }
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
