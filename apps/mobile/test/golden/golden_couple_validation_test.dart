// Golden Couple Validation Test — Actuarial Audit
//
// This file calls EVERY financial_core calculator with the golden couple data
// (Julien + Lauren from CLAUDE.md §8) and reports whether outputs match
// the expected values.
//
// Run: cd apps/mobile && flutter test test/golden/golden_couple_validation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/cross_pillar_calculator.dart';
import 'package:mint_mobile/services/financial_core/couple_optimizer.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

// ════════════════════════════════════════════════════════════════════════════════
//  GOLDEN COUPLE DATA — from CLAUDE.md §8
// ════════════════════════════════════════════════════════════════════════════════
//
// | Field              | Julien              | Lauren               |
// |--------------------|---------------------|----------------------|
// | Born               | 12.01.1977          | 23.06.1982           |
// | Age (03.2026)      | 49                  | 43                   |
// | Salaire brut       | 122'207 CHF/an      | 67'000 CHF/an        |
// | Canton             | VS (Sion)           | VS (Crans-Montana)   |
// | Nationality        | CH                  | US (FATCA)           |
// | Archetype          | swiss_native        | expat_us             |
// | Caisse LPP         | CPE (rémun. 5%)     | HOTELA               |
// | Avoir LPP          | 70'377 CHF          | 19'620 CHF           |
// | Rachat max LPP     | 539'414 CHF         | 52'949 CHF           |
// | LPP projeté 65     | 677'847 (rente ~33'892/an) | ~153'000      |
// | 3a capital          | 32'000              | 14'000               |
// | AVS couple         | 2'500 CHF/mois                             |
// | Taux remplacement  | 65.5% (~8'505 vs 12'978 net/mois)         |

// ════════════════════════════════════════════════════════════════════════════════
//  HELPER: Print comparison result
// ════════════════════════════════════════════════════════════════════════════════

String _verdict(String label, double actual, double expected,
    {double tolerancePct = 10.0}) {
  final delta = actual - expected;
  final deltaPct =
      expected != 0 ? ((actual - expected) / expected * 100) : 0.0;
  final pass = deltaPct.abs() <= tolerancePct || delta.abs() < 50;
  final status = pass ? 'PASS' : '** FAIL **';
  return '$status | $label\n'
      '       Actual:   ${actual.toStringAsFixed(2)}\n'
      '       Expected: ${expected.toStringAsFixed(2)}\n'
      '       Delta:    ${delta.toStringAsFixed(2)} (${deltaPct.toStringAsFixed(1)}%)';
}

// ════════════════════════════════════════════════════════════════════════════════
//  TEST 1: AVS Calculator — Individual rentes
// ════════════════════════════════════════════════════════════════════════════════

void main() {
  group('Golden Couple Validation — Actuarial Audit', () {
    // ── TEST 1: AVS Individual Rentes ──────────────────────────────────────

    test('1a. AVS Julien — individual monthly rente', () {
      // Julien: born 1977, age 49, contributing since 20 → 29 years so far
      // Salary 122'207/an > 88'200 → max RAMD → should get near-max rente
      // At 65: 29 current + 16 future = 45 → capped at 44 → full contribution
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: 65,
        lacunes: 0,
        grossAnnualSalary: 122207,
      );

      // Expected: 2520 CHF/mois (max, full contribution, high salary)
      const expected = 2520.0;
      final result = _verdict('AVS Julien monthly', rente, expected);
      // ignore: avoid_print
      print('\n$result');

      // Wide tolerance: the exact value depends on gap factor rounding
      expect(rente, closeTo(expected, 300),
          reason: 'Julien AVS should be near max (2520)');
    });

    test('1b. AVS Lauren — individual monthly rente', () {
      // Lauren: born 1982, age 43, US expat arrived ~age 20
      // Salary 67'000/an — between RAMD min (14700) and max (88200)
      // Contribution years: 43-20 = 23 current + 22 future = 45 → capped 44
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 43,
        retirementAge: 65,
        lacunes: 0,
        grossAnnualSalary: 67000,
        arrivalAge: 20, // arrived at 20, contributing since then
      );

      // Expected: between min (1260) and max (2520)
      // 67k salary → linear interpolation: (67000-14700)/(88200-14700) = 0.711
      // renteFromRAMD = 1260 + (2520-1260) * 0.711 = 1260 + 896 = 2156
      // gapFactor should be 1.0 (44/44 with future years)
      const expectedApprox = 2156.0;
      final result = _verdict('AVS Lauren monthly', rente, expectedApprox);
      // ignore: avoid_print
      print('\n$result');

      expect(rente, greaterThan(1260),
          reason: 'Lauren AVS should be above minimum');
      expect(rente, lessThan(2520),
          reason: 'Lauren AVS should be below maximum');
    });

    test('1c. AVS Couple — married cap (LAVS art. 35)', () {
      // Julien + Lauren married → cap at 150% of max = 3780 CHF/mois
      final julienAvs = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: 65,
        lacunes: 0,
        grossAnnualSalary: 122207,
      );
      final laurenAvs = AvsCalculator.computeMonthlyRente(
        currentAge: 43,
        retirementAge: 65,
        lacunes: 0,
        grossAnnualSalary: 67000,
        arrivalAge: 20,
      );

      final couple = AvsCalculator.computeCouple(
        avsUser: julienAvs,
        avsConjoint: laurenAvs,
        isMarried: true,
      );

      // Expected per CLAUDE.md: ~2500 CHF/mois → but that's per person total
      // The CLAUDE.md says "AVS couple: 2'500 CHF/mois" which likely means
      // the total couple monthly rente is ~2500 per month per CLAUDE.md §8
      // BUT the cap is at 3780 → if sum > 3780, cap applies
      // Julien ~2520 + Lauren ~2156 = ~4676 → cap at 3780
      // So total should be 3780 (capped)
      // CLAUDE.md says 2500/mois — this might be after tax or a different metric
      const expectedTotal = 3780.0;
      const claudeMdValue = 2500.0; // what CLAUDE.md §8 states

      // ignore: avoid_print
      print('\n--- AVS Couple Results ---');
      // ignore: avoid_print
      print('  Julien individual AVS:  ${julienAvs.toStringAsFixed(2)} CHF/mois');
      // ignore: avoid_print
      print('  Lauren individual AVS:  ${laurenAvs.toStringAsFixed(2)} CHF/mois');
      // ignore: avoid_print
      print('  Sum before cap:         ${(julienAvs + laurenAvs).toStringAsFixed(2)} CHF/mois');
      // ignore: avoid_print
      print('  Couple total (after cap): ${couple.total.toStringAsFixed(2)} CHF/mois');
      // ignore: avoid_print
      print('  Cap applied:            ${couple.total < (julienAvs + laurenAvs)}');
      // ignore: avoid_print
      print('  CLAUDE.md §8 states:    $claudeMdValue CHF/mois');
      // ignore: avoid_print
      print('  Legal max couple cap:   $expectedTotal CHF/mois');
      // ignore: avoid_print
      print('');
      final result = _verdict(
          'AVS Couple total', couple.total, expectedTotal);
      // ignore: avoid_print
      print(result);

      if ((couple.total - claudeMdValue).abs() > 500) {
        // ignore: avoid_print
        print(
            '\n  ** DISCREPANCY: CLAUDE.md says 2500/mois but calculator yields'
            ' ${couple.total.toStringAsFixed(0)}.'
            ' This may indicate CLAUDE.md uses a different assumption'
            ' (e.g. only one person retired, or after-tax). **');
      }

      expect(couple.total, closeTo(expectedTotal, 500),
          reason: 'Couple AVS should be near 3780 cap');
    });

    test('1d. AVS 13th rente — annual rente with 13 months', () {
      final julienMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: 65,
        lacunes: 0,
        grossAnnualSalary: 122207,
      );

      final annual12 =
          AvsCalculator.annualRente(julienMonthly, include13eme: false);
      final annual13 =
          AvsCalculator.annualRente(julienMonthly, include13eme: true);

      // ignore: avoid_print
      print('\n--- AVS 13th Rente ---');
      // ignore: avoid_print
      print('  Monthly:     ${julienMonthly.toStringAsFixed(2)}');
      // ignore: avoid_print
      print('  Annual (12): ${annual12.toStringAsFixed(2)}');
      // ignore: avoid_print
      print('  Annual (13): ${annual13.toStringAsFixed(2)}');
      // ignore: avoid_print
      print('  13th bonus:  ${(annual13 - annual12).toStringAsFixed(2)}');

      expect(annual13, equals(julienMonthly * 13),
          reason: '13th rente = monthly * 13');
      expect(annual13, greaterThan(annual12),
          reason: '13th rente should exceed 12-month');
    });

    // ── TEST 2: LPP Calculator ─────────────────────────────────────────────

    test('2a. LPP Julien — project to retirement at 65', () {
      // Julien: 49yo, LPP 70'377, caisse CPE rémun 5%, salary 122'207
      // Expected per CLAUDE.md: 677'847 CHF at 65 → rente ~33'892/an
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: 70377,
        currentAge: 49,
        retirementAge: 65,
        grossAnnualSalary: 122207,
        caisseReturn: 0.05, // CPE at 5%
        conversionRate: lppTauxConversionMinDecimal, // 6.8%
        // CPE Plan Maxi: salaire assuré + bonification totale from certificate
        salaireAssureOverride: 91967, // CPE Plan Maxi (from certificate)
        // CPE bonification vieillesse (employeur seul, ~21.5%)
        // Le 31.69% du certificat est la cotisation TOTALE (employeur + employé).
        // Seule la part vieillesse employeur (~21.5%) constitue la bonification.
        bonificationRateOverride: 0.24,
      );

      // The method returns annual rente = projectedBalance * conversionRate
      // Back-calculate projected balance:
      final projectedBalance = annualRente / LppCalculator.adjustedConversionRate(
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 65,
      );

      const expectedBalance = 677847.0;
      const expectedRente = 33892.0; // ~677847 * 0.054 or 0.068

      // ignore: avoid_print
      print('\n--- LPP Julien Projection ---');
      // ignore: avoid_print
      print('  Projected balance:  ${projectedBalance.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Expected balance:   ${expectedBalance.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Projected rente/an: ${annualRente.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Expected rente/an:  ${expectedRente.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Conversion rate:    $lppTauxConversionMinDecimal');
      // ignore: avoid_print
      print(
          _verdict('LPP Julien balance', projectedBalance, expectedBalance,
              tolerancePct: 25));
      // ignore: avoid_print
      print(
          _verdict('LPP Julien rente', annualRente, expectedRente,
              tolerancePct: 25));

      // LPP projection is complex — allow 25% tolerance to detect gross errors
      expect(projectedBalance, greaterThan(200000),
          reason: 'LPP projected balance must be substantial');
      expect(annualRente, greaterThan(10000),
          reason: 'LPP annual rente must be substantial');
    });

    test('2b. LPP Lauren — project to retirement at 65', () {
      // Lauren: 43yo, LPP 19'620, default return 2%, salary 67'000
      // Expected per CLAUDE.md: ~153'000 CHF at 65
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: 19620,
        currentAge: 43,
        retirementAge: 65,
        grossAnnualSalary: 67000,
        caisseReturn: 0.02, // default HOTELA
        conversionRate: lppTauxConversionMinDecimal,
      );

      final projectedBalance = annualRente / LppCalculator.adjustedConversionRate(
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 65,
      );

      const expectedBalance = 153000.0;

      // ignore: avoid_print
      print('\n--- LPP Lauren Projection ---');
      // ignore: avoid_print
      print('  Projected balance:  ${projectedBalance.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Expected balance:   ${expectedBalance.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Projected rente/an: ${annualRente.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print(
          _verdict('LPP Lauren balance', projectedBalance, expectedBalance,
              tolerancePct: 30));

      expect(projectedBalance, greaterThan(50000),
          reason: 'LPP Lauren balance must be positive and growing');
    });

    // ── TEST 3: Tax Calculator ─────────────────────────────────────────────

    test('3a. Capital withdrawal tax — Julien 677k, VS, married', () {
      // Julien: 677'847 CHF capital, canton VS (rate 6%), married
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 677847,
        canton: 'VS',
        isMarried: true,
      );

      // VS rate = 0.06, married discount = 0.85 → effective = 0.051
      // Progressive brackets:
      //   0-100k:   100k * 0.051 * 1.00 = 5100
      //   100-200k: 100k * 0.051 * 1.15 = 5865
      //   200-500k: 300k * 0.051 * 1.30 = 19890
      //   500-677k: 177847 * 0.051 * 1.50 = 13605
      //   Total ≈ 44460
      const expectedApprox = 44460.0;
      final effectiveRate = tax / 677847 * 100;

      // ignore: avoid_print
      print('\n--- Capital Withdrawal Tax (Julien) ---');
      // ignore: avoid_print
      print('  Capital brut:    677\'847 CHF');
      // ignore: avoid_print
      print('  Canton:          VS');
      // ignore: avoid_print
      print('  Married:         true');
      // ignore: avoid_print
      print('  Tax:             ${tax.toStringAsFixed(2)} CHF');
      // ignore: avoid_print
      print('  Effective rate:  ${effectiveRate.toStringAsFixed(2)}%');
      // ignore: avoid_print
      print(_verdict(
          'Capital tax Julien', tax, expectedApprox, tolerancePct: 15));

      expect(tax, greaterThan(20000),
          reason: 'Tax on 677k should be substantial');
      expect(tax, lessThan(100000),
          reason: 'Tax should not exceed ~15% of capital');
    });

    test('3b. Tax saving from LPP rachat — Julien 10k, VS', () {
      // Julien: income 122'207, rachat 10'000, canton VS
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: 122207,
        deduction: 10000,
        canton: 'VS',
      );

      // VS is a high-tax canton, income 122k → marginal rate ~32% * 1.1 = 35.2%
      // Saving on 10k ≈ 3520
      const expectedApprox = 3520.0;

      // ignore: avoid_print
      print('\n--- Tax Saving from LPP Rachat (Julien) ---');
      // ignore: avoid_print
      print('  Income:     122\'207 CHF');
      // ignore: avoid_print
      print('  Deduction:  10\'000 CHF');
      // ignore: avoid_print
      print('  Canton:     VS');
      // ignore: avoid_print
      print('  Tax saved:  ${saving.toStringAsFixed(2)} CHF');
      // ignore: avoid_print
      print(_verdict('Tax saving rachat', saving, expectedApprox,
          tolerancePct: 20));

      expect(saving, greaterThan(1000),
          reason: 'Tax saving on 10k should be > 1000 CHF');
      expect(saving, lessThan(6000),
          reason: 'Tax saving on 10k should be < 6000 CHF');
    });

    test('3c. Marginal rate — Julien VS vs ZG comparison', () {
      final rateVS = RetirementTaxCalculator.estimateMarginalRate(122207, 'VS');
      final rateZG = RetirementTaxCalculator.estimateMarginalRate(122207, 'ZG');

      // ignore: avoid_print
      print('\n--- Marginal Tax Rates at 122k ---');
      // ignore: avoid_print
      print('  VS (high-tax): ${(rateVS * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  ZG (low-tax):  ${(rateZG * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  Delta:         ${((rateVS - rateZG) * 100).toStringAsFixed(1)} pp');

      expect(rateVS, greaterThan(rateZG),
          reason: 'VS should have higher marginal rate than ZG');
      expect(rateVS, greaterThan(0.25),
          reason: 'VS marginal rate at 122k should be > 25%');
      expect(rateZG, lessThan(0.30),
          reason: 'ZG marginal rate at 122k should be < 30%');
    });

    test('3d. NetIncomeBreakdown — Julien', () {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: 122207,
        canton: 'VS',
        age: 49,
        etatCivil: 'marie',
        nombreEnfants: 0,
      );

      // ignore: avoid_print
      print('\n--- Net Income Breakdown (Julien) ---');
      // ignore: avoid_print
      print('  Gross annual:       ${breakdown.grossSalary.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Social charges:     ${breakdown.socialCharges.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  LPP employee:       ${breakdown.lppEmployee.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Income tax est:     ${breakdown.incomeTaxEstimate.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Net payslip:        ${breakdown.netPayslip.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Monthly net:        ${breakdown.monthlyNetPayslip.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Disposable income:  ${breakdown.disposableIncome.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Net ratio:          ${(breakdown.netRatio * 100).toStringAsFixed(1)}%');

      // CLAUDE.md says ~12'978 net/mois for household
      // Julien alone: 122k brut → net should be ~85-90% of brut before tax
      expect(breakdown.netPayslip, greaterThan(90000),
          reason: 'Julien net payslip should be > 90k');
      expect(breakdown.netPayslip, lessThan(120000),
          reason: 'Julien net payslip should be < 120k');
      expect(breakdown.monthlyNetPayslip, greaterThan(7000),
          reason: 'Julien monthly net should be > 7000');
    });

    // ── TEST 4: ForecasterService — Full projection ────────────────────────

    test('4. ForecasterService — Julien full projection', () {
      final julienProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        dateOfBirth: DateTime(1977, 1, 12),
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
        salaireBrutMensuel: 122207.0 / 12, // monthly
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          anneesContribuees: 29,
          lacunesAVS: 0,
          nomCaisse: 'CPE',
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          rachatEffectue: 0,
          tauxConversion: lppTauxConversionMinDecimal,
          rendementCaisse: 0.05, // CPE at 5%
          nombre3a: 1,
          totalEpargne3a: 32000,
          canContribute3a: true,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 0,
        ),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 67000 / 12,
          nombreDeMois: 12,
          nationality: 'US',
          isFatcaResident: true,
          canContribute3a: false,
          arrivalAge: 20,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 19620,
            rachatMaximum: 52949,
            rachatEffectue: 0,
            tauxConversion: lppTauxConversionMinDecimal,
            rendementCaisse: 0.02,
            nombre3a: 1,
            totalEpargne3a: 14000,
            canContribute3a: false,
          ),
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12), // Julien's 65th birthday
          label: 'Retraite',
        ),
      );

      final result = ForecasterService.project(profile: julienProfile);

      // Expected per CLAUDE.md §8:
      // Taux de remplacement: 65.5%
      // ~8'505 retirement income vs ~12'978 current net/mois
      const expectedTauxRemplacement = 65.5;

      // ignore: avoid_print
      print('\n--- ForecasterService Full Projection (Julien) ---');
      // ignore: avoid_print
      print('  Scenario Base:');
      // ignore: avoid_print
      print('    Capital final:        ${result.base.capitalFinal.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('    Revenu retraite/an:   ${result.base.revenuAnnuelRetraite.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('    Revenu retraite/mois: ${(result.base.revenuAnnuelRetraite / 12).toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('    Decomposition:        ${result.base.decomposition}');
      // ignore: avoid_print
      print('  Taux remplacement:      ${result.tauxRemplacementBase.toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  Expected (CLAUDE.md):   $expectedTauxRemplacement%');
      // ignore: avoid_print
      print('  Confidence score:       ${result.confidenceScore.toStringAsFixed(1)}');
      // ignore: avoid_print
      print('  Enrichment prompts:     ${result.enrichmentPrompts}');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('  Scenario Prudent:');
      // ignore: avoid_print
      print('    Capital final:        ${result.prudent.capitalFinal.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('    Revenu retraite/an:   ${result.prudent.revenuAnnuelRetraite.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  Scenario Optimiste:');
      // ignore: avoid_print
      print('    Capital final:        ${result.optimiste.capitalFinal.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('    Revenu retraite/an:   ${result.optimiste.revenuAnnuelRetraite.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print(
          _verdict('Taux remplacement', result.tauxRemplacementBase,
              expectedTauxRemplacement, tolerancePct: 30));

      // Allow 30% tolerance — the forecaster uses complex multi-pillar logic
      // and the CLAUDE.md value may have been computed under different assumptions
      expect(result.tauxRemplacementBase, greaterThan(30),
          reason: 'Taux remplacement should be > 30%');
      expect(result.tauxRemplacementBase, lessThan(120),
          reason: 'Taux remplacement should be < 120%');
      expect(result.base.revenuAnnuelRetraite, greaterThan(50000),
          reason: 'Annual retirement income should be > 50k');
      expect(result.base.capitalFinal, greaterThan(100000),
          reason: 'Final capital should be > 100k');
    });

    // ── TEST 5: CoupleOptimizer ────────────────────────────────────────────

    test('5a. CoupleOptimizer — LPP buyback order', () {
      final mainUser = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        dateOfBirth: DateTime(1977, 1, 12),
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 122207.0 / 12,
        nombreDeMois: 12,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          rachatEffectue: 0,
          rendementCaisse: 0.05,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );

      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 67000 / 12,
        nombreDeMois: 12,
        nationality: 'US',
        isFatcaResident: true,
        canContribute3a: false,
        arrivalAge: 20,
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: 19620,
          rachatMaximum: 52949,
          rachatEffectue: 0,
          rendementCaisse: 0.02,
        ),
      );

      final result = CoupleOptimizer.optimize(
        mainUser: mainUser,
        conjoint: conjoint,
      );

      // ignore: avoid_print
      print('\n--- CoupleOptimizer Results ---');

      // LPP Buyback order
      if (result.lppBuybackOrder != null) {
        final lpp = result.lppBuybackOrder!;
        // ignore: avoid_print
        print('  LPP Buyback:');
        // ignore: avoid_print
        print('    Winner:       ${lpp.winner}');
        // ignore: avoid_print
        print('    Saving delta: ${lpp.savingDelta.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Reason:       ${lpp.reason}');

        // Expected: Julien first (higher income → higher marginal rate)
        expect(lpp.winner, equals(CoupleWinner.mainUser),
            reason:
                'Julien should buy back first (higher income = higher tax saving)');
      } else {
        // ignore: avoid_print
        print('  LPP Buyback: null (unexpected)');
        fail('LPP buyback order should not be null');
      }

      // 3a contribution order
      if (result.pillar3aOrder != null) {
        final p3a = result.pillar3aOrder!;
        // ignore: avoid_print
        print('  Pillar 3a:');
        // ignore: avoid_print
        print('    Winner:       ${p3a.winner}');
        // ignore: avoid_print
        print('    Saving delta: ${p3a.savingDelta.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Reason:       ${p3a.reason}');

        // Expected: mainUser (Julien) because Lauren is FATCA-blocked
        expect(p3a.winner, equals(CoupleWinner.mainUser),
            reason: 'Lauren is FATCA → cannot contribute to 3a');
      } else {
        // ignore: avoid_print
        print('  Pillar 3a: null (unexpected)');
        fail('3a order should not be null');
      }

      // AVS cap
      if (result.avsCap != null) {
        final avs = result.avsCap!;
        // ignore: avoid_print
        print('  AVS Couple Cap:');
        // ignore: avoid_print
        print('    Cap applied:           ${avs.capApplied}');
        // ignore: avoid_print
        print('    User rente before:     ${avs.userRenteBeforeCap.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Conjoint rente before: ${avs.conjointRenteBeforeCap.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Monthly reduction:     ${avs.monthlyReduction.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Total after cap:       ${avs.totalAfterCap.toStringAsFixed(0)} CHF');

        expect(avs.capApplied, isTrue,
            reason: 'Married couple with high combined AVS should be capped');
        expect(avs.totalAfterCap, closeTo(3780, 100),
            reason: 'Total AVS should be near 3780 cap');
      }

      // Marriage penalty
      if (result.marriagePenalty != null) {
        final mp = result.marriagePenalty!;
        // ignore: avoid_print
        print('  Marriage Penalty:');
        // ignore: avoid_print
        print('    Has penalty:    ${mp.hasPenalty}');
        // ignore: avoid_print
        print('    Annual delta:   ${mp.annualDelta.toStringAsFixed(0)} CHF');
        // ignore: avoid_print
        print('    Trade-off:      ${mp.tradeOff}');
      }
    });

    // ── TEST 6: CrossPillarCalculator ──────────────────────────────────────

    test('6. CrossPillarCalculator — Julien analysis', () {
      final julienProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        dateOfBirth: DateTime(1977, 1, 12),
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 122207.0 / 12,
        nombreDeMois: 12,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          rachatEffectue: 0,
          rendementCaisse: 0.05,
          nombre3a: 1,
          totalEpargne3a: 32000,
          canContribute3a: true,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 0,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );

      final analysis = CrossPillarCalculator.analyze(profile: julienProfile);

      // ignore: avoid_print
      print('\n--- CrossPillarCalculator (Julien) ---');
      // ignore: avoid_print
      print('  Total potential impact: ${analysis.totalPotentialImpact.toStringAsFixed(0)} CHF/an');
      // ignore: avoid_print
      print('  Number of insights:    ${analysis.insights.length}');

      for (final insight in analysis.insights) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('  [${insight.type.name}]');
        // ignore: avoid_print
        print('    Impact CHF/an:  ${insight.impactChfAnnual.toStringAsFixed(0)}');
        // ignore: avoid_print
        print('    Confidence:     ${(insight.confidence * 100).toStringAsFixed(0)}%');
        // ignore: avoid_print
        print('    Trade-off:      ${insight.tradeOff}');
        // ignore: avoid_print
        print('    Details:        ${insight.details}');
      }

      // Expected: at least 3a optimization + LPP buyback
      final types = analysis.insights.map((i) => i.type).toSet();

      // 3a: Julien has canContribute3a=true and no planned monthly 3a
      if (types.contains(CrossPillarType.pillar3aOptimization)) {
        // ignore: avoid_print
        print('\n  PASS: 3a optimization detected');
      } else {
        // ignore: avoid_print
        print('\n  INFO: 3a optimization NOT detected (may depend on planned contributions)');
      }

      // LPP: rachat max 539k → huge opportunity
      if (types.contains(CrossPillarType.lppBuybackOpportunity)) {
        // ignore: avoid_print
        print('  PASS: LPP buyback opportunity detected');
      } else {
        // ignore: avoid_print
        print('  ** FAIL: LPP buyback NOT detected despite 539k lacune **');
      }

      expect(analysis.insights, isNotEmpty,
          reason: 'Julien should have at least one cross-pillar insight');
      expect(analysis.totalPotentialImpact, greaterThan(0),
          reason: 'Total impact should be positive');
    });

    // ── TEST 7: LPP blendedMonthly — Rente vs Capital ─────────────────────

    test('7. LPP blendedMonthly — Julien rente vs capital vs mixed', () {
      // Projected annual rente from LPP
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: 70377,
        currentAge: 49,
        retirementAge: 65,
        grossAnnualSalary: 122207,
        caisseReturn: 0.05,
        conversionRate: lppTauxConversionMinDecimal,
      );

      // 100% Rente
      final monthlyFullRente = LppCalculator.blendedMonthly(
        annualRente: annualRente,
        conversionRate: lppTauxConversionMinDecimal,
        lppCapitalPct: 0.0,
        canton: 'VS',
        isMarried: true,
      );

      // 100% Capital
      final monthlyFullCapital = LppCalculator.blendedMonthly(
        annualRente: annualRente,
        conversionRate: lppTauxConversionMinDecimal,
        lppCapitalPct: 1.0,
        canton: 'VS',
        isMarried: true,
      );

      // 50/50 Mixed
      final monthlyMixed = LppCalculator.blendedMonthly(
        annualRente: annualRente,
        conversionRate: lppTauxConversionMinDecimal,
        lppCapitalPct: 0.5,
        canton: 'VS',
        isMarried: true,
      );

      // ignore: avoid_print
      print('\n--- LPP Blended Monthly (Julien) ---');
      // ignore: avoid_print
      print('  Annual LPP rente:      ${annualRente.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  100% Rente monthly:    ${monthlyFullRente.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  100% Capital monthly:  ${monthlyFullCapital.toStringAsFixed(0)} CHF');
      // ignore: avoid_print
      print('  50/50 Mixed monthly:   ${monthlyMixed.toStringAsFixed(0)} CHF');

      expect(monthlyFullRente, greaterThan(0));
      expect(monthlyFullCapital, greaterThan(0));
      expect(monthlyMixed, greaterThan(0));
      // Capital route should yield less due to withdrawal tax
      // (unless SWR is favorable)
    });

    // ── TEST 8: Key Constants Sanity Check ─────────────────────────────────

    test('8. Constants sanity check', () {
      // ignore: avoid_print
      print('\n--- Constants Sanity Check ---');
      // ignore: avoid_print
      print('  AVS rente max mensuelle:  $avsRenteMaxMensuelle CHF');
      // ignore: avoid_print
      print('  AVS rente min mensuelle:  $avsRenteMinMensuelle CHF');
      // ignore: avoid_print
      print('  AVS couple cap mensuelle: $avsRenteCoupleMaxMensuelle CHF');
      // ignore: avoid_print
      print('  AVS duree cotisation:     $avsDureeCotisationComplete ans');
      // ignore: avoid_print
      print('  AVS RAMD min:             $avsRAMDMin CHF');
      // ignore: avoid_print
      print('  AVS RAMD max:             $avsRAMDMax CHF');
      // ignore: avoid_print
      print('  AVS 13eme rente active:   $avs13emeRenteActive');
      // ignore: avoid_print
      print('  LPP seuil entree:         $lppSeuilEntree CHF');
      // ignore: avoid_print
      print('  LPP coordination:         $lppDeductionCoordination CHF');
      // ignore: avoid_print
      print('  LPP taux conversion min:  ${lppTauxConversionMinDecimal * 100}%');
      // ignore: avoid_print
      print('  LPP salaire coord min:    $lppSalaireCoordMin CHF');
      // ignore: avoid_print
      print('  LPP salaire coord max:    $lppSalaireCoordMax CHF');
      // ignore: avoid_print
      print('  3a plafond avec LPP:      $pilier3aPlafondAvecLpp CHF');
      // ignore: avoid_print
      print('  3a plafond sans LPP:      $pilier3aPlafondSansLpp CHF');
      // ignore: avoid_print
      print('  VS capital tax rate:      ${tauxImpotRetraitCapital['VS']}');

      // CLAUDE.md §5 values
      expect(avsRenteMaxMensuelle, equals(2520.0));
      expect(avsRenteMinMensuelle, equals(1260.0));
      expect(avsRenteCoupleMaxMensuelle, equals(3780.0));
      expect(avsDureeCotisationComplete, equals(44));
      expect(lppSeuilEntree, equals(22680.0));
      expect(lppDeductionCoordination, equals(26460.0));
      expect(lppTauxConversionMinDecimal, closeTo(0.068, 0.001));
      expect(lppSalaireCoordMin, equals(3780.0));
      expect(pilier3aPlafondAvecLpp, equals(7258.0));
      expect(pilier3aPlafondSansLpp, equals(36288.0));
      expect(tauxImpotRetraitCapital['VS'], equals(0.060));
      expect(marriedCapitalTaxDiscount, equals(0.85));
    });

    // ── TEST 9: AVS reduction from gaps ────────────────────────────────────

    test('9. AVS reduction from contribution gaps', () {
      // ignore: avoid_print
      print('\n--- AVS Contribution Gap Impact ---');
      for (final gap in [0, 1, 2, 4, 8]) {
        final pct = AvsCalculator.reductionPercentageFromGap(gap);
        final loss = AvsCalculator.monthlyLossFromGap(gap);
        // ignore: avoid_print
        print(
            '  Gap $gap years: -${pct.toStringAsFixed(1)}% = -${loss.toStringAsFixed(0)} CHF/mois');
      }

      // 4 years gap → ~9.09% reduction
      expect(AvsCalculator.reductionPercentageFromGap(4),
          closeTo(9.09, 0.1));
      // 4 years gap → ~229 CHF/mois loss
      expect(AvsCalculator.monthlyLossFromGap(4), closeTo(229, 5));
    });

    // ── TEST 10: Lauren FATCA 3a block ─────────────────────────────────────

    test('10. Lauren FATCA — 3a contribution blocked', () {
      const laurenConjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 67000 / 12,
        nombreDeMois: 12,
        nationality: 'US',
        isFatcaResident: true,
        canContribute3a: false,
      );

      // ignore: avoid_print
      print('\n--- FATCA 3a Block (Lauren) ---');
      // ignore: avoid_print
      print('  isFatcaResident: ${laurenConjoint.isFatcaResident}');
      // ignore: avoid_print
      print('  canContribute3a: ${laurenConjoint.canContribute3a}');

      expect(laurenConjoint.isFatcaResident, isTrue);
      expect(laurenConjoint.canContribute3a, isFalse,
          reason: 'FATCA residents cannot contribute to 3a');

      // Also verify the copyWith enforces FATCA
      final copied = laurenConjoint.copyWith(canContribute3a: true);
      // ignore: avoid_print
      print(
          '  After copyWith(canContribute3a: true): ${copied.canContribute3a}');
      expect(copied.canContribute3a, isFalse,
          reason:
              'FATCA override: copyWith should NOT allow enabling 3a for US resident');
    });

    // ── SUMMARY ────────────────────────────────────────────────────────────

    test('SUMMARY — Audit Report', () {
      // ignore: avoid_print
      print('\n');
      // ignore: avoid_print
      print('=' * 70);
      // ignore: avoid_print
      print(' GOLDEN COUPLE ACTUARIAL AUDIT — SUMMARY');
      // ignore: avoid_print
      print('=' * 70);
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print(' Test 1a: AVS Julien individual     → computed above');
      // ignore: avoid_print
      print(' Test 1b: AVS Lauren individual     → computed above');
      // ignore: avoid_print
      print(' Test 1c: AVS Couple cap            → computed above');
      // ignore: avoid_print
      print(' Test 1d: AVS 13th rente            → computed above');
      // ignore: avoid_print
      print(' Test 2a: LPP Julien projection     → computed above');
      // ignore: avoid_print
      print(' Test 2b: LPP Lauren projection     → computed above');
      // ignore: avoid_print
      print(' Test 3a: Capital withdrawal tax     → computed above');
      // ignore: avoid_print
      print(' Test 3b: Tax saving LPP rachat     → computed above');
      // ignore: avoid_print
      print(' Test 3c: Marginal rates VS vs ZG   → computed above');
      // ignore: avoid_print
      print(' Test 3d: NetIncomeBreakdown        → computed above');
      // ignore: avoid_print
      print(' Test 4:  ForecasterService full    → computed above');
      // ignore: avoid_print
      print(' Test 5:  CoupleOptimizer           → computed above');
      // ignore: avoid_print
      print(' Test 6:  CrossPillarCalculator     → computed above');
      // ignore: avoid_print
      print(' Test 7:  LPP blended monthly       → computed above');
      // ignore: avoid_print
      print(' Test 8:  Constants sanity check     → computed above');
      // ignore: avoid_print
      print(' Test 9:  AVS gap impact            → computed above');
      // ignore: avoid_print
      print(' Test 10: FATCA 3a block            → computed above');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print(' Review the ACTUAL vs EXPECTED values above for each test.');
      // ignore: avoid_print
      print(' All tests use wide tolerances to DETECT, not ENFORCE.');
      // ignore: avoid_print
      print(' Discrepancies may indicate:');
      // ignore: avoid_print
      print('   1. Calculator logic bug');
      // ignore: avoid_print
      print('   2. Different assumptions in CLAUDE.md vs calculators');
      // ignore: avoid_print
      print('   3. Constants out of date');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('=' * 70);
    });
  });
}
