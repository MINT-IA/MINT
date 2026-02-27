/// OCR Sanitizer — Sprint S34 (SLM Safety).
///
/// Validates and sanitizes values extracted from document OCR before
/// injecting them into the user's financial profile.
///
/// ## Security contract
///
/// 1. Document images are NEVER stored (deleted after OCR extraction).
/// 2. On-device OCR is the default (document never leaves the phone).
/// 3. Cloud OCR requires explicit user consent + deletion after processing.
/// 4. Extracted values MUST be confirmed by the user before profile injection.
/// 5. Source quality is tracked per field (document vs manual vs estimated).
///
/// ## Validation rules
///
/// - CHF amounts: must be positive, < CHF 50M (sanity cap)
/// - Percentages: must be 0-100
/// - Dates: must be valid and within reasonable range
/// - Account numbers: format-validated (no storage of raw IBAN)
///
/// References:
///   - LPD art. 6 (data processing principles)
///   - FINMA circular 2008/21 (operational risk)
library;

/// Source quality of an extracted value.
enum DataSource {
  /// Extracted from a scanned document (OCR).
  document,

  /// Manually entered by the user.
  manual,

  /// Estimated from other profile data.
  estimated,

  /// Imported from bLink/open banking.
  openBanking,
}

/// Result of sanitizing an OCR-extracted value.
///
/// CRIT #7 fix: sealed class hierarchy prevents isValid=true + value=null.
/// - [ValidValue] guarantees a non-null [value].
/// - [InvalidValue] guarantees a non-null [rejectionReason].
sealed class SanitizedValue<T> {
  /// Source quality of this value.
  final DataSource source;

  /// Raw text as extracted by OCR (for user confirmation UI).
  final String rawText;

  const SanitizedValue({
    this.source = DataSource.document,
    this.rawText = '',
  });

  /// Whether the value passed validation.
  bool get isValid;

  /// The sanitized value (only on [ValidValue]).
  T? get value;

  /// Rejection reason (only on [InvalidValue]).
  String? get rejectionReason;
}

/// A successfully sanitized value with a guaranteed non-null [value].
class ValidValue<T> extends SanitizedValue<T> {
  @override
  final T value;

  const ValidValue({
    required this.value,
    super.source,
    super.rawText,
  });

  @override
  bool get isValid => true;

  @override
  String? get rejectionReason => null;
}

/// A rejected value with a guaranteed non-null [rejectionReason].
class InvalidValue<T> extends SanitizedValue<T> {
  @override
  final String rejectionReason;

  const InvalidValue({
    required this.rejectionReason,
    super.source,
    super.rawText,
  });

  @override
  bool get isValid => false;

  @override
  T? get value => null;
}

/// Sanitizes OCR-extracted values before profile injection.
///
/// All public methods return [SanitizedValue] which must be presented
/// to the user for confirmation before being written to the profile.
class OcrSanitizer {
  OcrSanitizer._();

  /// Maximum sane CHF amount (CHF 50M — covers ultra-high net worth).
  static const double _maxChfAmount = 50000000;

  /// Sanitize a CHF amount extracted from OCR.
  ///
  /// Validates:
  /// - Non-negative
  /// - Below sanity cap (CHF 50M)
  /// - Parseable as a number
  static SanitizedValue<double> sanitizeChfAmount(String rawText) {
    final cleaned = rawText
        .replaceAll("'", '')
        .replaceAll(' ', '')
        .replaceAll('CHF', '')
        .replaceAll('Fr.', '')
        .replaceAll(',', '.')
        .trim();

    final value = double.tryParse(cleaned);
    if (value == null) {
      return InvalidValue(
        rejectionReason: 'Format non reconnu: "$rawText"',
        rawText: rawText,
      );
    }

    if (value < 0) {
      return InvalidValue(
        rejectionReason: 'Montant négatif non autorisé',
        rawText: rawText,
      );
    }

    if (value > _maxChfAmount) {
      return InvalidValue(
        rejectionReason:
            'Montant anormalement élevé (> CHF ${_maxChfAmount.toStringAsFixed(0)})',
        rawText: rawText,
      );
    }

    return ValidValue(
      value: value,
      rawText: rawText,
    );
  }

  /// Sanitize a percentage extracted from OCR.
  ///
  /// Validates: 0-100 range, parseable.
  static SanitizedValue<double> sanitizePercentage(String rawText) {
    final cleaned = rawText
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();

    final value = double.tryParse(cleaned);
    if (value == null) {
      return InvalidValue(
        rejectionReason: 'Format non reconnu: "$rawText"',
        rawText: rawText,
      );
    }

    if (value < 0 || value > 100) {
      return InvalidValue(
        rejectionReason: 'Pourcentage hors limites (0-100%): $value%',
        rawText: rawText,
      );
    }

    return ValidValue(
      value: value,
      rawText: rawText,
    );
  }

  /// Sanitize a year extracted from OCR.
  ///
  /// Validates: 1900-2100 range, integer.
  static SanitizedValue<int> sanitizeYear(String rawText) {
    final cleaned = rawText.replaceAll(' ', '').trim();
    final value = int.tryParse(cleaned);

    if (value == null) {
      return InvalidValue(
        rejectionReason: 'Année non reconnue: "$rawText"',
        rawText: rawText,
      );
    }

    if (value < 1900 || value > 2100) {
      return InvalidValue(
        rejectionReason: 'Année hors limites (1900-2100): $value',
        rawText: rawText,
      );
    }

    return ValidValue(
      value: value,
      rawText: rawText,
    );
  }

  /// Sanitize an AVS number (AHV-Nr) extracted from OCR.
  ///
  /// Format: 756.XXXX.XXXX.XX (13 digits with check digit).
  /// We validate the format but do NOT store the raw number —
  /// only a boolean indicating the user has an AVS number.
  static SanitizedValue<bool> sanitizeAvsNumber(String rawText) {
    final cleaned = rawText.replaceAll('.', '').replaceAll(' ', '').trim();

    // AVS number: 13 digits starting with 756
    if (cleaned.length != 13 ||
        !cleaned.startsWith('756') ||
        !RegExp(r'^\d{13}$').hasMatch(cleaned)) {
      return InvalidValue(
        rejectionReason: 'Format AVS invalide (attendu: 756.XXXX.XXXX.XX)',
        rawText: rawText,
      );
    }

    // Valid format — return true (has AVS) without storing the number
    return ValidValue(
      value: true,
      rawText: '756.XXXX.XXXX.XX', // Masked for privacy
    );
  }
}
