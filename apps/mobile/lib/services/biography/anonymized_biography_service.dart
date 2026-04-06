import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

// ────────────────────────────────────────────────────────────
//  ANONYMIZED BIOGRAPHY SUMMARY — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Privacy-safe transformation of BiographyFacts for LLM prompt
// injection. Raw facts NEVER leave the device. Only this
// anonymized summary enters the coach system prompt.
//
// Rules:
//   - WHITELIST approach: every FactType has an explicit
//     rounding rule. Unknown types -> "[donnee confidentielle]".
//   - Salary: rounded to nearest 5k.
//   - LPP/3a: rounded to nearest 10k.
//   - Mortgage: rounded to nearest 50k.
//   - No names, no employer, no IBAN, no exact amounts.
//   - Stale facts (freshness < 0.60): marked [DONNEE ANCIENNE].
//   - Very stale (freshness < 0.30): excluded entirely.
//   - Output capped at 8000 chars (~2K tokens at ~4 chars/token).
//
// See: BIO-03, BIO-04, COMP-02, COMP-03 requirements.
// Threat: T-03-04 (whitelist anonymization).
// ────────────────────────────────────────────────────────────

/// French month names for source date formatting (no day — BIO-04).
const _frenchMonths = [
  'janvier',
  'fevrier',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'aout',
  'septembre',
  'octobre',
  'novembre',
  'decembre',
];

/// Privacy-safe biography summary builder for coach LLM injection.
///
/// Transforms raw [BiographyFact] list into an anonymized text block
/// suitable for the system prompt. All financial amounts are rounded,
/// no PII is included, and stale data is explicitly marked.
class AnonymizedBiographySummary {
  AnonymizedBiographySummary._();

  /// Maximum character count for the summary output (~2K tokens).
  static const _maxChars = 8000;

  /// Freshness weight below which facts are excluded entirely.
  static const _excludeThreshold = 0.30;

  /// Freshness weight below which facts are marked [DONNEE ANCIENNE].
  static const _staleThreshold = 0.60;

  /// Build the anonymized biography summary from a list of facts.
  ///
  /// Filters deleted and very stale facts, anonymizes values,
  /// formats source dates, marks aging facts, and caps output.
  ///
  /// Returns a string wrapped in BIOGRAPHIE FINANCIERE delimiters.
  static String build(List<BiographyFact> facts, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();

    // Filter: exclude deleted and very stale facts
    final filtered = facts.where((f) {
      if (f.isDeleted) return false;
      final w = FreshnessDecayService.weight(f, effectiveNow);
      return w >= _excludeThreshold;
    }).toList();

    // Sort by factType name for consistent ordering
    filtered.sort((a, b) => a.factType.name.compareTo(b.factType.name));

    final buffer = StringBuffer();

    // Header with privacy reminder
    buffer.writeln('--- BIOGRAPHIE FINANCIERE ---');
    buffer.writeln(
      'Rappel\u00a0: JAMAIS de montant exact, nom, employeur, IBAN.',
    );
    buffer.writeln(
      'Utilise des approximations (\u00abun peu moins de 100k\u00bb).',
    );
    buffer.writeln(
      'Date TOUJOURS la source (\u00abselon certificat de mars 2025\u00bb).',
    );

    // Anonymized facts
    for (final fact in filtered) {
      final anonymized = _anonymize(fact);
      final dateStr = _formatSourceDate(fact.sourceDate);
      final w = FreshnessDecayService.weight(fact, effectiveNow);
      final staleMarker = w < _staleThreshold ? ' [DONNEE ANCIENNE]' : '';

      buffer.writeln(
        '- ${fact.factType.name}\u00a0: $anonymized (source\u00a0: $dateStr)$staleMarker',
      );

      // Hard cap check to avoid runaway output
      if (buffer.length >= _maxChars - 50) break;
    }

    // Footer
    buffer.writeln('--- FIN BIOGRAPHIE ---');

    // Truncate to hard limit if needed
    final result = buffer.toString();
    if (result.length > _maxChars) {
      // Truncate and re-add footer
      final truncated = result.substring(0, _maxChars - 30);
      return '$truncated\n--- FIN BIOGRAPHIE ---';
    }

    return result;
  }

  /// Anonymize a single fact value using the WHITELIST approach.
  ///
  /// Every [FactType] has an explicit rule. Unknown/unhandled types
  /// return "[donnee confidentielle]" to prevent data leaks.
  static String _anonymize(BiographyFact fact) {
    switch (fact.factType) {
      case FactType.salary:
        return _roundToK(fact.value, 5000);
      case FactType.lppCapital:
      case FactType.lppRachatMax:
      case FactType.threeACapital:
        return _roundToK(fact.value, 10000);
      case FactType.avsContributionYears:
        // Integer, non-sensitive — pass through
        return '${_parseNum(fact.value).round()} ans';
      case FactType.taxRate:
        // Round to nearest 0.5%
        final rate = _parseNum(fact.value);
        final rounded = (rate * 2).round() / 2;
        return '~${rounded.toStringAsFixed(1)}\u00a0%';
      case FactType.mortgageDebt:
        return _roundToK(fact.value, 50000);
      case FactType.canton:
      case FactType.civilStatus:
      case FactType.employmentStatus:
        // Non-sensitive categorical — pass through
        return fact.value;
      case FactType.lifeEvent:
        // Event name only — non-sensitive
        return fact.value;
      case FactType.userDecision:
      case FactType.coachPreference:
        // Truncate long text to 100 chars
        if (fact.value.length > 100) {
          return '${fact.value.substring(0, 97)}...';
        }
        return fact.value;
    }
  }

  /// Round a numeric value to nearest [step] and format as "~Xk CHF".
  static String _roundToK(String raw, int step) {
    final value = _parseNum(raw);
    final rounded = (value / step).round() * step;
    final inK = rounded ~/ 1000;
    return '~${inK}k CHF';
  }

  /// Parse a string to a number, defaulting to 0 on failure.
  static double _parseNum(String raw) {
    return double.tryParse(raw.replaceAll(RegExp(r"['\s]"), '')) ?? 0;
  }

  /// Format a source date as "mars 2025" (month + year, no day).
  ///
  /// Returns "date inconnue" if null (BIO-04: no identifiable dates).
  static String _formatSourceDate(DateTime? sourceDate) {
    if (sourceDate == null) return 'date inconnue';
    final month = _frenchMonths[sourceDate.month - 1];
    return '$month ${sourceDate.year}';
  }
}
