import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  MILESTONE V2 SERVICE — S66 / Gamification
// ────────────────────────────────────────────────────────────
//
// Evalue l'ensemble des milestones V2 (20 milestones) en fonction
// du profil et des metriques d'engagement.
//
// Les milestones sont divises en 4 categories :
//   - engagement  : utilisation de l'application
//   - knowledge   : apprentissage et decouverte
//   - action      : actions financieres concretes
//   - consistency : regularite et series (streaks)
//
// COMPLIANCE :
// - JAMAIS de comparaison sociale ("mieux que", "top X%")
// - JAMAIS de classement ou rang
// - Tous les titres/descriptions sont des cles ARB
// - Progression uniquement par rapport aux objectifs personnels
//
// Architecture : pure function (deterministe, testable, sans effets de bord).
// ────────────────────────────────────────────────────────────

/// Categorie d'un milestone V2.
enum MilestoneCategory {
  /// Milestones lies a l'utilisation de l'application.
  engagement,

  /// Milestones lies a l'apprentissage et la decouverte.
  knowledge,

  /// Milestones lies aux actions financieres concretes.
  action,

  /// Milestones lies a la regularite (streaks hebdomadaires).
  consistency,
}

/// Un milestone V2 avec son etat de deverrouillage.
///
/// [titleKey] et [descriptionKey] sont des cles ARB.
/// [unlocked] indique si le milestone est atteint.
class Milestone {
  /// Identifiant unique du milestone.
  final String id;

  /// Cle ARB pour le titre court.
  final String titleKey;

  /// Cle ARB pour la description.
  final String descriptionKey;

  /// Categorie du milestone.
  final MilestoneCategory category;

  /// Indique si le milestone est deverrouille.
  final bool unlocked;

  const Milestone({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.category,
    required this.unlocked,
  });
}

/// Service d'evaluation des milestones V2.
///
/// Fonction pure : memes entrees -> memes sorties, aucun effet de bord.
/// 20 milestones repartis en 4 categories.
class MilestoneV2Service {
  MilestoneV2Service._();

  // ── Identifiants des milestones (constantes) ──────────────────

  // Engagement
  static const String _idFirstWeek = 'engagement_first_week';
  static const String _idOneMonth = 'engagement_one_month';
  static const String _idCitoyen = 'engagement_citoyen_mint';
  static const String _idFidele = 'engagement_fidele_6mois';
  static const String _idVeteran = 'engagement_veteran_1an';

  // Knowledge
  static const String _idCurieux = 'knowledge_curieux';
  static const String _idEclaire = 'knowledge_eclaire';
  static const String _idExpert = 'knowledge_expert';
  static const String _idStrategiste = 'knowledge_strategiste';
  static const String _idMaitre = 'knowledge_maitre';

  // Action
  static const String _idPremierPas = 'action_premier_pas';
  static const String _idActeur = 'action_acteur';
  static const String _idMastreDestin = 'action_maitre_destin';
  static const String _idBatisseur = 'action_batisseur';
  static const String _idArchitecte = 'action_architecte';

  // Consistency
  static const String _idFlammeNaissante = 'consistency_flamme_naissante';
  static const String _idFlammeVive = 'consistency_flamme_vive';
  static const String _idFlammeEternelle = 'consistency_flamme_eternelle';
  static const String _idConfiance = 'consistency_confiance';
  static const String _idChallenges = 'consistency_challenges_accomplis';

  // ── Seuils ───────────────────────────────────────────────────

  // Engagement (jours d'utilisation)
  static const int _seuilPremiereSemaine = 7;
  static const int _seuilUnMois = 30;
  static const int _seuilCitoyen = 90;
  static const int _seuilFidele = 180;
  static const int _seuilVeteran = 365;

  // Knowledge (nombre d'insights consultes)
  static const int _seuilCurieux = 5;
  static const int _seuilEclaire = 20;
  static const int _seuilExpert = 50;
  static const int _seuilStrategiste = 100;
  static const int _seuilMaitre = 200;

  // Action (nombre d'actions financieres completees)
  static const int _seuilPremierPas = 1;
  static const int _seuilActeur = 5;
  static const int _seuilMastreDestin = 20;
  static const int _seuilBatisseur = 50;
  static const int _seuilArchitecte = 100;

  // Consistency (semaines consecutives)
  static const int _seuilFlammeNaissante = 2;
  static const int _seuilFlammeVive = 4;
  static const int _seuilFlammeEternelle = 12;

  // Confiance (score de confiance >= 70%)
  static const double _seuilConfiance = 70.0;

  // Challenges communautaires completes
  static const int _seuilChallenges = 6;

  // ── API publique ──────────────────────────────────────────────

  /// Evalue tous les milestones en fonction des metriques fournies.
  ///
  /// [profile] — profil financier complet.
  /// [completedChallenges] — nombre de defis communautaires completes.
  /// [streakWeeks] — serie de semaines consecutives d'utilisation.
  /// [insightCount] — nombre total d'insights consultes.
  /// [confidenceScore] — score de confiance du profil (0-100).
  /// [actionCount] — nombre d'actions financieres completees.
  /// [daysActive] — nombre de jours d'utilisation de l'application.
  ///
  /// Retourne la liste des 20 milestones avec leur etat [unlocked].
  static List<Milestone> evaluate({
    required CoachProfile profile,
    required int completedChallenges,
    required int streakWeeks,
    required int insightCount,
    required double confidenceScore,
    int actionCount = 0,
    int daysActive = 0,
  }) {
    return [
      // ── Engagement ────────────────────────────────────────────
      Milestone(
        id: _idFirstWeek,
        titleKey: 'milestoneEngagementFirstWeekTitle',
        descriptionKey: 'milestoneEngagementFirstWeekDesc',
        category: MilestoneCategory.engagement,
        unlocked: daysActive >= _seuilPremiereSemaine,
      ),
      Milestone(
        id: _idOneMonth,
        titleKey: 'milestoneEngagementOneMonthTitle',
        descriptionKey: 'milestoneEngagementOneMonthDesc',
        category: MilestoneCategory.engagement,
        unlocked: daysActive >= _seuilUnMois,
      ),
      Milestone(
        id: _idCitoyen,
        titleKey: 'milestoneEngagementCitoyenTitle',
        descriptionKey: 'milestoneEngagementCitoyenDesc',
        category: MilestoneCategory.engagement,
        unlocked: daysActive >= _seuilCitoyen,
      ),
      Milestone(
        id: _idFidele,
        titleKey: 'milestoneEngagementFideleTitle',
        descriptionKey: 'milestoneEngagementFideleDesc',
        category: MilestoneCategory.engagement,
        unlocked: daysActive >= _seuilFidele,
      ),
      Milestone(
        id: _idVeteran,
        titleKey: 'milestoneEngagementVeteranTitle',
        descriptionKey: 'milestoneEngagementVeteranDesc',
        category: MilestoneCategory.engagement,
        unlocked: daysActive >= _seuilVeteran,
      ),

      // ── Knowledge ─────────────────────────────────────────────
      Milestone(
        id: _idCurieux,
        titleKey: 'milestoneKnowledgeCurieuxTitle',
        descriptionKey: 'milestoneKnowledgeCurieuxDesc',
        category: MilestoneCategory.knowledge,
        unlocked: insightCount >= _seuilCurieux,
      ),
      Milestone(
        id: _idEclaire,
        titleKey: 'milestoneKnowledgeEclaireTitle',
        descriptionKey: 'milestoneKnowledgeEclaireDesc',
        category: MilestoneCategory.knowledge,
        unlocked: insightCount >= _seuilEclaire,
      ),
      Milestone(
        id: _idExpert,
        titleKey: 'milestoneKnowledgeExpertTitle',
        descriptionKey: 'milestoneKnowledgeExpertDesc',
        category: MilestoneCategory.knowledge,
        unlocked: insightCount >= _seuilExpert,
      ),
      Milestone(
        id: _idStrategiste,
        titleKey: 'milestoneKnowledgeStrategisteTitle',
        descriptionKey: 'milestoneKnowledgeStrategisteDesc',
        category: MilestoneCategory.knowledge,
        unlocked: insightCount >= _seuilStrategiste,
      ),
      Milestone(
        id: _idMaitre,
        titleKey: 'milestoneKnowledgeMaitreTitle',
        descriptionKey: 'milestoneKnowledgeMaitreDesc',
        category: MilestoneCategory.knowledge,
        unlocked: insightCount >= _seuilMaitre,
      ),

      // ── Action ────────────────────────────────────────────────
      Milestone(
        id: _idPremierPas,
        titleKey: 'milestoneActionPremierPasTitle',
        descriptionKey: 'milestoneActionPremierPasDesc',
        category: MilestoneCategory.action,
        unlocked: actionCount >= _seuilPremierPas,
      ),
      Milestone(
        id: _idActeur,
        titleKey: 'milestoneActionActeurTitle',
        descriptionKey: 'milestoneActionActeurDesc',
        category: MilestoneCategory.action,
        unlocked: actionCount >= _seuilActeur,
      ),
      Milestone(
        id: _idMastreDestin,
        titleKey: 'milestoneActionMaitreDestinTitle',
        descriptionKey: 'milestoneActionMaitreDestinDesc',
        category: MilestoneCategory.action,
        unlocked: actionCount >= _seuilMastreDestin,
      ),
      Milestone(
        id: _idBatisseur,
        titleKey: 'milestoneActionBatisseurTitle',
        descriptionKey: 'milestoneActionBatisseurDesc',
        category: MilestoneCategory.action,
        unlocked: actionCount >= _seuilBatisseur,
      ),
      Milestone(
        id: _idArchitecte,
        titleKey: 'milestoneActionArchitecteTitle',
        descriptionKey: 'milestoneActionArchitecteDesc',
        category: MilestoneCategory.action,
        unlocked: actionCount >= _seuilArchitecte,
      ),

      // ── Consistency ───────────────────────────────────────────
      Milestone(
        id: _idFlammeNaissante,
        titleKey: 'milestoneConsistencyFlammeNaissanteTitle',
        descriptionKey: 'milestoneConsistencyFlammeNaissanteDesc',
        category: MilestoneCategory.consistency,
        unlocked: streakWeeks >= _seuilFlammeNaissante,
      ),
      Milestone(
        id: _idFlammeVive,
        titleKey: 'milestoneConsistencyFlammeViveTitle',
        descriptionKey: 'milestoneConsistencyFlammeViveDesc',
        category: MilestoneCategory.consistency,
        unlocked: streakWeeks >= _seuilFlammeVive,
      ),
      Milestone(
        id: _idFlammeEternelle,
        titleKey: 'milestoneConsistencyFlammeEtermelleTitle',
        descriptionKey: 'milestoneConsistencyFlammeEtermelleDesc',
        category: MilestoneCategory.consistency,
        unlocked: streakWeeks >= _seuilFlammeEternelle,
      ),
      Milestone(
        id: _idConfiance,
        titleKey: 'milestoneConsistencyConfianceTitle',
        descriptionKey: 'milestoneConsistencyConfianceDesc',
        category: MilestoneCategory.consistency,
        unlocked: confidenceScore >= _seuilConfiance,
      ),
      Milestone(
        id: _idChallenges,
        titleKey: 'milestoneConsistencyChallengesTitle',
        descriptionKey: 'milestoneConsistencyChallengesDesc',
        category: MilestoneCategory.consistency,
        unlocked: completedChallenges >= _seuilChallenges,
      ),
    ];
  }

  /// Retourne uniquement les milestones deverrouilles.
  static List<Milestone> unlocked({
    required CoachProfile profile,
    required int completedChallenges,
    required int streakWeeks,
    required int insightCount,
    required double confidenceScore,
    int actionCount = 0,
    int daysActive = 0,
  }) {
    return evaluate(
      profile: profile,
      completedChallenges: completedChallenges,
      streakWeeks: streakWeeks,
      insightCount: insightCount,
      confidenceScore: confidenceScore,
      actionCount: actionCount,
      daysActive: daysActive,
    ).where((m) => m.unlocked).toList();
  }

  /// Retourne le nombre total de milestones definis.
  static int get totalCount => 20;

  /// Retourne les milestones d'une categorie donnee.
  static List<Milestone> forCategory({
    required MilestoneCategory category,
    required CoachProfile profile,
    required int completedChallenges,
    required int streakWeeks,
    required int insightCount,
    required double confidenceScore,
    int actionCount = 0,
    int daysActive = 0,
  }) {
    return evaluate(
      profile: profile,
      completedChallenges: completedChallenges,
      streakWeeks: streakWeeks,
      insightCount: insightCount,
      confidenceScore: confidenceScore,
      actionCount: actionCount,
      daysActive: daysActive,
    ).where((m) => m.category == category).toList();
  }

  // ── Seuils publics (pour tests et affichage de progression) ──

  /// Seuil de semaines pour "Flamme naissante".
  static int get seuilFlammeNaissante => _seuilFlammeNaissante;

  /// Seuil de semaines pour "Flamme vive".
  static int get seuilFlammeVive => _seuilFlammeVive;

  /// Seuil de semaines pour "Flamme eternelle".
  static int get seuilFlammeEternelle => _seuilFlammeEternelle;

  /// Seuil d'insights pour "Curieux".
  static int get seuilCurieux => _seuilCurieux;

  /// Seuil d'insights pour "Eclaire".
  static int get seuilEclaire => _seuilEclaire;

  /// Seuil d'insights pour "Expert".
  static int get seuilExpert => _seuilExpert;
}
