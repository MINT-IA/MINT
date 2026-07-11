import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/wealth_financial_facts.dart';

void main() {
  group('WealthFinancialFacts', () {
    test('computes property net value after mortgage balance', () {
      expect(
        WealthFinancialFacts.propertyNetValue(
          propertyValue: 900000,
          mortgageBalance: 540000,
        ),
        360000,
      );
    });

    test('computes net wealth after debts', () {
      expect(
        WealthFinancialFacts.netWealth(totalAssets: 420000, totalDebts: 80000),
        340000,
      );
    });

    test('computes consumer debt from credit and leasing', () {
      expect(
        WealthFinancialFacts.consumerDebt(
          consumerCredit: 12000,
          leasing: 8000,
        ),
        20000,
      );
    });
  });
}
