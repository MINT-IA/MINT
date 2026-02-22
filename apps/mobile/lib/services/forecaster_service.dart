import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

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
    final revenuNetMensuel = profile.salaireBrutMensuel * 0.87;
    final partnerNetMensuel =
        (profile.conjoint?.salaireBrutMensuel ?? 0) * 0.87;
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
    final revenuNetMensuel = profile.salaireBrutMensuel * 0.87;
    final partnerNetMensuel =
        (profile.conjoint?.salaireBrutMensuel ?? 0) * 0.87;
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
    double conjSavingsBalance = 0; // Lauren's savings go to libre

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
    // Partner 3a contribution potential: if conjoint exists and has income,
    // add 604.83 CHF/month (7258/12) as potential 3a contribution
    // (only if not already captured in planned contributions)
    double partner3aMonthly = 0;
    if (profile.conjoint != null &&
        (profile.conjoint!.salaireBrutMensuel ?? 0) > 0) {
      final conjAnnualSalary =
          (profile.conjoint!.salaireBrutMensuel ?? 0) * 12;
      // Partner is salaried with LPP if their salary exceeds the LPP threshold
      if (conjAnnualSalary > lppSeuilEntree) {
        // Check if partner 3a is already in planned contributions
        final hasPartner3a = profile.plannedContributions
            .any((c) => c.category == '3a' && c.id.contains('partner'));
        if (!hasPartner3a) {
          partner3aMonthly = pilier3aPlafondAvecLpp / 12; // 604.83
        }
      }
    }

    // Conjoint LPP buyback — split before smart check-in adjustment
    double conjMonthlyLppBuyback = 0;
    for (final c in profile.plannedContributions) {
      if (c.id.contains('lauren') && c.category == 'lpp_buyback') {
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
      final lppReturn = lppBalance * lppMonthlyRate;
      lppBalance += lppReturn;

      final threeAReturn = threeABalance * threeAMonthlyRate;
      threeABalance += threeAReturn;

      final investReturn = investmentBalance * investMonthlyRate;
      investmentBalance += investReturn;

      final savingsReturn = savingsBalance * savingsMonthlyRate;
      savingsBalance += savingsReturn;

      final conjLppReturn = conjLppBalance * conjLppMonthlyRate;
      conjLppBalance += conjLppReturn;

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
      // 3a (capped at annual plafond)
      double effective3a = monthly3a;
      if (threeAYearContrib + effective3a > plafond3a) {
        effective3a = (plafond3a - threeAYearContrib).clamp(0, plafond3a);
      }
      threeABalance += effective3a;
      threeAYearContrib += effective3a;

      // Partner 3a (capped at annual plafond independently)
      double effectivePartner3a = partner3aMonthly;
      if (partner3aYearContrib + effectivePartner3a > plafond3a) {
        effectivePartner3a =
            (plafond3a - partner3aYearContrib).clamp(0, plafond3a);
      }
      partner3aBalance += effectivePartner3a;
      partner3aYearContrib += effectivePartner3a;

      // LPP buyback (capped at remaining lacune)
      double effectiveLppBuyback = monthlyLppBuyback;
      if (lppBuybackDone + effectiveLppBuyback > lppBuybackCap) {
        effectiveLppBuyback =
            (lppBuybackCap - lppBuybackDone).clamp(0, lppBuybackCap);
      }
      lppBalance += effectiveLppBuyback;
      lppBuybackDone += effectiveLppBuyback;

      // Conjoint LPP buyback
      double effectiveConjBuyback = conjMonthlyLppBuyback;
      if (conjLppBuybackDone + effectiveConjBuyback > conjLppBuybackCap) {
        effectiveConjBuyback = (conjLppBuybackCap - conjLppBuybackDone)
            .clamp(0, conjLppBuybackCap);
      }
      conjLppBalance += effectiveConjBuyback;
      conjLppBuybackDone += effectiveConjBuyback;

      // Investment + savings
      investmentBalance += monthlyInvestment;
      savingsBalance += monthlySavings;

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
    final avsResult = _estimateAvsCouple(profile);
    final renteAvsAnnuelle = avsResult['renteAnnuelleCouple'] as double;

    final renteLppJulien = lppBalance * (lppTauxConversionMin / 100);
    final renteLppLauren = conjLppBalance * (lppTauxConversionMin / 100);

    // 3a: annualize over 20 years (both user + partner)
    final retrait3aAnnualise = (threeABalance + partner3aBalance) / 20;

    // Free: 4% safe withdrawal rate
    final rendementLibreAnnuel =
        (investmentBalance + savingsBalance + conjSavingsBalance) * 0.04;

    final revenuRetraiteAnnuel = renteAvsAnnuelle +
        renteLppJulien +
        renteLppLauren +
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
        'lpp_julien': renteLppJulien,
        'lpp_conjoint': renteLppLauren,
        '3a': retrait3aAnnualise,
        'libre': rendementLibreAnnuel,
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  AVS ESTIMATION
  // ════════════════════════════════════════════════════════════════

  static Map<String, double> _estimateAvsCouple(CoachProfile profile) {
    // Julien
    final ageJulien = profile.age;
    final anneesContribJulien = profile.prevoyance.anneesContribuees ??
        (ageJulien - 20).clamp(0, avsDureeCotisationComplete);
    final gapFactorJulien = anneesContribJulien / avsDureeCotisationComplete;
    final renteJulienMensuelle = avsRenteMaxMensuelle * gapFactorJulien;

    // Conjoint
    double renteConjointMensuelle = 0;
    if (profile.conjoint != null) {
      final conjAge = profile.conjoint!.age ?? 45;
      final lacunes = profile.conjoint?.prevoyance?.lacunesAVS ?? 0;
      final anneesContribConj =
          ((conjAge - 20).clamp(0, avsDureeCotisationComplete) - lacunes)
              .clamp(0, avsDureeCotisationComplete);
      final gapFactorConj = anneesContribConj / avsDureeCotisationComplete;
      renteConjointMensuelle = avsRenteMaxMensuelle * gapFactorConj;
    }

    // Plafonnement couple (150% de la rente max individuelle)
    double renteTotaleMensuelle;
    if (profile.isCouple) {
      renteTotaleMensuelle = min(
        renteJulienMensuelle + renteConjointMensuelle,
        avsRenteCoupleMaxMensuelle,
      );
    } else {
      renteTotaleMensuelle = renteJulienMensuelle;
    }

    return {
      'renteJulienMensuelle': renteJulienMensuelle,
      'renteConjointMensuelle': renteConjointMensuelle,
      'renteTotaleMensuelle': renteTotaleMensuelle,
      'renteAnnuelleCouple': renteTotaleMensuelle * 12,
    };
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

  static double _monthlyRate(double annualRate) {
    return pow(1 + annualRate, 1 / 12) - 1;
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
