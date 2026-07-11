import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/emergency_fund_heuristic.dart';

void main() {
  test('maps 6-month emergency bucket to housing plus LAMal reserve', () {
    expect(
      EmergencyFundHeuristic.cashForWizardBucket(
        emergencyFundBucket: 'yes_6months',
        housingCost: 2200,
        monthlyLamalPremium: 420,
      ),
      15720,
    );
  });

  test('maps 3-month emergency bucket to housing plus LAMal reserve', () {
    expect(
      EmergencyFundHeuristic.cashForWizardBucket(
        emergencyFundBucket: 'yes_3months',
        housingCost: 2200,
        monthlyLamalPremium: 420,
      ),
      7860,
    );
  });

  test('normalizes yearly housing before applying the bucket', () {
    expect(
      EmergencyFundHeuristic.cashForWizardBucket(
        emergencyFundBucket: 'yes_3months',
        housingCost: 24000,
        monthlyLamalPremium: 500,
        housingPayFrequency: 'yearly',
      ),
      7500,
    );
  });

  test('unknown bucket returns zero', () {
    expect(
      EmergencyFundHeuristic.cashForWizardBucket(
        emergencyFundBucket: 'no',
        housingCost: 2200,
        monthlyLamalPremium: 420,
      ),
      0,
    );
  });

  test('reconstructs legacy smart-flow savings estimate', () {
    expect(
      LegacyCashEstimateHeuristic.smartFlowSavingsEstimate(
        age: 40,
        grossSalary: 100000,
      ),
      75000,
    );
  });
}
