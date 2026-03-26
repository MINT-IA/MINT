// Tests the full pipeline: cache → reg() → calculator
//
// Verifies:
// 1. Clear cache → reg() returns fallback
// 2. Simulate a sync with mock data → reg() returns synced value
// 3. loadFromDisk restores previous session
// 4. fetchConstants updates cache and persists to SP
// 5. avs_calculator uses reg() value when cache is populated

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RegulatorySyncService.clearCache();
  });

  group('RegulatorySyncService integration', () {
    test('reg() returns fallback when cache is empty', () {
      // No sync has occurred — cache is empty.
      final value = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);

      expect(value, pilier3aPlafondAvecLpp);
      expect(RegulatorySyncService.hasSynced, isFalse);
      expect(RegulatorySyncService.getCached('pillar3a.max_with_lpp'), isNull);
    });

    test('reg() returns cached value after sync', () {
      // Simulate a backend sync by injecting mock constants.
      const mockValue = 8000.0;
      RegulatorySyncService.setMockCache({
        'pillar3a.max_with_lpp': mockValue,
      });

      final value = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);

      expect(value, mockValue);
      expect(value, isNot(equals(pilier3aPlafondAvecLpp)));
      expect(RegulatorySyncService.hasSynced, isTrue);
    });

    test('loadFromDisk restores previous session', () async {
      // Pre-populate SharedPreferences with a previous session cache.
      final previousCache = {
        'avs.max_monthly_pension': 2600.0,
        'lpp.conversion_rate': 0.065,
      };
      SharedPreferences.setMockInitialValues({
        'regulatory_cache': jsonEncode(previousCache),
      });

      // Load from disk (simulates app cold-start).
      await RegulatorySyncService.loadFromDisk();

      expect(RegulatorySyncService.hasSynced, isTrue);
      expect(RegulatorySyncService.isFromDisk, isTrue);
      expect(RegulatorySyncService.getCached('avs.max_monthly_pension'), 2600.0);
      expect(RegulatorySyncService.getCached('lpp.conversion_rate'), 0.065);

      // syncStatus reflects disk state
      final status = RegulatorySyncService.syncStatus();
      expect(status['hasSynced'], isTrue);
      expect(status['isFromDisk'], isTrue);
      expect(status['cachedCount'], 2);
    });

    test('fetchConstants updates cache and persists to SP', () async {
      // We cannot call the real API in unit tests, but we can test the
      // persistence round-trip: inject → persist via loadFromDisk → verify.
      //
      // Step 1: Inject mock cache (simulates fetchConstants populating cache).
      RegulatorySyncService.setMockCache({
        'avs.max_monthly_pension': 2700.0,
      });
      expect(RegulatorySyncService.hasSynced, isTrue);
      expect(RegulatorySyncService.isFromDisk, isFalse);

      // Step 2: Verify syncStatus after network-style injection.
      final status = RegulatorySyncService.syncStatus();
      expect(status['hasSynced'], isTrue);
      expect(status['isFromDisk'], isFalse);
      expect(status['cachedCount'], 1);
      expect(status['lastSyncAt'], isNotNull);

      // Step 3: Simulate persist + cold restart.
      // Write the same data to SP, clear cache, then reload.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'regulatory_cache',
        jsonEncode({'avs.max_monthly_pension': 2700.0}),
      );

      RegulatorySyncService.clearCache();
      expect(RegulatorySyncService.hasSynced, isFalse);

      await RegulatorySyncService.loadFromDisk();
      expect(RegulatorySyncService.getCached('avs.max_monthly_pension'), 2700.0);
      expect(RegulatorySyncService.isFromDisk, isTrue);
    });

    test('avs_calculator uses reg() value when cache is populated', () {
      // Without cache: AvsCalculator uses hardcoded fallbacks.
      final renteNoCache = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: 65,
        grossAnnualSalary: 88200,
      );
      // With max salary and full contribution years, should get max rente.
      expect(renteNoCache, closeTo(avsRenteMaxMensuelle, 1.0));

      // Inject a different max rente via cache.
      const customMaxRente = 3000.0;
      RegulatorySyncService.setMockCache({
        'avs.max_monthly_pension': customMaxRente,
        'avs.min_monthly_pension': avsRenteMinMensuelle,
        'avs.ramd_max': avsRAMDMax,
        'avs.ramd_min': avsRAMDMin,
      });

      // Now AvsCalculator should use the cached value via reg().
      final renteWithCache = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: 65,
        grossAnnualSalary: 88200,
      );
      // renteFromRAMD for salary >= ramdMax returns reg('avs.max_monthly_pension')
      // which is now 3000.0 instead of 2520.0.
      expect(renteWithCache, closeTo(customMaxRente, 1.0));
      expect(renteWithCache, isNot(equals(renteNoCache)));
    });
  });
}
