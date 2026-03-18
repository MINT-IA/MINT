import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

// ────────────────────────────────────────────────────────────
//  ADAPTIVE CHALLENGE SERVICE — S62 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Selects and manages weekly micro-challenges adapted to the
// user's lifecycle phase, archetype, and financial literacy.
//
// 50 challenges across 6 categories, 7 phases, 8 archetypes.
// Difficulty adapts: starts easy, upgrades after 3 completions,
// downgrades after 2 consecutive skips.
//
// FHS reward points: easy=1, medium=3, hard=5.
//
// Pure service — persistence via SharedPreferences.
// ────────────────────────────────────────────────────────────

/// Category of a micro-challenge.
enum ChallengeCategory {
  budget,
  epargne,
  prevoyance,
  fiscalite,
  patrimoine,
  education,
}

/// Difficulty level of a micro-challenge.
enum ChallengeDifficulty {
  easy,
  medium,
  hard,
}

/// A weekly micro-challenge for the user.
class MicroChallenge {
  /// Unique identifier.
  final String id;

  /// Title in French, informal "tu", with proper accents.
  final String title;

  /// 1-2 sentence educational description.
  final String description;

  /// GoRouter route for the associated action/simulator.
  final String actionRoute;

  /// Category of the challenge.
  final ChallengeCategory category;

  /// Difficulty level.
  final ChallengeDifficulty difficulty;

  /// Which lifecycle phases this challenge targets (empty = all).
  final Set<LifecyclePhase> targetPhases;

  /// Which archetypes this challenge targets (empty = all).
  final Set<String> targetArchetypes;

  /// FHS bonus points for completing the challenge (1-5).
  final int fhsRewardPoints;

  /// Legal reference if applicable (e.g. "OPP3 art.\u00a07").
  final String? legalReference;

  const MicroChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.actionRoute,
    required this.category,
    required this.difficulty,
    this.targetPhases = const {},
    this.targetArchetypes = const {},
    required this.fhsRewardPoints,
    this.legalReference,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'actionRoute': actionRoute,
        'category': category.name,
        'difficulty': difficulty.name,
        'fhsRewardPoints': fhsRewardPoints,
      };
}

/// Record of a completed or skipped challenge.
class ChallengeRecord {
  final String challengeId;
  final DateTime timestamp;
  final bool completed; // true = completed, false = skipped

  const ChallengeRecord({
    required this.challengeId,
    required this.timestamp,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'timestamp': timestamp.toIso8601String(),
        'completed': completed,
      };

  factory ChallengeRecord.fromJson(Map<String, dynamic> json) {
    return ChallengeRecord(
      challengeId: json['challengeId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      completed: json['completed'] as bool,
    );
  }
}

/// Selects and manages weekly micro-challenges.
///
/// Pure service. All state is persisted via SharedPreferences.
class AdaptiveChallengeService {
  AdaptiveChallengeService._();

  // SharedPreferences keys
  static const _historyKey = '_challenge_history';
  static const _currentWeekKey = '_challenge_current_week';
  static const _currentChallengeKey = '_challenge_current_id';

  // Difficulty adaptation thresholds
  static const _upgradeAfter = 3; // completions to upgrade
  static const _downgradeAfter = 2; // consecutive skips to downgrade

  // ────────────────────────────────────────────
  //  PUBLIC API
  // ────────────────────────────────────────────

  /// Get the weekly challenge for the user.
  ///
  /// Returns the same challenge for the entire ISO week. Returns null
  /// if all matching challenges have been completed.
  static Future<MicroChallenge?> getWeeklyChallenge({
    required CoachProfile profile,
    required LifecyclePhaseResult lifecycle,
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final currentDate = now ?? DateTime.now();
    final sp = prefs ?? await SharedPreferences.getInstance();
    final weekId = _isoWeekId(currentDate);

    // Check if we already assigned a challenge this week
    final storedWeek = sp.getString(_currentWeekKey);
    final storedId = sp.getString(_currentChallengeKey);
    if (storedWeek == weekId && storedId != null) {
      final found = challengePool.where((c) => c.id == storedId).firstOrNull;
      if (found != null) return found;
    }

    // Select a new challenge
    final history = await getHistory(prefs: sp);
    final completedIds = history
        .where((r) => r.completed)
        .map((r) => r.challengeId)
        .toSet();

    final difficulty = await currentDifficulty(prefs: sp);

    // Filter challenges matching user's phase, archetype, and difficulty
    final candidates = challengePool.where((c) {
      // Already completed → skip
      if (completedIds.contains(c.id)) return false;

      // Difficulty must match current adaptive level
      if (c.difficulty != difficulty) return false;

      // Phase filter: if challenge has target phases, user must be in one
      if (c.targetPhases.isNotEmpty &&
          !c.targetPhases.contains(lifecycle.phase)) {
        return false;
      }

      // Archetype filter: if challenge targets specific archetypes, must match
      if (c.targetArchetypes.isNotEmpty &&
          !c.targetArchetypes.contains(profile.archetype.name)) {
        return false;
      }

      return true;
    }).toList();

    if (candidates.isEmpty) {
      // Try adjacent difficulties before giving up
      final fallback = _fallbackCandidates(
        completedIds: completedIds,
        lifecycle: lifecycle,
        profile: profile,
        excludeDifficulty: difficulty,
      );
      if (fallback.isEmpty) return null;
      final selected = fallback[weekId.hashCode.abs() % fallback.length];
      await _persistCurrentChallenge(sp, weekId, selected.id);
      return selected;
    }

    // Deterministic-ish selection based on week to avoid randomness issues
    final selected = candidates[weekId.hashCode.abs() % candidates.length];
    await _persistCurrentChallenge(sp, weekId, selected.id);
    return selected;
  }

  /// Mark a challenge as completed.
  static Future<void> completeChallenge({
    required String challengeId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final record = ChallengeRecord(
      challengeId: challengeId,
      timestamp: now ?? DateTime.now(),
      completed: true,
    );
    await _appendRecord(sp, record);
  }

  /// Mark a challenge as skipped.
  static Future<void> skipChallenge({
    required String challengeId,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final record = ChallengeRecord(
      challengeId: challengeId,
      timestamp: now ?? DateTime.now(),
      completed: false,
    );
    await _appendRecord(sp, record);
  }

  /// Get the full history of completed and skipped challenges.
  static Future<List<ChallengeRecord>> getHistory({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final raw = sp.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ChallengeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Compute the current adaptive difficulty.
  ///
  /// - Starts at [ChallengeDifficulty.easy].
  /// - Upgrades after 3 completions at current level.
  /// - Downgrades after 2 consecutive skips.
  ///
  /// M9: Made async to load prefs if null, consistent with other methods.
  static Future<ChallengeDifficulty> currentDifficulty({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();

    final raw = sp.getString(_historyKey);
    if (raw == null || raw.isEmpty) return ChallengeDifficulty.easy;

    final list = jsonDecode(raw) as List<dynamic>;
    if (list.isEmpty) return ChallengeDifficulty.easy;

    final records = list
        .map((e) => ChallengeRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return _computeDifficulty(records);
  }

  // ────────────────────────────────────────────
  //  PRIVATE HELPERS
  // ────────────────────────────────────────────

  /// Compute adaptive difficulty from history.
  static ChallengeDifficulty _computeDifficulty(List<ChallengeRecord> records) {
    var level = ChallengeDifficulty.easy;
    var completionsAtLevel = 0;
    var consecutiveSkips = 0;

    for (final record in records) {
      if (record.completed) {
        consecutiveSkips = 0;
        completionsAtLevel++;
        if (completionsAtLevel >= _upgradeAfter &&
            level != ChallengeDifficulty.hard) {
          level = ChallengeDifficulty
              .values[level.index + 1];
          completionsAtLevel = 0;
        }
      } else {
        consecutiveSkips++;
        completionsAtLevel = 0;
        if (consecutiveSkips >= _downgradeAfter &&
            level != ChallengeDifficulty.easy) {
          level = ChallengeDifficulty
              .values[level.index - 1];
          consecutiveSkips = 0;
        }
      }
    }

    return level;
  }

  /// Fallback: try other difficulties when primary has no candidates.
  static List<MicroChallenge> _fallbackCandidates({
    required Set<String> completedIds,
    required LifecyclePhaseResult lifecycle,
    required CoachProfile profile,
    required ChallengeDifficulty excludeDifficulty,
  }) {
    return challengePool.where((c) {
      if (completedIds.contains(c.id)) return false;
      if (c.difficulty == excludeDifficulty) return false;
      if (c.targetPhases.isNotEmpty &&
          !c.targetPhases.contains(lifecycle.phase)) {
        return false;
      }
      if (c.targetArchetypes.isNotEmpty &&
          !c.targetArchetypes.contains(profile.archetype.name)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// ISO week identifier (e.g. "2026-W12").
  ///
  /// M6: Uses the ISO year of the Thursday of the week to handle
  /// year boundary correctly (e.g. Dec 31 may belong to W01 of next year).
  static String _isoWeekId(DateTime date) {
    // ISO 8601: week starts Monday, week 1 contains Jan 4
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekDay = date.weekday; // 1=Mon, 7=Sun
    final weekNumber = ((dayOfYear - weekDay + 10) / 7).floor();
    // ISO year = year of the Thursday of this week
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Persist the current week's challenge selection.
  static Future<void> _persistCurrentChallenge(
    SharedPreferences sp,
    String weekId,
    String challengeId,
  ) async {
    await sp.setString(_currentWeekKey, weekId);
    await sp.setString(_currentChallengeKey, challengeId);
  }

  /// Append a record to history.
  static Future<void> _appendRecord(
    SharedPreferences sp,
    ChallengeRecord record,
  ) async {
    final existing = await getHistory(prefs: sp);
    existing.add(record);
    await sp.setString(_historyKey, jsonEncode(existing.map((e) => e.toJson()).toList()));
  }

  // ────────────────────────────────────────────
  //  CHALLENGE POOL (50 challenges)
  // ────────────────────────────────────────────

  /// All phases shorthand for convenience.
  static const _allPhases = <LifecyclePhase>{};

  /// Phases from construction and above.
  static const _constructionPlus = {
    LifecyclePhase.construction,
    LifecyclePhase.acceleration,
    LifecyclePhase.consolidation,
    LifecyclePhase.transition,
    LifecyclePhase.retraite,
    LifecyclePhase.transmission,
  };

  /// Phases from acceleration and above.
  static const _accelerationPlus = {
    LifecyclePhase.acceleration,
    LifecyclePhase.consolidation,
    LifecyclePhase.transition,
    LifecyclePhase.retraite,
    LifecyclePhase.transmission,
  };

  /// Phases from consolidation and above.
  static const _consolidationPlus = {
    LifecyclePhase.consolidation,
    LifecyclePhase.transition,
    LifecyclePhase.retraite,
    LifecyclePhase.transmission,
  };

  /// Active working phases (not retired).
  static const _activePhases = {
    LifecyclePhase.demarrage,
    LifecyclePhase.construction,
    LifecyclePhase.acceleration,
    LifecyclePhase.consolidation,
    LifecyclePhase.transition,
  };

  /// The 50 micro-challenges pool.
  static const List<MicroChallenge> challengePool = [
    // ── BUDGET (8 challenges) ──────────────────────────────
    MicroChallenge(
      id: 'budget_01',
      title: 'Vérifie tes 3 plus grosses dépenses de la semaine',
      description:
          'Identifie où part ton argent\u00a0: ouvre ton budget et repère les 3 postes les plus élevés cette semaine.',
      actionRoute: '/budget',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'budget_02',
      title: 'Calcule ton taux d\u2019épargne mensuel réel',
      description:
          'Ton taux d\u2019épargne, c\u2019est ce qui reste après toutes les dépenses. Vérifie s\u2019il dépasse 10\u00a0% de ton revenu net.',
      actionRoute: '/budget',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'budget_03',
      title: 'Compare le coût de tes assurances avec une offre alternative',
      description:
          'Les primes d\u2019assurance peuvent varier de 30\u00a0% d\u2019un assureur à l\u2019autre. Vérifie si tu pourrais économiser en changeant de caisse.',
      actionRoute: '/assurances/lamal',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'LAMal art.\u00a07',
    ),
    MicroChallenge(
      id: 'budget_04',
      title: 'Analyse tes frais fixes vs variables',
      description:
          'Sépare tes charges fixes (loyer, assurances) et variables (sorties, loisirs). C\u2019est la base pour optimiser ton budget.',
      actionRoute: '/budget',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'budget_05',
      title: 'Vérifie ton ratio d\u2019endettement',
      description:
          'Ton ratio d\u2019endettement ne devrait pas dépasser 33\u00a0% de ton revenu brut. Calcule-le pour savoir où tu en es.',
      actionRoute: '/debt/ratio',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'budget_06',
      title: 'Simule le coût réel de ton leasing',
      description:
          'Un leasing, c\u2019est plus que la mensualité\u00a0: assurance, entretien, valeur résiduelle. Calcule le coût total.',
      actionRoute: '/simulator/leasing',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'budget_07',
      title: 'Évalue ton matelas de sécurité en mois',
      description:
          'Combien de mois pourrais-tu tenir sans revenu\u00a0? L\u2019idéal est 3 à 6 mois de charges. Vérifie le tien.',
      actionRoute: '/budget',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'budget_08',
      title: 'Vérifie si tu pourrais réduire ton crédit à la consommation',
      description:
          'Un crédit conso à 8-12\u00a0% est très coûteux. Regarde si tu peux accélérer le remboursement ou le consolider.',
      actionRoute: '/debt/repayment',
      category: ChallengeCategory.budget,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 5,
    ),

    // ── ÉPARGNE (9 challenges) ─────────────────────────────
    MicroChallenge(
      id: 'epargne_01',
      title: 'Mets de côté CHF\u00a050 cette semaine',
      description:
          'Même un petit montant compte\u00a0: CHF\u00a050 par semaine, c\u2019est CHF\u00a02\u2019600 par an. Le plus dur, c\u2019est de commencer.',
      actionRoute: '/pilier-3a',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: {LifecyclePhase.demarrage, LifecyclePhase.construction},
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'epargne_02',
      title: 'Vérifie ton solde 3a et compare au plafond',
      description:
          'Le plafond 3a salarié est de CHF\u00a07\u2019258 par an. Vérifie combien tu as déjà versé cette année.',
      actionRoute: '/pilier-3a',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _allPhases,
      fhsRewardPoints: 3,
      legalReference: 'OPP3 art.\u00a07',
    ),
    MicroChallenge(
      id: 'epargne_03',
      title: 'Simule un rachat LPP de CHF\u00a05\u2019000',
      description:
          'Un rachat LPP est déductible des impôts. Simule l\u2019impact d\u2019un rachat de CHF\u00a05\u2019000 sur ta prévoyance et ta fiscalité.',
      actionRoute: '/rachat-lpp',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _accelerationPlus,
      fhsRewardPoints: 5,
      legalReference: 'LPP art.\u00a079b',
    ),
    MicroChallenge(
      id: 'epargne_04',
      title: 'Vérifie si tu peux encore verser au 3a cette année',
      description:
          'Le versement 3a est annuel\u00a0: si tu n\u2019as pas encore versé le maximum, il reste peut-être du temps.',
      actionRoute: '/pilier-3a',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _activePhases,
      fhsRewardPoints: 1,
      legalReference: 'OPP3 art.\u00a07',
    ),
    MicroChallenge(
      id: 'epargne_05',
      title: 'Compare les rendements de tes comptes 3a',
      description:
          'Tous les comptes 3a ne se valent pas. Compare le rendement de tes comptes avec le simulateur.',
      actionRoute: '/3a-deep/comparator',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'epargne_06',
      title: 'Calcule le rendement réel de ton 3a après inflation',
      description:
          'Un rendement de 1\u00a0% avec une inflation de 1.5\u00a0%, c\u2019est un rendement réel négatif. Vérifie ta situation.',
      actionRoute: '/3a-deep/real-return',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 5,
    ),
    MicroChallenge(
      id: 'epargne_07',
      title: 'Simule un retrait échelonné de tes comptes 3a',
      description:
          'Retirer tes 3a sur plusieurs années peut réduire l\u2019impôt. Simule la stratégie de retrait échelonné.',
      actionRoute: '/3a-deep/staggered-withdrawal',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 5,
      legalReference: 'LIFD art.\u00a038',
    ),
    MicroChallenge(
      id: 'epargne_08',
      title: 'Vérifie si tu peux cotiser rétroactivement au 3a',
      description:
          'Depuis 2025, tu peux rattraper des années sans versement. Vérifie si tu es éligible au 3a rétroactif.',
      actionRoute: '/3a-retroactif',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _activePhases,
      fhsRewardPoints: 3,
      legalReference: 'OPP3 art.\u00a07 al.\u00a01bis',
    ),
    MicroChallenge(
      id: 'epargne_09',
      title: 'Vérifie ton libre passage si tu as changé d\u2019employeur',
      description:
          'Lors d\u2019un changement d\u2019emploi, ton capital LPP est transféré sur un compte de libre passage. Vérifie que rien n\u2019a été oublié.',
      actionRoute: '/libre-passage',
      category: ChallengeCategory.epargne,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'LFLP art.\u00a04',
    ),

    // ── PRÉVOYANCE (9 challenges) ──────────────────────────
    MicroChallenge(
      id: 'prevoyance_01',
      title: 'Demande ton extrait de compte AVS',
      description:
          'Ton extrait AVS montre tes années de cotisation et ta rente estimée. Demande-le gratuitement sur lavs.ch.',
      actionRoute: '/scan/avs-guide',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _accelerationPlus,
      fhsRewardPoints: 3,
      legalReference: 'LAVS art.\u00a030ter',
    ),
    MicroChallenge(
      id: 'prevoyance_02',
      title: 'Vérifie ta couverture invalidité',
      description:
          'En cas d\u2019invalidité, ta rente AI + LPP couvre-t-elle tes charges\u00a0? Vérifie le gap éventuel.',
      actionRoute: '/invalidite',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'LAI art.\u00a028',
    ),
    MicroChallenge(
      id: 'prevoyance_03',
      title: 'Compare rente vs capital pour ta LPP',
      description:
          'Rente à vie ou capital\u00a0? Chaque option a ses avantages fiscaux et de flexibilité. Compare les scénarios.',
      actionRoute: '/rente-vs-capital',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 5,
      legalReference: 'LPP art.\u00a037',
    ),
    MicroChallenge(
      id: 'prevoyance_04',
      title: 'Consulte ta projection retraite',
      description:
          'Regarde ta projection de retraite complète\u00a0: AVS + LPP + 3a. Vérifie si tu es sur la bonne trajectoire.',
      actionRoute: '/retraite',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'prevoyance_05',
      title: 'Optimise ta séquence de décaissement',
      description:
          'L\u2019ordre dans lequel tu retires tes piliers a un impact fiscal majeur. Simule différentes séquences.',
      actionRoute: '/decaissement',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: {LifecyclePhase.transition, LifecyclePhase.retraite},
      fhsRewardPoints: 5,
      legalReference: 'LIFD art.\u00a038',
    ),
    MicroChallenge(
      id: 'prevoyance_06',
      title: 'Vérifie tes lacunes AVS',
      description:
          'Chaque année sans cotisation AVS réduit ta rente. Vérifie si tu as des lacunes à combler.',
      actionRoute: '/scan/avs-guide',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _accelerationPlus,
      fhsRewardPoints: 3,
      legalReference: 'LAVS art.\u00a029',
    ),
    MicroChallenge(
      id: 'prevoyance_07',
      title: 'Planifie ta succession',
      description:
          'Qui hérite de quoi en droit suisse\u00a0? Vérifie les parts réservataires et si un testament est nécessaire.',
      actionRoute: '/succession',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 5,
      legalReference: 'CC art.\u00a0470',
    ),
    MicroChallenge(
      id: 'prevoyance_08',
      title: 'Vérifie ta couverture en cas de chômage',
      description:
          'En cas de perte d\u2019emploi, combien toucherais-tu et pendant combien de temps\u00a0? Simule ta situation.',
      actionRoute: '/unemployment',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _activePhases,
      fhsRewardPoints: 3,
      legalReference: 'LACI art.\u00a022',
    ),
    MicroChallenge(
      id: 'prevoyance_09',
      title: 'Vérifie la couverture invalidité de ton activité indépendante',
      description:
          'En tant qu\u2019indépendant·e, ta couverture AI peut être insuffisante. Vérifie si une IJM complémentaire serait utile.',
      actionRoute: '/independants/ijm',
      category: ChallengeCategory.prevoyance,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _allPhases,
      targetArchetypes: {'independentWithLpp', 'independentNoLpp'},
      fhsRewardPoints: 5,
      legalReference: 'LAI art.\u00a028',
    ),

    // ── FISCALITÉ (8 challenges) ───────────────────────────
    MicroChallenge(
      id: 'fiscalite_01',
      title: 'Estime ton économie fiscale 3a',
      description:
          'Chaque franc versé en 3a est déductible. Calcule combien tu économises en impôts cette année.',
      actionRoute: '/fiscal',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
      legalReference: 'LIFD art.\u00a033 al.\u00a01 lit.\u00a0e',
    ),
    MicroChallenge(
      id: 'fiscalite_02',
      title: 'Vérifie si un rachat LPP serait déductible cette année',
      description:
          'Les rachats LPP sont déductibles du revenu imposable. Vérifie ton potentiel de rachat et l\u2019économie fiscale.',
      actionRoute: '/rachat-lpp',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 5,
      legalReference: 'LPP art.\u00a079b',
    ),
    MicroChallenge(
      id: 'fiscalite_03',
      title: 'Simule l\u2019impôt sur un retrait de capital',
      description:
          'Le retrait de capital (LPP/3a) est taxé séparément à un taux réduit. Simule l\u2019impôt pour différents montants.',
      actionRoute: '/fiscal',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 3,
      legalReference: 'LIFD art.\u00a038',
    ),
    MicroChallenge(
      id: 'fiscalite_04',
      title: 'Compare salaire vs dividende si tu es indépendant·e',
      description:
          'Le mix salaire/dividende adapté à ta situation dépend de ton revenu et de ton canton. Simule les deux scénarios.',
      actionRoute: '/independants/dividende-salaire',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _allPhases,
      targetArchetypes: {'independentWithLpp', 'independentNoLpp'},
      fhsRewardPoints: 5,
    ),
    MicroChallenge(
      id: 'fiscalite_05',
      title: 'Vérifie la valeur locative imputée de ton bien',
      description:
          'Si tu es propriétaire, la valeur locative est ajoutée à ton revenu imposable. Vérifie si elle est correcte.',
      actionRoute: '/mortgage/imputed-rental',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'fiscalite_06',
      title: 'Calcule ta charge fiscale globale',
      description:
          'Impôt fédéral + cantonal + communal\u00a0: calcule ta charge fiscale totale en pourcentage de ton revenu.',
      actionRoute: '/fiscal',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _allPhases,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'fiscalite_07',
      title: 'Vérifie ta conformité FATCA',
      description:
          'En tant que citoyen·ne US, tes comptes suisses sont soumis à FATCA. Vérifie que ta situation est en ordre.',
      actionRoute: '/expatriation',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _allPhases,
      targetArchetypes: {'expatUs'},
      fhsRewardPoints: 5,
    ),
    MicroChallenge(
      id: 'fiscalite_08',
      title: 'Vérifie ton imposition à la source',
      description:
          'En tant que frontalier·ère, tu es imposé·e à la source. Vérifie que le taux appliqué correspond à ta situation.',
      actionRoute: '/segments/frontalier',
      category: ChallengeCategory.fiscalite,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _allPhases,
      targetArchetypes: {'crossBorder'},
      fhsRewardPoints: 3,
    ),

    // ── PATRIMOINE (8 challenges) ──────────────────────────
    MicroChallenge(
      id: 'patrimoine_01',
      title: 'Calcule ta capacité d\u2019emprunt hypothécaire',
      description:
          'Avec la règle des 1/3, vérifie combien tu pourrais emprunter pour un achat immobilier.',
      actionRoute: '/hypotheque',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'FINMA circ.\u00a02012/2',
    ),
    MicroChallenge(
      id: 'patrimoine_02',
      title: 'Simule SARON vs taux fixe pour ton hypothèque',
      description:
          'SARON (variable) ou taux fixe\u00a0? Simule les deux scénarios sur 10 ans pour voir la différence.',
      actionRoute: '/mortgage/saron-vs-fixed',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 5,
    ),
    MicroChallenge(
      id: 'patrimoine_03',
      title: 'Compare location vs propriété',
      description:
          'Acheter n\u2019est pas toujours mieux que louer. Compare les deux options sur 20 ans avec le simulateur.',
      actionRoute: '/arbitrage/location-vs-propriete',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'patrimoine_04',
      title: 'Simule un EPL (retrait anticipé LPP pour ton logement)',
      description:
          'Tu peux utiliser ton 2e pilier pour financer ton logement. Simule l\u2019impact sur ta retraite.',
      actionRoute: '/epl',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 5,
      legalReference: 'LPP art.\u00a030c',
    ),
    MicroChallenge(
      id: 'patrimoine_05',
      title: 'Consulte ton bilan patrimonial complet',
      description:
          'Actifs, passifs, patrimoine net\u00a0: fais le point sur ta situation financière globale.',
      actionRoute: '/profile/bilan',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'patrimoine_06',
      title: 'Vérifie ton allocation annuelle optimale',
      description:
          'Entre 3a, rachat LPP et amortissement hypothécaire, comment répartir ton épargne cette année\u00a0?',
      actionRoute: '/arbitrage/allocation-annuelle',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _accelerationPlus,
      fhsRewardPoints: 5,
    ),
    MicroChallenge(
      id: 'patrimoine_07',
      title: 'Simule l\u2019impact d\u2019un amortissement hypothécaire',
      description:
          'Amortir directement ou indirectement via le 3a\u00a0? Simule les deux options et leur impact fiscal.',
      actionRoute: '/mortgage/amortization',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'patrimoine_08',
      title: 'Simule l\u2019effet des intérêts composés sur 20 ans',
      description:
          'Même un petit rendement crée un effet boule de neige. Simule la croissance de ton épargne sur 20 ans.',
      actionRoute: '/simulator/compound',
      category: ChallengeCategory.patrimoine,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),

    // ── ÉDUCATION (8 challenges) ───────────────────────────
    MicroChallenge(
      id: 'education_01',
      title: 'Lis l\u2019article sur la 13e rente AVS',
      description:
          'Depuis 2026, la 13e rente AVS augmente ta rente annuelle. Découvre ce que ça change concrètement pour toi.',
      actionRoute: '/education/hub',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
      legalReference: 'LAVS art.\u00a034',
    ),
    MicroChallenge(
      id: 'education_02',
      title: 'Comprends la différence entre taux de conversion min et surobligatoire',
      description:
          'Le taux de conversion LPP de 6.8\u00a0% ne s\u2019applique qu\u2019au minimum. Ta caisse peut avoir un taux différent pour le surobligatoire.',
      actionRoute: '/education/hub',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.hard,
      targetPhases: _consolidationPlus,
      fhsRewardPoints: 5,
      legalReference: 'LPP art.\u00a014',
    ),
    MicroChallenge(
      id: 'education_03',
      title: 'Découvre comment fonctionne le 1er pilier',
      description:
          'L\u2019AVS est un système par répartition\u00a0: les actifs financent les retraités. Comprends les bases de ta future rente.',
      actionRoute: '/education/hub',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
      legalReference: 'LAVS art.\u00a01',
    ),
    MicroChallenge(
      id: 'education_04',
      title: 'Comprends le système des 3 piliers',
      description:
          'AVS + LPP + 3a\u00a0: chaque pilier a son rôle. Comprends comment ils se complètent pour ta retraite.',
      actionRoute: '/education/hub',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.easy,
      targetPhases: _allPhases,
      fhsRewardPoints: 1,
    ),
    MicroChallenge(
      id: 'education_05',
      title: 'Explore le concept de taux de remplacement',
      description:
          'Le taux de remplacement mesure le rapport entre ta rente et ton dernier salaire. L\u2019objectif courant est 60-80\u00a0%.',
      actionRoute: '/retraite',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _allPhases,
      fhsRewardPoints: 3,
    ),
    MicroChallenge(
      id: 'education_06',
      title: 'Comprends les bonifications LPP par tranche d\u2019âge',
      description:
          'Les bonifications LPP augmentent avec l\u2019âge\u00a0: 7\u00a0%, 10\u00a0%, 15\u00a0%, 18\u00a0%. Vérifie dans quelle tranche tu es.',
      actionRoute: '/education/hub',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'LPP art.\u00a016',
    ),
    MicroChallenge(
      id: 'education_07',
      title: 'Découvre les conséquences financières du concubinage',
      description:
          'En concubinage, tu n\u2019as pas les mêmes droits successoraux qu\u2019un·e marié·e. Vérifie les protections nécessaires.',
      actionRoute: '/concubinage',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _constructionPlus,
      fhsRewardPoints: 3,
      legalReference: 'CC art.\u00a0470',
    ),
    MicroChallenge(
      id: 'education_08',
      title: 'Comprends l\u2019impact du gender gap sur la retraite',
      description:
          'Les femmes touchent en moyenne 37\u00a0% de rente en moins. Comprends les causes et les solutions possibles.',
      actionRoute: '/segments/gender-gap',
      category: ChallengeCategory.education,
      difficulty: ChallengeDifficulty.medium,
      targetPhases: _allPhases,
      fhsRewardPoints: 3,
    ),
  ];
}
