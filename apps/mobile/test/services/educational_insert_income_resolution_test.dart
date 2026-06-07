import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/educational_insert_service.dart';
import 'package:mint_mobile/widgets/educational/tax_savings_insert_widget.dart';

void main() {
  group('EducationalInsertService 3a income resolution', () {
    test('normalizes padded annual pay frequency before 3a simulation', () {
      final widget = EducationalInsertService.getInsertWidget(
        questionId: 'q_has_3a',
        answers: {
          'q_net_income_period_chf': 96000.0,
          'q_pay_frequency': ' annual ',
          'q_employment_status': 'employee',
        },
      );

      final taxWidget = widget as TaxSavingsInsertWidget;
      expect(taxWidget.initialIncome, closeTo(8000, 0.01));
      expect(taxWidget.hasPensionFund, isTrue);
    });
  });
}
