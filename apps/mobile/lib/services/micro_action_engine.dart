import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';

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
  //  PRIVATE: Temporal actions (via TemporalPriorityService)
  // ──────────────────────────────────────────────────

  static List<MicroAction> _temporalActions(
      CoachProfile profile, DateTime now) {
    final actions = <MicroAction>[];

    // ── Compute personalized 3a data for TemporalPriority ──
    final plafond =
        profile.employmentStatus == 'independant' ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;
    final verse3a = profile.total3aMensuel * 12;
    final marge3a = (plafond - verse3a).clamp(0.0, plafond);
    final taxSaving3a = marge3a * 0.30; // ~30% marginal estimate

    // ── Get real temporal items from TemporalPriorityService ──
    final temporalItems = TemporalPriorityService.prioritize(
      today: now,
      canton: profile.canton,
      taxSaving3a: taxSaving3a,
      limit: 3,
    );

    // ── Convert TemporalItems → MicroActions ──
    for (final item in temporalItems) {
      actions.add(MicroAction(
        id: _temporalItemId(item),
        title: item.title,
        description: '${item.body} ${item.timeConstraint}',
        category: _temporalItemCategory(item),
        estimatedMinutes: _temporalItemMinutes(item),
        estimatedImpactChf: _parseChfFromPersonalNumber(item.personalNumber),
        deeplink: item.deeplink,
        priorityScore: _temporalUrgencyToScore(item.urgency),
        urgency: _mapTemporalUrgency(item.urgency),
        icon: _temporalItemIcon(item),
        source: _temporalItemSource(item),
      ));
    }

    return actions;
  }

  /// Map TemporalItem to a stable MicroAction id.
  static String _temporalItemId(TemporalItem item) {
    final dl = item.deeplink.replaceAll('/', '_').replaceAll(RegExp('^_'), '');
    if (item.title.contains('3a') || item.title.contains('3e pilier')) {
      return 'verse_3a_deadline';
    }
    if (item.title.contains('fiscal') || item.title.contains('declaration')) {
      return 'fiscal_deductions';
    }
    if (item.title.contains('FRI') || item.title.contains('score')) {
      return 'quarterly_fri_review';
    }
    if (item.title.contains('plafond')) {
      return 'new_year_plafonds';
    }
    return 'temporal_$dl';
  }

  /// Infer category from TemporalItem content.
  static String _temporalItemCategory(TemporalItem item) {
    if (item.title.contains('3a') || item.title.contains('3e pilier')) {
      return '3a';
    }
    if (item.title.contains('fiscal') || item.title.contains('declaration')) {
      return 'fiscalite';
    }
    return 'retraite';
  }

  /// Estimated minutes to act on a temporal item.
  static int _temporalItemMinutes(TemporalItem item) {
    if (item.title.contains('3a')) return 5;
    if (item.title.contains('fiscal')) return 15;
    return 5;
  }

  /// Parse CHF amount from personalNumber string (e.g. "CHF 1'820").
  static double? _parseChfFromPersonalNumber(String personalNumber) {
    if (personalNumber.isEmpty) return null;
    final cleaned = personalNumber
        .replaceAll('CHF', '')
        .replaceAll("'", '')
        .replaceAll('\u2019', '')
        .trim();
    return double.tryParse(cleaned);
  }

  /// Map TemporalUrgency → MicroAction priority score (0-100).
  static int _temporalUrgencyToScore(TemporalUrgency urgency) {
    switch (urgency) {
      case TemporalUrgency.critical:
        return 98;
      case TemporalUrgency.high:
        return 92;
      case TemporalUrgency.medium:
        return 80;
      case TemporalUrgency.low:
        return 60;
    }
  }

  /// Map TemporalUrgency → MicroActionUrgency.
  static MicroActionUrgency _mapTemporalUrgency(TemporalUrgency urgency) {
    switch (urgency) {
      case TemporalUrgency.critical:
        return MicroActionUrgency.critical;
      case TemporalUrgency.high:
        return MicroActionUrgency.high;
      case TemporalUrgency.medium:
        return MicroActionUrgency.medium;
      case TemporalUrgency.low:
        return MicroActionUrgency.low;
    }
  }

  /// Icon for temporal-driven micro-actions.
  static IconData _temporalItemIcon(TemporalItem item) {
    if (item.title.contains('3a')) return Icons.savings_outlined;
    if (item.title.contains('fiscal') || item.title.contains('declaration')) {
      return Icons.receipt_long_outlined;
    }
    if (item.title.contains('FRI') || item.title.contains('score')) {
      return Icons.analytics_outlined;
    }
    return Icons.calendar_today_outlined;
  }

  /// Legal source for temporal-driven micro-actions.
  static String? _temporalItemSource(TemporalItem item) {
    if (item.title.contains('3a')) return 'OPP3 art. 7';
    if (item.title.contains('fiscal') || item.title.contains('declaration')) {
      return 'LIFD art. 33';
    }
    return null;
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
    if (profile.prevoyance.totalEpargne3a <= 0) {
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
