import 'package:flutter/foundation.dart';
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
        netMonthlyIncome: 10000, // 120k/year
        civilStatus: 'single',
        age: 30,
      );

      expect(result, isNotNull);
      debugPrint('VD Neighbor Result: $result');
      // Should find cheaper neighbor (VS, FR)
      expect(result!['savings'], greaterThan(1000));
    });

    test('findBetterNeighbor Zug (Low Tax)', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZG',
        netMonthlyIncome: 10000,
        civilStatus: 'single',
        age: 30,
      );

      // Probably null or very low savings as ZG is cheap
      // neighbors: ZH (expensive), LU (cheap but > ZG usually), SZ (cheap), AG (medium)
      // SZ might be cheaper in some cases, but likely result is null or low
      debugPrint('ZG Neighbor Result: $result');
    });
  });
}
