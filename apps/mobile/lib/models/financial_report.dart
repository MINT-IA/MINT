import 'circle_score.dart';
import 'lpp_capital_notice_specialist_handoff.dart';
import 'lpp_regulation_specialist_handoff.dart';
import 'pillar3a_beneficiary_specialist_handoff.dart';
import '../services/financial_core/replacement_rate_calculator.dart';

/// Rapport financier exhaustif généré en fin de wizard
class FinancialReport {
  // Profil utilisateur
  final UserProfile profile;

  // Scores par cercle
  final FinancialHealthScore healthScore;

  // Simulations & Projections
  final TaxSimulation taxSimulation;
  final RetirementProjection? retirementProjection;
  final LppBuybackStrategy? lppBuybackStrategy;

  /// Deadline-only specialist preparation from two resolved evidence objects.
  final LppCapitalNoticeSpecialistHandoff? lppCapitalNoticeHandoff;

  /// Metadata-only specialist preparation from an exact local BND match.
  final LppRegulationSpecialistHandoff? lppRegulationHandoff;

  /// Contract-scoped 3a specialist preparation from the qualified consumer.
  final Pillar3aBeneficiarySpecialistHandoff? pillar3aBeneficiaryHandoff;

  // Recommandations
  final List<ActionItem> priorityActions;
  final Roadmap personalizedRoadmap;

  // Conformité & Sources juridiques
  final List<String> disclaimers;
  final List<String> sources; // ["LPP art. 14", "LIFD art. 33", ...]

  // Confidence scoring (mandatory on all projections — ADR §5)
  /// Projection confidence score (0-100). Based on ConfidenceScorer when
  /// a CoachProfile is available, or a simplified estimate from wizard data.
  final double confidenceScore;

  /// Actions the user can take to improve projection accuracy.
  final List<String> enrichmentPrompts;

  // Metadata & Traçabilité (Aligned with SOT.md)
  final DateTime generatedAt;

  /// Timestamp of when the underlying data was last collected/updated.
  /// Null if unknown (e.g. no wizard answer timestamp available).
  final DateTime? dataCollectedAt;

  final String reportVersion;
  final Map<String, dynamic>? simulationAssumptions;
  final List<Map<String, dynamic>>?
      generatedLetters; // Audit trail of generated letters

  const FinancialReport({
    required this.profile,
    required this.healthScore,
    required this.taxSimulation,
    this.retirementProjection,
    this.lppBuybackStrategy,
    this.lppCapitalNoticeHandoff,
    this.lppRegulationHandoff,
    this.pillar3aBeneficiaryHandoff,
    required this.priorityActions,
    required this.personalizedRoadmap,
    this.disclaimers = const [],
    this.sources = const [],
    this.confidenceScore = 0,
    this.enrichmentPrompts = const [],
    required this.generatedAt,
    this.dataCollectedAt,
    this.reportVersion = '2.0',
    this.simulationAssumptions,
    this.generatedLetters,
  });
}

/// Profil utilisateur enrichi
class UserProfile {
  final String? firstName;
  final int birthYear;
  final String canton;
  final String civilStatus;
  final int childrenCount;
  final String employmentStatus;
  final double monthlyNetIncome;

  const UserProfile({
    this.firstName,
    required this.birthYear,
    required this.canton,
    required this.civilStatus,
    required this.childrenCount,
    required this.employmentStatus,
    required this.monthlyNetIncome,
  });

  int get age => DateTime.now().year - birthYear;
  int get yearsToRetirement => 65 - age;
  bool get isMarried => civilStatus == 'married';
  bool get hasChildren => childrenCount > 0;
  bool get isSalaried => employmentStatus == 'employee';
  double get annualIncome => monthlyNetIncome * 12;
}

/// Simulation fiscale annuelle
class TaxSimulation {
  final double taxableIncome;
  final Map<String, double> deductions;
  final double cantonalTax;
  final double federalTax;
  final double totalTax;
  final double effectiveRate;

  // Avec rachat LPP (si applicable)
  final double? taxWithLppBuyback;
  final double? taxSavingsFromBuyback;

  const TaxSimulation({
    required this.taxableIncome,
    required this.deductions,
    required this.cantonalTax,
    required this.federalTax,
    required this.totalTax,
    required this.effectiveRate,
    this.taxWithLppBuyback,
    this.taxSavingsFromBuyback,
  });

  double get totalDeductions =>
      deductions.values.fold(0, (sum, val) => sum + val);
}

/// Projection retraite
class RetirementProjection {
  final int retirementAge;
  final int yearsUntilRetirement;

  // Capitaux estimés
  final double? lppCapital;
  final double? pillar3aCapital;
  final double? otherAssets;

  // Rentes
  final double? monthlyAvsRent;
  final double? monthlyLppRent;

  /// Revenu mensuel net actuel explicitement fourni par l'appelant.
  /// Le taux reste inconnu si l'AVS ou la LPP manque, ou si ce revenu vaut 0.
  final double currentMonthlyIncome;

  // Total
  final double? totalCapital;
  final double? totalMonthlyIncome;

  const RetirementProjection({
    this.retirementAge = 65,
    required this.yearsUntilRetirement,
    required this.lppCapital,
    required this.pillar3aCapital,
    this.otherAssets,
    this.monthlyAvsRent,
    required this.monthlyLppRent,
    required this.currentMonthlyIncome,
  })  : totalCapital = lppCapital == null || pillar3aCapital == null
            ? null
            : lppCapital + pillar3aCapital + (otherAssets ?? 0),
        totalMonthlyIncome = monthlyAvsRent == null || monthlyLppRent == null
            ? null
            : monthlyAvsRent + monthlyLppRent;

  /// Taux de remplacement : revenu mensuel projeté à la retraite divisé par
  /// le revenu mensuel actuel. Il reste inconnu si la rente AVS, la rente LPP
  /// ou le revenu courant manque. Exprimé en pourcentage (ex: 65.0 = 65%).
  /// Clampé entre 0% et 150% (peut dépasser 100% dans certains cas, ex.
  /// faible revenu actuel + rentes complètes).
  double? get replacementRate => ReplacementRateCalculator.calculate(
        monthlyRetirementIncome: totalMonthlyIncome,
        currentMonthlyIncome: currentMonthlyIncome,
      );
}

/// Stratégie rachat LPP
class LppBuybackStrategy {
  final double totalBuybackAvailable;
  final List<AnnualBuyback> yearlyPlan;
  final double totalTaxSavings;

  const LppBuybackStrategy({
    required this.totalBuybackAvailable,
    required this.yearlyPlan,
    required this.totalTaxSavings,
  });
}

class AnnualBuyback {
  final int year;
  final double amount;
  final double estimatedTaxSavings;

  const AnnualBuyback({
    required this.year,
    required this.amount,
    required this.estimatedTaxSavings,
  });
}

/// Action prioritaire
class ActionItem {
  final String title;
  final String description;
  final ActionPriority priority;
  final double? potentialGainChf;
  final ActionCategory category;
  final List<String> steps;

  const ActionItem({
    required this.title,
    required this.description,
    required this.priority,
    this.potentialGainChf,
    required this.category,
    required this.steps,
  });
}

enum ActionPriority {
  critical, // À faire MAINTENANT
  high, // Ce mois
  medium, // 3-6 mois
  low, // Quand possible
}

enum ActionCategory {
  protection,
  pillar3a,
  lpp,
  avs,
  tax,
  insurance,
  investment,
  other,
}

/// Roadmap personnalisée
class Roadmap {
  final List<RoadmapPhase> phases;

  const Roadmap({required this.phases});
}

class RoadmapPhase {
  final String title;
  final String timeframe; // Localized time-horizon label from the UI layer.
  final List<ActionItem> actions;

  const RoadmapPhase({
    required this.title,
    required this.timeframe,
    required this.actions,
  });
}
