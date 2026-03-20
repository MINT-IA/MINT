import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';

/// Tests for ChiffreChocSelector (Sprint S31).
///
/// Validates metric selection priority, archetype-specific alerts,
/// edge cases, and compliance with no-advice / no-promise rules.
void main() {
  /// Helper to build a MinimalProfileResult with sensible defaults.
  MinimalProfileResult profile0({
    double avsMonthlyRente = 1900,
    double lppAnnualRente = 24000,
    double lppMonthlyRente = 2000,
    double totalMonthlyRetirement = 3900,
    double grossMonthlySalary = 8333,
    double replacementRate = 0.47,
    double retirementGapMonthly = 4433,
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

  group('ChiffreChocSelector', () {
    // ── Priority 0: Archetype-specific alerts ────────────────

    test('independent without LPP triggers archetype alert (highest priority)',
        () {
      final profile = profile0(
        employmentStatus: 'independant',
        lppMonthlyRente: 0,
        grossMonthlySalary: 8000,
        retirementGapMonthly: 6000,
        liquidityMonths: 0.5, // Would normally trigger liquidity alert
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementGap);
      expect(result.title, contains('Sans 2e pilier'));
      expect(result.colorKey, 'error');
    });

    test('non-Swiss expat with low AVS triggers archetype alert', () {
      final profile = profile0(
        nationalityGroup: 'EU',
        avsMonthlyRente: 1200,
        liquidityMonths: 6, // No liquidity issue
        replacementRate: 0.65, // No retirement gap
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementGap);
      expect(result.subtitle, contains('bilateraux'));
      expect(result.colorKey, 'warning');
    });

    test('non-EU expat with low AVS gets different message than EU expat', () {
      final profile = profile0(
        nationalityGroup: 'OTHER',
        avsMonthlyRente: 1000,
        liquidityMonths: 6,
        replacementRate: 0.65,
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.subtitle, contains('releve CI'));
      expect(result.subtitle, isNot(contains('bilateraux')));
    });

    // ── Priority 1: Liquidity alert ──────────────────────────

    test('liquidity < 2 months triggers liquidity alert', () {
      final profile = profile0(
        liquidityMonths: 1.5,
        currentSavings: 7500,
        nationalityGroup: 'CH', // No archetype override
        replacementRate: 0.65, // No retirement gap
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.liquidityAlert);
      expect(result.colorKey, 'error');
      expect(result.iconName, 'warning_amber');
    });

    test('liquidity < 1 month gets specific wording', () {
      final profile = profile0(
        liquidityMonths: 0.5,
        currentSavings: 2500,
        nationalityGroup: 'CH',
        replacementRate: 0.65,
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.subtitle, contains("Moins d'un mois"));
    });

    // ── Priority 2: Retirement gap ───────────────────────────

    test('replacement rate < 55% triggers retirement gap', () {
      final profile = profile0(
        replacementRate: 0.45,
        grossMonthlySalary: 10000,
        liquidityMonths: 6, // No liquidity issue
        nationalityGroup: 'CH',
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementGap);
      expect(result.colorKey, 'warning');
      expect(result.value, contains('/mois'));
    });

    test('independant with retirement gap gets specific 3a message', () {
      final profile = profile0(
        employmentStatus: 'independant',
        lppMonthlyRente: 500, // Has some LPP (so archetype alert skipped)
        replacementRate: 0.40,
        grossMonthlySalary: 10000,
        liquidityMonths: 6,
        nationalityGroup: 'CH',
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementGap);
      expect(result.subtitle, contains('3e pilier'));
    });

    // ── Priority 3: Tax saving 3a ────────────────────────────

    test('no existing 3a and saving > 1500 triggers tax saving', () {
      final profile = profile0(
        existing3a: 0,
        taxSaving3a: 2000,
        replacementRate: 0.60, // No retirement gap
        liquidityMonths: 6,
        nationalityGroup: 'CH',
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.taxSaving3a);
      expect(result.colorKey, 'success');
      expect(result.value, contains('/an'));
    });

    test('existing 3a > 0 skips tax saving, falls to retirement income', () {
      final profile = profile0(
        existing3a: 10000,
        taxSaving3a: 2000,
        replacementRate: 0.60,
        liquidityMonths: 6,
        nationalityGroup: 'CH',
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementIncome);
    });

    // ── Fallback: Retirement income ──────────────────────────

    test('fallback returns retirement income with replacement percentage', () {
      final profile = profile0(
        existing3a: 5000,
        taxSaving3a: 500, // Below threshold
        replacementRate: 0.60,
        liquidityMonths: 6,
        nationalityGroup: 'CH',
        totalMonthlyRetirement: 5000,
        grossMonthlySalary: 8333,
      );

      final result = ChiffreChocSelector.select(profile);

      expect(result.type, ChiffreChocType.retirementIncome);
      expect(result.colorKey, 'info');
      expect(result.subtitle, contains('60%'));
      expect(result.value, contains('/mois'));
    });

    // ── CHF formatting ───────────────────────────────────────

    test('CHF formatting uses Swiss apostrophe for thousands', () {
      final profile = profile0(
        replacementRate: 0.40,
        retirementGapMonthly: 4280,
        grossMonthlySalary: 10000,
        liquidityMonths: 6,
        nationalityGroup: 'CH',
      );

      final result = ChiffreChocSelector.select(profile);

      // 4280 formatted with apostrophe = CHF\u00A04'280
      expect(result.value, contains("4'280"));
    });

    // ── Edge cases ───────────────────────────────────────────

    test('zero salary returns fallback retirement income', () {
      final profile = profile0(
        grossMonthlySalary: 0,
        replacementRate: 0, // 0/0 edge
        liquidityMonths: 6,
        nationalityGroup: 'CH',
        existing3a: 5000,
        taxSaving3a: 0,
      );

      final result = ChiffreChocSelector.select(profile);

      // Should not crash; returns fallback
      expect(result.type, ChiffreChocType.retirementIncome);
    });

    test('Swiss national with AVS >= 1500 skips archetype alert', () {
      final profile = profile0(
        nationalityGroup: 'CH',
        avsMonthlyRente: 2000,
        replacementRate: 0.60,
        liquidityMonths: 6,
        existing3a: 5000,
        taxSaving3a: 500,
      );

      final result = ChiffreChocSelector.select(profile);

      // No archetype alert for Swiss with adequate AVS
      expect(result.type, ChiffreChocType.retirementIncome);
    });
  });
}
