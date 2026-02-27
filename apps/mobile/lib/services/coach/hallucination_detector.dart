/// Hallucination Detector — Sprint S34.
///
/// Extracts numbers (CHF amounts, percentages, durations) from LLM text
/// and compares against known values from financial_core.
///
/// ## Legal Constants Whitelist
///
/// Swiss social insurance constants (3a cap, LPP thresholds, AVS rente,
/// conversion rate, etc.) are whitelisted so the LLM can cite them without
/// triggering false-positive hallucination flags.
///
/// References:
///   - FINMA circular 2008/21 (operational risk)
///   - LSFin art. 8 (quality of financial information)
library;

import 'coach_models.dart';

class HallucinationDetector {
  HallucinationDetector._();

  static final _chfPattern = RegExp(r'CHF\s*([\d' "'" r']+(?:[.,]\d+)?)', caseSensitive: false);
  // CRIT #4 fix: capture integer percentages (e.g. "85%") in addition to decimals.
  static final _pctPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
  static final _durationPattern = RegExp(r'(\d+)\s*(?:mois|ans|semaines|jours)');
  static final _scorePattern = RegExp(r'(\d[\d' "'" r']*(?:[.,]\d+)?)\s*/\s*100');

  /// Swiss legal constants that the LLM is allowed to cite.
  ///
  /// These are well-known public values from Swiss social insurance law.
  /// If an extracted number matches one of these within tolerance,
  /// it is NOT flagged as a hallucination regardless of knownValues.
  ///
  /// Sources: LAVS art. 34, LPP art. 7/8/14/16, OPP3 art. 7
  static const Set<double> _legalConstantsChf = {
    // Pilier 3a (OPP3 art. 7)
    7258.0,   // Plafond 3a salarié affilié LPP
    36288.0,  // Plafond 3a indépendant sans LPP
    // LPP (art. 7, 8)
    22680.0,  // Seuil d'entrée LPP
    26460.0,  // Déduction de coordination
    3780.0,   // Salaire coordonné minimum
    64260.0,  // Salaire coordonné maximum
    90720.0,  // Salaire maximum assuré LPP
    // AVS (LAVS art. 34)
    2520.0,   // Rente AVS max mensuelle
    1260.0,   // Rente AVS min mensuelle
    3780.0,   // Rente couple max mensuelle
    30240.0,  // Rente AVS max annuelle
    530.0,    // Cotisation min indépendant
    // EPL (OPP2 art. 5)
    20000.0,  // EPL minimum
  };

  /// Legal percentage constants.
  static const Set<double> _legalConstantsPct = {
    6.8,    // Taux de conversion LPP minimum (LPP art. 14)
    1.25,   // Taux d'intérêt minimum LPP
    5.3,    // Cotisation AVS salarié
    10.6,   // Cotisation AVS totale
    6.8,    // Réduction anticipation AVS par an
    5.0,    // Taux théorique hypothécaire (FINMA/ASB)
    7.0,    // Bonification LPP 25-34
    10.0,   // Bonification LPP 35-44
    15.0,   // Bonification LPP 45-54
    18.0,   // Bonification LPP 55-65
    20.0,   // Part revenu 3a sans LPP
    70.0,   // Taux indemnité chômage standard
    80.0,   // Taux indemnité chômage avec charges
  };

  /// Tolerance for matching legal constants (±1%).
  static const double _legalConstantTolerance = 0.01;

  /// Check if a value matches a known legal constant.
  static bool _isLegalConstant(double value, String numberType) {
    final constants = (numberType == 'pct' || numberType == 'score')
        ? _legalConstantsPct
        : _legalConstantsChf;

    for (final constant in constants) {
      if (constant == 0) continue;
      final deviation = (value - constant).abs() / constant.abs();
      if (deviation <= _legalConstantTolerance) return true;
    }
    return false;
  }

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
  ///
  /// Numbers that match Swiss legal constants are automatically whitelisted
  /// and never flagged as hallucinations.
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
      // Skip legal constants — LLM is allowed to cite these.
      if (_isLegalConstant(foundValue, numberType)) continue;

      // Skip non-finite values (guards against infinity/NaN).
      if (!foundValue.isFinite) continue;

      String? bestKey;
      double? bestValue;
      double bestDeviation = double.infinity;

      for (final entry in knownValues.entries) {
        final knownVal = entry.value;
        // Skip non-finite known values.
        if (!knownVal.isFinite) continue;
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
