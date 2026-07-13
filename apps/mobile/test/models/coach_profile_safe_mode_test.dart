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
    double? selfEmployedNetIncome,
    double epargneLiquide = 20000,
    double totalMensuelDepenses = 3000,
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    Map<String, ProfileDataSource> dataSources = const {},
    Map<String, DateTime> dataTimestamps = const {},
    Set<String> userProvidedFields = const {'monthlyExpenses'},
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      nombreDeMois: nombreDeMois,
      employmentStatus: employmentStatus,
      selfEmployedNetIncome: selfEmployedNetIncome,
      depenses: DepensesProfile(
        loyer: totalMensuelDepenses,
        assuranceMaladie: 0,
      ),
      prevoyance: prevoyance,
      patrimoine: PatrimoineProfile(epargneLiquide: epargneLiquide),
      dettes: DetteProfile(
        creditConsommation: creditConsommation,
        leasing: leasing,
        autresDettes: autresDettes,
        mensualiteCreditConso: mensualiteCreditConso,
        mensualiteLeasing: mensualiteLeasing,
        mensualiteHypotheque: mensualiteHypotheque,
      ),
      dataSources: dataSources,
      dataTimestamps: dataTimestamps,
      userProvidedFields: userProvidedFields,
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

    test('conso mensualite / net <= 0.33 → false (B alone)', () {
      // Salary 6000, net ≈ 5426/month. Conso monthly = 800 → ratio ≈ 0.15
      final p = makeProfile(
        salaire: 6000,
        mensualiteCreditConso: 800,
        epargneLiquide: 30000,
        totalMensuelDepenses: 3000,
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

    test('independent income also feeds liquidity SafeMode', () {
      final p = makeProfile(
        salaire: 0,
        employmentStatus: 'independant',
        selfEmployedNetIncome: 144000,
        epargneLiquide: 5000,
        totalMensuelDepenses: 3000,
      );
      expect(p.isInDebtCrisis, isTrue);
    });
  });

  group('Retiree AVS official-pension boundary', () {
    CoachProfile retiree({
      double? avs,
      bool certificateTagged = false,
      double epargneLiquide = 30000,
      Set<String> userProvidedFields = const {'monthlyExpenses'},
    }) {
      const fieldPath = AvsOfficialPensionEvidence.selfFieldPath;
      return makeProfile(
        salaire: 0,
        employmentStatus: 'retraite',
        mensualiteCreditConso: 2000,
        epargneLiquide: epargneLiquide,
        totalMensuelDepenses: 3000,
        prevoyance: PrevoyanceProfile(
          renteAVSEstimeeMensuelle: avs,
          projectedRenteLpp: 36000,
        ),
        dataSources: certificateTagged
            ? const {fieldPath: ProfileDataSource.certificate}
            : const {},
        dataTimestamps: certificateTagged
            ? {fieldPath: DateTime.utc(2026, 7, 13)}
            : const {},
        userProvidedFields: userProvidedFields,
      );
    }

    test('missing AVS does not treat LPP alone as complete retiree income', () {
      expect(retiree().isInDebtCrisis, isFalse);
    });

    test('legacy non-null AVS does not unlock retiree income ratio', () {
      expect(retiree(avs: 2300).isInDebtCrisis, isFalse);
    });

    test('certificate tag plus timestamp still does not unlock income ratio',
        () {
      expect(
        retiree(avs: 2300, certificateTagged: true).isInDebtCrisis,
        isFalse,
      );
    });

    test('explicit expenses still allow liquidity Signal C', () {
      expect(retiree(epargneLiquide: 1000).isInDebtCrisis, isTrue);
    });

    test('display-only retiree expenses cannot trigger liquidity Signal C', () {
      expect(
        retiree(
          epargneLiquide: 0,
          userProvidedFields: const {},
        ).isInDebtCrisis,
        isFalse,
      );
    });

    test('inline user-input expense provenance allows retiree Signal C', () {
      expect(
        makeProfile(
          salaire: 0,
          employmentStatus: 'retraite',
          epargneLiquide: 1000,
          totalMensuelDepenses: 3000,
          dataSources: const {
            'depenses.loyer': ProfileDataSource.userInput,
          },
          userProvidedFields: const {},
        ).isInDebtCrisis,
        isTrue,
      );
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
