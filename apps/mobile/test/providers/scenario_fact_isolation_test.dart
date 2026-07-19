import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/session_epoch.dart';

final class _MemoryScenarioCache implements ScenarioSessionCache {
  String? value;
  bool unavailable = false;
  int clears = 0;
  int concurrentWrites = 0;
  int _activeWrites = 0;
  Completer<void>? nextWriteStarted;
  Completer<void>? nextWriteRelease;

  @override
  Future<void> clear() async {
    if (unavailable) throw StateError('cache unavailable');
    clears++;
    value = null;
  }

  @override
  Future<String?> read() async {
    if (unavailable) throw StateError('cache unavailable');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (unavailable) throw StateError('cache unavailable');
    if (_activeWrites > 0) concurrentWrites++;
    _activeWrites++;
    final started = nextWriteStarted;
    final release = nextWriteRelease;
    nextWriteStarted = null;
    nextWriteRelease = null;
    started?.complete();
    try {
      if (release != null) await release.future;
      this.value = value;
    } finally {
      _activeWrites--;
    }
  }
}

void main() {
  test('production session termination explicitly purges scenario persistence',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(
      source,
      contains('await scenarios.purgeSessionPersistence();'),
      reason: 'The scenario cache must be part of the strict durable purge, '
          'not only the later in-memory clear or global secure-storage sweep.',
    );
  });

  test(
    'EPL and rente-capital completion payloads never expose scenario outputs',
    () {
      const callers = <String, String>{
        'EPL': 'lib/screens/lpp_deep/epl_screen.dart',
        'rente-capital': 'lib/screens/arbitrage/rente_vs_capital_screen.dart',
      };

      for (final caller in callers.entries) {
        final source = File(caller.value).readAsStringSync();
        expect(
          source,
          isNot(contains('stepOutputs: {')),
          reason: '${caller.key} persists raw scenario outputs instead of an '
              'opaque scenario ID and status',
        );
      }
    },
  );

  group('bounded encrypted scenario store', () {
    const eplId = '11111111-1111-4111-8111-111111111111';
    const renteCapitalId = '22222222-2222-4222-8222-222222222222';
    late _MemoryScenarioCache cache;
    late ScenarioSessionStore store;

    setUp(() {
      cache = _MemoryScenarioCache();
      final ids = <String>[eplId, renteCapitalId].iterator;
      store = ScenarioSessionStore(
        cache: cache,
        idFactory: () {
          ids.moveNext();
          return ids.current;
        },
        clock: () => DateTime.utc(2026, 7, 19, 9),
      );
    });

    test('two opaque kinds never read each other', () async {
      final epl = await store.create(
        const EplScenarioLevers(requestedWithdrawal: 80000),
      );
      final renteCapital = await store.create(
        const RenteCapitalScenarioLevers(
          retirementAge: 64,
          annualBuyback: 12000,
          hasEpl: false,
          eplAmount: 0,
          returnRatePercent: 3,
          withdrawalRatePercent: 4,
          inflationPercent: 2,
          lifeExpectancy: 88,
        ),
      );

      expect(epl.id, eplId);
      expect(renteCapital.id, renteCapitalId);
      expect(
        await store.read(eplId, expectedKind: ScenarioKind.epl),
        isNotNull,
      );
      expect(
        await store.read(eplId, expectedKind: ScenarioKind.renteCapital),
        isNull,
      );
      expect(
        await store.read(
          renteCapitalId,
          expectedKind: ScenarioKind.renteCapital,
        ),
        isNotNull,
      );
      expect(
        await store.read(renteCapitalId, expectedKind: ScenarioKind.epl),
        isNull,
      );
    });

    test('cache stores typed levers but no certified facts or outputs',
        () async {
      await store.create(
        const EplScenarioLevers(requestedWithdrawal: 80000),
      );

      expect(cache.value, isNotNull);
      expect(cache.value, contains('requestedWithdrawal'));
      expect(cache.value, isNot(contains('avoirLppTotal')));
      expect(cache.value, isNot(contains('dataSources')));
      expect(cache.value, isNot(contains('sourceDate')));
      expect(cache.value, isNot(contains('stepOutputs')));
      expect(cache.value, isNot(contains('result')));
    });

    test('lifecycle is closed and terminal sessions cannot resurrect',
        () async {
      final draft = await store.create(
        const EplScenarioLevers(requestedWithdrawal: 80000),
      );
      expect(draft.status, ScenarioStatus.draft);

      final calculated = await store.transition(
        draft.id,
        expectedKind: ScenarioKind.epl,
        next: ScenarioStatus.calculated,
      );
      expect(calculated?.status, ScenarioStatus.calculated);

      final completed = await store.transition(
        draft.id,
        expectedKind: ScenarioKind.epl,
        next: ScenarioStatus.completed,
      );
      expect(completed?.status, ScenarioStatus.completed);
      expect(
        await store.transition(
          draft.id,
          expectedKind: ScenarioKind.epl,
          next: ScenarioStatus.calculated,
        ),
        isNull,
      );
      expect(
        await store.updateLevers(
          draft.id,
          expectedKind: ScenarioKind.epl,
          levers: const EplScenarioLevers(requestedWithdrawal: 99000),
        ),
        isNull,
      );

      final draftToAbandon = await store.create(
        const RenteCapitalScenarioLevers(
          retirementAge: 65,
          annualBuyback: 0,
          hasEpl: false,
          eplAmount: 0,
          returnRatePercent: 3,
          withdrawalRatePercent: 4,
          inflationPercent: 2,
          lifeExpectancy: 85,
        ),
      );
      expect(
        await store.transition(
          draftToAbandon.id,
          expectedKind: ScenarioKind.renteCapital,
          next: ScenarioStatus.completed,
        ),
        isNull,
      );
      final abandoned = await store.transition(
        draftToAbandon.id,
        expectedKind: ScenarioKind.renteCapital,
        next: ScenarioStatus.abandoned,
      );
      expect(abandoned?.status, ScenarioStatus.abandoned);
      expect(
        await store.latest(ScenarioKind.renteCapital),
        isNull,
      );
    });

    test('malformed and unavailable caches fail closed', () async {
      cache.value = '{not-json';
      expect(await store.load(), isEmpty);
      expect(cache.value, isNull);
      expect(cache.clears, 1);

      cache.unavailable = true;
      expect(await store.load(), isEmpty);
      expect(
        () => store.create(
          const EplScenarioLevers(requestedWithdrawal: 80000),
        ),
        throwsStateError,
      );
    });

    test('absent and malformed UUIDs fail closed', () async {
      await store.create(
        const EplScenarioLevers(requestedWithdrawal: 80000),
      );

      expect(await store.read('', expectedKind: ScenarioKind.epl), isNull);
      expect(
        await store.read('scenario-1', expectedKind: ScenarioKind.epl),
        isNull,
      );
    });
  });

  group('scenario provider reload and session boundary', () {
    const eplId = '33333333-3333-4333-8333-333333333333';
    late _MemoryScenarioCache cache;
    late SessionEpoch epoch;

    ScenarioSessionStore buildStore() => ScenarioSessionStore(
          cache: cache,
          idFactory: () => eplId,
          clock: () => DateTime.utc(2026, 7, 19, 10),
        );

    setUp(() {
      cache = _MemoryScenarioCache();
      epoch = SessionEpoch();
    });

    test('cold reconstruction restores levers but no derived output', () async {
      final writer = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: true,
      );
      final opened = await writer.open(
        const EplScenarioLevers(requestedWithdrawal: 75000),
        factsReady: true,
      );
      expect(opened?.status, ScenarioStatus.draft);
      await writer.markCalculated(eplId, expectedKind: ScenarioKind.epl);

      final reader = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: true,
      );
      await reader.load();
      final restored = reader.sessionFor(ScenarioKind.epl);

      expect(restored?.id, eplId);
      expect(restored?.status, ScenarioStatus.calculated);
      expect(
        (restored?.levers as EplScenarioLevers).requestedWithdrawal,
        75000,
      );
      expect(cache.value, isNot(contains('output')));
      expect(cache.value, isNot(contains('result')));
    });

    test('serializes the last lever save before terminal transition', () async {
      final provider = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: true,
      );
      await provider.open(
        const EplScenarioLevers(requestedWithdrawal: 75000),
        factsReady: true,
      );
      await provider.markCalculated(eplId, expectedKind: ScenarioKind.epl);

      final writeStarted = Completer<void>();
      final writeRelease = Completer<void>();
      cache.nextWriteStarted = writeStarted;
      cache.nextWriteRelease = writeRelease;
      final save = provider.saveLevers(
        eplId,
        expectedKind: ScenarioKind.epl,
        levers: const EplScenarioLevers(requestedWithdrawal: 99000),
        factsReady: true,
      );
      await writeStarted.future;
      final terminal = provider.markTerminal(
        eplId,
        expectedKind: ScenarioKind.epl,
        status: ScenarioStatus.completed,
      );

      await Future<void>.delayed(Duration.zero);
      writeRelease.complete();
      await save;
      await terminal;
      final persisted = await buildStore().read(
        eplId,
        expectedKind: ScenarioKind.epl,
      );
      expect(persisted?.status, ScenarioStatus.completed);
      expect(cache.concurrentWrites, 0);
      expect(
        (persisted?.levers as EplScenarioLevers).requestedWithdrawal,
        99000,
      );
    });

    test('missing facts and cache failure produce no active session', () async {
      final provider = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: true,
      );

      expect(
        await provider.open(
          const EplScenarioLevers(requestedWithdrawal: 75000),
          factsReady: false,
        ),
        isNull,
      );
      expect(cache.value, isNull);

      cache.unavailable = true;
      expect(
        await provider.open(
          const EplScenarioLevers(requestedWithdrawal: 75000),
          factsReady: true,
        ),
        isNull,
      );
      expect(provider.sessionFor(ScenarioKind.epl), isNull);
    });

    test('kill switch and session change purge or reject state', () async {
      final writer = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: true,
      );
      await writer.open(
        const EplScenarioLevers(requestedWithdrawal: 75000),
        factsReady: true,
      );
      expect(cache.value, isNotNull);

      final disabled = ScenarioSessionProvider(
        store: buildStore(),
        sessionEpoch: epoch,
        enabled: false,
      );
      await disabled.load();
      expect(cache.value, isNull);

      epoch.beginTermination();
      expect(
        await writer.open(
          const EplScenarioLevers(requestedWithdrawal: 99000),
          factsReady: true,
        ),
        isNull,
      );
      writer.clearSessionMemoryAfterPurge();
      expect(writer.sessionFor(ScenarioKind.epl), isNull);
    });
  });
}
