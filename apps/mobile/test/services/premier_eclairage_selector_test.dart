import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';

/// Tests for PremierEclairageSelector (Sprint S31).
///
/// Validates non-AVS priority, legacy-value quarantine, edge cases, and
/// compliance with no-advice / no-promise rules.
void main() {
  /// Helper to build a MinimalProfileResult with sensible defaults.
  MinimalProfileResult profile0({
    double? avsMonthlyRente = 1900,
    double lppAnnualRente = 24000,
    double lppMonthlyRente = 2000,
    double? totalMonthlyRetirement = 3900,
    double grossMonthlySalary = 8333,
    double? replacementRate = 0.47,
    double? retirementGapMonthly = 4433,
    double taxSaving3a = 1820,
    double marginalTaxRate = 0.25,
    double currentSavings = 30000,
    double estimatedMonthlyExpenses = 5000,
    double monthlyDebtImpact = 0,
    double liquidityMonths = 6,
    String canton = 'VD',
    int age = 45,
    double grossAnnualSalary = 100000,
    String householdType = 'single',
    bool isPropertyOwner = false,
    double existing3a = 0,
    double existingLpp = 50000,
    String employmentStatus = 'salarie',
    String nationalityGroup = 'CH',
    double plafond3a = 7258,
    List<String> estimatedFields = const [],
  }) {
    return MinimalProfileResult(
      avsMonthlyRente: avsMonthlyRente,
      lppAnnualRente: lppAnnualRente,
      lppMonthlyRente: lppMonthlyRente,
      totalMonthlyRetirement: totalMonthlyRetirement,
      grossMonthlySalary: grossMonthlySalary,
      replacementRate: replacementRate,
      retirementGapMonthly: retirementGapMonthly,
      taxSaving3a: taxSaving3a,
      marginalTaxRate: marginalTaxRate,
      currentSavings: currentSavings,
      estimatedMonthlyExpenses: estimatedMonthlyExpenses,
      monthlyDebtImpact: monthlyDebtImpact,
      liquidityMonths: liquidityMonths,
      canton: canton,
      age: age,
      grossAnnualSalary: grossAnnualSalary,
      householdType: householdType,
      isPropertyOwner: isPropertyOwner,
      existing3a: existing3a,
      existingLpp: existingLpp,
      employmentStatus: employmentStatus,
      nationalityGroup: nationalityGroup,
      plafond3a: plafond3a,
      estimatedFields: estimatedFields,
    );
  }

  group('G1 certified-null AVS contract', () {
    test('missing AVS envelope selects a non-retirement alternative', () {
      final result = PremierEclairageSelector.select(
        profile0(
          avsMonthlyRente: null,
          totalMonthlyRetirement: null,
          replacementRate: null,
          retirementGapMonthly: null,
          age: 49,
          existing3a: 5000,
          taxSaving3a: 500,
          nationalityGroup: 'EU',
          employmentStatus: 'independant',
          lppMonthlyRente: 0,
        ),
        stressType: 'stress_retraite',
      );

      expect(result.type, PremierEclairageType.hourlyRate);
    });

    test('legacy pension doubles cannot reactivate a retirement insight', () {
      final result = PremierEclairageSelector.select(
        profile0(
          avsMonthlyRente: 1200,
          totalMonthlyRetirement: 3200,
          replacementRate: 0.38,
          retirementGapMonthly: 5100,
          age: 49,
          existing3a: 5000,
          taxSaving3a: 500,
          nationalityGroup: 'EU',
          employmentStatus: 'independant',
          lppMonthlyRente: 0,
        ),
        stressType: 'stress_retraite',
      );

      expect(result.type, PremierEclairageType.hourlyRate);
      expect(
        result.type,
        isNot(anyOf(
          PremierEclairageType.retirementGap,
          PremierEclairageType.retirementIncome,
        )),
      );
      expect(result.rawValue, isNot(anyOf(1200, 3200, 0.38, 5100)));
    });
  });

  group('PremierEclairageSelector — non-AVS priorities', () {
    test('real liquidity below two months has first universal priority', () {
      final result = PremierEclairageSelector.select(profile0(
        liquidityMonths: 1.5,
        currentSavings: 7500,
        estimatedFields: const [],
      ));

      expect(result.type, PremierEclairageType.liquidityAlert);
      expect(result.colorKey, 'error');
      expect(result.iconName, 'warning_amber');
    });

    test('severe estimated liquidity below one month remains visible', () {
      final result = PremierEclairageSelector.select(profile0(
        liquidityMonths: 0.5,
        currentSavings: 2500,
        estimatedFields: const ['currentSavings'],
      ));

      expect(result.type, PremierEclairageType.liquidityAlert);
      expect(result.subtitle, contains("Moins d'un mois"));
      expect(
        result.confidenceMode,
        PremierEclairageConfidence.pedagogical,
      );
    });

    test('mild estimated liquidity does not raise an alert', () {
      final result = PremierEclairageSelector.select(profile0(
        liquidityMonths: 1.5,
        existing3a: 5000,
        taxSaving3a: 500,
        estimatedFields: const ['currentSavings'],
      ));

      expect(result.type, PremierEclairageType.hourlyRate);
    });

    test('tax-saving insight remains available as a non-AVS alternative', () {
      final result = PremierEclairageSelector.select(profile0(
        existing3a: 0,
        taxSaving3a: 2000,
      ));

      expect(result.type, PremierEclairageType.taxSaving3a);
      expect(result.colorKey, 'success');
      expect(result.value, contains('/an'));
    });

    test('existing 3a falls through to hourly insight for later lifecycle', () {
      final result = PremierEclairageSelector.select(profile0(
        age: 49,
        existing3a: 10000,
        taxSaving3a: 2000,
      ));

      expect(result.type, PremierEclairageType.hourlyRate);
      expect(result.value, contains('/h'));
      expect(result.confidenceMode, PremierEclairageConfidence.factual);
    });

    test('young lifecycle uses compound growth', () {
      final result = PremierEclairageSelector.select(profile0(
        age: 22,
        existing3a: 5000,
        taxSaving3a: 500,
      ));

      expect(result.type, PremierEclairageType.compoundGrowth);
      expect(result.rawValue, isNonZero);
      expect(result.confidenceMode, PremierEclairageConfidence.factual);
    });

    test('zero salary remains finite through compound-growth fallback', () {
      final result = PremierEclairageSelector.select(profile0(
        age: 45,
        grossMonthlySalary: 0,
        grossAnnualSalary: 0,
        existing3a: 5000,
        taxSaving3a: 0,
      ));

      expect(result.type, PremierEclairageType.compoundGrowth);
      expect(result.rawValue.isFinite, isTrue);
    });
  });

  group('PremierEclairageSelector — declared stress', () {
    test('budget stress selects hourly rate', () {
      final result = PremierEclairageSelector.select(
        profile0(age: 25),
        stressType: 'stress_budget',
      );

      expect(result.type, PremierEclairageType.hourlyRate);
    });

    test('tax stress selects 3a saving', () {
      final result = PremierEclairageSelector.select(
        profile0(taxSaving3a: 2000),
        stressType: 'stress_impots',
      );

      expect(result.type, PremierEclairageType.taxSaving3a);
    });

    test('retirement stress selects tax before hourly when available', () {
      final result = PremierEclairageSelector.select(
        profile0(
          age: 49,
          existing3a: 0,
          taxSaving3a: 2000,
          replacementRate: 0.20,
          retirementGapMonthly: 7000,
        ),
        stressType: 'stress_retraite',
      );

      expect(result.type, PremierEclairageType.taxSaving3a);
    });

    test('prevoyance stress selects compound growth for a young profile', () {
      final result = PremierEclairageSelector.select(
        profile0(
          age: 25,
          existing3a: 5000,
          taxSaving3a: 0,
        ),
        stressType: 'stress_prevoyance',
      );

      expect(result.type, PremierEclairageType.compoundGrowth);
    });
  });
}
