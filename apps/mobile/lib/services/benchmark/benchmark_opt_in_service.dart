// benchmark_opt_in_service.dart — S60 Cantonal Benchmarks
//
// Manages user opt-in preference for cantonal benchmark comparisons.
//
// COMPLIANCE: Opt-in ONLY (default = false).
// Users must explicitly choose to see cantonal benchmarks.
// No benchmark data is shown until the user actively opts in.

import 'package:shared_preferences/shared_preferences.dart';

/// Manages the opt-in state for cantonal benchmark comparisons.
///
/// Default state is NOT opted in — the user must explicitly activate benchmarks.
/// The opt-in preference is persisted across app sessions via SharedPreferences.
///
/// Usage:
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// final isIn = await BenchmarkOptInService.isOptedIn(prefs);
/// if (!isIn) {
///   await BenchmarkOptInService.setOptIn(true, prefs);
/// }
/// ```
class BenchmarkOptInService {
  BenchmarkOptInService._();

  /// SharedPreferences key for the opt-in preference.
  static const String _prefKey = 'benchmark_cantonal_opted_in';

  /// Returns true if the user has opted in to cantonal benchmarks.
  ///
  /// Defaults to false if no preference has been stored.
  static Future<bool> isOptedIn(SharedPreferences prefs) async {
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Persists the opt-in [value] to SharedPreferences.
  ///
  /// Pass [true] to enable benchmarks, [false] to disable.
  static Future<void> setOptIn(bool value, SharedPreferences prefs) async {
    await prefs.setBool(_prefKey, value);
  }
}
