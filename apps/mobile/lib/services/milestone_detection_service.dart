import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MILESTONE DETECTION SERVICE — T5 / Coach AI Layer
// ────────────────────────────────────────────────────────────
//
// Detecte les nouveaux milestones financiers atteints depuis
// le dernier check-in. Compare l'etat actuel vs l'etat persiste
// precedent (SharedPreferences).
//
// Milestones detectes :
//   - patrimoine_50k, patrimoine_100k, patrimoine_250k, patrimoine_500k
//   - 3a_max_reached (7'258 CHF verse cette annee)
//   - emergency_fund_3m, emergency_fund_6m (mois couverts)
//   - streak_3, streak_6, streak_12 (mois consecutifs check-in)
//   - score_bon (score >= 60), score_excellent (score >= 80)
//
// Logique pure sauf SharedPreferences pour la persistence.
// Aucun terme banni. Ton pedagogique, tutoiement.
// ────────────────────────────────────────────────────────────

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

    if (annual3a >= _plafond3aSalarie) {
      out.add(MilestoneEvent(
        id: '3a_max_reached',
        title: '3a au plafond',
        description:
            'Tu as atteint le plafond de CHF 7\'258 pour ton 3e pilier. C\'est la meilleure facon de combiner prevoyance et economie fiscale (OPP3 art. 7).',
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
}
