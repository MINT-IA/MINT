import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryPersistence
    implements PartnerAccountabilityBindingPersistence {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

final class _HangingPersistence
    implements PartnerAccountabilityBindingPersistence {
  final readCompleter = Completer<String?>();
  final writeCompleter = Completer<void>();
  final deleteCompleter = Completer<void>();

  @override
  Future<void> delete() => deleteCompleter.future;

  @override
  Future<String?> read() => readCompleter.future;

  @override
  Future<void> write(String value) => writeCompleter.future;
}

final class _MemoryQuarantine
    implements PartnerAccountabilityBindingQuarantine {
  bool quarantined = false;

  @override
  Future<bool> isQuarantined() async => quarantined;

  @override
  Future<void> quarantine() async => quarantined = true;

  @override
  Future<void> release() async => quarantined = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldReceipt = '11111111-1111-4111-8111-111111111111';
  const oldOwner = '22222222-2222-4222-8222-222222222222';
  const newReceipt = '33333333-3333-4333-8333-333333333333';
  const newOwner = '44444444-4444-4444-8444-444444444444';
  const oldSnapshot = '55555555-5555-4555-8555-555555555555';
  const newSnapshot = '66666666-6666-4666-8666-666666666666';
  final now = DateTime.utc(2026, 7, 15, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('diagnostic reset purges the production accountability binding',
      () async {
    final store = PartnerAccountabilityBindingStore();
    await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    expect((await store.load()).pending?.receiptId, newReceipt);

    await ReportPersistenceService.clearDiagnostic();

    expect((await store.load()).effective, isNull);
  });

  test('secure read write and delete are bounded and remain quarantined',
      () async {
    const timeout = Duration(milliseconds: 10);

    final readQuarantine = _MemoryQuarantine();
    final readStore = PartnerAccountabilityBindingStore(
      persistence: _HangingPersistence(),
      quarantine: readQuarantine,
      operationTimeout: timeout,
    );
    expect((await readStore.load()).effective, isNull);
    expect(readQuarantine.quarantined, isTrue);

    final writeQuarantine = _MemoryQuarantine();
    final writeStore = PartnerAccountabilityBindingStore(
      persistence: _HangingPersistence(),
      quarantine: writeQuarantine,
      operationTimeout: timeout,
    );
    await expectLater(
      writeStore.beginPending(
        receiptId: newReceipt,
        manualPartnerOwnerId: newOwner,
        now: now,
        noticeVersion: 'notice-v1',
        policyVersion: 'policy-v1',
        privacyContact: 'privacy@example.test',
        rightsChannel: 'https://example.test/rights',
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(writeQuarantine.quarantined, isTrue);

    final deleteQuarantine = _MemoryQuarantine();
    final deleteStore = PartnerAccountabilityBindingStore(
      persistence: _HangingPersistence(),
      quarantine: deleteQuarantine,
      operationTimeout: timeout,
    );
    expect(await deleteStore.clear(), isFalse);
    expect(deleteQuarantine.quarantined, isTrue);
  });

  test('pending shadows active and rollback restores the prior active',
      () async {
    final persistence = _MemoryPersistence();
    final store = PartnerAccountabilityBindingStore(persistence: persistence);
    await store.beginPending(
      receiptId: oldReceipt,
      manualPartnerOwnerId: oldOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: oldReceipt,
      manualPartnerOwnerId: oldOwner,
      now: now,
      expiresAt: now.add(const Duration(days: 365)),
    );
    await store.activatePending(
      receiptId: oldReceipt,
      manualPartnerOwnerId: oldOwner,
      lppSnapshotId: oldSnapshot,
      verifiedAt: now,
    );

    await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now.add(const Duration(minutes: 1)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    final pending = await store.load();
    expect(pending.effective?.receiptId, newReceipt);
    expect(pending.shadowed?.receiptId, oldReceipt);

    await store.rollback(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
    );
    final restored = await store.load();
    expect(restored.pending, isNull);
    expect(restored.active?.receiptId, oldReceipt);
    expect(restored.active?.state, PartnerAccountabilityBindingState.active);
  });

  test('same logical retry reuses IDs and activates only after receipt create',
      () async {
    final store = PartnerAccountabilityBindingStore(
      persistence: _MemoryPersistence(),
    );
    final first = await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    final retry = await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now.add(const Duration(minutes: 1)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    expect(retry.receiptId, first.receiptId);
    expect(retry.manualPartnerOwnerId, first.manualPartnerOwnerId);

    expect(
      () => store.activatePending(
        receiptId: newReceipt,
        manualPartnerOwnerId: newOwner,
        lppSnapshotId: newSnapshot,
        verifiedAt: now,
      ),
      throwsStateError,
    );
    await store.markReceiptCreated(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      expiresAt: now.add(const Duration(days: 365)),
    );
    final active = await store.activatePending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      lppSnapshotId: newSnapshot,
      verifiedAt: now,
    );
    expect(active.isCurrentAt(now), isTrue);
  });

  test('same IDs cannot reuse a pending binding across notice or policy drift',
      () async {
    final store = PartnerAccountabilityBindingStore(
      persistence: _MemoryPersistence(),
    );
    await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );

    await expectLater(
      store.beginPending(
        receiptId: newReceipt,
        manualPartnerOwnerId: newOwner,
        now: now.add(const Duration(minutes: 1)),
        noticeVersion: 'notice-v2',
        policyVersion: 'policy-v1',
        privacyContact: 'privacy@example.test',
        rightsChannel: 'https://example.test/rights',
      ),
      throwsStateError,
    );
    await expectLater(
      store.beginPending(
        receiptId: newReceipt,
        manualPartnerOwnerId: newOwner,
        now: now.add(const Duration(minutes: 1)),
        noticeVersion: 'notice-v1',
        policyVersion: 'policy-v2',
        privacyContact: 'privacy@example.test',
        rightsChannel: 'https://example.test/rights',
      ),
      throwsStateError,
    );
  });

  test('offline lifecycle becomes partial without deleting the binding',
      () async {
    final store = PartnerAccountabilityBindingStore(
      persistence: _MemoryPersistence(),
    );
    await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      expiresAt: now.add(const Duration(days: 365)),
    );
    await store.activatePending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      lppSnapshotId: newSnapshot,
      verifiedAt: now,
    );
    final partial = await store.markPartial(
      failureStatus: PartnerAccountabilityReceiptStatus.offline,
    );
    expect(partial?.state, PartnerAccountabilityBindingState.partial);
    expect(partial?.failureStatus, PartnerAccountabilityReceiptStatus.offline);
    expect((await store.load()).active?.receiptId, newReceipt);
  });

  test('cold current check fails closed at or after backend expiry', () async {
    final store = PartnerAccountabilityBindingStore(
      persistence: _MemoryPersistence(),
    );
    await store.beginPending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      now: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    final active = await store.activatePending(
      receiptId: newReceipt,
      manualPartnerOwnerId: newOwner,
      lppSnapshotId: newSnapshot,
      verifiedAt: now,
    );
    expect(active.isCurrentAt(now.add(const Duration(minutes: 4))), isTrue);
    expect(active.isCurrentAt(now.add(const Duration(minutes: 5))), isFalse);
  });

  test('legacy active binding without an LPP snapshot stays fail-closed',
      () async {
    final legacy = PartnerAccountabilityBinding.fromJson({
      'receiptId': oldReceipt,
      'manualPartnerOwnerId': oldOwner,
      'state': 'active',
      'createdAt': now.toIso8601String(),
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'privacyContact': 'privacy@example.test',
      'rightsChannel': 'https://example.test/rights',
      'lastVerifiedAt': now.toIso8601String(),
      'receiptCreatedAt': now.toIso8601String(),
      'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
      'failureStatus': null,
    });

    expect(legacy, isNotNull);
    expect(legacy!.isCurrentAt(now), isFalse);
  });

  test('legacy binding without accepted rights snapshot is unreadable',
      () async {
    final persistence = _MemoryPersistence()
      ..value = jsonEncode({
        'schemaVersion': 1,
        'active': {
          'receiptId': oldReceipt,
          'manualPartnerOwnerId': oldOwner,
          'state': 'active',
          'createdAt': now.toIso8601String(),
          'noticeVersion': 'notice-v1',
          'policyVersion': 'policy-v1',
          'lastVerifiedAt': now.toIso8601String(),
          'receiptCreatedAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
        },
      });
    final store = PartnerAccountabilityBindingStore(persistence: persistence);

    expect((await store.load()).effective, isNull);
  });

  test('binding with empty accepted rights snapshot is unreadable', () async {
    final persistence = _MemoryPersistence()
      ..value = jsonEncode({
        'schemaVersion': 1,
        'active': {
          'receiptId': oldReceipt,
          'manualPartnerOwnerId': oldOwner,
          'state': 'active',
          'createdAt': now.toIso8601String(),
          'noticeVersion': 'notice-v1',
          'policyVersion': 'policy-v1',
          'privacyContact': '',
          'rightsChannel': '',
          'lastVerifiedAt': now.toIso8601String(),
          'receiptCreatedAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
        },
      });
    final store = PartnerAccountabilityBindingStore(persistence: persistence);

    expect((await store.load()).effective, isNull);
  });
}
