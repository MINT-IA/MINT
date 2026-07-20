import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/first_job_service.dart';

void main() {
  group('canonical First Job presentation model', () {
    test('uses statutory AVS and AC illustrations', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.avsAiApg, closeTo(318, .1));
      expect(result.ac, closeTo(66, .1));
      expect(result.totalKnownDeductionsIllustration, closeTo(384, .1));
    });

    test('never converts an age credit into an employee LPP deduction', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.lppAgeCreditIllustration, closeTo(265.65, .5));
      expect(result.lppEmploye, isNull);
      expect(result.netEstime, isNull);
      expect(
        result.deductionItems.map((item) => item.kind),
        [
          SalaryDeductionKind.avsAiApg,
          SalaryDeductionKind.unemploymentInsurance,
        ],
      );
    });

    test('does not imply a retirement age credit before 25', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 24,
        canton: 'ZH',
      );

      expect(result.lppAgeCreditIllustration, isNull);
      expect(result.lppEmploye, isNull);
    });

    test('delegates Swiss currency formatting to the canonical formatter', () {
      expect(FirstJobService.formatChf(1641000), "CHF\u00a01'641'000");
    });
  });
}
