import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/independent_protection_financial_facts.dart';

void main() {
  group('IndependentProtectionFinancialFacts', () {
    test('periodizes employee AVS contribution from annual income', () {
      expect(
        IndependentProtectionFinancialFacts.employeeAvsMonthly(120000),
        closeTo(530, 0.01),
      );
    });

    test('periodizes employee LPP share from coordinated salary', () {
      expect(
        IndependentProtectionFinancialFacts.employeeLppMonthly(120000, 45),
        closeTo(401.63, 0.01),
      );
    });

    test('returns no employee LPP share below the entry threshold', () {
      expect(
        IndependentProtectionFinancialFacts.employeeLppMonthly(20000, 45),
        isZero,
      );
    });

    test('names vested-benefits five-year gain assumptions', () {
      expect(
        IndependentProtectionFinancialFacts
            .vestedBenefitsFoundationFiveYearGain(100000),
        closeTo(7000, 0.01),
      );
      expect(
        IndependentProtectionFinancialFacts.substituteInstitutionFiveYearGain(
          100000,
        ),
        closeTo(4000, 0.01),
      );
      expect(
        IndependentProtectionFinancialFacts.newPensionFundFiveYearGain(100000),
        closeTo(15000, 0.01),
      );
    });

    test('keeps voluntary LPP and professional coverage proxies explicit', () {
      expect(
        IndependentProtectionFinancialFacts.voluntaryLppTaxSavingProxy(100000),
        closeTo(8000, 0.01),
      );
      expect(
        IndependentProtectionFinancialFacts.employeeProfessionalCoverageProxy(
          100000,
        ),
        closeTo(2000, 0.01),
      );
      expect(
        IndependentProtectionFinancialFacts
            .selfEmployedProfessionalCoverageProxy(100000),
        closeTo(4000, 0.01),
      );
    });
  });
}
