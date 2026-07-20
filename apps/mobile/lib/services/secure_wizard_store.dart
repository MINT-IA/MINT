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
  static const _strictLppEvidenceKey = '_coach_lpp_evidence_v1';
  static const _strictPillar3aBeneficiaryEvidenceKey =
      '_coach_pillar3a_beneficiary_evidence_v1';
  static const _strictEstateEvidenceKey = '_coach_estate_evidence_v1';
  static const _strictProfileOwnerKey = '_coach_profile_owner_v1';
  static const _lppEvidenceSlotPrefix = '_coach_lpp_evidence_slot_v1_';
  static const _financialPlanSlotPrefix = '_financial_plan_slot_v1_';
  static const _authoritySlotPrefix = '_coach_authority_slot_v1_';
  static const _maxInactiveLppSlotsPerSweep = 32;
  static const _maxInactiveFinancialPlanSlotsPerSweep = 32;
  static const _maxInactiveAuthoritySlotsPerSweep = 32;

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
    _strictLppEvidenceKey,
    _strictPillar3aBeneficiaryEvidenceKey,
    _strictEstateEvidenceKey,
    _strictProfileOwnerKey,
  };

  /// Whether a key should be stored in secure storage.
  static bool isSensitive(String key) => _sensitiveKeys.contains(key);

  static bool isValidLppEvidenceSlotId(String slotId) =>
      RegExp(r'^[a-f0-9]{32}$').hasMatch(slotId);

  static bool isValidFinancialPlanSlotId(String slotId) =>
      RegExp(r'^[a-f0-9]{32}$').hasMatch(slotId);

  static bool isValidAuthoritySlotId(String slotId) =>
      RegExp(r'^[a-f0-9]{32}$').hasMatch(slotId);

  static String _lppEvidenceSlotKey(String slotId) {
    if (!isValidLppEvidenceSlotId(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'invalid LPP slot id');
    }
    return '$_lppEvidenceSlotPrefix$slotId';
  }

  static String _financialPlanSlotKey(String slotId) {
    if (!isValidFinancialPlanSlotId(slotId)) {
      throw ArgumentError.value(
          slotId, 'slotId', 'invalid financial plan slot');
    }
    return '$_financialPlanSlotPrefix$slotId';
  }

  static String _authoritySlotKey(String slotId) {
    if (!isValidAuthoritySlotId(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'invalid authority slot');
    }
    return '$_authoritySlotPrefix$slotId';
  }

  /// Write a sensitive value to encrypted storage.
  ///
  /// Returns false when platform secure storage is unavailable or does not
  /// answer. Dev/local iOS simulators can hit Keychain entitlement failures;
  /// those must never leave the profile save button spinning forever.
  static Future<bool> write(String key, String value) async {
    if (!_sensitiveKeys.contains(key)) return true;
    return _writeRaw(key, value);
  }

  static Future<bool> writeLppEvidenceSlot(
    String slotId,
    String value,
  ) async {
    return _writeRaw(
      _lppEvidenceSlotKey(slotId),
      value,
      deleteLateSuccess: true,
    );
  }

  static Future<bool> writeFinancialPlanSlot(
    String slotId,
    String value,
  ) async {
    return _writeRaw(
      _financialPlanSlotKey(slotId),
      value,
      deleteLateSuccess: true,
    );
  }

  static Future<bool> writeAuthoritySlot(String slotId, String value) {
    return _writeRaw(
      _authoritySlotKey(slotId),
      value,
      deleteLateSuccess: true,
    );
  }

  static Future<bool> _writeRaw(
    String key,
    String value, {
    bool deleteLateSuccess = false,
  }) async {
    late final Future<void> pendingWrite;
    try {
      pendingWrite = _storage.write(key: key, value: value);
      await pendingWrite.timeout(_operationTimeout);
      return true;
    } on TimeoutException {
      if (deleteLateSuccess) {
        unawaited(_deleteAfterLateWrite(pendingWrite, key));
      }
      return false;
    } on Object {
      return false;
    }
  }

  static Future<void> _deleteAfterLateWrite(
    Future<void> pendingWrite,
    String key,
  ) async {
    try {
      await pendingWrite;
      await _delete(key);
    } on Object {
      // A failed late write created no usable slot.
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
    return _readRaw(key);
  }

  /// Mutation-only read that preserves transport failure vs. missing data.
  static Future<String?> readStrict(String key) {
    if (!_sensitiveKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'not a sensitive wizard key');
    }
    return _readRawStrict(key);
  }

  static Future<String?> readLppEvidenceSlot(String slotId) async {
    if (!isValidLppEvidenceSlotId(slotId)) return null;
    return _readRaw(_lppEvidenceSlotKey(slotId));
  }

  static Future<String?> readFinancialPlanSlot(String slotId) async {
    if (!isValidFinancialPlanSlotId(slotId)) return null;
    return _readRaw(_financialPlanSlotKey(slotId));
  }

  /// Strict mutation read: transport failures are distinct from an absent key.
  static Future<String?> readFinancialPlanSlotStrict(String slotId) {
    if (!isValidFinancialPlanSlotId(slotId)) {
      throw ArgumentError.value(
          slotId, 'slotId', 'invalid financial plan slot');
    }
    return _readRawStrict(_financialPlanSlotKey(slotId));
  }

  static Future<String?> readAuthoritySlotStrict(String slotId) {
    if (!isValidAuthoritySlotId(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'invalid authority slot');
    }
    return _readRawStrict(_authoritySlotKey(slotId));
  }

  static Future<String?> readLegacyLppEvidenceRoot() =>
      _readRaw(_strictLppEvidenceKey);

  static Future<String?> _readRaw(String key) async {
    try {
      return await _storage.read(key: key).timeout(_operationTimeout);
    } on Object {
      return null;
    }
  }

  static Future<String?> _readRawStrict(String key) async {
    try {
      return await _storage.read(key: key).timeout(_operationTimeout);
    } on TimeoutException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Strict secure read timed out'),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Strict secure read failed: ${error.runtimeType}'),
        stackTrace,
      );
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

  static Future<void> _deleteStrict(String key) async {
    try {
      await _storage.delete(key: key).timeout(_operationTimeout);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Strict secure deletion failed: ${error.runtimeType}'),
        stackTrace,
      );
    }
  }

  static Future<void> deleteLppEvidenceSlot(String slotId) async {
    if (!isValidLppEvidenceSlotId(slotId)) return;
    await _delete(_lppEvidenceSlotKey(slotId));
  }

  static Future<void> deleteFinancialPlanSlot(String slotId) async {
    if (!isValidFinancialPlanSlotId(slotId)) return;
    await _delete(_financialPlanSlotKey(slotId));
  }

  /// Transactional deletion: the slot is considered gone only after a fresh
  /// secure-storage inventory no longer contains it. Some platform backends
  /// report an error after applying a delete, so the transport result alone is
  /// not an authority boundary.
  static Future<void> deleteFinancialPlanSlotStrict(String slotId) async {
    if (!isValidFinancialPlanSlotId(slotId)) {
      throw ArgumentError.value(
          slotId, 'slotId', 'invalid financial plan slot');
    }
    await _deleteAndConfirmAbsent(_financialPlanSlotKey(slotId));
  }

  static Future<void> deleteAuthoritySlot(String slotId) async {
    if (!isValidAuthoritySlotId(slotId)) return;
    await _delete(_authoritySlotKey(slotId));
  }

  static Future<void> deleteAuthoritySlotStrict(String slotId) async {
    if (!isValidAuthoritySlotId(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'invalid authority slot');
    }
    await _deleteAndConfirmAbsent(_authoritySlotKey(slotId));
  }

  static Future<void> _deleteAndConfirmAbsent(String key) async {
    try {
      await _deleteStrict(key);
    } on Object {
      // Confirm below. A platform may throw after it has applied the delete.
    }
    if ((await _readAllStrict()).containsKey(key)) {
      throw StateError('Strict secure deletion could not be confirmed');
    }
  }

  static Future<void> deleteLegacyLppEvidenceRoot() =>
      _delete(_strictLppEvidenceKey);

  static Future<void> deleteInactiveLppEvidenceSlots(
    String activeSlotId,
  ) async {
    if (!isValidLppEvidenceSlotId(activeSlotId)) return;
    try {
      await _deleteInactiveLppEvidenceSlots(activeSlotId)
          .timeout(_operationTimeout);
    } on Object {
      // Cleanup must never make an already-published active root unavailable.
    }
  }

  static Future<void> deleteInactiveFinancialPlanSlots(
    String activeSlotId,
  ) async {
    if (!isValidFinancialPlanSlotId(activeSlotId)) return;
    try {
      await _deleteInactiveFinancialPlanSlots(activeSlotId)
          .timeout(_operationTimeout);
    } on Object {
      // Cleanup must never invalidate the already-published active plan.
    }
  }

  static Future<void> deleteInactiveAuthoritySlots(String activeSlotId) async {
    if (!isValidAuthoritySlotId(activeSlotId)) return;
    try {
      final activeKey = _authoritySlotKey(activeSlotId);
      final stored = await _storage.readAll().timeout(_operationTimeout);
      final inactiveKeys = stored.keys
          .where(
            (key) => key.startsWith(_authoritySlotPrefix) && key != activeKey,
          )
          .take(_maxInactiveAuthoritySlotsPerSweep);
      await Future.wait<void>(inactiveKeys.map(_delete));
    } on Object {
      // Cleanup must never invalidate an already-published authority slot.
    }
  }

  /// Completes the recoverable cleanup attached to a committed plan pointer.
  /// The active slot is never deleted; every other plan slot must be proven
  /// absent before the caller may clear its cleanup journal.
  static Future<void> cleanupFinancialPlanAfterCommitStrict(
    String activeSlotId,
  ) async {
    if (!isValidFinancialPlanSlotId(activeSlotId)) {
      throw ArgumentError.value(activeSlotId, 'activeSlotId', 'invalid slot');
    }
    final activeKey = _financialPlanSlotKey(activeSlotId);
    final before = await _readAllStrict();
    for (final key in before.keys.where(
      (key) => key.startsWith(_financialPlanSlotPrefix) && key != activeKey,
    )) {
      await _deleteAndConfirmAbsent(key);
    }
    final retained = (await _readAllStrict()).keys.where(
          (key) => key.startsWith(_financialPlanSlotPrefix) && key != activeKey,
        );
    if (retained.isNotEmpty) {
      throw StateError('Inactive financial plan cleanup is incomplete');
    }
  }

  /// Completes the cleanup journal of a committed unified authority bundle.
  /// Fixed legacy roots and superseded LPP/authority slots are inert after the
  /// pointer commit, but are still sensitive bytes and therefore require a
  /// confirmed cold-restart sweep.
  static Future<void> cleanupAuthorityAfterCommitStrict(
    String activeSlotId,
  ) async {
    if (!isValidAuthoritySlotId(activeSlotId)) {
      throw ArgumentError.value(activeSlotId, 'activeSlotId', 'invalid slot');
    }
    final activeKey = _authoritySlotKey(activeSlotId);
    final before = await _readAllStrict();
    final cleanupKeys = <String>{
      ..._sensitiveKeys,
      ...before.keys.where(
        (key) =>
            key.startsWith(_lppEvidenceSlotPrefix) ||
            (key.startsWith(_authoritySlotPrefix) && key != activeKey),
      ),
    };
    for (final key in cleanupKeys) {
      await _deleteAndConfirmAbsent(key);
    }
    final retained = (await _readAllStrict()).keys.where(
          (key) =>
              cleanupKeys.contains(key) ||
              key.startsWith(_lppEvidenceSlotPrefix) ||
              (key.startsWith(_authoritySlotPrefix) && key != activeKey),
        );
    if (retained.isNotEmpty) {
      throw StateError('Superseded authority cleanup is incomplete');
    }
  }

  static Future<void> _deleteInactiveLppEvidenceSlots(
    String activeSlotId,
  ) async {
    final activeKey = _lppEvidenceSlotKey(activeSlotId);
    final stored = await _storage.readAll();
    final inactiveKeys = stored.keys
        .where(
          (key) => key.startsWith(_lppEvidenceSlotPrefix) && key != activeKey,
        )
        .take(_maxInactiveLppSlotsPerSweep);
    await Future.wait<void>(inactiveKeys.map(_delete));
  }

  static Future<void> _deleteInactiveFinancialPlanSlots(
    String activeSlotId,
  ) async {
    final activeKey = _financialPlanSlotKey(activeSlotId);
    final stored = await _storage.readAll();
    final inactiveKeys = stored.keys
        .where(
          (key) => key.startsWith(_financialPlanSlotPrefix) && key != activeKey,
        )
        .take(_maxInactiveFinancialPlanSlotsPerSweep);
    await Future.wait<void>(inactiveKeys.map(_delete));
  }

  static Future<void> deleteAllFinancialPlanSlots() async {
    try {
      final stored = await _storage.readAll().timeout(_operationTimeout);
      for (final key in stored.keys.where(
        (key) => key.startsWith(_financialPlanSlotPrefix),
      )) {
        await _delete(key);
      }
    } on Object {
      // Dynamic slot cleanup is best effort when secure storage is unavailable.
    }
  }

  /// Removes superseded fixed strict roots and legacy LPP slots after the
  /// versioned authority pointer is durably published.
  static Future<void> deleteAllLegacyAuthorityBestEffort() async {
    for (final key in const {
      _strictTaxSnapshotKey,
      _strictLppEvidenceKey,
      _strictPillar3aBeneficiaryEvidenceKey,
      _strictEstateEvidenceKey,
      _strictProfileOwnerKey,
    }) {
      await _delete(key);
    }
    try {
      final stored = await _storage.readAll().timeout(_operationTimeout);
      for (final key in stored.keys.where(
        (key) => key.startsWith(_lppEvidenceSlotPrefix),
      )) {
        await _delete(key);
      }
    } on Object {
      // The versioned authority remains canonical; a later sweep can retry.
    }
  }

  static Future<void> deleteAllFinancialPlanSlotsStrict() async {
    final stored = await _readAllStrict();
    final keys = stored.keys
        .where((key) => key.startsWith(_financialPlanSlotPrefix))
        .toList(growable: false);
    Object? failure;
    for (final key in keys) {
      try {
        await _deleteStrict(key);
      } on Object catch (error) {
        failure ??= error;
      }
    }
    final retained = (await _readAllStrict())
        .keys
        .where((key) => key.startsWith(_financialPlanSlotPrefix))
        .toList(growable: false);
    if (failure != null || retained.isNotEmpty) {
      throw StateError('Financial plan secure purge failed');
    }
  }

  /// Delete all sensitive keys from encrypted storage.
  static Future<void> deleteAll() async {
    for (final key in _sensitiveKeys) {
      await _delete(key);
    }
    try {
      final stored = await _storage.readAll().timeout(_operationTimeout);
      for (final key in stored.keys.where(
        (key) =>
            key.startsWith(_lppEvidenceSlotPrefix) ||
            key.startsWith(_financialPlanSlotPrefix) ||
            key.startsWith(_authoritySlotPrefix),
      )) {
        await _delete(key);
      }
    } on Object {
      // Dynamic slot cleanup is best effort when secure storage is unavailable.
    }
  }

  /// Privacy-critical purge used by reset/logout. Unlike [deleteAll], every
  /// transport error and retained dynamic slot is surfaced to the caller.
  static Future<void> deleteAllStrict() async {
    final stored = await _readAllStrict();
    final keys = <String>{
      ..._sensitiveKeys,
      ...stored.keys.where(
        (key) =>
            key.startsWith(_lppEvidenceSlotPrefix) ||
            key.startsWith(_financialPlanSlotPrefix) ||
            key.startsWith(_authoritySlotPrefix),
      ),
    };
    Object? failure;
    for (final key in keys) {
      try {
        await _deleteStrict(key);
      } on Object catch (error) {
        failure ??= error;
      }
    }
    final retained = await _readAllStrict();
    final retainedAuthority = retained.keys.where(
      (key) =>
          _sensitiveKeys.contains(key) ||
          key.startsWith(_lppEvidenceSlotPrefix) ||
          key.startsWith(_financialPlanSlotPrefix) ||
          key.startsWith(_authoritySlotPrefix),
    );
    if (failure != null || retainedAuthority.isNotEmpty) {
      throw StateError('Strict secure wizard purge failed');
    }
  }

  static Future<Map<String, String>> _readAllStrict() async {
    try {
      return await _storage.readAll().timeout(_operationTimeout);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError('Strict secure inventory failed: ${error.runtimeType}'),
        stackTrace,
      );
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
        } else if (key == _strictTaxSnapshotKey ||
            key == _strictLppEvidenceKey ||
            key ==
                _strictPillar3aBeneficiaryEvidenceKey || // gitleaks:allow — ledger field name, not a credential.
            key == _strictEstateEvidenceKey ||
            key == _strictProfileOwnerKey) {
          throw StateError('Strict secure snapshot write failed');
        } else if (kReleaseMode) {
          cleaned.remove(key);
        }
      }
    }
    return cleaned;
  }

  /// Builds the non-authoritative preferences cache without rewriting the
  /// three strict roots owned by a versioned authority slot.
  static Map<String, dynamic> secureAuthorityCache(
    Map<String, dynamic> answers,
  ) {
    final prepared = Map<String, dynamic>.from(answers);
    for (final key in _sensitiveKeys) {
      if (!prepared.containsKey(key)) continue;
      if (prepared[key] == null) {
        prepared.remove(key);
      } else {
        prepared[key] = '__secure__';
      }
    }
    return prepared;
  }

  /// Restore sensitive values from secure storage into an answers map.
  static Future<Map<String, dynamic>> restoreSensitiveKeys(
    Map<String, dynamic> answers,
  ) =>
      _restoreSensitiveKeys(answers, strict: false);

  /// Mutation-only restoration. A Keychain failure cannot be mistaken for an
  /// absent value and then persisted over the current authority.
  static Future<Map<String, dynamic>> restoreSensitiveKeysStrict(
    Map<String, dynamic> answers,
  ) =>
      _restoreSensitiveKeys(answers, strict: true);

  static Future<Map<String, dynamic>> _restoreSensitiveKeys(
    Map<String, dynamic> answers, {
    required bool strict,
  }) async {
    final restored = Map<String, dynamic>.from(answers);
    for (final key in _sensitiveKeys) {
      if (restored[key] != '__secure__') continue;
      if (key == _strictLppEvidenceKey) continue;
      final value = await (strict ? readStrict(key) : read(key));
      if (value != null) {
        // The strict tax root is a JSON string contract. Even malformed scalar
        // text must reach fail-closed quarantine byte-for-byte; generic answer
        // coercion would otherwise turn `true` or `123` into a different value.
        if (key == _strictTaxSnapshotKey ||
            key == _strictEstateEvidenceKey ||
            key == _strictProfileOwnerKey) {
          restored[key] = value;
          continue;
        }
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
