import 'dart:math' show pow;

import '../models/financial_report.dart';
import '../models/circle_score.dart';
import 'circle_scoring_service.dart';

/// Service de génération du rapport financier exhaustif
class FinancialReportService {
  final CircleScoringService _scoringService = CircleScoringService();

  /// Génère le rapport complet à partir des réponses du wizard
  FinancialReport generateReport(Map<String, dynamic> answers) {
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

    // 7. Actions prioritaires (top 3 from scoring)
    final priorityActions = _buildPriorityActions(healthScore);

    // 8. Roadmap personnalisée
    final roadmap = _buildRoadmap(healthScore, answers, profile);

    return FinancialReport(
      profile: profile,
      healthScore: healthScore,
      taxSimulation: taxSim,
      retirementProjection: retirementProj,
      pillar3aAnalysis: pillar3aAnalysis,
      lppBuybackStrategy: lppStrategy,
      priorityActions: priorityActions,
      personalizedRoadmap: roadmap,
      generatedAt: DateTime.now(),
      reportVersion: '2.0',
    );
  }

  UserProfile _buildUserProfile(Map<String, dynamic> answers) {
    return UserProfile(
      firstName: answers['q_firstname'] as String?,
      birthYear: _parseInt(answers['q_birth_year']) ?? DateTime.now().year - 40,
      canton: answers['q_canton'] as String? ?? 'VD',
      civilStatus: answers['q_civil_status'] as String? ?? 'single',
      childrenCount: _parseInt(answers['q_children']) ?? 0,
      employmentStatus: answers['q_employment_status'] as String? ?? 'employee',
      monthlyNetIncome:
          _parseDouble(answers['q_net_income_period_chf']) ?? 5000,
    );
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
    final cantonalTax = totalTax * 0.75; // ~75% cantonal+communal
    final federalTax = totalTax * 0.25; // ~25% fédéral

    // Simulation avec rachat LPP (si montant disponible)
    final lppBuybackAvailable =
        _parseDouble(answers['q_lpp_buyback_available']) ?? 0;
    double? taxWithBuyback;
    double? savings;

    if (lppBuybackAvailable > 50000) {
      final buybackAmount = 50000.0; // 1ère tranche recommandée
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
    final estimatedLppGrowth = profile.monthlyNetIncome *
        0.15 *
        12 *
        profile.yearsToRetirement; // 15% cotisation
    final lppCapital = currentLppCapital + estimatedLppGrowth + lppBuybacks;

    // Capital 3a (projection simplifiée à 3% rendement)
    final contribution3a =
        _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final pillar3aCapital =
        _futureValue(contribution3a, 0.03, profile.yearsToRetirement);

    // Rentes
    final monthlyAvsRent = _estimateAvsRent(profile);
    final lppConversionRate = 0.06; // 6% taux conversion (hypothèse prudente)
    final monthlyLppRent = (lppCapital * lppConversionRate) / 12;

    return RetirementProjection(
      yearsUntilRetirement: profile.yearsToRetirement,
      lppCapital: lppCapital,
      pillar3aCapital: pillar3aCapital,
      monthlyAvsRent: monthlyAvsRent,
      monthlyLppRent: monthlyLppRent,
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
    final maxContribution = profile.isSalaried ? 7258.0 : 36288.0;

    // Projections par provider (simplifié)
    final projections = <String, double>{
      'bank':
          _futureValue(contribution, 0.015, profile.yearsToRetirement), // 1.5%
      'viac':
          _futureValue(contribution, 0.045, profile.yearsToRetirement), // 4.5%
      'finpension':
          _futureValue(contribution, 0.055, profile.yearsToRetirement), // 5.5%
      'insurance':
          _futureValue(contribution, 0.01, profile.yearsToRetirement), // 1%
    };

    final potentialGain = projections['viac']! - projections['bank']!;

    // Optimisation retrait (si multiple comptes)
    double? taxSingle;
    double? taxMultiple;
    double? savingsMultiple;

    if (nb3aAccounts == 1 && projections['viac']! > 100000) {
      final totalCapital = projections['viac']!;
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
    final marginalRate =
        _estimateMarginalRate(profile.annualIncome, profile.canton);

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

  List<ActionItem> _buildPriorityActions(FinancialHealthScore healthScore) {
    final actions = <ActionItem>[];

    // Extraire les top recommandations de chaque cercle
    for (final reco in healthScore.topPriorities) {
      final action = _parseRecommendationToAction(reco);
      if (action != null) actions.add(action);
    }

    return actions.take(3).toList();
  }

  ActionItem? _parseRecommendationToAction(String recommendation) {
    // Parsing simple basé sur keywords
    if (recommendation.contains('2e compte 3a')) {
      return const ActionItem(
        title: 'Ouvre un 2e compte 3a chez VIAC',
        description:
            'Optimise ta fiscalité au retrait et diversifie tes placements.',
        priority: ActionPriority.high,
        potentialGainChf: 12000,
        category: ActionCategory.pillar3a,
        steps: [
          '1. Va sur viac.ch',
          '2. Crée ton compte (10 min)',
          '3. Choisis stratégie 60% actions',
          '4. Configure versement automatique',
        ],
      );
    }

    if (recommendation.contains('rachat LPP')) {
      return const ActionItem(
        title: 'Planifie ton rachat LPP échelonné',
        description: 'Économise jusqu\'à 60\'000 CHF d\'impôts sur 4 ans.',
        priority: ActionPriority.critical,
        potentialGainChf: 60000,
        category: ActionCategory.lpp,
        steps: [
          '1. Demande certificat LPP à ta caisse',
          '2. Vérifie montant rachetable exact',
          '3. Planifie rachat 50k CHF/an sur 4 ans',
          '4. Effectue 1er rachat avant 31 décembre',
        ],
      );
    }

    if (recommendation.contains('AVS')) {
      return const ActionItem(
        title: 'Vérifie ton compte AVS',
        description: 'Évite de perdre jusqu\'à 38\'000 CHF de rente à vie.',
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
      return const ActionItem(
        title: 'Rembourse tes dettes de consommation',
        description: 'C\'est le placement le plus rentable (6-10% garanti).',
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
      return const ActionItem(
        title: 'Constitue ton fonds d\'urgence',
        description: 'Vise 3 mois de charges sur un compte épargne séparé.',
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
      Map<String, dynamic> answers, UserProfile profile) {
    return Roadmap(phases: [
      RoadmapPhase(
        title: 'Immédiat',
        timeframe: 'Ce mois',
        actions: _buildPriorityActions(healthScore)
            .where((a) =>
                a.priority == ActionPriority.critical ||
                a.priority == ActionPriority.high)
            .toList(),
      ),
      RoadmapPhase(
        title: 'Court Terme',
        timeframe: '3-6 mois',
        actions: [], // À compléter selon contexte
      ),
    ]);
  }

  // ===== HELPERS =====

  double _estimateEffectiveRate(
      double taxableIncome, String canton, bool isMarried) {
    // Simplification grossière - à remplacer par vrai calcul cantonal
    final baseRate = isMarried ? 0.12 : 0.15;

    if (taxableIncome > 150000) return baseRate + 0.10;
    if (taxableIncome > 100000) return baseRate + 0.05;
    if (taxableIncome > 60000) return baseRate + 0.02;
    return baseRate;
  }

  double _estimateMarginalRate(double annualIncome, String canton) {
    // Taux marginal ~ 25-35% selon revenu
    if (annualIncome > 120000) return 0.35;
    if (annualIncome > 90000) return 0.30;
    if (annualIncome > 60000) return 0.25;
    return 0.20;
  }

  double _estimateAvsRent(UserProfile profile) {
    // Rente AVS max couple = 3'585 CHF, individuel = 2'370 CHF
    // Simplifié : suppose rente complète
    return profile.isMarried ? 3585 : 2370;
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
