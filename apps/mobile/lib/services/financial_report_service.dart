import 'dart:math' show pow;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

import '../models/financial_report.dart';
import '../models/circle_score.dart';
import 'circle_scoring_service.dart';

/// Service de génération du rapport financier exhaustif
class FinancialReportService {
  final CircleScoringService _scoringService = CircleScoringService();

  /// Génère le rapport complet à partir des réponses du wizard
  FinancialReport generateReport(Map<String, dynamic> answers, {S? l}) {
    // 1. Profil utilisateur
    final profile = _buildUserProfile(answers);

    // 2. Score de santé financière
    final healthScore = _scoringService.calculateScore(answers);

    // 3. Simulation fiscale
    final taxSim = _buildTaxSimulation(answers, profile);

    // 4. Projection retraite (si données suffisantes)
    final retirementProj = _buildRetirementProjection(answers, profile);

    // 5. Analyse 3a (si applicable)
    final pillar3aAnalysis = _build3aAnalysis(answers, profile);

    // 6. Stratégie rachat LPP (si applicable)
    final lppStrategy = _buildLppStrategy(answers, profile);

    // 7. Actions prioritaires (top 3 from scoring) — enrichies avec gains calculés
    final priorityActions = _buildPriorityActions(
      healthScore,
      taxSim: taxSim,
      lppStrategy: lppStrategy,
      pillar3aAnalysis: pillar3aAnalysis,
      l: l,
    );

    // 8. Roadmap personnalisée
    final roadmap = _buildRoadmap(healthScore, answers, profile, l: l);

    // 9. Sources juridiques par cercle
    final sources = _buildJuridicalSources(healthScore);

    // 10. Disclaimers dynamiques
    final disclaimers = _buildDisclaimers(
      taxSim: taxSim,
      retirementProj: retirementProj,
      lppStrategy: lppStrategy,
      l: l,
    );

    return FinancialReport(
      profile: profile,
      healthScore: healthScore,
      taxSimulation: taxSim,
      retirementProjection: retirementProj,
      pillar3aAnalysis: pillar3aAnalysis,
      lppBuybackStrategy: lppStrategy,
      priorityActions: priorityActions,
      personalizedRoadmap: roadmap,
      disclaimers: disclaimers,
      sources: sources,
      generatedAt: DateTime.now(),
      reportVersion: '2.0',
    );
  }

  /// Construit la liste des sources juridiques en fonction des cercles activés
  List<String> _buildJuridicalSources(FinancialHealthScore healthScore) {
    final sources = <String>[];

    // Cercle 1 — Protection / dette / urgence
    if (healthScore.circle1Protection.items.isNotEmpty) {
      sources.add('LP art. 93 — Minimum vital');
      sources.add('Directives CSIAS');
    }

    // Cercle 2 — Prévoyance / LPP / AVS / 3a
    if (healthScore.circle2Prevoyance.items.isNotEmpty) {
      sources.add('LPP art. 14 — Taux de conversion');
      sources.add('OPP3 — 3e pilier');
      sources.add('LAVS — Rentes');
    }

    // Cercle 3 — Croissance / investissement / fiscalité
    if (healthScore.circle3Croissance.items.isNotEmpty) {
      sources.add('LIFD art. 33 — Déductions fiscales');
    }

    // Cercle 4 — Optimisation / succession / assurance
    if (healthScore.circle4Optimisation.items.isNotEmpty) {
      sources.add('CC art. 470 — Réserves héréditaires');
      sources.add('LIFD — Impôt fédéral');
    }

    return sources;
  }

  /// Construit la liste des disclaimers dynamiques selon les simulations actives
  List<String> _buildDisclaimers({
    required TaxSimulation taxSim,
    RetirementProjection? retirementProj,
    LppBuybackStrategy? lppStrategy,
    S? l,
  }) {
    final disclaimers = <String>[
      l?.reportDisclaimerBase1 ?? 'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin.',
      l?.reportDisclaimerBase2 ?? 'Les montants sont des estimations basées sur les données déclarées.',
      l?.reportDisclaimerBase3 ?? 'Les performances passées ne préjugent pas des performances futures.',
    ];

    // Disclaimer fiscal (toujours présent car taxSim est required)
    if (taxSim.totalTax > 0) {
      disclaimers.add(
        l?.reportDisclaimerFiscal ?? 'L\'estimation fiscale est approximative et ne remplace pas une déclaration d\'impôts.',
      );
    }

    // Disclaimer retraite
    if (retirementProj != null) {
      disclaimers.add(
        l?.reportDisclaimerRetraite ?? 'La projection retraite est indicative et dépend de l\'évolution législative (réformes AVS/LPP).',
      );
    }

    // Disclaimer rachat LPP
    if (lppStrategy != null) {
      disclaimers.add(
        l?.reportDisclaimerRachatLpp ?? 'Le rachat LPP est soumis à un blocage de 3 ans pour les retraits EPL (LPP art. 79b al. 3).',
      );
    }

    return disclaimers;
  }

  UserProfile _buildUserProfile(Map<String, dynamic> answers) {
    final birthYear = _parseInt(answers['q_birth_year']) ?? DateTime.now().year - 40;
    return UserProfile(
      firstName: answers['q_firstname'] as String?,
      birthYear: birthYear,
      canton: answers['q_canton'] as String? ?? 'ZH',
      civilStatus: answers['q_civil_status'] as String? ?? 'single',
      childrenCount: _parseInt(answers['q_children']) ?? 0,
      employmentStatus: answers['q_employment_status'] as String? ?? 'employee',
      monthlyNetIncome:
          _parseDouble(answers['q_net_income_period_chf']) ?? 5000,
      // Nouvelle logique AVS (triage lacunes)
      avsGapYears: _calculateAvsGaps(answers, birthYear),
      spouseAvsGapYears: _calculateSpouseAvsGaps(answers, birthYear),
      // Legacy fallback
      contributionYears: _parseInt(answers['q_avs_contribution_years']),
      spouseContributionYears:
          _parseInt(answers['q_spouse_avs_contribution_years']),
      firstEmploymentYear: _parseInt(answers['q_first_employment_year']),
      spouseFirstEmploymentYear:
          _parseInt(answers['q_spouse_first_employment_year']),
    );
  }

  /// Calcule les lacunes AVS depuis les nouvelles questions de triage.
  int? _calculateAvsGaps(Map<String, dynamic> answers, int birthYear) {
    final status = answers['q_avs_lacunes_status'];
    if (status == null) return null;
    switch (status) {
      case 'no_gaps':
        return 0;
      case 'arrived_late':
        final arrivalYear = _parseInt(answers['q_avs_arrival_year']);
        if (arrivalYear == null) return null;
        return (arrivalYear - (birthYear + 21)).clamp(0, 44);
      case 'lived_abroad':
        return _parseInt(answers['q_avs_years_abroad']) ?? 0;
      case 'unknown':
        return null;
      default:
        return null;
    }
  }

  int? _calculateSpouseAvsGaps(Map<String, dynamic> answers, int birthYear) {
    final status = answers['q_spouse_avs_lacunes_status'];
    if (status == null) return null;
    switch (status) {
      case 'no_gaps':
        return 0;
      case 'arrived_late':
        final arrivalYear = _parseInt(answers['q_spouse_avs_arrival_year']);
        if (arrivalYear == null) return null;
        return (arrivalYear - (birthYear + 21)).clamp(0, 44);
      case 'lived_abroad':
        return _parseInt(answers['q_spouse_avs_years_abroad']) ?? 0;
      case 'unknown':
        return null;
      default:
        return null;
    }
  }

  TaxSimulation _buildTaxSimulation(
      Map<String, dynamic> answers, UserProfile profile) {
    final annualIncome = profile.annualIncome;

    // Déductions
    final deductions = <String, double>{};

    // 3a
    final contribution3a =
        _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    if (contribution3a > 0) {
      deductions['3a'] = contribution3a;
    }

    // LPP rachat (si année en cours)
    final lppBuyback = _parseDouble(answers['q_lpp_buyback_current_year']) ?? 0;
    if (lppBuyback > 0) {
      deductions['Rachat LPP'] = lppBuyback;
    }

    // Enfants
    if (profile.hasChildren) {
      deductions['Déduction enfants'] = profile.childrenCount * 6500.0;
    }

    final taxableIncome =
        annualIncome - deductions.values.fold(0.0, (sum, val) => sum + val);

    // Estimation fiscale simplifiée (à raffiner avec service dédié)
    final effectiveRate = _estimateEffectiveRate(
        taxableIncome, profile.canton, profile.isMarried);
    final totalTax = taxableIncome * effectiveRate;
    // Approximation: ~75% of Swiss income tax is cantonal+communal, ~25% federal.
    // A precise split requires FiscalService per canton; acceptable for report overview.
    final cantonalTax = totalTax * 0.75;
    final federalTax = totalTax * 0.25;

    // Simulation avec rachat LPP (si montant disponible)
    final lppBuybackAvailable =
        _parseDouble(answers['q_lpp_buyback_available']) ?? 0;
    double? taxWithBuyback;
    double? savings;

    if (lppBuybackAvailable > 50000) {
      const buybackAmount = 50000.0; // 1ère tranche recommandée
      final taxableWithBuyback = taxableIncome - buybackAmount;
      final rateWithBuyback = _estimateEffectiveRate(
          taxableWithBuyback, profile.canton, profile.isMarried);
      taxWithBuyback = taxableWithBuyback * rateWithBuyback;
      savings = totalTax - taxWithBuyback;
    }

    return TaxSimulation(
      taxableIncome: taxableIncome,
      deductions: deductions,
      cantonalTax: cantonalTax,
      federalTax: federalTax,
      totalTax: totalTax,
      effectiveRate: effectiveRate,
      taxWithLppBuyback: taxWithBuyback,
      taxSavingsFromBuyback: savings,
    );
  }

  RetirementProjection? _buildRetirementProjection(
      Map<String, dynamic> answers, UserProfile profile) {
    if (profile.yearsToRetirement <= 0) return null;

    // Capital LPP estimé (simplifié - à raffiner)
    final currentLppCapital =
        _parseDouble(answers['q_current_lpp_capital']) ?? 0;
    final lppBuybacks = _parseDouble(answers['q_lpp_buyback_available']) ?? 0;
    // Year-by-year LPP growth using real age-band bonification rates (LPP art. 16)
    double estimatedLppGrowth = 0;
    // Note: LPP art. 8 uses gross insured salary; monthlyNetIncome is net.
    // Inverse: net → gross via NetIncomeBreakdown.estimateBrutFromNet
    final annualGrossApprox = NetIncomeBreakdown.estimateBrutFromNet(
      profile.monthlyNetIncome * 12,
      age: profile.age,
    );
    // Use LPP constants for coordinated salary (LPP art. 8)
    // Guard: if gross < seuil d'accès LPP (22'680), no LPP coverage
    final double coordinatedSalary;
    if (annualGrossApprox < reg('lpp.entry_threshold', lppSeuilEntree)) {
      coordinatedSalary = 0.0; // Not eligible for LPP
    } else {
      coordinatedSalary = (annualGrossApprox - reg('lpp.coordination_deduction', lppDeductionCoordination))
          .clamp(reg('lpp.min_coordinated_salary', lppSalaireCoordMin), reg('lpp.max_coordinated_salary', lppSalaireCoordMax));
    }
    final refAgeReport = reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    for (int year = 0; year < profile.yearsToRetirement; year++) {
      final ageThisYear = profile.age + year;
      if (ageThisYear >= 25 && ageThisYear <= refAgeReport) {
        final rate = getLppBonificationRate(ageThisYear);
        estimatedLppGrowth += coordinatedSalary * rate;
      }
    }
    final lppCapital = currentLppCapital + estimatedLppGrowth + lppBuybacks;

    // Capital 3a (projection simplifiée à 3% rendement)
    final contribution3a =
        _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final pillar3aCapital =
        _futureValue(contribution3a, 0.03, profile.yearsToRetirement);

    // Rentes
    final monthlyAvsRent = _estimateAvsRent(profile);
    // LPP art. 14: 6.8% minimum légal sur part obligatoire uniquement.
    // Financial report is a simplified view without certificate data access.
    // Use surobligatoire estimate (5.4%) as conservative educational default
    // rather than 6.8% which overstates for most caisses.
    final monthlyLppRent = (lppCapital * reg('lpp.conversion_rate_suroblig', lppTauxConversionSurobligDecimal)) / 12;

    return RetirementProjection(
      yearsUntilRetirement: profile.yearsToRetirement,
      lppCapital: lppCapital,
      pillar3aCapital: pillar3aCapital,
      monthlyAvsRent: monthlyAvsRent,
      monthlyLppRent: monthlyLppRent,
      avsReductionFactor: profile.avsReductionFactor,
      spouseAvsReductionFactor: profile.spouseAvsReductionFactor,
      currentMonthlyIncome: profile.monthlyNetIncome,
    );
  }

  Pillar3aAnalysis? _build3aAnalysis(
      Map<String, dynamic> answers, UserProfile profile) {
    final nb3aAccounts = _parseInt(answers['q_3a_accounts_count']) ?? 0;
    if (nb3aAccounts == 0) return null;

    // q_3a_providers est une List (multiChoice)
    final providers =
        (answers['q_3a_providers'] as List?)?.cast<String>() ?? ['bank'];

    final contribution = _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final maxContribution = profile.isSalaried ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) : reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp);

    // Projections par provider (simplifié)
    final projections = <String, double>{
      'bank':
          _futureValue(contribution, 0.015, profile.yearsToRetirement), // 1.5%
      'fintech':
          _futureValue(contribution, 0.045, profile.yearsToRetirement), // 4.5%
      'fintech_low_fee':
          _futureValue(contribution, 0.055, profile.yearsToRetirement), // 5.5%
      'insurance':
          _futureValue(contribution, 0.01, profile.yearsToRetirement), // 1%
    };

    final potentialGain = projections['fintech']! - projections['bank']!;

    // Optimisation retrait (si multiple comptes)
    double? taxSingle;
    double? taxMultiple;
    double? savingsMultiple;

    if (nb3aAccounts == 1 && projections['fintech']! > 100000) {
      final totalCapital = projections['fintech']!;
      taxSingle = totalCapital * 0.08; // ~ 8% impôt capital Swiss moyenne
      taxMultiple =
          (totalCapital / 2) * 0.05 * 2; // Échelonné sur 2 ans = taux plus bas
      savingsMultiple = taxSingle - taxMultiple;
    }

    return Pillar3aAnalysis(
      currentAccountsCount: nb3aAccounts,
      providers: providers,
      annualContribution: contribution,
      maxContribution: maxContribution,
      projectionsByProvider: projections,
      potentialGainVsBank: potentialGain,
      taxOnWithdrawalSingleAccount: taxSingle,
      taxOnWithdrawalMultipleAccounts: taxMultiple,
      withdrawalOptimizationSavings: savingsMultiple,
    );
  }

  LppBuybackStrategy? _buildLppStrategy(
      Map<String, dynamic> answers, UserProfile profile) {
    final buybackAvailable =
        _parseDouble(answers['q_lpp_buyback_available']) ?? 0;
    if (buybackAvailable < 10000) return null;

    final yearsToRetirement = profile.yearsToRetirement;
    final isMarried = profile.civilStatus == 'marie';
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
        profile.annualIncome, profile.canton,
        isMarried: isMarried, children: profile.childrenCount);

    final plan = <AnnualBuyback>[];
    final currentYear = DateTime.now().year;

    // RÈGLE DES 3 ANS : Si retrait capital prévu, finir rachats AVANT (retraite - 3 ans)
    // Stratégie optimale : Racheter dans les dernières années pré-retraite pour max l'effet fiscal

    int startYear;
    int nbYears;
    String strategy;

    if (yearsToRetirement <= 3) {
      // URGENT : Moins de 3 ans avant retraite
      // Racheter MAINTENANT (mais attention règle 3 ans si retrait capital)
      startYear = currentYear;
      nbYears = yearsToRetirement.clamp(1, 3);
      strategy = 'urgent';
    } else if (yearsToRetirement <= 5) {
      // PROCHE : 3-5 ans avant retraite
      // Commencer maintenant, étaler sur années restantes
      startYear = currentYear;
      nbYears = 3;
      strategy = 'optimal_now';
    } else {
      // LOIN de la retraite (>5 ans)
      // Recommandation : ATTENDRE et faire rachats 3 ans avant retraite
      // Mais si besoin fiscal immédiat, étaler sur 3 ans maintenant
      final retirementYear = currentYear + yearsToRetirement;

      // Option 1 : Attendre (RECOMMANDÉ si pas besoin fiscal urgent)
      startYear = retirementYear - 5; // Commencer 5 ans avant retraite
      nbYears = 3; // Étaler sur 3 ans (de -5 à -2 ans avant retraite)
      strategy = 'wait_recommended';

      // Note: Si besoin fiscal urgent, on pourrait proposer un plan maintenant
      // mais ce n'est pas optimal fiscalement
    }

    // Calculer montant annuel optimal
    final yearlyAmount = (buybackAvailable / nbYears).roundToDouble();

    // Générer le plan année par année
    for (int i = 0; i < nbYears; i++) {
      final year = startYear + i;
      final amount = (i == nbYears - 1)
          ? (buybackAvailable - ((nbYears - 1) * yearlyAmount))
          : yearlyAmount;

      // Le taux marginal peut baisser si revenu baisse avec l'âge
      final yearMarginalRate = (strategy == 'wait_recommended')
          ? marginalRate * 0.95 // Légèrement plus bas dans le futur
          : marginalRate;

      plan.add(AnnualBuyback(
        year: year,
        amount: amount,
        estimatedTaxSavings: amount * yearMarginalRate,
      ));
    }

    final totalSavings =
        plan.fold(0.0, (sum, buy) => sum + buy.estimatedTaxSavings);

    return LppBuybackStrategy(
      totalBuybackAvailable: buybackAvailable,
      yearlyPlan: plan,
      totalTaxSavings: totalSavings,
    );
  }

  List<ActionItem> _buildPriorityActions(
    FinancialHealthScore healthScore, {
    TaxSimulation? taxSim,
    LppBuybackStrategy? lppStrategy,
    Pillar3aAnalysis? pillar3aAnalysis,
    S? l,
  }) {
    final actions = <ActionItem>[];

    // Extraire les top recommandations de chaque cercle
    for (final reco in healthScore.topPriorities) {
      final action = _parseRecommendationToAction(
        reco,
        taxSim: taxSim,
        lppStrategy: lppStrategy,
        pillar3aAnalysis: pillar3aAnalysis,
        l: l,
      );
      if (action != null) actions.add(action);
    }

    return actions.take(3).toList();
  }

  ActionItem? _parseRecommendationToAction(
    String recommendation, {
    TaxSimulation? taxSim,
    LppBuybackStrategy? lppStrategy,
    Pillar3aAnalysis? pillar3aAnalysis,
    S? l,
  }) {
    // Parsing basé sur keywords avec gains calculés à partir des données réelles
    if (recommendation.contains('premier compte 3a') || recommendation.contains('premier 3a')) {
      return ActionItem(
        title: l?.reportActionTitle3aFirst ?? 'Ouvre ton premier 3a',
        description: l?.reportActionDesc3aFirst ?? 'Déduis jusqu\'à CHF 7\'258/an de ton revenu imposable. Économie immédiate.',
        priority: ActionPriority.high,
        potentialGainChf: 1500,
        category: ActionCategory.pillar3a,
        steps: [
          '1. Compare les offres (fintech, banque)',
          '2. Ouvre ton compte en 10 minutes',
          '3. Configure un versement automatique',
          '4. Choisis une stratégie adaptée à ton horizon',
        ],
      );
    }

    if (recommendation.contains('2e compte 3a')) {
      // Gain réel : économie fiscale au retrait via échelonnement + rendement vs banque
      final gainVsBank = pillar3aAnalysis?.potentialGainVsBank;
      final withdrawalSavings = pillar3aAnalysis?.withdrawalOptimizationSavings;
      final totalGain = (gainVsBank ?? 0) + (withdrawalSavings ?? 0);
      final computedGain = totalGain > 0 ? totalGain : 12000.0;

      return ActionItem(
        title: l?.reportActionTitle3aSecond ?? 'Ouvre un 2e compte 3a fintech',
        description: l?.reportActionDesc3aSecond ??
            'Optimise ta fiscalité au retrait et diversifie tes placements.',
        priority: ActionPriority.high,
        potentialGainChf: computedGain,
        category: ActionCategory.pillar3a,
        steps: const [
          '1. Compare les prestataires 3a en ligne',
          '2. Crée ton compte (10 min)',
          '3. Choisis stratégie 60% actions',
          '4. Configure versement automatique',
        ],
      );
    }

    if (recommendation.contains('rachat LPP')) {
      // Gain réel : économie fiscale totale calculée par la stratégie LPP
      final computedGain = lppStrategy?.totalTaxSavings ?? 0;
      final displayGain = computedGain > 0 ? computedGain : 60000.0;
      final nbYears = lppStrategy?.yearlyPlan.length ?? 4;

      return ActionItem(
        title: 'Planifie ton rachat LPP échelonné',
        description:
            'Économise jusqu\'à CHF ${displayGain.toStringAsFixed(0)} d\'impôts sur $nbYears ans.',
        priority: ActionPriority.critical,
        potentialGainChf: displayGain,
        category: ActionCategory.lpp,
        steps: const [
          '1. Demande certificat LPP à ta caisse',
          '2. Vérifie montant rachetable exact',
          '3. Planifie rachat échelonné avant retraite',
          '4. Effectue 1er rachat avant 31 décembre',
        ],
      );
    }

    if (recommendation.contains('AVS')) {
      return ActionItem(
        title: l?.reportActionTitleAvsCheck ?? 'Vérifie ton compte AVS',
        description: l?.reportActionDescAvsCheck ?? 'Évite de perdre jusqu\'à 38\'000 CHF de rente à vie.',
        priority: ActionPriority.high,
        category: ActionCategory.avs,
        steps: [
          '1. Commande extrait gratuit sur ahv-iv.ch',
          '2. Vérifie les années de cotisation',
          '3. Si lacunes : cotisations volontaires possibles',
        ],
      );
    }

    if (recommendation.contains('dette') || recommendation.contains('crédit')) {
      return ActionItem(
        title: l?.reportActionTitleDette ?? 'Rembourse tes dettes de consommation',
        description: l?.reportActionDescDette ??
            'C\'est le placement le plus rentable : tu économises 6-10% par an sur les intérêts.',
        priority: ActionPriority.critical,
        potentialGainChf: 2000,
        category: ActionCategory.protection,
        steps: [
          '1. Liste toutes tes dettes (Montant, Taux)',
          '2. Attaque celle avec le plus haut taux',
          '3. Arrête tout nouvel investissement',
        ],
      );
    }

    if (recommendation.toLowerCase().contains('urgence')) {
      return ActionItem(
        title: l?.reportActionTitleUrgence ?? 'Constitue ton fonds d\'urgence',
        description: l?.reportActionDescUrgence ?? 'Vise 3 mois de charges sur un compte épargne séparé.',
        priority: ActionPriority.critical,
        category: ActionCategory.protection,
        steps: [
          '1. Ouvre un compte épargne gratuit (ex: Zak, Neon)',
          '2. Mets en place un virement auto (ex 10% salaire)',
          '3. Ne touche pas à cet argent sauf urgence',
        ],
      );
    }

    return null;
  }

  Roadmap _buildRoadmap(FinancialHealthScore healthScore,
      Map<String, dynamic> answers, UserProfile profile, {S? l}) {
    return Roadmap(phases: [
      RoadmapPhase(
        title: l?.reportRoadmapPhaseImmediat ?? 'Immédiat',
        timeframe: l?.reportRoadmapTimeframeImmediat ?? 'Ce mois',
        actions: _buildPriorityActions(healthScore, l: l)
            .where((a) =>
                a.priority == ActionPriority.critical ||
                a.priority == ActionPriority.high)
            .toList(),
      ),
      RoadmapPhase(
        title: l?.reportRoadmapPhaseCourtTerme ?? 'Court Terme',
        timeframe: l?.reportRoadmapTimeframeCourtTerme ?? '3-6 mois',
        actions: const [], // À compléter selon contexte
      ),
    ]);
  }

  // ===== HELPERS =====

  double _estimateEffectiveRate(
      double taxableIncome, String canton, bool isMarried) {
    // Delegate to centralized marginal rate estimator (financial_core).
    // RetirementTaxCalculator.estimateMarginalRate accounts for canton grouping
    // and income-level brackets (AFC taux marginaux 2025).
    final marginalRate =
        RetirementTaxCalculator.estimateMarginalRate(taxableIncome, canton);
    // Married couples benefit from splitting (~15% reduction, cf. LIFD art. 36).
    return isMarried ? marginalRate * 0.85 : marginalRate;
  }

  double _estimateAvsRent(UserProfile profile) {
    // Delegate to AvsCalculator for centralized AVS rente logic (LAVS art. 29, 34, 35).
    // Inverse: net → gross via NetIncomeBreakdown.estimateBrutFromNet
    final grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(
      profile.monthlyNetIncome * 12,
      age: profile.age,
    );

    final refAgeAvs = reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    // F6-2: isFemale/birthYear not passed — UserProfile (wizard answers) does not
    // capture gender. Defaults to male reference age (65). Acceptable for this
    // report-level estimate; gender-aware age is used in CoachProfile-based screens.
    final userRente = AvsCalculator.computeMonthlyRente(
      currentAge: profile.age,
      retirementAge: refAgeAvs,
      lacunes: profile.avsGapYears ?? 0,
      anneesContribuees: profile.contributionYears,
      grossAnnualSalary: grossAnnualSalary,
    );

    if (profile.isMarried) {
      // Spouse rente: use same gross salary assumption (no spouse salary available)
      // TODO: Accept spouse income for more accurate couple AVS computation.
      // F6-2: isFemale/birthYear not passed for spouse — UserProfile has no
      // spouse gender field. Defaults to male reference age. Same limitation
      // as user rente above (wizard answers model lacks gender).
      final spouseRente = AvsCalculator.computeMonthlyRente(
        currentAge: profile.age, // Approximate: same age assumed for spouse
        retirementAge: refAgeAvs,
        lacunes: profile.spouseAvsGapYears ?? 0,
        anneesContribuees: profile.spouseContributionYears,
        grossAnnualSalary: grossAnnualSalary,
      );

      // Apply married couple cap (LAVS art. 35 — 150% of individual max)
      final couple = AvsCalculator.computeCouple(
        avsUser: userRente,
        avsConjoint: spouseRente,
        isMarried: true,
      );
      return couple.total;
    } else {
      return userRente;
    }
  }

  double _futureValue(double annualPayment, double rate, int years) {
    if (rate == 0) return annualPayment * years;
    return annualPayment * ((pow(1 + rate, years.toDouble()) - 1) / rate);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
