// benchmark_opt_in_test.dart — S60
//
// Tests for BenchmarkOptInService:
//   - Default is not opted in
//   - Opt in persists
//   - Opt out persists

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/benchmark/benchmark_opt_in_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BenchmarkOptInService', () {
    test('default is not opted in', () async {
      final prefs = await SharedPreferences.getInstance();
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isFalse);
    });

    test('opt in persists', () async {
      final prefs = await SharedPreferences.getInstance();
      await BenchmarkOptInService.setOptIn(true, prefs);
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isTrue);
    });

    test('opt out persists', () async {
      final prefs = await SharedPreferences.getInstance();
      // First opt in
      await BenchmarkOptInService.setOptIn(true, prefs);
      // Then opt out
      await BenchmarkOptInService.setOptIn(false, prefs);
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isFalse);
    });

    test('toggling multiple times preserves last value', () async {
      final prefs = await SharedPreferences.getInstance();
      await BenchmarkOptInService.setOptIn(true, prefs);
      await BenchmarkOptInService.setOptIn(false, prefs);
      await BenchmarkOptInService.setOptIn(true, prefs);
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isTrue);
    });

    test('fresh prefs instance also returns persisted value', () async {
      // Set opt-in using initial prefs
      SharedPreferences.setMockInitialValues({'benchmark_cantonal_opted_in': true});
      final prefs = await SharedPreferences.getInstance();
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isTrue);
    });

    test('opt out after initial opt-in in new session is false', () async {
      SharedPreferences.setMockInitialValues({'benchmark_cantonal_opted_in': false});
      final prefs = await SharedPreferences.getInstance();
      final result = await BenchmarkOptInService.isOptedIn(prefs);
      expect(result, isFalse);
    });

    test('setOptIn true does not throw', () async {
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        BenchmarkOptInService.setOptIn(true, prefs),
        completes,
      );
    });

    test('setOptIn false does not throw', () async {
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        BenchmarkOptInService.setOptIn(false, prefs),
        completes,
      );
    });
  });
}
