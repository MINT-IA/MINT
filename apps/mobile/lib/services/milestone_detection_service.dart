import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MILESTONE DETECTION SERVICE — T5 / Coach AI Layer + S36
// ────────────────────────────────────────────────────────────
//
// Detecte les nouveaux milestones financiers atteints depuis
// le dernier check-in. Compare l'etat actuel vs l'etat persiste
// precedent (SharedPreferences).
//
// S36 additions:
//   - MilestoneType enum for type-safe milestone identification
//   - DetectedMilestone model for snapshot-based comparison
//   - detect() static method for pure snapshot comparison
//
// COMPLIANCE:
// - NEVER social comparison ("top 20% des Suisses" -> BANNED)
// - NEVER guarantee outcomes ("tu es securise" -> BANNED)
// - Always factual: what was achieved, what it means concretely
// - All French (informal "tu")
//
// Milestones detectes :
//   - patrimoine_50k, patrimoine_100k, patrimoine_250k, patrimoine_500k
//   - 3a_max_reached (7'258 CHF salarie / 36'288 CHF independant)
//   - emergency_fund_3m, emergency_fund_6m (mois couverts)
//   - streak_3, streak_6, streak_12 (mois consecutifs check-in)
//   - score_bon (score >= 60), score_excellent (score >= 80)
//   - lpp_buyback_completed, fri_improved_10, fri_above_50/70/85
//   - first_arbitrage_completed
//
// Logique pure sauf SharedPreferences pour la persistence.
// Aucun terme banni. Ton pedagogique, tutoiement.
// ────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
//  S36 — SNAPSHOT-BASED MILESTONE DETECTION
// ════════════════════════════════════════════════════════════

/// Type-safe milestone identifier — Sprint S36.
enum MilestoneType {
  emergencyFund3Months,
  emergencyFund6Months,
  threeAMaxReached,
  lppBuybackCompleted,
  friImproved10Points,
  friAbove50,
  friAbove70,
  friAbove85,
  patrimoine50k,
  patrimoine100k,
  patrimoine250k,
  firstArbitrageCompleted,
  checkInStreak6Months,
  checkInStreak12Months,
}

/// A detected milestone with factual celebration text — Sprint S36.
///
/// Contains the concrete value achieved and a factual celebration
/// message. No social comparison, no guarantees.
class DetectedMilestone {
  /// Type of the milestone.
  final MilestoneType type;

  /// Factual celebration text in French (informal "tu").
  final String celebrationText;

  /// Concrete value highlighted (e.g. "CHF 50'000", "72/100").
  final String concreteValue;

  /// When this milestone was detected.
  final DateTime detectedAt;

  const DetectedMilestone({
    required this.type,
    required this.celebrationText,
    required this.concreteValue,
    required this.detectedAt,
  });
}

/// Evenement milestone celebre par l'utilisateur.
class MilestoneEvent {
  /// Identifiant unique (ex: "patrimoine_100k")
  final String id;

  /// Titre court en francais (ex: "Cap des CHF 100'000")
  final String title;

  /// Description pedagogique (ex: "Ton patrimoine a franchi les 100k !")
  final String description;

  /// Icone Material
  final IconData icon;

  /// Couleur associee (depuis MintColors)
  final Color color;

  /// Message LLM optionnel (genere si BYOK actif)
  String? narrativeMessage;

  MilestoneEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.narrativeMessage,
  });
}

/// Detecte les nouveaux milestones atteints depuis le dernier check-in.
///
/// Compare l'etat actuel vs l'etat persiste precedent.
/// Retourne uniquement les milestones non encore celebres.
///
/// Accepte une instance [SharedPreferences] optionnelle pour les tests.
class MilestoneDetectionService {
  MilestoneDetectionService._();

  /// Cle SharedPreferences pour les milestones deja celebres.
  static const _achievedKey = 'achieved_milestones_v1';

  /// Plafond 3a salarie (OPP3 art. 7, 2025/2026).
  static const _plafond3aSalarie = 7258.0;

  /// Plafond 3a independant sans LPP (20% revenu net, max OPP3 art. 7).
  static const _plafond3aIndependant = 36288.0;

  /// Detecte les nouveaux milestones (pas encore celebres).
  ///
  /// [profile] — profil financier complet (apres check-in).
  /// [currentScore] — score Financial Fitness actuel.
  /// [streak] — resultat du calcul de serie (StreakResult).
  /// [prefs] — instance SharedPreferences (injectable pour les tests).
  ///
  /// Retourne une liste de [MilestoneEvent] pour celebration.
  static Future<List<MilestoneEvent>> detectNew({
    required CoachProfile profile,
    required int currentScore,
    required StreakResult streak,
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final achieved = sp.getStringList(_achievedKey)?.toSet() ?? <String>{};
    final newMilestones = <MilestoneEvent>[];

    // Verifier chaque categorie de milestone
    _checkPatrimoine(profile, achieved, newMilestones);
    _check3aMax(profile, achieved, newMilestones);
    _checkEmergencyFund(profile, achieved, newMilestones);
    _checkStreak(streak, achieved, newMilestones);
    _checkScore(currentScore, achieved, newMilestones);

    // Persister les nouveaux milestones comme "celebres"
    if (newMilestones.isNotEmpty) {
      achieved.addAll(newMilestones.map((m) => m.id));
      await sp.setStringList(_achievedKey, achieved.toList());
    }

    return newMilestones;
  }

  // ── Patrimoine milestones ─────────────────────────────────

  static void _checkPatrimoine(
    CoachProfile profile,
    Set<String> achieved,
    List<MilestoneEvent> out,
  ) {
    // Calcul identique a StreakService.computeMilestones
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;

    if (patrimoine >= 50000 && !achieved.contains('patrimoine_50k')) {
      out.add(MilestoneEvent(
        id: 'patrimoine_50k',
        title: 'Premier jalon : CHF 50\'000',
        description:
            'Ton patrimoine a franchi les CHF 50\'000. C\'est une base solide pour construire ton avenir financier.',
        icon: Icons.emoji_events,
        color: MintColors.warning,
      ));
    }

    if (patrimoine >= 100000 && !achieved.contains('patrimoine_100k')) {
      out.add(MilestoneEvent(
        id: 'patrimoine_100k',
        title: 'Cap des CHF 100\'000',
        description:
            'CHF 100\'000 de patrimoine ! Tu fais partie des personnes qui prennent leur avenir financier au serieux.',
        icon: Icons.workspace_premium,
        color: MintColors.success,
      ));
    }

    if (patrimoine >= 250000 && !achieved.contains('patrimoine_250k')) {
      out.add(MilestoneEvent(
        id: 'patrimoine_250k',
        title: 'Quart de million',
        description:
            'CHF 250\'000 — un quart de million. Ta discipline porte ses fruits. Continue sur cette lancee.',
        icon: Icons.diamond,
        color: MintColors.purple,
      ));
    }

    if (patrimoine >= 500000 && !achieved.contains('patrimoine_500k')) {
      out.add(MilestoneEvent(
        id: 'patrimoine_500k',
        title: 'Demi-million',
        description:
            'CHF 500\'000 de patrimoine. C\'est un accomplissement remarquable qui te donne de la liberte pour tes projets de vie.',
        icon: Icons.stars,
        color: MintColors.indigo,
      ));
    }
  }

  // ── 3a milestone ──────────────────────────────────────────

  static void _check3aMax(
    CoachProfile profile,
    Set<String> achieved,
    List<MilestoneEvent> out,
  ) {
    if (achieved.contains('3a_max_reached')) return;

    // Choisir le plafond selon le statut d'emploi
    final plafond = profile.employmentStatus == 'independant'
        ? _plafond3aIndependant
        : _plafond3aSalarie;

    // Check current year 3a contributions from check-ins
    final currentYear = DateTime.now().year;
    double annual3aFromCheckIns = 0;
    for (final ci in profile.checkIns) {
      if (ci.month.year == currentYear) {
        for (final entry in ci.versements.entries) {
          // Sum all contributions tagged as 3a
          final contribution = profile.plannedContributions
              .where((c) => c.id == entry.key && c.category == '3a')
              .firstOrNull;
          if (contribution != null) {
            annual3aFromCheckIns += entry.value;
          }
        }
      }
    }

    // Also check planned monthly contributions (annualized)
    final annual3aPlanned = profile.total3aMensuel * 12;

    // Use the higher of check-in actuals or planned
    final annual3a =
        annual3aFromCheckIns > 0 ? annual3aFromCheckIns : annual3aPlanned;

    if (annual3a >= plafond) {
      final plafondFormatted = plafond.toStringAsFixed(0);
      out.add(MilestoneEvent(
        id: '3a_max_reached',
        title: '3a au plafond',
        description:
            'Tu as atteint le plafond de CHF $plafondFormatted pour ton 3e pilier. C\'est une facon efficace de combiner prevoyance et economie fiscale (OPP3 art. 7).',
        icon: Icons.savings,
        color: MintColors.indigo,
      ));
    }
  }

  // ── Emergency fund milestones ─────────────────────────────

  static void _checkEmergencyFund(
    CoachProfile profile,
    Set<String> achieved,
    List<MilestoneEvent> out,
  ) {
    final monthlyExpenses = profile.depenses.totalMensuel;
    if (monthlyExpenses <= 0) return;

    final liquidSavings = profile.patrimoine.epargneLiquide;

    if (liquidSavings >= monthlyExpenses * 3 &&
        !achieved.contains('emergency_fund_3m')) {
      out.add(MilestoneEvent(
        id: 'emergency_fund_3m',
        title: 'Matelas de securite : 3 mois',
        description:
            'Ton epargne liquide couvre 3 mois de charges fixes. Tu as un filet de securite en cas d\'imprev.',
        icon: Icons.shield,
        color: MintColors.teal,
      ));
    }

    if (liquidSavings >= monthlyExpenses * 6 &&
        !achieved.contains('emergency_fund_6m')) {
      out.add(MilestoneEvent(
        id: 'emergency_fund_6m',
        title: 'Matelas de securite : 6 mois',
        description:
            'Ton epargne liquide couvre 6 mois de charges fixes. Tu es serein·e face aux coups durs.',
        icon: Icons.security,
        color: MintColors.success,
      ));
    }
  }

  // ── Streak milestones ─────────────────────────────────────

  static void _checkStreak(
    StreakResult streak,
    Set<String> achieved,
    List<MilestoneEvent> out,
  ) {
    if (streak.currentStreak >= 3 && !achieved.contains('streak_3')) {
      out.add(MilestoneEvent(
        id: 'streak_3',
        title: '3 mois consecutifs',
        description:
            'Tu as fait 3 check-ins d\'affilee. La regularite est la cle de la reussite financiere.',
        icon: Icons.local_fire_department,
        color: MintColors.warning,
      ));
    }

    if (streak.currentStreak >= 6 && !achieved.contains('streak_6')) {
      out.add(MilestoneEvent(
        id: 'streak_6',
        title: '6 mois consecutifs',
        description:
            'Un semestre complet de suivi financier. Ta discipline fait la difference.',
        icon: Icons.whatshot,
        color: MintColors.deepOrange,
      ));
    }

    if (streak.currentStreak >= 12 && !achieved.contains('streak_12')) {
      out.add(MilestoneEvent(
        id: 'streak_12',
        title: 'Une annee complete',
        description:
            '12 mois consecutifs de check-in. Tu es un·e vrai·e pilote de tes finances.',
        icon: Icons.military_tech,
        color: MintColors.purple,
      ));
    }
  }

  // ── Score milestones ──────────────────────────────────────

  static void _checkScore(
    int currentScore,
    Set<String> achieved,
    List<MilestoneEvent> out,
  ) {
    if (currentScore >= 60 && !achieved.contains('score_bon')) {
      out.add(MilestoneEvent(
        id: 'score_bon',
        title: 'Score Bon',
        description:
            'Ton score Financial Fitness a depasse 60/100. Tes efforts portent leurs fruits.',
        icon: Icons.trending_up,
        color: MintColors.scoreBon,
      ));
    }

    if (currentScore >= 80 && !achieved.contains('score_excellent')) {
      out.add(MilestoneEvent(
        id: 'score_excellent',
        title: 'Score Excellent',
        description:
            'Ton score Financial Fitness a depasse 80/100. Tu geres tes finances avec brio.',
        icon: Icons.star,
        color: MintColors.scoreExcellent,
      ));
    }
  }

  // ════════════════════════════════════════════════════════════
  //  S36 — SNAPSHOT-BASED DETECTION (pure, no SharedPreferences)
  // ════════════════════════════════════════════════════════════

  /// Compare current vs previous snapshot to detect new milestones.
  ///
  /// Pure function — no persistence, no side effects.
  /// Only triggers milestones that are met NOW but were NOT met before.
  ///
  /// Expected keys in [current] / [previous]:
  ///   - "emergencyFundMonths" — months of expenses covered by liquid savings
  ///   - "threeAContribution" — annual 3a contribution (CHF)
  ///   - "lppBuybackDone" — 1.0 if completed, 0.0 if not
  ///   - "friScore" — Financial Resilience Index (0-100)
  ///   - "patrimoine" — total patrimoine (CHF)
  ///   - "arbitrageCount" — number of arbitrages completed
  ///
  /// [checkInStreak] — current consecutive check-in months.
  /// [arbitrageCount] — total completed arbitrage simulations.
  /// [now] — override for testing (defaults to DateTime.now()).
  static List<DetectedMilestone> detect({
    required Map<String, double> current,
    Map<String, double> previous = const {},
    int checkInStreak = 0,
    int arbitrageCount = 0,
    DateTime? now,
  }) {
    final detectedAt = now ?? DateTime.now();
    final results = <DetectedMilestone>[];

    // ── Emergency fund milestones ─────────────────────────────
    final curMonths = current['emergencyFundMonths'] ?? 0;
    final prevMonths = previous['emergencyFundMonths'] ?? 0;

    if (curMonths >= 3 && prevMonths < 3) {
      results.add(DetectedMilestone(
        type: MilestoneType.emergencyFund3Months,
        celebrationText:
            'Reserve de liquidite : ${curMonths.toStringAsFixed(0)} mois. '
            'L\'equivalent de 3 mois de charges.',
        concreteValue: '${curMonths.toStringAsFixed(0)} mois',
        detectedAt: detectedAt,
      ));
    }

    if (curMonths >= 6 && prevMonths < 6) {
      results.add(DetectedMilestone(
        type: MilestoneType.emergencyFund6Months,
        celebrationText:
            'Reserve de liquidite : ${curMonths.toStringAsFixed(0)} mois. '
            'Ton coussin de securite est solide.',
        concreteValue: '${curMonths.toStringAsFixed(0)} mois',
        detectedAt: detectedAt,
      ));
    }

    // ── 3a max milestone ──────────────────────────────────────
    final cur3a = current['threeAContribution'] ?? 0;
    final prev3a = previous['threeAContribution'] ?? 0;
    final taxSaving3a = current['taxSaving3a'] ?? 0;

    if (cur3a >= _plafond3aSalarie && prev3a < _plafond3aSalarie) {
      final savingStr = _formatChf(taxSaving3a);
      results.add(DetectedMilestone(
        type: MilestoneType.threeAMaxReached,
        celebrationText:
            'Plafond 3a atteint — CHF 7\'258. '
            'Economie fiscale estimee : ~CHF $savingStr.',
        concreteValue: 'CHF 7\'258',
        detectedAt: detectedAt,
      ));
    }

    // ── LPP buyback milestone ─────────────────────────────────
    final curBuyback = current['lppBuybackDone'] ?? 0;
    final prevBuyback = previous['lppBuybackDone'] ?? 0;

    if (curBuyback >= 1.0 && prevBuyback < 1.0) {
      results.add(DetectedMilestone(
        type: MilestoneType.lppBuybackCompleted,
        celebrationText:
            'Rachat LPP effectue. Impact sur ta prevoyance visible dans le simulateur.',
        concreteValue: 'rachat LPP',
        detectedAt: detectedAt,
      ));
    }

    // ── FRI score milestones ──────────────────────────────────
    final curFri = current['friScore'] ?? 0;
    final prevFri = previous['friScore'] ?? 0;
    final friDelta = curFri - prevFri;

    if (friDelta >= 10 && prevFri > 0) {
      results.add(DetectedMilestone(
        type: MilestoneType.friImproved10Points,
        celebrationText:
            'Score de solidite : +${friDelta.toStringAsFixed(0)} points. '
            'Progression concrete.',
        concreteValue: '+${friDelta.toStringAsFixed(0)} points',
        detectedAt: detectedAt,
      ));
    }

    if (curFri >= 50 && prevFri < 50) {
      results.add(DetectedMilestone(
        type: MilestoneType.friAbove50,
        celebrationText:
            'Score de solidite : ${curFri.toStringAsFixed(0)}/100. '
            'Au-dessus de la mediane.',
        concreteValue: '${curFri.toStringAsFixed(0)}/100',
        detectedAt: detectedAt,
      ));
    }

    if (curFri >= 70 && prevFri < 70) {
      results.add(DetectedMilestone(
        type: MilestoneType.friAbove70,
        celebrationText:
            'Score de solidite : ${curFri.toStringAsFixed(0)}/100. '
            'Au-dessus du seuil de 70.',
        concreteValue: '${curFri.toStringAsFixed(0)}/100',
        detectedAt: detectedAt,
      ));
    }

    if (curFri >= 85 && prevFri < 85) {
      results.add(DetectedMilestone(
        type: MilestoneType.friAbove85,
        celebrationText:
            'Score de solidite : ${curFri.toStringAsFixed(0)}/100. '
            'Zone d\'excellence.',
        concreteValue: '${curFri.toStringAsFixed(0)}/100',
        detectedAt: detectedAt,
      ));
    }

    // ── Patrimoine milestones ─────────────────────────────────
    final curPat = current['patrimoine'] ?? 0;
    final prevPat = previous['patrimoine'] ?? 0;

    if (curPat >= 50000 && prevPat < 50000) {
      results.add(DetectedMilestone(
        type: MilestoneType.patrimoine50k,
        celebrationText:
            'Patrimoine estime : CHF ${_formatChf(curPat)}. '
            'Un cap symbolique franchi.',
        concreteValue: 'CHF ${_formatChf(curPat)}',
        detectedAt: detectedAt,
      ));
    }

    if (curPat >= 100000 && prevPat < 100000) {
      results.add(DetectedMilestone(
        type: MilestoneType.patrimoine100k,
        celebrationText:
            'Patrimoine estime : CHF ${_formatChf(curPat)}. '
            'Seuil des 100k atteint.',
        concreteValue: 'CHF ${_formatChf(curPat)}',
        detectedAt: detectedAt,
      ));
    }

    if (curPat >= 250000 && prevPat < 250000) {
      results.add(DetectedMilestone(
        type: MilestoneType.patrimoine250k,
        celebrationText:
            'Patrimoine estime : CHF ${_formatChf(curPat)}. '
            'Un quart de million.',
        concreteValue: 'CHF ${_formatChf(curPat)}',
        detectedAt: detectedAt,
      ));
    }

    // ── Arbitrage milestone ───────────────────────────────────
    final curArb = current['arbitrageCount'] ?? arbitrageCount.toDouble();
    final prevArb = previous['arbitrageCount'] ?? 0;

    if (curArb >= 1 && prevArb < 1) {
      results.add(DetectedMilestone(
        type: MilestoneType.firstArbitrageCompleted,
        celebrationText:
            'Premiere simulation d\'arbitrage terminee. '
            'Explore d\'autres scenarios.',
        concreteValue: '1 arbitrage',
        detectedAt: detectedAt,
      ));
    }

    // ── Check-in streak milestones ────────────────────────────
    // These use the explicit checkInStreak parameter rather than
    // the snapshot map, since streaks are tracked separately.
    final prevStreak = (previous['checkInStreak'] ?? 0).toInt();

    if (checkInStreak >= 6 && prevStreak < 6) {
      results.add(DetectedMilestone(
        type: MilestoneType.checkInStreak6Months,
        celebrationText:
            '6 mois de check-ins consecutifs. Ta discipline porte ses fruits.',
        concreteValue: '6 mois',
        detectedAt: detectedAt,
      ));
    }

    if (checkInStreak >= 12 && prevStreak < 12) {
      results.add(DetectedMilestone(
        type: MilestoneType.checkInStreak12Months,
        celebrationText:
            '12 mois de check-ins. Une annee complete de suivi.',
        concreteValue: '12 mois',
        detectedAt: detectedAt,
      ));
    }

    return results;
  }

  // ── S36 Formatting helper ──────────────────────────────────

  /// Format a CHF amount with Swiss apostrophe as thousands separator.
  ///
  /// Example: 1820.5 -> "1'820", 7258.0 -> "7'258"
  static String _formatChf(double amount) {
    final intStr = amount.toStringAsFixed(0);
    return intStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}\'',
    );
  }
}
