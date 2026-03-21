import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  COMMUNITY CHALLENGE SERVICE — S66 / Gamification
// ────────────────────────────────────────────────────────────
//
// Fournit le defi communautaire mensuel courant et la persistence
// de completion locale. Aucune comparaison sociale. Aucun classement.
//
// Design : "Advent calendar", pas "leaderboard".
// Tous les defis sont personnels : l'utilisateur progresse par
// rapport a ses propres objectifs, pas par rapport aux autres.
//
// COMPLIANCE :
// - NEVER ranking / leaderboard / social comparison
// - NEVER "top X%", "mieux que", "meilleur que"
// - Opt-in communautaire uniquement (cf. gamificationOptInPrompt)
// - Toutes les cles de texte sont dans les ARB (aucun string en dur)
// ────────────────────────────────────────────────────────────

/// Theme saisonnier d'un defi communautaire.
///
/// Regroupe les defis par saison financiere suisse :
/// - [fiscalite]  : Jan-Mar (saison des impots)
/// - [prevoyance] : Apr-Jun (bilan mi-annuel)
/// - [epargne]    : Jul-Sep (epargne estivale)
/// - [bilan]      : Oct-Dec (bilan annuel + deadline 3a)
enum ChallengeTheme {
  fiscalite,
  prevoyance,
  epargne,
  bilan,
}

/// Defi communautaire mensuel.
///
/// Un defi change chaque mois. Il propose une action concrete
/// educative, sans comparaison avec d'autres utilisateurs.
/// [titleKey] et [descriptionKey] sont des cles ARB.
class CommunityChallenge {
  /// Identifiant unique au format "YYYY-MM-slug".
  final String id;

  /// Cle ARB pour le titre court (ex: "communityChallenge01Title").
  final String titleKey;

  /// Cle ARB pour la description longue.
  final String descriptionKey;

  /// Theme saisonnier associe.
  final ChallengeTheme theme;

  /// Premier jour du mois du defi.
  final DateTime startDate;

  /// Dernier jour du mois du defi.
  final DateTime endDate;

  /// Tag d'intention optionnel pour la navigation contextuelle.
  final String? intentTag;

  const CommunityChallenge({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.theme,
    required this.startDate,
    required this.endDate,
    this.intentTag,
  });
}

/// Service de gestion des defis communautaires mensuels.
///
/// Les defis sont definis de facon statique pour une annee complete.
/// La completion est persistee localement via SharedPreferences.
/// Aucune donnee n'est envoyee a un serveur sans consentement.
class CommunityChallengeService {
  CommunityChallengeService._();

  static const _completedKey = 'community_challenges_completed_v1';

  // ── Catalogue annuel des defis (12 mois) ──────────────────────
  //
  // Chaque mois dispose d'un defi educatif thematique.
  // Les identifiants suivent le format "YYYY-MM-slug" mais la
  // methode currentChallenge() reconstruit l'id avec l'annee courante
  // pour que le defi se renouvelle chaque annee.

  /// Defis par mois (index 1 = janvier, 12 = decembre).
  static const List<_MonthlyChallengeTemplate> _templates = [
    // Janvier — fiscalite
    _MonthlyChallengeTemplate(
      monthIndex: 1,
      slugSuffix: 'declarations-impots',
      titleKey: 'communityChallenge01Title',
      descriptionKey: 'communityChallenge01Desc',
      theme: ChallengeTheme.fiscalite,
      intentTag: 'fiscalite',
    ),
    // Fevrier — fiscalite
    _MonthlyChallengeTemplate(
      monthIndex: 2,
      slugSuffix: 'deductions-fiscales',
      titleKey: 'communityChallenge02Title',
      descriptionKey: 'communityChallenge02Desc',
      theme: ChallengeTheme.fiscalite,
      intentTag: 'fiscalite',
    ),
    // Mars — fiscalite
    _MonthlyChallengeTemplate(
      monthIndex: 3,
      slugSuffix: 'pilier3a-deadline',
      titleKey: 'communityChallenge03Title',
      descriptionKey: 'communityChallenge03Desc',
      theme: ChallengeTheme.fiscalite,
      intentTag: '3a-deep',
    ),
    // Avril — prevoyance
    _MonthlyChallengeTemplate(
      monthIndex: 4,
      slugSuffix: 'bilan-prevoyance',
      titleKey: 'communityChallenge04Title',
      descriptionKey: 'communityChallenge04Desc',
      theme: ChallengeTheme.prevoyance,
      intentTag: 'lpp-deep',
    ),
    // Mai — prevoyance
    _MonthlyChallengeTemplate(
      monthIndex: 5,
      slugSuffix: 'rachat-lpp',
      titleKey: 'communityChallenge05Title',
      descriptionKey: 'communityChallenge05Desc',
      theme: ChallengeTheme.prevoyance,
      intentTag: 'lpp-deep',
    ),
    // Juin — prevoyance
    _MonthlyChallengeTemplate(
      monthIndex: 6,
      slugSuffix: 'bilan-mi-annuel',
      titleKey: 'communityChallenge06Title',
      descriptionKey: 'communityChallenge06Desc',
      theme: ChallengeTheme.prevoyance,
      intentTag: null,
    ),
    // Juillet — epargne
    _MonthlyChallengeTemplate(
      monthIndex: 7,
      slugSuffix: 'objectif-epargne',
      titleKey: 'communityChallenge07Title',
      descriptionKey: 'communityChallenge07Desc',
      theme: ChallengeTheme.epargne,
      intentTag: null,
    ),
    // Aout — epargne
    _MonthlyChallengeTemplate(
      monthIndex: 8,
      slugSuffix: 'fonds-urgence',
      titleKey: 'communityChallenge08Title',
      descriptionKey: 'communityChallenge08Desc',
      theme: ChallengeTheme.epargne,
      intentTag: null,
    ),
    // Septembre — epargne
    _MonthlyChallengeTemplate(
      monthIndex: 9,
      slugSuffix: 'versement-3a-automne',
      titleKey: 'communityChallenge09Title',
      descriptionKey: 'communityChallenge09Desc',
      theme: ChallengeTheme.epargne,
      intentTag: '3a-deep',
    ),
    // Octobre — bilan
    _MonthlyChallengeTemplate(
      monthIndex: 10,
      slugSuffix: 'mois-prevoyance',
      titleKey: 'communityChallenge10Title',
      descriptionKey: 'communityChallenge10Desc',
      theme: ChallengeTheme.bilan,
      intentTag: 'retraite',
    ),
    // Novembre — bilan
    _MonthlyChallengeTemplate(
      monthIndex: 11,
      slugSuffix: 'planification-fin-annee',
      titleKey: 'communityChallenge11Title',
      descriptionKey: 'communityChallenge11Desc',
      theme: ChallengeTheme.bilan,
      intentTag: 'fiscalite',
    ),
    // Decembre — bilan + deadline 3a
    _MonthlyChallengeTemplate(
      monthIndex: 12,
      slugSuffix: 'deadline-3a',
      titleKey: 'communityChallenge12Title',
      descriptionKey: 'communityChallenge12Desc',
      theme: ChallengeTheme.bilan,
      intentTag: '3a-deep',
    ),
  ];

  // ── API publique ───────────────────────────────────────────────

  /// Retourne le defi communautaire du mois courant.
  ///
  /// [now] permet d'injecter une date pour les tests (defaut : DateTime.now()).
  /// Retourne null uniquement si aucun template ne correspond (cas impossible
  /// avec le catalogue complet de 12 mois).
  static CommunityChallenge? currentChallenge({DateTime? now}) {
    final date = now ?? DateTime.now();
    return _challengeForMonth(date.year, date.month);
  }

  /// Retourne le defi pour un mois donne (1-12) et une annee donnee.
  ///
  /// Utile pour afficher les defis passes ou futurs.
  static CommunityChallenge? challengeForMonth(int year, int month) {
    return _challengeForMonth(year, month);
  }

  /// Verifie si un defi est marque comme complete localement.
  static Future<bool> isCompleted(
    String challengeId,
    SharedPreferences prefs,
  ) async {
    final completed = prefs.getStringList(_completedKey) ?? [];
    return completed.contains(challengeId);
  }

  /// Marque un defi comme complete dans SharedPreferences.
  static Future<void> complete(
    String challengeId,
    SharedPreferences prefs,
  ) async {
    final completed = List<String>.from(
      prefs.getStringList(_completedKey) ?? [],
    );
    if (!completed.contains(challengeId)) {
      completed.add(challengeId);
      await prefs.setStringList(_completedKey, completed);
    }
  }

  /// Retourne la liste des identifiants de defis completes.
  static Future<List<String>> completedChallenges(
    SharedPreferences prefs,
  ) async {
    return List<String>.unmodifiable(
      prefs.getStringList(_completedKey) ?? [],
    );
  }

  /// Retourne le nombre de defis completes.
  static Future<int> completedCount(SharedPreferences prefs) async {
    final list = prefs.getStringList(_completedKey) ?? [];
    return list.length;
  }

  // ── Methodes privees ──────────────────────────────────────────

  static CommunityChallenge? _challengeForMonth(int year, int month) {
    if (month < 1 || month > 12) return null;

    final template = _templates.firstWhere(
      (t) => t.monthIndex == month,
      orElse: () => throw StateError('No template for month $month'),
    );

    // Calcule le dernier jour du mois
    final lastDay = DateTime(year, month + 1, 0).day;

    return CommunityChallenge(
      id: '$year-${month.toString().padLeft(2, '0')}-${template.slugSuffix}',
      titleKey: template.titleKey,
      descriptionKey: template.descriptionKey,
      theme: template.theme,
      startDate: DateTime(year, month, 1),
      endDate: DateTime(year, month, lastDay),
      intentTag: template.intentTag,
    );
  }
}

/// Template interne (non expose) pour definir les defis.
class _MonthlyChallengeTemplate {
  final int monthIndex;
  final String slugSuffix;
  final String titleKey;
  final String descriptionKey;
  final ChallengeTheme theme;
  final String? intentTag;

  const _MonthlyChallengeTemplate({
    required this.monthIndex,
    required this.slugSuffix,
    required this.titleKey,
    required this.descriptionKey,
    required this.theme,
    this.intentTag,
  });
}
