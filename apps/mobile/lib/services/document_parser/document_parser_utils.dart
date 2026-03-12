// ────────────────────────────────────────────────────────────
//  DOCUMENT PARSER UTILITIES — Shared across all parsers
// ────────────────────────────────────────────────────────────
//
//  Centralizes Swiss number/percentage parsing and field pattern
//  definitions to avoid duplication across parsers.
//
//  Used by: LppCertificateParser, TaxDeclarationParser,
//           AvsExtractParser, SalaryCertificateParser
// ────────────────────────────────────────────────────────────

/// Reusable regex fragment: Swiss number capture group.
/// Matches: CHF 143'287.50, Fr. 98 400, 44887.50, etc.
const String numCapture = r"([CHFfr.\s]*[\d\s'.,]+)";

/// Parse a Swiss-formatted number: "143'287.50", "143 287", "CHF 143'287".
///
/// Handles:
/// - Apostrophe thousand separator: 143'287.50
/// - Space thousand separator: 143 287.50
/// - Right single quote (Unicode): 143\u2019287.50
/// - Comma as decimal (FR/DE): 143'287,50
/// - German thousands-dot + decimal-comma: 7.083,35
/// - Negative values: -523.40
///
/// Returns null if no valid number found.
double? parseSwissNumber(String text) {
  // Remove currency prefixes and whitespace
  var cleaned = text
      .replaceAll(RegExp(r"CHF\s*", caseSensitive: false), "")
      .replaceAll(RegExp(r"Fr\.\s*", caseSensitive: false), "")
      .trim();

  // Remove thousand separators (apostrophe, right single quote, NBSP)
  cleaned = cleaned.replaceAll("'", "");
  cleaned = cleaned.replaceAll("\u2019", ""); // Right single quotation mark
  cleaned = cleaned.replaceAll("\u00A0", ""); // Non-breaking space

  // Handle space as thousand separator (but not decimal)
  cleaned = cleaned.replaceAll(RegExp(r"(\d)\s+(\d)"), r"$1$2");

  // Handle mixed dot+comma formats (German-Swiss: "7.083,35")
  // If both dot and comma are present, the LAST separator is the decimal.
  if (cleaned.contains(",") && cleaned.contains(".")) {
    final lastDot = cleaned.lastIndexOf(".");
    final lastComma = cleaned.lastIndexOf(",");
    if (lastComma > lastDot) {
      // "7.083,35" → comma is decimal separator, dots are thousands
      cleaned = cleaned.replaceAll(".", "");
      cleaned = cleaned.replaceAll(",", ".");
    } else {
      // "7,083.35" → dot is decimal separator, commas are thousands
      cleaned = cleaned.replaceAll(",", "");
    }
  } else if (cleaned.contains(",") && !cleaned.contains(".")) {
    // Only comma present: "143287,50" → decimal comma
    final lastComma = cleaned.lastIndexOf(",");
    final afterComma = cleaned.substring(lastComma + 1);
    if (afterComma.length <= 2) {
      cleaned = "${cleaned.substring(0, lastComma)}.$afterComma";
    } else {
      // "143,287" → thousands comma (English style, rare in CH)
      cleaned = cleaned.replaceAll(",", "");
    }
  }

  // Remove any remaining non-numeric chars except dot and minus
  cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");

  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Parse a percentage: "6.80%", "6,80 %", "80".
///
/// If value > 1, assumes percent form (e.g. 80 → 80%).
/// If value <= 1, assumes decimal form (e.g. 0.80 → 80%).
/// Edge case: exactly 1.0 → treated as 100% (decimal form).
double? parsePercentage(String text) {
  final cleaned = text.replaceAll("%", "").trim();
  final value = parseSwissNumber(cleaned);
  if (value == null) return null;
  // Threshold: > 1 is already in percent form; <= 1 is decimal.
  // Exactly 1.0 → 100% (correct: 1.0 as decimal = 100%).
  return value > 1 ? value : value * 100;
}

/// Generic field definition for pattern-based parsing.
///
/// Used by all document parsers to define field extraction rules.
class FieldPattern {
  final String fieldName;
  final String label;
  final List<RegExp> patterns;
  final String? profileField;
  final bool isPercentage;
  final bool isInteger;

  const FieldPattern({
    required this.fieldName,
    required this.label,
    required this.patterns,
    this.profileField,
    this.isPercentage = false,
    this.isInteger = false,
  });
}
