/// Pure financial calculation functions (testable, no UI dependencies).
library;

/// Swiss legal max rates from 01.01.2026
const double maxRateCashCredit = 10.0;
const double maxRateOverdraft = 12.0;

/// Calculate compound interest with monthly contributions.
/// Returns a map with finalValue, totalInvested, and gains.
Map<String, double> calculateCompoundInterest({
  required double principal,
  required double monthlyContribution,
  required double annualRate,
  required int years,
}) {
  final double r = annualRate / 100 / 12; // monthly rate
  final int n = years * 12; // total months

  double finalValue;
  if (r == 0) {
    finalValue = principal + monthlyContribution * n;
  } else {
    // Future value of principal
    final double fvPrincipal = principal * _pow(1 + r, n);
    // Future value of annuity (monthly contributions)
    final double fvAnnuity =
        monthlyContribution * ((_pow(1 + r, n) - 1) / r);
    finalValue = fvPrincipal + fvAnnuity;
  }

  final double totalInvested = principal + monthlyContribution * n;
  final double gains = finalValue - totalInvested;

  return {
    'finalValue': _round(finalValue),
    'totalInvested': _round(totalInvested),
    'gains': _round(gains),
  };
}

/// Calculate the opportunity cost of leasing vs investing.
Map<String, dynamic> calculateLeasingOpportunityCost({
  required double monthlyPayment,
  required int durationMonths,
  required double alternativeAnnualRate,
  List<int> projectionYears = const [5, 10, 20],
}) {
  final Map<String, double> opportunityCost = {};

  for (final years in projectionYears) {
    final result = calculateCompoundInterest(
      principal: 0,
      monthlyContribution: monthlyPayment,
      annualRate: alternativeAnnualRate,
      years: years,
    );
    opportunityCost['${years}y'] = result['finalValue']!;
  }

  return {
    'totalLeasingCost': _round(monthlyPayment * durationMonths),
    'opportunityCost': opportunityCost,
  };
}

/// Calculate 3a tax benefit and potential growth.
Map<String, double> calculate3aTaxBenefit({
  required double annualContribution,
  required double marginalTaxRate,
  required int years,
  double annualReturn = 4.0,
}) {
  final double annualTaxSaved = annualContribution * marginalTaxRate;
  final double totalContributions = annualContribution * years;
  final double totalTaxSaved = annualTaxSaved * years;

  final result = calculateCompoundInterest(
    principal: 0,
    monthlyContribution: annualContribution / 12,
    annualRate: annualReturn,
    years: years,
  );

  return {
    'annualTaxSaved': _round(annualTaxSaved),
    'totalTaxSavedOverPeriod': _round(totalTaxSaved),
    'potentialFinalValue': result['finalValue']!,
    'totalContributions': _round(totalContributions),
  };
}

/// Calculate consumer credit / micro-credit total cost.
/// Returns monthly payment, total interest, total cost, and rate warning.
Map<String, dynamic> calculateConsumerCredit({
  required double amount,
  required int durationMonths,
  required double annualRate,
  double fees = 0.0,
}) {
  if (durationMonths <= 0) {
    return {'error': 'Duration must be positive'};
  }

  final double monthlyRate = annualRate / 100 / 12;

  double monthlyPayment;
  double totalInterest;

  if (monthlyRate == 0) {
    monthlyPayment = amount / durationMonths;
    totalInterest = 0;
  } else {
    // Standard amortizing loan formula
    monthlyPayment = amount *
        (monthlyRate * _pow(1 + monthlyRate, durationMonths)) /
        (_pow(1 + monthlyRate, durationMonths) - 1);
    totalInterest = (monthlyPayment * durationMonths) - amount;
  }

  final double totalCost = amount + totalInterest + fees;
  final double effectiveRate = annualRate; // Simplified

  // Rate warning based on Swiss legal max (2026)
  final bool rateWarning = annualRate >= maxRateCashCredit;

  return {
    'monthlyPayment': _round(monthlyPayment),
    'totalInterest': _round(totalInterest),
    'totalCost': _round(totalCost),
    'effectiveRate': _round(effectiveRate),
    'rateWarning': rateWarning,
    'legalMaxRate': maxRateCashCredit,
  };
}

/// Calculate debt risk score from questionnaire answers.
/// Returns score, risk level, and tailored recommendations.
Map<String, dynamic> calculateDebtRiskScore({
  required bool hasRegularOverdrafts,
  required bool hasMultipleCredits,
  required bool hasLatePayments,
  required bool hasDebtCollection,
  required bool hasImpulsiveBuying,
  required bool hasGamblingHabit,
}) {
  final factors = [
    hasRegularOverdrafts,
    hasMultipleCredits,
    hasLatePayments,
    hasDebtCollection,
    hasImpulsiveBuying,
    hasGamblingHabit,
  ];
  final int score = factors.where((f) => f).length;

  String riskLevel;
  List<String> recommendations;

  if (score <= 1) {
    riskLevel = 'low';
    recommendations = [
      'Continuez à surveiller vos finances.',
      'Constituez une épargne de précaution (3-6 mois de charges).',
    ];
  } else if (score <= 3) {
    riskLevel = 'medium';
    recommendations = [
      'Faites un budget mensuel détaillé.',
      'Évitez tout nouveau crédit.',
      'Consultez les ressources de prévention (Caritas, Dettes Conseils Suisse).',
    ];
  } else {
    riskLevel = 'high';
    recommendations = [
      'Contactez un service de conseil en dettes dès que possible.',
      'Ne contractez aucun nouveau crédit.',
      'Parlez à un professionnel de votre situation.',
    ];
  }

  // Add gambling-specific recommendation
  if (hasGamblingHabit) {
    recommendations.add(
      'Pour les jeux d\'argent : envisagez de fixer des limites ou de vous auto-exclure.',
    );
  }

  return {
    'riskScore': score,
    'riskLevel': riskLevel,
    'recommendations': recommendations,
    'hasGamblingRisk': hasGamblingHabit,
  };
}

// Helper functions
double _pow(double base, int exp) {
  double result = 1;
  for (int i = 0; i < exp; i++) {
    result *= base;
  }
  return result;
}

double _round(double value) {
  return (value * 100).round() / 100;
}

