/// Tests for CoachProfile.isInDebtCrisis — SafeMode signals A, B, C.
///
/// Signal A: consumer debt present (creditConsommation | leasing | autresDettes > 0)
/// Signal B: (conso monthly + mortgage excess) / net monthly > 0.33
/// Signal C: emergency fund < 3 months of expenses
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  // ── Helper ──────────────────────────────────────────────────────────────────
  CoachProfile makeProfile({
    String employmentStatus = 'salarie',
    double salaire = 6000, // monthly gross
    double nombreDeMois = 12.0,
    String canton = 'ZH',
    int birthYear = 1985,
    double? creditConsommation,
    double? leasing,
    double? autresDettes,
    double? mensualiteCreditConso,
    double? mensualiteLeasing,
    double? mensualiteHypotheque,
    double epargneLiquide = 20000,
    double totalMensuelDepenses = 3000,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      nombreDeMois: nombreDeMois,
      employmentStatus: employmentStatus,
      depenses: DepensesProfile(
        loyer: totalMensuelDepenses,
        assuranceMaladie: 0,
      ),
      prevoyance: const PrevoyanceProfile(),
      patrimoine: PatrimoineProfile(epargneLiquide: epargneLiquide),
      dettes: DetteProfile(
        creditConsommation: creditConsommation,
        leasing: leasing,
        autresDettes: autresDettes,
        mensualiteCreditConso: mensualiteCreditConso,
        mensualiteLeasing: mensualiteLeasing,
        mensualiteHypotheque: mensualiteHypotheque,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050, 12, 31),
        label: 'Retraite',
      ),
    );
  }

  // ── Signal A ─────────────────────────────────────────────────────────────────
  group('Signal A — consumer debt present', () {
    test('creditConsommation > 0 → true', () {
      final p = makeProfile(creditConsommation: 5000);
      expect(p.isInDebtCrisis, isTrue);
    });

    test('leasing > 0 → true', () {
      final p = makeProfile(leasing: 800);
      expect(p.isInDebtCrisis, isTrue);
    });

    test('autresDettes > 0 → true', () {
      final p = makeProfile(autresDettes: 1200);
      expect(p.isInDebtCrisis, isTrue);
    });

    test('no consumer debt, no other signal → false', () {
      final p = makeProfile(epargneLiquide: 30000, totalMensuelDepenses: 3000);
      expect(p.isInDebtCrisis, isFalse);
    });

    test('wizard monthly consumer debt without known capital → true', () {
      final p = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_gross_income_monthly': 6000,
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': 900,
        'q_housing_cost_period_chf': 1800,
        'q_lamal_premium_monthly_chf': 420,
        'q_cash_total': 30000,
      });

      expect(p.dettes.creditConsommation, isNull);
      expect(p.dettes.mensualiteCreditConso, 900);
      expect(p.isInDebtCrisis, isTrue);
    });

    test('wizard monthly consumer debt survives inline mortgage capital', () {
      final p = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_gross_income_monthly': 6000,
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': 900,
        '_coach_dettes_hypotheque': 600000,
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
        'q_cash_total': 30000,
      });

      expect(p.dettes.hypotheque, 600000);
      expect(p.dettes.mensualiteCreditConso, 900);
      expect(p.dettes.creditConsommation, isNull);
      expect(p.isInDebtCrisis, isTrue);
    });
  });

  // ── Signal B ─────────────────────────────────────────────────────────────────
  group('Signal B — ratio > 0.33', () {
    test('conso mensualite / net > 0.33 → true', () {
      // Salary 6000 CHF/month gross = 72000/year, ZH, age 39.
      // Net payslip ≈ 65115/year = 5426/month (after social + LPP).
      // mensualiteCreditConso = 2000 → ratio ≈ 0.369 > 0.33 → true.
      final p = makeProfile(
        salaire: 6000,
        mensualiteCreditConso: 2000,
        epargneLiquide: 30000, // Signal C OK: 30000/3000 = 10 months
      );
      expect(p.isInDebtCrisis, isTrue);
    });

    test('material conso mensualite / net <= 0.33 → true (Signal A)', () {
      // Salary 6000, net ≈ 5426/month. Conso monthly = 800 → material
      // consumer debt exists, even though Signal B ratio remains below 0.33.
      final p = makeProfile(
        salaire: 6000,
        mensualiteCreditConso: 800,
        epargneLiquide: 30000,
        totalMensuelDepenses: 3000,
      );
      expect(p.isInDebtCrisis, isTrue);
    });

    test('small leasing payment for high income is not debt crisis', () {
      final p = makeProfile(
        salaire: 12000,
        mensualiteLeasing: 350,
        epargneLiquide: 50000,
        totalMensuelDepenses: 4000,
      );
      expect(p.isInDebtCrisis, isFalse);
    });
  });

  // ── Signal C ─────────────────────────────────────────────────────────────────
  group('Signal C — emergency fund < 3 months', () {
    test('liquid < 3 × monthly expenses → true', () {
      // Expenses 3000/month, liquid 5000 → 1.67 months
      final p = makeProfile(epargneLiquide: 5000, totalMensuelDepenses: 3000);
      expect(p.isInDebtCrisis, isTrue);
    });

    test('liquid >= 3 × monthly expenses → false (C alone)', () {
      // Expenses 3000/month, liquid 15000 → 5 months
      final p = makeProfile(epargneLiquide: 15000, totalMensuelDepenses: 3000);
      expect(p.isInDebtCrisis, isFalse);
    });

    test('implausible monthly expense capture does not trigger crisis', () {
      final p = makeProfile(
        epargneLiquide: 30000,
        totalMensuelDepenses: 19272200,
      );
      expect(p.isInDebtCrisis, isFalse);
    });
  });

  // ── P0 2026-08-03 — partial-data false positive ───────────────────────────────
  group('P0 — salary-only partial profile is NOT in debt crisis', () {
    test('salary known, no debt, no savings entered, no expenses → false', () {
      // Mirrors the julien_swiss seed / Julien's real device profile: a payslip
      // import gives a gross salary, but savings (epargneLiquide) and expenses
      // are not yet entered → both default to 0. This must NOT be read as a
      // zero cushion / debt crisis. Previously Signal C fabricated an expense
      // base (net × 0.6) and divided the 0 savings default → false "crisis".
      final p = makeProfile(
        salaire: 9500,
        epargneLiquide: 0,
        totalMensuelDepenses: 0,
      );
      expect(p.dettes.totalDettes, 0);
      expect(p.isInDebtCrisis, isFalse);
      expect(p.safeModeSignals, isEmpty);
    });

    test('expenses declared but savings unknown (0) → false (no fabrication)',
        () {
      // Expenses entered from a budget, but the liquid-savings field left blank
      // (0). Unknown savings must not be read as a zero cushion.
      final p = makeProfile(
        salaire: 9500,
        epargneLiquide: 0,
        totalMensuelDepenses: 3000,
      );
      expect(p.isInDebtCrisis, isFalse);
    });

    test('savings declared but expenses unknown (0) → false (no fabrication)',
        () {
      final p = makeProfile(
        salaire: 9500,
        epargneLiquide: 2000,
        totalMensuelDepenses: 0,
      );
      expect(p.isInDebtCrisis, isFalse);
    });

    test('real thin cushion (both known) still fires Signal C', () {
      // Regression guard: the fix must not suppress a genuine shortfall when
      // BOTH cushion and burn rate are actually declared.
      final p = makeProfile(
        salaire: 9500,
        epargneLiquide: 4000,
        totalMensuelDepenses: 3000, // 1.33 months < 3 → fires
      );
      expect(p.isInDebtCrisis, isTrue);
      expect(p.safeModeSignals, contains(SafeModeSignal.thinEmergencyFund));
    });

    test('real consumer debt still fires (provenance = consumerDebt)', () {
      final p = makeProfile(
        salaire: 9500,
        creditConsommation: 8000,
        epargneLiquide: 0,
        totalMensuelDepenses: 0,
      );
      expect(p.isInDebtCrisis, isTrue);
      expect(p.safeModeSignals, contains(SafeModeSignal.consumerDebt));
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────────────────
  group('Edge cases', () {
    test('E4 student — zero salary, no debt → false', () {
      final p = makeProfile(
        salaire: 0,
        employmentStatus: 'etudiant',
        epargneLiquide: 5000, // would fail C if income existed
        totalMensuelDepenses: 3000,
      );
      expect(p.isInDebtCrisis, isFalse);
    });

    test('all fields zero → false', () {
      final p = makeProfile();
      // Default: no debt, 20k liquid, 3000 expenses → 6.67 months OK
      expect(p.isInDebtCrisis, isFalse);
    });
  });
}
