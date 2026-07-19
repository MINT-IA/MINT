import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

import '../models/financial_report.dart';
import '../models/circle_score.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'circle_scoring_service.dart';

/// Service de génération du rapport financier exhaustif
class FinancialReportService {
  final CircleScoringService _scoringService = CircleScoringService();

  /// Génère le rapport complet à partir des réponses du wizard
  FinancialReport generateReport(
    Map<String, dynamic> answers, {
    S? l,
    LppCapitalNoticeSpecialistHandoff? lppCapitalNoticeHandoff,
    LppRegulationSpecialistHandoff? lppRegulationHandoff,
    Pillar3aBeneficiarySpecialistHandoff? pillar3aBeneficiaryHandoff,
  }) {
    // 1. Profil utilisateur
    final profile = _buildUserProfile(answers);

    // 2. Score de santé financière. Wizard-only AVS declarations remain
    // unverified; only the profile's certificate-backed evidence can affect it.
    final coachProfile = CoachProfile.fromWizardAnswers(answers);
    final healthScore = _scoringService.calculateScore(
      answers,
      profile: coachProfile,
    );

    // 3. Simulation fiscale
    final taxSim = _buildTaxSimulation(answers, profile);

    // 4. Projection retraite (si données suffisantes)
    final retirementProj = _buildRetirementProjection(answers, profile);

    // 5. Stratégie rachat LPP (si applicable)
    final lppStrategy = _buildLppStrategy(answers, profile);

    // 6. Actions prioritaires (top 3 from scoring) — enrichies avec gains calculés
    final priorityActions = _buildPriorityActions(
      healthScore,
      taxSim: taxSim,
      lppStrategy: lppStrategy,
      l: l,
    );

    // 7. Roadmap personnalisée
    final roadmap = _buildRoadmap(healthScore, answers, profile, l: l);

    // 8. Sources juridiques par cercle
    final sources = _buildJuridicalSources(healthScore);

    // 9. Disclaimers dynamiques
    final disclaimers = _buildDisclaimers(
      taxSim: taxSim,
      retirementProj: retirementProj,
      lppStrategy: lppStrategy,
      l: l,
    );

    // FIX-W11-2: Compute confidence score via ConfidenceScorer (financial_core)
    final confidenceResult = ConfidenceScorer.score(coachProfile);
    final confidenceScore = confidenceResult.score;
    final enrichmentPrompts = confidenceResult.prompts
        .map((prompt) => prompt.machineDescriptor)
        .toList();

    // FIX-W11-4: Snapshot current constants for report traceability
    final simulationAssumptions = <String, dynamic>{
      'constants_version':
          RegulatorySyncService.lastSyncAt?.toIso8601String() ??
              'offline_fallback',
      'lpp_conversion_rate': lppTauxConversionMinDecimal,
      'pillar3a_max': pilier3aPlafondAvecLpp,
    };

    // FIX-W11-5: Data collection timestamp from wizard answers
    final lastAnswerTimestamp = answers['_last_updated_at'] as String?;
    DateTime? dataCollectedAt;
    if (lastAnswerTimestamp != null) {
      dataCollectedAt = DateTime.tryParse(lastAnswerTimestamp);
    }

    return FinancialReport(
      profile: profile,
      healthScore: healthScore,
      taxSimulation: taxSim,
      retirementProjection: retirementProj,
      lppBuybackStrategy: lppStrategy,
      lppCapitalNoticeHandoff: lppCapitalNoticeHandoff,
      lppRegulationHandoff: lppRegulationHandoff,
      pillar3aBeneficiaryHandoff: pillar3aBeneficiaryHandoff,
      priorityActions: priorityActions,
      personalizedRoadmap: roadmap,
      disclaimers: disclaimers,
      sources: sources,
      confidenceScore: confidenceScore,
      enrichmentPrompts: enrichmentPrompts,
      generatedAt: DateTime.now(),
      dataCollectedAt: dataCollectedAt,
      reportVersion: '2.1',
      simulationAssumptions: simulationAssumptions,
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
      sources.add(
          'LPP art. 14 — Taux de conversion'); // lint-ignore: legacy i18n debt predates this G1 slice
      sources.add('OPP3 — 3e pilier');
      sources.add('LAVS — Rentes');
    }

    // Cercle 3 — Croissance / investissement / fiscalité
    if (healthScore.circle3Croissance.items.isNotEmpty) {
      sources.add(
          'LIFD art. 33 — Déductions fiscales'); // lint-ignore: legacy i18n debt predates this G1 slice
    }

    // Cercle 4 — Optimisation / succession / assurance
    if (healthScore.circle4Optimisation.items.isNotEmpty) {
      sources.add(
          'CC art. 470 — Réserves héréditaires'); // lint-ignore: legacy i18n debt predates this G1 slice
      sources.add(
          'LIFD — Impôt fédéral'); // lint-ignore: legacy i18n debt predates this G1 slice
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
      l?.reportDisclaimerBase1 ??
          'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin.', // lint-ignore: legacy i18n debt predates this G1 slice
      l?.reportDisclaimerBase2 ??
          'Les montants sont des estimations basées sur les données déclarées.', // lint-ignore: legacy i18n debt predates this G1 slice
      l?.reportDisclaimerBase3 ??
          'Les performances passées ne préjugent pas des performances futures.', // lint-ignore: legacy i18n debt predates this G1 slice
    ];

    // Disclaimer fiscal (toujours présent car taxSim est required)
    if (taxSim.totalTax > 0) {
      disclaimers.add(
        l?.reportDisclaimerFiscal ??
            'L\'estimation fiscale est approximative et ne remplace pas une déclaration d\'impôts.', // lint-ignore: legacy i18n debt predates this G1 slice
      );
    }

    // Disclaimer retraite
    if (retirementProj != null) {
      disclaimers.add(
        l?.reportDisclaimerRetraite ??
            'La projection retraite est indicative et dépend de l\'évolution législative (réformes AVS/LPP).', // lint-ignore: legacy i18n debt predates this G1 slice
      );
    }

    // Disclaimer rachat LPP
    if (lppStrategy != null) {
      disclaimers.add(
        l?.reportDisclaimerRachatLpp ??
            'Le rachat LPP est soumis à un blocage de 3 ans pour les retraits EPL (LPP art. 79b al. 3).', // lint-ignore: legacy i18n debt predates this G1 slice
      );
    }

    return disclaimers;
  }

  UserProfile _buildUserProfile(Map<String, dynamic> answers) {
    final birthYear =
        _parseInt(answers['q_birth_year']) ?? DateTime.now().year - 40;
    return UserProfile(
      firstName: answers['q_firstname'] as String?,
      birthYear: birthYear,
      canton: answers['q_canton'] as String? ?? 'ZH',
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

    // Enfants — déduction fédérale LIFD art. 35 al. 1 let. a (6'700 CHF
    // en 2025) + déduction cantonale LHID art. 9 al. 2 let. c (7'000-13'000
    // CHF selon canton). Wave 7 fiscal audit P0-R4 : le flat 6'500 ignorait
    // toute la couche cantonale (sous-estimation ~55 % pour VS/VD/GE).
    if (profile.hasChildren) {
      final perChild = FamilyService.totalChildDeduction(profile.canton);
      deductions[
          'Déduction enfants' // lint-ignore: legacy i18n debt predates this G1 slice
          ] = profile.childrenCount * perChild;
    }

    final taxableIncome =
        annualIncome - deductions.values.fold(0.0, (sum, val) => sum + val);

    // Estimation fiscale simplifiée (à raffiner avec service dédié).
    // `children` forwarded so married-with-children splitting (LIFD art. 36
    // al. 2bis) is reflected via the AFC family adjustment table.
    final effectiveRate = _estimateEffectiveRate(
        taxableIncome, profile.canton, profile.isMarried,
        children: profile.childrenCount);
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
          taxableWithBuyback, profile.canton, profile.isMarried,
          children: profile.childrenCount);
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

    return RetirementProjection(
      yearsUntilRetirement: profile.yearsToRetirement,
      // A point LPP projection requires certificate-backed mandatory and
      // extra-mandatory splits plus the fund's own projected pension.
      lppCapital: null,
      // A 3a point requires dated balances and an explicit scenario range.
      pillar3aCapital: null,
      monthlyAvsRent: null,
      monthlyLppRent: null,
      currentMonthlyIncome: profile.monthlyNetIncome,
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
    S? l,
  }) {
    final actions = <ActionItem>[];

    // Extraire les top recommandations de chaque cercle
    for (final reco in healthScore.topPriorities) {
      final action = _parseRecommendationToAction(
        reco,
        taxSim: taxSim,
        lppStrategy: lppStrategy,
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
    S? l,
  }) {
    // Parsing basé sur keywords avec gains calculés à partir des données réelles
    if (recommendation.contains('rachat LPP')) {
      // Gain réel : économie fiscale totale calculée par la stratégie LPP
      final computedGain = lppStrategy?.totalTaxSavings ?? 0;
      final displayGain = computedGain > 0 ? computedGain : 60000.0;
      final nbYears = lppStrategy?.yearlyPlan.length ?? 4;

      return ActionItem(
        title:
            'Planifie ton rachat LPP échelonné', // lint-ignore: legacy i18n debt predates this G1 slice
        description:
            'Économise jusqu\'à ${formatChfWithPrefix(displayGain)} d\'impôts sur $nbYears ans.', // lint-ignore: legacy i18n debt predates this G1 slice
        priority: ActionPriority.critical,
        potentialGainChf: displayGain,
        category: ActionCategory.lpp,
        steps: const [
          '1. Demande certificat LPP à ta caisse', // lint-ignore: legacy i18n debt predates this G1 slice
          '2. Vérifie montant rachetable exact', // lint-ignore: legacy i18n debt predates this G1 slice
          '3. Planifie rachat échelonné avant retraite', // lint-ignore: legacy i18n debt predates this G1 slice
          '4. Effectue 1er rachat avant 31 décembre', // lint-ignore: legacy i18n debt predates this G1 slice
        ],
      );
    }

    if (recommendation.contains('AVS')) {
      return ActionItem(
        title: l?.reportActionTitleAvsCheck ??
            'Vérifie ton compte AVS', // lint-ignore: legacy i18n debt predates this G1 slice
        description: l?.reportActionDescAvsCheck ??
            'Commande ton extrait CI et fais vérifier les périodes par ta caisse de compensation.', // lint-ignore: legacy catalog or internal copy; localization debt predates G1 AVS-03
        priority: ActionPriority.high,
        category: ActionCategory.avs,
        steps: [
          '1. Commande extrait gratuit sur ahv-iv.ch', // lint-ignore: legacy i18n debt predates this G1 slice
          '2. Vérifie les années de cotisation', // lint-ignore: legacy i18n debt predates this G1 slice
          '3. Demande à la caisse quelles périodes sont retenues', // lint-ignore: legacy catalog or internal copy; localization debt predates G1 AVS-03
        ],
      );
    }

    if (recommendation.contains('dette') ||
        recommendation.contains(
            'crédit' // lint-ignore: legacy i18n debt predates this G1 slice
            )) {
      return ActionItem(
        title: l?.reportActionTitleDette ??
            'Rembourse tes dettes de consommation', // lint-ignore: legacy i18n debt predates this G1 slice
        description: l?.reportActionDescDette ??
            'Chaque CHF remboursé te fait économiser l\'équivalent du taux d\'intérêt de la dette (souvent 6-10 % par an).', // lint-ignore: legacy i18n debt predates this G1 slice
        priority: ActionPriority.critical,
        potentialGainChf: 2000,
        category: ActionCategory.protection,
        steps: [
          '1. Liste toutes tes dettes (montant, taux)', // lint-ignore: legacy i18n debt predates this G1 slice
          '2. Attaque celle avec le plus haut taux', // lint-ignore: legacy i18n debt predates this G1 slice
          '3. Arrête tout nouvel investissement tant qu\'il reste une dette > 5 % d\'intérêt', // lint-ignore: legacy i18n debt predates this G1 slice
        ],
      );
    }

    if (recommendation.toLowerCase().contains('urgence')) {
      return ActionItem(
        title: l?.reportActionTitleUrgence ??
            'Constitue ton fonds d\'urgence', // lint-ignore: legacy i18n debt predates this G1 slice
        description: l?.reportActionDescUrgence ??
            'Vise 3 mois de charges sur un compte épargne séparé.', // lint-ignore: legacy i18n debt predates this G1 slice
        priority: ActionPriority.critical,
        category: ActionCategory.protection,
        steps: [
          '1. Ouvre un compte épargne sans frais dans ta banque', // lint-ignore: legacy i18n debt predates this G1 slice
          '2. Mets en place un virement automatique (≈ 10 % du salaire)', // lint-ignore: legacy i18n debt predates this G1 slice
          '3. Ne touche pas à cet argent sauf urgence', // lint-ignore: legacy i18n debt predates this G1 slice
        ],
      );
    }

    return null;
  }

  Roadmap _buildRoadmap(FinancialHealthScore healthScore,
      Map<String, dynamic> answers, UserProfile profile,
      {S? l}) {
    return Roadmap(phases: [
      RoadmapPhase(
        title: l?.reportRoadmapPhaseImmediat ??
            'Immédiat', // lint-ignore: legacy i18n debt predates this G1 slice
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
      double taxableIncome, String canton, bool isMarried,
      {int children = 0}) {
    // Wave 7 fiscal audit P0-R3 : the previous `× 0.85` flat ignored
    // that cantonal splitting varies 8-25 % by income and canton
    // (LIFD art. 36 al. 2bis, LHID art. 11 — ZH barème séparé, VS
    // quotient familial, GE splitting modifié, VD ×0.5). The centralized
    // estimateMarginalRate already consumes `isMarried` + `children`
    // via its `_familyAdjustment` table sourced from AFC 2024, so we
    // just forward the parameters instead of double-discounting.
    return RetirementTaxCalculator.estimateMarginalRate(
      taxableIncome,
      canton,
      isMarried: isMarried,
      children: children,
    );
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
