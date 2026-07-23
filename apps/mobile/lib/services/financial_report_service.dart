import 'dart:math' show pow;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
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
      profile: profile,
      taxSim: taxSim,
      lppStrategy: lppStrategy,
      pillar3aAnalysis: pillar3aAnalysis,
      l: l,
    );

    // 8. Roadmap personnalisée
    final roadmap = _buildRoadmap(
      healthScore,
      answers,
      profile,
      taxSim: taxSim,
      lppStrategy: lppStrategy,
      pillar3aAnalysis: pillar3aAnalysis,
      l: l,
    );

    // 9. Sources juridiques par cercle
    final sources = _buildJuridicalSources(healthScore);

    // 10. Disclaimers dynamiques
    final disclaimers = _buildDisclaimers(
      taxSim: taxSim,
      retirementProj: retirementProj,
      lppStrategy: lppStrategy,
      l: l,
    );

    // FIX-W11-2: Compute confidence score via ConfidenceScorer (financial_core)
    double confidenceScore = 0;
    List<String> enrichmentPrompts = const [];
    try {
      final coachProfile = CoachProfile.fromWizardAnswers(answers);
      final confidenceResult = ConfidenceScorer.score(coachProfile);
      confidenceScore = confidenceResult.score;
      enrichmentPrompts = confidenceResult.prompts.map((p) => p.label).toList();
    } catch (_) {
      // Fallback: confidence remains 0 if profile cannot be built
    }

    // -pd4 : la borne prudente conjoint (revenu inconnu) doit être DITE.
    if (profile.isMarried && profile.spouseMonthlyNetIncome == null) {
      enrichmentPrompts = [
        ...enrichmentPrompts,
        l?.reportSpouseIncomeMissingPrompt ??
            'Renseigne le revenu de ton/ta conjoint\u00b7e\u00a0: sa rente AVS est '
                'estimée au minimum légal en attendant.',
      ];
    }

    final pillar3aHasLpp = _hasPillar3aLppAffiliation(profile);
    final pillar3aMaxApplicable = _applicablePillar3aMax(
      profile,
      hasLpp: pillar3aHasLpp,
    );

    // FIX-W11-4: Snapshot current constants for report traceability
    final simulationAssumptions = <String, dynamic>{
      'constants_version':
          RegulatorySyncService.lastSyncAt?.toIso8601String() ??
              'offline_fallback',
      'lpp_conversion_rate': lppTauxConversionMinDecimal,
      'avs_max_monthly': avsRenteMaxMensuelle,
      'pillar3a_lpp_status': pillar3aHasLpp ? 'with_lpp' : 'without_lpp',
      'pillar3a_max_applicable': pillar3aMaxApplicable,
      'pillar3a_max_with_lpp':
          reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp),
      'pillar3a_max_without_lpp':
          reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp),
      'pillar3a_without_lpp_income_rate': pilier3aTauxRevenuSansLpp,
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
      pillar3aAnalysis: pillar3aAnalysis,
      lppBuybackStrategy: lppStrategy,
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
      l?.reportDisclaimerBase1 ??
          'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin.',
      l?.reportDisclaimerBase2 ??
          'Les montants sont des estimations basées sur les données déclarées.',
      l?.reportDisclaimerBase3 ??
          'Les performances passées ne préjugent pas des performances futures.',
    ];

    // Disclaimer fiscal (toujours présent car taxSim est required)
    if (taxSim.totalTax > 0) {
      disclaimers.add(
        l?.reportDisclaimerFiscal ??
            'L\'estimation fiscale est approximative et ne remplace pas une déclaration d\'impôts.',
      );
    }

    // Disclaimer retraite
    if (retirementProj != null) {
      disclaimers.add(
        l?.reportDisclaimerRetraite ??
            'La projection retraite est indicative et dépend de l\'évolution législative (réformes AVS/LPP).',
      );
    }

    // Disclaimer rachat LPP
    if (lppStrategy != null) {
      disclaimers.add(
        l?.reportDisclaimerRachatLpp ??
            'Le rachat LPP est soumis à un blocage de 3 ans pour les retraits EPL (LPP art. 79b al. 3).',
      );
    }

    return disclaimers;
  }

  UserProfile _buildUserProfile(Map<String, dynamic> answers) {
    final birthYear = _birthYearFromAnswers(answers);
    final employmentStatus =
        answers['q_employment_status'] as String? ?? 'employee';
    final parsedMonthlyNetIncome =
        _parseDouble(answers['q_net_income_period_chf']);
    final payFrequency =
        (answers['q_pay_frequency'] as String?)?.trim().toLowerCase();
    final explicitMonthlyNetIncome = (payFrequency == 'yearly' ||
            payFrequency == 'annuel' ||
            payFrequency == 'annual')
        ? parsedMonthlyNetIncome != null
            ? parsedMonthlyNetIncome / 12
            : null
        : parsedMonthlyNetIncome;
    final independentAnnualNetIncome =
        _parseDouble(answers['q_self_employed_net_income_annual_chf']);
    final independentMonthlyNetIncome =
        _isIndependentEmploymentStatus(employmentStatus) &&
                independentAnnualNetIncome != null &&
                independentAnnualNetIncome.isFinite &&
                independentAnnualNetIncome > 0
            ? independentAnnualNetIncome / 12
            : null;
    final monthlyNetIncome =
        explicitMonthlyNetIncome ?? independentMonthlyNetIncome ?? 0.0;
    return UserProfile(
      firstName: answers['q_firstname'] as String?,
      birthYear: birthYear,
      canton: answers['q_canton'] as String? ?? 'ZH',
      civilStatus: answers['q_civil_status'] as String? ?? 'single',
      childrenCount: _parseInt(answers['q_children']) ?? 0,
      employmentStatus: employmentStatus,
      monthlyNetIncome: monthlyNetIncome,
      independentProfessionalAnnualIncome: independentAnnualNetIncome,
      hasPensionFund: _parsePensionFundAffiliation(
        answers['q_has_pension_fund'],
      ),
      gender: answers['q_gender'] as String?,
      spouseGender: answers['q_spouse_gender'] as String?,
      // FIX-W11-3: Spouse birth year and income for accurate couple AVS
      spouseBirthYear: _parseInt(answers['q_partner_birth_year']),
      spouseMonthlyNetIncome: _parseDouble(answers['q_partner_net_income_chf']),
      // Nouvelle logique AVS (triage lacunes)
      avsGapYears:
          birthYear >= 1900 ? _calculateAvsGaps(answers, birthYear) : null,
      spouseAvsGapYears: birthYear >= 1900
          ? _calculateSpouseAvsGaps(answers, birthYear)
          : null,
      // Legacy fallback
      contributionYears: _parseInt(answers['q_avs_contribution_years']),
      spouseContributionYears:
          _parseInt(answers['q_spouse_avs_contribution_years']),
      firstEmploymentYear: _parseInt(answers['q_first_employment_year']),
      spouseFirstEmploymentYear:
          _parseInt(answers['q_spouse_first_employment_year']),
    );
  }

  /// Delegates to CircleScoringService shared static helper (single source of truth).
  int? _calculateAvsGaps(Map<String, dynamic> answers, int birthYear) =>
      CircleScoringService.calculateAvsGapsFromAnswers(answers, birthYear);

  int? _calculateSpouseAvsGaps(Map<String, dynamic> answers, int birthYear) =>
      CircleScoringService.calculateSpouseAvsGapsFromAnswers(
          answers, birthYear);

  int _birthYearFromAnswers(Map<String, dynamic> answers) {
    final dobRaw = answers['q_date_of_birth'];
    if (dobRaw is String) {
      final dob = DateTime.tryParse(dobRaw);
      if (dob != null) return dob.year;
    }
    return _parseInt(answers['q_birth_year']) ?? 0;
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
      deductions['Déduction enfants'] = profile.childrenCount * perChild;
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
      const buybackAmount = 50000.0; // 1ère tranche illustrative
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
    final age = profile.ageOrNull;
    final yearsToRetirement = profile.yearsToRetirementOrNull;
    if (age == null || yearsToRetirement == null || yearsToRetirement <= 0) {
      return null;
    }

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
      age: age,
    );
    // Use LPP constants for coordinated salary (LPP art. 8)
    // Guard: if gross < seuil d'accès LPP (22'680), no LPP coverage
    final double coordinatedSalary;
    if (annualGrossApprox < reg('lpp.entry_threshold', lppSeuilEntree)) {
      coordinatedSalary = 0.0; // Not eligible for LPP
    } else {
      coordinatedSalary = (annualGrossApprox -
              reg('lpp.coordination_deduction', lppDeductionCoordination))
          .clamp(reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
              reg('lpp.max_coordinated_salary', lppSalaireCoordMax));
    }
    final refAgeReport =
        reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    for (int year = 0; year < yearsToRetirement; year++) {
      final ageThisYear = age + year;
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
        _futureValue(contribution3a, 0.03, yearsToRetirement);

    // Rentes
    final monthlyAvsRent = _estimateAvsRent(profile);
    // FIX-047: Use legal minimum 6.8% (same as dashboard) to avoid
    // confusing users with different CHF amounts. Was 5.8% (surobligatoire)
    // which understated rente by 18.6% vs dashboard.
    final convRate = reg('lpp.conversion_rate', lppTauxConversionMinDecimal);
    final monthlyLppRent = (lppCapital * convRate) / 12;

    return RetirementProjection(
      yearsUntilRetirement: yearsToRetirement,
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
    final yearsToRetirement = profile.yearsToRetirementOrNull;
    if (yearsToRetirement == null) return null;
    final maxContribution = _applicablePillar3aMax(profile);

    // Projections par provider (simplifié)
    final projections = <String, double>{
      'bank': _futureValue(contribution, 0.015, yearsToRetirement), // 1.5%
      'fintech': _futureValue(contribution, 0.045, yearsToRetirement), // 4.5%
      'fintech_low_fee':
          _futureValue(contribution, 0.055, yearsToRetirement), // 5.5%
      'insurance': _futureValue(contribution, 0.01, yearsToRetirement), // 1%
    };

    final potentialGain = projections['fintech']! - projections['bank']!;

    // Optimisation retrait (si multiple comptes)
    double? taxSingle;
    double? taxMultiple;
    double? savingsMultiple;

    if (nb3aAccounts == 1 && projections['fintech']! > 100000) {
      // Wave 7 fiscal audit P0-R6 : the previous 8 %/5 % flat was invented
      // AND the /2*2 algebraic split cancelled to `totalCapital × 0.05`.
      // Delegate to RetirementTaxCalculator which implements LIFD art. 38
      // progressive brackets (×1.0/×1.15/×1.30/×1.50/×1.70) + Wave 3
      // cantonal married matrix (marriedCapitalTaxDiscountFor).
      final totalCapital = projections['fintech']!;
      taxSingle = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: totalCapital,
        canton: profile.canton,
        isMarried: profile.isMarried,
      );
      // Staggered over 2 tax years — each year taxed on half the capital,
      // benefitting from lower progressive brackets.
      final halfTax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: totalCapital / 2,
        canton: profile.canton,
        isMarried: profile.isMarried,
      );
      taxMultiple = halfTax * 2;
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

    final yearsToRetirement = profile.yearsToRetirementOrNull;
    if (yearsToRetirement == null) return null;
    final isMarried = profile.civilStatus == 'marie';
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
        profile.annualIncome, profile.canton,
        isMarried: isMarried, children: profile.childrenCount);

    final plan = <AnnualBuyback>[];
    final currentYear = DateTime.now().year;

    // RÈGLE DES 3 ANS : si retrait capital prévu, finir les rachats avant retraite - 3 ans.
    // Le calendrier privilégie les dernières années pré-retraite pour l'effet fiscal estimé.

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
      strategy = 'near_term';
    } else {
      // LOIN de la retraite (>5 ans)
      // Scénario : attendre et faire les rachats 3 ans avant retraite.
      // Mais si besoin fiscal immédiat, étaler sur 3 ans maintenant
      final retirementYear = currentYear + yearsToRetirement;

      // Option 1 : attendre si pas besoin fiscal urgent
      startYear = retirementYear - 5; // Commencer 5 ans avant retraite
      nbYears = 3; // Étaler sur 3 ans (de -5 à -2 ans avant retraite)
      strategy = 'wait_scenario';

      // Note: Si besoin fiscal urgent, on pourrait proposer un plan maintenant
      // mais l'impact fiscal estimé peut être moins favorable.
    }

    // Calculer le montant annuel indicatif.
    final yearlyAmount = (buybackAvailable / nbYears).roundToDouble();

    // Générer le plan année par année
    for (int i = 0; i < nbYears; i++) {
      final year = startYear + i;
      final amount = (i == nbYears - 1)
          ? (buybackAvailable - ((nbYears - 1) * yearlyAmount))
          : yearlyAmount;

      // Le taux marginal peut baisser si revenu baisse avec l'âge
      final yearMarginalRate = (strategy == 'wait_scenario')
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
    UserProfile? profile,
    TaxSimulation? taxSim,
    LppBuybackStrategy? lppStrategy,
    Pillar3aAnalysis? pillar3aAnalysis,
    S? l,
  }) {
    final actions = <ActionItem>[];
    ActionItem? independentNoLpp3aAction;

    // Extraire les top recommandations de chaque cercle
    for (final reco in healthScore.topPriorities) {
      final action = _parseRecommendationToAction(
        reco,
        profile: profile,
        taxSim: taxSim,
        lppStrategy: lppStrategy,
        pillar3aAnalysis: pillar3aAnalysis,
        l: l,
      );
      if (action == null) continue;
      if (_isIndependentWithoutLppProfile(profile) &&
          action.category == ActionCategory.pillar3a) {
        independentNoLpp3aAction = action;
        continue;
      }
      actions.add(action);
    }

    if (independentNoLpp3aAction != null) {
      final debtActions = actions.where(_isDebtAction).toList();
      final otherActions =
          actions.where((action) => !_isDebtAction(action)).toList();
      actions
        ..clear()
        ..addAll(debtActions)
        ..add(independentNoLpp3aAction)
        ..addAll(otherActions);
    }

    return actions.take(3).toList();
  }

  ActionItem? _parseRecommendationToAction(
    String recommendation, {
    UserProfile? profile,
    TaxSimulation? taxSim,
    LppBuybackStrategy? lppStrategy,
    Pillar3aAnalysis? pillar3aAnalysis,
    S? l,
  }) {
    // Parsing basé sur keywords avec gains calculés à partir des données réelles
    if (_isIndependentWithoutLppProfile(profile) &&
        recommendation.contains('3a')) {
      final fiscalGain = _estimateFirst3aFiscalGain(
        profile: profile,
        taxSim: taxSim,
      );
      return _buildIndependentNoLpp3aAction(l: l, fiscalGain: fiscalGain);
    }

    if (recommendation.contains('premier compte 3a') ||
        recommendation.contains('premier 3a')) {
      final fiscalGain = _estimateFirst3aFiscalGain(
        profile: profile,
        taxSim: taxSim,
      );
      return ActionItem(
        title: l?.reportActionTitle3aFirst ?? 'Évaluer l’intérêt d’un 3a',
        description: l?.reportActionDesc3aFirst ??
            'Marge déductible et impact fiscal estimés selon ton revenu, ton canton et ton statut LPP.',
        priority: ActionPriority.high,
        potentialGainChf: fiscalGain,
        category: ActionCategory.pillar3a,
        steps: [
          '1. Vérifie ton éligibilité et ton statut LPP',
          '2. Compare les frais, supports et contraintes de retrait',
          '3. Estime l’impact fiscal avec tes données',
          '4. Revois les hypothèses avant de décider',
        ],
      );
    }

    if (recommendation.contains('2e compte 3a')) {
      // Gain réel : économie fiscale au retrait via échelonnement + rendement vs banque
      final gainVsBank = pillar3aAnalysis?.potentialGainVsBank;
      final withdrawalSavings = pillar3aAnalysis?.withdrawalOptimizationSavings;
      final totalGain = (gainVsBank ?? 0) + (withdrawalSavings ?? 0);

      return ActionItem(
        title: l?.reportActionTitle3aSecond ?? 'Évaluer l’intérêt d’un 2e 3a',
        description: l?.reportActionDesc3aSecond ??
            'Échelonnement au retrait et diversification à examiner selon tes comptes existants.',
        priority: ActionPriority.high,
        potentialGainChf: totalGain > 0 ? totalGain : null,
        category: ActionCategory.pillar3a,
        steps: const [
          '1. Compare les frais et restrictions des comptes existants',
          '2. Évalue l’intérêt d’un échelonnement au retrait',
          '3. Vérifie l’impact selon canton, horizon et montants',
          '4. Revois les hypothèses avant de décider',
        ],
      );
    }

    if (recommendation.contains('rachat LPP')) {
      // Gain réel : économie fiscale totale calculée par la stratégie LPP
      final computedGain = lppStrategy?.totalTaxSavings ?? 0;
      final nbYears = lppStrategy?.yearlyPlan.length ?? 4;

      return ActionItem(
        title: 'Planifie ton rachat LPP échelonné',
        description: computedGain > 0
            ? 'Impact fiscal estimé : ${formatChfWithPrefix(computedGain)} sur $nbYears ans.'
            : 'Planifie le calendrier et vérifie le montant exact auprès de ta caisse.',
        priority: ActionPriority.critical,
        potentialGainChf: computedGain > 0 ? computedGain : null,
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
        description: l?.reportActionDescAvsCheck ??
            'Vérifie tes années de cotisation pour estimer une éventuelle lacune AVS.',
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
        title:
            l?.reportActionTitleDette ?? 'Rembourse tes dettes de consommation',
        description: l?.reportActionDescDette ??
            'Chaque CHF remboursé te fait économiser l\'équivalent du taux d\'intérêt de la dette (souvent 6-10 % par an).',
        priority: ActionPriority.critical,
        category: ActionCategory.protection,
        steps: [
          '1. Liste toutes tes dettes (montant, taux)',
          '2. Attaque celle avec le plus haut taux',
          '3. Arrête tout nouvel investissement tant qu\'il reste une dette > 5 % d\'intérêt',
        ],
      );
    }

    if (recommendation.toLowerCase().contains('urgence')) {
      return ActionItem(
        title: l?.reportActionTitleUrgence ?? 'Constitue ton fonds d\'urgence',
        description: l?.reportActionDescUrgence ??
            'Vise 3 mois de charges sur un compte épargne séparé.',
        priority: ActionPriority.critical,
        category: ActionCategory.protection,
        steps: [
          '1. Identifie un support liquide, séparé et sans frais inutiles',
          '2. Planifie un montant réaliste selon tes ressources mensuelles',
          '3. Garde cette réserve accessible uniquement pour une urgence',
        ],
      );
    }

    return null;
  }

  ActionItem _buildIndependentNoLpp3aAction({
    required S? l,
    required double? fiscalGain,
  }) {
    return ActionItem(
      title: l?.reportActionTitle3aIndependentNoLpp ??
          'Clarifier mon statut indépendant avant d’augmenter le 3a',
      description: l?.reportActionDesc3aIndependentNoLpp ??
          'MINT estime ton plafond 3a avec les revenus déclarés et l’hypothèse sans LPP. Ce plafond légal ne dit pas si ton budget mensuel peut absorber un versement : vérifie aussi ta capacité, ton statut AVS d’indépendant, ton revenu net imposable, ta couverture accident/perte de gain et la liquidité nécessaire si tes revenus varient. Piste suivante : comparer l’option LPP facultative, le 3a et la trésorerie avec un spécialiste qualifié.',
      priority: ActionPriority.high,
      potentialGainChf: fiscalGain,
      category: ActionCategory.pillar3a,
      steps: [
        l?.reportActionStep3aIndependentNoLpp1 ??
            '1. Confirme ton statut AVS indépendant et ton absence d’affiliation LPP',
        l?.reportActionStep3aIndependentNoLpp2 ??
            '2. Vérifie le revenu d’activité déclaré pour le plafond 3a et le revenu imposable pour l’impact fiscal',
        l?.reportActionStep3aIndependentNoLpp3 ??
            '3. Teste la capacité de ton budget mensuel avec la volatilité de tes revenus',
        l?.reportActionStep3aIndependentNoLpp4 ??
            '4. Passe en revue les couvertures risque avant de décider',
      ],
    );
  }

  bool _isIndependentWithoutLppProfile(UserProfile? profile) {
    return profile != null &&
        profile.isIndependent &&
        !_hasPillar3aLppAffiliation(profile);
  }

  bool _isDebtAction(ActionItem action) {
    // Debt steps are still French fallbacks; keep this in sync if localized.
    return action.category == ActionCategory.protection &&
        action.steps.join(' ').toLowerCase().contains('dette');
  }

  Roadmap _buildRoadmap(FinancialHealthScore healthScore,
      Map<String, dynamic> answers, UserProfile profile,
      {TaxSimulation? taxSim,
      LppBuybackStrategy? lppStrategy,
      Pillar3aAnalysis? pillar3aAnalysis,
      S? l}) {
    return Roadmap(phases: [
      RoadmapPhase(
        title: l?.reportRoadmapPhaseImmediat ?? 'Immédiat',
        timeframe: l?.reportRoadmapTimeframeImmediat ?? 'Ce mois',
        actions: _buildPriorityActions(
          healthScore,
          profile: profile,
          taxSim: taxSim,
          lppStrategy: lppStrategy,
          pillar3aAnalysis: pillar3aAnalysis,
          l: l,
        )
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

  bool _isIndependentEmploymentStatus(String? status) {
    final normalized = status?.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'self_employed' ||
        normalized == 'independent' ||
        normalized == 'independant' ||
        normalized == 'indépendant';
  }

  double? _estimateFirst3aFiscalGain({
    required UserProfile? profile,
    required TaxSimulation? taxSim,
  }) {
    if (profile == null ||
        taxSim == null ||
        taxSim.taxableIncome <= 0 ||
        taxSim.totalTax <= 0 ||
        taxSim.effectiveRate <= 0) {
      return null;
    }
    final age = profile.ageOrNull;
    if (age == null) return null;

    final grossAnnualSalary = _estimatedGrossAnnualIncome(profile);
    final hasLpp = _hasPillar3aLppAffiliation(profile);
    final maxContribution = _applicablePillar3aMax(profile, hasLpp: hasLpp);
    final current3a = taxSim.deductions['3a'] ?? 0;
    final remainingDeduction = maxContribution - current3a;
    if (remainingDeduction <= 0) return null;

    final impact = RetirementTaxCalculator.estimate3aTaxImpact(
      grossAnnualSalary: grossAnnualSalary,
      canton: profile.canton,
      isMarried: profile.isMarried,
      children: profile.childrenCount,
      hasLpp: hasLpp,
      contribution: remainingDeduction,
    );
    return impact.estimatedTaxSaving > 0 ? impact.estimatedTaxSaving : null;
  }

  double _estimatedGrossAnnualIncome(UserProfile profile) {
    final age = profile.ageOrNull;
    if (age == null) return profile.annualIncome;
    return NetIncomeBreakdown.estimateBrutFromNet(
      profile.monthlyNetIncome * 12,
      age: age,
    );
  }

  bool _hasPillar3aLppAffiliation(UserProfile profile) {
    if (profile.hasPensionFund != null) {
      return profile.hasPensionFund!;
    }
    final grossAnnualIncome = _estimatedGrossAnnualIncome(profile);
    return profile.isSalaried &&
        grossAnnualIncome >= reg('lpp.entry_threshold', lppSeuilEntree);
  }

  bool? _parsePensionFundAffiliation(dynamic value) {
    if (value is bool) return value;
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'yes' ||
        normalized == 'true' ||
        normalized == 'oui' ||
        normalized == 'ja' ||
        normalized == 'si' ||
        normalized == 'sì') {
      return true;
    }
    if (normalized == 'no' ||
        normalized == 'false' ||
        normalized == 'non' ||
        normalized == 'nein') {
      return false;
    }
    return null;
  }

  double _applicablePillar3aMax(
    UserProfile profile, {
    bool? hasLpp,
  }) {
    final resolvedHasLpp = hasLpp ?? _hasPillar3aLppAffiliation(profile);
    if (resolvedHasLpp) {
      return reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    }

    final incomeBase = profile.isIndependent &&
            profile.independentProfessionalAnnualIncome != null &&
            profile.independentProfessionalAnnualIncome!.isFinite &&
            profile.independentProfessionalAnnualIncome! > 0
        ? profile.independentProfessionalAnnualIncome!
        : profile.annualIncome;

    return (incomeBase * pilier3aTauxRevenuSansLpp)
        .clamp(
          0.0,
          reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp),
        )
        .toDouble();
  }

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

  double _estimateAvsRent(UserProfile profile) {
    final age = profile.ageOrNull;
    if (age == null) return 0;

    // Delegate to AvsCalculator for centralized AVS rente logic (LAVS art. 29, 34, 35).
    // Inverse: net → gross via NetIncomeBreakdown.estimateBrutFromNet
    final grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(
      profile.monthlyNetIncome * 12,
      age: age,
    );

    // F7-2: Pass gender and birthYear so AvsCalculator uses the correct
    // AVS21 reference age (64F / 65M — LAVS art. 21 al. 1).
    final isFemale = profile.gender == 'F';
    final refAgeAvs = profile.gender != null
        ? avsReferenceAge(birthYear: profile.birthYear, isFemale: isFemale)
        : reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    final userRente = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: refAgeAvs,
      lacunes: profile.avsGapYears ?? 0,
      anneesContribuees: profile.contributionYears,
      grossAnnualSalary: grossAnnualSalary,
      isFemale: profile.gender != null ? isFemale : null,
      birthYear: profile.gender != null ? profile.birthYear : null,
    );

    if (profile.isMarried) {
      // FIX-W11-3: Use spouse's actual age and salary instead of user's.
      // S57-F4: Use spouse's actual gender when available. Never infer from
      // user gender — same-sex couples would get the wrong reference age.
      // Fallback to male reference age (65) when spouse gender is unknown.
      final spouseIsFemale = profile.spouseGender == 'F';
      final hasSpouseGender = profile.spouseGender != null;
      final spouseBirthYear = profile.spouseBirthYear ?? profile.birthYear;
      final spouseAge = profile.spouseAge ?? age;
      final spouseRefAge = hasSpouseGender
          ? avsReferenceAge(
              birthYear: spouseBirthYear, isFemale: spouseIsFemale)
          : reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble())
              .toInt();
      // Beads MINT_nosync-pd4 (Codex review PR #976) : l'ancien fallback
      // clonait le salaire de l'UTILISATEUR sur le conjoint sans revenu
      // renseigné — fabrication de données qui gonflait la rente couple.
      // Honnête : revenu inconnu -> borne PRUDENTE = rente minimale légale
      // (RAMD <= minimum -> 1'260/mois) x gapFactor conjoint. La limite est
      // dite via un prompt d'enrichissement au call site — jamais une
      // estimation basse silencieuse.
      final spouseGrossAnnual = profile.spouseMonthlyNetIncome != null
          ? NetIncomeBreakdown.estimateBrutFromNet(
              profile.spouseMonthlyNetIncome! * 12,
              age: spouseAge,
            )
          : avsRAMDMin;
      final spouseRente = AvsCalculator.computeMonthlyRente(
        currentAge: spouseAge,
        retirementAge: spouseRefAge,
        lacunes: profile.spouseAvsGapYears ?? 0,
        anneesContribuees: profile.spouseContributionYears,
        grossAnnualSalary: spouseGrossAnnual,
        isFemale: hasSpouseGender ? spouseIsFemale : null,
        birthYear: hasSpouseGender ? spouseBirthYear : null,
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
    if (value is num) return value.toInt();
    if (value is String) {
      final normalized = value.trim().replaceAll("'", '').replaceAll(',', '.');
      return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(
          value.trim().replaceAll("'", '').replaceAll(',', '.'));
    }
    return null;
  }
}
