import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/snapshot_service.dart';

/// Tests for SnapshotService — in-memory financial snapshot capture.
///
/// Sprint S33: Arbitrage Phase 2 + Snapshots.
/// Validates creation, retrieval, ordering, and evolution tracking.
void main() {
  setUp(() {
    SnapshotService.deleteAll();
  });

  group('SnapshotService.createSnapshot', () {
    test('creates snapshot with generated ID and timestamp', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'wizard_complete',
        age: 49,
        grossIncome: 122207,
        canton: 'VS',
        replacementRatio: 0.65,
        monthsLiquidity: 6.0,
        taxSavingPotential: 2500,
        confidenceScore: 75,
      );

      expect(snap.id, startsWith('snap_'));
      expect(snap.trigger, 'wizard_complete');
      expect(snap.age, 49);
      expect(snap.grossIncome, 122207);
      expect(snap.canton, 'VS');
      expect(snap.replacementRatio, 0.65);
      expect(snap.monthsLiquidity, 6.0);
      expect(snap.taxSavingPotential, 2500);
      expect(snap.confidenceScore, 75);
    });

    test('each snapshot gets a unique ID', () {
      final snap1 = SnapshotService.createSnapshot(
        trigger: 'test1', age: 30, grossIncome: 60000, canton: 'ZH',
        replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
        confidenceScore: 50,
      );
      final snap2 = SnapshotService.createSnapshot(
        trigger: 'test2', age: 31, grossIncome: 65000, canton: 'BE',
        replacementRatio: 0.55, monthsLiquidity: 4, taxSavingPotential: 1100,
        confidenceScore: 55,
      );
      expect(snap1.id, isNot(equals(snap2.id)));
    });

    test('default enrichmentCount is 3', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'test', age: 40, grossIncome: 80000, canton: 'GE',
        replacementRatio: 0.6, monthsLiquidity: 5, taxSavingPotential: 2000,
        confidenceScore: 60,
      );
      expect(snap.enrichmentCount, 3);
    });

    test('custom enrichmentCount is respected', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'test', age: 40, grossIncome: 80000, canton: 'GE',
        replacementRatio: 0.6, monthsLiquidity: 5, taxSavingPotential: 2000,
        confidenceScore: 60, enrichmentCount: 7,
      );
      expect(snap.enrichmentCount, 7);
    });
  });

  group('SnapshotService.getSnapshots', () {
    test('returns empty list when no snapshots exist', () {
      expect(SnapshotService.getSnapshots(), isEmpty);
    });

    test('returns snapshots in reverse chronological order', () {
      SnapshotService.createSnapshot(
        trigger: 'first', age: 30, grossIncome: 60000, canton: 'ZH',
        replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
        confidenceScore: 50,
      );
      SnapshotService.createSnapshot(
        trigger: 'second', age: 31, grossIncome: 65000, canton: 'ZH',
        replacementRatio: 0.55, monthsLiquidity: 4, taxSavingPotential: 1100,
        confidenceScore: 55,
      );
      final snaps = SnapshotService.getSnapshots();
      expect(snaps.length, 2);
      expect(snaps.first.trigger, 'second',
          reason: 'Most recent snapshot should be first');
    });

    test('respects limit parameter', () {
      for (int i = 0; i < 15; i++) {
        SnapshotService.createSnapshot(
          trigger: 'snap_$i', age: 30 + i, grossIncome: 60000, canton: 'ZH',
          replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
          confidenceScore: 50,
        );
      }
      final limited = SnapshotService.getSnapshots(limit: 5);
      expect(limited.length, 5);
    });

    test('default limit is 10', () {
      for (int i = 0; i < 15; i++) {
        SnapshotService.createSnapshot(
          trigger: 'snap_$i', age: 30, grossIncome: 60000, canton: 'ZH',
          replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
          confidenceScore: 50,
        );
      }
      final snaps = SnapshotService.getSnapshots();
      expect(snaps.length, 10);
    });
  });

  group('SnapshotService.deleteAll', () {
    test('clears all snapshots', () {
      SnapshotService.createSnapshot(
        trigger: 'test', age: 40, grossIncome: 80000, canton: 'GE',
        replacementRatio: 0.6, monthsLiquidity: 5, taxSavingPotential: 2000,
        confidenceScore: 60,
      );
      expect(SnapshotService.getSnapshots(), isNotEmpty);
      SnapshotService.deleteAll();
      expect(SnapshotService.getSnapshots(), isEmpty);
    });
  });

  group('SnapshotService.getEvolution', () {
    test('returns chronological evolution for replacementRatio', () {
      SnapshotService.createSnapshot(
        trigger: 'first', age: 40, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.55, monthsLiquidity: 4, taxSavingPotential: 1500,
        confidenceScore: 60,
      );
      SnapshotService.createSnapshot(
        trigger: 'second', age: 41, grossIncome: 85000, canton: 'ZH',
        replacementRatio: 0.60, monthsLiquidity: 5, taxSavingPotential: 1600,
        confidenceScore: 65,
      );
      final evolution = SnapshotService.getEvolution('replacementRatio');
      expect(evolution.length, 2);
      expect(evolution.first.value, 0.55);
      expect(evolution.last.value, 0.60);
    });

    test('returns evolution for confidenceScore', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 40, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
        confidenceScore: 40,
      );
      SnapshotService.createSnapshot(
        trigger: 'b', age: 40, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
        confidenceScore: 70,
      );
      final evolution = SnapshotService.getEvolution('confidenceScore');
      expect(evolution.last.value, greaterThan(evolution.first.value));
    });

    test('returns 0.0 for unknown field', () {
      SnapshotService.createSnapshot(
        trigger: 'test', age: 40, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.5, monthsLiquidity: 3, taxSavingPotential: 1000,
        confidenceScore: 50,
      );
      final evolution = SnapshotService.getEvolution('unknownField');
      expect(evolution.first.value, 0.0);
    });

    test('returns empty list when no snapshots', () {
      final evolution = SnapshotService.getEvolution('replacementRatio');
      expect(evolution, isEmpty);
    });
  });

  group('FinancialSnapshot — data model', () {
    test('all fields are stored correctly via createSnapshot', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'manual',
        age: 55,
        grossIncome: 150000,
        canton: 'TI',
        replacementRatio: 0.7,
        monthsLiquidity: 8,
        taxSavingPotential: 3000,
        confidenceScore: 80,
        enrichmentCount: 2,
      );
      expect(snap.trigger, 'manual');
      expect(snap.age, 55);
      expect(snap.canton, 'TI');
      expect(snap.enrichmentCount, 2);
      expect(snap.createdAt, isNotNull);
    });
  });
}
