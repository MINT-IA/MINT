import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────────────────
//  FinancialPlanService — encrypted slot persistence for financial plans
// ────────────────────────────────────────────────────────────────────────────

class FinancialPlanService {
  FinancialPlanService._();

  /// Legacy plaintext key. Read only for one fail-closed migration.
  static const String _legacyPlansKey = 'financial_plan_v1';
  static const String _activeSlotKey = 'financial_plan_active_slot_v1';
  static const String _purgeJournalPreference =
      'financial_plan_purge_pending_v1';
  static const String _cleanupPendingKey = 'financial_plan_cleanup_pending_v1';
  static const int _maxPlans = 3;
  static Future<void>? _persistenceTail;

  /// Loads newest-first plans. A valid legacy plaintext payload is returned
  /// only after it has been moved to an encrypted slot and removed from prefs.
  static Future<List<FinancialPlan>> loadAll({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return _serialize(() async {
      await _resumePurgeIfNeededLocked(sp);
      await _reconcileCleanupBestEffort(sp);
      return _loadAllLocked(sp, migrateLegacy: true);
    });
  }

  static Future<FinancialPlan?> loadCurrent({
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all.isEmpty ? null : all.first;
  }

  static Future<void> save(
    FinancialPlan plan, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await _serialize(() async {
      await _resumePurgeIfNeededLocked(sp);
      await _reconcileCleanupLocked(sp);
      final plans = await _loadAllLocked(
        sp,
        migrateLegacy: false,
        strictActive: true,
      );
      plans.removeWhere((candidate) => candidate.id == plan.id);
      plans.insert(0, plan);
      while (plans.length > _maxPlans) {
        plans.removeLast();
      }
      await _publishPayloadLocked(sp, _encodePlans(plans));
    });
  }

  static Future<void> delete(
    String planId, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await _serialize(() async {
      await _resumePurgeIfNeededLocked(sp);
      await _reconcileCleanupLocked(sp);
      final plans = await _loadAllLocked(
        sp,
        migrateLegacy: false,
        strictActive: true,
      );
      plans.removeWhere((plan) => plan.id == planId);
      await _publishPayloadLocked(sp, _encodePlans(plans));
    });
  }

  static Future<void> clear({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await _serialize(() async {
      await _beginPurgeLocked(sp);
      await _continuePurgeLocked(sp);
    });
  }

  static Future<void> _beginPurgeLocked(SharedPreferences prefs) async {
    await prefs.reload();
    if (prefs.getBool(_purgeJournalPreference) == true) return;
    final stored = await prefs.setBool(_purgeJournalPreference, true);
    if (!stored) await prefs.reload();
    if (!stored || prefs.getBool(_purgeJournalPreference) != true) {
      throw StateError('Financial plan purge journal failed');
    }
  }

  static Future<void> _resumePurgeIfNeededLocked(
    SharedPreferences prefs,
  ) async {
    await prefs.reload();
    if (!prefs.containsKey(_purgeJournalPreference)) return;
    await _continuePurgeLocked(prefs);
  }

  static Future<void> _continuePurgeLocked(SharedPreferences prefs) async {
    Object? failure;
    try {
      await _removePreference(
        prefs,
        _activeSlotKey,
        'Financial plan pointer clear failed',
      );
    } on Object catch (error) {
      failure = error;
    }
    try {
      await _removePreference(
        prefs,
        _legacyPlansKey,
        'Financial plan legacy clear failed',
      );
    } on Object catch (error) {
      failure ??= error;
    }
    try {
      await SecureWizardStore.deleteAllFinancialPlanSlotsStrict();
    } on Object catch (error) {
      failure ??= error;
    }
    if (failure != null) {
      throw StateError('Financial plan purge failed');
    }
    await _removePreference(
      prefs,
      _cleanupPendingKey,
      'Financial plan cleanup journal purge failed',
    );
    await _removePreference(
      prefs,
      _purgeJournalPreference,
      'Financial plan purge journal cleanup failed',
    );
  }

  static Future<List<FinancialPlan>> _loadAllLocked(
    SharedPreferences prefs, {
    required bool migrateLegacy,
    bool strictActive = false,
  }) async {
    final activeSlotId = prefs.getString(_activeSlotKey);
    final legacyBytes = prefs.getString(_legacyPlansKey);

    if (activeSlotId != null) {
      if (!SecureWizardStore.isValidFinancialPlanSlotId(activeSlotId)) {
        if (strictActive) {
          throw StateError('Financial plan active pointer is invalid');
        }
        return <FinancialPlan>[];
      }
      final payload = strictActive
          ? await SecureWizardStore.readFinancialPlanSlotStrict(activeSlotId)
          : await SecureWizardStore.readFinancialPlanSlot(activeSlotId);
      if (payload == null) {
        if (strictActive) {
          throw StateError('Financial plan active payload is unavailable');
        }
        return <FinancialPlan>[];
      }
      final plans = _decodePlans(payload);
      if (plans == null) {
        if (strictActive) {
          throw StateError('Financial plan active payload is invalid');
        }
        return <FinancialPlan>[];
      }
      if (migrateLegacy && legacyBytes != null) {
        await _ensureCleanupJournalBestEffort(prefs, activeSlotId);
      }
      return plans;
    }

    if (legacyBytes == null) return <FinancialPlan>[];
    final plans = _decodePlans(legacyBytes);
    if (plans == null) {
      await _removePreference(
        prefs,
        _legacyPlansKey,
        'Invalid financial plan legacy purge failed',
      );
      return <FinancialPlan>[];
    }
    if (migrateLegacy) {
      await _publishPayloadLocked(prefs, legacyBytes);
    }
    return plans;
  }

  static List<FinancialPlan>? _decodePlans(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List<dynamic>) return null;
      return decoded
          .map(
            (item) => FinancialPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: true);
    } on Object {
      return null;
    }
  }

  static String _encodePlans(List<FinancialPlan> plans) =>
      jsonEncode(plans.map((plan) => plan.toJson()).toList(growable: false));

  static Future<void> _publishPayloadLocked(
    SharedPreferences prefs,
    String payload,
  ) async {
    final previousPointer = prefs.getString(_activeSlotKey);
    final nextSlotId = _newSlotId();
    await _setStringPreference(
      prefs,
      _cleanupPendingKey,
      nextSlotId,
      'Financial plan cleanup journal failed',
    );
    final stored = await SecureWizardStore.writeFinancialPlanSlot(
      nextSlotId,
      payload,
    );
    if (!stored) {
      await _discardStagedPlanSlotLocked(prefs, nextSlotId);
      throw StateError('Financial plan secure slot write failed');
    }

    try {
      await _setStringPreference(
        prefs,
        _activeSlotKey,
        nextSlotId,
        'Financial plan pointer publication failed',
      );
    } on Object catch (error, stackTrace) {
      Object? rollbackFailure;
      try {
        await _rollbackPreferences(
          prefs,
          previousPointer: previousPointer,
        );
      } on Object catch (rollbackError) {
        rollbackFailure = rollbackError;
      }
      if (rollbackFailure != null) {
        await prefs.reload();
        if (prefs.getString(_activeSlotKey) == nextSlotId) {
          await _finishCleanupBestEffort(prefs, nextSlotId);
          return;
        }
      }
      try {
        await _discardStagedPlanSlotLocked(prefs, nextSlotId);
      } on Object catch (rollbackError) {
        rollbackFailure ??= rollbackError;
      }
      if (rollbackFailure != null) {
        throw StateError('Financial plan cross-store rollback failed');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    await _finishCleanupBestEffort(prefs, nextSlotId);
  }

  static Future<void> _discardStagedPlanSlotLocked(
    SharedPreferences prefs,
    String stagedSlotId,
  ) async {
    await SecureWizardStore.deleteFinancialPlanSlotStrict(stagedSlotId);
    await _removePreference(
      prefs,
      _cleanupPendingKey,
      'Financial plan staging journal cleanup failed',
    );
  }

  static Future<void> _finishCleanupBestEffort(
    SharedPreferences prefs,
    String committedSlotId,
  ) async {
    try {
      if (prefs.getString(_legacyPlansKey) != null) {
        await _removePreference(
          prefs,
          _legacyPlansKey,
          'Financial plan legacy cleanup failed',
        );
      }
      await SecureWizardStore.cleanupFinancialPlanAfterCommitStrict(
        committedSlotId,
      );
      if (prefs.getString(_cleanupPendingKey) == committedSlotId) {
        await _removePreference(
          prefs,
          _cleanupPendingKey,
          'Financial plan cleanup journal removal failed',
        );
      }
    } on Object {
      // The pointer already commits B. Retain the marker and retry on the next
      // mutable load instead of returning an error that describes durable B as
      // a failed A transaction.
      try {
        await prefs.reload();
      } on Object {
        // The active secure pointer remains the read authority.
      }
    }
  }

  static Future<void> _ensureCleanupJournalBestEffort(
    SharedPreferences prefs,
    String activeSlotId,
  ) async {
    try {
      if (prefs.getString(_cleanupPendingKey) != activeSlotId) {
        await _setStringPreference(
          prefs,
          _cleanupPendingKey,
          activeSlotId,
          'Financial plan cleanup journal failed',
        );
      }
      await _finishCleanupBestEffort(prefs, activeSlotId);
    } on Object {
      // Exact active payload remains readable; a later load retries cleanup.
    }
  }

  static Future<void> _reconcileCleanupBestEffort(
    SharedPreferences prefs,
  ) async {
    try {
      await _reconcileCleanupLocked(prefs);
    } on Object {
      // A load may still expose the exact active slot. Mutations call the
      // strict variant and cannot overwrite an unresolved staging journal.
    }
  }

  static Future<void> _reconcileCleanupLocked(
    SharedPreferences prefs,
  ) async {
    final stagedSlotId = prefs.getString(_cleanupPendingKey);
    if (stagedSlotId == null) return;
    if (!SecureWizardStore.isValidFinancialPlanSlotId(stagedSlotId)) {
      throw StateError('Financial plan cleanup journal is invalid');
    }
    final activeSlotId = prefs.getString(_activeSlotKey);
    if (activeSlotId == stagedSlotId) {
      if (prefs.getString(_legacyPlansKey) != null) {
        await _removePreference(
          prefs,
          _legacyPlansKey,
          'Financial plan legacy cleanup failed',
        );
      }
      await SecureWizardStore.cleanupFinancialPlanAfterCommitStrict(
        activeSlotId!,
      );
      await _removePreference(
        prefs,
        _cleanupPendingKey,
        'Financial plan cleanup journal removal failed',
      );
      return;
    }
    await _discardStagedPlanSlotLocked(prefs, stagedSlotId);
  }

  static Future<void> _rollbackPreferences(
    SharedPreferences prefs, {
    required String? previousPointer,
  }) async {
    await _restoreStringPreference(
      prefs,
      key: _activeSlotKey,
      value: previousPointer,
      failure: 'Financial plan pointer rollback failed',
    );
  }

  static Future<void> _setStringPreference(
    SharedPreferences prefs,
    String key,
    String value,
    String failure,
  ) async {
    final stored = await prefs.setString(key, value);
    if (!stored || prefs.getString(key) != value) throw StateError(failure);
  }

  static Future<void> _removePreference(
    SharedPreferences prefs,
    String key,
    String failure,
  ) async {
    await prefs.reload();
    if (!prefs.containsKey(key)) return;
    final removed = await prefs.remove(key);
    await prefs.reload();
    if (!removed || prefs.containsKey(key)) throw StateError(failure);
  }

  static Future<void> _restoreStringPreference(
    SharedPreferences prefs, {
    required String key,
    required String? value,
    required String failure,
  }) async {
    if (value == null) {
      await _removePreference(prefs, key, failure);
      return;
    }
    await _setStringPreference(prefs, key, value, failure);
  }

  static String _newSlotId() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      growable: false,
    ).join();
  }

  static Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _persistenceTail;
    final completion = Completer<void>();
    final current = completion.future;
    _persistenceTail = current;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_persistenceTail, current)) _persistenceTail = null;
    }
  }
}
