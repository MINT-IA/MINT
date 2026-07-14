import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';

// ────────────────────────────────────────────────────────────
//  FORECASTER SERVICE — Sprint C3 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Moteur de projection financiere a 3 scenarios.
// Projette le capital total (AVS + LPP + 3a + libre) jusqu'a
// une date cible (retraite, achat immo, etc.).
//
// Inputs : CoachProfile (profil + conjoint + versements)
// Output : ProjectionResult (3 scenarios + milestones)
//
// Toutes les hypotheses de rendement sont explicites.
// Aucun terme banni ("garanti", "certain", "assure").
// ────────────────────────────────────────────────────────────

/// Hypotheses de rendement par type d'actif et par scenario
class ScenarioAssumptions {
  final String label;
  final double lppReturn; // rendement annuel caisse LPP
  final double threeAReturn; // rendement annuel 3a
  final double investmentReturn; // rendement annuel epargne investie
  final double savingsReturn; // rendement annuel epargne compte
  final double inflation; // inflation annuelle

  const ScenarioAssumptions({
    required this.label,
    required this.lppReturn,
    required this.threeAReturn,
    required this.investmentReturn,
    required this.savingsReturn,
    required this.inflation,
  });

  /// Scenarios predefinies
  static const prudent = ScenarioAssumptions(
    label: 'Prudent',
    lppReturn: 0.01,
    threeAReturn: 0.02,
    investmentReturn: 0.03,
    savingsReturn: 0.005,
    inflation: 0.015,
  );

  static const base = ScenarioAssumptions(
    label: 'Base',
    lppReturn: 0.02,
    threeAReturn: 0.045,
    investmentReturn: 0.06,
    savingsReturn: 0.01,
    inflation: 0.015,
  );

  static const optimiste = ScenarioAssumptions(
    label: 'Optimiste',
    lppReturn: 0.03,
    threeAReturn: 0.07,
    investmentReturn: 0.09,
    savingsReturn: 0.015,
    inflation: 0.015,
  );

  /// Create a modified copy (for "Et si..." sliders) // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
  ScenarioAssumptions copyWith({
    String? label,
    double? lppReturn,
    double? threeAReturn,
    double? investmentReturn,
    double? savingsReturn,
    double? inflation,
  }) {
    return ScenarioAssumptions(
      label: label ?? this.label,
      lppReturn: lppReturn ?? this.lppReturn,
      threeAReturn: threeAReturn ?? this.threeAReturn,
      investmentReturn: investmentReturn ?? this.investmentReturn,
      savingsReturn: savingsReturn ?? this.savingsReturn,
      inflation: inflation ?? this.inflation,
    );
  }
}

/// Point de projection (un mois)
class ProjectionPoint {
  final DateTime date;
  final double capitalCumule;
  final double contributionMensuelle;
  final double rendementCumule;

  const ProjectionPoint({
    required this.date,
    required this.capitalCumule,
    required this.contributionMensuelle,
    required this.rendementCumule,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'capitalCumule': capitalCumule,
        'contributionMensuelle': contributionMensuelle,
        'rendementCumule': rendementCumule,
      };

  factory ProjectionPoint.fromJson(Map<String, dynamic> json) {
    return ProjectionPoint(
      date: DateTime.parse(json['date'] as String),
      capitalCumule: (json['capitalCumule'] as num?)?.toDouble() ?? 0,
      contributionMensuelle:
          (json['contributionMensuelle'] as num?)?.toDouble() ?? 0,
      rendementCumule: (json['rendementCumule'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Jalon de progression (ex: "100k de capital prevoyance atteint") // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
class ProjectionMilestone {
  final DateTime date;
  final String label;
  final double amount;

  const ProjectionMilestone({
    required this.date,
    required this.label,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'label': label,
        'amount': amount,
      };
}

/// Resultat d'un scenario de projection
class ProjectionScenario {
  final String label;
  final List<ProjectionPoint> points; // mensuels
  final double capitalFinal;
  final double? revenuAnnuelRetraite;
  final double revenuAnnuelRetraiteHorsAvs;
  final double? revenuAvsIndividuelAnnuel;
  final Map<String, double> decomposition;
  final Map<String, double> decompositionHorsAvs;
  // ex: { 'avs': 43000, 'lpp': 24000, '3a': 8000, 'libre': 12000 }

  ProjectionScenario({
    required this.label,
    required this.points,
    required this.capitalFinal,
    required this.revenuAnnuelRetraite,
    required this.revenuAnnuelRetraiteHorsAvs,
    required this.revenuAvsIndividuelAnnuel,
    required Map<String, double> decomposition,
    required Map<String, double> decompositionHorsAvs,
  })  : decomposition = Map.unmodifiable(decomposition),
        decompositionHorsAvs = Map.unmodifiable(decompositionHorsAvs);

  Map<String, dynamic> toJson() => {
        'label': label,
        'capitalFinal': capitalFinal,
        'revenuAnnuelRetraite': revenuAnnuelRetraite,
        'revenuAnnuelRetraiteHorsAvs': revenuAnnuelRetraiteHorsAvs,
        'revenuAvsIndividuelAnnuel': revenuAvsIndividuelAnnuel,
        'decomposition': decomposition,
        'decompositionHorsAvs': decompositionHorsAvs,
        'selfAvsIncluded': revenuAvsIndividuelAnnuel != null,
        'avsIncluded':
            revenuAnnuelRetraite != null && decomposition.containsKey('avs'),
        'pointsCount': points.length,
      };

  factory ProjectionScenario.fromJson(Map<String, dynamic> json) {
    final selfAvsIncluded = json['selfAvsIncluded'] == true;
    final avsIncluded = json['avsIncluded'] == true;
    final persistedDecomposition =
        (json['decomposition'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            const <String, double>{};
    final persistedNonAvs =
        (json['decompositionHorsAvs'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble()));
    final decompositionHorsAvs = persistedNonAvs ??
        Map<String, double>.fromEntries(
          persistedDecomposition.entries.where(
            (entry) => !entry.key.startsWith('avs'),
          ),
        );
    final persistedNonAvsIncome =
        (json['revenuAnnuelRetraiteHorsAvs'] as num?)?.toDouble();
    return ProjectionScenario(
      label: json['label'] as String? ?? '',
      points: const [], // points not persisted in snapshots
      capitalFinal: (json['capitalFinal'] as num?)?.toDouble() ?? 0,
      revenuAnnuelRetraite: avsIncluded
          ? (json['revenuAnnuelRetraite'] as num?)?.toDouble()
          : null,
      revenuAnnuelRetraiteHorsAvs: persistedNonAvsIncome ??
          decompositionHorsAvs.values.fold(0, (sum, value) => sum + value),
      revenuAvsIndividuelAnnuel: selfAvsIncluded
          ? (json['revenuAvsIndividuelAnnuel'] as num?)?.toDouble()
          : null,
      decomposition:
          avsIncluded ? persistedDecomposition : const <String, double>{},
      decompositionHorsAvs: decompositionHorsAvs,
    );
  }
}

/// Resultat complet de projection (3 scenarios)
class ProjectionResult {
  final ProjectionScenario prudent;
  final ProjectionScenario base;
  final ProjectionScenario optimiste;
  final double? tauxRemplacementBase; // % du revenu brut actuel du ménage
  final bool selfAvsIncluded;
  final bool avsIncluded;
  final List<String> missingFields;
  final List<ProjectionMilestone> milestones;
  final String disclaimer;
  final List<String> sources;

  /// Projection confidence score (0-100) — mandatory on all projections.
  /// 3-axis: completeness x accuracy x freshness (geometric mean).
  /// See ConfidenceScorer for details.
  final double confidenceScore;

  /// Actions the user can take to improve projection accuracy.
  final List<String> enrichmentPrompts;

  ProjectionResult({
    required this.prudent,
    required this.base,
    required this.optimiste,
    required this.tauxRemplacementBase,
    required this.selfAvsIncluded,
    required this.avsIncluded,
    required List<String> missingFields,
    required this.milestones,
    required this.disclaimer,
    required this.sources,
    this.confidenceScore = 0,
    this.enrichmentPrompts = const [],
  }) : missingFields = List.unmodifiable(missingFields);

  Map<String, dynamic> toJson() => {
        'prudent': prudent.toJson(),
        'base': base.toJson(),
        'optimiste': optimiste.toJson(),
        'tauxRemplacementBase': tauxRemplacementBase,
        'selfAvsIncluded': selfAvsIncluded,
        'avsIncluded': avsIncluded,
        'missingFields': missingFields,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'disclaimer': disclaimer,
        'sources': sources,
        'confidenceScore': confidenceScore,
        'enrichmentPrompts': enrichmentPrompts,
      };

  /// Reconstruct a [ProjectionResult] from a JSON map (e.g. stored snapshot).
  ///
  /// Used by the day-1 snapshot comparison on the dashboard (Phase 5).
  /// Only restores aggregate figures (capitalFinal, revenuAnnuelRetraite,
  /// decomposition) — monthly [points] are NOT serialised to keep
  /// the snapshot lightweight.
  factory ProjectionResult.fromJson(Map<String, dynamic> json) {
    final selfAvsIncluded = json['selfAvsIncluded'] == true;
    final avsIncluded = json['avsIncluded'] == true;
    ProjectionScenario scenarioFromJson(Map<String, dynamic> s) {
      return ProjectionScenario.fromJson({
        ...s,
        'selfAvsIncluded': selfAvsIncluded,
        'avsIncluded': avsIncluded,
      });
    }

    return ProjectionResult(
      prudent: scenarioFromJson(
          json['prudent'] as Map<String, dynamic>? ?? const {}),
      base: scenarioFromJson(json['base'] as Map<String, dynamic>? ?? const {}),
      optimiste: scenarioFromJson(
          json['optimiste'] as Map<String, dynamic>? ?? const {}),
      tauxRemplacementBase: avsIncluded
          ? (json['tauxRemplacementBase'] as num?)?.toDouble()
          : null,
      selfAvsIncluded: selfAvsIncluded,
      avsIncluded: avsIncluded,
      missingFields: (json['missingFields'] as List<dynamic>?)
              ?.map((field) => field as String)
              .toList() ??
          const [],
      milestones: const [], // milestones are not persisted in snapshots
      disclaimer: json['disclaimer'] as String? ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          const [],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
      enrichmentPrompts: (json['enrichmentPrompts'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          const [],
    );
  }
}

/// Service de projection financiere.
///
/// Toutes les methodes sont statiques et pures (deterministes).
/// Le service ne fait aucun appel reseau.
class ForecasterService {
  ForecasterService._();

  static const spouseBirthYearFieldPath = 'conjoint.birthYear';
  static const spouseSalaryFieldPath = 'conjoint.salaireBrutMensuel';
  static const spouseRamdFieldPath = 'conjoint.prevoyance.ramd';
  static const spouseContributionYearsFieldPath =
      'conjoint.prevoyance.anneesContribuees';
  static const selfAvsPensionFieldPath =
      AvsOfficialPensionEvidence.selfFieldPath;
  static const spouseAvsPensionFieldPath =
      AvsOfficialPensionEvidence.spouseFieldPath;

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Projette le capital total a la date cible du GoalA
  /// avec 3 scenarios (prudent, base, optimiste).
  static ProjectionResult project({
    required CoachProfile profile,
    DateTime? targetDate,
    S? l,
  }) {
    final target = targetDate ?? profile.goalA.targetDate;
    final missingFields = _projectionMissingFields(profile);

    final scenarioPrudent = _projectScenario(
      profile: profile,
      assumptions: ScenarioAssumptions.prudent,
      targetDate: target,
    );
    final scenarioBase = _projectScenario(
      profile: profile,
      assumptions: ScenarioAssumptions.base,
      targetDate: target,
    );
    final scenarioOptimiste = _projectScenario(
      profile: profile,
      assumptions: ScenarioAssumptions.optimiste,
      targetDate: target,
    );

    // Taux de remplacement — both sides must use the same basis.
    // revenuAnnuelRetraite is GROSS (AVS + LPP rente + 3a annualized + SWR).
    // Compare against GROSS household income for consistency.
    // Previously used householdNetAnnuel (NET) which inflated the ratio.
    final householdGrossAnnuel = profile.revenuBrutAnnuelCouple;
    final completeRetirementIncome = scenarioBase.revenuAnnuelRetraite;
    final tauxRemplacement = completeRetirementIncome != null &&
            !missingFields.contains(spouseSalaryFieldPath)
        ? safeReplacementRate(
            annualRetirementIncome: completeRetirementIncome,
            annualCurrentIncome: householdGrossAnnuel,
          )
        : null;

    // Milestones
    final milestones = _detectMilestones(scenarioBase.points);

    // Confidence scoring (mandatory on all projections — CLAUDE.md §5)
    final confidence = ConfidenceScorer.score(profile);

    return ProjectionResult(
      prudent: scenarioPrudent,
      base: scenarioBase,
      optimiste: scenarioOptimiste,
      tauxRemplacementBase: tauxRemplacement,
      selfAvsIncluded: scenarioBase.revenuAvsIndividuelAnnuel != null,
      avsIncluded: scenarioBase.revenuAnnuelRetraite != null,
      missingFields: missingFields,
      milestones: milestones,
      disclaimer: l?.forecasterDisclaimer ??
          'Projections educatives basees sur des hypotheses de rendement. ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'Ne constitue pas un conseil financier. Les rendements passes ne ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'presagent pas des rendements futurs. Consulte un·e spécialiste ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'pour un plan personnalise. LSFin.', // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
      sources: [
        'LAVS art. 21-29 (rente AVS)',
        'LPP art. 14 (taux de conversion)', // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 79b (rachat)',
      ],
      confidenceScore: confidence.score,
      enrichmentPrompts:
          confidence.prompts.map((p) => p.machineDescriptor).toList(),
    );
  }

  /// Projette un scenario unique avec des hypotheses custom
  /// (utile pour les sliders "Et si...") // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
  static ProjectionScenario projectCustom({
    required CoachProfile profile,
    required ScenarioAssumptions assumptions,
    DateTime? targetDate,
  }) {
    return _projectScenario(
      profile: profile,
      assumptions: assumptions,
      targetDate: targetDate ?? profile.goalA.targetDate,
    );
  }

  /// Projette avec des hypotheses "Et si..." personnalisees. // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
  ///
  /// L'utilisateur ajuste les parametres du scenario Base via des sliders.
  /// Les scenarios Prudent et Optimiste sont derives automatiquement
  /// en conservant les ecarts (spreads) des presets originaux.
  ///
  /// Exemple : si l'utilisateur fixe lppReturn Base a 3%, et que le spread
  /// original est 1% (base 2% - prudent 1%), alors :
  ///   Prudent = 3% - 1% = 2%, Optimiste = 3% + 1% = 4%
  static ProjectionResult projectEtSi({
    required CoachProfile profile,
    required ScenarioAssumptions customBase,
    DateTime? targetDate,
    S? l,
  }) {
    final target = targetDate ?? profile.goalA.targetDate;
    final missingFields = _projectionMissingFields(profile);

    // Calculate spreads from original presets (base - prudent, optimiste - base)
    final lppSpreadDown = ScenarioAssumptions.base.lppReturn -
        ScenarioAssumptions.prudent.lppReturn;
    final lppSpreadUp = ScenarioAssumptions.optimiste.lppReturn -
        ScenarioAssumptions.base.lppReturn;
    final threeASpreadDown = ScenarioAssumptions.base.threeAReturn -
        ScenarioAssumptions.prudent.threeAReturn;
    final threeASpreadUp = ScenarioAssumptions.optimiste.threeAReturn -
        ScenarioAssumptions.base.threeAReturn;
    final investSpreadDown = ScenarioAssumptions.base.investmentReturn -
        ScenarioAssumptions.prudent.investmentReturn;
    final investSpreadUp = ScenarioAssumptions.optimiste.investmentReturn -
        ScenarioAssumptions.base.investmentReturn;
    final savingsSpreadDown = ScenarioAssumptions.base.savingsReturn -
        ScenarioAssumptions.prudent.savingsReturn;
    final savingsSpreadUp = ScenarioAssumptions.optimiste.savingsReturn -
        ScenarioAssumptions.base.savingsReturn;

    final customPrudent = ScenarioAssumptions(
      label: 'Prudent',
      lppReturn: (customBase.lppReturn - lppSpreadDown).clamp(0.0, 0.15),
      threeAReturn:
          (customBase.threeAReturn - threeASpreadDown).clamp(0.0, 0.20),
      investmentReturn:
          (customBase.investmentReturn - investSpreadDown).clamp(0.0, 0.25),
      savingsReturn:
          (customBase.savingsReturn - savingsSpreadDown).clamp(0.0, 0.10),
      inflation: customBase.inflation,
    );

    final customOptimiste = ScenarioAssumptions(
      label: 'Optimiste',
      lppReturn: (customBase.lppReturn + lppSpreadUp).clamp(0.0, 0.15),
      threeAReturn: (customBase.threeAReturn + threeASpreadUp).clamp(0.0, 0.20),
      investmentReturn:
          (customBase.investmentReturn + investSpreadUp).clamp(0.0, 0.25),
      savingsReturn:
          (customBase.savingsReturn + savingsSpreadUp).clamp(0.0, 0.10),
      inflation: customBase.inflation,
    );

    final scenarioPrudent = _projectScenario(
      profile: profile,
      assumptions: customPrudent,
      targetDate: target,
    );
    final scenarioBase = _projectScenario(
      profile: profile,
      assumptions: customBase,
      targetDate: target,
    );
    final scenarioOptimiste = _projectScenario(
      profile: profile,
      assumptions: customOptimiste,
      targetDate: target,
    );

    // Keep the same gross household denominator as project().
    final householdGrossAnnuel = profile.revenuBrutAnnuelCouple;
    final completeRetirementIncome = scenarioBase.revenuAnnuelRetraite;
    final tauxRemplacement = completeRetirementIncome != null &&
            !missingFields.contains(spouseSalaryFieldPath)
        ? safeReplacementRate(
            annualRetirementIncome: completeRetirementIncome,
            annualCurrentIncome: householdGrossAnnuel,
          )
        : null;

    final milestones = _detectMilestones(scenarioBase.points);

    // Confidence scoring (mandatory on all projections — CLAUDE.md §5)
    final confidence = ConfidenceScorer.score(profile);

    return ProjectionResult(
      prudent: scenarioPrudent,
      base: scenarioBase,
      optimiste: scenarioOptimiste,
      tauxRemplacementBase: tauxRemplacement,
      selfAvsIncluded: scenarioBase.revenuAvsIndividuelAnnuel != null,
      avsIncluded: scenarioBase.revenuAnnuelRetraite != null,
      missingFields: missingFields,
      milestones: milestones,
      disclaimer: l?.forecasterEtSiDisclaimer ??
          'Simulation "Et si..." a titre educatif uniquement. ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'Hypotheses de rendement ajustees manuellement. ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'Ne constitue pas un conseil financier (LSFin). ' // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
              'Les rendements passes ne presagent pas des rendements futurs.', // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
      sources: [
        'LAVS art. 21-29 (rente AVS)',
        'LPP art. 14 (taux de conversion)', // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 79b (rachat)',
      ],
      confidenceScore: confidence.score,
      enrichmentPrompts:
          confidence.prompts.map((p) => p.machineDescriptor).toList(),
    );
  }

  /// Calcule le delta mensuel visible au check-in.
  ///
  /// Ce KPI represente l'effort du mois valide (somme des versements),
  /// et non une valeur future composee jusqu'a la retraite.
  /// La valeur future est déjà couverte par la projection complète.
  static double calculateMonthlyDelta({
    required CoachProfile profile,
    required Map<String, double> versements,
  }) {
    // profile is intentionally kept in signature for backward compatibility.
    if (versements.isEmpty) return 0;
    return versements.values
        .where((v) => v.isFinite)
        .fold<double>(0, (sum, v) => sum + v);
  }

  // ════════════════════════════════════════════════════════════════
  //  PROJECTION ENGINE (PRIVATE)
  // ════════════════════════════════════════════════════════════════

  static ProjectionScenario _projectScenario({
    required CoachProfile profile,
    required ScenarioAssumptions assumptions,
    required DateTime targetDate,
  }) {
    final now = DateTime.now();
    final months = _monthsBetween(now, targetDate);
    if (months <= 0) {
      return ProjectionScenario(
        label: assumptions.label,
        points: const [],
        capitalFinal: 0,
        revenuAnnuelRetraite: null,
        revenuAnnuelRetraiteHorsAvs: 0,
        revenuAvsIndividuelAnnuel: null,
        decomposition: const {},
        decompositionHorsAvs: const {},
      );
    }

    // --- Initial balances ---
    double lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
    double threeABalance = profile.prevoyance.totalEpargne3a;
    double investmentBalance = profile.patrimoine.investissements;
    double savingsBalance = profile.patrimoine.epargneLiquide;

    // Conjoint balances
    double conjLppBalance = profile.conjoint?.prevoyance?.avoirLppTotal ?? 0;
    double conjSavingsBalance =
        profile.conjoint?.patrimoine?.epargneLiquide ?? 0;

    // --- Monthly contributions (from planned) ---
    double monthly3a = profile.total3aMensuel;
    double monthlyLppBuyback = profile.totalLppBuybackMensuel;
    double monthlyInvestment = 0;
    double monthlySavings = 0;

    // Categorize free savings vs investments
    for (final c in profile.plannedContributions) {
      if (c.category == 'investissement') {
        monthlyInvestment += c.amount;
      } else if (c.category == 'epargne_libre') {
        monthlySavings += c.amount;
      }
    }

    // --- Couple adjustments ---
    // Detect conjoint contributions by matching their firstName in the ID.
    final conjFirstName = profile.conjoint?.firstName?.toLowerCase() ?? '';

    // Partner 3a contribution potential: if conjoint exists, has income,
    // AND can contribute to 3a.
    //
    // Wave 7 fiscal audit P0-F1 (2026-04-18): archetype-aware FATCA
    // blocker. Previous code trusted `prevoyance?.canContribute3a ?? true`,
    // which defaults to TRUE when the nested prevoyance object is null or
    // the flag wasn't set — so a US-person conjoint like Lauren was auto-
    // projected with ~7'258 CHF/yr of 3a contribution, inflating her
    // retirement capital by ~145k CHF and silently pointing downstream
    // arbitrage (rente vs capital, EPL, rachat) into an IRC §1291 PFIC /
    // IRS Notice 2014-7 foreign-trust trap. Three independent signals
    // must now align before we add any partner 3a potential:
    //   1. `isFatcaResident` false (explicit declaration).
    //   2. nationality not 'US' (safety net when the FATCA flag drifted).
    //   3. nested `prevoyance.canContribute3a` true if present, else
    //      fallback to true only for the non-FATCA, non-US case above.
    double partner3aMonthly = 0;
    final conjoint = profile.conjoint;
    final conjointSalary = conjoint?.salaireBrutMensuel;
    if (conjoint != null &&
        conjointSalary != null &&
        conjointSalary.isFinite &&
        conjointSalary > 0) {
      final bool isUsPerson =
          conjoint.isFatcaResident || conjoint.nationality == 'US';
      final bool conjCanContribute = !isUsPerson &&
          conjoint.canContribute3a &&
          (conjoint.prevoyance?.canContribute3a ?? true);
      if (conjCanContribute) {
        final conjAnnualSalary =
            IncomeConversionCalculator.annualGrossFromMonthly(
          monthlyGross: conjointSalary,
          months: IncomeConversionCalculator.defaultAnnualSalaryMonths,
        );
        if (conjAnnualSalary > reg('lpp.entry_threshold', lppSeuilEntree)) {
          final hasPartner3a = profile.plannedContributions.any((c) =>
              c.category == '3a' &&
              conjFirstName.isNotEmpty &&
              c.id.toLowerCase().contains(conjFirstName));
          if (!hasPartner3a) {
            partner3aMonthly =
                reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) / 12;
          }
        }
      }
    }

    // Conjoint LPP buyback — split before smart check-in adjustment
    double conjMonthlyLppBuyback = 0;
    for (final c in profile.plannedContributions) {
      final isConjointContrib = conjFirstName.isNotEmpty &&
          c.id.toLowerCase().contains(conjFirstName);
      if (isConjointContrib && c.category == 'lpp_buyback') {
        conjMonthlyLppBuyback += c.amount;
        // Remove from main person's total
        monthlyLppBuyback -= c.amount;
      }
    }

    // Smart contributions: use max(planned, rolling avg of last 3 check-ins)
    // This makes projections responsive to actual behavior without punishing
    // temporary dips (garde-fou: only increases, never decreases).
    // Average is computed per-month (sum all entries of same category per
    // check-in) to compare correctly with total planned amounts.
    if (profile.checkIns.length >= 2) {
      final recent = profile.checkIns.length > 3
          ? profile.checkIns.sublist(profile.checkIns.length - 3)
          : profile.checkIns;

      double sum3a = 0, sumLpp = 0;
      int monthsWith3a = 0, monthsWithLpp = 0;

      for (final ci in recent) {
        double monthTotal3a = 0, monthTotalLpp = 0;
        for (final entry in ci.versements.entries) {
          final contrib = profile.plannedContributions
              .where((c) => c.id == entry.key)
              .firstOrNull;
          if (contrib == null) continue;
          if (contrib.category == '3a') {
            monthTotal3a += entry.value;
          } else if (contrib.category == 'lpp_buyback') {
            monthTotalLpp += entry.value;
          }
        }
        if (monthTotal3a > 0) {
          sum3a += monthTotal3a;
          monthsWith3a++;
        }
        if (monthTotalLpp > 0) {
          sumLpp += monthTotalLpp;
          monthsWithLpp++;
        }
      }

      if (monthsWith3a > 0) {
        monthly3a = max(monthly3a, sum3a / monthsWith3a);
      }
      if (monthsWithLpp > 0) {
        monthlyLppBuyback = max(monthlyLppBuyback, sumLpp / monthsWithLpp);
      }
    }

    // --- LPP buyback cap ---
    final lppBuybackCap = profile.prevoyance.lacuneRachatRestante;
    double lppBuybackDone = 0;

    final conjLppBuybackCap =
        profile.conjoint?.prevoyance?.lacuneRachatRestante ?? 0;
    double conjLppBuybackDone = 0;

    // --- Monthly rates ---
    // Use profile-specific caisse rate if it differs from default (2%),
    // otherwise fall back to scenario assumption rate.
    final profileCaisseRate = profile.prevoyance.rendementCaisse;
    final effectiveLppRate =
        (profileCaisseRate != 0.02) ? profileCaisseRate : assumptions.lppReturn;
    final lppMonthlyRate = effectiveLppRate / 12;
    final threeAMonthlyRate = assumptions.threeAReturn / 12;
    final investMonthlyRate = assumptions.investmentReturn / 12;
    final savingsMonthlyRate = assumptions.savingsReturn / 12;
    final conjLppMonthlyRate = (profile.conjoint?.prevoyance?.rendementCaisse ??
            assumptions.lppReturn) /
        12;

    // Partner 3a balance (separate from main user 3a)
    double partner3aBalance = 0;

    // 3a annual cap tracking
    final plafond3a = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    double threeAYearContrib = 0;
    double partner3aYearContrib = 0;
    int currentYear = now.year;

    // --- Projection loop ---
    final points = <ProjectionPoint>[];
    double totalRendement = 0;

    for (int m = 0; m < months; m++) {
      // FIX-059: was m+1, causing all projections to be shifted by 1 month.
      final date = DateTime(now.year, now.month + m);

      // Reset 3a cap at year boundary
      if (date.year != currentYear) {
        threeAYearContrib = 0;
        partner3aYearContrib = 0;
        currentYear = date.year;
      }

      // --- Apply returns FIRST (compound on existing balance) ---
      // LPP: bonifications by age (LPP art. 16) via financial_core
      final lppBefore = lppBalance;
      final userAge = profile.age + (m ~/ 12);
      lppBalance = LppCalculator.projectOneMonth(
        currentBalance: lppBalance,
        age: userAge,
        grossAnnualSalary: profile.salaireBrutMensuel * 12,
        monthlyReturn: lppMonthlyRate,
        salaireAssureOverride: profile.prevoyance.salaireAssure,
        bonificationRateOverride: profile.prevoyance.bonificationRate,
      );
      final lppReturn = lppBalance - lppBefore;

      final threeAReturn = threeABalance * threeAMonthlyRate;
      threeABalance += threeAReturn;

      final investReturn = investmentBalance * investMonthlyRate;
      investmentBalance += investReturn;

      final savingsReturn = savingsBalance * savingsMonthlyRate;
      savingsBalance += savingsReturn;

      // Conjoint LPP: bonifications by age (LPP art. 16)
      final conjLppBefore = conjLppBalance;
      final conjoint = profile.conjoint;
      final conjointAge = conjoint?.age;
      final conjointSalary = conjoint?.salaireBrutMensuel;
      if (conjointAge != null &&
          conjointSalary != null &&
          conjointSalary.isFinite &&
          conjointSalary >= 0) {
        conjLppBalance = LppCalculator.projectOneMonth(
          currentBalance: conjLppBalance,
          age: conjointAge + (m ~/ 12),
          grossAnnualSalary: conjointSalary * 12,
          monthlyReturn: conjLppMonthlyRate,
          salaireAssureOverride: conjoint?.prevoyance?.salaireAssure,
          bonificationRateOverride: conjoint?.prevoyance?.bonificationRate,
        );
      } else {
        // A known balance may keep growing under the scenario return, but
        // missing age/salary cannot create synthetic LPP bonifications.
        conjLppBalance *= 1 + conjLppMonthlyRate;
      }
      final conjLppReturn = conjLppBalance - conjLppBefore;

      totalRendement += lppReturn +
          threeAReturn +
          investReturn +
          savingsReturn +
          conjLppReturn;

      // --- Apply returns on partner 3a ---
      final partner3aReturn = partner3aBalance * threeAMonthlyRate;
      partner3aBalance += partner3aReturn;
      totalRendement += partner3aReturn;

      // --- Apply contributions ---
      // Horizon dampening: after year 20, recurring contributions taper by
      // 2.5%/year (career changes, family expenses, inflation eroding real
      // capacity). Floor 50%. Aligned with RetirementProjectionService.
      // LPP buybacks are NOT dampened — they are capped by lacune, not recurring.
      final yearsSinceStart = m ~/ 12;
      final contributionFactor = yearsSinceStart < 20
          ? 1.0
          : max(0.5, 1.0 - (yearsSinceStart - 20) * 0.025);

      // 3a (capped at annual plafond)
      double effective3a = monthly3a * contributionFactor;
      if (threeAYearContrib + effective3a > plafond3a) {
        effective3a = (plafond3a - threeAYearContrib).clamp(0, plafond3a);
      }
      threeABalance += effective3a;
      threeAYearContrib += effective3a;

      // Partner 3a (capped at annual plafond independently)
      double effectivePartner3a = partner3aMonthly * contributionFactor;
      if (partner3aYearContrib + effectivePartner3a > plafond3a) {
        effectivePartner3a =
            (plafond3a - partner3aYearContrib).clamp(0, plafond3a);
      }
      partner3aBalance += effectivePartner3a;
      partner3aYearContrib += effectivePartner3a;

      // LPP buyback (capped at remaining lacune — no dampening)
      double effectiveLppBuyback = monthlyLppBuyback;
      if (lppBuybackDone + effectiveLppBuyback > lppBuybackCap) {
        effectiveLppBuyback =
            (lppBuybackCap - lppBuybackDone).clamp(0, lppBuybackCap);
      }
      lppBalance += effectiveLppBuyback;
      lppBuybackDone += effectiveLppBuyback;

      // Conjoint LPP buyback (no dampening)
      double effectiveConjBuyback = conjMonthlyLppBuyback;
      if (conjLppBuybackDone + effectiveConjBuyback > conjLppBuybackCap) {
        effectiveConjBuyback = (conjLppBuybackCap - conjLppBuybackDone)
            .clamp(0, conjLppBuybackCap);
      }
      conjLppBalance += effectiveConjBuyback;
      conjLppBuybackDone += effectiveConjBuyback;

      // Investment + savings (dampened)
      investmentBalance += monthlyInvestment * contributionFactor;
      savingsBalance += monthlySavings * contributionFactor;

      // Conjoint free savings — only add conjoint-specific contributions
      // (monthlySavings already counted in savingsBalance above)

      // --- Record point ---
      final totalCapital = lppBalance +
          threeABalance +
          partner3aBalance +
          investmentBalance +
          savingsBalance +
          conjLppBalance +
          conjSavingsBalance;
      final totalContrib = effective3a +
          effectivePartner3a +
          effectiveLppBuyback +
          effectiveConjBuyback +
          monthlyInvestment +
          monthlySavings;

      points.add(ProjectionPoint(
        date: date,
        capitalCumule: totalCapital,
        contributionMensuelle: totalContrib,
        rendementCumule: totalRendement,
      ));
    }

    // --- Calculate retirement income ---
    final retirementAge = targetDate.year - profile.birthYear;
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;

    final conjRetirementAge =
        profile.conjoint?.effectiveRetirementAge ?? retirementAge;
    // G1 fail-closed boundary: current fields contain gap counts, RAMD and an
    // illustrative monthly estimate, but the production parser does not emit
    // an official pension plus source-document date. None of those legacy
    // facts may unlock an evidence-backed self or household AVS amount.
    const double? revenuAvsIndividuelAnnuel = null;

    // LPP rente — split obligatoire/surobligatoire conversion rates.
    //
    // The legal minimum conversion rate (6.8%, LPP art. 14) applies ONLY to
    // the obligatoire portion. Most caisses apply a lower enveloping rate
    // (typically 5.0–5.8%) to the surobligatoire portion.
    //
    // When we have the oblig/suroblig split from a certificate, we apply
    // separate rates. Otherwise, we use a conservative blended estimate
    // (fallback: 5.4% on surobligatoire) to avoid overstating projections.
    //
    // See: CLAUDE.md §5, arbitrage_engine.dart for reference implementation.
    final userConvRateOblig = LppCalculator.adjustedConversionRate(
      baseRate: reg('lpp.conversion_rate_min',
          lppTauxConversionMinDecimal), // 6.8% — obligatoire only
      retirementAge: retirementAge,
    );
    final userConvRateSurob = LppCalculator.adjustedConversionRate(
      baseRate: profile.prevoyance.tauxConversionSuroblig ??
          reg('lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal),
      retirementAge: retirementAge,
    );
    final double renteLppUser;
    final userOblig = profile.prevoyance.avoirLppObligatoire;
    final userSurob = profile.prevoyance.avoirLppSurobligatoire;
    if (userOblig != null && userSurob != null) {
      // Certificate data available: project each part with its own rate ratio.
      // The projected lppBalance grew from the total initial balance.
      // Split proportionally based on the original oblig/suroblig ratio.
      final totalInitial = userOblig + userSurob;
      final obligRatio = totalInitial > 0 ? userOblig / totalInitial : 0.5;
      final projectedOblig = lppBalance * obligRatio;
      final projectedSurob = lppBalance * (1 - obligRatio);
      renteLppUser = projectedOblig * userConvRateOblig +
          projectedSurob * userConvRateSurob;
    } else {
      // No certificate split available.
      // If the profile has a user-set or parser-set enveloping rate that
      // differs from the default 6.8%, honour it (it came from real data).
      // Otherwise, use the conservative surobligatoire estimate (5.4%)
      // to avoid silently overstating with the minimum legal rate.
      final profileRate = profile.prevoyance.tauxConversion;
      final regConvMin =
          reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal);
      final isDefaultRate = (profileRate - regConvMin).abs() < 0.001;
      final baseRate = isDefaultRate
          ? reg(
              'lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal)
          : profileRate;
      final envelopingRate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: retirementAge,
      );
      renteLppUser = lppBalance * envelopingRate;
    }

    // Conjoint LPP — same oblig/suroblig logic
    final conjConvRateOblig = LppCalculator.adjustedConversionRate(
      baseRate: reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal),
      retirementAge: conjRetirementAge,
    );
    final conjConvRateSurob = LppCalculator.adjustedConversionRate(
      baseRate: profile.conjoint?.prevoyance?.tauxConversionSuroblig ??
          reg('lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal),
      retirementAge: conjRetirementAge,
    );
    final double renteLppConjoint;
    final conjOblig = profile.conjoint?.prevoyance?.avoirLppObligatoire;
    final conjSurob = profile.conjoint?.prevoyance?.avoirLppSurobligatoire;
    if (conjOblig != null && conjSurob != null) {
      final conjTotalInitial = conjOblig + conjSurob;
      final conjObligRatio =
          conjTotalInitial > 0 ? conjOblig / conjTotalInitial : 0.5;
      final projectedConjOblig = conjLppBalance * conjObligRatio;
      final projectedConjSurob = conjLppBalance * (1 - conjObligRatio);
      renteLppConjoint = projectedConjOblig * conjConvRateOblig +
          projectedConjSurob * conjConvRateSurob;
    } else {
      final regConvMin2 =
          reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal);
      final conjProfileRate =
          profile.conjoint?.prevoyance?.tauxConversion ?? regConvMin2;
      final conjIsDefault = (conjProfileRate - regConvMin2).abs() < 0.001;
      final conjBaseRate = conjIsDefault
          ? reg(
              'lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal)
          : conjProfileRate;
      final conjEnvelopingRate = LppCalculator.adjustedConversionRate(
        baseRate: conjBaseRate,
        retirementAge: conjRetirementAge,
      );
      renteLppConjoint = conjLppBalance * conjEnvelopingRate;
    }

    // 3a: annualize over 20 years AFTER capital withdrawal tax (LIFD art. 38)
    final threeATotal = threeABalance + partner3aBalance;
    final threeATax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: threeATotal,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      isMarried: isMarried,
    );
    final retrait3aAnnualise = (threeATotal - threeATax) / 20;

    // Free: 4% safe withdrawal rate
    final rendementLibreAnnuel =
        (investmentBalance + savingsBalance + conjSavingsBalance) * 0.04;

    final decompositionHorsAvs = <String, double>{
      'lpp_user': renteLppUser,
      'lpp_conjoint': renteLppConjoint,
      '3a': retrait3aAnnualise,
      'libre': rendementLibreAnnuel,
    };
    final revenuRetraiteAnnuelHorsAvs =
        decompositionHorsAvs.values.fold(0.0, (sum, value) => sum + value);
    const double? revenuRetraiteAnnuel = null;

    const decomposition = <String, double>{};

    final capitalFinal = points.isNotEmpty ? points.last.capitalCumule : 0.0;

    return ProjectionScenario(
      label: assumptions.label,
      points: points,
      capitalFinal: capitalFinal,
      revenuAnnuelRetraite: revenuRetraiteAnnuel,
      revenuAnnuelRetraiteHorsAvs: revenuRetraiteAnnuelHorsAvs,
      revenuAvsIndividuelAnnuel: revenuAvsIndividuelAnnuel,
      decomposition: decomposition,
      decompositionHorsAvs: decompositionHorsAvs,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  MILESTONE DETECTION
  // ════════════════════════════════════════════════════════════════

  static List<ProjectionMilestone> _detectMilestones(
    List<ProjectionPoint> points,
  ) {
    final milestones = <ProjectionMilestone>[];
    final thresholds = [
      50000,
      100000,
      200000,
      500000,
      1000000,
      1500000,
      2000000
    ];
    final reached = <int>{};

    for (final point in points) {
      for (final threshold in thresholds) {
        if (!reached.contains(threshold) && point.capitalCumule >= threshold) {
          reached.add(threshold);
          milestones.add(ProjectionMilestone(
            date: point.date,
            label:
                'CHF ${_formatNumber(threshold.toDouble())} de capital atteint', // lint-ignore: legacy user copy or internal prompt; localization debt predates G1 B2
            amount: threshold.toDouble(),
          ));
        }
      }
    }

    return milestones;
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  static int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  /// Canonical replacement rate computation with safety guards.
  ///
  /// FIX-P1-3: Made public so [RetirementProjectionService] delegates here
  /// instead of duplicating the formula (which lacked guards).
  /// Clamps to 0-200%, rejects negative or absurdly low incomes.
  static double? safeReplacementRate({
    required double annualRetirementIncome,
    required double annualCurrentIncome,
  }) {
    // Evite les pourcentages absurdes quand le revenu courant est incomplet
    // (profil partiel, valeur aberrante, import inachevé).
    if (!annualCurrentIncome.isFinite || annualCurrentIncome < 12000) {
      return null;
    }
    if (!annualRetirementIncome.isFinite || annualRetirementIncome < 0) {
      return null;
    }
    final raw = annualRetirementIncome / annualCurrentIncome * 100;
    if (!raw.isFinite) return null;
    return raw.clamp(0.0, 200.0);
  }

  static List<String> _projectionMissingFields(
    CoachProfile profile,
  ) {
    // Ask for the missing official-pension facts, not gap counts already known
    // to the ledger. The partner path remains distinct because two person-owned
    // pension components are required before a household total is possible.
    final missing = <String>[selfAvsPensionFieldPath];
    if (profile.isCouple) missing.add(spouseAvsPensionFieldPath);
    return missing;
  }

  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Format CHF with Swiss apostrophe
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
