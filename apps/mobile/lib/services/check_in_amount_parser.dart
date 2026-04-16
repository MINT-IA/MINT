/// Utility to extract CHF amounts from free-form user text.
///
/// Handles Swiss number formatting:
///   - Apostrophe thousands separator: 1'500
///   - Space thousands separator:      1 500
///   - Comma decimal separator:        1,50
///   - Dot decimal separator:          1.50
///   - CHF prefix:                     CHF 1500
///
/// Returns null when:
///   - No numeric value found in the text
///   - Value is <= 0
///   - Value exceeds 999'999 CHF (sanity cap for monthly contributions)
///
/// This parser is used by the check-in chat flow to extract contribution
/// amounts from conversational answers like "j'ai versé 500" or "1'500.50".
library;

class CheckInAmountParser {
  CheckInAmountParser._();

  /// Maximum accepted amount (exclusive upper bound for monthly contributions).
  /// 999'999.99 is accepted; 1'000'000+ is rejected.
  static const double _maxAmount = 1000000.0;

  /// Extract the first CHF amount from free text.
  ///
  /// Returns null if no valid amount found or amount is out of range.
  static double? parseAmount(String text) {
    if (text.isEmpty) return null;

    // Normalize non-breaking spaces to regular spaces
    final cleaned = text.replaceAll('\u00a0', ' ');

    // Match a number that may contain:
    //   - apostrophes (Swiss thousand separator): 1'500
    //   - spaces (thousand separator): 1 500
    //   - comma or dot (decimal): 1,50 or 1.50
    // Negative numbers are rejected: the pattern must NOT be preceded by '-'.
    // We find all matches and pick the first one NOT preceded by a minus sign.
    final pattern = RegExp(
      r"(\d[\d'\s]*)([.,]\d+)?",
      caseSensitive: false,
    );
    RegExpMatch? match;
    for (final m in pattern.allMatches(cleaned)) {
      final start = m.start;
      // Check if the character immediately before is a minus sign
      if (start > 0 && cleaned[start - 1] == '-') continue;
      match = m;
      break;
    }

    if (match == null) return null;

    // Reconstruct the raw number string
    final integerPart = match.group(1) ?? '';
    final decimalPart = match.group(2) ?? '';

    // Clean integer part: remove apostrophes and spaces used as separators
    final cleanedInteger = integerPart
        .replaceAll("'", '')
        .replaceAll(' ', '')
        .trim();

    if (cleanedInteger.isEmpty) return null;

    // Normalize decimal separator: comma -> dot
    final cleanedDecimal = decimalPart.replaceAll(',', '.');

    final rawNumber = cleanedInteger + cleanedDecimal;

    final value = double.tryParse(rawNumber);
    if (value == null) return null;
    if (value <= 0) return null;
    if (value > _maxAmount) return null;

    return value;
  }
}
