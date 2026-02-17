import 'circle_score.dart';

/// Rapport financier exhaustif généré en fin de wizard
class FinancialReport {
  // Profil utilisateur
  final UserProfile profile;

  // Scores par cercle
  final FinancialHealthScore healthScore;

  // Simulations & Projections
  final TaxSimulation taxSimulation;
  final RetirementProjection? retirementProjection;
  final Pillar3aAnalysis? pillar3aAnalysis;
  final LppBuybackStrategy? lppBuybackStrategy;

  // Recommandations
  final List<ActionItem> priorityActions;
  final Roadmap personalizedRoadmap;

  // Conformité & Sources juridiques
  final List<String> disclaimers;
  final List<String> sources; // ["LPP art. 14", "LIFD art. 33", ...]

  // Metadata & Traçabilité (Aligned with SOT.md)
  final DateTime generatedAt;
  final String reportVersion;
  final Map<String, dynamic>? simulationAssumptions;
  final List<Map<String, dynamic>>?
      generatedLetters; // Audit trail of generated letters

  const FinancialReport({
    required this.profile,
    required this.healthScore,
    required this.taxSimulation,
    this.retirementProjection,
    this.pillar3aAnalysis,
    this.lppBuybackStrategy,
    required this.priorityActions,
    required this.personalizedRoadmap,
    this.disclaimers = const [],
    this.sources = const [],
    required this.generatedAt,
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

  final int? contributionYears;
  final int? spouseContributionYears;

  const UserProfile({
    this.firstName,
    required this.birthYear,
    required this.canton,
    required this.civilStatus,
    required this.childrenCount,
    required this.employmentStatus,
    required this.monthlyNetIncome,
    this.contributionYears,
    this.spouseContributionYears,
  });

  int get age => DateTime.now().year - birthYear;
  int get yearsToRetirement => 65 - age;
  bool get isMarried => civilStatus == 'married';
  bool get hasChildren => childrenCount > 0;
  bool get isSalaried => employmentStatus == 'employee';
  double get annualIncome => monthlyNetIncome * 12;

  /// Facteur de réduction AVS (1/44 par année manquante)
  double get avsReductionFactor {
    final years = contributionYears ?? 44;
    return (years / 44).clamp(0.0, 1.0);
  }

  /// Facteur de réduction AVS pour le conjoint
  double get spouseAvsReductionFactor {
    if (!isMarried) return 0.0;
    final years = spouseContributionYears ?? 44;
    return (years / 44).clamp(0.0, 1.0);
  }
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
  final double lppCapital;
  final double pillar3aCapital;
  final double? otherAssets;

  // Rentes
  final double monthlyAvsRent;
  final double monthlyLppRent;

  // Facteurs de réduction (Pédagogie)
  final double avsReductionFactor;
  final double spouseAvsReductionFactor;

  // Total
  final double totalCapital;
  final double totalMonthlyIncome;

  const RetirementProjection({
    this.retirementAge = 65,
    required this.yearsUntilRetirement,
    required this.lppCapital,
    required this.pillar3aCapital,
    this.otherAssets,
    required this.monthlyAvsRent,
    required this.monthlyLppRent,
    this.avsReductionFactor = 1.0,
    this.spouseAvsReductionFactor = 1.0,
  })  : totalCapital = lppCapital + pillar3aCapital + (otherAssets ?? 0),
        totalMonthlyIncome = monthlyAvsRent + monthlyLppRent;

  double get replacementRate =>
      (totalMonthlyIncome / 7800) * 100; // TODO: Dynamic
}

/// Analyse 3a
class Pillar3aAnalysis {
  final int currentAccountsCount;
  final List<String> providers; // 'bank', 'viac', 'finpension', 'insurance'
  final double annualContribution;
  final double maxContribution;

  // Projections
  final Map<String, double>
      projectionsByProvider; // Provider → Capital à 65 ans
  final double potentialGainVsBank; // Si passage à VIAC

  // Optimisation retrait
  final double? taxOnWithdrawalSingleAccount;
  final double? taxOnWithdrawalMultipleAccounts;
  final double? withdrawalOptimizationSavings;

  const Pillar3aAnalysis({
    required this.currentAccountsCount,
    required this.providers,
    required this.annualContribution,
    required this.maxContribution,
    required this.projectionsByProvider,
    required this.potentialGainVsBank,
    this.taxOnWithdrawalSingleAccount,
    this.taxOnWithdrawalMultipleAccounts,
    this.withdrawalOptimizationSavings,
  });

  bool get isMaximizing => annualContribution >= maxContribution;
  bool get hasMultipleAccounts => currentAccountsCount >= 2;
  bool get usesViacOrFinpension =>
      providers.contains('viac') || providers.contains('finpension');
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
  final String timeframe; // "Immédiat", "Court terme (3-6 mois)", etc.
  final List<ActionItem> actions;

  const RoadmapPhase({
    required this.title,
    required this.timeframe,
    required this.actions,
  });
}
