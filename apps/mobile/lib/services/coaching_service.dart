import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────
//  COACHING PROACTIF SERVICE — Sprint S11
// ────────────────────────────────────────────────────────────
//
// Generates personalised coaching tips based on the user's
// financial profile. All logic is local (no backend call).
// Aligned with backend coaching triggers for consistency.
// ────────────────────────────────────────────────────────────

/// Priority levels for coaching tips.
enum CoachingPriority {
  haute,
  moyenne,
  basse,
}

/// Employment status used in coaching logic.
enum EmploymentStatus {
  salarie,
  independant,
  sansEmploi,
}

/// Marital status used in coaching logic.
enum EtatCivil {
  celibataire,
  marie,
  divorce,
  veuf,
  concubinage,
}

/// User's financial profile for coaching tip generation.
class CoachingProfile {
  final int age;
  final String canton; // e.g. "VD", "GE", "ZH"
  final double revenuAnnuel;
  final bool has3a;
  final double montant3a; // annual contribution this year
  final bool hasLpp;
  final double avoirLpp;
  final double lacuneLpp; // buyback room
  final double tauxActivite; // 0.0 – 100.0 (%)
  final double chargesFixesMensuelles;
  final double epargneDispo; // available savings
  final double detteTotale;
  final bool hasBudget;
  final EmploymentStatus employmentStatus;
  final EtatCivil etatCivil;

  const CoachingProfile({
    required this.age,
    required this.canton,
    required this.revenuAnnuel,
    this.has3a = false,
    this.montant3a = 0,
    this.hasLpp = false,
    this.avoirLpp = 0,
    this.lacuneLpp = 0,
    this.tauxActivite = 100,
    this.chargesFixesMensuelles = 0,
    this.epargneDispo = 0,
    this.detteTotale = 0,
    this.hasBudget = false,
    this.employmentStatus = EmploymentStatus.salarie,
    this.etatCivil = EtatCivil.celibataire,
  });
}

/// A single coaching tip.
class CoachingTip {
  final String id;
  final String category; // "fiscalite", "prevoyance", "budget", "retraite"
  final CoachingPriority priority;
  final String title;
  final String message;
  final String action; // call-to-action text
  final double? estimatedImpactChf;
  final String source; // legal/regulatory source reference
  final IconData icon;

  const CoachingTip({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.message,
    required this.action,
    this.estimatedImpactChf,
    required this.source,
    required this.icon,
  });
}

/// Service that generates proactive coaching tips from a user profile.
///
/// All computations are local. No banned terms ("garanti", "assuré",
/// "certain") are used — only "peut", "pourrait", "estimation".
class CoachingService {
  // ──────────────────────────────────────────────────────────
  //  Constants
  // ──────────────────────────────────────────────────────────

  /// 3a ceiling for salaried employees (2024+).
  static const double _plafond3aSalarie = 7056;

  /// 3a ceiling for self-employed (2024+).
  static const double _plafond3aIndependant = 35280;

  /// Swiss legal retirement age (post-AVS21 reform, unified at 65).
  static const int _ageRetraite = 65;

  /// Simplified cantonal marginal tax rates for fiscal impact estimation.
  /// These are rough averages (fed + cantonal + communal) at ~80 kCHF income.
  static const Map<String, double> _tauxMarginalCantonal = {
    'ZH': 0.34,
    'BE': 0.38,
    'LU': 0.30,
    'UR': 0.25,
    'SZ': 0.24,
    'OW': 0.25,
    'NW': 0.25,
    'GL': 0.29,
    'ZG': 0.22,
    'FR': 0.35,
    'SO': 0.35,
    'BS': 0.37,
    'BL': 0.35,
    'SH': 0.33,
    'AR': 0.30,
    'AI': 0.27,
    'SG': 0.33,
    'GR': 0.32,
    'AG': 0.33,
    'TG': 0.31,
    'TI': 0.35,
    'VD': 0.37,
    'VS': 0.32,
    'NE': 0.38,
    'GE': 0.37,
    'JU': 0.38,
  };

  /// Age milestones with coaching relevance.
  static const List<int> _ageMilestones = [25, 35, 45, 50, 55, 58, 63];

  // ──────────────────────────────────────────────────────────
  //  Public API
  // ──────────────────────────────────────────────────────────

  /// Generate a sorted list of coaching tips for the given profile.
  ///
  /// Tips are sorted by priority (haute first), then by estimated
  /// financial impact (highest first).
  static List<CoachingTip> generateTips({
    required CoachingProfile profile,
  }) {
    final tips = <CoachingTip>[];

    // a) 3a deadline (Oct–Dec)
    _check3aDeadline(profile, tips);

    // b) Missing 3a
    _checkMissing3a(profile, tips);

    // c) LPP buyback opportunity
    _checkLppBuyback(profile, tips);

    // d) Tax declaration deadline (March 31)
    _checkTaxDeadline(profile, tips);

    // e) Retirement countdown (age >= 50)
    _checkRetirementCountdown(profile, tips);

    // f) Emergency fund
    _checkEmergencyFund(profile, tips);

    // g) Debt ratio
    _checkDebtRatio(profile, tips);

    // h) Age milestones
    _checkAgeMilestones(profile, tips);

    // i) Part-time gap
    _checkPartTimeGap(profile, tips);

    // j) Independent alert
    _checkIndependentAlert(profile, tips);

    // k) Budget missing
    _checkBudgetMissing(profile, tips);

    // l) 3a not maxed
    _check3aNotMaxed(profile, tips);

    // Sort: haute first, then by impact descending
    tips.sort((a, b) {
      final priorityCmp = a.priority.index.compareTo(b.priority.index);
      if (priorityCmp != 0) return priorityCmp;
      final impactA = a.estimatedImpactChf ?? 0;
      final impactB = b.estimatedImpactChf ?? 0;
      return impactB.compareTo(impactA); // highest impact first
    });

    return tips;
  }

  // ──────────────────────────────────────────────────────────
  //  Coaching triggers (private)
  // ──────────────────────────────────────────────────────────

  /// a) 3a deadline: October–December, remind to max out 3a.
  static void _check3aDeadline(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    final now = DateTime.now();
    if (now.month < 10 || now.month > 12) return;
    if (!profile.has3a) return;

    final plafond = profile.employmentStatus == EmploymentStatus.independant
        ? _plafond3aIndependant
        : _plafond3aSalarie;
    final restant = plafond - profile.montant3a;
    if (restant <= 0) return;

    final tauxMarginal = _getTauxMarginal(profile.canton);
    final impact = restant * tauxMarginal;

    tips.add(CoachingTip(
      id: 'deadline_3a',
      category: 'fiscalite',
      priority: CoachingPriority.haute,
      title: 'Versement 3a avant le 31 decembre',
      message:
          'Il vous reste ${_formatChf(restant)} de marge sur votre plafond 3a '
          '(${_formatChf(plafond)}). Un versement avant le 31 decembre '
          'pourrait reduire votre charge fiscale de ${_formatChf(impact)} '
          'environ.',
      action: 'Simuler mon 3a',
      estimatedImpactChf: impact,
      source: 'LPP art. 7 / OPP3',
      icon: Icons.calendar_today,
    ));
  }

  /// b) Missing 3a: user has no 3a at all.
  static void _checkMissing3a(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.has3a) return;
    if (profile.revenuAnnuel <= 0) return;

    final plafond = profile.employmentStatus == EmploymentStatus.independant
        ? _plafond3aIndependant
        : _plafond3aSalarie;
    final tauxMarginal = _getTauxMarginal(profile.canton);
    final impact = plafond * tauxMarginal;

    tips.add(CoachingTip(
      id: 'missing_3a',
      category: 'prevoyance',
      priority: CoachingPriority.haute,
      title: 'Vous n\'avez pas de 3e pilier',
      message:
          'Ouvrir un 3e pilier vous permettrait de deduire jusqu\'a '
          '${_formatChf(plafond)} de votre revenu imposable chaque annee. '
          'L\'economie fiscale estimee est de ${_formatChf(impact)} par an '
          'dans le canton de ${profile.canton}.',
      action: 'Decouvrir le 3e pilier',
      estimatedImpactChf: impact,
      source: 'LPP art. 82 / OPP3 art. 7',
      icon: Icons.savings_outlined,
    ));
  }

  /// c) LPP buyback opportunity.
  static void _checkLppBuyback(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (!profile.hasLpp) return;
    if (profile.lacuneLpp <= 0) return;

    final tauxMarginal = _getTauxMarginal(profile.canton);
    // Recommend max 20% of income or available lacune, whichever is smaller
    final double rachatRecommande =
        (profile.lacuneLpp).clamp(0.0, profile.revenuAnnuel * 0.2);
    final impact = rachatRecommande * tauxMarginal;

    final priority = profile.lacuneLpp > 50000
        ? CoachingPriority.haute
        : CoachingPriority.moyenne;

    tips.add(CoachingTip(
      id: 'lpp_buyback',
      category: 'prevoyance',
      priority: priority,
      title: 'Rachat LPP possible',
      message:
          'Vous avez une lacune de prevoyance de ${_formatChf(profile.lacuneLpp)}. '
          'Un rachat volontaire de ${_formatChf(rachatRecommande)} '
          'pourrait vous faire economiser environ ${_formatChf(impact)} '
          'd\'impots tout en ameliorant votre retraite.',
      action: 'Simuler un rachat LPP',
      estimatedImpactChf: impact,
      source: 'LPP art. 79b',
      icon: Icons.account_balance,
    ));
  }

  /// d) Tax declaration deadline (March 31 for most cantons).
  static void _checkTaxDeadline(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    final now = DateTime.now();
    // Active from January to March
    if (now.month < 1 || now.month > 3) return;

    // Some cantons have different deadlines, but March 31 is the default.
    final deadline = DateTime(now.year, 3, 31);
    final daysLeft = deadline.difference(now).inDays;
    if (daysLeft < 0) return;

    tips.add(CoachingTip(
      id: 'tax_deadline',
      category: 'fiscalite',
      priority: daysLeft <= 14
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'Declaration d\'impots a rendre',
      message:
          'Le delai pour votre declaration fiscale dans le canton de '
          '${profile.canton} est le 31 mars. Il reste $daysLeft jours. '
          'Pensez a rassembler vos attestations 3a, certificats LPP, '
          'frais effectifs et dons deductibles.',
      action: 'Voir ma checklist fiscale',
      estimatedImpactChf: null,
      source: 'LIFD / LHID — delai cantonal',
      icon: Icons.description_outlined,
    ));
  }

  /// e) Retirement countdown (age >= 50).
  static void _checkRetirementCountdown(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.age < 50) return;

    final yearsLeft = _ageRetraite - profile.age;
    if (yearsLeft <= 0) return;

    final priority =
        yearsLeft <= 5 ? CoachingPriority.haute : CoachingPriority.moyenne;

    tips.add(CoachingTip(
      id: 'retirement_countdown',
      category: 'retraite',
      priority: priority,
      title: 'Retraite dans $yearsLeft ans',
      message:
          'A $yearsLeft ans de la retraite, il est important de verifier '
          'votre strategie de prevoyance. Avez-vous optimise vos rachats '
          'LPP ? Vos comptes 3a sont-ils diversifies ? Rente ou capital : '
          'avez-vous fait votre choix ?',
      action: 'Planifier ma retraite',
      estimatedImpactChf: null,
      source: 'LAVS art. 21 / LPP',
      icon: Icons.beach_access_outlined,
    ));
  }

  /// f) Emergency fund: less than 3 months of charges.
  static void _checkEmergencyFund(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.chargesFixesMensuelles <= 0) return;
    final monthsCovered = profile.epargneDispo / profile.chargesFixesMensuelles;
    if (monthsCovered >= 3) return;

    final deficit =
        (3 * profile.chargesFixesMensuelles) - profile.epargneDispo;

    tips.add(CoachingTip(
      id: 'emergency_fund',
      category: 'budget',
      priority: monthsCovered < 1
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'Reserve d\'urgence insuffisante',
      message:
          'Votre epargne disponible couvre ${monthsCovered.toStringAsFixed(1)} '
          'mois de charges fixes. Les experts recommandent au moins 3 mois. '
          'Il vous manque environ ${_formatChf(deficit)} pour atteindre '
          'ce seuil de securite.',
      action: 'Voir mon budget',
      estimatedImpactChf: deficit,
      source: 'Recommandation Budget-conseil Suisse',
      icon: Icons.shield_outlined,
    ));
  }

  /// g) Debt ratio > 33%.
  static void _checkDebtRatio(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.revenuAnnuel <= 0) return;
    if (profile.detteTotale <= 0) return;

    final revenuMensuel = profile.revenuAnnuel / 12;
    // Approximate debt service: assume 3% annual + amortization over 20y
    final serviceDette = profile.detteTotale * (0.03 + 1 / 20) / 12;
    final ratio = serviceDette / revenuMensuel;

    if (ratio <= 0.33) return;

    final ratioPct = (ratio * 100).toStringAsFixed(0);

    tips.add(CoachingTip(
      id: 'debt_ratio',
      category: 'budget',
      priority: ratio > 0.50
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'Taux d\'endettement eleve ($ratioPct%)',
      message:
          'Votre taux d\'endettement estime est de $ratioPct%, '
          'au-dessus du seuil de 33% recommande par les banques suisses. '
          'Reduire vos dettes ameliore votre capacite d\'emprunt et '
          'votre tranquillite financiere.',
      action: 'Analyser mes dettes',
      estimatedImpactChf: null,
      source: 'Directives FINMA / pratique bancaire',
      icon: Icons.warning_amber_rounded,
    ));
  }

  /// h) Age milestones.
  static void _checkAgeMilestones(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (!_ageMilestones.contains(profile.age)) return;

    final milestone = _getMilestoneMessage(profile.age);
    if (milestone == null) return;

    tips.add(CoachingTip(
      id: 'age_milestone_${profile.age}',
      category: 'prevoyance',
      priority: profile.age >= 50
          ? CoachingPriority.moyenne
          : CoachingPriority.basse,
      title: milestone.title,
      message: milestone.message,
      action: milestone.action,
      estimatedImpactChf: null,
      source: milestone.source,
      icon: Icons.cake_outlined,
    ));
  }

  /// i) Part-time gap alert.
  static void _checkPartTimeGap(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.tauxActivite >= 100) return;
    if (profile.tauxActivite <= 0) return;

    // Estimate the prevoyance gap: reduced LPP contributions
    final tauxPct = profile.tauxActivite.toStringAsFixed(0);
    final reductionPct = (100 - profile.tauxActivite).toStringAsFixed(0);

    // Rough estimate: LPP contribution gap
    final salaireCoordonne = (profile.revenuAnnuel - 25725).clamp(0, 62475);
    final cotisLppAnnuelle = salaireCoordonne * 0.15; // ~15% average
    final cotisPleinTemps =
        (profile.revenuAnnuel / (profile.tauxActivite / 100) - 25725)
                .clamp(0, 62475) *
            0.15;
    final gap = cotisPleinTemps - cotisLppAnnuelle;

    tips.add(CoachingTip(
      id: 'part_time_gap',
      category: 'prevoyance',
      priority: profile.tauxActivite < 60
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'Temps partiel : lacune de prevoyance',
      message:
          'A $tauxPct% d\'activite, votre prevoyance professionnelle est '
          'reduite d\'environ $reductionPct%. La deduction de coordination '
          'de CHF 25\'725 penalise davantage les temps partiels. '
          'Envisagez un rachat LPP ou un versement 3a supplementaire '
          'pour compenser.',
      action: 'Simuler ma prevoyance',
      estimatedImpactChf: gap > 0 ? gap : null,
      source: 'LPP art. 8 / OPP2 art. 5',
      icon: Icons.schedule,
    ));
  }

  /// j) Independent alert: no mandatory LPP.
  static void _checkIndependentAlert(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.employmentStatus != EmploymentStatus.independant) return;

    final plafond3a = _plafond3aIndependant;
    final tauxMarginal = _getTauxMarginal(profile.canton);
    final impact = plafond3a * tauxMarginal;

    tips.add(CoachingTip(
      id: 'independant_alert',
      category: 'prevoyance',
      priority: CoachingPriority.haute,
      title: 'Independant : pas de LPP obligatoire',
      message:
          'En tant qu\'independant, vous n\'etes pas soumis a la LPP '
          'obligatoire. Votre prevoyance repose sur l\'AVS et votre 3e '
          'pilier (plafond ${_formatChf(plafond3a)}). Pensez a une '
          'affiliation volontaire a une caisse de pension ou a maximiser '
          'votre 3a.',
      action: 'Explorer mes options',
      estimatedImpactChf: impact,
      source: 'LPP art. 4 / LAVS',
      icon: Icons.business_center_outlined,
    ));
  }

  /// k) Budget missing.
  static void _checkBudgetMissing(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (profile.hasBudget) return;

    tips.add(CoachingTip(
      id: 'budget_missing',
      category: 'budget',
      priority: CoachingPriority.moyenne,
      title: 'Pas encore de budget',
      message:
          'Un budget structure est la base de toute strategie financiere. '
          'Il permet d\'identifier votre capacite d\'epargne reelle et '
          'de fixer des objectifs concrets. MINT peut vous aider a en '
          'creer un en quelques minutes.',
      action: 'Creer mon budget',
      estimatedImpactChf: null,
      source: 'Recommandation Budget-conseil Suisse',
      icon: Icons.pie_chart_outline,
    ));
  }

  /// l) 3a contribution not maxed out.
  static void _check3aNotMaxed(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    if (!profile.has3a) return; // covered by missing_3a check
    final now = DateTime.now();
    // Only trigger outside Oct–Dec window (already covered by deadline check)
    if (now.month >= 10 && now.month <= 12) return;

    final plafond = profile.employmentStatus == EmploymentStatus.independant
        ? _plafond3aIndependant
        : _plafond3aSalarie;
    final restant = plafond - profile.montant3a;
    if (restant <= 0) return;

    final tauxMarginal = _getTauxMarginal(profile.canton);
    final impact = restant * tauxMarginal;

    tips.add(CoachingTip(
      id: '3a_not_maxed',
      category: 'fiscalite',
      priority: CoachingPriority.basse,
      title: 'Plafond 3a non atteint',
      message:
          'Votre versement 3a actuel est de ${_formatChf(profile.montant3a)} '
          'sur un plafond de ${_formatChf(plafond)}. Verser le solde de '
          '${_formatChf(restant)} pourrait representer une economie fiscale '
          'd\'environ ${_formatChf(impact)}.',
      action: 'Simuler mon 3a',
      estimatedImpactChf: impact,
      source: 'OPP3 art. 7',
      icon: Icons.trending_up,
    ));
  }

  // ──────────────────────────────────────────────────────────
  //  Age milestone messages
  // ──────────────────────────────────────────────────────────

  static _MilestoneInfo? _getMilestoneMessage(int age) {
    switch (age) {
      case 25:
        return const _MilestoneInfo(
          title: '25 ans : demarrer son 3e pilier',
          message:
              'A 25 ans, c\'est le moment ideal pour ouvrir un 3e pilier. '
              'Grace aux interets composes, chaque annee compte. '
              'Meme un petit versement mensuel fait une grande difference '
              'sur 40 ans.',
          action: 'Simuler les interets composes',
          source: 'OPP3 / Recommandation pedagogique',
        );
      case 35:
        return const _MilestoneInfo(
          title: '35 ans : faire le point prevoyance',
          message:
              'A 35 ans, verifiez que votre prevoyance est sur la bonne '
              'trajectoire. Avez-vous un 3a ? Votre LPP est-elle '
              'suffisante ? C\'est aussi l\'age ou un rachat LPP '
              'commence a devenir interessant fiscalement.',
          action: 'Faire mon bilan prevoyance',
          source: 'LPP / Recommandation pedagogique',
        );
      case 45:
        return const _MilestoneInfo(
          title: '45 ans : optimiser sa strategie',
          message:
              'A 45 ans, il reste 20 ans avant la retraite. C\'est le '
              'moment d\'optimiser : maximiser le 3a, envisager des '
              'rachats LPP, et diversifier. Chaque franc investi '
              'aujourd\'hui a encore du temps pour fructifier.',
          action: 'Optimiser ma strategie',
          source: 'LPP art. 79b / Recommandation pedagogique',
        );
      case 50:
        return const _MilestoneInfo(
          title: '50 ans : preparer sa retraite',
          message:
              'A 50 ans, la retraite se rapproche. Verifiez votre avoir '
              'LPP, planifiez vos derniers rachats, et commencez a '
              'reflechir au choix rente vs capital. Anticipez aussi '
              'l\'impact fiscal du retrait.',
          action: 'Planifier ma retraite',
          source: 'LPP / LAVS art. 21',
        );
      case 55:
        return const _MilestoneInfo(
          title: '55 ans : derniere ligne droite',
          message:
              'A 55 ans, la planification fiscale du retrait devient '
              'cruciale. Echelonner les retraits 3a sur plusieurs annees '
              'fiscales peut representer une economie significative. '
              'Preparez votre strategie de decumulation.',
          action: 'Planifier mes retraits',
          source: 'LPP / LIFD art. 38',
        );
      case 58:
        return const _MilestoneInfo(
          title: '58 ans : retraite anticipee possible',
          message:
              'Des 58 ans, vous pouvez envisager un retrait anticipe de '
              'votre 2e pilier dans certaines caisses. Attention : la '
              'rente sera reduite (environ 6% par annee d\'anticipation). '
              'Evaluez l\'impact sur votre budget.',
          action: 'Simuler ma retraite anticipee',
          source: 'LPP art. 13 al. 2',
        );
      case 63:
        return const _MilestoneInfo(
          title: '63 ans : derniers ajustements',
          message:
              'A 2 ans de la retraite legale, finalisez votre strategie. '
              'Dernier rachat LPP (attention au delai de 3 ans avant '
              'retrait), choix rente/capital, et organisation du '
              'budget post-retraite.',
          action: 'Finaliser ma preparation',
          source: 'LPP art. 79b al. 3',
        );
      default:
        return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────────────────

  /// Get the estimated marginal tax rate for a canton.
  static double _getTauxMarginal(String canton) {
    return _tauxMarginalCantonal[canton.toUpperCase()] ?? 0.33;
  }

  /// Format a CHF amount with Swiss apostrophe separator.
  static String formatChf(double value) {
    return _formatChf(value);
  }

  /// Format CHF with Swiss apostrophe (private).
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

  /// Build a demo profile for preview mode.
  static CoachingProfile buildDemoProfile() {
    return const CoachingProfile(
      age: 35,
      canton: 'VD',
      revenuAnnuel: 85000,
      has3a: false,
      montant3a: 0,
      hasLpp: true,
      avoirLpp: 95000,
      lacuneLpp: 42000,
      tauxActivite: 100,
      chargesFixesMensuelles: 3800,
      epargneDispo: 8500,
      detteTotale: 0,
      hasBudget: false,
      employmentStatus: EmploymentStatus.salarie,
      etatCivil: EtatCivil.celibataire,
    );
  }
}

/// Internal helper for milestone data.
class _MilestoneInfo {
  final String title;
  final String message;
  final String action;
  final String source;

  const _MilestoneInfo({
    required this.title,
    required this.message,
    required this.action,
    required this.source,
  });
}
