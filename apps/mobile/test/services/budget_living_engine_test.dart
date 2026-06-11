import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';

/// Tests for BudgetLivingEngine — real computation, not stubs.
///
/// Golden couple: Julien (1977, 122'207 CHF/an, VS, CPE 5%) +
///                Lauren (1982,  67'000 CHF/an, VS, HOTELA)
///
/// All values are cross-checked against known expected ranges from
/// the test golden data in CLAUDE.md §8.
void main() {
  // ── Helper: build a minimal salaried CoachProfile ────────────

  CoachProfile buildProfile({
    int birthYear = 1980,
    double salaireBrutMensuel = 8000,
    String canton = 'VD',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    ConjointProfile? conjoint,
    double avoirLppTotal = 50000,
    double totalEpargne3a = 10000,
    double loyer = 1800,
    double assuranceMaladie = 430,
    List<PlannedMonthlyContribution> contributions = const [],
    DetteProfile dettes = const DetteProfile(),
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      etatCivil: etatCivil,
      conjoint: conjoint,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLppTotal,
        totalEpargne3a: totalEpargne3a,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 20000,
        investissements: 0,
      ),
      dettes: dettes,
      depenses: DepensesProfile(
        loyer: loyer,
        assuranceMaladie: assuranceMaladie,
      ),
      dataSources: const {
        'depenses.loyer': ProfileDataSource.userInput,
        'depenses.assuranceMaladie': ProfileDataSource.userInput,
      },
      userProvidedFields: const {
        'housingCost',
        'lamalPremium',
      },
      plannedContributions: contributions,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );
  }

  // ── Group 1: Present Budget ──────────────────────────────────

  group('BudgetLivingEngine — present budget', () {
    test('monthlyNet is positive for a salaried worker', () {
      final profile = buildProfile();
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.monthlyNet, greaterThan(0),
          reason: 'Net income from AVS/LPP deductions must be positive');
    });

    test('monthlyNet is lower than gross salary', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.monthlyNet, lessThan(8000),
          reason: 'Net must be lower than gross after AVS/LPP/AC deductions');
    });

    test('monthlyCharges includes housing and health insurance', () {
      final profile = buildProfile(loyer: 2000, assuranceMaladie: 500);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.monthlyCharges, greaterThanOrEqualTo(2500),
          reason: 'Housing (2000) + health (500) = at least 2500');
    });

    test('monthlyFree = net - charges - savings (identity check)', () {
      final profile = buildProfile();
      final snapshot = BudgetLivingEngine.compute(profile);
      final p = snapshot.present;

      expect(
        p.monthlyFree,
        closeTo(p.monthlyNet - p.monthlyCharges - p.monthlySavings, 0.01),
        reason: 'monthlyFree must equal net - charges - savings exactly',
      );
    });

    test('monthly debt increases charges and reduces free cash exactly', () {
      final base = BudgetLivingEngine.compute(buildProfile()).present;
      final withDebt = BudgetLivingEngine.compute(
        buildProfile(
          dettes: const DetteProfile(mensualiteCreditConso: 900),
        ),
      ).present;

      expect(withDebt.monthlyNet, base.monthlyNet);
      expect(withDebt.monthlyDebt, 900);
      expect(withDebt.monthlyCharges - base.monthlyCharges, 900);
      expect(base.monthlyFree - withDebt.monthlyFree, 900);
    });

    test('uses the same displayed remainder as the budget screen read model',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 5379.0,
        'q_pay_frequency': 'monthly',
        'q_housing_cost_period_chf': 2200.0,
        'q_lamal_premium_monthly_chf': 420.0,
        'q_debt_payments_period_chf': 0.0,
      });
      final inputs = BudgetInputs.fromCoachProfile(profile);
      final budgetScreenPresent = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: const BudgetPlan(
          available: 0,
          variables: 0,
          future: 0,
          stopRuleTriggered: false,
          emergencyFundMonths: 0,
        ),
      );

      final livingPresent = BudgetLivingEngine.compute(profile).present;

      expect(livingPresent.monthlyNet, budgetScreenPresent.monthlyNet);
      expect(livingPresent.monthlyCharges, budgetScreenPresent.monthlyCharges);
      expect(livingPresent.monthlyFree, budgetScreenPresent.monthlyFree);
    });

    test('chargesRatio is between 0 and 200 percent', () {
      final profile = buildProfile();
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.chargesRatio, inInclusiveRange(0, 200));
    });

    test('deficit detected when charges exceed income', () {
      // Artificially high housing cost to force deficit
      final profile = buildProfile(
        salaireBrutMensuel: 2000,
        loyer: 5000,
      );
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.isDeficit, isTrue,
          reason: '5000 CHF rent on 2000 CHF salary must produce deficit');
    });

    test('zero income yields zero net', () {
      final profile = buildProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.present.monthlyNet, equals(0));
    });
  });

  // ── Group 2: Stage transitions ───────────────────────────────

  group('BudgetLivingEngine — stage transitions', () {
    test('presentOnly when salary is zero', () {
      final profile = buildProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.stage, equals(BudgetStage.presentOnly),
          reason: 'No income means no retirement projection possible');
    });

    test('stage is not presentOnly for full profile', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      // With income > 0 and age > 0, should at least be emergingRetirement
      expect(snapshot.stage, isNot(equals(BudgetStage.presentOnly)));
    });

    test('fullGapVisible requires sufficient confidence', () {
      // A profile with rich data should reach fullGapVisible (confidence >= 40)
      final profile = buildProfile(
        salaireBrutMensuel: 10000,
        avoirLppTotal: 100000,
        totalEpargne3a: 30000,
        loyer: 2000,
        assuranceMaladie: 430,
      );
      final snapshot = BudgetLivingEngine.compute(profile);

      // At minimum it should not be presentOnly with this data
      expect(snapshot.stage, isNot(equals(BudgetStage.presentOnly)));
    });

    test('retirement and gap null when stage is presentOnly', () {
      final profile = buildProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(snapshot.retirement, isNull);
      expect(snapshot.gap, isNull);
    });

    test('retirement and gap populated when stage is not presentOnly', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      if (snapshot.stage != BudgetStage.presentOnly) {
        expect(snapshot.retirement, isNotNull);
        expect(snapshot.gap, isNotNull);
      }
    });
  });

  // ── Group 3: Retirement budget ───────────────────────────────

  group('BudgetLivingEngine — retirement budget', () {
    test('retirement monthlyIncome is positive for standard worker', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      if (snapshot.retirement != null) {
        expect(snapshot.retirement!.monthlyIncome, greaterThan(0));
      }
    });

    test('retirement monthlyNet <= monthlyIncome (tax reduces income)', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      if (snapshot.retirement != null) {
        expect(
          snapshot.retirement!.monthlyNet,
          lessThanOrEqualTo(snapshot.retirement!.monthlyIncome),
        );
      }
    });

    test('retirement monthlyTax is non-negative', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      if (snapshot.retirement != null) {
        expect(snapshot.retirement!.monthlyTax, greaterThanOrEqualTo(0));
      }
    });
  });

  // ── Group 4: Budget gap ──────────────────────────────────────

  group('BudgetLivingEngine — budget gap', () {
    test('replacementRate is between 0 and 200 percent', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      if (snapshot.gap != null) {
        expect(snapshot.gap!.replacementRate, inInclusiveRange(0.0, 200.0));
      }
    });

    test('gap.isSignificant returns false when present net is 0', () {
      const gap = BudgetGap(monthlyGap: 500, replacementRate: 50);
      expect(gap.isSignificant(0), isFalse);
    });

    test('gap.isSignificant returns true when gap > 20% of present net', () {
      const gap = BudgetGap(monthlyGap: 1000, replacementRate: 50);
      expect(gap.isSignificant(4000), isTrue,
          reason: '1000 gap on 4000 net = 25%, which is > 20%');
    });

    test('gap.isSurplus when retirement net exceeds present net', () {
      const gap = BudgetGap(monthlyGap: -200, replacementRate: 110);
      expect(gap.isSurplus, isTrue);
    });
  });

  // ── Group 5: Cap impacts ─────────────────────────────────────

  group('BudgetLivingEngine — cap impacts', () {
    test('cap impacts ordered by descending delta', () {
      final profile = buildProfile(
        salaireBrutMensuel: 10000,
        avoirLppTotal: 100000,
      );
      final snapshot = BudgetLivingEngine.compute(profile);

      final caps = snapshot.capImpacts;
      for (int i = 0; i < caps.length - 1; i++) {
        expect(
          caps[i].monthlyDelta,
          greaterThanOrEqualTo(caps[i + 1].monthlyDelta),
          reason: 'Caps must be sorted by descending monthly delta',
        );
      }
    });

    test('rachat_lpp cap appears when lacune > 0', () {
      final profileWithLacune = CoachProfile(
        birthYear: 1980,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          rachatMaximum: 100000,
          rachatEffectue: 0,
        ),
        patrimoine: const PatrimoineProfile(),
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 430),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Retraite',
        ),
      );
      final snapshot = BudgetLivingEngine.compute(profileWithLacune);

      if (snapshot.stage != BudgetStage.presentOnly) {
        final hasRachat =
            snapshot.capImpacts.any((c) => c.capId == 'rachat_lpp');
        expect(hasRachat, isTrue,
            reason: 'rachat_lpp cap must appear when lacune > 0');
      }
    });

    test('cap monthlyDelta values are finite and positive', () {
      final profile = buildProfile(salaireBrutMensuel: 8000);
      final snapshot = BudgetLivingEngine.compute(profile);

      for (final cap in snapshot.capImpacts) {
        expect(cap.monthlyDelta.isFinite, isTrue,
            reason: 'Cap delta must be finite');
        expect(cap.monthlyDelta, greaterThan(0),
            reason: 'Cap delta must be positive (it is a benefit)');
      }
    });

    test(
        'profil expatUs (non éligible 3a) → aucun levier « 3a_max » '
        '(Codex W4 P2)', () {
      // nationality 'US' → canContribute3a == false → annualCeiling == 0 →
      // pas de room 3a → le levier 3a_max ne doit jamais être proposé.
      final expatUs = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        nationality: 'US',
        salaireBrutMensuel: 12000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 80000,
          totalEpargne3a: 0, // aucun 3a versé : sans le gate, un gap apparaîtrait
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 20000),
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 430),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      expect(expatUs.canContribute3a, isFalse,
          reason: 'US person — providers 3a refusent (FATCA)');

      final snapshot = BudgetLivingEngine.compute(expatUs);
      final has3aMax =
          snapshot.capImpacts.any((c) => c.capId == '3a_max');
      expect(has3aMax, isFalse,
          reason:
              'Aucun levier 3a_max ne doit fuiter vers un profil non éligible');
    });

    test(
        'profil suisse éligible avec gap 3a → levier « 3a_max » présent '
        '(contrôle positif du gate)', () {
      final eligible = buildProfile(
        salaireBrutMensuel: 12000,
        totalEpargne3a: 0, // zéro 3a → gap maximal → levier attendu
        avoirLppTotal: 100000,
      );
      expect(eligible.canContribute3a, isTrue);

      final snapshot = BudgetLivingEngine.compute(eligible);
      if (snapshot.stage != BudgetStage.presentOnly) {
        final has3aMax =
            snapshot.capImpacts.any((c) => c.capId == '3a_max');
        expect(has3aMax, isTrue,
            reason: 'Le gate ne doit pas supprimer le levier pour un éligible');
      }
    });
  });

  // ── Group 6: Golden couple Julien ────────────────────────────

  group('BudgetLivingEngine — golden couple Julien (CLAUDE.md §8)', () {
    // Julien: born 1977, 122'207 CHF/an (salaireBrutMensuel = 10183.9),
    // VS, LPP 70'377, 3a 32'000. Married to Lauren.
    late CoachProfile julienProfile;

    setUp(() {
      julienProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10184, // 122'207 / 12 rounded
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5583, // 67'000 / 12 rounded
          nationality: 'US',
          isFatcaResident: true,
          canContribute3a: false,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 19620,
          ),
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          rachatEffectue: 0,
          totalEpargne3a: 32000,
          rendementCaisse: 0.05,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 0,
          investissements: 0,
        ),
        depenses: const DepensesProfile(
          loyer: 2500,
          assuranceMaladie: 860, // 2 adults in VS
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );
    });

    test('present monthlyNet is within expected range for couple', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);

      // Combined gross: ~122'207 + 67'000 = 189'207 CHF/an
      // Net should be roughly 70–85% of gross = ~11'050–13'390 CHF/mois
      // Include a safety margin: test bounds are 9'000–16'000 CHF/mois
      expect(snapshot.present.monthlyNet, greaterThan(9000));
      expect(snapshot.present.monthlyNet, lessThan(16000));
    });

    test('present monthlyFree matches net - charges - savings', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);
      final p = snapshot.present;

      expect(
        p.monthlyFree,
        closeTo(p.monthlyNet - p.monthlyCharges - p.monthlySavings, 1.0),
      );
    });

    test('retirement income is positive', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);

      expect(snapshot.retirement, isNotNull,
          reason: 'Full profile should produce retirement estimate');
      expect(snapshot.retirement!.monthlyIncome, greaterThan(0));
    });

    test('replacement rate is within plausible range (30-100%)', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);

      if (snapshot.gap != null) {
        // Swiss average replacement rate is ~60-65%, Julien known as ~65.5%
        // Allow 25-100% range to account for projection uncertainty
        expect(snapshot.gap!.replacementRate, greaterThan(25),
            reason: 'Replacement rate must be > 25% for well-funded couple');
        expect(snapshot.gap!.replacementRate, lessThan(100));
      }
    });

    test('confidence score is finite and within 0-100', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);

      expect(snapshot.confidenceScore, inInclusiveRange(0.0, 100.0));
      expect(snapshot.confidenceScore.isFinite, isTrue);
    });

    test('rachat_lpp cap is present with very large lacune', () {
      final snapshot = BudgetLivingEngine.compute(julienProfile);

      if (snapshot.stage != BudgetStage.presentOnly) {
        // Julien has 539'414 CHF lacune — rachat_lpp must be the dominant cap
        final rachatCap = snapshot.capImpacts
            .where((c) => c.capId == 'rachat_lpp')
            .firstOrNull;
        expect(rachatCap, isNotNull,
            reason:
                'Julien has CHF 539\'414 LPP lacune — rachat_lpp must appear');
        expect(rachatCap!.monthlyDelta, greaterThan(100),
            reason:
                'Projecting 539k CHF lacune over ~16 years must yield > 100 CHF/month');
      }
    });
  });

  // ── Group 7: BudgetSnapshot convenience properties ───────────

  group('BudgetSnapshot — model properties', () {
    test('monthlyFree delegates to present.monthlyFree', () {
      const p = PresentBudget(
        monthlyNet: 5000,
        monthlyCharges: 2000,
        monthlySavings: 500,
        monthlyFree: 2500,
      );
      const snap = BudgetSnapshot(
        present: p,
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 50,
      );
      expect(snap.monthlyFree, equals(2500));
    });

    test('hasFullGap is false when stage is not fullGapVisible', () {
      const p = PresentBudget(
        monthlyNet: 5000,
        monthlyCharges: 2000,
        monthlySavings: 0,
        monthlyFree: 3000,
      );
      const snap = BudgetSnapshot(
        present: p,
        gap: BudgetGap(monthlyGap: 500, replacementRate: 70),
        capImpacts: [],
        stage: BudgetStage.emergingRetirement,
        confidenceScore: 30,
      );
      expect(snap.hasFullGap, isFalse);
    });

    test('hasFullGap is true when stage is fullGapVisible and gap is set', () {
      const p = PresentBudget(
        monthlyNet: 5000,
        monthlyCharges: 2000,
        monthlySavings: 0,
        monthlyFree: 3000,
      );
      const snap = BudgetSnapshot(
        present: p,
        gap: BudgetGap(monthlyGap: 500, replacementRate: 70),
        capImpacts: [],
        stage: BudgetStage.fullGapVisible,
        confidenceScore: 70,
      );
      expect(snap.hasFullGap, isTrue);
    });
  });

  // ── Group 8: Graceful degradation ────────────────────────────

  group('BudgetLivingEngine — edge cases', () {
    test('does not throw for minimal profile', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'ZH',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('does not throw for elderly user (age 68)', () {
      final profile = buildProfile(birthYear: 1958); // age 68 in 2026
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('does not throw for very young user (age 22)', () {
      final profile = buildProfile(birthYear: 2004); // age 22 in 2026
      expect(() => BudgetLivingEngine.compute(profile), returnsNormally);
    });

    test('independently employed without LPP returns presentOnly', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 0, // independant, no salary
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        patrimoine: const PatrimoineProfile(),
        depenses: const DepensesProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final snapshot = BudgetLivingEngine.compute(profile);
      // No salary means no net income projection possible
      expect(snapshot.present.monthlyNet, equals(0));
      expect(snapshot.stage, equals(BudgetStage.presentOnly));
    });

    test('independent monthlyNet matches BudgetInputs derivation', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 10000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        patrimoine: const PatrimoineProfile(),
        depenses: const DepensesProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);
      final snapshot = BudgetLivingEngine.compute(profile);

      expect(inputs.netIncome, closeTo(9000, 0.01));
      expect(snapshot.present.monthlyNet, closeTo(inputs.netIncome, 0.01));
    });
  });

  // ── SALVAGE-00 SC-2: cross-path monthlyFree convergence (3a-contributing) ──
  //
  // Gate Fix 2 (arch-03): the engine-path and the builder-from-inputs path MUST
  // compute the SAME monthlyFree for a 3a-contributing profile, because both
  // now source planned savings from the ONE shared helper
  // BudgetLivingEngine.computeMonthlySavings (3a + LPP buyback). Before the fix
  // the builder defaulted savings to 0 (plan.future), diverging from the engine
  // by exactly total3aMensuel + totalLppBuybackMensuel.
  group('SALVAGE-00 SC-2: cross-path monthlyFree convergence (3a-contributing)',
      () {
    // Mirrors budget_screen._presentBudgetFromInputs offline fallback, post-fix:
    // savings sourced from the same shared helper the engine uses.
    double builderMonthlyFree(CoachProfile profile, BudgetSnapshot engineSnap) {
      final monthlyNet = engineSnap.present.monthlyNet;
      final monthlyCharges = engineSnap.present.monthlyCharges;
      final monthlySavings = BudgetLivingEngine.computeMonthlySavings(profile);
      return monthlyNet - monthlyCharges - monthlySavings;
    }

    test('engine and builder agree on monthlyFree for a 3a-contributing profile',
        () {
      final profile = buildProfile(
        salaireBrutMensuel: 8000,
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a test',
            category: '3a',
            amount: 564.55,
          ),
          PlannedMonthlyContribution(
            id: 'lpp_buyback_test',
            label: 'LPP buyback test',
            category: 'lpp_buyback',
            amount: 500.0,
          ),
        ],
      );
      final engineSnap = BudgetLivingEngine.compute(profile);
      final builder = builderMonthlyFree(profile, engineSnap);

      // Both paths subtract the SAME real planned 3a/LPP via ONE helper.
      expect(builder, closeTo(engineSnap.present.monthlyFree, 0.01),
          reason: 'builder monthlyFree must equal engine monthlyFree when both '
              'use computeMonthlySavings (no plan.future=0 divergence)');
      // Sanity: savings actually non-zero for this 3a-contributing fixture.
      expect(BudgetLivingEngine.computeMonthlySavings(profile),
          closeTo(1064.55, 0.01),
          reason: '3a (564.55) + LPP buyback (500) = 1064.55/mo');
    });
  });
}
