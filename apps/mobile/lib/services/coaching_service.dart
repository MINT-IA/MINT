import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/rag_service.dart';

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

  /// Depenses exceptionnelles du dernier check-in (null si aucun check-in).
  final double? lastCheckInDepensesExceptionnelles;

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
    this.lastCheckInDepensesExceptionnelles,
  });
}

/// A single coaching tip.
class CoachingTip {
  final String id;
  final String category; // "fiscalite", "prevoyance", "budget", "retraite"
  final CoachingPriority priority;
  final String title;
  final String message; // original static message
  String? narrativeMessage; // LLM-enriched message (null if no BYOK)
  final String action; // call-to-action text
  final double? estimatedImpactChf;
  final String source; // legal/regulatory source reference
  final IconData icon;

  CoachingTip({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.message,
    this.narrativeMessage,
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

  /// 3a ceiling for salaried employees (2025/2026, OPP3 art. 7).
  static const double _plafond3aSalarie = 7258;

  /// 3a ceiling for self-employed without LPP (2025/2026, OPP3 art. 7).
  static const double _plafond3aIndependant = 36288;

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

    // m) Budget drift detection
    _checkBudgetDrift(profile, tips);

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

  /// Enrichit les 3 premiers tips avec des narrations LLM personnalisees.
  /// Si pas de BYOK, retourne les tips inchanges (zero regression).
  ///
  /// Le LLM recoit le tip original + le profil complet et genere un
  /// message narratif qui croise toutes les dimensions du profil
  /// (age, situation familiale, emploi, canton, chiffres specifiques).
  static Future<List<CoachingTip>> enrichTips({
    required List<CoachingTip> tips,
    required CoachingProfile profile,
    required String firstName,
    required String? apiKey,
    required String? provider,
    String? model,
  }) async {
    // If no BYOK, return tips unchanged
    if (apiKey == null || apiKey.isEmpty) return tips;
    if (tips.isEmpty) return tips;

    // Enrich only the top 3 tips (economy of tokens)
    final toEnrich = tips.take(3).toList();
    final ragService = RagService();

    for (final tip in toEnrich) {
      try {
        final prompt = _buildEnrichmentPrompt(tip, profile, firstName);

        final response = await ragService.query(
          question: prompt,
          apiKey: apiKey,
          provider: provider ?? 'openai',
          model: model,
          profileContext: {
            'age': profile.age,
            'canton': profile.canton,
            'financial_summary':
                _buildFinancialSummary(profile, firstName),
          },
        );

        // Apply guardrails (filter banned terms)
        final filtered = _filterBannedTerms(response.answer);
        if (filtered.isNotEmpty && filtered.length > 20) {
          tip.narrativeMessage = filtered;
        }
      } catch (_) {
        // Silently fail — keep original message (resilience)
      }
    }

    return tips;
  }

  // ──────────────────────────────────────────────────────────
  //  Enrichment helpers (private)
  // ──────────────────────────────────────────────────────────

  static String _buildEnrichmentPrompt(
    CoachingTip tip,
    CoachingProfile profile,
    String firstName,
  ) {
    return '''
Tu es le coach MINT. Personnalise ce conseil pour $firstName :

TIP :
- Titre : ${tip.title}
- Message : ${tip.message}
- Impact : ${tip.estimatedImpactChf != null ? 'CHF ${tip.estimatedImpactChf!.toStringAsFixed(0)}' : 'non estime'}
- Source : ${tip.source}

PROFIL :
- Age : ${profile.age} ans
- Canton : ${profile.canton}
- Statut civil : ${profile.etatCivil.name}
- Emploi : ${profile.employmentStatus.name} (${profile.tauxActivite}%)
- Revenu annuel : CHF ${profile.revenuAnnuel.toStringAsFixed(0)}
- 3a : ${profile.has3a ? 'oui (CHF ${profile.montant3a.toStringAsFixed(0)})' : 'non'}
- LPP : avoir CHF ${profile.avoirLpp.toStringAsFixed(0)}, lacune CHF ${profile.lacuneLpp.toStringAsFixed(0)}
- Epargne dispo : CHF ${profile.epargneDispo.toStringAsFixed(0)}
- Dettes : CHF ${profile.detteTotale.toStringAsFixed(0)}
- Charges fixes : CHF ${profile.chargesFixesMensuelles.toStringAsFixed(0)}/mois

INSTRUCTIONS :
R\u00e9\u00e9cris le message en 3-4 phrases max. Personnalise en croisant la situation familiale, l'emploi, l'\u00e2ge et les chiffres. Tutoiement. Ton chaleureux et \u00e9ducatif. JAMAIS : garanti, certain, assur\u00e9, sans risque, optimal, meilleur, parfait. Retourne UNIQUEMENT le nouveau message.''';
  }

  static String _buildFinancialSummary(
    CoachingProfile profile,
    String firstName,
  ) {
    return '$firstName, ${profile.age} ans, ${profile.canton}, '
        '${profile.employmentStatus.name}, '
        'revenu CHF ${profile.revenuAnnuel.toStringAsFixed(0)}';
  }

  /// Filter banned terms from LLM output, replacing with safe alternatives.
  static String _filterBannedTerms(String text) {
    var result = text;
    const banned = [
      'garanti',
      'certain',
      'assuré',
      'assuree',
      'sans risque',
      'optimal',
      'meilleur',
      'parfait',
    ];
    const replacements = [
      'potentiel',
      'probable',
      'estime',
      'estimee',
      'a faible risque',
      'adapte',
      'pertinent',
      'solide',
    ];
    for (int i = 0; i < banned.length; i++) {
      result = result.replaceAll(
        RegExp(banned[i], caseSensitive: false),
        replacements[i],
      );
    }
    return result;
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
      title: 'Versement 3a avant le 31 décembre',
      message:
          'Il te reste ${_formatChf(restant)} de marge sur ton plafond 3a '
          '(${_formatChf(plafond)}). Un versement avant le 31 décembre '
          'pourrait réduire ta charge fiscale de ${_formatChf(impact)} '
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
      title: 'Tu n\'as pas de 3e pilier',
      message:
          'Ouvrir un 3e pilier te permettrait de déduire jusqu\'à '
          '${_formatChf(plafond)} de ton revenu imposable chaque année. '
          'L\'économie fiscale estimée est de ${_formatChf(impact)} par an '
          'dans le canton de ${profile.canton}.',
      action: 'Découvrir le 3e pilier',
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
          'Tu as une lacune de prévoyance de ${_formatChf(profile.lacuneLpp)}. '
          'Un rachat volontaire de ${_formatChf(rachatRecommande)} '
          'pourrait te faire économiser environ ${_formatChf(impact)} '
          'd\'impôts tout en améliorant ta retraite.',
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
      title: 'Déclaration d\'impôts à rendre',
      message:
          'Le délai pour ta déclaration fiscale dans le canton de '
          '${profile.canton} est le 31 mars. Il reste $daysLeft jours. '
          'Pense à rassembler tes attestations 3a, certificats LPP, '
          'frais effectifs et dons déductibles.',
      action: 'Voir ma checklist fiscale',
      estimatedImpactChf: null,
      source: 'LIFD / LHID — délai cantonal',
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
          'À $yearsLeft ans de la retraite, il est important de vérifier '
          'ta stratégie de prévoyance. As-tu optimisé tes rachats '
          'LPP ? Tes comptes 3a sont-ils diversifiés ? Rente ou capital : '
          'as-tu fait ton choix ?',
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
      title: 'Réserve d\'urgence insuffisante',
      message:
          'Ton épargne disponible couvre ${monthsCovered.toStringAsFixed(1)} '
          'mois de charges fixes. Les experts recommandent au moins 3 mois. '
          'Il te manque environ ${_formatChf(deficit)} pour atteindre '
          'ce seuil de sécurité.',
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
      title: 'Taux d\'endettement élevé ($ratioPct%)',
      message:
          'Ton taux d\'endettement estimé est de $ratioPct%, '
          'au-dessus du seuil de 33% recommandé par les banques suisses. '
          'Réduire tes dettes améliore ta capacité d\'emprunt et '
          'ta tranquillité financière.',
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
    final salaireCoordonne = (profile.revenuAnnuel - lppDeductionCoordination).clamp(0, lppSalaireCoordMax.toDouble());
    final cotisLppAnnuelle = salaireCoordonne * 0.15; // ~15% average
    final cotisPleinTemps =
        (profile.revenuAnnuel / (profile.tauxActivite / 100) - lppDeductionCoordination)
                .clamp(0, lppSalaireCoordMax.toDouble()) *
            0.15;
    final gap = cotisPleinTemps - cotisLppAnnuelle;

    tips.add(CoachingTip(
      id: 'part_time_gap',
      category: 'prevoyance',
      priority: profile.tauxActivite < 60
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'Temps partiel : lacune de prévoyance',
      message:
          'À $tauxPct% d\'activité, ta prévoyance professionnelle est '
          'réduite d\'environ $reductionPct%. La déduction de coordination '
          'de CHF 26\'460 pénalise davantage les temps partiels. '
          'Envisage un rachat LPP ou un versement 3a supplémentaire '
          'pour compenser.',
      action: 'Simuler ma prévoyance',
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
      title: 'Indépendant : pas de LPP obligatoire',
      message:
          'En tant qu\'indépendant, tu n\'es pas soumis à la LPP '
          'obligatoire. Ta prévoyance repose sur l\'AVS et ton 3e '
          'pilier (plafond ${_formatChf(plafond3a)}). Pense à une '
          'affiliation volontaire à une caisse de pension ou à maximiser '
          'ton 3a.',
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
          'Un budget structuré est la base de toute stratégie financière. '
          'Il permet d\'identifier ta capacité d\'épargne réelle et '
          'de fixer des objectifs concrets. MINT peut t\'aider à en '
          'créer un en quelques minutes.',
      action: 'Créer mon budget',
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
          'Ton versement 3a actuel est de ${_formatChf(profile.montant3a)} '
          'sur un plafond de ${_formatChf(plafond)}. Verser le solde de '
          '${_formatChf(restant)} pourrait représenter une économie fiscale '
          'd\'environ ${_formatChf(impact)}.',
      action: 'Simuler mon 3a',
      estimatedImpactChf: impact,
      source: 'OPP3 art. 7',
      icon: Icons.trending_up,
    ));
  }

  /// m) Budget drift: exceptional expenses > 20% of monthly income.
  static void _checkBudgetDrift(
    CoachingProfile profile,
    List<CoachingTip> tips,
  ) {
    final depExc = profile.lastCheckInDepensesExceptionnelles;
    if (depExc == null || depExc <= 0) return;

    final revenuMensuel = profile.revenuAnnuel / 12;
    if (revenuMensuel <= 0) return;

    final ratio = depExc / revenuMensuel;
    if (ratio <= 0.20) return;

    final ratioPct = (ratio * 100).toStringAsFixed(0);

    tips.add(CoachingTip(
      id: 'budget_drift',
      category: 'budget',
      priority: ratio > 0.40
          ? CoachingPriority.haute
          : CoachingPriority.moyenne,
      title: 'D\u00e9penses exceptionnelles \u00e9lev\u00e9es',
      message:
          'Tes d\u00e9penses exceptionnelles du dernier mois repr\u00e9sentent '
          '$ratioPct% de ton revenu mensuel (${_formatChf(depExc)}). '
          'V\u00e9rifie que ton budget reste sur les rails et ajuste '
          'si n\u00e9cessaire.',
      action: 'V\u00e9rifier mon budget',
      estimatedImpactChf: depExc,
      source: 'Recommandation Budget-conseil Suisse',
      icon: Icons.trending_down,
    ));
  }

  // ──────────────────────────────────────────────────────────
  //  Age milestone messages
  // ──────────────────────────────────────────────────────────

  static _MilestoneInfo? _getMilestoneMessage(int age) {
    switch (age) {
      case 25:
        return const _MilestoneInfo(
          title: '25 ans : démarrer son 3e pilier',
          message:
              'À 25 ans, c\'est le moment idéal pour ouvrir un 3e pilier. '
              'Grâce aux intérêts composés, chaque année compte. '
              'Même un petit versement mensuel fait une grande différence '
              'sur 40 ans.',
          action: 'Simuler les intérêts composés',
          source: 'OPP3 / Recommandation pédagogique',
        );
      case 35:
        return const _MilestoneInfo(
          title: '35 ans : faire le point prévoyance',
          message:
              'À 35 ans, vérifie que ta prévoyance est sur la bonne '
              'trajectoire. As-tu un 3a ? Ta LPP est-elle '
              'suffisante ? C\'est aussi l\'âge où un rachat LPP '
              'commence à devenir intéressant fiscalement.',
          action: 'Faire mon bilan prévoyance',
          source: 'LPP / Recommandation pédagogique',
        );
      case 45:
        return const _MilestoneInfo(
          title: '45 ans : optimiser sa stratégie',
          message:
              'À 45 ans, il reste 20 ans avant la retraite. C\'est le '
              'moment d\'optimiser : maximiser le 3a, envisager des '
              'rachats LPP, et diversifier. Chaque franc investi '
              'aujourd\'hui a encore du temps pour fructifier.',
          action: 'Optimiser ma stratégie',
          source: 'LPP art. 79b / Recommandation pédagogique',
        );
      case 50:
        return const _MilestoneInfo(
          title: '50 ans : préparer sa retraite',
          message:
              'À 50 ans, la retraite se rapproche. Vérifie ton avoir '
              'LPP, planifie tes derniers rachats, et commence à '
              'réfléchir au choix rente vs capital. Anticipe aussi '
              'l\'impact fiscal du retrait.',
          action: 'Planifier ma retraite',
          source: 'LPP / LAVS art. 21',
        );
      case 55:
        return const _MilestoneInfo(
          title: '55 ans : dernière ligne droite',
          message:
              'À 55 ans, la planification fiscale du retrait devient '
              'cruciale. Échelonner les retraits 3a sur plusieurs années '
              'fiscales peut représenter une économie significative. '
              'Prépare ta stratégie de décumulation.',
          action: 'Planifier mes retraits',
          source: 'LPP / LIFD art. 38',
        );
      case 58:
        return const _MilestoneInfo(
          title: '58 ans : retraite anticipée possible',
          message:
              'Dès 58 ans, tu peux envisager un retrait anticipé de '
              'ton 2e pilier dans certaines caisses. Attention : la '
              'rente sera réduite (environ 6% par année d\'anticipation). '
              'Évalue l\'impact sur ton budget.',
          action: 'Simuler ma retraite anticipée',
          source: 'LPP art. 13 al. 2',
        );
      case 63:
        return const _MilestoneInfo(
          title: '63 ans : derniers ajustements',
          message:
              'À 2 ans de la retraite légale, finalise ta stratégie. '
              'Dernier rachat LPP (attention au délai de 3 ans avant '
              'retrait), choix rente/capital, et organisation du '
              'budget post-retraite.',
          action: 'Finaliser ma préparation',
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
