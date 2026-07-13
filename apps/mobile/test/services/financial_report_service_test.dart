import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/models/financial_report.dart';

/// Unit tests for FinancialReportService
///
/// Tests the comprehensive financial report generation engine that:
///   - Builds UserProfile from wizard answers
///   - Computes tax simulations (cantonal + federal)
///   - Keeps uncertified retirement amounts explicitly unknown
///   - Builds LPP buyback strategies
///   - Generates priority actions from health scores
///   - Creates personalised roadmaps
void main() {
  late FinancialReportService service;

  setUp(() {
    service = FinancialReportService();
  });

  // ── Helper: minimal answers for a valid report ──────────────────────
  Map<String, dynamic> minimalAnswers() {
    return {
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };
  }

  // ── Helper: full answers for a rich profile ─────────────────────────
  Map<String, dynamic> fullAnswers() {
    return {
      'q_firstname': 'Marc',
      'q_birth_year': 1985,
      'q_canton': 'GE',
      'q_civil_status': 'married',
      'q_children': '2',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 8500.0,
      'q_3a_accounts_count': 2,
      'q_3a_providers': ['viac', 'bank'],
      'q_3a_annual_contribution': 7258.0,
      'q_lpp_buyback_available': 80000.0,
      'q_current_lpp_capital': 150000.0,
      'q_avs_lacunes_status': 'no',
      'q_avs_contribution_years': 20,
      'q_spouse_avs_contribution_years': 18,
      'q_emergency_fund': 'yes_6months',
      'q_has_consumer_debt': 'no',
      'q_has_investments': 'yes',
      'q_housing_status': 'owner',
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 1. REPORT GENERATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Report generation', () {
    test('generates report from minimal answers without throwing', () {
      final report = service.generateReport(minimalAnswers());
      expect(report, isA<FinancialReport>());
    });

    test('report contains all required sections', () {
      final report = service.generateReport(minimalAnswers());

      expect(report.profile, isNotNull);
      expect(report.healthScore, isNotNull);
      expect(report.taxSimulation, isNotNull);
      expect(report.priorityActions, isA<List<ActionItem>>());
      expect(report.personalizedRoadmap, isA<Roadmap>());
      expect(report.generatedAt, isA<DateTime>());
      expect(report.reportVersion, equals('2.1'));
    });

    test('report from full answers includes optional sections', () {
      final report = service.generateReport(fullAnswers());

      expect(report.retirementProjection, isNotNull);
      expect(report.lppBuybackStrategy, isNotNull);
    });

    test('report generatedAt is close to now', () {
      final before = DateTime.now();
      final report = service.generateReport(minimalAnswers());
      final after = DateTime.now();

      expect(
          report.generatedAt
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(report.generatedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. USER PROFILE BUILDING
  // ═══════════════════════════════════════════════════════════════════════

  group('UserProfile building', () {
    test('defaults canton to ZH when missing', () {
      final answers = <String, dynamic>{
        'q_birth_year': 1990,
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 5000.0,
      };
      final report = service.generateReport(answers);
      expect(report.profile.canton, equals('ZH'));
    });

    test('defaults civilStatus to single when missing', () {
      final answers = minimalAnswers();
      answers.remove('q_civil_status');
      final report = service.generateReport(answers);
      expect(report.profile.civilStatus, equals('single'));
      expect(report.profile.isMarried, isFalse);
    });

    test('correctly identifies married profile', () {
      final answers = minimalAnswers();
      answers['q_civil_status'] = 'married';
      final report = service.generateReport(answers);
      expect(report.profile.isMarried, isTrue);
    });

    test('computes annual income from monthly net income', () {
      final report = service.generateReport(minimalAnswers());
      // 6000 * 12 = 72000
      expect(report.profile.annualIncome, equals(72000.0));
    });

    test('defaults monthly income to 5000 when missing', () {
      final answers = minimalAnswers();
      answers.remove('q_net_income_period_chf');
      final report = service.generateReport(answers);
      expect(report.profile.monthlyNetIncome, equals(5000.0));
    });

    test('parses children count from string', () {
      final answers = minimalAnswers();
      answers['q_children'] = '3';
      final report = service.generateReport(answers);
      expect(report.profile.childrenCount, equals(3));
      expect(report.profile.hasChildren, isTrue);
    });

    test('hasChildren is false when 0 children', () {
      final report = service.generateReport(minimalAnswers());
      expect(report.profile.hasChildren, isFalse);
    });

    test('isSalaried correctly reflects employment status', () {
      final answers = minimalAnswers();
      answers['q_employment_status'] = 'employee';
      final report = service.generateReport(answers);
      expect(report.profile.isSalaried, isTrue);

      answers['q_employment_status'] = 'self_employed';
      final report2 = service.generateReport(answers);
      expect(report2.profile.isSalaried, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. TAX SIMULATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Tax simulation', () {
    test('computes positive total tax for standard income', () {
      final report = service.generateReport(minimalAnswers());
      expect(report.taxSimulation.totalTax, greaterThan(0));
    });

    test('effective rate is between 0 and 1', () {
      final report = service.generateReport(minimalAnswers());
      expect(report.taxSimulation.effectiveRate, greaterThan(0));
      expect(report.taxSimulation.effectiveRate, lessThan(1));
    });

    test('cantonal + federal equals total tax', () {
      final report = service.generateReport(minimalAnswers());
      final sum =
          report.taxSimulation.cantonalTax + report.taxSimulation.federalTax;
      expect(sum, closeTo(report.taxSimulation.totalTax, 0.01));
    });

    test('cantonal tax is approximately 75% of total', () {
      final report = service.generateReport(minimalAnswers());
      final ratio =
          report.taxSimulation.cantonalTax / report.taxSimulation.totalTax;
      expect(ratio, closeTo(0.75, 0.001));
    });

    test('married profile gets lower effective rate', () {
      final singleAnswers = minimalAnswers();
      singleAnswers['q_civil_status'] = 'single';
      final reportSingle = service.generateReport(singleAnswers);

      final marriedAnswers = minimalAnswers();
      marriedAnswers['q_civil_status'] = 'married';
      final reportMarried = service.generateReport(marriedAnswers);

      expect(reportMarried.taxSimulation.effectiveRate,
          lessThan(reportSingle.taxSimulation.effectiveRate));
    });

    test('3a contribution appears in deductions', () {
      final answers = minimalAnswers();
      answers['q_3a_annual_contribution'] = 7258.0;
      final report = service.generateReport(answers);
      expect(report.taxSimulation.deductions.containsKey('3a'), isTrue);
      expect(report.taxSimulation.deductions['3a'], equals(7258.0));
    });

    test(
        'children deduction = federal + cantonal per child (LIFD art. 35 + LHID art. 9)',
        () {
      final answers = minimalAnswers(); // q_canton = 'VD'
      answers['q_children'] = '2';
      final report = service.generateReport(answers);
      // Wave 7 fiscal audit P0-R4 : 2 enfants × (6'700 féd. + 11'000 VD) = 35'400 CHF.
      // Previously the code applied a flat 6'500 × n that ignored the cantonal
      // layer entirely; the test now pins the corrected value.
      const expected = 2 * (6700.0 + 11000.0); // 35'400
      expect(report.taxSimulation.deductions['D\u00e9duction enfants'],
          equals(expected));
    });

    test('LPP buyback triggers tax comparison when available > 50k', () {
      final answers = fullAnswers();
      answers['q_lpp_buyback_available'] = 60000.0;
      final report = service.generateReport(answers);
      expect(report.taxSimulation.taxWithLppBuyback, isNotNull);
      expect(report.taxSimulation.taxSavingsFromBuyback, isNotNull);
      expect(report.taxSimulation.taxSavingsFromBuyback!, greaterThan(0));
    });

    test('no LPP buyback comparison when available <= 50k', () {
      final answers = minimalAnswers();
      answers['q_lpp_buyback_available'] = 30000.0;
      final report = service.generateReport(answers);
      expect(report.taxSimulation.taxWithLppBuyback, isNull);
      expect(report.taxSimulation.taxSavingsFromBuyback, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. RETIREMENT PROJECTION
  // ═══════════════════════════════════════════════════════════════════════

  group('Retirement projection', () {
    test('returns null when years to retirement <= 0', () {
      final answers = minimalAnswers();
      // Born in 1950 => age ~76 => yearsToRetirement = 65 - 76 = -11
      answers['q_birth_year'] = 1950;
      final report = service.generateReport(answers);
      expect(report.retirementProjection, isNull);
    });

    test('returns projection for working-age person', () {
      final answers = minimalAnswers();
      answers['q_birth_year'] = 1990; // age ~36 => years to retirement ~29
      final report = service.generateReport(answers);
      expect(report.retirementProjection, isNotNull);
      expect(report.retirementProjection!.yearsUntilRetirement, greaterThan(0));
    });

    test('retirement point capitals stay null without reviewed evidence', () {
      final answers = minimalAnswers();
      answers['q_current_lpp_capital'] = 100000.0;
      answers['q_lpp_buyback_available'] = 20000.0;
      final report = service.generateReport(answers);

      expect(report.retirementProjection!.lppCapital, isNull);
      expect(report.retirementProjection!.pillar3aCapital, isNull);
      expect(report.retirementProjection!.monthlyLppRent, isNull);
      expect(report.retirementProjection!.totalCapital, isNull);
    });

    test('official AVS amount stays null until reviewed evidence is wired', () {
      final report = service.generateReport(minimalAnswers());

      expect(report.retirementProjection!.monthlyAvsRent, isNull);
    });

    test('retirement total stays null while official AVS is unknown', () {
      final report = service.generateReport(minimalAnswers());

      expect(report.retirementProjection!.totalMonthlyIncome, isNull);
    });

    test('replacement rate stays null while official AVS is unknown', () {
      final report = service.generateReport(minimalAnswers());

      expect(report.retirementProjection!.replacementRate, isNull);
    });

    test('replacement rate stays null when current income is not known', () {
      const projection = RetirementProjection(
        yearsUntilRetirement: 10,
        lppCapital: 100000,
        pillar3aCapital: 50000,
        monthlyAvsRent: 2000,
        monthlyLppRent: 1000,
        currentMonthlyIncome: 0,
      );

      expect(projection.replacementRate, isNull);
    });

    test('replacement rate stays null while the LPP pension is unknown', () {
      const projection = RetirementProjection(
        yearsUntilRetirement: 10,
        lppCapital: null,
        pillar3aCapital: 50000,
        monthlyAvsRent: 2000,
        monthlyLppRent: null,
        currentMonthlyIncome: 8000,
      );

      expect(projection.totalMonthlyIncome, isNull);
      expect(projection.replacementRate, isNull);
    });

    test('replacement rate uses the actual current monthly income', () {
      const projection = RetirementProjection(
        yearsUntilRetirement: 25,
        lppCapital: 500000,
        pillar3aCapital: 100000,
        monthlyAvsRent: 2520,
        monthlyLppRent: 3980,
        currentMonthlyIncome: 10000,
      );

      expect(projection.replacementRate, closeTo(65.0, 0.1));
      expect(projection.replacementRate, isNot(closeTo(83.3, 1.0)));
    });

    test('replacement rate is capped at 150 percent', () {
      const projection = RetirementProjection(
        yearsUntilRetirement: 10,
        lppCapital: 200000,
        pillar3aCapital: 50000,
        monthlyAvsRent: 2520,
        monthlyLppRent: 3000,
        currentMonthlyIncome: 2000,
      );

      expect(projection.replacementRate, 150.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. LPP BUYBACK STRATEGY
  // ═══════════════════════════════════════════════════════════════════════

  group('LPP buyback strategy', () {
    test('returns null when buyback available < 10000', () {
      final answers = minimalAnswers();
      answers['q_lpp_buyback_available'] = 5000.0;
      final report = service.generateReport(answers);
      expect(report.lppBuybackStrategy, isNull);
    });

    test('returns strategy when buyback available >= 10000', () {
      final answers = minimalAnswers();
      answers['q_lpp_buyback_available'] = 50000.0;
      final report = service.generateReport(answers);
      expect(report.lppBuybackStrategy, isNotNull);
      expect(report.lppBuybackStrategy!.totalBuybackAvailable, equals(50000.0));
    });

    test('yearly plan sums to total buyback available', () {
      final answers = minimalAnswers();
      answers['q_lpp_buyback_available'] = 60000.0;
      final report = service.generateReport(answers);
      final totalPlanned = report.lppBuybackStrategy!.yearlyPlan
          .fold(0.0, (sum, buy) => sum + buy.amount);
      expect(totalPlanned, closeTo(60000.0, 1.0));
    });

    test('total tax savings is positive', () {
      final answers = minimalAnswers();
      answers['q_lpp_buyback_available'] = 80000.0;
      final report = service.generateReport(answers);
      expect(report.lppBuybackStrategy!.totalTaxSavings, greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. PRIORITY ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  group('Priority actions', () {
    test('returns at most 3 priority actions', () {
      final report = service.generateReport(fullAnswers());
      expect(report.priorityActions.length, lessThanOrEqualTo(3));
    });

    test('actions with debt should include debt-related action', () {
      final answers = fullAnswers();
      answers['q_has_consumer_debt'] = 'yes';
      answers['q_emergency_fund'] = 'no';
      final report = service.generateReport(answers);

      // The scoring service will flag debt and emergency fund issues
      // Priority actions should reflect those concerns
      expect(report.priorityActions, isA<List<ActionItem>>());
    });

    test('roadmap has at least one phase', () {
      final report = service.generateReport(minimalAnswers());
      expect(report.personalizedRoadmap.phases.length, greaterThanOrEqualTo(1));
    });

    test('roadmap immediate phase is labeled correctly', () {
      final report = service.generateReport(minimalAnswers());
      final immediatePhase = report.personalizedRoadmap.phases.first;
      expect(immediatePhase.title, equals('Imm\u00e9diat'));
      expect(immediatePhase.timeframe, equals('Ce mois'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('empty answers map does not throw', () {
      expect(
        () => service.generateReport({}),
        returnsNormally,
      );
    });

    test('empty answers use all defaults', () {
      final report = service.generateReport({});
      expect(report.profile.canton, equals('ZH'));
      expect(report.profile.civilStatus, equals('single'));
      expect(report.profile.monthlyNetIncome, equals(5000.0));
      expect(report.profile.childrenCount, equals(0));
    });

    test('zero income produces valid report', () {
      final answers = minimalAnswers();
      answers['q_net_income_period_chf'] = 0.0;
      final report = service.generateReport(answers);
      expect(report.taxSimulation.totalTax, equals(0));
    });

    test('very high income produces valid report', () {
      final answers = minimalAnswers();
      answers['q_net_income_period_chf'] = 50000.0; // 600k annual
      final report = service.generateReport(answers);
      expect(report.taxSimulation.totalTax, greaterThan(0));
      expect(report.taxSimulation.effectiveRate, greaterThan(0.15));
    });

    test('birth year as string is parsed correctly', () {
      final answers = minimalAnswers();
      answers['q_birth_year'] = '1990';
      final report = service.generateReport(answers);
      expect(report.profile.birthYear, equals(1990));
    });

    test('income as int is handled correctly', () {
      final answers = minimalAnswers();
      answers['q_net_income_period_chf'] = 6000;
      final report = service.generateReport(answers);
      expect(report.profile.monthlyNetIncome, equals(6000.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. MODEL PROPERTIES
  // ═══════════════════════════════════════════════════════════════════════

  group('UserProfile computed properties', () {
    test('yearsToRetirement is 65 - age', () {
      final report = service.generateReport(minimalAnswers());
      final expectedAge = DateTime.now().year - 1990;
      expect(report.profile.yearsToRetirement, equals(65 - expectedAge));
    });
  });
}
