import 'package:mint_mobile/constants/social_insurance.dart';

/// A single year entry in the retroactive 3a breakdown.
class YearlyRetroactiveEntry {
  /// The calendar year this entry represents.
  final int year;

  /// The 3a limit applicable for that year.
  final double limit;

  /// Whether this contribution is tax-deductible in the reference year.
  final bool deductible;

  const YearlyRetroactiveEntry({
    required this.year,
    required this.limit,
    this.deductible = true,
  });
}

/// Result of a retroactive 3a calculation.
class Retroactive3aResult {
  /// Number of gap years effectively used (clamped 1-10).
  final int gapYears;

  /// Sum of all retroactive yearly limits.
  final double totalRetroactive;

  /// Current year 3a limit (not part of retroactive).
  final double totalCurrentYear;

  /// totalRetroactive + totalCurrentYear.
  final double totalContribution;

  /// Estimated tax savings: totalRetroactive * tauxMarginal.
  final double economiesFiscales;

  /// Per-year breakdown (most recent gap year first).
  final List<YearlyRetroactiveEntry> breakdown;

  /// One-liner impact number for the user.
  final String chiffreChoc;

  /// Educational disclaimer (LSFin / OPP3).
  final String disclaimer;

  /// Legal references.
  final List<String> sources;

  const Retroactive3aResult({
    required this.gapYears,
    required this.totalRetroactive,
    required this.totalCurrentYear,
    required this.totalContribution,
    required this.economiesFiscales,
    required this.breakdown,
    required this.chiffreChoc,
    required this.disclaimer,
    required this.sources,
  });
}

/// Pure-function calculator for the retroactive Pillar 3a catch-up
/// available from 2026 under OPP3 art. 7 (amendment).
///
/// Allows Swiss residents to contribute for up to 10 missed years
/// in addition to the current-year contribution, deductible in the
/// year the payment is made.
class Retroactive3aCalculator {
  Retroactive3aCalculator._();

  /// Calculate retroactive 3a potential.
  ///
  /// [gapYears] — number of past years without 3a contributions (clamped 1-10).
  /// [tauxMarginal] — user's marginal tax rate as a decimal (e.g. 0.35 for 35%).
  /// [hasLpp] — true if affiliated to a pension fund (small 3a), false for independent without LPP (large 3a).
  /// [referenceYear] — the year the catch-up payment is made (default 2026).
  static Retroactive3aResult calculate({
    required int gapYears,
    required double tauxMarginal,
    bool hasLpp = true,
    int referenceYear = 2026,
  }) {
    final effectiveGap = gapYears.clamp(1, pilier3aMaxRetroactiveYears);

    // Scaling factor for sans-LPP (large 3a).
    final scaleFactor =
        hasLpp ? 1.0 : pilier3aPlafondSansLpp / pilier3aPlafondAvecLpp;

    // Build yearly breakdown (most recent gap year first).
    final breakdown = <YearlyRetroactiveEntry>[];
    double totalRetroactive = 0;

    for (int i = 1; i <= effectiveGap; i++) {
      final year = referenceYear - i;
      final baseLimit = pilier3aHistoricalLimits[year] ?? 6768.0;
      final effectiveLimit = baseLimit * scaleFactor;
      totalRetroactive += effectiveLimit;
      breakdown.add(YearlyRetroactiveEntry(year: year, limit: effectiveLimit));
    }

    // Current year contribution (not retroactive, but part of total).
    final currentYearLimit =
        hasLpp ? pilier3aPlafondAvecLpp : pilier3aPlafondSansLpp;
    final totalContribution = totalRetroactive + currentYearLimit;

    // Tax savings — all retroactive amounts deductible in referenceYear.
    final economiesFiscales = totalRetroactive * tauxMarginal;

    // Chiffre choc.
    final savingsFormatted = _formatChf(economiesFiscales);
    final chiffreChoc =
        'Tu peux rattraper $effectiveGap an${effectiveGap > 1 ? "s" : ""} '
        "d'\u00e9pargne 3a et \u00e9conomiser $savingsFormatted d'imp\u00f4ts "
        'en $referenceYear.';

    return Retroactive3aResult(
      gapYears: effectiveGap,
      totalRetroactive: totalRetroactive,
      totalCurrentYear: currentYearLimit,
      totalContribution: totalContribution,
      economiesFiscales: economiesFiscales,
      breakdown: breakdown,
      chiffreChoc: chiffreChoc,
      disclaimer:
          'Outil \u00e9ducatif\u00a0\u2014 ne constitue pas un conseil fiscal (LSFin). '
          'Le rattrapage 3a est disponible d\u00e8s 2026 (OPP3 art. 7). '
          "L'\u00e9conomie fiscale d\u00e9pend de ton taux marginal r\u00e9el.",
      sources: const [
        'OPP3 art. 7 (amendement 2026)',
        'LIFD art. 33 al. 1 let. e',
        'Plafonds annuels OFAS',
      ],
    );
  }

  /// Format a CHF amount with apostrophe thousands separator.
  static String _formatChf(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0 && str[i - 1] != '-') {
        buffer.write("'");
      }
    }
    return 'CHF\u00a0${buffer.toString().split("").reversed.join()}';
  }
}
