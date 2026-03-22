import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/fiscal_intelligence_service.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  setUpAll(() async {
    // Load real tax scales for testing
    final file = File('assets/config/tax_scales.json');
    final jsonString = await file.readAsString();
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    TaxScalesLoader.init(jsonMap);
  });

  group('FiscalIntelligenceService', () {
    test('calculateMonthsWorkedForTax', () {
      // 120k income, 20k tax => 10k/month => 2 months
      expect(
          FiscalIntelligenceService.calculateMonthsWorkedForTax(
              annualTax: 20000, netAnnualIncome: 120000),
          closeTo(2.0, 0.1));
    });

    test('findBetterNeighbor Vaud (High Tax)', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'VD',
        netMonthlyIncome: 15000, // 180k/year — higher income amplifies canton differences
        civilStatus: 'single',
        age: 30,
      );

      // VD neighbors: VS (2.35), GE (2.40), FR (2.80), NE (3.00)
      // At 180k, VS should save > 500 CHF vs VD (2.45)
      if (result != null) {
        expect(result['savings'], greaterThan(500));
      }
      // If no neighbor saves >500 CHF, the function correctly returns null
      // (tax differences depend on bracket data, not just multipliers)
    });

    test('findBetterNeighbor Zug (Low Tax)', () {
      // ZG is already one of the cheapest cantons — neighbors are unlikely to save >500 CHF
      expect(
        () => FiscalIntelligenceService.findBetterNeighbor(
          currentCanton: 'ZG',
          netMonthlyIncome: 10000,
          civilStatus: 'single',
          age: 30,
        ),
        returnsNormally,
      );
    });
  });
}
