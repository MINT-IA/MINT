import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────────
//  BUDGET DOMAIN — Unit Tests
//
//  Covers:
//   A. BudgetPlan model
//   B. BudgetService.premierEclairage()
//   C. BudgetService.computePlan() — justAvailable style
//   D. BudgetService.computePlan() — envelopes3 style (no overrides)
//   E. BudgetService.computePlan() — envelopes3 style (with overrides)
//   F. BudgetService.computePlan() — stop rule / deficit
//   G. BudgetInputs helpers
//   H. Legal references
//
//  Base légale : LP art. 93, CC art. 163, LAMal art. 61, LIFD art. 33
// ────────────────────────────────────────────────────────────────

const _baseInputs = BudgetInputs(
  payFrequency: PayFrequency.monthly,
  netIncome: 5000,
  housingCost: 1500,
  debtPayments: 200,
  taxProvision: 300,
  healthInsurance: 400,
  otherFixedCosts: 100,
  style: BudgetStyle.envelopes3,
);

void main() {
  // ════════════════════════════════════════════════════════════
  //  A. BudgetPlan model
  // ════════════════════════════════════════════════════════════

  group('BudgetPlan', () {
    test('constructor stores all fields', () {
      const plan = BudgetPlan(
        available: 2500,
        variables: 2000,
        future: 500,
        stopRuleTriggered: false,
        emergencyFundMonths: 3,
      );

      expect(plan.available, 2500);
      expect(plan.variables, 2000);
      expect(plan.future, 500);
      expect(plan.stopRuleTriggered, isFalse);
      expect(plan.emergencyFundMonths, 3);
    });

    test('emergencyFundProgress: 0 months → 0.0', () {
      const plan = BudgetPlan(
        available: 1000,
        variables: 1000,
        future: 0,
        stopRuleTriggered: false,
        emergencyFundMonths: 0,
      );
      expect(plan.emergencyFundProgress, 0.0);
    });

    test('emergencyFundProgress: 3 months → 0.5 (target = 6)', () {
      const plan = BudgetPlan(
        available: 1000,
        variables: 1000,
        future: 0,
        stopRuleTriggered: false,
        emergencyFundMonths: 3,
      );
      expect(plan.emergencyFundProgress, closeTo(0.5, 0.001));
    });

    test('emergencyFundProgress: 6 months → 1.0 (fully funded)', () {
      const plan = BudgetPlan(
        available: 1000,
        variables: 1000,
        future: 0,
        stopRuleTriggered: false,
        emergencyFundMonths: 6,
      );
      expect(plan.emergencyFundProgress, 1.0);
    });

    test('emergencyFundProgress: 12 months → clamped at 1.0', () {
      const plan = BudgetPlan(
        available: 1000,
        variables: 1000,
        future: 0,
        stopRuleTriggered: false,
        emergencyFundMonths: 12,
      );
      expect(plan.emergencyFundProgress, 1.0);
    });

    test('emergencyFundTarget constant is 6.0', () {
      expect(BudgetPlan.emergencyFundTarget, 6.0);
    });

    test('equality: same values are equal', () {
      const a = BudgetPlan(
        available: 1000,
        variables: 800,
        future: 200,
        stopRuleTriggered: false,
        emergencyFundMonths: 2,
      );
      const b = BudgetPlan(
        available: 1000,
        variables: 800,
        future: 200,
        stopRuleTriggered: false,
        emergencyFundMonths: 2,
      );
      expect(a, equals(b));
    });

    test('equality: different available → not equal', () {
      const a = BudgetPlan(
        available: 1000,
        variables: 1000,
        future: 0,
        stopRuleTriggered: false,
      );
      const b = BudgetPlan(
        available: 2000,
        variables: 2000,
        future: 0,
        stopRuleTriggered: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('stopRuleTriggered=true preserved', () {
      const plan = BudgetPlan(
        available: 0,
        variables: 0,
        future: 0,
        stopRuleTriggered: true,
      );
      expect(plan.stopRuleTriggered, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B. BudgetService.premierEclairage()
  // ════════════════════════════════════════════════════════════

  group('BudgetService.premierEclairage', () {
    test('zero income surfaces enrichment prompt (P0-B1)', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 0,
        housingCost: 1000,
        debtPayments: 0,
      );
      // Wave 7 P0-B1 — previous "0 % de ton revenu part en charges fixes"
      // masked a missing income. The fix now surfaces an enrichment CTA.
      expect(BudgetService.premierEclairage(inputs),
          contains('Déclare ton revenu net'));
    });

    test('all charges = 0 returns 0%', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 0,
        debtPayments: 0,
      );
      expect(BudgetService.premierEclairage(inputs),
          '0 % de ton revenu part en charges fixes');
    });

    test('half income in charges → 50 % (neutral band)', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 4000,
        housingCost: 2000,
        debtPayments: 0,
      );
      expect(BudgetService.premierEclairage(inputs),
          '50 % de ton revenu part en charges fixes');
    });

    test('pct ≥ 70 % triggers fragile band + LP art. 93 (P0-B1)', () {
      // totalCharges = 2000 + 400 + 200 = 2600 over netIncome 3300 → 79 %.
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 3300,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 200,
        healthInsurance: 400,
      );
      final msg = BudgetService.premierEclairage(inputs);
      expect(msg, contains('79 %'));
      expect(msg, contains('Situation fragile'));
      expect(msg, contains('LP art. 93'));
    });

    test('pct ≥ 100 % triggers Safe Mode escalation (P0-B1)', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 2000,
        housingCost: 1500,
        debtPayments: 500,
        taxProvision: 200,
      );
      // totalCharges = 2200; pct = round(2200/2000 * 100) = 110
      final msg = BudgetService.premierEclairage(inputs);
      expect(msg, contains('110 %'));
      expect(msg, contains('dépassent ton revenu'));
      expect(msg, contains('Safe Mode'));
    });

    test('thresholds use displayed CHF values, not raw cents', () {
      const fragileInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000.49,
        housingCost: 699.51,
        debtPayments: 0,
      );
      final fragileMsg = BudgetService.premierEclairage(fragileInputs);
      final fragilePlan = BudgetService().computePlan(fragileInputs);

      expect(fragileMsg, contains('70 %'));
      expect(fragileMsg, contains('Situation fragile'));
      expect(fragilePlan.distress, BudgetDistressLevel.fragile);

      const criticalInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000.49,
        housingCost: 999.51,
        debtPayments: 0,
      );
      final criticalMsg = BudgetService.premierEclairage(criticalInputs);
      final criticalPlan = BudgetService().computePlan(criticalInputs);

      expect(criticalMsg, contains('100 %'));
      expect(criticalMsg, contains('atteignent ou dépassent'));
      expect(criticalMsg, contains('Safe Mode'));
      expect(criticalPlan.distress, BudgetDistressLevel.critical);

      const neutralInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000.49,
        housingCost: 599.51,
        debtPayments: 0,
      );
      final neutralPlan = BudgetService().computePlan(neutralInputs);

      expect(BudgetService.premierEclairage(neutralInputs), contains('60 %'));
      expect(neutralPlan.distress, BudgetDistressLevel.none);
    });

    test('golden couple Julien — typical household budget', () {
      // Julien: net income ~8100 CHF/month (from 122'207 CHF gross, VS canton)
      // Loyer typical VS: ~1800, LAMal: ~450, tax: ~900, dettes: 0
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8100,
        housingCost: 1800,
        debtPayments: 0,
        taxProvision: 900,
        healthInsurance: 450,
        otherFixedCosts: 200,
      );
      final choc = BudgetService.premierEclairage(inputs);
      // totalCharges = 3350; pct = round(3350/8100 * 100) = 41
      expect(choc, '41 % de ton revenu part en charges fixes');
    });

    test('BudgetPlan.distress mirrors thresholds (P0-B1 wiring)', () {
      // Fragile band
      const fragileInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 3300,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 200,
        healthInsurance: 400,
      );
      final fragilePlan = BudgetService().computePlan(fragileInputs);
      expect(fragilePlan.distress, BudgetDistressLevel.fragile);

      // Critical band
      const criticalInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 2000,
        housingCost: 1500,
        debtPayments: 500,
        taxProvision: 200,
      );
      final criticalPlan = BudgetService().computePlan(criticalInputs);
      expect(criticalPlan.distress, BudgetDistressLevel.critical);

      // Unknown when income missing
      const unknownInputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 0,
        housingCost: 1500,
        debtPayments: 0,
      );
      final unknownPlan = BudgetService().computePlan(unknownInputs);
      expect(unknownPlan.distress, BudgetDistressLevel.unknown);
      expect(unknownPlan.chargesRatio, isNull);
    });

    test('has disclaimer', () {
      expect(BudgetService.disclaimer, contains('LSFin'));
      expect(BudgetService.disclaimer, contains('éducatif'));
    });

    test('has legal sources', () {
      expect(BudgetService.sources, isNotEmpty);
      expect(BudgetService.sources.any((s) => s.contains('LAMal')), isTrue);
      expect(BudgetService.sources.any((s) => s.contains('LIFD')), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  C. BudgetService.computePlan() — justAvailable
  // ════════════════════════════════════════════════════════════

  group('BudgetService.computePlan — justAvailable style', () {
    final service = BudgetService();

    test('available = income - all fixed charges', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 200,
        taxProvision: 300,
        healthInsurance: 400,
        otherFixedCosts: 100,
        style: BudgetStyle.justAvailable,
      );
      final plan = service.computePlan(inputs);
      // available = 5000 - 1500 - 200 - 300 - 400 - 100 = 2500
      expect(plan.available, closeTo(2500, 0.01));
    });

    test('justAvailable: variables == available, future == 0', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 2000,
        debtPayments: 0,
        style: BudgetStyle.justAvailable,
      );
      final plan = service.computePlan(inputs);
      expect(plan.variables, equals(plan.available));
      expect(plan.future, 0);
    });

    test('justAvailable: stopRuleTriggered always false', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000,
        housingCost: 1000,
        debtPayments: 0,
        style: BudgetStyle.justAvailable,
      );
      final plan = service.computePlan(inputs);
      expect(plan.stopRuleTriggered, isFalse);
    });

    test('justAvailable: available never negative (deficit clamped to 0)', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000,
        housingCost: 2000,
        debtPayments: 500,
        style: BudgetStyle.justAvailable,
      );
      final plan = service.computePlan(inputs);
      expect(plan.available, 0.0);
      expect(plan.variables, 0.0);
    });

    test('justAvailable: emergency fund months propagated from inputs', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1000,
        debtPayments: 0,
        style: BudgetStyle.justAvailable,
        emergencyFundMonths: 4,
      );
      final plan = service.computePlan(inputs);
      expect(plan.emergencyFundMonths, 4);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  D. BudgetService.computePlan() — envelopes3 (no overrides)
  // ════════════════════════════════════════════════════════════

  group('BudgetService.computePlan — envelopes3 no overrides', () {
    final service = BudgetService();

    test('default: all available goes to variables, future = 0', () {
      final plan = service.computePlan(_baseInputs);
      // available = 5000 - 1500 - 200 - 300 - 400 - 100 = 2500
      expect(plan.available, closeTo(2500, 0.01));
      expect(plan.variables, closeTo(2500, 0.01));
      expect(plan.future, closeTo(0, 0.01));
    });

    test('available matches canonical displayed monthly free when future is 0',
        () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000.4,
        housingCost: 1200.5,
        healthInsurance: 400.5,
        taxProvision: 300.5,
        debtPayments: 200.5,
        otherFixedCosts: 100.5,
        style: BudgetStyle.envelopes3,
      );

      final plan = service.computePlan(inputs);
      final present = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: plan,
      );

      expect(plan.available, 2795);
      expect(plan.available, present.monthlyFree);
      expect(
        plan.available + PresentBudgetBuilder.fixedChargesFromInputs(inputs),
        PresentBudgetBuilder.displayChf(inputs.netIncome),
      );
    });

    test('variables + future == available', () {
      final plan = service.computePlan(_baseInputs);
      expect(plan.variables + plan.future, closeTo(plan.available, 0.01));
    });

    test('stopRuleTriggered = false when variables > 0', () {
      final plan = service.computePlan(_baseInputs);
      expect(plan.stopRuleTriggered, isFalse);
    });

    test('zero income → available = 0, stopRuleTriggered = true', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 0,
        housingCost: 0,
        debtPayments: 0,
        style: BudgetStyle.envelopes3,
      );
      final plan = service.computePlan(inputs);
      expect(plan.available, 0.0);
      expect(plan.stopRuleTriggered, isTrue);
    });

    test('emergency fund months propagated', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1000,
        debtPayments: 0,
        style: BudgetStyle.envelopes3,
        emergencyFundMonths: 6,
      );
      final plan = service.computePlan(inputs);
      expect(plan.emergencyFundMonths, 6);
      expect(plan.emergencyFundProgress, 1.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  E. BudgetService.computePlan() — envelopes3 with overrides
  // ════════════════════════════════════════════════════════════

  group('BudgetService.computePlan — envelopes3 with overrides', () {
    final service = BudgetService();

    test('override future → variables = available - future', () {
      // available = 5000 - 1500 - 200 - 300 - 400 - 100 = 2500
      final plan = service.computePlan(_baseInputs, overrides: {'future': 500});
      expect(plan.future, closeTo(500, 0.01));
      expect(plan.variables, closeTo(2000, 0.01));
    });

    test('override variables → future = available - variables', () {
      final plan =
          service.computePlan(_baseInputs, overrides: {'variables': 1500});
      expect(plan.variables, closeTo(1500, 0.01));
      expect(plan.future, closeTo(1000, 0.01));
    });

    test('override future exceeding available → clamped to available', () {
      // available = 2500; override future = 5000 → clamped to 2500
      final plan =
          service.computePlan(_baseInputs, overrides: {'future': 5000});
      expect(plan.future, closeTo(2500, 0.01));
      expect(plan.variables, closeTo(0, 0.01));
    });

    test('override future negative → clamped to 0', () {
      final plan =
          service.computePlan(_baseInputs, overrides: {'future': -100});
      expect(plan.future, closeTo(0, 0.01));
      expect(plan.variables, closeTo(2500, 0.01));
    });

    test('override variables exceeding available → clamped to available', () {
      final plan =
          service.computePlan(_baseInputs, overrides: {'variables': 9999});
      expect(plan.variables, closeTo(2500, 0.01));
      expect(plan.future, closeTo(0, 0.01));
    });

    test('override variables negative → clamped to 0', () {
      final plan =
          service.computePlan(_baseInputs, overrides: {'variables': -50});
      expect(plan.variables, closeTo(0, 0.01));
      expect(plan.future, closeTo(2500, 0.01));
    });

    test('override future = 0 → all available in variables', () {
      final plan = service.computePlan(_baseInputs, overrides: {'future': 0});
      expect(plan.future, closeTo(0, 0.01));
      expect(plan.variables, closeTo(2500, 0.01));
    });

    test('variables + future == available after override', () {
      final plan = service.computePlan(_baseInputs, overrides: {'future': 800});
      expect(plan.variables + plan.future, closeTo(plan.available, 0.01));
    });

    test('stopRuleTriggered when override sets variables to 0', () {
      // Force variables to 0 via future = available
      final plan =
          service.computePlan(_baseInputs, overrides: {'future': 2500});
      expect(plan.stopRuleTriggered, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  F. BudgetService.computePlan() — stop rule / deficit
  // ════════════════════════════════════════════════════════════

  group('BudgetService.computePlan — stop rule and deficit', () {
    final service = BudgetService();

    test('charges exceed income → available = 0, stopRuleTriggered = true', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 2000,
        housingCost: 1800,
        debtPayments: 400,
        taxProvision: 100,
        style: BudgetStyle.envelopes3,
      );
      final plan = service.computePlan(inputs);
      expect(plan.available, 0.0);
      expect(plan.stopRuleTriggered, isTrue);
    });

    test('exactly zero available → stopRuleTriggered = true', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 3000,
        housingCost: 1500,
        debtPayments: 500,
        taxProvision: 500,
        healthInsurance: 500,
        style: BudgetStyle.envelopes3,
      );
      final plan = service.computePlan(inputs);
      expect(plan.available, closeTo(0, 0.01));
      expect(plan.stopRuleTriggered, isTrue);
    });

    test('very tight budget (1 CHF available) → not triggered', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 3001,
        housingCost: 1500,
        debtPayments: 500,
        taxProvision: 500,
        healthInsurance: 500,
        style: BudgetStyle.envelopes3,
      );
      final plan = service.computePlan(inputs);
      expect(plan.available, closeTo(1, 0.01));
      expect(plan.stopRuleTriggered, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  G. BudgetInputs helpers
  // ════════════════════════════════════════════════════════════

  group('BudgetInputs', () {
    test('hasEstimatedValues = false when both flags false', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        isTaxEstimated: false,
        isHealthEstimated: false,
      );
      expect(inputs.hasEstimatedValues, isFalse);
    });

    test('hasEstimatedValues = true when tax is estimated', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        isTaxEstimated: true,
      );
      expect(inputs.hasEstimatedValues, isTrue);
    });

    test('hasEstimatedValues = true when health is estimated', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        isHealthEstimated: true,
      );
      expect(inputs.hasEstimatedValues, isTrue);
    });

    test('hasMissingValues = true when otherFixed missing', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        isOtherFixedMissing: true,
      );
      expect(inputs.hasMissingValues, isTrue);
    });

    test('hasMissingValues = false by default', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
      );
      expect(inputs.hasMissingValues, isFalse);
    });

    test('default style is envelopes3', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1000,
        debtPayments: 0,
      );
      expect(inputs.style, BudgetStyle.envelopes3);
    });

    test('default emergency fund months is 0', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1000,
        debtPayments: 0,
      );
      expect(inputs.emergencyFundMonths, 0);
    });

    test('plausibleMonthlyFixedExpensesFromProfile ignores impossible housing',
        () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
          transport: 200,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final expenses =
          BudgetInputs.plausibleMonthlyFixedExpensesFromProfile(profile);

      expect(expenses, 620);
    });

    test('fromCoachProfile prefers explicit debt monthly payment over proxy',
        () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(
          creditConsommation: 24000,
          mensualiteCreditConso: 1200,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.debtPayments, 1200);
    });

    test('fromCoachProfile sums explicit consumer and leasing payments', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(
          creditConsommation: 24000,
          leasing: 12000,
          mensualiteCreditConso: 600,
          mensualiteLeasing: 350,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.debtPayments, 950);
    });

    test('fromCoachProfile keeps mortgage out of debt payments', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(
          hypotheque: 500000,
          creditConsommation: 24000,
          leasing: 12000,
          mensualiteHypotheque: 1800,
          mensualiteCreditConso: 600,
          mensualiteLeasing: 350,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.debtPayments, 950);
    });

    test('fromCoachProfile counts housing separately from consumer debt', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        depenses: const DepensesProfile(loyer: 2200),
        dettes: const DetteProfile(
          hypotheque: 500000,
          creditConsommation: 24000,
          leasing: 12000,
          mensualiteHypotheque: 1800,
          mensualiteCreditConso: 600,
          mensualiteLeasing: 350,
        ),
        dataSources: const {
          'depenses.loyer': ProfileDataSource.userInput,
        },
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.housingCost, 2200);
      expect(inputs.debtPayments, 950);
    });

    test('fromCoachProfile uses total debt proxy only without monthly payments',
        () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(creditConsommation: 21600),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.debtPayments, 600);
    });

    test('fromWizardAnswers preserves declared monthly debt payment', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_gross_salary_annual': 84000,
        'q_has_consumer_debt': true,
        'q_debt_payments_period_chf': 900,
      });

      expect(profile.dettes.totalDettes, 0);
      expect(profile.dettes.totalMensualite, 900);
      expect(profile.dettes.hasDette, isTrue);

      final inputs = BudgetInputs.fromCoachProfile(profile);
      expect(inputs.debtPayments, 900);
    });

    test('PayFrequency enum has three values', () {
      expect(PayFrequency.values, hasLength(3));
      expect(PayFrequency.values, contains(PayFrequency.monthly));
      expect(PayFrequency.values, contains(PayFrequency.biweekly));
      expect(PayFrequency.values, contains(PayFrequency.weekly));
    });

    test('BudgetStyle enum has two values', () {
      expect(BudgetStyle.values, hasLength(2));
      expect(BudgetStyle.values, contains(BudgetStyle.justAvailable));
      expect(BudgetStyle.values, contains(BudgetStyle.envelopes3));
    });

    test('fromMap with emergency fund yes_6months → 6', () {
      final map = {
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_emergency_fund': 'yes_6months',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      };
      final inputs = BudgetInputs.fromMap(map);
      expect(inputs.emergencyFundMonths, 6);
    });

    test('fromMap with emergency fund yes_3months → 3', () {
      final map = {
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_emergency_fund': 'yes_3months',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      };
      final inputs = BudgetInputs.fromMap(map);
      expect(inputs.emergencyFundMonths, 3);
    });

    test('fromMap with emergency fund no → 0', () {
      final map = {
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_emergency_fund': 'no',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      };
      final inputs = BudgetInputs.fromMap(map);
      expect(inputs.emergencyFundMonths, 0);
    });

    test('fromMap unknown pay_frequency → defaults to monthly', () {
      final map = {
        'q_pay_frequency': 'quarterly', // unknown
        'q_net_income_period_chf': 4000.0,
        'q_housing_cost_period_chf': 1000.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'ZH',
        'q_civil_status': 'single',
      };
      final inputs = BudgetInputs.fromMap(map);
      expect(inputs.payFrequency, PayFrequency.monthly);
    });

    test('fromMap unknown budget_style → defaults to envelopes3', () {
      final map = {
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 4000.0,
        'q_housing_cost_period_chf': 1000.0,
        'q_debt_payments_period_chf': 0.0,
        'q_budget_style': 'unknown_style',
        'q_canton': 'ZH',
        'q_civil_status': 'single',
      };
      final inputs = BudgetInputs.fromMap(map);
      expect(inputs.style, BudgetStyle.envelopes3);
    });

    test('fromMap reads legacy q_net_income_monthly when canonical is absent',
        () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_monthly': 6000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, 6000);
    });

    test('fromMap prefers canonical income when both income keys exist', () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_monthly': 4000.0,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5379.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, 5379);
    });

    test('fromMap lets explicit zero canonical income override legacy income',
        () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_monthly': 5379.0,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 0.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, 0);
    });

    test('fromMap accepts persisted numeric strings', () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_period_chf': '5379',
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_other_fixed_costs_monthly_chf': '180',
        'q_tax_provision_monthly_chf': '520',
        'q_debt_payments_period_chf': '0',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, 5379);
      expect(inputs.housingCost, 2200);
      expect(inputs.healthInsurance, 420);
      expect(inputs.otherFixedCosts, 180);
      expect(inputs.taxProvision, 520);
    });

    test('fromMap sums detailed coach fixed expenses when canonical is absent',
        () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_period_chf': '5379',
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '520',
        'q_debt_payments_period_chf': '0',
        '_coach_depenses_transport': '120',
        '_coach_depenses_telecom': '80',
        '_coach_depenses_electricite': '60',
        '_coach_depenses_frais_medicaux': '40',
        '_coach_depenses_autres': '100',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.otherFixedCosts, 400);
      expect(inputs.isOtherFixedMissing, isFalse);
    });

    test('fromMap accepts Swiss apostrophe numeric strings', () {
      final inputs = BudgetInputs.fromMap({
        'q_net_income_period_chf': "5'379",
        'q_housing_cost_period_chf': "2'200",
        'q_lamal_premium_monthly_chf': '420',
        'q_debt_payments_period_chf': '0',
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, 5379);
      expect(inputs.housingCost, 2200);
      expect(inputs.healthInsurance, 420);
    });

    test('fromMap normalizes weekly income to monthly', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'weekly',
        'q_net_income_period_chf': 1000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, closeTo(4333, 1));
    });

    test('fromMap estimates tax from normalized non-monthly income', () {
      final weekly = BudgetInputs.fromMap({
        'q_pay_frequency': 'weekly',
        'q_net_income_period_chf': 1000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });
      final monthlyEquivalent = BudgetInputs.fromMap({
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 4333.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(weekly.netIncome, closeTo(monthlyEquivalent.netIncome, 1));
      expect(weekly.taxProvision, closeTo(monthlyEquivalent.taxProvision, 1));
      expect(weekly.isTaxEstimated, isTrue);
    });

    test('fromMap treats housing and debt amounts as monthly', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'weekly',
        'q_net_income_period_chf': 1000.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 100.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, closeTo(4333, 1));
      expect(inputs.housingCost, 1500);
      expect(inputs.debtPayments, 100);
    });

    test('fromMap keeps biweekly budget debt monthly', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'biweekly',
        'q_net_income_period_chf': 2500.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 1200.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, closeTo(5415, 1));
      expect(inputs.debtPayments, 1200);
    });

    test('fromMap normalizes biweekly income to monthly', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'biweekly',
        'q_net_income_period_chf': 2500.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_debt_payments_period_chf': 0.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.netIncome, closeTo(5415, 1));
    });

    test('fromMap drops implausible monthly capture amounts', () {
      final map = {
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5379.0,
        'q_housing_cost_period_chf': 19272200.0,
        'q_lamal_premium_monthly_chf': 420420.0,
        'q_other_fixed_costs_monthly_chf': 50000.0,
        'q_canton': 'VS',
        'q_civil_status': 'single',
      };

      final inputs = BudgetInputs.fromMap(map);

      expect(inputs.housingCost, 0);
      expect(inputs.healthInsurance, lessThan(1000));
      expect(inputs.isHealthEstimated, isTrue);
      expect(inputs.otherFixedCosts, 0);
      expect(inputs.isOtherFixedMissing, isTrue);
    });

    test('fromMap marks absent housing as missing for legacy budgets', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5379.0,
        'q_lamal_premium_monthly_chf': 420.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.housingCost, 0);
      expect(inputs.isHousingMissing, isTrue);
      expect(inputs.hasMissingValues, isTrue);
    });

    test('fromMap marks absent LAMal as missing for legacy budgets', () {
      final inputs = BudgetInputs.fromMap({
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 5379.0,
        'q_housing_cost_period_chf': 1500.0,
        'q_canton': 'VD',
        'q_civil_status': 'single',
      });

      expect(inputs.healthInsurance, greaterThan(0));
      expect(inputs.isHealthEstimated, isTrue);
      expect(inputs.isHealthMissing, isTrue);
      expect(inputs.hasMissingValues, isTrue);
    });

    test('fromCoachProfile marks absent housing and LAMal as missing', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 520,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.housingCost, 0);
      expect(inputs.healthInsurance, 0);
      expect(inputs.isHousingMissing, isTrue);
      expect(inputs.isHealthMissing, isTrue);
      expect(inputs.isHealthEstimated, isFalse);
      expect(inputs.hasMissingValues, isTrue);
    });

    test('fromCoachProfile preserves estimated LAMal source as estimated', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(assuranceMaladie: 520),
        dataSources: const {
          'depenses.assuranceMaladie': ProfileDataSource.estimated,
        },
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.healthInsurance, 520);
      expect(inputs.isHealthMissing, isFalse);
      expect(inputs.isHealthEstimated, isTrue);
    });

    test('fromCoachProfile treats userProvided LAMal as provided', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(assuranceMaladie: 420),
        userProvidedFields: const {'lamalPremium'},
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.healthInsurance, 420);
      expect(inputs.isHealthMissing, isFalse);
      expect(inputs.isHealthEstimated, isFalse);
    });

    test('fromCoachProfile uses independent net-income approximation', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 10000,
        employmentStatus: 'independant',
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.netIncome, closeTo(9000, 0.01));
    });

    test(
        'fromCoachProfile uses professional net income when independent gross is absent',
        () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 0,
        employmentStatus: 'independant',
        independentNetProfessionalIncomeAnnual: 96000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.netIncome, 8000);
    });

    test('fromCoachProfile uses annual gross for salaried net income', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 10000,
        nombreDeMois: 13,
        employmentStatus: 'salarie',
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);
      final expected = NetIncomeBreakdown.compute(
        grossSalary: profile.revenuBrutAnnuel,
        canton: profile.canton,
        age: profile.age,
      ).monthlyNetPayslip;

      expect(inputs.netIncome, closeTo(expected, 0.01));
    });

    test('fromCoachProfile includes independent partner approximation', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'GE',
        salaireBrutMensuel: 6000,
        employmentStatus: 'salarie',
        conjoint: const ConjointProfile(
          birthYear: 1988,
          salaireBrutMensuel: 4000,
          employmentStatus: 'independant',
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);
      final ownNet = NetIncomeBreakdown.compute(
        grossSalary: profile.revenuBrutAnnuel,
        canton: profile.canton,
        age: profile.age,
      ).monthlyNetPayslip;

      expect(inputs.netIncome, closeTo(ownNet + 3600, 0.01));
    });

    test('fromCoachProfile sums only trusted detailed fixed expenses', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(
          electricite: 80,
          transport: 120,
          telecom: 90,
          fraisMedicaux: 60,
          autresDepensesFixes: 700,
        ),
        dataSources: const {
          'depenses.transport': ProfileDataSource.userInput,
          'depenses.telecom': ProfileDataSource.userInput,
        },
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.otherFixedCosts, 210);
      expect(inputs.isOtherFixedMissing, isFalse);
    });

    test('fromCoachProfile excludes implausible charges from emergency fund',
        () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VS',
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420420,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 12000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );

      final inputs = BudgetInputs.fromCoachProfile(profile);

      expect(inputs.housingCost, 0);
      expect(inputs.healthInsurance, 0);
      expect(inputs.emergencyFundMonths, greaterThan(1));
    });

    test('toMap roundtrip preserves core values', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 200,
        taxProvision: 300,
        healthInsurance: 400,
        otherFixedCosts: 100,
        isTaxEstimated: true,
        isHealthEstimated: false,
        isHousingMissing: false,
        isHealthMissing: false,
        isOtherFixedMissing: false,
        style: BudgetStyle.envelopes3,
        emergencyFundMonths: 3,
      );
      final map = inputs.toMap();
      expect(map['q_pay_frequency'], 'monthly');
      expect(map['q_net_income_period_chf'], 5000);
      expect(map['q_housing_cost_period_chf'], 1500);
      expect(map['q_debt_payments_period_chf'], 200);
      expect(map['q_tax_provision_monthly_chf'], 300);
      expect(map['q_lamal_premium_monthly_chf'], 400);
      expect(map['q_other_fixed_costs_monthly_chf'], 100);
      expect(map['meta_tax_estimated'], isTrue);
      expect(map['meta_health_estimated'], isFalse);
      expect(map['meta_housing_missing'], isFalse);
      expect(map['meta_health_missing'], isFalse);
      expect(map['meta_other_fixed_missing'], isFalse);
      expect(map['q_budget_style'], 'envelopes3');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  H. Legal & compliance
  // ════════════════════════════════════════════════════════════

  group('BudgetService — compliance', () {
    test('disclaimer references LSFin', () {
      expect(BudgetService.disclaimer.toLowerCase(), contains('lsfin'));
    });

    test('disclaimer mentions "outil éducatif"', () {
      expect(BudgetService.disclaimer, contains('éducatif'));
    });

    test('disclaimer mentions "ne constitue pas un conseil"', () {
      expect(BudgetService.disclaimer, contains('ne constitue pas'));
    });

    test('sources list references LAMal', () {
      expect(
        BudgetService.sources.any((s) => s.contains('LAMal')),
        isTrue,
      );
    });

    test('sources list references LIFD', () {
      expect(
        BudgetService.sources.any((s) => s.contains('LIFD')),
        isTrue,
      );
    });

    test('sources list references CC', () {
      expect(
        BudgetService.sources.any((s) => s.contains('CC')),
        isTrue,
      );
    });

    test('premierEclairage never returns a promised return or banned term', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
      );
      final choc = BudgetService.premierEclairage(inputs);
      const bannedTerms = [
        'garanti',
        'certain',
        'optimal',
        'meilleur',
        'parfait',
        'sans risque',
      ];
      for (final term in bannedTerms) {
        expect(choc.toLowerCase(), isNot(contains(term)),
            reason: 'premierEclairage contains banned term: $term');
      }
    });
  });
}
