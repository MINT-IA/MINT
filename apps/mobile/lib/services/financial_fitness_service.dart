import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  FINANCIAL FITNESS SERVICE — Sprint C2 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Calcule le Financial Fitness Score (FFS) : un score composite
// de 0 a 100 base sur 3 sous-scores (Budget, Prevoyance, Patrimoine).
//
// Analogie sportive : c'est le "FTP" ou "VO2max" financier.
// Le score evolue mensuellement via les check-ins.
//
// Aucun terme banni. Ton pedagogique.
// ────────────────────────────────────────────────────────────

/// Niveau du score
enum FitnessLevel {
  critique, // 0-39
  attention, // 40-59
  bon, // 60-79
  excellent, // 80-100
}

extension FitnessLevelExtension on FitnessLevel {
  String get label {
    switch (this) {
      case FitnessLevel.critique:
        return 'Priorite : stabilisons tes bases.';
      case FitnessLevel.attention:
        return 'Attention : quelques points a ameliorer.';
      case FitnessLevel.bon:
        return 'Bien ! Tu es sur la bonne voie.';
      case FitnessLevel.excellent:
        return 'Excellent ! Tu es en avance sur ta trajectoire.';
    }
  }

  String get shortLabel {
    switch (this) {
      case FitnessLevel.critique:
        return 'Critique';
      case FitnessLevel.attention:
        return 'Attention';
      case FitnessLevel.bon:
        return 'Bon';
      case FitnessLevel.excellent:
        return 'Excellent';
    }
  }
}

/// Tendance du score par rapport au mois precedent
enum ScoreTrend { up, stable, down }

extension ScoreTrendExtension on ScoreTrend {
  String get symbol {
    switch (this) {
      case ScoreTrend.up:
        return '\u2191'; // ↑
      case ScoreTrend.stable:
        return '\u2192'; // →
      case ScoreTrend.down:
        return '\u2193'; // ↓
    }
  }
}

/// Detail d'un critere de scoring
class ScoreCriterion {
  final String id;
  final String label;
  final int points; // 0-25
  final int maxPoints;
  final String detail;

  const ScoreCriterion({
    required this.id,
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.detail,
  });

  double get ratio => maxPoints > 0 ? points / maxPoints : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'points': points,
    'maxPoints': maxPoints,
    'detail': detail,
  };
}

/// Sous-score (Budget, Prevoyance, ou Patrimoine)
class SubScore {
  final String name;
  final int score; // 0-100
  final double weight; // poids dans le score global
  final List<ScoreCriterion> criteria;

  const SubScore({
    required this.name,
    required this.score,
    required this.weight,
    required this.criteria,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'weight': weight,
    'criteria': criteria.map((c) => c.toJson()).toList(),
  };
}

/// Financial Fitness Score complet
class FinancialFitnessScore {
  final int global; // 0-100
  final SubScore budget;
  final SubScore prevoyance;
  final SubScore patrimoine;
  final FitnessLevel level;
  final ScoreTrend trend;
  final int? deltaVsPreviousMonth;
  final String coachMessage;
  final DateTime calculatedAt;

  const FinancialFitnessScore({
    required this.global,
    required this.budget,
    required this.prevoyance,
    required this.patrimoine,
    required this.level,
    required this.trend,
    this.deltaVsPreviousMonth,
    required this.coachMessage,
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
    'global': global,
    'budget': budget.toJson(),
    'prevoyance': prevoyance.toJson(),
    'patrimoine': patrimoine.toJson(),
    'level': level.name,
    'trend': trend.name,
    'deltaVsPreviousMonth': deltaVsPreviousMonth,
    'coachMessage': coachMessage,
    'calculatedAt': calculatedAt.toIso8601String(),
  };
}

/// Service de calcul du Financial Fitness Score.
///
/// Toutes les methodes sont statiques et pures.
class FinancialFitnessService {
  FinancialFitnessService._();

  // ════════════════════════════════════════════════════════════════
  //  WEIGHTS
  // ════════════════════════════════════════════════════════════════

  static const double _weightBudget = 0.35;
  static const double _weightPrevoyance = 0.40;
  static const double _weightPatrimoine = 0.25;

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Calcule le Financial Fitness Score pour un profil donne.
  ///
  /// Si [previousScore] est fourni, calcule la tendance et le delta.
  static FinancialFitnessScore calculate({
    required CoachProfile profile,
    int? previousScore,
  }) {
    final budgetScore = _calculateBudget(profile);
    final prevoyanceScore = _calculatePrevoyance(profile);
    final patrimoineScore = _calculatePatrimoine(profile);

    final global = (budgetScore.score * _weightBudget +
            prevoyanceScore.score * _weightPrevoyance +
            patrimoineScore.score * _weightPatrimoine)
        .round()
        .clamp(0, 100);

    final level = _getLevel(global);
    final trend = _getTrend(global, previousScore);
    final delta = previousScore != null ? global - previousScore : null;

    final message = _generateCoachMessage(
      level: level,
      budget: budgetScore,
      prevoyance: prevoyanceScore,
      patrimoine: patrimoineScore,
      profile: profile,
    );

    return FinancialFitnessScore(
      global: global,
      budget: budgetScore,
      prevoyance: prevoyanceScore,
      patrimoine: patrimoineScore,
      level: level,
      trend: trend,
      deltaVsPreviousMonth: delta,
      coachMessage: message,
      calculatedAt: DateTime.now(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUDGET SUB-SCORE (35%)
  // ════════════════════════════════════════════════════════════════

  static SubScore _calculateBudget(CoachProfile profile) {
    final criteria = <ScoreCriterion>[];

    // 1. Reste a vivre > 20% du revenu (0-25 points)
    final resteAVivre = profile.resteAVivreMensuel;
    final revenuNet = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton,
      age: profile.age,
    ).monthlyNetPayslip;
    final ratioResteAVivre = revenuNet > 0 ? resteAVivre / revenuNet : 0.0;
    final pointsResteAVivre = ratioResteAVivre >= 0.20
        ? 25
        : (ratioResteAVivre / 0.20 * 25).round().clamp(0, 25);
    criteria.add(ScoreCriterion(
      id: 'reste_a_vivre',
      label: 'Reste a vivre',
      points: pointsResteAVivre,
      maxPoints: 25,
      detail: ratioResteAVivre >= 0.20
          ? '${(ratioResteAVivre * 100).toStringAsFixed(0)}% — au-dessus du seuil de 20%'
          : '${(ratioResteAVivre * 100).toStringAsFixed(0)}% — en dessous du seuil de 20%',
    ));

    // 2. Fonds d'urgence >= 3 mois (0-25 points)
    final depensesMensuelles = profile.totalDepensesMensuelles;
    final epargneLiquide = profile.patrimoine.epargneLiquide;
    final moisCouverts =
        depensesMensuelles > 0 ? epargneLiquide / depensesMensuelles : 0.0;
    final pointsFondsUrgence = moisCouverts >= 6
        ? 25
        : moisCouverts >= 3
            ? 20
            : (moisCouverts / 3 * 20).round().clamp(0, 20);
    criteria.add(ScoreCriterion(
      id: 'fonds_urgence',
      label: 'Fonds d\'urgence',
      points: pointsFondsUrgence,
      maxPoints: 25,
      detail: moisCouverts >= 3
          ? '${moisCouverts.toStringAsFixed(1)} mois couverts'
          : '${moisCouverts.toStringAsFixed(1)} mois (cible : 3 mois minimum)',
    ));

    // 3. Pas de dette consommation (0 ou 25 points)
    final hasDetteConso = (profile.dettes.creditConsommation ?? 0) > 0 ||
        (profile.dettes.leasing ?? 0) > 0;
    final pointsDette = hasDetteConso ? 0 : 25;
    criteria.add(ScoreCriterion(
      id: 'dette_consommation',
      label: 'Pas de dette consommation',
      points: pointsDette,
      maxPoints: 25,
      detail: hasDetteConso
          ? 'Dette de consommation detectee — priorite reduction'
          : 'Aucune dette de consommation',
    ));

    // 4. Budget tenu / epargne reguliere (0-25 points)
    final totalContributions = profile.totalContributionsMensuelles;
    final tauxEpargne =
        revenuNet > 0 ? totalContributions / revenuNet : 0.0;
    final pointsBudget = tauxEpargne >= 0.20
        ? 25
        : (tauxEpargne / 0.20 * 25).round().clamp(0, 25);
    criteria.add(ScoreCriterion(
      id: 'taux_epargne',
      label: 'Taux d\'epargne',
      points: pointsBudget,
      maxPoints: 25,
      detail:
          '${(tauxEpargne * 100).toStringAsFixed(0)}% du revenu net epargne/investi',
    ));

    final total =
        criteria.fold(0, (sum, c) => sum + c.points);
    final score = (total / 100 * 100).round().clamp(0, 100);

    return SubScore(
      name: 'Budget',
      score: score,
      weight: _weightBudget,
      criteria: criteria,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PREVOYANCE SUB-SCORE (40%)
  // ════════════════════════════════════════════════════════════════

  static SubScore _calculatePrevoyance(CoachProfile profile) {
    final criteria = <ScoreCriterion>[];

    // 1. 3a maximise (0-25 points)
    final plafond3a = profile.employmentStatus == 'independant'
        ? reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp)
        : reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    final contribution3aAnnuelle = profile.total3aMensuel * 12;
    final ratio3a = plafond3a > 0 ? contribution3aAnnuelle / plafond3a : 0.0;
    final points3a = ratio3a >= 1.0
        ? 25
        : (ratio3a * 25).round().clamp(0, 25);
    criteria.add(ScoreCriterion(
      id: '3a_maximise',
      label: '3a maximise',
      points: points3a,
      maxPoints: 25,
      detail: ratio3a >= 1.0
          ? 'Plafond 3a atteint (${_formatChf(plafond3a)})'
          : '${_formatChf(contribution3aAnnuelle)} / ${_formatChf(plafond3a)} par an',
    ));

    // 2. LPP : rachat en cours ou lacune comblee (0-25 points)
    final lacune = profile.prevoyance.lacuneRachatRestante;
    final rachatMensuel = profile.totalLppBuybackMensuel;
    int pointsLpp;
    String detailLpp;

    if (lacune <= 0) {
      pointsLpp = 25;
      detailLpp = 'Lacune LPP comblee';
    } else if (rachatMensuel > 0) {
      // Rachat en cours : scorer proportionnellement
      final anneesRachat = lacune / (rachatMensuel * 12);
      pointsLpp = anneesRachat <= 5 ? 20 : anneesRachat <= 10 ? 15 : 10;
      detailLpp =
          'Rachat en cours (${_formatChf(rachatMensuel)}/mois, ~${anneesRachat.toStringAsFixed(0)} ans restants)';
    } else {
      pointsLpp = 0;
      detailLpp = 'Lacune de ${_formatChf(lacune)} — aucun rachat planifie';
    }
    criteria.add(ScoreCriterion(
      id: 'lpp_buyback',
      label: 'Rachat LPP',
      points: pointsLpp,
      maxPoints: 25,
      detail: detailLpp,
    ));

    // 3. Pas de lacune AVS critique (0-25 points)
    final lacunesAvs = profile.prevoyance.lacunesAVS ?? 0;
    final lacunesAvsConjoint =
        profile.conjoint?.prevoyance?.lacunesAVS ?? 0;
    final totalLacunes = lacunesAvs + lacunesAvsConjoint;
    int pointsAvs;
    String detailAvs;

    if (totalLacunes == 0) {
      pointsAvs = 25;
      detailAvs = 'Aucune lacune AVS';
    } else if (totalLacunes <= 2) {
      pointsAvs = 20;
      detailAvs = '$totalLacunes annee(s) de lacune AVS';
    } else if (totalLacunes <= 5) {
      pointsAvs = 10;
      detailAvs = '$totalLacunes annees de lacune AVS — impact significatif';
    } else {
      pointsAvs = 0;
      detailAvs =
          '$totalLacunes annees de lacune AVS — impact important sur la rente';
    }
    criteria.add(ScoreCriterion(
      id: 'avs_gaps',
      label: 'Lacunes AVS',
      points: pointsAvs,
      maxPoints: 25,
      detail: detailAvs,
    ));

    // 4. Couverture invalidite (0-25 points)
    // Simplified: has LPP = some coverage, self-employed without = 0
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    final isSelfEmployed = profile.employmentStatus == 'independant';
    int pointsInvalidite;
    String detailInvalidite;

    if (hasLpp) {
      pointsInvalidite = 20; // LPP provides some coverage
      detailInvalidite = 'Couverture via LPP (verifie ton certificat)';
    } else if (isSelfEmployed) {
      pointsInvalidite = 0;
      detailInvalidite = 'Independant sans LPP — couverture AI minimale';
    } else {
      pointsInvalidite = 10;
      detailInvalidite = 'Situation a verifier';
    }
    criteria.add(ScoreCriterion(
      id: 'invalidite',
      label: 'Couverture invalidite',
      points: pointsInvalidite,
      maxPoints: 25,
      detail: detailInvalidite,
    ));

    final total =
        criteria.fold(0, (sum, c) => sum + c.points);
    final score = (total / 100 * 100).round().clamp(0, 100);

    return SubScore(
      name: 'Prevoyance',
      score: score,
      weight: _weightPrevoyance,
      criteria: criteria,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PATRIMOINE SUB-SCORE (25%)
  // ════════════════════════════════════════════════════════════════

  static SubScore _calculatePatrimoine(CoachProfile profile) {
    final criteria = <ScoreCriterion>[];

    // 1. Epargne investie (pas seulement compte) (0-25 points)
    final totalPatrimoine = profile.patrimoine.totalPatrimoine;
    final investissements = profile.patrimoine.investissements;
    final ratioInvesti =
        totalPatrimoine > 0 ? investissements / totalPatrimoine : 0.0;
    final pointsInvesti = ratioInvesti >= 0.50
        ? 25
        : (ratioInvesti / 0.50 * 25).round().clamp(0, 25);
    criteria.add(ScoreCriterion(
      id: 'epargne_investie',
      label: 'Epargne investie',
      points: pointsInvesti,
      maxPoints: 25,
      detail:
          '${(ratioInvesti * 100).toStringAsFixed(0)}% du patrimoine est investi',
    ));

    // 2. Diversification (0-25 points)
    int diversificationCount = 0;
    if (profile.patrimoine.epargneLiquide > 0) diversificationCount++;
    if (profile.patrimoine.investissements > 0) diversificationCount++;
    if ((profile.patrimoine.immobilier ?? 0) > 0) diversificationCount++;
    if (profile.prevoyance.totalEpargne3a > 0) diversificationCount++;
    if ((profile.prevoyance.avoirLppTotal ?? 0) > 0) diversificationCount++;

    final pointsDiversification = diversificationCount >= 4
        ? 25
        : diversificationCount >= 3
            ? 20
            : diversificationCount >= 2
                ? 12
                : 5;
    criteria.add(ScoreCriterion(
      id: 'diversification',
      label: 'Diversification',
      points: pointsDiversification,
      maxPoints: 25,
      detail: '$diversificationCount classes d\'actifs differentes',
    ));

    // 3. Croissance nette positive (0-25 points)
    // Based on monthly contributions vs expenses
    final monthlyGrowth = profile.totalContributionsMensuelles;
    final pointsCroissance = monthlyGrowth > 0
        ? (monthlyGrowth > 2000 ? 25 : (monthlyGrowth / 2000 * 25).round().clamp(0, 25))
        : 0;
    criteria.add(ScoreCriterion(
      id: 'croissance',
      label: 'Croissance nette',
      points: pointsCroissance,
      maxPoints: 25,
      detail: monthlyGrowth > 0
          ? '${_formatChf(monthlyGrowth)}/mois en contributions'
          : 'Aucune contribution mensuelle planifiee',
    ));

    // 4. Objectif patrimoine sur trajectoire (0-25 points)
    // Based on streak and check-in regularity
    final streak = profile.streak;
    final checkIns = profile.checkInsCompletes;
    int pointsTrajectoire;
    String detailTrajectoire;

    if (checkIns == 0) {
      pointsTrajectoire = 0;
      detailTrajectoire = 'Pas encore de check-in — commence a suivre ta progression';
    } else if (streak >= 6) {
      pointsTrajectoire = 25;
      detailTrajectoire = '$streak mois consecutifs on-track';
    } else if (streak >= 3) {
      pointsTrajectoire = 18;
      detailTrajectoire = '$streak mois consecutifs on-track';
    } else {
      pointsTrajectoire = 8;
      detailTrajectoire = '$checkIns check-in(s) — continue pour ameliorer';
    }
    criteria.add(ScoreCriterion(
      id: 'trajectoire',
      label: 'Suivi trajectoire',
      points: pointsTrajectoire,
      maxPoints: 25,
      detail: detailTrajectoire,
    ));

    final total =
        criteria.fold(0, (sum, c) => sum + c.points);
    final score = (total / 100 * 100).round().clamp(0, 100);

    return SubScore(
      name: 'Patrimoine',
      score: score,
      weight: _weightPatrimoine,
      criteria: criteria,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  static FitnessLevel _getLevel(int score) {
    if (score >= 80) return FitnessLevel.excellent;
    if (score >= 60) return FitnessLevel.bon;
    if (score >= 40) return FitnessLevel.attention;
    return FitnessLevel.critique;
  }

  static ScoreTrend _getTrend(int current, int? previous) {
    if (previous == null) return ScoreTrend.stable;
    if (current > previous) return ScoreTrend.up;
    if (current < previous) return ScoreTrend.down;
    return ScoreTrend.stable;
  }

  static String _generateCoachMessage({
    required FitnessLevel level,
    required SubScore budget,
    required SubScore prevoyance,
    required SubScore patrimoine,
    required CoachProfile profile,
  }) {
    // Find the weakest pillar
    final scores = {
      'budget': budget.score,
      'prevoyance': prevoyance.score,
      'patrimoine': patrimoine.score,
    };
    final weakest = scores.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );

    switch (level) {
      case FitnessLevel.excellent:
        return 'Tu es en avance sur ta trajectoire. Continue comme ca !';
      case FitnessLevel.bon:
        if (weakest.key == 'prevoyance') {
          return 'Bonne base ! Pour progresser, concentre-toi sur ta prevoyance (3a, LPP).';
        } else if (weakest.key == 'budget') {
          return 'Bonne base ! Ameliorer ton budget et fonds d\'urgence te ferait passer au niveau superieur.';
        }
        return 'Bonne base ! Focus sur ton patrimoine pour progresser.';
      case FitnessLevel.attention:
        if (profile.dettes.hasDette) {
          return 'Priorite : reduire tes dettes de consommation avant d\'optimiser.';
        }
        return 'Des progres a faire, mais tu es sur la bonne voie. Un pas a la fois.';
      case FitnessLevel.critique:
        return 'Commencons par les fondamentaux : budget, fonds d\'urgence, et reduction des dettes.';
    }
  }

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}
