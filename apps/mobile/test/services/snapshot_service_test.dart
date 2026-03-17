import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/snapshot_service.dart';

void main() {
  // Reset static state before each test.
  setUp(() {
    SnapshotService.deleteAll();
  });

  // ---------------------------------------------------------------------------
  // createSnapshot
  // ---------------------------------------------------------------------------
  group('SnapshotService — createSnapshot', () {
    test('creates a snapshot with generated id', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'wizard_complete',
        age: 49,
        grossIncome: 122207,
        canton: 'VS',
        replacementRatio: 0.655,
        monthsLiquidity: 6.0,
        taxSavingPotential: 7258,
        confidenceScore: 72,
      );
      expect(snap.id, startsWith('snap_'));
      expect(snap.trigger, 'wizard_complete');
      expect(snap.age, 49);
      expect(snap.grossIncome, 122207);
      expect(snap.canton, 'VS');
    });

    test('createdAt is approximately now', () {
      final before = DateTime.now();
      final snap = SnapshotService.createSnapshot(
        trigger: 'annual_refresh',
        age: 43,
        grossIncome: 67000,
        canton: 'VS',
        replacementRatio: 0.50,
        monthsLiquidity: 3.0,
        taxSavingPotential: 5000,
        confidenceScore: 55,
      );
      final after = DateTime.now();
      expect(snap.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(snap.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('enrichmentCount defaults to 3', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'test',
        age: 30,
        grossIncome: 80000,
        canton: 'ZH',
        replacementRatio: 0.60,
        monthsLiquidity: 4.0,
        taxSavingPotential: 3000,
        confidenceScore: 45,
      );
      expect(snap.enrichmentCount, 3);
    });

    test('enrichmentCount can be overridden', () {
      final snap = SnapshotService.createSnapshot(
        trigger: 'test',
        age: 30,
        grossIncome: 80000,
        canton: 'ZH',
        replacementRatio: 0.60,
        monthsLiquidity: 4.0,
        taxSavingPotential: 3000,
        confidenceScore: 45,
        enrichmentCount: 0,
      );
      expect(snap.enrichmentCount, 0);
    });

    test('consecutive snapshots have unique ids', () {
      final snap1 = SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      final snap2 = SnapshotService.createSnapshot(
        trigger: 'b', age: 31, grossIncome: 82000, canton: 'ZH',
        replacementRatio: 0.62, monthsLiquidity: 4.5, taxSavingPotential: 3100,
        confidenceScore: 55,
      );
      expect(snap1.id, isNot(snap2.id));
    });
  });

  // ---------------------------------------------------------------------------
  // getSnapshots
  // ---------------------------------------------------------------------------
  group('SnapshotService — getSnapshots', () {
    test('returns empty list when no snapshots exist', () {
      expect(SnapshotService.getSnapshots(), isEmpty);
    });

    test('returns snapshots in reverse chronological order', () {
      SnapshotService.createSnapshot(
        trigger: 'first', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      SnapshotService.createSnapshot(
        trigger: 'second', age: 31, grossIncome: 82000, canton: 'ZH',
        replacementRatio: 0.62, monthsLiquidity: 4.5, taxSavingPotential: 3100,
        confidenceScore: 55,
      );

      final snapshots = SnapshotService.getSnapshots();
      expect(snapshots.length, 2);
      // Most recent first
      expect(snapshots[0].trigger, 'second');
      expect(snapshots[1].trigger, 'first');
    });

    test('limit parameter restricts results', () {
      for (int i = 0; i < 5; i++) {
        SnapshotService.createSnapshot(
          trigger: 'snap_$i', age: 30 + i, grossIncome: 80000,
          canton: 'ZH', replacementRatio: 0.6, monthsLiquidity: 4,
          taxSavingPotential: 3000, confidenceScore: 50,
        );
      }
      final limited = SnapshotService.getSnapshots(limit: 3);
      expect(limited.length, 3);
    });

    test('limit greater than count returns all snapshots', () {
      SnapshotService.createSnapshot(
        trigger: 'only', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      final all = SnapshotService.getSnapshots(limit: 100);
      expect(all.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteAll
  // ---------------------------------------------------------------------------
  group('SnapshotService — deleteAll', () {
    test('clears all snapshots', () {
      SnapshotService.createSnapshot(
        trigger: 'test', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      expect(SnapshotService.getSnapshots(), isNotEmpty);

      SnapshotService.deleteAll();
      expect(SnapshotService.getSnapshots(), isEmpty);
    });

    test('resets counter so new snapshots start fresh', () {
      SnapshotService.createSnapshot(
        trigger: 'before', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      SnapshotService.deleteAll();

      final snap = SnapshotService.createSnapshot(
        trigger: 'after', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      // Counter resets to 0, then increments to 1
      expect(snap.id, contains('_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // getEvolution
  // ---------------------------------------------------------------------------
  group('SnapshotService — getEvolution', () {
    test('returns empty list when no snapshots', () {
      expect(SnapshotService.getEvolution('replacementRatio'), isEmpty);
    });

    test('returns chronological order for replacementRatio', () {
      SnapshotService.createSnapshot(
        trigger: 'first', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.50, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      SnapshotService.createSnapshot(
        trigger: 'second', age: 31, grossIncome: 82000, canton: 'ZH',
        replacementRatio: 0.65, monthsLiquidity: 5, taxSavingPotential: 3500,
        confidenceScore: 60,
      );

      final evolution = SnapshotService.getEvolution('replacementRatio');
      expect(evolution.length, 2);
      // Chronological: first then second
      expect(evolution[0].value, 0.50);
      expect(evolution[1].value, 0.65);
    });

    test('returns grossIncome evolution', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      final evolution = SnapshotService.getEvolution('grossIncome');
      expect(evolution.length, 1);
      expect(evolution[0].value, 80000);
    });

    test('returns confidenceScore evolution', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 72,
      );
      final evolution = SnapshotService.getEvolution('confidenceScore');
      expect(evolution[0].value, 72);
    });

    test('unknown field returns 0.0 for each snapshot', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      final evolution = SnapshotService.getEvolution('unknownField');
      expect(evolution.length, 1);
      expect(evolution[0].value, 0.0);
    });

    test('monthsLiquidity field works', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 8.5, taxSavingPotential: 3000,
        confidenceScore: 50,
      );
      final evolution = SnapshotService.getEvolution('monthsLiquidity');
      expect(evolution[0].value, 8.5);
    });

    test('taxSavingPotential field works', () {
      SnapshotService.createSnapshot(
        trigger: 'a', age: 30, grossIncome: 80000, canton: 'ZH',
        replacementRatio: 0.6, monthsLiquidity: 4, taxSavingPotential: 7258,
        confidenceScore: 50,
      );
      final evolution = SnapshotService.getEvolution('taxSavingPotential');
      expect(evolution[0].value, 7258);
    });
  });
}
