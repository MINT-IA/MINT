/// Guided Precision Entry service (S41).
///
/// Mirrors the backend precision logic: contextual field help,
/// cross-validation alerts, archetype-aware smart defaults,
/// and progressive precision prompts.
///
/// References:
/// - DATA_ACQUISITION_STRATEGY.md, Channel 2
/// - ADR-20260223-unified-financial-engine.md
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// Contextual help for a financial field — tells the user exactly
/// where to find the number and what it is called on the document.
class FieldHelp {
  final String fieldName;
  final String whereToFind;
  final String documentName;
  final String germanName;
  final String? fallbackEstimation;

  const FieldHelp({
    required this.fieldName,
    required this.whereToFind,
    required this.documentName,
    required this.germanName,
    this.fallbackEstimation,
  });
}

/// Alert raised when entered values are inconsistent with each other
/// or with reasonable Swiss-financial bounds.
class CrossValidationAlert {
  final String fieldName;

  /// 'warning' or 'error'
  final String severity;
  final String message;
  final String suggestion;

  const CrossValidationAlert({
    required this.fieldName,
    required this.severity,
    required this.message,
    required this.suggestion,
  });
}

/// An archetype-aware default value for a field the user hasn't filled.
class SmartDefault {
  final String fieldName;
  final double value;
  final String source;
  final double confidence; // 0.0 – 1.0

  const SmartDefault({
    required this.fieldName,
    required this.value,
    required this.source,
    required this.confidence,
  });
}

/// Contextual prompt asking for more precision when it matters.
class PrecisionPrompt {
  final String trigger;
  final String fieldNeeded;
  final String promptText;
  final String impactText;

  const PrecisionPrompt({
    required this.trigger,
    required this.fieldNeeded,
    required this.promptText,
    required this.impactText,
  });
}

/// Main precision service — all methods are static / pure.
class PrecisionService {
  PrecisionService._();

  // ------------------------------------------------------------------
  // 1. Contextual field help
  // ------------------------------------------------------------------

  /// Returns contextual help for a given financial field.
  static FieldHelp? getFieldHelp(String fieldName, S s) {
    return _buildFieldHelpMap(s)[fieldName];
  }

  /// Returns all known field-help entries.
  static List<FieldHelp> allFieldHelps(S s) =>
      _buildFieldHelpMap(s).values.toList(growable: false);

  static Map<String, FieldHelp> _buildFieldHelpMap(S s) {
    return {
      'lpp_total': FieldHelp(
        fieldName: 'lpp_total',
        whereToFind: s.precisionFieldHelpLppTotalWhere,
        documentName: s.precisionFieldHelpLppTotalDoc,
        germanName: s.precisionFieldHelpLppTotalDe,
        fallbackEstimation: s.precisionFieldHelpLppTotalFallback,
      ),
      'lpp_obligatoire': FieldHelp(
        fieldName: 'lpp_obligatoire',
        whereToFind: s.precisionFieldHelpLppObligWhere,
        documentName: s.precisionFieldHelpLppObligDoc,
        germanName: s.precisionFieldHelpLppObligDe,
        fallbackEstimation: s.precisionFieldHelpLppObligFallback,
      ),
      'lpp_surobligatoire': FieldHelp(
        fieldName: 'lpp_surobligatoire',
        whereToFind: s.precisionFieldHelpLppSurobligWhere,
        documentName: s.precisionFieldHelpLppSurobligDoc,
        germanName: s.precisionFieldHelpLppSurobligDe,
        fallbackEstimation: s.precisionFieldHelpLppSurobligFallback,
      ),
      'salaire_brut': FieldHelp(
        fieldName: 'salaire_brut',
        whereToFind: s.precisionFieldHelpSalaireBrutWhere,
        documentName: s.precisionFieldHelpSalaireBrutDoc,
        germanName: s.precisionFieldHelpSalaireBrutDe,
        fallbackEstimation: null,
      ),
      'salaire_net': FieldHelp(
        fieldName: 'salaire_net',
        whereToFind: s.precisionFieldHelpSalaireNetWhere,
        documentName: s.precisionFieldHelpSalaireNetDoc,
        germanName: s.precisionFieldHelpSalaireNetDe,
        fallbackEstimation: s.precisionFieldHelpSalaireNetFallback,
      ),
      'taux_marginal': FieldHelp(
        fieldName: 'taux_marginal',
        whereToFind: s.precisionFieldHelpTauxMarginalWhere,
        documentName: s.precisionFieldHelpTauxMarginalDoc,
        germanName: s.precisionFieldHelpTauxMarginalDe,
        fallbackEstimation: s.precisionFieldHelpTauxMarginalFallback,
      ),
      'avs_contribution_years': FieldHelp(
        fieldName: 'avs_contribution_years',
        whereToFind: s.precisionFieldHelpAvsYearsWhere,
        documentName: s.precisionFieldHelpAvsYearsDoc,
        germanName: s.precisionFieldHelpAvsYearsDe,
        fallbackEstimation: s.precisionFieldHelpAvsYearsFallback,
      ),
      'pillar_3a_balance': FieldHelp(
        fieldName: 'pillar_3a_balance',
        whereToFind: s.precisionFieldHelp3aBalanceWhere,
        documentName: s.precisionFieldHelp3aBalanceDoc,
        germanName: s.precisionFieldHelp3aBalanceDe,
        fallbackEstimation: s.precisionFieldHelp3aBalanceFallback,
      ),
      'mortgage_remaining': FieldHelp(
        fieldName: 'mortgage_remaining',
        whereToFind: s.precisionFieldHelpMortgageWhere,
        documentName: s.precisionFieldHelpMortgageDoc,
        germanName: s.precisionFieldHelpMortgageDe,
        fallbackEstimation: null,
      ),
      'monthly_expenses': FieldHelp(
        fieldName: 'monthly_expenses',
        whereToFind: s.precisionFieldHelpExpensesWhere,
        documentName: s.precisionFieldHelpExpensesDoc,
        germanName: s.precisionFieldHelpExpensesDe,
        fallbackEstimation: s.precisionFieldHelpExpensesFallback,
      ),
      'replacement_ratio': FieldHelp(
        fieldName: 'replacement_ratio',
        whereToFind: s.precisionFieldHelpReplacementRatioWhere,
        documentName: s.precisionFieldHelpReplacementRatioDoc,
        germanName: s.precisionFieldHelpReplacementRatioDe,
        fallbackEstimation: s.precisionFieldHelpReplacementRatioFallback,
      ),
      'tax_saving_3a': FieldHelp(
        fieldName: 'tax_saving_3a',
        whereToFind: s.precisionFieldHelpTaxSaving3aWhere,
        documentName: s.precisionFieldHelpTaxSaving3aDoc,
        germanName: s.precisionFieldHelpTaxSaving3aDe,
        fallbackEstimation: s.precisionFieldHelpTaxSaving3aFallback,
      ),
    };
  }

  // ------------------------------------------------------------------
  // 2. Cross-validation
  // ------------------------------------------------------------------

  /// Runs cross-validation checks on [profile] and returns alerts.
  ///
  /// [profile] keys follow the same naming as the field-help map:
  /// `lpp_total`, `lpp_obligatoire`, `salaire_brut`, `salaire_net`,
  /// `age`, `avs_contribution_years`, `pillar_3a_balance`, etc.
  static List<CrossValidationAlert> crossValidate(
    Map<String, dynamic> profile,
    S s,
  ) {
    final alerts = <CrossValidationAlert>[];

    final age = _dbl(profile, 'age');
    final salaireBrut = _dbl(profile, 'salaire_brut');
    final salaireNet = _dbl(profile, 'salaire_net');
    final lppTotal = _dbl(profile, 'lpp_total');
    final lppOblig = _dbl(profile, 'lpp_obligatoire');
    final lppSuroblig = _dbl(profile, 'lpp_surobligatoire');
    final pillar3a = _dbl(profile, 'pillar_3a_balance');
    final avsYears = _dbl(profile, 'avs_contribution_years');
    final monthlyExpenses = _dbl(profile, 'monthly_expenses');
    final tauxMarginal = _dbl(profile, 'taux_marginal');

    // Check 1: LPP total vs age/salary bounds
    if (lppTotal > 0 && age > 25 && salaireBrut > 0) {
      final yearsWorked = age - 25;
      final annualSalary = salaireBrut * 12;
      // Rough lower bound: 7% of coordinated salary per year (minimum)
      final salaireCoord =
          (annualSalary - lppDeductionCoordination).clamp(lppSalaireCoordMin, double.infinity);
      final expectedMin = salaireCoord * 0.07 * yearsWorked * 0.5;
      // Upper bound: generous employer ~25% of full salary
      final expectedMax = annualSalary * 0.25 * yearsWorked;

      if (lppTotal < expectedMin) {
        alerts.add(CrossValidationAlert(
          fieldName: 'lpp_total',
          severity: 'warning',
          message: s.precisionCrossValLppLow(_fmt(lppTotal)),
          suggestion: s.precisionCrossValLppLowSuggestion,
        ));
      }
      if (lppTotal > expectedMax) {
        alerts.add(CrossValidationAlert(
          fieldName: 'lpp_total',
          severity: 'warning',
          message: s.precisionCrossValLppHigh,
          suggestion: s.precisionCrossValLppHighSuggestion,
        ));
      }
    }

    // Check 2: LPP obligatoire + surobligatoire = total
    if (lppOblig > 0 && lppSuroblig > 0 && lppTotal > 0) {
      final sum = lppOblig + lppSuroblig;
      if ((sum - lppTotal).abs() > lppTotal * 0.02) {
        alerts.add(CrossValidationAlert(
          fieldName: 'lpp_obligatoire',
          severity: 'error',
          message: s.precisionCrossValLppSumMismatch(_fmt(sum), _fmt(lppTotal)),
          suggestion: s.precisionCrossValLppSumMismatchSuggestion,
        ));
      }
    }

    // Check 3: Salary gross vs net ratio
    if (salaireBrut > 0 && salaireNet > 0) {
      final ratio = salaireNet / salaireBrut;
      if (ratio > 0.92) {
        alerts.add(CrossValidationAlert(
          fieldName: 'salaire_net',
          severity: 'warning',
          message: s.precisionCrossValNetHighRatio,
          suggestion: s.precisionCrossValNetHighRatioSuggestion,
        ));
      }
      if (ratio < 0.55) {
        alerts.add(CrossValidationAlert(
          fieldName: 'salaire_net',
          severity: 'warning',
          message: s.precisionCrossValNetLowRatio,
          suggestion: s.precisionCrossValNetLowRatioSuggestion,
        ));
      }
    }

    // Check 4: AVS contribution years vs age
    if (avsYears > 0 && age > 0) {
      final maxYears = (age - 20).clamp(0, 44).toDouble();
      if (avsYears > maxYears + 1) {
        alerts.add(CrossValidationAlert(
          fieldName: 'avs_contribution_years',
          severity: 'error',
          message: s.precisionCrossValAvsYearsExceed(
            avsYears.toString(),
            age.round().toString(),
          ),
          suggestion: s.precisionCrossValAvsYearsExceedSuggestion(
            maxYears.round().toString(),
          ),
        ));
      }
    }

    // Check 5: Pillar 3a balance vs age
    if (pillar3a > 0 && age > 0) {
      const maxAnnual = pilier3aPlafondAvecLpp;
      final maxYears3a = (age - 18).clamp(0, 47).toDouble();
      // Reasonable upper bound: max contribution each year + ~3% annual return
      final theoreticalMax = maxAnnual * maxYears3a * 1.4;
      if (pillar3a > theoreticalMax) {
        alerts.add(CrossValidationAlert(
          fieldName: 'pillar_3a_balance',
          severity: 'warning',
          message: s.precisionCrossVal3aHigh,
          suggestion: s.precisionCrossVal3aHighSuggestion,
        ));
      }
      if (age < 18 && pillar3a > 0) {
        alerts.add(CrossValidationAlert(
          fieldName: 'pillar_3a_balance',
          severity: 'error',
          message: s.precisionCrossVal3aUnder18,
          suggestion: s.precisionCrossVal3aUnder18Suggestion,
        ));
      }
    }

    // Check 6: Monthly expenses vs net salary
    if (monthlyExpenses > 0 && salaireNet > 0) {
      if (monthlyExpenses > salaireNet * 1.3) {
        alerts.add(CrossValidationAlert(
          fieldName: 'monthly_expenses',
          severity: 'warning',
          message: s.precisionCrossValExpensesHigh,
          suggestion: s.precisionCrossValExpensesHighSuggestion,
        ));
      }
    }

    // Check 7: Marginal tax rate bounds
    if (tauxMarginal > 0) {
      if (tauxMarginal > 0.50) {
        alerts.add(CrossValidationAlert(
          fieldName: 'taux_marginal',
          severity: 'warning',
          message: s.precisionCrossValTauxHigh,
          suggestion: s.precisionCrossValTauxHighSuggestion,
        ));
      }
      if (tauxMarginal < 0.05 && salaireBrut > 3000) {
        alerts.add(CrossValidationAlert(
          fieldName: 'taux_marginal',
          severity: 'warning',
          message: s.precisionCrossValTauxLow,
          suggestion: s.precisionCrossValTauxLowSuggestion,
        ));
      }
    }

    return alerts;
  }

  // ------------------------------------------------------------------
  // 3. Smart defaults
  // ------------------------------------------------------------------

  /// Computes archetype-aware default values for missing fields.
  ///
  /// Uses Swiss statutory minimums, bonification tables, and
  /// archetype-specific adjustments.
  static List<SmartDefault> computeSmartDefaults({
    required String archetype,
    required int age,
    required double salary,
    required String canton,
    required S s,
  }) {
    final defaults = <SmartDefault>[];
    final annualSalary = salary * 12;

    // --- LPP total estimation ---
    final yearsContrib = _lppYears(archetype, age);
    final salaireCoord =
        (annualSalary - lppDeductionCoordination).clamp(lppSalaireCoordMin, annualSalary * 0.8);
    double lppEstimate = 0;
    for (int a = (age - yearsContrib).round(); a < age; a++) {
      lppEstimate += salaireCoord * _bonificationRate(a);
    }
    // Add ~2% annual return compounding
    lppEstimate *= 1.0 + (yearsContrib * 0.015);

    if (archetype == 'independent_no_lpp') {
      defaults.add(SmartDefault(
        fieldName: 'lpp_total',
        value: 0,
        source: s.precisionDefaultLppNoLpp,
        confidence: 0.90,
      ));
    } else {
      defaults.add(SmartDefault(
        fieldName: 'lpp_total',
        value: _round(lppEstimate),
        source: s.precisionDefaultLppEstimate(archetype, age.toString()),
        confidence: archetype == 'swiss_native' ? 0.40 : 0.25,
      ));
    }

    // --- LPP obligatoire estimation ---
    if (archetype != 'independent_no_lpp') {
      // Obligatory part: use only statutory minimum salary coord
      final coordMin = (annualSalary - lppDeductionCoordination).clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      double obligEstimate = 0;
      for (int a = (age - yearsContrib).round(); a < age; a++) {
        obligEstimate += coordMin * _bonificationRate(a);
      }
      obligEstimate *= 1.0 + (yearsContrib * 0.01);

      defaults.add(SmartDefault(
        fieldName: 'lpp_obligatoire',
        value: _round(obligEstimate),
        source: s.precisionDefaultLppOblig,
        confidence: 0.30,
      ));
    }

    // --- Salaire net estimation ---
    final netRatio = _netRatio(canton);
    defaults.add(SmartDefault(
      fieldName: 'salaire_net',
      value: _round(salary * netRatio),
      source: s.precisionDefaultSalaireNet(
        (netRatio * 100).round().toString(),
        canton,
      ),
      confidence: 0.35,
    ));

    // --- AVS contribution years ---
    double avsYears;
    if (archetype == 'swiss_native') {
      avsYears = (age - 20).clamp(0, 44).toDouble();
    } else if (archetype.startsWith('expat')) {
      // Expat: assume arrival at ~30 on average
      avsYears = (age - 30).clamp(0, 44).toDouble();
    } else if (archetype == 'cross_border') {
      avsYears = (age - 25).clamp(0, 44).toDouble();
    } else {
      avsYears = (age - 20).clamp(0, 44).toDouble();
    }
    defaults.add(SmartDefault(
      fieldName: 'avs_contribution_years',
      value: avsYears,
      source: s.precisionDefaultAvsYears(archetype),
      confidence: archetype == 'swiss_native' ? 0.55 : 0.30,
    ));

    // --- Pillar 3a balance ---
    final contributing3aYears = (age - 25).clamp(0, 40).toDouble();
    final estimated3a = contributing3aYears > 0
        ? contributing3aYears * pilier3aPlafondAvecLpp * 0.6 // assume 60% utilization
        : 0.0;
    defaults.add(SmartDefault(
      fieldName: 'pillar_3a_balance',
      value: _round(estimated3a),
      source: s.precisionDefault3aBalance,
      confidence: 0.20,
    ));

    // --- Monthly expenses ---
    final estimatedExpenses = salary * 0.65;
    defaults.add(SmartDefault(
      fieldName: 'monthly_expenses',
      value: _round(estimatedExpenses),
      source: s.precisionDefaultExpenses,
      confidence: 0.25,
    ));

    // --- Taux marginal estimation ---
    final tauxEstimate = RetirementTaxCalculator.estimateMarginalRate(annualSalary, canton);
    defaults.add(SmartDefault(
      fieldName: 'taux_marginal',
      value: (tauxEstimate * 100).roundToDouble(),
      source: s.precisionDefaultTauxMarginal(canton),
      confidence: 0.30,
    ));

    // --- Replacement ratio ---
    defaults.add(SmartDefault(
      fieldName: 'replacement_ratio',
      value: 70,
      source: s.precisionDefaultReplacementRatio,
      confidence: 0.50,
    ));

    // --- Tax saving 3a ---
    final taxSaving3a = pilier3aPlafondAvecLpp * tauxEstimate;
    defaults.add(SmartDefault(
      fieldName: 'tax_saving_3a',
      value: _round(taxSaving3a),
      source: s.precisionDefaultTaxSaving3a(
        (tauxEstimate * 100).round().toString(),
      ),
      confidence: 0.25,
    ));

    return defaults;
  }

  // ------------------------------------------------------------------
  // 4. Precision prompts
  // ------------------------------------------------------------------

  /// Returns context-sensitive precision prompts based on the current
  /// screen/context and the user's profile completeness.
  static List<PrecisionPrompt> getPrecisionPrompts({
    required String context,
    required Map<String, dynamic> profile,
    required S s,
  }) {
    final prompts = <PrecisionPrompt>[];

    final hasLppOblig = _dbl(profile, 'lpp_obligatoire') > 0;
    final hasLppTotal = _dbl(profile, 'lpp_total') > 0;
    final hasTauxMarginal = _dbl(profile, 'taux_marginal') > 0;
    final hasAvsYears = _dbl(profile, 'avs_contribution_years') > 0;
    final has3a = _dbl(profile, 'pillar_3a_balance') > 0;
    final hasMortgage = _dbl(profile, 'mortgage_remaining') > 0;

    // Rente vs Capital arbitrage context
    if (context == 'rente_vs_capital' || context == 'retirement') {
      if (!hasLppOblig) {
        prompts.add(PrecisionPrompt(
          trigger: 'rente_vs_capital',
          fieldNeeded: 'lpp_obligatoire',
          promptText: s.precisionPromptLppObligText,
          impactText: s.precisionPromptLppObligImpact,
        ));
      }
      if (!hasLppTotal) {
        prompts.add(PrecisionPrompt(
          trigger: 'rente_vs_capital',
          fieldNeeded: 'lpp_total',
          promptText: s.precisionPromptLppTotalText,
          impactText: s.precisionPromptLppTotalImpact,
        ));
      }
    }

    // Tax optimization context
    if (context == 'tax_optimization' || context == 'rachat_lpp') {
      if (!hasTauxMarginal) {
        prompts.add(PrecisionPrompt(
          trigger: 'tax_optimization',
          fieldNeeded: 'taux_marginal',
          promptText: s.precisionPromptTauxMarginalText,
          impactText: s.precisionPromptTauxMarginalImpact,
        ));
      }
    }

    // Retirement projection context
    if (context == 'retirement' || context == 'dashboard') {
      if (!hasAvsYears) {
        prompts.add(PrecisionPrompt(
          trigger: 'retirement',
          fieldNeeded: 'avs_contribution_years',
          promptText: s.precisionPromptAvsYearsText,
          impactText: s.precisionPromptAvsYearsImpact,
        ));
      }
      if (!has3a) {
        prompts.add(PrecisionPrompt(
          trigger: 'retirement',
          fieldNeeded: 'pillar_3a_balance',
          promptText: s.precisionPrompt3aText,
          impactText: s.precisionPrompt3aImpact,
        ));
      }
    }

    // 3a deep context
    if (context == '3a_deep' || context == '3a_optimization') {
      if (!hasTauxMarginal) {
        prompts.add(PrecisionPrompt(
          trigger: '3a_optimization',
          fieldNeeded: 'taux_marginal',
          promptText: s.precisionPromptTauxMarginal3aText,
          impactText: s.precisionPromptTauxMarginal3aImpact,
        ));
      }
    }

    // Mortgage context
    if (context == 'mortgage') {
      if (!hasMortgage) {
        prompts.add(PrecisionPrompt(
          trigger: 'mortgage',
          fieldNeeded: 'mortgage_remaining',
          promptText: s.precisionPromptMortgageText,
          impactText: s.precisionPromptMortgageImpact,
        ));
      }
    }

    // Budget context
    if (context == 'budget') {
      final hasExpenses = _dbl(profile, 'monthly_expenses') > 0;
      if (!hasExpenses) {
        prompts.add(PrecisionPrompt(
          trigger: 'budget',
          fieldNeeded: 'monthly_expenses',
          promptText: s.precisionPromptExpensesText,
          impactText: s.precisionPromptExpensesImpact,
        ));
      }
    }

    return prompts;
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  static double _dbl(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      final intV = v.round();
      final str = intV.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return v.toStringAsFixed(0);
  }

  static double _round(double v) => (v / 100).roundToDouble() * 100;

  /// LPP contribution years depending on archetype.
  static double _lppYears(String archetype, int age) {
    switch (archetype) {
      case 'swiss_native':
        return (age - 25).clamp(0, 40).toDouble();
      case 'expat_eu':
      case 'expat_non_eu':
      case 'expat_us':
        return (age - 30).clamp(0, 35).toDouble(); // later start
      case 'independent_with_lpp':
        return (age - 30).clamp(0, 35).toDouble();
      case 'independent_no_lpp':
        return 0;
      case 'cross_border':
        return (age - 25).clamp(0, 40).toDouble();
      case 'returning_swiss':
        return (age - 28).clamp(0, 37).toDouble();
      default:
        return (age - 25).clamp(0, 40).toDouble();
    }
  }

  /// LPP bonification rate by age (LPP art. 16).
  static double _bonificationRate(int age) {
    if (age < 25) return 0;
    if (age < 35) return 0.07;
    if (age < 45) return 0.10;
    if (age < 55) return 0.15;
    return 0.18;
  }

  /// Approximate net/gross ratio by canton.
  static double _netRatio(String canton) {
    // Higher-tax cantons have lower net ratio
    const highTax = {'GE', 'VD', 'NE', 'BS', 'BE', 'JU', 'FR'};
    const lowTax = {'ZG', 'SZ', 'NW', 'OW', 'AI', 'AR', 'UR'};
    if (lowTax.contains(canton.toUpperCase())) return 0.82;
    if (highTax.contains(canton.toUpperCase())) return 0.75;
    return 0.78; // median
  }

}
