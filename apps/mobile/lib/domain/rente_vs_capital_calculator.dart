// Pure Dart calculator for LPP Rente vs Capital comparison.
//
// Faithfully ports the Python logic from services/backend/app/services/rules_engine.py
// (compute_rente_vs_capital + _simulate_capital_drawdown).
//
// Sources:
// - LPP art. 14 al. 2 (taux de conversion minimum 6.8%)
// - LIFD art. 38 (imposition du capital de prevoyance)

/// Capital withdrawal tax rates by canton and civil status.
/// Format: {canton: {status: [rate_below_500k, rate_at_or_above_500k]}}
/// Source: Baremes fiscaux cantonaux 2024, retrait en capital prevoyance.
const Map<String, Map<String, List<double>>> capitalWithdrawalTaxRates = {
  'ZH': {'single': [0.055, 0.080], 'married': [0.045, 0.065]},
  'BE': {'single': [0.065, 0.095], 'married': [0.055, 0.080]},
  'VD': {'single': [0.080, 0.115], 'married': [0.070, 0.100]},
  'GE': {'single': [0.075, 0.105], 'married': [0.065, 0.095]},
  'LU': {'single': [0.040, 0.060], 'married': [0.035, 0.050]},
  'BS': {'single': [0.070, 0.100], 'married': [0.060, 0.085]},
};

const double _capitalTaxThreshold = 500000.0;
const double _lppConversionRate = 0.068;

/// Supported cantons for the simulator.
const List<String> supportedCantons = ['ZH', 'BE', 'VD', 'GE', 'LU', 'BS'];

/// Internal result of a drawdown simulation.
class _DrawdownResult {
  final double capitalAtEnd;
  final int? breakEvenMonth;
  final List<double> monthlyValues;

  const _DrawdownResult({
    required this.capitalAtEnd,
    this.breakEvenMonth,
    required this.monthlyValues,
  });
}

/// Result of a single scenario simulation.
class ScenarioResult {
  final String name;
  final double rendement;
  final double capital85;
  final double? breakEvenAge;
  final List<double> capitalTimeSeries;

  const ScenarioResult({
    required this.name,
    required this.rendement,
    required this.capital85,
    this.breakEvenAge,
    required this.capitalTimeSeries,
  });
}

/// Full result of rente vs capital comparison.
class RenteVsCapitalResult {
  final double renteAnnuelle;
  final double renteMensuelle;
  final double capitalTotal;
  final double impotRetrait;
  final double tauxEffectif;
  final double capitalNet;
  final Map<String, ScenarioResult> scenarios;

  const RenteVsCapitalResult({
    required this.renteAnnuelle,
    required this.renteMensuelle,
    required this.capitalTotal,
    required this.impotRetrait,
    required this.tauxEffectif,
    required this.capitalNet,
    required this.scenarios,
  });
}

/// Simulate month-by-month capital drawdown with returns.
_DrawdownResult _simulateCapitalDrawdown({
  required double capitalNet,
  required double retraitMensuel,
  required double rendementAnnuel,
  required int nbMois,
}) {
  final rendementMensuel = rendementAnnuel / 12;
  double capital = capitalNet;
  int? breakEvenMois;
  final values = <double>[capital];

  for (int mois = 1; mois <= nbMois; mois++) {
    capital = capital * (1 + rendementMensuel) - retraitMensuel;
    if (capital <= 0 && breakEvenMois == null) {
      breakEvenMois = mois;
      capital = 0.0;
    }
    values.add(capital);
  }

  return _DrawdownResult(
    capitalAtEnd: capital,
    breakEvenMonth: breakEvenMois,
    monthlyValues: values,
  );
}

/// Compare rente viagere LPP vs retrait en capital on 3 scenarios.
///
/// Throws [ArgumentError] if canton/status combination is not supported.
RenteVsCapitalResult computeRenteVsCapital({
  required double avoirObligatoire,
  required double avoirSurobligatoire,
  required double tauxConversionSurob,
  required int ageRetraite,
  required String canton,
  required String statutCivil,
}) {
  final renteAnnuelle =
      avoirObligatoire * _lppConversionRate +
      avoirSurobligatoire * tauxConversionSurob;
  final renteMensuelle = renteAnnuelle / 12;

  final capitalTotal = avoirObligatoire + avoirSurobligatoire;

  final cantonRates = capitalWithdrawalTaxRates[canton];
  if (cantonRates == null || !cantonRates.containsKey(statutCivil)) {
    throw ArgumentError('Canton/statut non supporte: $canton/$statutCivil');
  }

  final rates = cantonRates[statutCivil]!;
  final tauxBas = rates[0];
  final tauxHaut = rates[1];
  final tauxEffectif =
      capitalTotal < _capitalTaxThreshold ? tauxBas : tauxHaut;
  final impotRetrait = capitalTotal * tauxEffectif;
  final capitalNet = capitalTotal - impotRetrait;

  final nbMois85 = (85 - ageRetraite) * 12;
  final nbMoisMax = (150 - ageRetraite) * 12;
  final nbMoisChart = (100 - ageRetraite) * 12;

  final scenarioParams = <String, double>{
    'prudent': 0.01,
    'central': 0.03,
    'optimiste': 0.05,
  };

  final scenarios = <String, ScenarioResult>{};

  for (final entry in scenarioParams.entries) {
    final nom = entry.key;
    final rendement = entry.value;

    final res85 = _simulateCapitalDrawdown(
      capitalNet: capitalNet,
      retraitMensuel: renteMensuelle,
      rendementAnnuel: rendement,
      nbMois: nbMois85,
    );

    final resMax = _simulateCapitalDrawdown(
      capitalNet: capitalNet,
      retraitMensuel: renteMensuelle,
      rendementAnnuel: rendement,
      nbMois: nbMoisMax,
    );

    final resChart = _simulateCapitalDrawdown(
      capitalNet: capitalNet,
      retraitMensuel: renteMensuelle,
      rendementAnnuel: rendement,
      nbMois: nbMoisChart,
    );

    // Extract yearly values for the chart
    final yearlyValues = <double>[];
    for (int i = 0; i <= nbMoisChart; i += 12) {
      if (i < resChart.monthlyValues.length) {
        yearlyValues.add(resChart.monthlyValues[i]);
      }
    }

    final capital85 =
        res85.capitalAtEnd > 0 ? res85.capitalAtEnd : 0.0;
    double? breakEvenAge;
    if (resMax.breakEvenMonth != null) {
      breakEvenAge = ageRetraite + resMax.breakEvenMonth! / 12;
      breakEvenAge = (breakEvenAge * 10).round() / 10;
    }

    scenarios[nom] = ScenarioResult(
      name: nom,
      rendement: rendement,
      capital85: double.parse(capital85.toStringAsFixed(2)),
      breakEvenAge: breakEvenAge,
      capitalTimeSeries: yearlyValues,
    );
  }

  return RenteVsCapitalResult(
    renteAnnuelle: double.parse(renteAnnuelle.toStringAsFixed(2)),
    renteMensuelle: double.parse(renteMensuelle.toStringAsFixed(2)),
    capitalTotal: double.parse(capitalTotal.toStringAsFixed(2)),
    impotRetrait: double.parse(impotRetrait.toStringAsFixed(2)),
    tauxEffectif: tauxEffectif,
    capitalNet: double.parse(capitalNet.toStringAsFixed(2)),
    scenarios: scenarios,
  );
}
