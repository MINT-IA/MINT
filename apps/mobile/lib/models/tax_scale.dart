class TaxScale {
  final String canton;
  final String tariff; // "Single, no children", "Married...", etc.
  final double
      incomeThreshold; // "For the next CHF 6'900" -> This is Bracket Size
  final double rate; // Rate in %

  TaxScale({
    required this.canton,
    required this.tariff,
    required this.incomeThreshold,
    required this.rate,
  });

  factory TaxScale.fromCsvRow(String canton, List<dynamic> row) {
    // row: ['Income tax', 'Single...', 'Canton', '6’900', '0.00']

    // Parsing helper
    double parseAmount(String val) {
      return double.tryParse(val.replaceAll("’", "").replaceAll("'", "")) ??
          0.0;
    }

    // Handle special cases (e.g. Uri flat tax with fewer columns)
    if (row.length == 4) {
      return TaxScale(
        canton: canton,
        tariff: row[1] as String,
        incomeThreshold: 0.0, // Assume 0 threshold for flat tax
        rate: parseAmount(row[3] as String), // Rate is at index 3
      );
    }

    return TaxScale(
      canton: canton,
      tariff: row[1] as String,
      incomeThreshold: parseAmount(row[3] as String),
      rate: parseAmount(row[4] as String),
    );
  }
}
