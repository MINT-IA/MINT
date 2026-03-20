import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/withdrawal_sequencing_service.dart';

// ────────────────────────────────────────────────────────────
//  WITHDRAWAL SEQUENCING SERVICE TESTS — autoresearch-test-generation
// ────────────────────────────────────────────────────────────

void main() {
  CoachProfile makeProfile({
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 10000,
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    double epargne3a = 0,
    int nombre3a = 0,
    double avoirLpp = 0,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      etatCivil: etatCivil,
      prevoyance: PrevoyanceProfile(
        totalEpargne3a: epargne3a,
        nombre3a: nombre3a,
        avoirLppTotal: avoirLpp,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );
  }

  group('WithdrawalSequencingService.optimize', () {
    test('no capital → empty sequences', () {
      final profile = makeProfile();
      final result = WithdrawalSequencingService.optimize(profile: profile);

      expect(result.optimizedSequence, isEmpty);
      expect(result.naiveSequence, isEmpty);
      expect(result.totalTaxOptimized, equals(0));
      expect(result.totalTaxNaive, equals(0));
      expect(result.taxSavings, equals(0));
    });

    test('already retired → empty sequences', () {
      final profile = makeProfile(
        birthYear: 1956, // age ~70
        epargne3a: 100000,
      );
      final result = WithdrawalSequencingService.optimize(profile: profile);

      expect(result.optimizedSequence, isEmpty);
      expect(result.naiveSequence, isEmpty);
    });

    test('result always includes disclaimer', () {
      final profile = makeProfile(epargne3a: 50000, nombre3a: 2);
      final result = WithdrawalSequencingService.optimize(profile: profile);

      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('LSFin'));
      expect(result.disclaimer, contains('LIFD art. 38'));
    });

    test('result always includes legal sources', () {
      final profile = makeProfile(epargne3a: 50000, nombre3a: 2);
      final result = WithdrawalSequencingService.optimize(profile: profile);

      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
    });

    test('with 3a capital → generates withdrawal events', () {
      final profile = makeProfile(
        birthYear: 1977, // age ~49, retires at 65
        epargne3a: 100000,
        nombre3a: 3,
      );
      final result = WithdrawalSequencingService.optimize(profile: profile);

      // Should have some events (3 3a accounts to sequence)
      expect(result.optimizedSequence, isNotEmpty);
    });

    test('optimized tax ≤ naive tax (optimization works)', () {
      final profile = makeProfile(
        birthYear: 1977,
        epargne3a: 150000,
        nombre3a: 5,
        avoirLpp: 200000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        lppCapitalPct: 0.5,
      );

      // Optimized should be ≤ naive (or at worst equal)
      expect(result.totalTaxOptimized, lessThanOrEqualTo(result.totalTaxNaive));
      expect(result.taxSavings, greaterThanOrEqualTo(0));
    });

    test('tax savings percent is correctly computed', () {
      final profile = makeProfile(
        birthYear: 1977,
        epargne3a: 100000,
        nombre3a: 3,
        avoirLpp: 300000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        lppCapitalPct: 1.0,
      );

      if (result.totalTaxNaive > 0) {
        final expectedPercent =
            result.taxSavings / result.totalTaxNaive;
        expect(result.savingsPercent, closeTo(expectedPercent, 0.01));
      }
    });

    test('married couple gets tax discount', () {
      final profileSingle = makeProfile(
        epargne3a: 200000,
        nombre3a: 5,
        etatCivil: CoachCivilStatus.celibataire,
      );
      final profileMarried = makeProfile(
        epargne3a: 200000,
        nombre3a: 5,
        etatCivil: CoachCivilStatus.marie,
      );

      final resultSingle =
          WithdrawalSequencingService.optimize(profile: profileSingle);
      final resultMarried =
          WithdrawalSequencingService.optimize(profile: profileMarried);

      // Married should pay less tax on same capital
      if (resultSingle.totalTaxNaive > 0) {
        expect(resultMarried.totalTaxNaive,
            lessThanOrEqualTo(resultSingle.totalTaxNaive));
      }
    });

    test('withdrawal events have valid structure', () {
      final profile = makeProfile(
        birthYear: 1977,
        epargne3a: 100000,
        nombre3a: 3,
      );
      final result = WithdrawalSequencingService.optimize(profile: profile);

      for (final event in result.optimizedSequence) {
        expect(event.year, greaterThan(2024));
        expect(event.age, greaterThan(0));
        expect(event.source, isNotEmpty);
        expect(event.label, isNotEmpty);
        expect(event.amount, greaterThan(0));
        expect(event.tax, greaterThanOrEqualTo(0));
        expect(event.netAmount, equals(event.amount - event.tax));
        expect(event.effectiveRate, greaterThanOrEqualTo(0));
        expect(event.effectiveRate, lessThan(1.0));
      }
    });

    test('lppCapitalPct = 0 → no LPP in sequence', () {
      final profile = makeProfile(
        birthYear: 1977,
        avoirLpp: 500000,
      );
      final result = WithdrawalSequencingService.optimize(
        profile: profile,
        lppCapitalPct: 0.0,
      );

      // With 0% capital, LPP should not appear in withdrawal sequence
      final hasLpp = result.optimizedSequence
          .any((e) => e.source.contains('lpp'));
      expect(hasLpp, isFalse);
    });
  });
}
