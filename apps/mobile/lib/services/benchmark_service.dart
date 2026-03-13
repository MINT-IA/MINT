/// Personal financial progress tracking service.
///
/// COMPLIANCE: No social comparison (CLAUDE.md § 6 — "No-Social-Comparison").
/// "top 20% des Suisses" → BANNED. Compare only to user's own past.
///
/// All methods compare the user's current values against their own previous
/// values or personal targets. No OFS/BFS percentile ranking.
class BenchmarkService {
  BenchmarkService._();

  /// Determine age bracket key for display purposes only.
  static String _ageBracket(int age) {
    if (age < 25) return '18-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    if (age < 65) return '55-64';
    return '65+';
  }

  /// Compare current savings vs previous savings (personal progression).
  ///
  /// [previousMonthlySavings] defaults to 0 if no prior data.
  /// Returns a [BenchmarkResult] with personal delta, no percentile.
  static BenchmarkResult compareSavings({
    required int age,
    required double monthlyNetIncome,
    required double monthlySavings,
    double previousMonthlySavings = 0,
  }) {
    final bracket = _ageBracket(age);
    final userRate = monthlyNetIncome > 0
        ? monthlySavings / monthlyNetIncome
        : 0.0;

    final delta = monthlySavings - previousMonthlySavings;

    return BenchmarkResult(
      userValue: monthlySavings,
      previousValue: previousMonthlySavings,
      delta: delta,
      bracket: bracket,
      message: _savingsMessage(userRate, monthlySavings, delta),
    );
  }

  /// Compare 3a participation vs user's own goal.
  static BenchmarkResult compare3a({
    required int age,
    required bool has3a,
    required double annualContribution,
    double previousAnnualContribution = 0,
  }) {
    final bracket = _ageBracket(age);

    if (!has3a) {
      return BenchmarkResult(
        userValue: 0,
        previousValue: previousAnnualContribution,
        delta: 0,
        bracket: bracket,
        message: 'Tu n\'as pas encore de 3e pilier. '
            'Ouvrir un 3a pourrait te permettre d\'économiser des impôts.',
      );
    }

    final delta = annualContribution - previousAnnualContribution;

    return BenchmarkResult(
      userValue: annualContribution,
      previousValue: previousAnnualContribution,
      delta: delta,
      bracket: bracket,
      message: _contributionMessage(annualContribution, delta),
    );
  }

  /// Compare emergency fund vs recommended 3-6 months target.
  static BenchmarkResult compareEmergencyFund({
    required int age,
    required double emergencyFundMonths,
    double previousEmergencyFundMonths = 0,
  }) {
    final bracket = _ageBracket(age);
    final delta = emergencyFundMonths - previousEmergencyFundMonths;

    return BenchmarkResult(
      userValue: emergencyFundMonths,
      previousValue: previousEmergencyFundMonths,
      delta: delta,
      bracket: bracket,
      message: _emergencyMessage(emergencyFundMonths, delta),
    );
  }

  // ── Private helpers ──────────────────────────────────────

  static String _savingsMessage(
      double userRate, double monthlySavings, double delta) {
    final ratePct = (userRate * 100).toStringAsFixed(0);
    if (delta > 0) {
      return 'Tu épargnes CHF\u00A0${delta.toStringAsFixed(0)}/mois de plus '
          'qu\'avant. Ton taux d\'épargne est de $ratePct%.';
    }
    if (monthlySavings > 0) {
      return 'Tu épargnes CHF\u00A0${monthlySavings.toStringAsFixed(0)}/mois, '
          'soit $ratePct% de ton revenu. Continue ainsi.';
    }
    return 'Chaque franc épargné compte. '
        'Commence petit et augmente progressivement.';
  }

  static String _contributionMessage(double contribution, double delta) {
    if (delta > 0) {
      return 'Ta cotisation 3a a augmenté de CHF\u00A0${delta.toStringAsFixed(0)} '
          'par rapport à avant. Continue sur cette lancée.';
    }
    if (contribution >= 7000) {
      return 'Tu es proche du plafond 3a. '
          'Chaque franc versé réduit tes impôts.';
    }
    return 'Ta cotisation 3a est de CHF\u00A0${contribution.toStringAsFixed(0)}/an. '
        'Augmenter ta cotisation pourrait amplifier tes économies d\'impôts.';
  }

  static String _emergencyMessage(double months, double delta) {
    if (months >= 3) {
      if (delta > 0) {
        return 'Ton fonds d\'urgence couvre ${months.toStringAsFixed(1)} mois '
            '(+${delta.toStringAsFixed(1)} mois par rapport à avant). '
            'Tu es dans la zone de confort recommandée (3-6 mois).';
      }
      return 'Ton fonds d\'urgence couvre ${months.toStringAsFixed(1)} mois — '
          'c\'est dans la zone de confort recommandée (3-6 mois).';
    }
    return 'La recommandation est 3-6 mois de charges. '
        'Tu en couvres ${months.toStringAsFixed(1)}. '
        'Chaque mois de réserve supplémentaire renforce ta sécurité.';
  }
}

/// Result of a personal progress comparison.
///
/// No percentile or social ranking — only personal delta.
class BenchmarkResult {
  final double userValue;
  final double previousValue;
  final double delta;
  final String bracket;
  final String message;

  const BenchmarkResult({
    required this.userValue,
    required this.previousValue,
    required this.delta,
    required this.bracket,
    required this.message,
  });
}
