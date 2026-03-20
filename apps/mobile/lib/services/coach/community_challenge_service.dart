/// Community Challenge Service — Sprint S66 (Advanced Gamification).
///
/// Seasonal, opt-in community challenges that reward engagement
/// with FHS bonus points. All participation is anonymized.
///
/// Rules (NON-NEGOTIABLE):
/// - ZERO ranked comparisons or leaderboards
/// - ZERO social comparison language
/// - ZERO PII in shared achievements
/// - ALL text French, informal "tu", proper accents
/// - Disclaimer on every shared achievement
/// - Opt-in only — no auto-enrollment
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Seasonal event periods for community challenges.
enum SeasonalEvent { newYear, taxSeason, summerSavings, yearEndPlanning }

/// Category of a community challenge.
enum ChallengeCategory { pillar3a, avs, budget, lpp, tax, patrimoine }

// ════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════

/// A community challenge available for opt-in participation.
///
/// [participantCount] and [completionRate] are anonymized aggregates.
/// They NEVER identify individual users.
/// COMPLIANCE: UI must NOT display completionRate as "X% ont terminé"
/// (implicit social comparison). Use it only for internal analytics.
class CommunityChallenge {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final ChallengeCategory category;
  final int participantCount;
  final double completionRate;
  final int fhsBonus;
  final String? seasonalEvent;

  const CommunityChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.participantCount,
    required this.completionRate,
    required this.fhsBonus,
    this.seasonalEvent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'category': category.name,
        'participantCount': participantCount,
        'completionRate': completionRate,
        'fhsBonus': fhsBonus,
        'seasonalEvent': seasonalEvent,
      };

  factory CommunityChallenge.fromJson(Map<String, dynamic> json) {
    return CommunityChallenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      category: ChallengeCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ChallengeCategory.budget,
      ),
      participantCount: json['participantCount'] as int,
      completionRate: (json['completionRate'] as num).toDouble(),
      fhsBonus: json['fhsBonus'] as int,
      seasonalEvent: json['seasonalEvent'] as String?,
    );
  }
}

/// Record of a user's participation in a challenge.
class ChallengeRecord {
  final String challengeId;
  final String title;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final int fhsBonus;

  const ChallengeRecord({
    required this.challengeId,
    required this.title,
    required this.joinedAt,
    this.completedAt,
    required this.fhsBonus,
  });

  bool get isCompleted => completedAt != null;

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'title': title,
        'joinedAt': joinedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'fhsBonus': fhsBonus,
      };

  factory ChallengeRecord.fromJson(Map<String, dynamic> json) {
    return ChallengeRecord(
      challengeId: json['challengeId'] as String,
      title: json['title'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      fhsBonus: json['fhsBonus'] as int,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Manages community challenges with opt-in participation and seasonal events.
///
/// All methods are static. Persistence via [SharedPreferences].
class CommunityChallengeService {
  CommunityChallengeService._();

  /// SharedPreferences key for joined challenge records.
  static const _recordsKey = '_community_challenge_records';

  /// Known valid routes for challenge deep links.
  ///
  /// Any route used in a challenge CTA must be in this set.
  /// This prevents broken deep links when routes are renamed.
  static const _validRoutes = {
    '/pilier-3a',
    '/rachat-lpp',
    '/fiscal',
    '/retraite',
    '/budget',
    '/hypotheque',
    '/pulse',
    '/pulse/fhs',
    '/pulse/achievements',
    '/mint',
    '/profile',
  };

  /// Validate that a route exists in the known routes set.
  ///
  /// Returns the route if valid, or '/pulse' as safe fallback.
  static String validateRoute(String route) {
    return _validRoutes.contains(route) ? route : '/pulse';
  }

  /// Compliance disclaimer for shared achievements.
  static const String shareDisclaimer =
      'MINT est un outil éducatif. '
      'Cet accomplissement ne constitue pas un conseil financier (LSFin).';

  // ── Static challenge pool: 12 challenges (3 per season) ──

  /// Generate the full pool of challenges for a given year.
  static List<CommunityChallenge> _challengePool(int year) => [
        // ── New Year (January) ──
        CommunityChallenge(
          id: 'ny_goals_$year',
          title: 'Fixe tes 3 objectifs financiers $year',
          description:
              'Imagine ton année réussie\u00a0: définis tes priorités '
              '(épargne, prévoyance, projets). Chaque progrès compte\u00a0!',
          startDate: DateTime(year, 1, 1),
          endDate: DateTime(year, 1, 31),
          category: ChallengeCategory.budget,
          participantCount: 342,
          completionRate: 0.67,
          fhsBonus: 5,
          seasonalEvent: SeasonalEvent.newYear.name,
        ),
        CommunityChallenge(
          id: 'ny_avs_$year',
          title: 'Vérifie ton extrait AVS',
          description:
              'C\'est important pour ta retraite\u00a0: commande ton extrait de '
              'compte individuel sur inforegister.admin.ch et vérifie tes '
              'années de cotisation.',
          startDate: DateTime(year, 1, 1),
          endDate: DateTime(year, 1, 31),
          category: ChallengeCategory.avs,
          participantCount: 215,
          completionRate: 0.43,
          fhsBonus: 7,
          seasonalEvent: SeasonalEvent.newYear.name,
        ),
        CommunityChallenge(
          id: 'ny_budget_$year',
          title: 'Simule ton budget annuel',
          description:
              'Tu peux avoir une vision claire\u00a0: utilise le simulateur '
              'MINT pour projeter tes revenus et dépenses sur 12\u00a0mois. '
              'Courage, c\'est une étape importante\u00a0!',
          startDate: DateTime(year, 1, 1),
          endDate: DateTime(year, 1, 31),
          category: ChallengeCategory.budget,
          participantCount: 189,
          completionRate: 0.55,
          fhsBonus: 4,
          seasonalEvent: SeasonalEvent.newYear.name,
        ),

        // ── Tax Season (March-April) ──
        CommunityChallenge(
          id: 'tax_deductions_$year',
          title: 'Explore tes déductions fiscales',
          description:
              'L\'impact peut être significatif\u00a0: explore les déductions '
              'possibles (3a, frais professionnels, formation continue).',
          startDate: DateTime(year, 3, 1),
          endDate: DateTime(year, 4, 30),
          category: ChallengeCategory.tax,
          participantCount: 478,
          completionRate: 0.58,
          fhsBonus: 8,
          seasonalEvent: SeasonalEvent.taxSeason.name,
        ),
        CommunityChallenge(
          id: 'tax_3a_$year',
          title: 'Prépare ton dossier 3a',
          description:
              'Tu t\u2019y prends tôt, c\u2019est malin\u00a0! Rassemble tes attestations '
              '3a pour la déclaration d\'impôts.',
          startDate: DateTime(year, 3, 1),
          endDate: DateTime(year, 4, 30),
          category: ChallengeCategory.pillar3a,
          participantCount: 356,
          completionRate: 0.72,
          fhsBonus: 6,
          seasonalEvent: SeasonalEvent.taxSeason.name,
        ),
        CommunityChallenge(
          id: 'tax_compare_$year',
          title: 'Compare tes charges avec l\'année dernière',
          description:
              'Chaque progrès est motivant\u00a0: regarde l\'évolution de tes '
              'charges fixes et identifie les postes qui ont le plus bougé.',
          startDate: DateTime(year, 3, 1),
          endDate: DateTime(year, 4, 30),
          category: ChallengeCategory.budget,
          participantCount: 201,
          completionRate: 0.45,
          fhsBonus: 5,
          seasonalEvent: SeasonalEvent.taxSeason.name,
        ),

        // ── Summer (June-July) ──
        CommunityChallenge(
          id: 'sum_security_$year',
          title: 'Évalue ton matelas de sécurité',
          description:
              'C\'est important pour ta confiance\u00a0: vérifie que tu '
              'as au moins 3 à 6\u00a0mois de dépenses en épargne liquide.',
          startDate: DateTime(year, 6, 1),
          endDate: DateTime(year, 7, 31),
          category: ChallengeCategory.patrimoine,
          participantCount: 267,
          completionRate: 0.61,
          fhsBonus: 6,
          seasonalEvent: SeasonalEvent.summerSavings.name,
        ),
        CommunityChallenge(
          id: 'sum_housing_$year',
          title: 'Revisite ta stratégie immobilière',
          description:
              'Imagine l\'impact sur 20\u00a0ans\u00a0: simule les '
              'scénarios propriétaire vs locataire avec les taux actuels.',
          startDate: DateTime(year, 6, 1),
          endDate: DateTime(year, 7, 31),
          category: ChallengeCategory.patrimoine,
          participantCount: 143,
          completionRate: 0.38,
          fhsBonus: 5,
          seasonalEvent: SeasonalEvent.summerSavings.name,
        ),
        CommunityChallenge(
          id: 'sum_lpp_$year',
          title: 'Fais le point sur ta LPP',
          description:
              'Ton progrès est visible\u00a0: scanne ton certificat de '
              'prévoyance et compare avec les projections MINT.',
          startDate: DateTime(year, 6, 1),
          endDate: DateTime(year, 7, 31),
          category: ChallengeCategory.lpp,
          participantCount: 312,
          completionRate: 0.52,
          fhsBonus: 7,
          seasonalEvent: SeasonalEvent.summerSavings.name,
        ),

        // ── Year-End (November-December) ──
        CommunityChallenge(
          id: 'ye_3a_$year',
          title: 'Dernière ligne droite pour ton 3a',
          description:
              'Courage, c\'est le moment\u00a0! Il reste quelques semaines '
              'pour compléter ton versement 3a avant le 31\u00a0décembre.',
          startDate: DateTime(year, 11, 1),
          endDate: DateTime(year, 12, 31),
          category: ChallengeCategory.pillar3a,
          participantCount: 521,
          completionRate: 0.78,
          fhsBonus: 10,
          seasonalEvent: SeasonalEvent.yearEndPlanning.name,
        ),
        CommunityChallenge(
          id: 'ye_bilan_$year',
          title: 'Bilan patrimonial annuel',
          description:
              'Une année de plus au compteur\u00a0! Fais le bilan '
              'de ton patrimoine\u00a0: épargne, prévoyance, dettes, '
              'investissements.',
          startDate: DateTime(year, 11, 1),
          endDate: DateTime(year, 12, 31),
          category: ChallengeCategory.patrimoine,
          participantCount: 298,
          completionRate: 0.49,
          fhsBonus: 8,
          seasonalEvent: SeasonalEvent.yearEndPlanning.name,
        ),
        CommunityChallenge(
          id: 'ye_december_$year',
          title: 'Planifie tes versements de décembre',
          description:
              'L\'impact fiscal peut être important\u00a0: organise tes '
              'versements 3a et rachats LPP avant la fin de l\'année fiscale.',
          startDate: DateTime(year, 11, 1),
          endDate: DateTime(year, 12, 31),
          category: ChallengeCategory.pillar3a,
          participantCount: 387,
          completionRate: 0.63,
          fhsBonus: 9,
          seasonalEvent: SeasonalEvent.yearEndPlanning.name,
        ),
      ];

  // ── Public API ──

  /// Get active challenges for the current period.
  ///
  /// Only returns challenges whose date range includes [now].
  /// Excludes challenges the user has already completed.
  static Future<List<CommunityChallenge>> getActiveChallenges({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final pool = _challengePool(effectiveNow.year);

    // Filter to active date range.
    final active = pool.where((c) =>
        !c.startDate.isAfter(effectiveNow) &&
        !c.endDate.isBefore(effectiveNow)).toList();

    // Exclude already-completed challenges.
    if (prefs != null) {
      final records = _loadRecords(prefs);
      final completedIds = records
          .where((r) => r.isCompleted)
          .map((r) => r.challengeId)
          .toSet();
      active.removeWhere((c) => completedIds.contains(c.id));
    }

    return active;
  }

  /// Join a challenge (opt-in).
  ///
  /// Records the join timestamp. Does nothing if already joined.
  static Future<void> joinChallenge({
    required String challengeId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    if (prefs == null) return;

    final records = _loadRecords(prefs);

    // Already joined? No-op.
    if (records.any((r) => r.challengeId == challengeId)) return;

    // Find the challenge to get its title and bonus.
    final effectiveNow = now ?? DateTime.now();
    final allChallenges = _challengePool(effectiveNow.year);
    final challenge = allChallenges
        .where((c) => c.id == challengeId)
        .firstOrNull;

    records.add(ChallengeRecord(
      challengeId: challengeId,
      title: challenge?.title ?? challengeId,
      joinedAt: effectiveNow,
      fhsBonus: challenge?.fhsBonus ?? 5,
    ));

    _saveRecords(prefs, records);
  }

  /// Complete a challenge.
  ///
  /// Sets the completion timestamp. Must be joined first.
  static Future<void> completeChallenge({
    required String challengeId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    if (prefs == null) return;

    final records = _loadRecords(prefs);
    final effectiveNow = now ?? DateTime.now();

    final idx = records.indexWhere((r) => r.challengeId == challengeId);
    if (idx < 0) return; // Not joined — no-op.

    final old = records[idx];
    if (old.isCompleted) return; // Already completed — no-op.

    records[idx] = ChallengeRecord(
      challengeId: old.challengeId,
      title: old.title,
      joinedAt: old.joinedAt,
      completedAt: effectiveNow,
      fhsBonus: old.fhsBonus,
    );

    _saveRecords(prefs, records);
  }

  /// Get user's challenge history (joined and/or completed).
  static Future<List<ChallengeRecord>> getHistory({
    SharedPreferences? prefs,
  }) async {
    if (prefs == null) return [];
    return _loadRecords(prefs);
  }

  /// Get upcoming seasonal events from [now] onward.
  static List<SeasonalEvent> getUpcomingEvents({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final month = effectiveNow.month;

    // Map months to seasonal events.
    // Jan → newYear, Mar-Apr → taxSeason, Jun-Jul → summer, Nov-Dec → yearEnd.
    final events = <SeasonalEvent>[];

    if (month <= 1) {
      events.addAll([
        SeasonalEvent.newYear,
        SeasonalEvent.taxSeason,
        SeasonalEvent.summerSavings,
        SeasonalEvent.yearEndPlanning,
      ]);
    } else if (month <= 4) {
      events.addAll([
        SeasonalEvent.taxSeason,
        SeasonalEvent.summerSavings,
        SeasonalEvent.yearEndPlanning,
      ]);
    } else if (month <= 7) {
      events.addAll([
        SeasonalEvent.summerSavings,
        SeasonalEvent.yearEndPlanning,
      ]);
    } else if (month <= 10) {
      events.add(SeasonalEvent.yearEndPlanning);
    }
    // Nov-Dec: yearEnd is current, next year's newYear is upcoming.
    // But we only return current-year events.

    return events;
  }

  /// Format a shareable achievement (anonymized, no PII, no comparison).
  ///
  /// Returns text suitable for sharing outside the app.
  /// NEVER contains personal data or social comparisons.
  static String formatShareableAchievement({
    required String milestoneId,
    required String milestoneLabel,
  }) {
    return 'J\'ai atteint le cap «\u00a0$milestoneLabel\u00a0» sur MINT\u00a0! '
        '$shareDisclaimer';
  }

  // ── Persistence helpers ──

  static List<ChallengeRecord> _loadRecords(SharedPreferences prefs) {
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChallengeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void _saveRecords(
    SharedPreferences prefs,
    List<ChallengeRecord> records,
  ) {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    prefs.setString(_recordsKey, json);
  }
}
