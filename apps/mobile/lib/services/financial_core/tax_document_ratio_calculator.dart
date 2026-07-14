/// Pure ratio arithmetic shared by tax-document ingestion.
///
/// Callers keep ownership of admission checks and interpretation. This helper
/// only preserves the arithmetic conversion from an amount/reference ratio to
/// percentage points.
abstract final class TaxDocumentRatioCalculator {
  static double percentOf({
    required double amount,
    required double reference,
  }) =>
      amount / reference * 100;
}
