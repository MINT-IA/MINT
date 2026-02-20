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
    final revenuNetMensuel = profile.salaireBrutMensuel * 0.87;
    final revenuNetAnnuel = revenuNetMensuel * 12;
    final tauxRemplacement = revenuNetAnnuel > 0
        ? (scenarioBase.revenuAnnuelRetraite / revenuNetAnnuel * 100)
        : 0.0;

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

    // Taux de remplacement base
    final revenuNetMensuel = profile.salaireBrutMensuel * 0.87;
    final revenuNetAnnuel = revenuNetMensuel * 12;
    final tauxRemplacement = revenuNetAnnuel > 0
        ? (scenarioBase.revenuAnnuelRetraite / revenuNetAnnuel * 100)
        : 0.0;

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

  /// Calcule le delta mensuel (impact d'un mois de versements)
  static double calculateMonthlyDelta({
    required CoachProfile profile,
    required Map<String, double> versements,
  }) {
    final targetDate = profile.goalA.targetDate;
    final months = _monthsBetween(DateTime.now(), targetDate);
    if (months <= 0) {
      return versements.values.fold(0.0, (sum, v) => sum + v);
    }

    final base = ScenarioAssumptions.base;
    final monthlyRates = <String, double>{
      '3a': _monthlyRate(base.threeAReturn),
      'lpp_buyback': _monthlyRate(base.lppReturn),
      'investissement': _monthlyRate(base.investmentReturn),
      'epargne_libre': _monthlyRate(base.savingsReturn),
    };

    String? categoryForId(String id) {
      for (final c in profile.plannedContributions) {
        if (c.id == id) return c.category;
      }
      return null;
    }

    double delta = 0;
    for (final entry in versements.entries) {
      final category = categoryForId(entry.key);
      final monthlyRate =
          monthlyRates[category] ?? _monthlyRate(base.savingsReturn);
      delta += entry.value * pow(1 + monthlyRate, months);
    }
    return delta;
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

    // Conjoint LPP buyback
    double conjMonthlyLppBuyback = 0;
    for (final c in profile.plannedContributions) {
      if (c.id.contains('lauren') && c.category == 'lpp_buyback') {
        conjMonthlyLppBuyback += c.amount;
        // Remove from main person's total
        monthlyLppBuyback -= c.amount;
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

    // 3a annual cap tracking
    const plafond3a = pilier3aPlafondAvecLpp;
    double threeAYearContrib = 0;
    int currentYear = now.year;

    // --- Projection loop ---
    final points = <ProjectionPoint>[];
    double totalRendement = 0;

    for (int m = 0; m < months; m++) {
      final date = DateTime(now.year, now.month + m + 1);

      // Reset 3a cap at year boundary
      if (date.year != currentYear) {
        threeAYearContrib = 0;
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

      // --- Apply contributions ---
      // 3a (capped at annual plafond)
      double effective3a = monthly3a;
      if (threeAYearContrib + effective3a > plafond3a) {
        effective3a = (plafond3a - threeAYearContrib).clamp(0, plafond3a);
      }
      threeABalance += effective3a;
      threeAYearContrib += effective3a;

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
          investmentBalance +
          savingsBalance +
          conjLppBalance +
          conjSavingsBalance;
      final totalContrib = effective3a +
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

    // 3a: annualize over 20 years
    final retrait3aAnnualise = threeABalance / 20;

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
