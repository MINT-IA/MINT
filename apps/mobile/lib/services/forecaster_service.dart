import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

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

  /// Create a modified copy (for "Et si..." sliders)
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

/// Jalon de progression (ex: "100k de capital prevoyance atteint")
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
  final double revenuAnnuelRetraite;
  final Map<String, double> decomposition;
  // ex: { 'avs': 43000, 'lpp': 24000, '3a': 8000, 'libre': 12000 }

  const ProjectionScenario({
    required this.label,
    required this.points,
    required this.capitalFinal,
    required this.revenuAnnuelRetraite,
    required this.decomposition,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'capitalFinal': capitalFinal,
        'revenuAnnuelRetraite': revenuAnnuelRetraite,
        'decomposition': decomposition,
        'pointsCount': points.length,
      };

  factory ProjectionScenario.fromJson(Map<String, dynamic> json) {
    return ProjectionScenario(
      label: json['label'] as String? ?? '',
      points: const [], // points not persisted in snapshots
      capitalFinal: (json['capitalFinal'] as num?)?.toDouble() ?? 0,
      revenuAnnuelRetraite:
          (json['revenuAnnuelRetraite'] as num?)?.toDouble() ?? 0,
      decomposition: (json['decomposition'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          const {},
    );
  }
}

/// Resultat complet de projection (3 scenarios)
class ProjectionResult {
  final ProjectionScenario prudent;
  final ProjectionScenario base;
  final ProjectionScenario optimiste;
  final double tauxRemplacementBase; // % du revenu actuel net
  final List<ProjectionMilestone> milestones;
  final String disclaimer;
  final List<String> sources;

  const ProjectionResult({
    required this.prudent,
    required this.base,
    required this.optimiste,
    required this.tauxRemplacementBase,
    required this.milestones,
    required this.disclaimer,
    required this.sources,
  });

  Map<String, dynamic> toJson() => {
        'prudent': prudent.toJson(),
        'base': base.toJson(),
        'optimiste': optimiste.toJson(),
        'tauxRemplacementBase': tauxRemplacementBase,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'disclaimer': disclaimer,
        'sources': sources,
      };

  /// Reconstruct a [ProjectionResult] from a JSON map (e.g. stored snapshot).
  ///
  /// Used by the day-1 snapshot comparison on the dashboard (Phase 5).
  /// Only restores aggregate figures (capitalFinal, revenuAnnuelRetraite,
  /// decomposition) — monthly [points] are NOT serialised to keep
  /// the snapshot lightweight.
  factory ProjectionResult.fromJson(Map<String, dynamic> json) {
    ProjectionScenario _scenarioFromJson(Map<String, dynamic> s) {
      return ProjectionScenario(
        label: s['label'] as String? ?? '',
        points: const [], // points are not persisted in snapshots
        capitalFinal: (s['capitalFinal'] as num?)?.toDouble() ?? 0,
        revenuAnnuelRetraite:
            (s['revenuAnnuelRetraite'] as num?)?.toDouble() ?? 0,
        decomposition: (s['decomposition'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            const {},
      );
    }

    return ProjectionResult(
      prudent: _scenarioFromJson(
          json['prudent'] as Map<String, dynamic>? ?? const {}),
      base: _scenarioFromJson(
          json['base'] as Map<String, dynamic>? ?? const {}),
      optimiste: _scenarioFromJson(
          json['optimiste'] as Map<String, dynamic>? ?? const {}),
      tauxRemplacementBase:
          (json['tauxRemplacementBase'] as num?)?.toDouble() ?? 0,
      milestones: const [], // milestones are not persisted in snapshots
      disclaimer: json['disclaimer'] as String? ?? '',
      sources: (json['sources'] as List<dynamic>?)
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

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Projette le capital total a la date cible du GoalA
  /// avec 3 scenarios (prudent, base, optimiste).
  static ProjectionResult project({
    required CoachProfile profile,
    DateTime? targetDate,
  }) {
    final target = targetDate ?? profile.goalA.targetDate;

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

    // Taux de remplacement base sur le scenario base
    // Use household income (main + partner) when conjoint exists
    final mainBreakdown = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton,
      age: profile.age,
    );
    final revenuNetMensuel = mainBreakdown.monthlyNetPayslip;
    final conjoint = profile.conjoint;
    final partnerNetMensuel = conjoint != null &&
            conjoint.salaireBrutMensuel != null &&
            conjoint.age != null
        ? NetIncomeBreakdown.compute(
            grossSalary: conjoint.salaireBrutMensuel! * 12,
            canton: profile.canton,
            age: conjoint.age!,
          ).monthlyNetPayslip
        : 0.0;
    final householdNetAnnuel = (revenuNetMensuel + partnerNetMensuel) * 12;
    final tauxRemplacement = _safeReplacementRate(
      annualRetirementIncome: scenarioBase.revenuAnnuelRetraite,
      annualCurrentIncome: householdNetAnnuel,
    );

    // Milestones
    final milestones = _detectMilestones(scenarioBase.points);

    return ProjectionResult(
      prudent: scenarioPrudent,
      base: scenarioBase,
      optimiste: scenarioOptimiste,
      tauxRemplacementBase: tauxRemplacement,
      milestones: milestones,
      disclaimer:
          'Projections educatives basees sur des hypotheses de rendement. '
          'Ne constitue pas un conseil financier. Les rendements passes ne '
          'presagent pas des rendements futurs. Consulte un·e specialiste '
          'pour un plan personnalise. LSFin.',
      sources: [
        'LAVS art. 21-29 (rente AVS)',
        'LPP art. 14 (taux de conversion)',
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 79b (rachat)',
      ],
    );
  }

  /// Projette un scenario unique avec des hypotheses custom
  /// (utile pour les sliders "Et si...")
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

  /// Projette avec des hypotheses "Et si..." personnalisees.
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
  }) {
    final target = targetDate ?? profile.goalA.targetDate;

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

    // Taux de remplacement base (household income for couples)
    final mainBreakdownCustom = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton,
      age: profile.age,
    );
    final revenuNetMensuel = mainBreakdownCustom.monthlyNetPayslip;
    final conjointCustom = profile.conjoint;
    final partnerNetMensuel = conjointCustom != null &&
            conjointCustom.salaireBrutMensuel != null &&
            conjointCustom.age != null
        ? NetIncomeBreakdown.compute(
            grossSalary: conjointCustom.salaireBrutMensuel! * 12,
            canton: profile.canton,
            age: conjointCustom.age!,
          ).monthlyNetPayslip
        : 0.0;
    final householdNetAnnuel = (revenuNetMensuel + partnerNetMensuel) * 12;
    final tauxRemplacement = _safeReplacementRate(
      annualRetirementIncome: scenarioBase.revenuAnnuelRetraite,
      annualCurrentIncome: householdNetAnnuel,
    );

    final milestones = _detectMilestones(scenarioBase.points);

    return ProjectionResult(
      prudent: scenarioPrudent,
      base: scenarioBase,
      optimiste: scenarioOptimiste,
      tauxRemplacementBase: tauxRemplacement,
      milestones: milestones,
      disclaimer: 'Simulation "Et si..." a titre educatif uniquement. '
          'Hypotheses de rendement ajustees manuellement. '
          'Ne constitue pas un conseil financier (LSFin). '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'LAVS art. 21-29 (rente AVS)',
        'LPP art. 14 (taux de conversion)',
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 79b (rachat)',
      ],
    );
  }

  /// Calcule le delta mensuel visible au check-in.
  ///
  /// Ce KPI represente l'effort du mois valide (somme des versements),
  /// et non une valeur future composee jusqu'a la retraite.
  /// La valeur future est deja couverte par la projection complete.
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
        revenuAnnuelRetraite: 0,
        decomposition: const {},
      );
    }

    // --- Initial balances ---
    double lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
    double threeABalance = profile.prevoyance.totalEpargne3a;
    double investmentBalance = profile.patrimoine.investissements;
    double savingsBalance = profile.patrimoine.epargneLiquide;

    // Conjoint balances
    double conjLppBalance = profile.conjoint?.prevoyance?.avoirLppTotal ?? 0;
    double conjSavingsBalance = 0; // Conjoint savings → libre

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
    final conjFirstName =
        profile.conjoint?.firstName?.toLowerCase() ?? '';

    // Partner 3a contribution potential: if conjoint exists, has income,
    // AND can contribute to 3a (e.g. FATCA US persons cannot).
    // Add 604.83 CHF/month (7258/12) as potential 3a contribution
    // (only if not already captured in planned contributions)
    double partner3aMonthly = 0;
    if (profile.conjoint != null &&
        (profile.conjoint!.salaireBrutMensuel ?? 0) > 0 &&
        (profile.conjoint!.prevoyance?.canContribute3a ?? true)) {
      final conjAnnualSalary =
          (profile.conjoint!.salaireBrutMensuel ?? 0) * 12;
      // Partner is salaried with LPP if their salary exceeds the LPP threshold
      if (conjAnnualSalary > lppSeuilEntree) {
        // Check if partner 3a is already in planned contributions
        final hasPartner3a = profile.plannedContributions.any((c) =>
            c.category == '3a' &&
            conjFirstName.isNotEmpty &&
            c.id.toLowerCase().contains(conjFirstName));
        if (!hasPartner3a) {
          partner3aMonthly = pilier3aPlafondAvecLpp / 12; // 604.83
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
    final lppMonthlyRate = assumptions.lppReturn / 12;
    final threeAMonthlyRate = assumptions.threeAReturn / 12;
    final investMonthlyRate = assumptions.investmentReturn / 12;
    final savingsMonthlyRate = assumptions.savingsReturn / 12;
    final conjLppMonthlyRate = (profile.conjoint?.prevoyance?.rendementCaisse ??
            assumptions.lppReturn) /
        12;

    // Partner 3a balance (separate from main user 3a)
    double partner3aBalance = 0;

    // 3a annual cap tracking
    const plafond3a = pilier3aPlafondAvecLpp;
    double threeAYearContrib = 0;
    double partner3aYearContrib = 0;
    int currentYear = now.year;

    // --- Projection loop ---
    final points = <ProjectionPoint>[];
    double totalRendement = 0;

    for (int m = 0; m < months; m++) {
      final date = DateTime(now.year, now.month + m + 1);

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
      final conjAge = (profile.conjoint?.age ?? profile.age) + (m ~/ 12);
      final conjAnnualSalary = (profile.conjoint?.salaireBrutMensuel ?? 0) * 12;
      conjLppBalance = LppCalculator.projectOneMonth(
        currentBalance: conjLppBalance,
        age: conjAge,
        grossAnnualSalary: conjAnnualSalary,
        monthlyReturn: conjLppMonthlyRate,
      );
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
    final grossAnnualSalary = profile.salaireBrutMensuel * 12;
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;

    // AVS user — RAMD-based, with arrivalAge/lacunes (LAVS art. 34)
    final avsUserMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: profile.age,
      retirementAge: retirementAge,
      arrivalAge: profile.arrivalAge,
      anneesContribuees: profile.prevoyance.anneesContribuees,
      lacunes: profile.prevoyance.lacunesAVS ?? 0,
      grossAnnualSalary: grossAnnualSalary,
    );

    // AVS conjoint — pass anneesContribuees (LAVS art. 29bis)
    double avsConjointMonthly = 0;
    final conjRetirementAge =
        profile.conjoint?.effectiveRetirementAge ?? retirementAge;
    if (profile.conjoint != null) {
      final conjAge = profile.conjoint!.age ?? profile.age;
      final conjSalary = (profile.conjoint!.salaireBrutMensuel ?? 0) * 12;
      avsConjointMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: conjAge,
        retirementAge: conjRetirementAge,
        arrivalAge: profile.conjoint!.arrivalAge,
        anneesContribuees: profile.conjoint!.prevoyance?.anneesContribuees,
        lacunes: profile.conjoint!.prevoyance?.lacunesAVS ?? 0,
        grossAnnualSalary: conjSalary,
      );
    }

    // Couple cap: married only (LAVS art. 35)
    final coupleAvs = AvsCalculator.computeCouple(
      avsUser: avsUserMonthly,
      avsConjoint: avsConjointMonthly,
      isMarried: isMarried,
    );
    final renteAvsAnnuelle = coupleAvs.total * 12;

    // LPP rente — adjust conversion rate for early retirement (LPP art. 13)
    final userConvRate = LppCalculator.adjustedConversionRate(
      baseRate: profile.prevoyance.tauxConversion,
      retirementAge: retirementAge,
    );
    final renteLppUser = lppBalance * userConvRate;
    final conjConvRate = LppCalculator.adjustedConversionRate(
      baseRate: profile.conjoint?.prevoyance?.tauxConversion ?? 0.068,
      retirementAge: conjRetirementAge,
    );
    final renteLppConjoint = conjLppBalance * conjConvRate;

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

    final revenuRetraiteAnnuel = renteAvsAnnuelle +
        renteLppUser +
        renteLppConjoint +
        retrait3aAnnualise +
        rendementLibreAnnuel;

    final capitalFinal = points.isNotEmpty ? points.last.capitalCumule : 0.0;

    return ProjectionScenario(
      label: assumptions.label,
      points: points,
      capitalFinal: capitalFinal,
      revenuAnnuelRetraite: revenuRetraiteAnnuel,
      decomposition: {
        'avs': renteAvsAnnuelle,
        'avs_user': coupleAvs.user * 12,
        'avs_conjoint': coupleAvs.conjoint * 12,
        'lpp_user': renteLppUser,
        'lpp_conjoint': renteLppConjoint,
        '3a': retrait3aAnnualise,
        'libre': rendementLibreAnnuel,
      },
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
                'CHF ${_formatNumber(threshold.toDouble())} de capital atteint',
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

  static double _safeReplacementRate({
    required double annualRetirementIncome,
    required double annualCurrentIncome,
  }) {
    // Evite les pourcentages absurdes quand le revenu courant est incomplet
    // (profil partiel, valeur aberrante, import inachevé).
    if (annualCurrentIncome <= 0 || annualRetirementIncome <= 0) return 0.0;
    if (annualCurrentIncome < 12000) return 0.0;
    final raw = annualRetirementIncome / annualCurrentIncome * 100;
    if (!raw.isFinite) return 0.0;
    return raw.clamp(0.0, 200.0);
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
