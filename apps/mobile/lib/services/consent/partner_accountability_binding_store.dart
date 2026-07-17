import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PartnerAccountabilityBindingPersistence {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

abstract interface class PartnerAccountabilityBindingQuarantine {
  Future<bool> isQuarantined();
  Future<void> quarantine();
  Future<void> release();
}

final class SharedPreferencesPartnerAccountabilityBindingQuarantine
    implements PartnerAccountabilityBindingQuarantine {
  const SharedPreferencesPartnerAccountabilityBindingQuarantine();

  static const _key = 'partner_lpp_accountability_quarantined_v1';
  static bool _processQuarantined = false;

  @override
  Future<bool> isQuarantined() async {
    if (_processQuarantined) return true;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  @override
  Future<void> quarantine() async {
    _processQuarantined = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, true);
  }

  @override
  Future<void> release() async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(_key);
    if (!removed && preferences.containsKey(_key)) {
      throw StateError('Accountability quarantine release failed');
    }
    _processQuarantined = false;
  }
}

final class _MemoryPartnerAccountabilityBindingQuarantine
    implements PartnerAccountabilityBindingQuarantine {
  bool quarantined = false;

  @override
  Future<bool> isQuarantined() async => quarantined;

  @override
  Future<void> quarantine() async => quarantined = true;

  @override
  Future<void> release() async => quarantined = false;
}

final class SecurePartnerAccountabilityBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  const SecurePartnerAccountabilityBindingPersistence({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  }) : _storage = storage;

  static const _key = 'partner_lpp_accountability_binding_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class PartnerAccountabilityBindingStore {
  PartnerAccountabilityBindingStore({
    PartnerAccountabilityBindingPersistence? persistence,
    PartnerAccountabilityBindingQuarantine? quarantine,
    Duration operationTimeout = const Duration(seconds: 2),
  })  : _persistence = persistence ??
            const SecurePartnerAccountabilityBindingPersistence(),
        _quarantine = quarantine ??
            (persistence == null
                ? const SharedPreferencesPartnerAccountabilityBindingQuarantine()
                : _MemoryPartnerAccountabilityBindingQuarantine()),
        _operationTimeout = operationTimeout;

  final PartnerAccountabilityBindingPersistence _persistence;
  final PartnerAccountabilityBindingQuarantine _quarantine;
  final Duration _operationTimeout;
  Future<void>? _mutationTail;
  bool _sessionQuarantined = false;

  Future<PartnerAccountabilityBindingEnvelope> load() async {
    if (await _isQuarantined()) {
      return const PartnerAccountabilityBindingEnvelope();
    }
    try {
      final raw = await _persistence.read().timeout(_operationTimeout);
      return PartnerAccountabilityBindingEnvelope.fromJsonString(raw);
    } on Object {
      await _setQuarantined();
      return const PartnerAccountabilityBindingEnvelope();
    }
  }

  Future<PartnerAccountabilityBinding> beginPending({
    required String receiptId,
    required String manualPartnerOwnerId,
    required DateTime now,
    required String noticeVersion,
    required String policyVersion,
    required String privacyContact,
    required String rightsChannel,
  }) =>
      _serialize(() async {
        final current = await load();
        final existing = current.pending;
        if (existing != null) {
          if (existing.receiptId != receiptId ||
              existing.manualPartnerOwnerId != manualPartnerOwnerId ||
              existing.noticeVersion != noticeVersion ||
              existing.policyVersion != policyVersion ||
              existing.privacyContact != privacyContact ||
              existing.rightsChannel != rightsChannel) {
            throw StateError(
                'A different partner accountability attempt is pending');
          }
          return existing;
        }
        final pending = PartnerAccountabilityBinding(
          receiptId: receiptId,
          manualPartnerOwnerId: manualPartnerOwnerId,
          state: PartnerAccountabilityBindingState.pending,
          createdAt: now.toUtc(),
          noticeVersion: noticeVersion,
          policyVersion: policyVersion,
          privacyContact: privacyContact,
          rightsChannel: rightsChannel,
        );
        await _write(PartnerAccountabilityBindingEnvelope(
          active: current.active,
          pending: pending,
          shadowed: current.active,
        ));
        return pending;
      });

  Future<PartnerAccountabilityBinding> markReceiptCreated({
    required String receiptId,
    required String manualPartnerOwnerId,
    required DateTime now,
    required DateTime expiresAt,
  }) =>
      _serialize(() async {
        final current = await load();
        final pending = _matchingPending(
          current,
          receiptId,
          manualPartnerOwnerId,
        ).copyWith(
          receiptCreatedAt: now.toUtc(),
          expiresAt: expiresAt.toUtc(),
        );
        await _write(PartnerAccountabilityBindingEnvelope(
          active: current.active,
          pending: pending,
          shadowed: current.shadowed,
        ));
        return pending;
      });

  Future<PartnerAccountabilityBinding> activatePending({
    required String receiptId,
    required String manualPartnerOwnerId,
    required String lppSnapshotId,
    required DateTime verifiedAt,
  }) =>
      _serialize(() async {
        if (lppSnapshotId.isEmpty) {
          throw StateError('The LPP snapshot binding is unavailable');
        }
        final current = await load();
        final pending = _matchingPending(
          current,
          receiptId,
          manualPartnerOwnerId,
        );
        if (!pending.hasCreatedReceipt) {
          throw StateError('The accountability receipt is not created');
        }
        final expiry = pending.expiresAt;
        if (expiry == null || !verifiedAt.toUtc().isBefore(expiry)) {
          throw StateError('The accountability receipt is expired');
        }
        final active = pending.copyWith(
          state: PartnerAccountabilityBindingState.active,
          lppSnapshotId: lppSnapshotId,
          lastVerifiedAt: verifiedAt.toUtc(),
          clearFailureStatus: true,
        );
        await _write(PartnerAccountabilityBindingEnvelope(active: active));
        return active;
      });

  Future<void> rollback({
    required String receiptId,
    required String manualPartnerOwnerId,
  }) =>
      _serialize(() async {
        final current = await load();
        final pending = current.pending;
        if (pending == null) return;
        if (pending.receiptId != receiptId ||
            pending.manualPartnerOwnerId != manualPartnerOwnerId) {
          throw StateError('Pending accountability binding mismatch');
        }
        await _write(PartnerAccountabilityBindingEnvelope(
          active: current.shadowed ?? current.active,
        ));
      });

  /// Restores the binding that was authoritative before a failed root/binding
  /// publication. This also compensates the uncertain case where the pending
  /// binding became active but the activation future still completed with an
  /// error.
  Future<void> compensateFailedActivation({
    required String receiptId,
    required String manualPartnerOwnerId,
    required PartnerAccountabilityBinding? previousActive,
  }) =>
      _serialize(() async {
        final current = await _loadPersistedForCompensation();
        final pending = current.pending;
        final active = current.active;
        final failedBindingStillPresent = (pending?.receiptId == receiptId &&
                pending?.manualPartnerOwnerId == manualPartnerOwnerId) ||
            (active?.receiptId == receiptId &&
                active?.manualPartnerOwnerId == manualPartnerOwnerId);
        final alreadyRestored = previousActive != null &&
            active?.receiptId == previousActive.receiptId &&
            active?.manualPartnerOwnerId ==
                previousActive.manualPartnerOwnerId &&
            active?.lppSnapshotId == previousActive.lppSnapshotId &&
            pending == null;
        if (!failedBindingStillPresent && !alreadyRestored) {
          throw StateError('Failed accountability activation mismatch');
        }
        if (alreadyRestored) return;
        await _write(
          PartnerAccountabilityBindingEnvelope(active: previousActive),
        );
      });

  Future<PartnerAccountabilityBindingEnvelope>
      _loadPersistedForCompensation() async {
    final raw = await _persistence.read().timeout(_operationTimeout);
    return PartnerAccountabilityBindingEnvelope.fromJsonString(raw);
  }

  Future<PartnerAccountabilityBinding?> markPartial({
    required PartnerAccountabilityReceiptStatus failureStatus,
  }) =>
      _serialize(() async {
        final current = await load();
        final active = current.active;
        if (active == null) return null;
        final partial = active.copyWith(
          state: PartnerAccountabilityBindingState.partial,
          failureStatus: failureStatus,
        );
        await _write(PartnerAccountabilityBindingEnvelope(active: partial));
        return partial;
      });

  Future<PartnerAccountabilityBinding> verifyActive({
    required String receiptId,
    required DateTime verifiedAt,
    required DateTime expiresAt,
  }) =>
      _serialize(() async {
        final current = await load();
        final active = current.active;
        if (active == null || active.receiptId != receiptId) {
          throw StateError('Active accountability binding mismatch');
        }
        if (!verifiedAt.toUtc().isBefore(expiresAt.toUtc())) {
          throw StateError('The accountability receipt is expired');
        }
        final verified = active.copyWith(
          state: PartnerAccountabilityBindingState.active,
          lastVerifiedAt: verifiedAt.toUtc(),
          expiresAt: expiresAt.toUtc(),
          clearFailureStatus: true,
        );
        await _write(PartnerAccountabilityBindingEnvelope(active: verified));
        return verified;
      });

  /// Privacy-critical purge. A failed or timed-out secure deletion leaves a
  /// durable quarantine marker, so stale receipt bindings remain unreadable.
  Future<bool> clear() => _serialize(() async {
        await _setQuarantined();
        try {
          await _persistence.delete().timeout(_operationTimeout);
          return await _releaseQuarantine();
        } on Object {
          return false;
        }
      });

  PartnerAccountabilityBinding _matchingPending(
    PartnerAccountabilityBindingEnvelope envelope,
    String receiptId,
    String ownerId,
  ) {
    final pending = envelope.pending;
    if (pending == null ||
        pending.receiptId != receiptId ||
        pending.manualPartnerOwnerId != ownerId) {
      throw StateError('Pending accountability binding mismatch');
    }
    return pending;
  }

  Future<void> _write(PartnerAccountabilityBindingEnvelope envelope) async {
    await _setQuarantined();
    try {
      await _persistence
          .write(envelope.toJsonString())
          .timeout(_operationTimeout);
      if (!await _releaseQuarantine()) {
        throw StateError('Accountability quarantine release failed');
      }
    } on Object {
      await _setQuarantined();
      rethrow;
    }
  }

  Future<bool> _isQuarantined() async {
    if (_sessionQuarantined) return true;
    try {
      final quarantined =
          await _quarantine.isQuarantined().timeout(_operationTimeout);
      _sessionQuarantined = quarantined;
      return quarantined;
    } on Object {
      _sessionQuarantined = true;
      return true;
    }
  }

  Future<void> _setQuarantined() async {
    _sessionQuarantined = true;
    try {
      await _quarantine.quarantine().timeout(_operationTimeout);
    } on Object {
      // The in-process guard remains closed when durable quarantine is down.
    }
  }

  Future<bool> _releaseQuarantine() async {
    try {
      await _quarantine.release().timeout(_operationTimeout);
      _sessionQuarantined = false;
      return true;
    } on Object {
      _sessionQuarantined = true;
      return false;
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _mutationTail;
    final completer = Completer<void>();
    _mutationTail = completer.future;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completer.complete();
      if (identical(_mutationTail, completer.future)) _mutationTail = null;
    }
  }
}
