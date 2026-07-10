import 'dart:math' show min;

import 'package:mint_mobile/constants/social_insurance.dart';

enum UnemploymentIneligibilityReason {
  invalidMonthlyEarnings,
  insufficientContributions,
}

class UnemploymentCoreResult {
  const UnemploymentCoreResult({
    required this.eligible,
    required this.ineligibilityReason,
    required this.rate,
    required this.retainedMonthlyEarnings,
    required this.dailyBenefit,
    required this.monthlyBenefit,
    required this.dailyBenefitCount,
    required this.coverageMonths,
    required this.waitingPeriodDays,
    required this.monthlyLoss,
  });

  final bool eligible;
  final UnemploymentIneligibilityReason? ineligibilityReason;
  final double rate;
  final double retainedMonthlyEarnings;
  final double dailyBenefit;
  final double monthlyBenefit;
  final int dailyBenefitCount;
  final double coverageMonths;
  final int waitingPeriodDays;
  final double monthlyLoss;
}

class UnemploymentCalculator {
  UnemploymentCalculator._();

  static const double _baseRate = 0.70;
  static const double _enhancedRate = 0.80;
  static const int _standardWaitingPeriodDays = 5;
  static const double _workingDaysPerMonth = acJoursOuvrablesMoisMoyen;

  static double get _maxMonthlyInsuredEarnings =>
      reg('ac.max_monthly_insured_income', acGainAssureMensuelMax);

  static double get _enhancedRateThreshold =>
      reg('ac.enhanced_rate_threshold', acSeuilSalaireMajore);

  static UnemploymentCoreResult compute({
    required double monthlyInsuredEarnings,
    required int age,
    required int contributionMonths,
    bool hasChildren = false,
    bool hasDisability = false,
  }) {
    if (monthlyInsuredEarnings <= 0) {
      return _notEligible(
        UnemploymentIneligibilityReason.invalidMonthlyEarnings,
      );
    }

    if (contributionMonths < 12) {
      return _notEligible(
        UnemploymentIneligibilityReason.insufficientContributions,
      );
    }

    final rate = _determineRate(
      monthlyInsuredEarnings,
      hasChildren,
      hasDisability,
    );
    final retainedMonthlyEarnings =
        min(monthlyInsuredEarnings, _maxMonthlyInsuredEarnings);
    final dailyBenefit = _roundToCents(
      (retainedMonthlyEarnings * rate) / _workingDaysPerMonth,
    );
    final monthlyBenefit = _roundToCents(dailyBenefit * _workingDaysPerMonth);
    final dailyBenefitCount = _durationDays(
      age,
      contributionMonths,
      hasChildren,
      hasDisability,
    );

    return UnemploymentCoreResult(
      eligible: true,
      ineligibilityReason: null,
      rate: rate,
      retainedMonthlyEarnings: retainedMonthlyEarnings,
      dailyBenefit: dailyBenefit,
      monthlyBenefit: monthlyBenefit,
      dailyBenefitCount: dailyBenefitCount,
      coverageMonths: dailyBenefitCount / _workingDaysPerMonth,
      waitingPeriodDays: _standardWaitingPeriodDays,
      monthlyLoss: _roundToCents(monthlyInsuredEarnings - monthlyBenefit),
    );
  }

  static UnemploymentCoreResult _notEligible(
    UnemploymentIneligibilityReason reason,
  ) {
    return UnemploymentCoreResult(
      eligible: false,
      ineligibilityReason: reason,
      rate: 0,
      retainedMonthlyEarnings: 0,
      dailyBenefit: 0,
      monthlyBenefit: 0,
      dailyBenefitCount: 0,
      coverageMonths: 0,
      waitingPeriodDays: _standardWaitingPeriodDays,
      monthlyLoss: 0,
    );
  }

  static double _determineRate(
    double monthlyInsuredEarnings,
    bool hasChildren,
    bool hasDisability,
  ) {
    if (hasChildren ||
        hasDisability ||
        monthlyInsuredEarnings < _enhancedRateThreshold) {
      return _enhancedRate;
    }
    return _baseRate;
  }

  static double _roundToCents(double value) =>
      (value * 100).roundToDouble() / 100;

  static int _durationDays(
    int age,
    int contributionMonths,
    bool hasChildren,
    bool hasDisability,
  ) {
    final seniorAge =
        reg('ac.senior_age_threshold', acAgeSeuillSenior.toDouble()).toInt();
    if ((age >= seniorAge || hasDisability) && contributionMonths >= 22) {
      return reg('ac.senior_days', acJoursSenior.toDouble()).toInt();
    }
    if (age < 25 && !hasChildren) {
      return reg('ac.min_days', acJoursMinCotisation.toDouble()).toInt();
    }
    if (contributionMonths >= 18) {
      return reg('ac.standard_days', acJoursStandard.toDouble()).toInt();
    }
    return reg(
      'ac.intermediate_days',
      acJoursIntermediaireCotisation.toDouble(),
    ).toInt();
  }
}
