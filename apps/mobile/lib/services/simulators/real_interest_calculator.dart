import 'dart:math';

class RealInterestSimulationResult {
  final double netInvested;
  final RealInterestScenario pessimistic;
  final RealInterestScenario neutral;
  final RealInterestScenario optimistic;
  final Map<String, dynamic> assumptions;

  RealInterestSimulationResult({
    required this.netInvested,
    required this.pessimistic,
    required this.neutral,
    required this.optimistic,
    required this.assumptions,
  });
}

class RealInterestScenario {
  final double totalCapital;
  final double effectiveYield;

  RealInterestScenario(
      {required this.totalCapital, required this.effectiveYield});
}

/// Calculateur pédagogique : Intérêt Réel (3a/LPP)
/// Montre l'effet levier de l'économie fiscale.
class RealInterestCalculator {
  static RealInterestSimulationResult simulate({
    required double amountInvested,
    required double marginalTaxRate,
    required int investmentDurationYears,
    double? customYieldPessimistic,
    double? customYieldNeutral,
    double? customYieldOptimistic,
  }) {
    // 1. Calcul de l'effort net d'épargne
    // L'économie d'impôt est considérée comme "déjà gagnée" ou "non-sortie" de la poche.
    // Effort Net = Montant Versé - (Montant Versé * Taux Marginal)
    // Ex: Versé 7000, Taux 25%. Impôt économisé = 1750. Effort = 5250.
    final taxSaving = amountInvested * marginalTaxRate;
    final netInvested = amountInvested - taxSaving;

    // 2. Définition des scénarios de rendement marché (Hypothèses)
    final ratePessimistic = customYieldPessimistic ?? 0.02; // 2%
    final rateNeutral = customYieldNeutral ?? 0.04; // 4%
    final rateOptimistic = customYieldOptimistic ?? 0.06; // 6%

    // 3. Projection du Capital Final (Capitalisation composée)
    // Basé sur le MONTANT BRUT INVESTI (car c'est lui qui travaille)
    // On assume ici que c'est un versement UNIQUE (pour simplifier la pédagogie de l'instant)
    final capitalPessimistic = _compoundInterest(
        amountInvested, ratePessimistic, investmentDurationYears);
    final capitalNeutral =
        _compoundInterest(amountInvested, rateNeutral, investmentDurationYears);
    final capitalOptimistic = _compoundInterest(
        amountInvested, rateOptimistic, investmentDurationYears);

    // 4. Calcul du rendement effectif (ROI sur l'effort net)
    // (Final / NetInvested)^(1/n) - 1

    return RealInterestSimulationResult(
      netInvested: netInvested,
      pessimistic: RealInterestScenario(
        totalCapital: capitalPessimistic,
        effectiveYield: _calculateCAGR(
            netInvested, capitalPessimistic, investmentDurationYears),
      ),
      neutral: RealInterestScenario(
        totalCapital: capitalNeutral,
        effectiveYield: _calculateCAGR(
            netInvested, capitalNeutral, investmentDurationYears),
      ),
      optimistic: RealInterestScenario(
        totalCapital: capitalOptimistic,
        effectiveYield: _calculateCAGR(
            netInvested, capitalOptimistic, investmentDurationYears),
      ),
      assumptions: {
        'tax_rate_used': marginalTaxRate,
        'pessimistic_rate': ratePessimistic,
        'neutral_rate': rateNeutral,
        'optimistic_rate': rateOptimistic,
        'duration_years': investmentDurationYears,
        'formula': 'Simulated Lump Sum Investment',
      },
    );
  }

  static double _compoundInterest(double principal, double rate, int years) {
    if (years == 0) return principal;
    return principal * pow(1 + rate, years);
  }

  static double _calculateCAGR(double start, double end, int years) {
    if (start <= 0 || years <= 0) return 0.0;
    return pow(end / start, 1 / years) - 1;
  }
}
