import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/first_job_salary_financial_facts.dart';

void main() {
  group('FirstJobSalaryFinancialFactsCalculator', () {
    test('applies the registered AC solidarity rate above the ceiling', () {
      final facts = FirstJobSalaryFinancialFactsCalculator.calculate(
        grossMonthlySalary: 13000,
        age: 30,
      );

      expect(facts.avsAiApg, closeTo(689, .01));
      expect(facts.ac, closeTo(139.10, .01));
    });

    test('keeps the LPP age credit separate across statutory age bands', () {
      final age30 = FirstJobSalaryFinancialFactsCalculator.calculate(
        grossMonthlySalary: 6000,
        age: 30,
      );
      final age45 = FirstJobSalaryFinancialFactsCalculator.calculate(
        grossMonthlySalary: 6000,
        age: 45,
      );

      expect(age30.lppAgeCreditIllustration, closeTo(265.65, .01));
      expect(age45.lppAgeCreditIllustration, closeTo(569.25, .01));
    });
  });
}
