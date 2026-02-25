/// Anonymous financial benchmarks based on OFS/BFS Swiss statistics.
///
/// All data is sourced from publicly available Swiss federal statistics:
/// - OFS Enquête sur le budget des ménages (EBM) 2022/2023
/// - OFS Statistique des revenus et des conditions de vie (SILC) 2023
/// - OFS Statistique de l'épargne et de la fortune (2023)
///
/// No user data is shared or compared with other users.
/// These are static reference points from official Swiss surveys.
class BenchmarkService {
  BenchmarkService._();

  /// Swiss median savings rate by age bracket (% of net income).
  /// Source: OFS EBM 2022 — taux d'épargne net médian.
  static const Map<String, double> _savingsRateByAge = {
    '18-24': 0.05, // étudiants + premiers emplois
    '25-34': 0.12,
    '35-44': 0.10, // charge familiale maximale
    '45-54': 0.14,
    '55-64': 0.18, // enfants partis, rattrapage retraite
    '65+': 0.08,
  };

  /// Swiss median net income by age bracket (CHF/month).
  /// Source: OFS SILC 2023 — revenu disponible équivalent médian.
  static const Map<String, double> _medianIncomeByAge = {
    '18-24': 3200,
    '25-34': 5400,
    '35-44': 6200,
    '45-54': 6800,
    '55-64': 6500,
    '65+': 4800,
  };

  /// Share of Swiss population with a 3a account by age bracket.
  /// Source: OFS/ASA Statistique prévoyance privée 2023.
  static const Map<String, double> _has3aByAge = {
    '18-24': 0.15,
    '25-34': 0.52,
    '35-44': 0.61,
    '45-54': 0.67,
    '55-64': 0.72,
    '65+': 0.10, // retrait à la retraite
  };

  /// Swiss median emergency fund coverage (months of expenses).
  /// Source: OFS Enquête budget ménages 2022.
  static const Map<String, double> _emergencyFundMonthsByAge = {
    '18-24': 0.8,
    '25-34': 1.5,
    '35-44': 2.2,
    '45-54': 3.5,
    '55-64': 5.0,
    '65+': 8.0,
  };

  /// Determine age bracket key from birth year.
  static String _ageBracket(int age) {
    if (age < 25) return '18-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    if (age < 65) return '55-64';
    return '65+';
  }

  /// Compute savings percentile relative to Swiss average.
  ///
  /// Returns a [BenchmarkResult] with the user's ranking.
  static BenchmarkResult compareSavings({
    required int age,
    required double monthlyNetIncome,
    required double monthlySavings,
  }) {
    final bracket = _ageBracket(age);
    final medianRate = _savingsRateByAge[bracket] ?? 0.10;
    final medianIncome = _medianIncomeByAge[bracket] ?? 5000;

    final userRate = monthlyNetIncome > 0
        ? monthlySavings / monthlyNetIncome
        : 0.0;

    // Estimate percentile using a simplified normal distribution
    // around the median savings rate (std dev ≈ 0.08).
    final percentile = _estimatePercentile(userRate, medianRate, 0.08);

    final medianSavings = medianIncome * medianRate;
    final delta = monthlySavings - medianSavings;

    return BenchmarkResult(
      percentile: percentile,
      medianValue: medianSavings,
      userValue: monthlySavings,
      delta: delta,
      bracket: bracket,
      message: _savingsMessage(percentile, bracket, delta),
    );
  }

  /// Compare 3a participation vs Swiss average.
  static BenchmarkResult compare3a({
    required int age,
    required bool has3a,
    required double annualContribution,
  }) {
    final bracket = _ageBracket(age);
    final adoptionRate = _has3aByAge[bracket] ?? 0.50;

    if (!has3a) {
      final missingPercent = (adoptionRate * 100).round();
      return BenchmarkResult(
        percentile: ((1 - adoptionRate) * 100).round(),
        medianValue: adoptionRate * 100,
        userValue: 0,
        delta: 0,
        bracket: bracket,
        message: '$missingPercent% des $bracket ans en Suisse ont un 3e pilier. '
            'Tu pourrais rejoindre ce groupe et potentiellement économiser des impôts.',
      );
    }

    // For 3a contributors, compare contribution amount
    // Median 3a contribution: ~CHF 5'500/year (OFS 2023).
    const medianContribution = 5500.0;
    final percentile = _estimatePercentile(
        annualContribution, medianContribution, 2000);

    return BenchmarkResult(
      percentile: percentile,
      medianValue: medianContribution,
      userValue: annualContribution,
      delta: annualContribution - medianContribution,
      bracket: bracket,
      message: _contributionMessage(percentile, annualContribution),
    );
  }

  /// Compare emergency fund vs Swiss median.
  static BenchmarkResult compareEmergencyFund({
    required int age,
    required double emergencyFundMonths,
  }) {
    final bracket = _ageBracket(age);
    final median = _emergencyFundMonthsByAge[bracket] ?? 2.0;
    final percentile = _estimatePercentile(emergencyFundMonths, median, 1.5);

    return BenchmarkResult(
      percentile: percentile,
      medianValue: median,
      userValue: emergencyFundMonths,
      delta: emergencyFundMonths - median,
      bracket: bracket,
      message: _emergencyMessage(percentile, emergencyFundMonths, median, bracket),
    );
  }

  // ── Private helpers ──────────────────────────────────────

  static int _estimatePercentile(double value, double median, double stdDev) {
    if (stdDev <= 0) return 50;
    final z = (value - median) / stdDev;
    // Approximate CDF using logistic function (close to normal for |z| < 3)
    final p = 1.0 / (1.0 + _exp(-1.7 * z));
    return (p * 100).round().clamp(1, 99);
  }

  static double _exp(double x) {
    // Clamp to avoid overflow
    if (x > 20) return 4.85e8;
    if (x < -20) return 2.06e-9;
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  static String _savingsMessage(int percentile, String bracket, double delta) {
    if (percentile >= 75) {
      return 'Tu épargnes plus que $percentile% des $bracket ans en Suisse. Continue ainsi.';
    }
    if (percentile >= 50) {
      return 'Ton taux d\'épargne est dans la moyenne suisse pour les $bracket ans.';
    }
    if (delta.abs() < 100) {
      return 'Ton épargne est proche de la médiane suisse pour les $bracket ans.';
    }
    return 'La médiane suisse pour les $bracket ans est CHF ${delta.abs().toStringAsFixed(0)}/mois de plus. '
        'Chaque petit pas compte.';
  }

  static String _contributionMessage(int percentile, double contribution) {
    if (percentile >= 75) {
      return 'Ta cotisation 3a est supérieure à celle de $percentile% des cotisant·e·s suisses.';
    }
    if (percentile >= 50) {
      return 'Ta cotisation 3a est dans la moyenne des cotisant·e·s suisses.';
    }
    return 'La médiane des cotisations 3a en Suisse est ~CHF 5\'500/an. '
        'Augmenter ta cotisation pourrait amplifier tes économies d\'impôts.';
  }

  static String _emergencyMessage(
      int percentile, double months, double median, String bracket) {
    if (months >= 3) {
      return 'Ton fonds d\'urgence couvre ${months.toStringAsFixed(1)} mois — '
          'c\'est ${percentile >= 50 ? 'au-dessus' : 'proche'} de la médiane suisse '
          '(${median.toStringAsFixed(1)} mois pour les $bracket ans).';
    }
    return 'La recommandation suisse est 3-6 mois de charges. '
        'Tu en couvres ${months.toStringAsFixed(1)}. '
        'La médiane pour les $bracket ans est ${median.toStringAsFixed(1)} mois.';
  }
}

/// Result of a benchmark comparison.
class BenchmarkResult {
  final int percentile;
  final double medianValue;
  final double userValue;
  final double delta;
  final String bracket;
  final String message;

  const BenchmarkResult({
    required this.percentile,
    required this.medianValue,
    required this.userValue,
    required this.delta,
    required this.bracket,
    required this.message,
  });
}
