import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';

class MemoryAdapter implements MintNext3aTaskStorageAdapter {
  String? value;
  bool failWrite = false;
  bool persistThenFailWrite = false;
  bool failRead = false;
  bool failDelete = false;
  Completer<void>? writeStarted;
  Completer<void>? writeGate;
  Completer<void>? readStarted;
  Completer<void>? readGate;
  final List<Completer<void>> deleteGates = [];
  final Set<int> failingDeleteCalls = {};
  int deleteCalls = 0;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('read failed');
    final snapshot = value;
    if (readStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await readGate?.future;
    return snapshot;
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('write failed');
    if (writeStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await writeGate?.future;
    this.value = value;
    if (persistThenFailWrite) throw StateError('ambiguous write failure');
  }

  @override
  Future<void> delete(String key) async {
    final call = deleteCalls++;
    if (call < deleteGates.length) await deleteGates[call].future;
    if (failDelete || failingDeleteCalls.contains(call)) {
      throw StateError('delete failed');
    }
    value = null;
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);
  late MemoryAdapter adapter;
  late MintNext3aTaskStore store;

  setUp(() {
    adapter = MemoryAdapter();
    store = MintNext3aTaskStore(adapter: adapter, now: () => now);
  });

  test('saves exactly the eight allowed fields and is idempotent', () async {
    final first = await store.save(taxYear: 2026);
    final encoded = adapter.value!;
    expect((jsonDecode(encoded) as Map).keys.toSet(), {
      'schema_version',
      'task_id',
      'tax_year',
      'status',
      'created_at',
      'updated_at',
      'expires_at',
      'source',
    });
    expect(first.status, 'open');
    expect(first.taxYear, 2026);
    expect(await store.save(taxYear: 2026), first);
    expect(adapter.value, encoded);
  });

  test('write failure propagates and creates no task', () async {
    adapter.failWrite = true;
    await expectLater(
      store.save(taxYear: 2026),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'write'),
      ),
    );
    expect(adapter.value, isNull);
  });

  test('ambiguous write failure purges the owned key before propagating',
      () async {
    adapter.persistThenFailWrite = true;

    await expectLater(
      store.save(taxYear: 2026),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'write'),
      ),
    );

    expect(adapter.value, isNull);
  });

  test('ambiguous write cleanup failure stays explicit', () async {
    adapter.persistThenFailWrite = true;
    adapter.failDelete = true;

    await expectLater(
      store.save(taxYear: 2026),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'write_cleanup'),
      ),
    );

    expect(adapter.value, isNotNull);
  });

  test('one supplied operation instant governs save and validation', () async {
    final operationTime = DateTime.utc(2026, 12, 31, 23, 59, 59);
    final task = await store.save(taxYear: 2026, at: operationTime);

    expect(task.createdAt, operationTime);
    expect(task.updatedAt, operationTime);
    expect(await store.read(at: operationTime), task);
    expect(task.expiresAt, DateTime.utc(2027, 1, 31, 23, 59, 59));
  });

  test('previous tax year remains readable only during January carryover',
      () async {
    final created = DateTime.utc(2026, 12, 31, 12);
    final task = await store.save(taxYear: 2026, at: created);

    expect(await store.read(at: DateTime.utc(2027, 1, 15)), task);
    expect(await store.read(at: DateTime.utc(2027, 2, 1)), isNull);
    expect(adapter.value, isNull);
  });

  test('invalid, expired, and future-created values are purged', () async {
    Future<void> rejected(Map<String, Object?> value) async {
      adapter.value = jsonEncode(value);
      expect(await store.read(), isNull);
      expect(adapter.value, isNull);
    }

    final valid = (await store.save(taxYear: 2026)).toJson();
    final hostilePayloads = <Map<String, Object?>>[
      {...valid, 'income': 1},
      {...valid}..remove('source'),
      {...valid, 'schema_version': 2},
      {...valid, 'schema_version': '1'},
      {...valid, 'task_id': '3a.pay_now'},
      {...valid, 'tax_year': '2026'},
      {...valid, 'status': 'archived'},
      {...valid, 'status': 'done'},
      {...valid, 'source': 'profile_inference'},
      {
        ...valid,
        'created_at': now.add(const Duration(seconds: 1)).toIso8601String(),
      },
      {
        ...valid,
        'updated_at': now.add(const Duration(seconds: 1)).toIso8601String(),
      },
      {
        ...valid,
        'updated_at':
            now.subtract(const Duration(seconds: 1)).toIso8601String(),
      },
      {...valid, 'created_at': 7},
      {...valid, 'expires_at': '2026-01-01T00:00:00.000Z'},
      {...valid, 'expires_at': '2027-01-31T23:59:59.001Z'},
      {
        ...valid,
        'tax_year': 9998,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'expires_at': '9999-01-31T23:59:59.000Z',
      },
    ];
    for (final hostile in hostilePayloads) {
      await rejected(hostile);
    }
    adapter.value = '{broken';
    expect(await store.read(), isNull);
    expect(adapter.value, isNull);
    adapter.value = jsonEncode(['not', 'a', 'map']);
    expect(await store.read(), isNull);
    expect(adapter.value, isNull);
  });

  test('delete removes owned key', () async {
    await store.save(taxYear: 2026);
    await store.delete();
    expect(await store.read(), isNull);
  });

  test('purge requested during an in-flight save wins without resurrection',
      () async {
    adapter.writeStarted = Completer<void>();
    adapter.writeGate = Completer<void>();

    final save = store.save(taxYear: 2026);
    await adapter.writeStarted!.future;
    final purge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    adapter.writeGate!.complete();

    await expectLater(
      save,
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(await purge, isTrue);
    expect(adapter.value, isNull);
  });

  test('purge supersedes an idempotent save while its read is in flight',
      () async {
    await store.save(taxYear: 2026);
    adapter.readStarted = Completer<void>();
    adapter.readGate = Completer<void>();

    final save = store.save(taxYear: 2026);
    await adapter.readStarted!.future;
    final purge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    adapter.readGate!.complete();

    await expectLater(
      save,
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(await purge, isTrue);
    expect(adapter.value, isNull);
  });

  test('read in flight when purge is requested cannot publish stale task',
      () async {
    await store.save(taxYear: 2026);
    adapter.readStarted = Completer<void>();
    adapter.readGate = Completer<void>();

    final read = store.read();
    await adapter.readStarted!.future;
    final purge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    adapter.readGate!.complete();

    expect(await read, isNull);
    expect(await purge, isTrue);
    expect(adapter.value, isNull);
  });

  test('save requested while purge is pending stays behind the closed barrier',
      () async {
    adapter.writeStarted = Completer<void>();
    adapter.writeGate = Completer<void>();

    final earlierSave = store.save(taxYear: 2026);
    await adapter.writeStarted!.future;
    final purge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    final saveDuringPurge = store.save(taxYear: 2026);
    adapter.writeGate!.complete();

    await expectLater(
      earlierSave,
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(await purge, isTrue);
    await expectLater(
      saveDuringPurge,
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(adapter.value, isNull);

    expect((await store.save(taxYear: 2026)).status, 'open');
  });

  test('read requested while purge is pending cannot publish the old task',
      () async {
    await store.save(taxYear: 2026);
    adapter.readStarted = Completer<void>();
    adapter.readGate = Completer<void>();

    final earlierRead = store.read();
    await adapter.readStarted!.future;
    final purge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    final readDuringPurge = store.read();
    adapter.readGate!.complete();

    expect(await earlierRead, isNull);
    expect(await readDuringPurge, isNull);
    expect(await purge, isTrue);
    expect(adapter.value, isNull);
  });

  test('failed purge stays fail-closed until a successful retry', () async {
    await store.save(taxYear: 2026);
    adapter.failDelete = true;

    expect(
      await MintNext3aTaskStore.purgeOwnedTask(adapter: adapter),
      isFalse,
    );
    expect(await store.read(), isNull);
    await expectLater(
      store.save(taxYear: 2026),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(adapter.value, isNotNull);

    adapter.failDelete = false;
    expect(
      await MintNext3aTaskStore.purgeOwnedTask(adapter: adapter),
      isTrue,
    );
    expect(adapter.value, isNull);
    expect((await store.save(taxYear: 2026)).status, 'open');
  });

  test('overlapping purges stay closed until the final purge succeeds',
      () async {
    await store.save(taxYear: 2026);
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    adapter.deleteGates.addAll([firstGate, secondGate]);
    adapter.failingDeleteCalls.add(0);

    final firstPurge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    final secondPurge = MintNext3aTaskStore.purgeOwnedTask(adapter: adapter);
    final saveDuringPurges = store.save(taxYear: 2026);
    expect(await store.read(), isNull);

    firstGate.complete();
    expect(await firstPurge, isFalse);
    expect(await store.read(), isNull);

    secondGate.complete();
    expect(await secondPurge, isTrue);
    await expectLater(
      saveDuringPurges,
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'superseded'),
      ),
    );
    expect(adapter.value, isNull);
    expect((await store.save(taxYear: 2026)).status, 'open');
  });

  test('adapter read and delete failures stay explicit', () async {
    adapter.failRead = true;
    await expectLater(
      store.read(),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'read'),
      ),
    );
    adapter.failRead = false;
    await store.save(taxYear: 2026);
    adapter.failDelete = true;
    await expectLater(
      store.delete(),
      throwsA(
        isA<MintNext3aTaskStorageException>()
            .having((error) => error.operation, 'operation', 'delete'),
      ),
    );
    expect(adapter.value, isNotNull);
    adapter.failDelete = false;
    expect(
      await MintNext3aTaskStore.purgeOwnedTask(adapter: adapter),
      isTrue,
    );
    expect(adapter.value, isNull);
  });
}
