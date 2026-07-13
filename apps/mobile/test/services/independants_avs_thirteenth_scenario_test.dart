import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/avs_thirteenth_pension_calculator.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

void main() {
  setUp(() {
    FeatureFlags.enableAvsThirteenthScenarioCashflow = true;
    RegulatorySyncService.clearCache();
  });

  tearDown(() {
    FeatureFlags.enableAvsThirteenthScenarioCashflow = false;
    RegulatorySyncService.clearCache();
  });

  test('sub-centime AVS registry value cannot create a false supplement', () {
    RegulatorySyncService.setMockCache({
      'avs.max_monthly_pension': 2520.123,
      'avs.max_annual_pension': 30240,
    });

    final result = IndependantsService.calculateLppVolontaire(
      80000,
      40,
      0.30,
    );

    expect(result.avsThirteenthScenario, isNull);
    expect(
      result.avsThirteenthScenarioFailureReadiness,
      AvsThirteenthReadiness.providerCorrectionRequired,
    );
    expect(
      result.avsThirteenthScenarioFailureFields,
      ['avs.max_monthly_pension.exactCentime'],
    );
    expect(result.projectionSansLpp, 30240);
  });
}
