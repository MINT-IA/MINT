import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Unit tests for CoachProfile model — Sprint C1 (MINT Coach)
///
/// Tests the extended financial profile model with couple support,
/// prevoyance, patrimoine, goals, and check-in history.
void main() {
  // ════════════════════════════════════════════════════════════
  //  DEMO PROFILE
  // ════════════════════════════════════════════════════════════

  group('CoachProfile - Demo profile (Julien+Lauren)', () {
    late CoachProfile demo;

    setUp(() {
      demo = CoachProfile.buildDemo();
    });

    test('demo profile has correct identity', () {
      expect(demo.firstName, 'Julien');
      expect(demo.birthYear, 1977);
      expect(demo.canton, 'VS');
      expect(demo.commune, 'Sion');
      expect(demo.etatCivil, CoachCivilStatus.marie);
    });

    test('demo profile age is calculated correctly', () {
      final expectedAge = DateTime.now().year - 1977;
      expect(demo.age, expectedAge);
    });

    test('demo profile anneesAvantRetraite is correct', () {
      // Demo profile has targetRetirementAge = 63
      final expectedYears = (63 - (DateTime.now().year - 1977)).clamp(0, 99);
      expect(demo.anneesAvantRetraite, expectedYears);
    });

    test('demo profile revenu brut annuel includes bonus', () {
      // 9080 * 13 = 118'040 + 7% bonus = 126'302.80
      final expected = 9080 * 13 * 1.07;
      expect(demo.revenuBrutAnnuel, closeTo(expected, 1));
    });

    test('demo profile has conjoint (Lauren)', () {
      expect(demo.conjoint, isNotNull);
      expect(demo.conjoint!.firstName, 'Lauren');
      expect(demo.conjoint!.birthYear, 1981);
      expect(demo.conjoint!.isFatcaResident, true);
      expect(demo.conjoint!.canContribute3a, false);
      expect(demo.conjoint!.nationality, 'US');
    });

    test('demo profile isCouple returns true', () {
      expect(demo.isCouple, true);
    });

    test('demo profile revenu brut annuel couple', () {
      // Julien: ~126'302 + Lauren: 5000*12 = 60'000
      expect(demo.revenuBrutAnnuelCouple, greaterThan(180000));
    });

    test('demo profile has 5 comptes 3a', () {
      expect(demo.prevoyance.nombre3a, 5);
      expect(demo.prevoyance.comptes3a.length, 5);
      expect(demo.prevoyance.totalEpargne3a, 35000);
    });

    test('demo profile LPP lacune is 300k', () {
      expect(demo.prevoyance.rachatMaximum, 300000);
      expect(demo.prevoyance.lacuneRachatRestante, 300000);
    });

    test('demo profile has 6 planned contributions', () {
      expect(demo.plannedContributions.length, 6);
    });

    test('demo profile total contributions mensuelles', () {
      // 604.83 + 604.83 + 1000 + 500 + 1000 + 500 = 4209.66
      expect(demo.totalContributionsMensuelles, closeTo(4209.66, 0.01));
    });

    test('demo profile 3a mensuel total', () {
      // 604.83 + 604.83 = 1209.66
      expect(demo.total3aMensuel, closeTo(1209.66, 0.01));
    });

    test('demo profile LPP buyback mensuel', () {
      // 1000 + 500 = 1500
      expect(demo.totalLppBuybackMensuel, 1500);
    });

    test('demo profile patrimoine', () {
      expect(demo.patrimoine.epargneLiquide, 15000);
      expect(demo.patrimoine.investissements, 100000);
      expect(demo.patrimoine.deviseInvestissements, InvestmentCurrency.usd);
    });

    test('demo profile has no debts', () {
      expect(demo.dettes.hasDette, false);
      expect(demo.dettes.totalDettes, 0);
    });

    test('demo profile goalA is retirement', () {
      expect(demo.goalA.type, GoalAType.retraite);
      // Demo profile has targetDate = DateTime(2040, 12, 31)
      expect(demo.goalA.targetDate.year, 2040);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CONJOINT PROFILE
  // ════════════════════════════════════════════════════════════

  group('ConjointProfile', () {
    test('revenuBrutAnnuel with 12 months no bonus', () {
      const conj = ConjointProfile(
        salaireBrutMensuel: 5000,
        nombreDeMois: 12,
      );
      expect(conj.revenuBrutAnnuel, 60000);
    });

    test('revenuBrutAnnuel with 13 months and bonus', () {
      const conj = ConjointProfile(
        salaireBrutMensuel: 5000,
        nombreDeMois: 13,
        bonusPourcentage: 10,
      );
      // 5000 * 13 = 65000 + 10% = 71500
      expect(conj.revenuBrutAnnuel, 71500);
    });

    test('revenuBrutAnnuel is 0 when no salary', () {
      const conj = ConjointProfile();
      expect(conj.revenuBrutAnnuel, 0);
    });

    test('FATCA resident canContribute3a defaults correctly', () {
      const fatca = ConjointProfile(isFatcaResident: true, canContribute3a: false);
      expect(fatca.canContribute3a, false);

      const noFatca = ConjointProfile();
      expect(noFatca.canContribute3a, true);
    });

    test('FATCA propagates canContribute3a to prevoyance via fromJson', () {
      final json = {
        'isFatcaResident': true,
        'prevoyance': {
          'avoirLppTotal': 80000,
          // canContribute3a intentionally NOT set (defaults true)
        },
      };
      final conj = ConjointProfile.fromJson(json);
      expect(conj.isFatcaResident, true);
      expect(conj.canContribute3a, false);
      expect(conj.prevoyance?.canContribute3a, false,
          reason: 'FATCA must propagate to prevoyance.canContribute3a');
    });

    test('FATCA propagates canContribute3a to prevoyance via copyWith', () {
      const conj = ConjointProfile(
        prevoyance: PrevoyanceProfile(avoirLppTotal: 50000),
      );
      // Before: not FATCA
      expect(conj.prevoyance?.canContribute3a, true);

      // After: set FATCA
      final fatca = conj.copyWith(isFatcaResident: true);
      expect(fatca.canContribute3a, false);
      expect(fatca.prevoyance?.canContribute3a, false,
          reason: 'copyWith(isFatcaResident: true) must cascade to prevoyance');
    });

    test('non-FATCA preserves canContribute3a true on prevoyance', () {
      final json = {
        'isFatcaResident': false,
        'prevoyance': {'avoirLppTotal': 80000},
      };
      final conj = ConjointProfile.fromJson(json);
      expect(conj.prevoyance?.canContribute3a, true);
    });

    test('FATCA invariant: explicit canContribute3a=true is overridden', () {
      // fromJson: even if payload says canContribute3a=true, FATCA wins
      final json = {
        'isFatcaResident': true,
        'canContribute3a': true, // explicit but invalid
        'prevoyance': {
          'avoirLppTotal': 80000,
          'canContribute3a': true, // explicit but invalid
        },
      };
      final conj = ConjointProfile.fromJson(json);
      expect(conj.canContribute3a, false,
          reason: 'FATCA must override explicit canContribute3a=true');
      expect(conj.prevoyance?.canContribute3a, false,
          reason: 'FATCA must override prevoyance canContribute3a=true');

      // copyWith: same invariant
      const base = ConjointProfile(
        isFatcaResident: true,
        canContribute3a: false,
      );
      final broken = base.copyWith(canContribute3a: true);
      expect(broken.canContribute3a, false,
          reason: 'copyWith cannot break FATCA invariant');
    });

    test('age and anneesAvantRetraite computed', () {
      final conj = ConjointProfile(birthYear: DateTime.now().year - 45);
      expect(conj.age, 45);
      expect(conj.anneesAvantRetraite, 20);
    });

    test('age is null when birthYear is null', () {
      const conj = ConjointProfile();
      expect(conj.age, isNull);
      expect(conj.anneesAvantRetraite, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PREVOYANCE PROFILE
  // ════════════════════════════════════════════════════════════

  group('PrevoyanceProfile', () {
    test('lacuneRachatRestante with no rachat done', () {
      const p = PrevoyanceProfile(rachatMaximum: 300000, rachatEffectue: 0);
      expect(p.lacuneRachatRestante, 300000);
    });

    test('lacuneRachatRestante with partial rachat', () {
      const p = PrevoyanceProfile(rachatMaximum: 300000, rachatEffectue: 50000);
      expect(p.lacuneRachatRestante, 250000);
    });

    test('lacuneRachatRestante clamps to 0', () {
      const p = PrevoyanceProfile(rachatMaximum: 100, rachatEffectue: 200);
      expect(p.lacuneRachatRestante, 0);
    });

    test('lacuneRachatRestante with nulls', () {
      const p = PrevoyanceProfile();
      expect(p.lacuneRachatRestante, 0);
    });

    test('default values', () {
      const p = PrevoyanceProfile();
      expect(p.tauxConversion, 0.068);
      expect(p.rendementCaisse, 0.02);
      expect(p.nombre3a, 0);
      expect(p.totalEpargne3a, 0);
      expect(p.canContribute3a, true);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PATRIMOINE, DETTES, DEPENSES
  // ════════════════════════════════════════════════════════════

  group('PatrimoineProfile', () {
    test('totalPatrimoine sums all assets', () {
      const p = PatrimoineProfile(
        epargneLiquide: 10000,
        investissements: 50000,
        immobilier: 200000,
      );
      expect(p.totalPatrimoine, 260000);
    });

    test('totalPatrimoine with nulls', () {
      const p = PatrimoineProfile(epargneLiquide: 5000);
      expect(p.totalPatrimoine, 5000);
    });
  });

  group('DetteProfile', () {
    test('totalDettes sums all debts', () {
      const d = DetteProfile(
        creditConsommation: 5000,
        leasing: 10000,
        hypotheque: 300000,
        autresDettes: 2000,
      );
      expect(d.totalDettes, 317000);
      expect(d.hasDette, true);
    });

    test('hasDette false when no debts', () {
      const d = DetteProfile();
      expect(d.hasDette, false);
      expect(d.totalDettes, 0);
    });
  });

  group('DepensesProfile', () {
    test('totalMensuel sums all expenses', () {
      const d = DepensesProfile(
        loyer: 1980,
        assuranceMaladie: 850,
        electricite: 80,
        transport: 400,
        telecom: 120,
      );
      expect(d.totalMensuel, 3430);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GOAL A / GOAL B
  // ════════════════════════════════════════════════════════════

  group('GoalA', () {
    test('moisRestants for future date', () {
      final goal = GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 10, 12, 31),
        label: 'Retraite',
      );
      expect(goal.moisRestants, greaterThan(100));
    });

    test('moisRestants for past date is 0', () {
      final goal = GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2020, 1, 1),
        label: 'Passe',
      );
      expect(goal.moisRestants, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MONTHLY CHECK-IN
  // ════════════════════════════════════════════════════════════

  group('MonthlyCheckIn', () {
    test('totalVersements sums all contributions', () {
      final ci = MonthlyCheckIn(
        month: DateTime(2026, 2, 1),
        versements: {
          '3a_julien': 604.83,
          '3a_lauren': 604.83,
          'lpp_buyback': 1000,
        },
        completedAt: DateTime.now(),
      );
      expect(ci.totalVersements, closeTo(2209.66, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERIALIZATION (JSON round-trip)
  // ════════════════════════════════════════════════════════════

  group('CoachProfile - JSON serialization', () {
    test('round-trip demo profile', () {
      final demo = CoachProfile.buildDemo();
      final json = demo.toJson();
      final restored = CoachProfile.fromJson(json);

      expect(restored.firstName, demo.firstName);
      expect(restored.birthYear, demo.birthYear);
      expect(restored.canton, demo.canton);
      expect(restored.etatCivil, demo.etatCivil);
      expect(restored.salaireBrutMensuel, demo.salaireBrutMensuel);
      expect(restored.nombreDeMois, demo.nombreDeMois);
      expect(restored.conjoint?.firstName, demo.conjoint?.firstName);
      expect(restored.conjoint?.isFatcaResident, demo.conjoint?.isFatcaResident);
      expect(restored.prevoyance.nombre3a, demo.prevoyance.nombre3a);
      expect(restored.prevoyance.totalEpargne3a, demo.prevoyance.totalEpargne3a);
      expect(restored.patrimoine.investissements, demo.patrimoine.investissements);
      expect(restored.goalA.type, demo.goalA.type);
      expect(restored.plannedContributions.length, demo.plannedContributions.length);
    });

    test('ConjointProfile JSON round-trip', () {
      const conj = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1981,
        salaireBrutMensuel: 5000,
        nationality: 'US',
        isFatcaResident: true,
        canContribute3a: false,
      );
      final json = conj.toJson();
      final restored = ConjointProfile.fromJson(json);
      expect(restored.firstName, 'Lauren');
      expect(restored.isFatcaResident, true);
      expect(restored.canContribute3a, false);
    });

    test('PrevoyanceProfile JSON round-trip', () {
      const p = PrevoyanceProfile(
        nomCaisse: 'CDE',
        avoirLppTotal: 300000,
        rachatMaximum: 300000,
        tauxConversion: 0.068,
        nombre3a: 5,
        totalEpargne3a: 35000,
        comptes3a: [
          Compte3a(provider: 'VIAC', solde: 10000),
          Compte3a(provider: 'Finpens', solde: 5000, rendementEstime: 0.05),
        ],
      );
      final json = p.toJson();
      final restored = PrevoyanceProfile.fromJson(json);
      expect(restored.nomCaisse, 'CDE');
      expect(restored.comptes3a.length, 2);
      expect(restored.comptes3a[1].rendementEstime, 0.05);
    });

    test('MonthlyCheckIn JSON round-trip', () {
      final ci = MonthlyCheckIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a': 604.83, 'lpp': 1000},
        depensesExceptionnelles: 500,
        note: 'Test',
        completedAt: DateTime(2026, 2, 15),
      );
      final json = ci.toJson();
      final restored = MonthlyCheckIn.fromJson(json);
      expect(restored.versements['3a'], 604.83);
      expect(restored.depensesExceptionnelles, 500);
      expect(restored.note, 'Test');
    });

    test('GoalA JSON round-trip', () {
      final goal = GoalA(
        type: GoalAType.achatImmo,
        targetDate: DateTime(2030, 6, 1),
        targetAmount: 800000,
        label: 'Achat maison Sion',
      );
      final json = goal.toJson();
      final restored = GoalA.fromJson(json);
      expect(restored.type, GoalAType.achatImmo);
      expect(restored.targetAmount, 800000);
      expect(restored.label, 'Achat maison Sion');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  STREAK CALCULATION
  // ════════════════════════════════════════════════════════════

  group('CoachProfile - Streak', () {
    test('no check-ins means streak 0', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      expect(profile.streak, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SINGLE PROFILE (no couple)
  // ════════════════════════════════════════════════════════════

  group('CoachProfile - Single', () {
    test('isCouple is false for celibataire', () {
      final profile = CoachProfile(
        birthYear: 1995,
        canton: 'ZH',
        salaireBrutMensuel: 7000,
        etatCivil: CoachCivilStatus.celibataire,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2060),
          label: 'Retraite',
        ),
      );
      expect(profile.isCouple, false);
      expect(profile.conjoint, isNull);
      expect(profile.revenuBrutAnnuelCouple, profile.revenuBrutAnnuel);
    });

    test('isCouple is true for concubinage', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 8000,
        etatCivil: CoachCivilStatus.concubinage,
        conjoint: const ConjointProfile(salaireBrutMensuel: 6000),
        goalA: GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime(2030),
          label: 'Achat',
        ),
      );
      expect(profile.isCouple, true);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('CoachProfile - Edge cases', () {
    test('resteAVivreMensuel can be negative', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'GE',
        salaireBrutMensuel: 4000,
        depenses: const DepensesProfile(
          loyer: 2500,
          assuranceMaladie: 600,
          transport: 500,
          electricite: 200,
        ),
        goalA: GoalA(
          type: GoalAType.debtFree,
          targetDate: DateTime(2028),
          label: 'Sortir des dettes',
        ),
      );
      // Net: 4000 * 0.87 = 3480. Expenses: 3800. Reste: -320
      expect(profile.resteAVivreMensuel, lessThan(0));
    });

    test('anneesAvantRetraite clamps to 0 for retirees', () {
      final profile = CoachProfile(
        birthYear: 1950,
        canton: 'TI',
        salaireBrutMensuel: 0,
        employmentStatus: 'retraite',
        goalA: GoalA(
          type: GoalAType.custom,
          targetDate: DateTime(2030),
          label: 'Succession',
        ),
      );
      expect(profile.anneesAvantRetraite, 0);
    });

    test('empty planned contributions', () {
      final profile = CoachProfile(
        birthYear: 2000,
        canton: 'ZH',
        salaireBrutMensuel: 5000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2065),
          label: 'Retraite',
        ),
      );
      expect(profile.totalContributionsMensuelles, 0);
      expect(profile.total3aMensuel, 0);
      expect(profile.totalLppBuybackMensuel, 0);
      expect(profile.totalEpargneLibreMensuel, 0);
    });
  });
}
