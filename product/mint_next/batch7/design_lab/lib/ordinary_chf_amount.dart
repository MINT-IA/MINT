const int maxOrdinaryChfAmountMinorUnits = 99999999999999;

/// Parses a user-entered CHF amount without floating-point conversion.
///
/// The same deliberately small grammar is used in every supported locale:
/// an optional grouping separator (space, NBSP, straight/curly apostrophe)
/// and either `.` or `,` for one or two decimal digits.
int parseOrdinaryChfAmount(String raw, {String? locale}) {
  if (raw.runes.length > 32) {
    throw const FormatException('amount_too_long');
  }
  if (locale != null &&
      !const {'fr', 'en', 'de', 'it', 'es', 'pt'}.contains(locale)) {
    throw const FormatException('unsupported_locale');
  }

  final value = raw.trim();
  final match = RegExp(
    r"^((?:[0-9]{1,3}(?:[ \u00a0'’][0-9]{3})+)|[0-9]+)(?:([.,])([0-9]{1,2}))?$",
  ).firstMatch(value);
  if (match == null) {
    throw const FormatException('invalid_amount');
  }

  final wholeDigits = match.group(1)!.replaceAll(RegExp(r"[ \u00a0'’]"), '');
  final fraction = match.group(3) ?? '';
  final minorDigits = fraction.isEmpty ? '00' : fraction.padRight(2, '0');
  final minorUnits = BigInt.parse('$wholeDigits$minorDigits');
  if (minorUnits > BigInt.from(maxOrdinaryChfAmountMinorUnits)) {
    throw const FormatException('amount_too_large');
  }
  return minorUnits.toInt();
}
