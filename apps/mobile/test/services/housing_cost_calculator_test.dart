import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/housing_cost_calculator.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  group('HousingCostCalculator', () {
    // ── compute() ──────────────────────────────────────────────

    test('renter: indexed rent increases with years to retirement', () {
      final result = HousingCostCalculator.compute(
        housingStatus: 'renter',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        monthlyRent: 2000,
      );

      // 2000 * (1.015)^15 ≈ 2501
      expect(result.monthlyNetCost, greaterThan(2000));
      expect(result.monthlyNetCost, lessThan(2600));
      expect(result.equityAvailable, 0.0);
      expect(result.fiscalImpact, 0.0);
    });

    test('renter: locataire alias works', () {
      final result = HousingCostCalculator.compute(
        housingStatus: 'locataire',
        canton: 'GE',
        currentAge: 45,
        targetRetirementAge: 65,
        monthlyRent: 1800,
      );

      expect(result.monthlyNetCost, greaterThan(1800));
      expect(result.equityAvailable, 0.0);
    });

    test('renter: null rent defaults to 0', () {
      final result = HousingCostCalculator.compute(
        housingStatus: 'renter',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
      );

      expect(result.monthlyNetCost, 0.0);
      expect(result.assumptions, contains('Loyer non renseigne, estime a 0 CHF'));
    });

    test('owner with mortgage: includes interest + amortization + PPE + maintenance', () {
      // LTV = 800k / 1M = 80% → above 65% → amortization required
      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 800000,
        mortgageRate: 0.02,
      );

      // Interest: 800k * 2% / 12 = 1333
      // Amortization: (800k - 650k) / (15*12) = 150k / 180 = 833
      // Maintenance: 1M * 1% / 12 = 833
      // PPE: 1M * 0.3% / 12 = 250
      // + fiscal impact
      expect(result.monthlyNetCost, greaterThan(3200));
      expect(result.equityAvailable, 200000);
      // Amortization should appear in assumptions
      expect(
        result.assumptions.any((a) => a.contains('Amortissement 2e rang')),
        isTrue,
        reason: 'Should mention 2nd rank amortization for LTV > 65%',
      );
    });

    test('amortization capped at 15 years (FINMA auto-regulation)', () {
      // Age 40 → retirement 65 = 25 years, but cap = min(25, 15) = 15
      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 40,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 800000,
        mortgageRate: 0.02,
      );

      // Amortization: (800k - 650k) / (15*12) = 150k / 180 ≈ 833/mo
      // NOT (800k - 650k) / (25*12) = 500/mo (uncapped would be wrong)
      expect(result.monthlyNetCost, greaterThan(3200));
      // Assumption should say 15 ans, not 25 ans
      expect(
        result.assumptions.any((a) => a.contains('sur 15 ans')),
        isTrue,
        reason: 'Amortization period should be capped at 15 years',
      );
      expect(
        result.assumptions.any((a) => a.contains('sur 25 ans')),
        isFalse,
        reason: 'Should NOT use uncapped 25 years',
      );
    });

    test('owner with LTV <= 65%: no amortization', () {
      // LTV = 500k / 1M = 50% → below 65% → no amortization
      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 500000,
        mortgageRate: 0.02,
      );

      expect(
        result.assumptions.any((a) => a.contains('Amortissement')),
        isFalse,
        reason: 'Should NOT mention amortization when LTV <= 65%',
      );
    });

    test('owner without mortgage: PPE + maintenance + valeur locative', () {
      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 55,
        targetRetirementAge: 65,
        propertyMarketValue: 800000,
        mortgageBalance: 0,
      );

      // No interest, no amortization
      // Maintenance: 800k * 1% / 12 = 667
      // PPE: 800k * 0.3% / 12 = 200
      // Valeur locative fiscal impact > 0 (no deduction from mortgage interest)
      expect(result.monthlyNetCost, greaterThan(800));
      expect(result.equityAvailable, 800000);
      expect(result.assumptions, contains('Proprietaire sans hypotheque'));
    });

    test('valeurLocative2028Reform suppresses fiscal impact', () {
      // Save and set flag
      final original = FeatureFlags.valeurLocative2028Reform;
      FeatureFlags.valeurLocative2028Reform = true;

      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 500000,
        mortgageRate: 0.02,
      );

      expect(result.fiscalImpact, 0.0);
      expect(result.assumptions, contains('Reforme 2028: valeur locative supprimee'));

      // Restore flag
      FeatureFlags.valeurLocative2028Reform = original;
    });

    test('cantonal rate disclaimer mentions estimation', () {
      final result = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 0,
      );

      expect(
        result.assumptions.any((a) => a.contains('taux moyen cantonal')),
        isTrue,
        reason: 'Should mention cantonal rate is an estimate',
      );
    });

    test('owner vs renter: owner has different cost structure', () {
      final renter = HousingCostCalculator.compute(
        housingStatus: 'renter',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        monthlyRent: 2000,
      );

      final owner = HousingCostCalculator.compute(
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 1000000,
        mortgageBalance: 500000,
        mortgageRate: 0.02,
      );

      // Both have costs, but they differ
      expect(renter.monthlyNetCost, greaterThan(0));
      expect(owner.monthlyNetCost, greaterThan(0));
      // Owner has equity, renter doesn't
      expect(owner.equityAvailable, greaterThan(0));
      expect(renter.equityAvailable, 0.0);
    });

    // ── estimateRetirementExpenses() ───────────────────────────

    test('backward compatible: null housingStatus returns base estimate', () {
      final result = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333, // 100k/12
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 0,
        housingStatus: null,
      );

      // 75% of household net via NetIncomeBreakdown.compute() (not the old * 0.87)
      // NetIncomeBreakdown.compute(grossSalary: 99996, canton: 'ZH', age: 50)
      // gives monthlyNetPayslip ≈ 7318.9 → × 0.75 ≈ 5489.2
      expect(result, closeTo(5489.17, 1.0));
    });

    test('with current expenses: uses 85% rule with floor', () {
      final result = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 6000,
        housingStatus: null,
      );

      // 85% of 6000 = 5100; floor = householdNet * 0.70
      // householdNet ≈ 7318.9 (via NetIncomeBreakdown.compute) → floor ≈ 5123.2
      // max(5100, 5123.2) = 5123.2 (floor wins because net is higher than old * 0.87)
      expect(result, closeTo(5123.23, 1.0));
    });

    test('renter housing adjusts expenses (subtract current, add indexed)', () {
      final withoutHousing = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 0,
        housingStatus: null,
      );

      final withHousing = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 0,
        housingStatus: 'renter',
        monthlyRent: 2000,
        currentAge: 50,
        targetRetirementAge: 65,
      );

      // With indexed rent, expenses should be higher
      expect(withHousing, greaterThan(withoutHousing));
    });

    test('owner: anti-double-counting subtracts current housing cost', () {
      // Owner with 300k mortgage on 800k property
      // Current housing cost: interest (300k * 1.5% / 12 = 375)
      //   + maintenance (800k * 1% / 12 = 667) + PPE (800k * 0.3% / 12 = 200) = 1242
      // Without housing adjustment, base = 85% * 6000 = 5100
      // With adjustment: 5100 - 1242 + retirementCost ≠ 5100

      final withHousing = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 6000,
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 800000,
        mortgageBalance: 300000,
        mortgageRate: 0.015,
      );

      // The adjusted expenses should differ from the base (5100)
      // because current housing is subtracted and retirement housing added
      final base = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 6000,
        housingStatus: null,
      );

      expect(withHousing, isNot(equals(base)));
    });

    test('owner housing adjusts expenses differently than renter', () {
      final ownerExpenses = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 6000,
        housingStatus: 'owner',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        propertyMarketValue: 800000,
        mortgageBalance: 300000,
        mortgageRate: 0.015,
      );

      final renterExpenses = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 6000,
        housingStatus: 'renter',
        canton: 'ZH',
        currentAge: 50,
        targetRetirementAge: 65,
        monthlyRent: 2000,
      );

      // Owner and renter should produce different expense estimates
      expect(ownerExpenses, isNot(equals(renterExpenses)));
    });

    test('zero salary fallback: returns 5000 default', () {
      final result = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 0,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 0,
        housingStatus: null,
      );

      expect(result, 5000.0);
    });

    test('couple household: both salaries contribute', () {
      final single = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 0,
        currentExpenses: 0,
        housingStatus: null,
      );

      final couple = HousingCostCalculator.estimateRetirementExpenses(
        salaireBrutMensuel: 8333,
        conjointSalaireBrutMensuel: 5000,
        currentExpenses: 0,
        housingStatus: null,
      );

      expect(couple, greaterThan(single));
    });
  });
}
