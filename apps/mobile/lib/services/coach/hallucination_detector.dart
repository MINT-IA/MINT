/// Hallucination Detector — Sprint S34.
///
/// Extracts numbers (CHF amounts, percentages, durations) from LLM text
/// and compares against known values from financial_core.
///
/// References:
///   - FINMA circular 2008/21 (operational risk)
///   - LSFin art. 8 (quality of financial information)
library;

import 'coach_models.dart';

class HallucinationDetector {
  HallucinationDetector._();

  static final _chfPattern = RegExp(r'CHF\s*([\d' "'" r']+(?:[.,]\d+)?)', caseSensitive: false);
  static final _pctPattern = RegExp(r'(\d+[.,]\d+)\s*%');
  static final _durationPattern = RegExp(r'(\d+)\s*(?:mois|ans|semaines|jours)');
  static final _scorePattern = RegExp(r'(\d[\d' "'" r']*(?:[.,]\d+)?)\s*/\s*100');

  /// Parse a Swiss-formatted number (e.g., 1'820 or 1,820.50).
  static double _parseSwissNumber(String text) {
    final cleaned = text.replaceAll("'", '').replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Extract all numbers from text.
  /// Returns list of (originalText, parsedValue, numberType).
  static List<(String, double, String)> extractNumbers(String text) {
    final results = <(String, double, String)>[];

    for (final match in _chfPattern.allMatches(text)) {
      final value = _parseSwissNumber(match.group(1)!);
      results.add((match.group(0)!, value, 'chf'));
    }

    for (final match in _pctPattern.allMatches(text)) {
      final value = _parseSwissNumber(match.group(1)!);
      results.add((match.group(0)!, value, 'pct'));
    }

    for (final match in _durationPattern.allMatches(text)) {
      final value = double.parse(match.group(1)!);
      results.add((match.group(0)!, value, 'duration'));
    }

    for (final match in _scorePattern.allMatches(text)) {
      final value = _parseSwissNumber(match.group(1)!);
      results.add((match.group(0)!, value, 'score'));
    }

    return results;
  }

  /// Detect hallucinated numbers in LLM output.
  ///
  /// [tolerancePct]: Relative tolerance for CHF amounts (default 5%).
  /// [toleranceAbs]: Absolute tolerance for percentages/scores (default 2 points).
  static List<HallucinatedNumber> detect(
    String llmOutput,
    Map<String, double> knownValues, {
    double tolerancePct = 0.05,
    double toleranceAbs = 2.0,
  }) {
    if (knownValues.isEmpty) return [];

    final extracted = extractNumbers(llmOutput);
    if (extracted.isEmpty) return [];

    final hallucinations = <HallucinatedNumber>[];

    for (final (foundText, foundValue, numberType) in extracted) {
      String? bestKey;
      double? bestValue;
      double bestDeviation = double.infinity;

      for (final entry in knownValues.entries) {
        final knownVal = entry.value;
        final deviation = knownVal == 0
            ? foundValue.abs()
            : (foundValue - knownVal).abs() / knownVal.abs();
        if (deviation < bestDeviation) {
          bestDeviation = deviation;
          bestKey = entry.key;
          bestValue = knownVal;
        }
      }

      if (bestKey == null) continue;

      bool isHallucinated = false;
      if (numberType == 'pct' || numberType == 'score') {
        if ((foundValue - bestValue!).abs() > toleranceAbs) {
          isHallucinated = true;
        }
      } else {
        if (bestValue == 0) {
          isHallucinated = foundValue != 0;
        } else if (bestDeviation > tolerancePct) {
          isHallucinated = true;
        }
      }

      if (isHallucinated) {
        hallucinations.add(HallucinatedNumber(
          foundText: foundText,
          foundValue: foundValue,
          closestKey: bestKey,
          closestValue: bestValue!,
          deviationPct: bestDeviation * 100,
        ));
      }
    }

    return hallucinations;
  }
}
