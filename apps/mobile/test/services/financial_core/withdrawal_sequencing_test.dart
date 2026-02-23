import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/withdrawal_sequencing_service.dart';

/// Builds a minimal CoachProfile for testing.
///
/// Allows overriding key fields relevant to withdrawal sequencing.
CoachProfile _buildProfile({
  int birthYear = 1990,
  String canton = 'ZH',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  double salaireBrutMensuel = 8000,
  int nombre3a = 3,
  double totalEpargne3a = 240000,
  List<Compte3a>? comptes3a,
  double? avoirLppTotal,
  double tauxConversion = 0.068,
  double rendementCaisse = 0.02,
}) {
  final accounts = comptes3a ??
      List.generate(
        nombre3a,
        (i) => Compte3a(
          provider: 'Test Provider ${i + 1}',
          solde: nombre3a > 0 ? totalEpargne3a / nombre3a : 0,
          rendementEstime: 0.0, // No growth to keep tests predictable
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

void main() {
  group('WithdrawalSequencingService.optimize', () {
    // ──────────────────────────────────────────────────────────
    //  1. Optimized tax <= naive tax (core invariant)
    // ──────────────────────────────────────────────────────────
    test('optimized tax is less than or equal to naive tax', () {
      final profile = _buildProfile(
        birthYear: 1970, // age ~56
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      expect(result.totalTaxOptimized,
          lessThanOrEqualTo(result.totalTaxNaive));
      expect(result.taxSavings, greaterThanOrEqualTo(0));
    });

    // ──────────────────────────────────────────────────────────
    //  2. Staggered 3a produces strictly lower tax
    // ──────────────────────────────────────────────────────────
    test('staggered 3a accounts produce lower tax than all-at-once', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      // With 3 accounts of 80k each, staggering should produce savings
      // because 80k stays in the lowest bracket (0-100k at 1.0x)
      // while 240k all-at-once crosses into the 1.15x bracket.
      expect(result.taxSavings, greaterThan(0));
      expect(result.savingsPercent, greaterThan(0));
    });

    // ──────────────────────────────────────────────────────────
    //  3. Single 3a account → no staggering benefit
    // ──────────────────────────────────────────────────────────
    test('single 3a account has no staggering benefit', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 1,
        totalEpargne3a: 80000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      // Single account: optimized and naive should produce the same tax
      // (both withdraw 80k in a single year).
      expect(result.optimizedSequence.length, equals(1));
      expect(result.naiveSequence.length, equals(1));
      expect(result.totalTaxOptimized, closeTo(result.totalTaxNaive, 1));
    });

    // ──────────────────────────────────────────────────────────
    //  4. Married couples get lower tax
    // ──────────────────────────────────────────────────────────
    test('married couples get lower tax than singles', () {
      final single = _buildProfile(
        birthYear: 1970,
        etatCivil: CoachCivilStatus.celibataire,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final married = _buildProfile(
        birthYear: 1970,
        etatCivil: CoachCivilStatus.marie,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );

      final singleResult = WithdrawalSequencingService.optimize(
        profile: single,
        retirementAge: 65,
      );
      final marriedResult = WithdrawalSequencingService.optimize(
        profile: married,
        retirementAge: 65,
      );

      expect(marriedResult.totalTaxOptimized,
          lessThan(singleResult.totalTaxOptimized));
      expect(marriedResult.totalTaxNaive,
          lessThan(singleResult.totalTaxNaive));
    });

    // ──────────────────────────────────────────────────────────
    //  5. LPP 100% rente → no capital withdrawal events for LPP
    // ──────────────────────────────────────────────────────────
    test('LPP 100% rente produces no LPP capital events', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 2,
        totalEpargne3a: 100000,
        avoirLppTotal: 300000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.0, // 100% rente
      );

      // No LPP capital event
      final lppEvents = result.optimizedSequence
          .where((e) => e.source == 'lpp_capital')
          .toList();
      expect(lppEvents, isEmpty);

      // But 3a events should exist
      final events3a = result.optimizedSequence
          .where((e) => e.source.startsWith('3a_'))
          .toList();
      expect(events3a.length, equals(2));
    });

    // ──────────────────────────────────────────────────────────
    //  6. Total amounts match (no money lost)
    // ──────────────────────────────────────────────────────────
    test('total gross amounts match between optimized and naive', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
        avoirLppTotal: 200000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.5,
      );

      final totalOptimized = result.optimizedSequence
          .fold(0.0, (sum, e) => sum + e.amount);
      final totalNaive = result.naiveSequence
          .fold(0.0, (sum, e) => sum + e.amount);

      // Both scenarios should handle the same total capital.
      // NOTE: With 3a growth (returns > 0) projected to different years,
      // optimized amounts may differ slightly. With 0% return they match.
      expect(totalOptimized, closeTo(totalNaive, 1));
    });

    // ──────────────────────────────────────────────────────────
    //  7. Each event has valid year/age
    // ──────────────────────────────────────────────────────────
    test('each event has valid year and age', () {
      final currentYear = DateTime.now().year;
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      for (final event in result.optimizedSequence) {
        expect(event.year, greaterThanOrEqualTo(currentYear));
        expect(event.age, greaterThanOrEqualTo(55));
        expect(event.age, lessThanOrEqualTo(70));
        expect(event.amount, greaterThan(0));
        expect(event.tax, greaterThanOrEqualTo(0));
        expect(event.netAmount, lessThanOrEqualTo(event.amount));
        expect(event.effectiveRate, greaterThanOrEqualTo(0));
        expect(event.effectiveRate, lessThanOrEqualTo(1));
      }
    });

    // ──────────────────────────────────────────────────────────
    //  8. Canton affects total tax
    // ──────────────────────────────────────────────────────────
    test('canton affects total tax (VD > ZG)', () {
      final profileVD = _buildProfile(
        birthYear: 1970,
        canton: 'VD', // 8.0%
        nombre3a: 2,
        totalEpargne3a: 200000,
      );
      final profileZG = _buildProfile(
        birthYear: 1970,
        canton: 'ZG', // 3.5%
        nombre3a: 2,
        totalEpargne3a: 200000,
      );

      final resultVD = WithdrawalSequencingService.optimize(
        profile: profileVD,
        retirementAge: 65,
      );
      final resultZG = WithdrawalSequencingService.optimize(
        profile: profileZG,
        retirementAge: 65,
      );

      expect(resultVD.totalTaxOptimized,
          greaterThan(resultZG.totalTaxOptimized));
      expect(resultVD.totalTaxNaive,
          greaterThan(resultZG.totalTaxNaive));
    });

    // ──────────────────────────────────────────────────────────
    //  9. Zero capital → empty sequences
    // ──────────────────────────────────────────────────────────
    test('zero capital produces empty sequences', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 0,
        totalEpargne3a: 0,
        avoirLppTotal: 0,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      expect(result.optimizedSequence, isEmpty);
      expect(result.naiveSequence, isEmpty);
      expect(result.totalTaxOptimized, equals(0));
      expect(result.totalTaxNaive, equals(0));
      expect(result.taxSavings, equals(0));
    });

    // ──────────────────────────────────────────────────────────
    //  10. Disclaimer mentions LIFD art. 38 and LSFin-related text
    // ──────────────────────────────────────────────────────────
    test('disclaimer mentions LIFD art. 38 and compliance text', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 1,
        totalEpargne3a: 50000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      expect(result.disclaimer, contains('LIFD art. 38'));
      expect(result.disclaimer, contains('OPP3 art. 3'));
      expect(result.disclaimer, contains('specialiste'));
      expect(result.disclaimer, contains('Simulation pedagogique'));

      // Sources check
      expect(result.sources,
          contains('LIFD art. 38 (imposition separee capital prevoyance)'));
      expect(result.sources,
          contains('OPP3 art. 3 (retrait anticipe 3a)'));
      expect(result.sources,
          contains('LPP art. 37 (prestations en capital)'));
    });

    // ──────────────────────────────────────────────────────────
    //  11. Tax savings increase with more 3a accounts
    // ──────────────────────────────────────────────────────────
    test('tax savings increase with more 3a accounts (same total)', () {
      // Same total (240k) split into 2 vs 4 accounts.
      final profile2 = _buildProfile(
        birthYear: 1970,
        nombre3a: 2,
        totalEpargne3a: 240000,
      );
      final profile4 = _buildProfile(
        birthYear: 1970,
        nombre3a: 4,
        totalEpargne3a: 240000,
      );

      final result2 = WithdrawalSequencingService.optimize(
        profile: profile2,
        retirementAge: 65,
      );
      final result4 = WithdrawalSequencingService.optimize(
        profile: profile4,
        retirementAge: 65,
      );

      // More accounts = more staggering = more savings.
      expect(result4.taxSavings,
          greaterThanOrEqualTo(result2.taxSavings));
    });

    // ──────────────────────────────────────────────────────────
    //  12. LPP capital withdrawal is included when lppCapitalPct > 0
    // ──────────────────────────────────────────────────────────
    test('LPP capital included when lppCapitalPct > 0', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 1,
        totalEpargne3a: 50000,
        avoirLppTotal: 300000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 0.5,
      );

      final lppEvents = result.optimizedSequence
          .where((e) => e.source == 'lpp_capital')
          .toList();
      expect(lppEvents.length, equals(1));
      expect(lppEvents.first.amount, greaterThan(0));
      expect(lppEvents.first.label, equals('LPP capital'));
    });

    // ──────────────────────────────────────────────────────────
    //  13. Naive: all events at retirement year
    // ──────────────────────────────────────────────────────────
    test('naive sequence has all events at retirement age', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 150000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      for (final event in result.naiveSequence) {
        expect(event.age, equals(65));
      }
    });

    // ──────────────────────────────────────────────────────────
    //  14. Optimized: 3a events span multiple years
    // ──────────────────────────────────────────────────────────
    test('optimized 3a events span multiple years', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
      );

      final years = result.optimizedSequence
          .where((e) => e.source.startsWith('3a_'))
          .map((e) => e.year)
          .toSet();

      // 3 accounts should be spread across at least 2 different years.
      expect(years.length, greaterThanOrEqualTo(2));
    });

    // ──────────────────────────────────────────────────────────
    //  15. Net amount = gross amount - tax for every event
    // ──────────────────────────────────────────────────────────
    test('net amount equals gross minus tax for all events', () {
      final profile = _buildProfile(
        birthYear: 1970,
        nombre3a: 3,
        totalEpargne3a: 240000,
        avoirLppTotal: 200000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        retirementAge: 65,
        lppCapitalPct: 1.0,
      );

      for (final event in result.optimizedSequence) {
        expect(event.netAmount, closeTo(event.amount - event.tax, 0.01));
      }
      for (final event in result.naiveSequence) {
        expect(event.netAmount, closeTo(event.amount - event.tax, 0.01));
      }
    });
  });
}
