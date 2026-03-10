import 'package:mint_mobile/services/financial_core/financial_core.dart';

class BuybackStaggeringResult {
  final double singleShotTaxSaving;
  final double staggeredTotalTaxSaving;
  final double delta;
  final String disclaimer;

  BuybackStaggeringResult({
    required this.singleShotTaxSaving,
    required this.staggeredTotalTaxSaving,
    required this.delta,
    required this.disclaimer,
  });
}

class BuybackSimulator {
  /// Estime l'avantage du lissage de rachat LPP sur plusieurs années.
  ///
  /// Logique simplifiée : L'impôt suisse étant progressif, déduire un énorme montant (Single Shot)
  /// peut parfois faire "gaspiller" la déduction sur des tranches à taux bas, VOIRE réduire le taux
  /// à un niveau très bas.
  ///
  /// CEPENDANT, contrairement à l'impôt sur le RETRAIT (où lisser réduit le taux car progressif),
  /// pour la DÉDUCTION, l'effet dépend de si on "casse" le taux marginal max.
  ///
  /// Si revenu = 150k. Taux marginal stable ~30% jusqu'à 100k.
  /// Deduct 100k -> Reste 50k. On a économisé du 30% sur 50k, puis du 20% sur 30k...
  ///
  /// Si on déduit 20k par an pendant 5 ans. -> Reste 130k/an.
  /// On économise le taux marginal (30%) SUR TOUTE LA SOMME.
  ///
  /// Donc oui, le lissage est gagnant pour les DÉDUCTIONS tant que le taux marginal est décroissant
  /// (ce qui est toujours le cas par définition de la progressivité !).
  ///
  static BuybackStaggeringResult compareStaggering({
    required double totalBuybackAmount,
    required int years,
    required double taxableIncome,
    required String canton,
    required String civilStatus,
  }) {
    // 1. Estimation "Single Shot"
    // On doit estimer l'impôt SANS rachat et AVEC rachat TOTAL.
    // Note: Pour ce MVP, on utilise une heuristique de courbe progressive simple
    // ou on injecte le TaxEstimatorService si dispo.
    // Ici, faisons une simulation courbe convexe quadratique simple pour illustrer pédagogiquement.
    // Tax = Rate * Income. Rate grows with Income.

    // Heuristique simple de l'économie fiscale (Marginal Rate Decay)
    // Saving = Integral of Marginal Rate from (Income - Deduction) to Income.

    double singleShotSaving =
        _estimateTaxSaving(taxableIncome, totalBuybackAmount, canton);

    // 2. Estimation "Staggered"
    // Deduction par an = Total / Years
    double yearlyDeduction = totalBuybackAmount / years;
    double yearlySaving =
        _estimateTaxSaving(taxableIncome, yearlyDeduction, canton);

    double staggeredTotalSaving = yearlySaving * years;

    return BuybackStaggeringResult(
      singleShotTaxSaving: singleShotSaving,
      staggeredTotalTaxSaving: staggeredTotalSaving,
      delta: staggeredTotalSaving - singleShotSaving,
      disclaimer:
          "Simulation pédagogique basée sur une progressivité moyenne. Sous réserve d'acceptation par l'administration fiscale. Le lissage abusif (ex: 3 ans avant retrait capital) peut être requalifié.",
    );
  }

  /// Estime l'économie d'impôt d'une déduction donnée sur le revenu donné.
  /// Delegates to RetirementTaxCalculator.estimateMarginalRate() from financial_core.
  static double _estimateTaxSaving(
      double income, double deduction, String canton) {
    if (deduction <= 0) return 0.0;

    // Numerical integration over the deduction range using the canton-aware
    // marginal rate from financial_core. We slice the deduction into steps
    // and sum the marginal tax saved at each income level.
    const int steps = 10;
    final double stepSize = deduction / steps;
    double currentIncome = income;
    double totallySaved = 0.0;

    for (int i = 0; i < steps; i++) {
      final double midPoint = currentIncome - (stepSize / 2);
      final double rate =
          RetirementTaxCalculator.estimateMarginalRate(midPoint, canton);
      totallySaved += stepSize * rate;
      currentIncome -= stepSize;
    }

    return totallySaved;
  }
}
