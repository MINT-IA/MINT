import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

void main() {
  group('AVS Logic Tests', () {
    test('UserProfile avsReductionFactor calculation', () {
      // 44 years = 1.0
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 44,
        ).avsReductionFactor,
        1.0,
      );

      // 40 years = 40/44
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 40,
        ).avsReductionFactor,
        40 / 44,
      );

      // 22 years = 0.5
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 22,
        ).avsReductionFactor,
        0.5,
      );

      // Null years = 1.0 (default)
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: null,
        ).avsReductionFactor,
        1.0,
      );
    });

    test('FinancialReportService._estimateAvsRent with gaps', () {
      final service = FinancialReportService();

      // The report uses AvsCalculator.computeMonthlyRente which takes into
      // account income-based rente (RAMD) and future contribution years.

      final answersSingleGap = {
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 5000,
        'q_avs_lacunes_status': 'yes',
        'q_avs_contribution_years': 40,
        'q_current_lpp_capital': 100000,
      };

      final report = service.generateReport(answersSingleGap);
      // grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(60000)
      //   uses Newton-Raphson iteration (not the old / 0.87 linear approx)
      //   → ~68299 CHF (slightly lower than old 68965.5)
      // renteFromRAMD(~68299) = ~2176 (linear interpolation)
      // With anneesContribuees=40 + futureYears=19 = 44 total => gapFactor=1.0
      // So rente = ~2176

      expect(report.retirementProjection?.monthlyAvsRent,
          closeTo(2176.0, 1.0));
    });

    test('Married AVS Rent calculation with spouse gaps', () {
      final service = FinancialReportService();

      final answersMarriedGaps = {
        'q_birth_year': 1980,
        'q_canton': 'ZH',
        'q_civil_status': 'married',
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 8000,
        'q_avs_lacunes_status': 'yes',
        'q_avs_contribution_years': 40,
        'q_spouse_avs_contribution_years': 42,
        'q_current_lpp_capital': 150000,
      };

      final report = service.generateReport(answersMarriedGaps);

      // grossAnnualSalary = 8000 * 12 / 0.87 = ~110344.8 (> RAMD max 88200)
      // Both user and spouse get max rente = 2520 CHF/mois
      // With future years: user 40+19=44, spouse 42+19=44 => gapFactor=1.0 for both
      // userRente = 2520, spouseRente = 2520, total = 5040
      // Married cap (LAVS art. 35): 150% of 2520 = 3780
      // Total capped to 3780
      expect(report.retirementProjection?.monthlyAvsRent,
          closeTo(3780.0, 1.0));
    });
  });
}
