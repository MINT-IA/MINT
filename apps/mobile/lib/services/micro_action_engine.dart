import 'package:flutter/material.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coaching_service.dart';

// ────────────────────────────────────────────────────────────
//  MICRO-ACTION ENGINE — Coach Vivant (Track A)
// ────────────────────────────────────────────────────────────
//
//  Genere des micro-actions (1-3) personnalisees a partir du
//  profil, du check-in mensuel et du contexte temporel.
//
//  Chaque micro-action = 1 titre + 1 impact CHF + 1 duree
//  estimee + 1 deeplink vers l'ecran d'action.
//
//  Selection: urgence temporelle > impact fiscal > gaps profil.
//  Sources: CoachingService tips, TemporalPriorityService.
//
//  Ne constitue pas un conseil financier — outil educatif (LSFin).
// ────────────────────────────────────────────────────────────

/// Urgency level for micro-actions.
enum MicroActionUrgency { critical, high, medium, low }

/// A single, actionable micro-step the user can do now.
class MicroAction {
  /// Unique identifier (e.g., 'verse_3a_now', 'scan_lpp_cert').
  final String id;

  /// Short title (max ~40 chars, French, informal "tu").
  final String title;

  /// One-line description of what the user should do.
  final String description;

  /// Category for grouping (3a, lpp, budget, assurance, couple, retraite).
  final String category;

  /// Estimated time to complete (minutes).
  final int estimatedMinutes;

  /// Estimated annual CHF impact (tax savings, returns, etc.). Null if not quantifiable.
  final double? estimatedImpactChf;

  /// GoRouter deeplink to the relevant screen.
  final String deeplink;

  /// Priority score (0-100, higher = more urgent/impactful).
  final int priorityScore;

  /// Urgency level for visual badge.
  final MicroActionUrgency urgency;

  /// Icon for display.
  final IconData icon;

  /// Legal source reference.
  final String? source;

  const MicroAction({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.estimatedMinutes,
    this.estimatedImpactChf,
    required this.deeplink,
    required this.priorityScore,
    required this.urgency,
    required this.icon,
    this.source,
  });
}

class MicroActionEngine {
  MicroActionEngine._();

  /// Suggest 1-3 micro-actions based on profile + check-in context.
  ///
  /// Selection priority:
  /// 1. Temporal urgency (3a deadline, fiscal season)
  /// 2. Profile gaps (missing data → scan/enrich)
  /// 3. Financial impact (rachat, 3a versement, budget fix)
  /// 4. Couple coordination (if applicable)
  static List<MicroAction> suggest({
    required CoachProfile profile,
    MonthlyCheckIn? currentCheckIn,
    MonthlyCheckIn? previousCheckIn,
    int limit = 3,
  }) {
    final candidates = <MicroAction>[];
    final now = DateTime.now();
    final age = now.year - profile.birthYear;

    // ── 1. Temporal urgency ──────────────────────────
    candidates.addAll(_temporalActions(profile, now));

    // ── 2. Profile gaps (data enrichment) ────────────
    candidates.addAll(_profileGapActions(profile));

    // ── 3. Financial optimization ────────────────────
    candidates.addAll(_financialActions(profile, age));

    // ── 4. Check-in anomalies ────────────────────────
    if (currentCheckIn != null) {
      candidates.addAll(
          _checkInDrivenActions(profile, currentCheckIn, previousCheckIn));
    }

    // ── 5. Couple coordination ───────────────────────
    if (profile.isCouple && profile.conjoint != null) {
      candidates.addAll(_coupleActions(profile));
    }

    // ── Dedup by id + sort by priority ───────────────
    final seen = <String>{};
    final deduped = <MicroAction>[];
    for (final action in candidates) {
      if (seen.add(action.id)) deduped.add(action);
    }
    deduped.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return deduped.take(limit).toList();
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Temporal actions (calendar-driven)
  // ──────────────────────────────────────────────────

  static List<MicroAction> _temporalActions(
      CoachProfile profile, DateTime now) {
    final actions = <MicroAction>[];
    final daysUntilYearEnd =
        DateTime(now.year, 12, 31).difference(now).inDays;

    // 3a deadline (Oct-Dec = high urgency)
    if (now.month >= 10) {
      final plafond =
          profile.employmentStatus == 'independant' ? 36288.0 : 7258.0;
      final verse3a = profile.total3aMensuel * 12;
      final marge = (plafond - verse3a).clamp(0.0, plafond);
      if (marge > 0) {
        final taxSaving = marge * 0.30; // ~30% marginal estimate
        actions.add(MicroAction(
          id: 'verse_3a_deadline',
          title: 'Verse ton 3a avant le 31 decembre',
          description:
              'Il reste $daysUntilYearEnd jours. Marge restante : CHF ${marge.round()}.',
          category: '3a',
          estimatedMinutes: 5,
          estimatedImpactChf: taxSaving,
          deeplink: '/simulator/3a',
          priorityScore: 95,
          urgency: daysUntilYearEnd <= 30
              ? MicroActionUrgency.critical
              : MicroActionUrgency.high,
          icon: Icons.savings_outlined,
          source: 'OPP3 art. 7',
        ));
      }
    }

    // Fiscal season (Jan-Mar)
    if (now.month >= 1 && now.month <= 3) {
      actions.add(const MicroAction(
        id: 'fiscal_deductions',
        title: 'Verifie tes deductions fiscales',
        description:
            'Saison fiscale en cours. Rassemble tes attestations 3a et LPP.',
        category: 'fiscalite',
        estimatedMinutes: 15,
        deeplink: '/profile/bilan',
        priorityScore: 90,
        urgency: MicroActionUrgency.high,
        icon: Icons.receipt_long_outlined,
        source: 'LIFD art. 33',
      ));
    }

    return actions;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Profile gap actions (data enrichment)
  // ──────────────────────────────────────────────────

  static List<MicroAction> _profileGapActions(CoachProfile profile) {
    final actions = <MicroAction>[];

    // Missing LPP data → scan certificate
    if (profile.prevoyance.avoirLppTotal == null ||
        profile.prevoyance.avoirLppTotal == 0) {
      actions.add(const MicroAction(
        id: 'scan_lpp_cert',
        title: 'Scanne ton certificat LPP',
        description:
            'Ajoute ton avoir LPP pour des projections plus precises (+12 pts).',
        category: 'lpp',
        estimatedMinutes: 2,
        deeplink: '/profile/documents',
        priorityScore: 85,
        urgency: MicroActionUrgency.medium,
        icon: Icons.document_scanner_outlined,
        source: 'LPP art. 86b',
      ));
    }

    // Missing assurance maladie
    if (profile.depenses.assuranceMaladie <= 0) {
      actions.add(const MicroAction(
        id: 'add_assurance',
        title: 'Renseigne ta prime LAMal',
        description:
            'Ta prime d\'assurance maladie manque pour un bilan complet.',
        category: 'assurance',
        estimatedMinutes: 2,
        deeplink: '/profile/bilan',
        priorityScore: 60,
        urgency: MicroActionUrgency.low,
        icon: Icons.health_and_safety_outlined,
        source: 'LAMal',
      ));
    }

    // Missing 3a data
    if ((profile.prevoyance.totalEpargne3a ?? 0) <= 0) {
      actions.add(const MicroAction(
        id: 'add_3a_balance',
        title: 'Ajoute ton solde 3a',
        description:
            'Ton avoir 3e pilier manque. Ajoute-le pour une projection complete.',
        category: '3a',
        estimatedMinutes: 2,
        deeplink: '/profile/bilan',
        priorityScore: 70,
        urgency: MicroActionUrgency.medium,
        icon: Icons.account_balance_outlined,
        source: 'OPP3 art. 7',
      ));
    }

    return actions;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Financial optimization actions
  // ──────────────────────────────────────────────────

  static List<MicroAction> _financialActions(CoachProfile profile, int age) {
    final actions = <MicroAction>[];

    // LPP buyback potential (45+ with rachat capacity)
    if (age >= 45 && (profile.prevoyance.avoirLppTotal ?? 0) > 0) {
      actions.add(const MicroAction(
        id: 'explore_rachat_lpp',
        title: 'Explore le rachat LPP',
        description:
            'A ton age, un rachat echelonne pourrait optimiser ta fiscalite.',
        category: 'lpp',
        estimatedMinutes: 5,
        deeplink: '/lpp-deep/rachat',
        priorityScore: 75,
        urgency: MicroActionUrgency.medium,
        icon: Icons.trending_up_outlined,
        source: 'LPP art. 79b',
      ));
    }

    // Emergency fund check (if depenses available but low liquidity)
    final depMensuelles = profile.totalDepensesMensuelles;
    final liquide = profile.patrimoine.epargneLiquide;
    if (depMensuelles > 0) {
      final moisReserve = liquide / depMensuelles;
      if (moisReserve < 3) {
        actions.add(MicroAction(
          id: 'build_emergency_fund',
          title: 'Renforce ta reserve de liquidite',
          description:
              'Tu as ${moisReserve.toStringAsFixed(1)} mois de reserve. L\'ideal est 3-6 mois.',
          category: 'budget',
          estimatedMinutes: 10,
          deeplink: '/budget',
          priorityScore: 65,
          urgency: moisReserve < 1
              ? MicroActionUrgency.high
              : MicroActionUrgency.medium,
          icon: Icons.shield_outlined,
        ));
      }
    }

    return actions;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Check-in driven actions (anomaly-based)
  // ──────────────────────────────────────────────────

  static List<MicroAction> _checkInDrivenActions(
    CoachProfile profile,
    MonthlyCheckIn current,
    MonthlyCheckIn? previous,
  ) {
    final actions = <MicroAction>[];

    // Large exceptional expenses → budget review
    final depExc = current.depensesExceptionnelles ?? 0;
    if (depExc > 2000) {
      actions.add(MicroAction(
        id: 'budget_review_depexc',
        title: 'Revois ton budget ce mois',
        description:
            'Depenses exceptionnelles de CHF ${depExc.round()} detectees.',
        category: 'budget',
        estimatedMinutes: 10,
        deeplink: '/budget',
        priorityScore: 70,
        urgency: MicroActionUrgency.medium,
        icon: Icons.pie_chart_outline,
      ));
    }

    // Versements dropped significantly vs previous
    if (previous != null) {
      final prevTotal = previous.totalVersements;
      final currTotal = current.totalVersements;
      if (prevTotal > 0 && currTotal < prevTotal * 0.5) {
        actions.add(const MicroAction(
          id: 'versements_drop',
          title: 'Tes versements ont baisse',
          description:
              'Tes versements ce mois sont inferieurs a la moitie du mois dernier. '
              'Souhaites-tu ajuster ton plan ?',
          category: 'budget',
          estimatedMinutes: 5,
          deeplink: '/profile/bilan',
          priorityScore: 68,
          urgency: MicroActionUrgency.medium,
          icon: Icons.trending_down_outlined,
        ));
      }
    }

    return actions;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Couple coordination actions
  // ──────────────────────────────────────────────────

  static List<MicroAction> _coupleActions(CoachProfile profile) {
    final actions = <MicroAction>[];
    final conjoint = profile.conjoint;
    if (conjoint == null) return actions;

    final conjName = conjoint.firstName ?? 'ton conjoint';

    // FATCA coordination
    if (conjoint.isFatcaResident) {
      actions.add(MicroAction(
        id: 'fatca_couple_check',
        title: 'Verifie vos obligations FATCA',
        description:
            '$conjName est resident·e US. Vos comptes 3a et LPP '
            'peuvent etre impactes.',
        category: 'couple',
        estimatedMinutes: 10,
        deeplink: '/profile/bilan',
        priorityScore: 82,
        urgency: MicroActionUrgency.high,
        icon: Icons.flag_outlined,
        source: 'FATCA / IGA CH-US',
      ));
    }

    // Conjoint profile incomplete
    if ((conjoint.salaireBrutMensuel ?? 0) <= 0) {
      actions.add(MicroAction(
        id: 'complete_conjoint_profile',
        title: 'Complete le profil de $conjName',
        description:
            'Ajoute son salaire pour des projections couple precises.',
        category: 'couple',
        estimatedMinutes: 3,
        deeplink: '/profile/bilan',
        priorityScore: 55,
        urgency: MicroActionUrgency.low,
        icon: Icons.people_outline,
      ));
    }

    return actions;
  }
}
