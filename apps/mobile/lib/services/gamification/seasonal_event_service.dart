// ────────────────────────────────────────────────────────────
//  SEASONAL EVENT SERVICE — S66 / Gamification
// ────────────────────────────────────────────────────────────
//
// Fournit les evenements saisonniers actifs a une date donnee.
// Ces evenements sont lies au calendrier financier suisse :
// declaration d'impots, deadline 3a, revue mi-annuelle, etc.
//
// Un evenement est "actif" si la date courante est comprise
// entre sa startDate et sa endDate (inclusif).
//
// COMPLIANCE :
// - Aucune comparaison sociale
// - Aucun classement, aucun rang
// - Toutes les cles de texte dans les ARB
// ────────────────────────────────────────────────────────────

/// Type d'evenement saisonnier financier suisse.
enum SeasonalEventType {
  /// Feb-Mar : periode de declaration d'impots.
  taxSeason,

  /// Dec : compte a rebours avant la deadline 3e pilier (31 dec).
  pillar3aCountdown,

  /// Jan : prise de resolutions financieres pour la nouvelle annee.
  newYearResolutions,

  /// Jul : revue des 6 premiers mois de l'annee.
  midYearReview,

  /// Oct : mois de la prevoyance (campagne suisse annuelle).
  retirementMonth,

  /// Oct-Nov : changement de franchise LAMal (nouvelles primes publiees).
  lamalFranchiseReview,
}

/// Evenement saisonnier actif sur une periode donnee.
///
/// [titleKey] et [descriptionKey] sont des cles ARB.
/// [intentTag] est un tag de navigation contextuelle optionnel.
class SeasonalEvent {
  /// Identifiant unique de l'evenement.
  final String id;

  /// Cle ARB pour le titre court.
  final String titleKey;

  /// Cle ARB pour la description.
  final String descriptionKey;

  /// Type d'evenement.
  final SeasonalEventType type;

  /// Debut de la periode d'activation (inclus).
  final DateTime startDate;

  /// Fin de la periode d'activation (inclus).
  final DateTime endDate;

  /// Tag d'intention optionnel (lien vers un hub ou un outil).
  final String? intentTag;

  const SeasonalEvent({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.intentTag,
  });

  /// Indique si l'evenement est actif a la date donnee.
  bool isActiveOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

/// Service des evenements saisonniers financiers.
///
/// Fournit la liste des evenements actifs a un instant donne.
/// Les evenements sont definis pour couvrir les 12 mois de l'annee,
/// chaque mois ayant au moins un evenement actif.
class SeasonalEventService {
  SeasonalEventService._();

  // ── Catalogue annuel des evenements ───────────────────────────
  //
  // Couverture mensuelle :
  //   Jan      : newYearResolutions (1-31 jan)
  //   Feb-Mar  : taxSeason (1 feb - 31 mar)
  //   Apr-Jun  : midYearReview (anticipe + active en juillet)
  //     -> pour couvrir avr/mai/jun : on ajoute un evenement de prep
  //   Jul      : midYearReview (1-31 jul)
  //   Aug-Sep  : pillar3aCountdown prepare (1 sep - 30 nov)
  //   Oct      : retirementMonth (1-31 oct)
  //   Nov      : pillar3aCountdown early (1-30 nov)
  //   Dec      : pillar3aCountdown (1-31 dec)
  //
  // Note : les dates sont calculees chaque annee via _buildFor(year).

  /// Retourne la liste des evenements actifs a la date donnee.
  ///
  /// [now] permet d'injecter une date pour les tests.
  /// Un evenement est actif si [now] est dans sa fenetre.
  static List<SeasonalEvent> activeEvents({DateTime? now}) {
    final date = now ?? DateTime.now();
    final allEvents = _buildFor(date.year);
    return allEvents.where((e) => e.isActiveOn(date)).toList();
  }

  /// Retourne TOUS les evenements definis pour une annee donnee.
  ///
  /// Utile pour les tests et les aperçus calendaires.
  static List<SeasonalEvent> allEventsForYear(int year) {
    return _buildFor(year);
  }

  // ── Construction du catalogue annuel ─────────────────────────

  static List<SeasonalEvent> _buildFor(int year) {
    return [
      // ── Janvier : resolutions de nouvelle annee ──────────────
      SeasonalEvent(
        id: '$year-new-year-resolutions',
        titleKey: 'seasonalNewYearResolutionsTitle',
        descriptionKey: 'seasonalNewYearResolutionsDesc',
        type: SeasonalEventType.newYearResolutions,
        startDate: DateTime(year, 1, 1),
        endDate: DateTime(year, 1, 31),
        intentTag: null,
      ),

      // ── Fevrier-Mars : saison des impots ─────────────────────
      SeasonalEvent(
        id: '$year-tax-season',
        titleKey: 'seasonalTaxSeasonTitle',
        descriptionKey: 'seasonalTaxSeasonDesc',
        type: SeasonalEventType.taxSeason,
        startDate: DateTime(year, 2, 1),
        endDate: DateTime(year, 3, 31),
        intentTag: 'fiscalite',
      ),

      // ── Avril-Juin : preparation revue mi-annuelle ───────────
      // Couvre avril, mai, juin avec un evenement de preparation
      SeasonalEvent(
        id: '$year-mid-year-prep',
        titleKey: 'seasonalMidYearReviewTitle',
        descriptionKey: 'seasonalMidYearReviewDesc',
        type: SeasonalEventType.midYearReview,
        startDate: DateTime(year, 4, 1),
        endDate: DateTime(year, 6, 30),
        intentTag: null,
      ),

      // ── Juillet : revue mi-annuelle ──────────────────────────
      SeasonalEvent(
        id: '$year-mid-year-review',
        titleKey: 'seasonalMidYearReviewTitle',
        descriptionKey: 'seasonalMidYearReviewDesc',
        type: SeasonalEventType.midYearReview,
        startDate: DateTime(year, 7, 1),
        endDate: DateTime(year, 7, 31),
        intentTag: null,
      ),

      // ── Aout-Septembre : sensibilisation 3a ──────────────────
      // Utilise le type pillar3aCountdown comme sensibilisation estivale
      SeasonalEvent(
        id: '$year-3a-awareness',
        titleKey: 'seasonal3aCountdownTitle',
        descriptionKey: 'seasonal3aCountdownDesc',
        type: SeasonalEventType.pillar3aCountdown,
        startDate: DateTime(year, 8, 1),
        endDate: DateTime(year, 9, 30),
        intentTag: '3a-deep',
      ),

      // ── Octobre : mois de la prevoyance ──────────────────────
      SeasonalEvent(
        id: '$year-retirement-month',
        titleKey: 'seasonalRetirementMonthTitle',
        descriptionKey: 'seasonalRetirementMonthDesc',
        type: SeasonalEventType.retirementMonth,
        startDate: DateTime(year, 10, 1),
        endDate: DateTime(year, 10, 31),
        intentTag: 'retraite',
      ),

      // ── Novembre : compte a rebours 3a ───────────────────────
      SeasonalEvent(
        id: '$year-3a-countdown-nov',
        titleKey: 'seasonal3aCountdownTitle',
        descriptionKey: 'seasonal3aCountdownDesc',
        type: SeasonalEventType.pillar3aCountdown,
        startDate: DateTime(year, 11, 1),
        endDate: DateTime(year, 11, 30),
        intentTag: '3a-deep',
      ),

      // ── Octobre : LAMal franchise review (nouvelles primes) ──
      SeasonalEvent(
        id: '$year-lamal-franchise-oct',
        titleKey: 'seasonalLamalTitle',
        descriptionKey: 'seasonalLamalDesc',
        type: SeasonalEventType.lamalFranchiseReview,
        startDate: DateTime(year, 10, 1),
        endDate: DateTime(year, 11, 30),
        intentTag: 'lamal_franchise',
      ),

      // ── Decembre : deadline 3a (31 dec) ──────────────────────
      SeasonalEvent(
        id: '$year-3a-deadline-dec',
        titleKey: 'seasonal3aCountdownTitle',
        descriptionKey: 'seasonal3aCountdownDesc',
        type: SeasonalEventType.pillar3aCountdown,
        startDate: DateTime(year, 12, 1),
        endDate: DateTime(year, 12, 31),
        intentTag: '3a-deep',
      ),
    ];
  }
}
