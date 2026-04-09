import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';

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
    test('zero income returns 0% message', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 0,
        housingCost: 1000,
        debtPayments: 0,
      );
      expect(BudgetService.premierEclairage(inputs),
          '0% de ton revenu part en charges fixes');
    });

    test('all charges = 0 returns 0%', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 0,
        debtPayments: 0,
      );
      expect(BudgetService.premierEclairage(inputs),
          '0% de ton revenu part en charges fixes');
    });

    test('half income in charges → 50%', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 4000,
        housingCost: 2000,
        debtPayments: 0,
      );
      expect(BudgetService.premierEclairage(inputs),
          '50% de ton revenu part en charges fixes');
    });

    test('charges exceed income returns 100%+ message', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 2000,
        housingCost: 1500,
        debtPayments: 500,
        taxProvision: 200,
      );
      // totalCharges = 2200; pct = round(2200/2000 * 100) = 110
      expect(BudgetService.premierEclairage(inputs),
          '110% de ton revenu part en charges fixes');
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
      expect(choc, '41% de ton revenu part en charges fixes');
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
      final plan =
          service.computePlan(_baseInputs, overrides: {'future': 800});
      expect(plan.variables + plan.future, closeTo(plan.available, 0.01));
    });

    test('stopRuleTriggered when override sets variables to 0', () {
      // Force variables to 0 via future = available
      final plan = service.computePlan(_baseInputs, overrides: {'future': 2500});
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
