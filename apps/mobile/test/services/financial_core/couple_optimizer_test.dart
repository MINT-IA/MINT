import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/couple_optimizer.dart';

// ────────────────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────────────────

GoalA _retraiteGoal() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1), // ~65 ans
      label: 'Retraite',
    );

// ────────────────────────────────────────────────────────────
//  Golden couple: Julien + Lauren (from CLAUDE.md §8)
// ────────────────────────────────────────────────────────────

CoachProfile _julien() => CoachProfile(
      firstName: 'Julien',
      birthYear: 1977, // age 49 in 2026
      canton: 'VS',
      salaireBrutMensuel: 10184, // 122'207 / 12
      nombreDeMois: 12,
      etatCivil: CoachCivilStatus.marie,
      goalA: _retraiteGoal(),
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 70377,
        rachatMaximum: 539414,
        totalEpargne3a: 32000,
      ),
    );

ConjointProfile _lauren() => const ConjointProfile(
      firstName: 'Lauren',
      birthYear: 1982, // age 43 in 2026
      salaireBrutMensuel: 5583, // 67'000 / 12
      nombreDeMois: 12,
      nationality: 'US',
      isFatcaResident: true,
      canContribute3a: false,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: 19620,
        rachatMaximum: 52949,
        totalEpargne3a: 14000,
      ),
    );

ConjointProfile _nonFatcaConjoint() => const ConjointProfile(
      firstName: 'Marie',
      birthYear: 1985,
      salaireBrutMensuel: 4500,
      nombreDeMois: 12,
      nationality: 'CH',
      isFatcaResident: false,
      canContribute3a: true,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: 30000,
        rachatMaximum: 80000,
        totalEpargne3a: 10000,
      ),
    );

void main() {
  group('CoupleOptimizer.optimize', () {
    test('returns a result with all 4 analyses for complete couple', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      expect(result.hasResults, isTrue);
      expect(result.lppBuybackOrder, isNotNull);
      expect(result.pillar3aOrder, isNotNull);
      expect(result.avsCap, isNotNull);
      expect(result.marriagePenalty, isNotNull);
    });
  });

  group('LPP buyback order', () {
    test('Julien has higher income → Julien first', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      final lpp = result.lppBuybackOrder!;
      expect(lpp.winner, CoupleWinner.mainUser);
      expect(lpp.savingDelta, greaterThan(0));
    });

    test('tradeOff mentions 3 year lock-in', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      expect(result.lppBuybackOrder!.tradeOff, contains('3 ans'));
    });

    test('equal income → noPreference', () {
      final user = CoachProfile(
        birthYear: 1986,
        canton: 'VD',
        goalA: _retraiteGoal(),
        salaireBrutMensuel: 5000,
        prevoyance: const PrevoyanceProfile(rachatMaximum: 50000),
      );
      const conj = ConjointProfile(
        birthYear: 1984,
        salaireBrutMensuel: 5000,
        prevoyance: PrevoyanceProfile(rachatMaximum: 50000),
      );
      final result = CoupleOptimizer.optimize(mainUser: user, conjoint: conj);
      expect(result.lppBuybackOrder!.winner, CoupleWinner.noPreference);
    });

    test('no rachat possible → null result', () {
      final user = CoachProfile(
        birthYear: 1986,
        canton: 'VD',
        goalA: _retraiteGoal(),
        salaireBrutMensuel: 5000,
        prevoyance: const PrevoyanceProfile(rachatMaximum: 0),
      );
      const conj = ConjointProfile(
        birthYear: 1984,
        salaireBrutMensuel: 5000,
        prevoyance: PrevoyanceProfile(rachatMaximum: 0),
      );
      final result = CoupleOptimizer.optimize(mainUser: user, conjoint: conj);
      expect(result.lppBuybackOrder, isNull);
    });
  });

  group('3a contribution order', () {
    test('Lauren FATCA → 3a optimal = Julien only', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      final p3a = result.pillar3aOrder!;
      expect(p3a.winner, CoupleWinner.mainUser);
      expect(p3a.reason, contains('FATCA'));
    });

    test('non-FATCA conjoint with lower income → mainUser first', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _nonFatcaConjoint(),
      );
      final p3a = result.pillar3aOrder!;
      expect(p3a.winner, CoupleWinner.mainUser);
      expect(p3a.savingDelta, greaterThan(0));
    });

    test('tradeOff mentions ceiling', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _nonFatcaConjoint(),
      );
      expect(result.pillar3aOrder!.tradeOff, contains('7'));
    });
  });

  group('AVS couple cap (LAVS art. 35)', () {
    test('married couple with high income → cap applied', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      final avs = result.avsCap!;
      expect(avs.capApplied, isTrue);
      expect(avs.monthlyReduction, greaterThan(0));
      // 3780 cap × 13/12 (13ème rente) = ~4095
      expect(avs.totalAfterCap, lessThanOrEqualTo(4100));
    });

    test('concubin couple → no cap applied', () {
      final user = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        goalA: _retraiteGoal(),
        salaireBrutMensuel: 10184,
        etatCivil: CoachCivilStatus.concubinage,
      );
      final result = CoupleOptimizer.optimize(
        mainUser: user,
        conjoint: _lauren(),
      );
      final avs = result.avsCap!;
      expect(avs.capApplied, isFalse);
    });

    test('low income couple → no cap even if married', () {
      final user = CoachProfile(
        birthYear: 1986,
        canton: 'VD',
        goalA: _retraiteGoal(),
        salaireBrutMensuel: 2000,
        etatCivil: CoachCivilStatus.marie,
      );
      const conj = ConjointProfile(
        birthYear: 1985,
        salaireBrutMensuel: 2000,
      );
      final result = CoupleOptimizer.optimize(mainUser: user, conjoint: conj);
      final avs = result.avsCap!;
      expect(avs.capApplied, isFalse);
    });

    test('conjoint without age → null result', () {
      const conj = ConjointProfile(salaireBrutMensuel: 5000);
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: conj,
      );
      expect(result.avsCap, isNull);
    });
  });

  group('Marriage penalty', () {
    test('VS couple with disparate income → result computed', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      final mp = result.marriagePenalty!;
      expect(mp.annualDelta, isNot(0));
      expect(mp.tradeOff, contains('canton'));
    });

    test('conjoint without income → null result', () {
      const conj = ConjointProfile(birthYear: 1985, salaireBrutMensuel: 0);
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: conj,
      );
      expect(result.marriagePenalty, isNull);
    });

    test('tradeOff mentions penalty or bonus', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      final mp = result.marriagePenalty!;
      if (mp.hasPenalty) {
        expect(mp.tradeOff, contains('surcharge'));
      } else {
        expect(mp.tradeOff, contains('avantage'));
      }
    });
  });

  group('Edge cases & compliance', () {
    test('all analyses return tradeOff (LSFin compliance)', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      if (result.lppBuybackOrder != null) {
        expect(result.lppBuybackOrder!.tradeOff, isNotEmpty);
      }
      if (result.pillar3aOrder != null) {
        expect(result.pillar3aOrder!.tradeOff, isNotEmpty);
      }
      if (result.marriagePenalty != null) {
        expect(result.marriagePenalty!.tradeOff, isNotEmpty);
      }
    });

    test('savingDelta is always non-negative', () {
      final result = CoupleOptimizer.optimize(
        mainUser: _julien(),
        conjoint: _lauren(),
      );
      if (result.lppBuybackOrder != null) {
        expect(result.lppBuybackOrder!.savingDelta, greaterThanOrEqualTo(0));
      }
      if (result.pillar3aOrder != null) {
        expect(result.pillar3aOrder!.savingDelta, greaterThanOrEqualTo(0));
      }
    });
  });
}
