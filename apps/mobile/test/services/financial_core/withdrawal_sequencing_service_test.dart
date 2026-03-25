import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/withdrawal_sequencing_service.dart';

// ════════════════════════════════════════════════════════════════
//  WITHDRAWAL SEQUENCING SERVICE — edge-case tests
//
//  Covers: zero values, negative-like inputs, single asset,
//  multiple assets same year, empty list, very large values,
//  already-retired profiles, young profiles, extreme lppCapitalPct.
// ════════════════════════════════════════════════════════════════

void main() {
  group('WithdrawalSequencingService — edge cases', () {
    // ──────────────────────────────────────────────────────────
    //  1. Already retired (age >= retirementAge) returns empty
    // ──────────────────────────────────────────────────────────
    test('already retired person returns empty sequences', () {
      final profile = _buildProfile(birthYear: 1950); // age ~76
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );
      expect(result.optimizedSequence, isEmpty);
      expect(result.naiveSequence, isEmpty);
      expect(result.totalTaxOptimized, equals(0));
      expect(result.totalTaxNaive, equals(0));
    });

    // ──────────────────────────────────────────────────────────
    //  2. Very young person (age 25, retirement 65)
    // ──────────────────────────────────────────────────────────
    test('very young person (25) produces valid results', () {
      final profile = _buildProfile(
        birthYear: DateTime.now().year - 25,
        nombre3a: 2,
        totalEpargne3a: 20000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );
      // Should have events (at least 3a withdrawals)
      expect(result.optimizedSequence, isNotEmpty);
      // All events should be in the future
      final currentYear = DateTime.now().year;
      for (final e in result.optimizedSequence) {
        expect(e.year, greaterThan(currentYear));
      }
    });

    // ──────────────────────────────────────────────────────────
    //  3. Single 3a account — one event in both sequences
    // ──────────────────────────────────────────────────────────
    test('single 3a account produces exactly one event per sequence', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 1,
        totalEpargne3a: 100000,
        avoirLppTotal: null,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.0,
      );
      expect(result.optimizedSequence.length, equals(1));
      expect(result.naiveSequence.length, equals(1));
    });

    // ──────────────────────────────────────────────────────────
    //  4. Very large capital (5M total) — no overflow
    // ──────────────────────────────────────────────────────────
    test('very large capital does not overflow', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 5,
        totalEpargne3a: 5000000,
        avoirLppTotal: 2000000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 1.0,
      );
      expect(result.totalTaxOptimized.isFinite, isTrue);
      expect(result.totalTaxNaive.isFinite, isTrue);
      expect(result.taxSavings.isFinite, isTrue);
      // With 5 accounts of 1M each, staggering should produce big savings
      expect(result.taxSavings, greaterThan(0));
    });

    // ──────────────────────────────────────────────────────────
    //  5. Zero 3a + zero LPP capital — empty sequences
    // ──────────────────────────────────────────────────────────
    test('zero capital on all sources returns empty', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 0,
        totalEpargne3a: 0,
        avoirLppTotal: 0,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 1.0,
      );
      expect(result.optimizedSequence, isEmpty);
      expect(result.naiveSequence, isEmpty);
    });

    // ──────────────────────────────────────────────────────────
    //  6. LPP capital 100% — includes LPP event
    // ──────────────────────────────────────────────────────────
    test('lppCapitalPct 1.0 includes full LPP capital event', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 0,
        totalEpargne3a: 0,
        avoirLppTotal: 500000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 1.0,
      );
      // Should have exactly one LPP event
      final lppEvents = result.optimizedSequence
          .where((e) => e.source == 'lpp_capital')
          .toList();
      expect(lppEvents.length, equals(1));
      expect(lppEvents.first.amount, greaterThan(0));
    });

    // ──────────────────────────────────────────────────────────
    //  7. Multiple 3a same-sized — staggered into different years
    // ──────────────────────────────────────────────────────────
    test('multiple same-sized 3a accounts spread across years', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 4,
        totalEpargne3a: 400000, // 100k each
        avoirLppTotal: null,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.0,
      );
      final years = result.optimizedSequence.map((e) => e.year).toSet();
      // With 4 accounts and a 5-year window (60-65), they should be spread
      expect(years.length, greaterThanOrEqualTo(3));
    });

    // ──────────────────────────────────────────────────────────
    //  8. Effective rate between 0 and 1 for all events
    // ──────────────────────────────────────────────────────────
    test('effective rate is between 0 and 1 for all events', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 300000,
        avoirLppTotal: 200000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.5,
      );
      for (final e in [...result.optimizedSequence, ...result.naiveSequence]) {
        expect(e.effectiveRate, greaterThanOrEqualTo(0),
            reason: '${e.source}: effective rate >= 0');
        expect(e.effectiveRate, lessThanOrEqualTo(1),
            reason: '${e.source}: effective rate <= 1');
      }
    });

    // ──────────────────────────────────────────────────────────
    //  9. Savings percent between 0 and 1
    // ──────────────────────────────────────────────────────────
    test('savings percent is between 0 and 1', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );
      expect(result.savingsPercent, greaterThanOrEqualTo(0));
      expect(result.savingsPercent, lessThanOrEqualTo(1));
    });

    // ──────────────────────────────────────────────────────────
    //  10. LPP capital at exactly 0% — no LPP events
    // ──────────────────────────────────────────────────────────
    test('lppCapitalPct 0.0 excludes LPP events even with large LPP', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 1,
        totalEpargne3a: 50000,
        avoirLppTotal: 1000000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.0,
      );
      final lppEvents = result.optimizedSequence
          .where((e) => e.source == 'lpp_capital')
          .toList();
      expect(lppEvents, isEmpty);
      final lppNaiveEvents = result.naiveSequence
          .where((e) => e.source == 'lpp_capital')
          .toList();
      expect(lppNaiveEvents, isEmpty);
    });
  });
}

// ════════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════════

CoachProfile _buildProfile({
  int birthYear = 1970,
  String canton = 'ZH',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  double salaireBrutMensuel = 8000,
  int nombre3a = 3,
  double totalEpargne3a = 240000,
  double? avoirLppTotal,
  double tauxConversion = 0.068,
  double rendementCaisse = 0.02,
}) {
  final accounts = List.generate(
    nombre3a,
    (i) => Compte3a(
      provider: 'Test Provider ${i + 1}',
      solde: nombre3a > 0 ? totalEpargne3a / nombre3a : 0,
      rendementEstime: 0.0, // Zero growth for predictable tests
    ),
  );

  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    etatCivil: etatCivil,
    salaireBrutMensuel: salaireBrutMensuel,
    prevoyance: PrevoyanceProfile(
      nombre3a: nombre3a,
      totalEpargne3a: totalEpargne3a,
      comptes3a: accounts,
      avoirLppTotal: avoirLppTotal,
      tauxConversion: tauxConversion,
      rendementCaisse: rendementCaisse,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65, 12, 31),
      label: 'Retraite a 65 ans',
    ),
  );
}
