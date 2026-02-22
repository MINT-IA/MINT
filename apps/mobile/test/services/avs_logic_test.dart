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

      // Note: FinancialReportService._estimateAvsRent is private,
      // but we can test it through buildRetirementProjection or
      // by making a test-only subclass if needed.
      // For now, let's assume we can generate a report and check the projection.

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
      final expectedRent = 2520 * (40 / 44); // 30'240/12 = 2520 CHF/mois (LAVS)

      expect(report.retirementProjection?.monthlyAvsRent,
          closeTo(expectedRent, 0.1));
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

      // Couple max = 3780 (1890 each)
      // Part 1: 1890 * (40/44)
      // Part 2: 1890 * (42/44)
      final expectedRent = (1890.0 * 40 / 44) + (1890.0 * 42 / 44);

      expect(report.retirementProjection?.monthlyAvsRent,
          closeTo(expectedRent, 0.1));
    });
  });
}
