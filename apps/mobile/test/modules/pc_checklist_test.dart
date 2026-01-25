import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/modules/pc_module.dart';

void main() {
  group('PCModule (Prestations Complémentaires)', () {
    test('Detects potential eligibility for low income/wealth', () {
      final result = PCModule.checkEligibility(
        netIncome: 2500, // Very low
        netWealth: 10000, // Low
        rent: 1200,
        canton: 'VD',
      );

      expect(result.isPotentiallyEligible, true);
      expect(result.actionLabel, contains("Contacter l'office PC"));
    });

    test('Rejects high income', () {
      final result = PCModule.checkEligibility(
        netIncome: 6000,
        netWealth: 50000,
        rent: 1500,
        canton: 'VD',
      );

      expect(result.isPotentiallyEligible, false);
    });

    test('Disclaimer mandatory', () {
      final result = PCModule.checkEligibility(
          netIncome: 3000, netWealth: 0, rent: 1000, canton: 'GE');
      expect(result.disclaimer, contains("décision officielle"));
    });
  });
}
