// Pure Dart calculator for LPP Rente vs Capital comparison.
//
// Faithfully ports the Python logic from
// services/backend/app/services/retirement/lpp_conversion_service.py
//
// Sources:
// - LPP art. 14 al. 2 (taux de conversion minimum 6.8%)
// - LIFD art. 38 (imposition du capital de prevoyance)

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

// LPP conversion rate: use centralized constant from social_insurance.dart
// (lppTauxConversionMinDecimal = 0.068)

/// All 26 supported Swiss cantons.
List<String> get supportedCantons => sortedCantonCodes;

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
    if (breakEvenMois != null) {
      // Capital exhausted — stay at 0
      values.add(0.0);
      continue;
    }
    capital = capital * (1 + rendementMensuel) - retraitMensuel;
    if (capital <= 0) {
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
/// Supports all 26 Swiss cantons with progressive tax brackets.
/// Throws [ArgumentError] if canton is not supported.
RenteVsCapitalResult computeRenteVsCapital({
  required double avoirObligatoire,
  required double avoirSurobligatoire,
  required double tauxConversionSurob,
  required int ageRetraite,
  required String canton,
  required String statutCivil,
  double? retraitMensuelOverride,
}) {
  final renteAnnuelle =
      avoirObligatoire * lppTauxConversionMinDecimal +
      avoirSurobligatoire * tauxConversionSurob;
  final renteMensuelle = renteAnnuelle / 12;

  final capitalTotal = avoirObligatoire + avoirSurobligatoire;

  // Look up base cantonal rate (26 cantons)
  final baseRate = tauxImpotRetraitCapital[canton];
  if (baseRate == null) {
    throw ArgumentError('Canton non supporte: $canton');
  }

  // Apply married discount (splitting cantonal ~15%)
  final effectiveBaseRate = statutCivil == 'married'
      ? baseRate * marriedCapitalTaxDiscount
      : baseRate;

  // Progressive tax calculation (mirrors backend)
  final impotRetrait = double.parse(
      RetirementTaxCalculator.progressiveTax(capitalTotal, effectiveBaseRate)
          .toStringAsFixed(2));
  final tauxEffectif = capitalTotal > 0 ? impotRetrait / capitalTotal : 0.0;
  final capitalNet = capitalTotal - impotRetrait;

  // Use custom withdrawal if provided, otherwise match rente
  final retraitMensuel = retraitMensuelOverride ?? renteMensuelle;

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
      retraitMensuel: retraitMensuel,
      rendementAnnuel: rendement,
      nbMois: nbMois85,
    );

    final resMax = _simulateCapitalDrawdown(
      capitalNet: capitalNet,
      retraitMensuel: retraitMensuel,
      rendementAnnuel: rendement,
      nbMois: nbMoisMax,
    );

    final resChart = _simulateCapitalDrawdown(
      capitalNet: capitalNet,
      retraitMensuel: retraitMensuel,
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
