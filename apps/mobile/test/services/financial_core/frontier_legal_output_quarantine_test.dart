import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/fiscal_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

void main() {
  test('net income stays on the ordinary tax engine without frontier facts',
      () {
    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: 120000,
      canton: 'GE',
      age: 45,
      etatCivil: 'celibataire',
      nombreEnfants: 0,
    );
    final ordinaryTax = FiscalService.estimateTax(
      revenuBrut: 120000,
      canton: 'GE',
      etatCivil: 'celibataire',
      nombreEnfants: 0,
    );

    expect(breakdown.incomeTaxEstimate, ordinaryTax['chargeTotale']);
    expect(
      breakdown.disposableIncome,
      breakdown.netPayslip - (ordinaryTax['chargeTotale'] as double),
    );
  });
}
