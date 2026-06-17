import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

/// Minimal profile computation service (Sprint S31 — Onboarding Redesign).
///
/// ARCHITECTURE: Local computation engine for onboarding.
/// Used as fallback when backend API is unavailable.
/// The backend MinimalProfileService is the authoritative source.
/// Constants are synced via reg() from RegulatoryRegistry.
///
/// Computes a financial snapshot from as few as 3 inputs (age, salary, canton).
/// All calculations delegate to [financial_core] — NEVER duplicates formulas.
///
/// Legal basis: LAVS art. 21-40, LPP art. 7-16, OPP3 art. 7, LIFD art. 38.
class MinimalProfileService {
  MinimalProfileService._();

  /// Compute a minimal financial profile from basic inputs.
  ///
  /// Required: [age], [grossSalary] (annual), [canton].
  /// Optional fields are estimated when not provided and tracked in
  /// [MinimalProfileResult.estimatedFields].
  static MinimalProfileResult compute({
    required int age,
    required double grossSalary,
    required String canton,
    String? employmentStatus,
    String? nationalityGroup,
    String? householdType,
    double? currentSavings,
    bool? isPropertyOwner,
    double? existing3a,
    double? existingLpp,
    int? targetRetirementAge,
    String? lppCaisseType,
    double? totalDebts,
    double? monthlyDebtService,

    /// Gender: 'M', 'F', or null. Passed to AvsCalculator for AVS21
    /// reference age (LAVS art. 21 al. 1). Null defaults to male (65).
    String? gender,

    /// Birth year — used with [gender] for AVS21 transitional cohorts.
    int? birthYear,

    /// Age d'arrivée en Suisse (si expat). Plumbé jusqu'à l'estimation LPP
    /// pour démarrer l'accumulation à l'arrivée, pas toujours à 25 (LPP art. 7).
    /// AUSSI transmis à AvsCalculator : une arrivée tardive ⇒ années de
    /// cotisation réduites ⇒ gapFactor < 1 (LAVS art. 29). Sans lui, l'aperçu
    /// rendait la rente MAX (2520) pour un Suisse de retour (incohérence ×2
    /// avec response_card / forecaster — matrice returning_swiss_gaps-1).
    int? arrivalAge,

    /// Années manquantes au sens AVS (lacunes — LAVS art. 29). Plumbées
    /// jusqu'à AvsCalculator pour appliquer le gapFactor, exactement comme
    /// forecaster_service:831 (chemin de référence).
    int lacunes = 0,

    /// Années cotisées AVS connues (certificat / dérivation onboarding).
    /// Si fourni, prime sur la dérivation arrivalAge dans AvsCalculator.
    int? anneesContribuees,

    /// Droit à la DÉDUCTION fiscale 3a pour cet archétype (plan 08, oracles
    /// expat_us-2 + frontalier-1). False → plafond3a, taxSaving3a et
    /// marginalTaxRate sont émis à 0 : un US person (FATCA) ou un frontalier
    /// NON quasi-résident ne peut pas déduire en Suisse. L'appelant calcule
    /// ce booléen via [ArchetypePredicates.canContribute3a] (source of truth
    /// unique, partagée avec coach_profile.canContribute3a — CLAUDE.md
    /// NEVER #3). Default true : tout salarié/indépendant suisse standard.
    bool canContribute3a = true,
  }) {
    final estimatedFields = <String>[];

    // --- Apply defaults with estimation tracking ---
    final effectiveHousehold = householdType ?? 'single';
    if (householdType == null) estimatedFields.add('householdType');

    final effectivePropertyOwner = isPropertyOwner ?? false;
    if (isPropertyOwner == null) estimatedFields.add('isPropertyOwner');

    // Estimate savings: (age - 25) * gross * 5% (conservative assumption)
    final effectiveSavings =
        currentSavings ?? max(0.0, (age - 25) * grossSalary * 0.05);
    if (currentSavings == null) estimatedFields.add('currentSavings');

    final effective3a = existing3a ?? 0.0;
    if (existing3a == null) estimatedFields.add('existing3a');

    // --- Employment status impact ---
    // Independant sans LPP: LPP = 0, 3a max = 36'288 CHF (OPP3 art. 7)
    // Sans emploi: reduced AVS, no LPP contributions
    final effectiveEmployment = employmentStatus ?? 'salarie';
    // Gate LPP=0 partagé (financial_core) — même prédicat que coach_profile,
    // sinon les deux moteurs divergent (oracle independent_no_lpp-3).
    // Ce service n'a pas de question caisse séparée : pour un indépendant
    // l'ESTIMATION est interdite. hasPensionFund=false ⇒ pas d'estimation
    // âge×salaire pour un indépendant.
    final canEstimateLppByEmployment =
        ArchetypePredicates.canEstimateLppByEmployment(
      employmentStatus: effectiveEmployment,
      hasPensionFund: effectiveEmployment != 'independant',
    );
    final isIndependantNoLpp =
        !canEstimateLppByEmployment && effectiveEmployment == 'independant';
    final isSansEmploi = effectiveEmployment == 'sans_emploi';

    // Estimate LPP balance from age-weighted bonifications since arrival/25.
    // Independent without LPP declaration → 0 balance
    final effectiveLpp = existingLpp ??
        (canEstimateLppByEmployment
            ? _estimateLppBalance(age, grossSalary, arrivalAge: arrivalAge)
            : 0.0);
    if (existingLpp == null) estimatedFields.add('existingLpp');

    // F7-2: Use gender-aware retirement age when gender + birth year are provided.
    // Falls back to male reference age (65) when gender is unknown.
    final effectiveBirthYear = birthYear ?? (DateTime.now().year - age);
    final effectiveRetAge = targetRetirementAge ??
        (gender != null
            ? avsReferenceAge(
                birthYear: effectiveBirthYear, isFemale: gender == 'F')
            : avsAgeReferenceHomme);

    // --- AVS monthly rente (financial_core) ---
    // Sans emploi: use minimum AVS contribution salary
    final avsGrossSalary = isSansEmploi
        ? reg(
            'lpp.entry_threshold', lppSeuilEntree) // minimum contribution base
        : grossSalary;
    // F7-2: Pass gender and birthYear when available so AvsCalculator
    // uses AVS21 reference age (64F / 65M — LAVS art. 21 al. 1).
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: effectiveRetAge,
      // Plumbing du gapFactor : arrivée tardive + lacunes ⇒ années réduites
      // (LAVS art. 29). Même chemin que forecaster_service:826-835 et
      // response_card_service:764 — un Suisse de retour (arrivalAge=43) voit
      // désormais ~1260 CHF/mois, plus jamais la rente MAX 2520 (gapFactor=1.0
      // forcé). Matrice returning_swiss_gaps-1 + §2 « Rente AVS ».
      arrivalAge: arrivalAge,
      anneesContribuees: anneesContribuees,
      lacunes: lacunes,
      grossAnnualSalary: avsGrossSalary,
      isFemale: gender != null ? gender == 'F' : null,
      birthYear: gender != null ? effectiveBirthYear : null,
    );

    // --- LPP projection (financial_core) ---
    double lppAnnualRente;
    if (isIndependantNoLpp || isSansEmploi) {
      // No LPP for independants without caisse or unemployed
      lppAnnualRente = 0.0;
    } else {
      // Caisse complémentaire uses a blended conversion rate (~5.8%)
      // vs standard minimum 6.8% (LPP art. 14 al. 2). Les deux branches
      // utilisent les constantes nommées du registry — plus de littéral inline.
      final effectiveConversionRate = lppCaisseType == 'complementaire'
          ? reg('lpp.conversion_rate_complementaire',
              lppTauxConversionSurobligDecimal)
          : reg('lpp.conversion_rate', lppTauxConversionMinDecimal);
      lppAnnualRente = LppCalculator.projectToRetirement(
        currentBalance: effectiveLpp,
        currentAge: age,
        retirementAge: effectiveRetAge,
        grossAnnualSalary: grossSalary,
        caisseReturn: reg('lpp.min_interest_rate', lppTauxInteretMin) / 100,
        conversionRate: effectiveConversionRate,
      );
    }
    final lppMonthly = lppAnnualRente / 12;

    // --- Debt service impact (donnée budget, surfacée pour l'affichage) ---
    // Le service de la dette est une donnée *budget*, PAS un revenu de retraite.
    // Il n'est plus soustrait du revenu de retraite total (composition canonique
    // = AVS + LPP, alignée sur response_card et retirement_projection_service).
    // Voir financial_core/replacement_rate.dart + matrice D3.
    final effectiveDebtService =
        monthlyDebtService ?? (totalDebts != null ? totalDebts * 0.005 : 0.0);

    // --- Total retirement income (composition canonique : AVS + LPP) ---
    final totalMonthlyRetirement = max(0.0, avsMonthly + lppMonthly);
    final grossMonthlySalary = grossSalary / 12;
    // --- Taux de remplacement : dénominateur NET courant (lock CONTEXT W1) ---
    // Source canonique unique ReplacementRate (financial_core L1) : dénominateur
    // = revenu NET via NetIncomeBreakdown (canton + âge aware), plus le brut.
    // Champ conservé en fraction (0-1) pour les consommateurs historiques.
    final netMonthlyIncome = NetIncomeBreakdown.compute(
      grossSalary: grossSalary,
      canton: canton.isNotEmpty ? canton : 'ZH',
      age: age,
    ).monthlyNetPayslip;
    final replacementRate = ReplacementRate.fraction(
      totalMonthlyRetirement: totalMonthlyRetirement,
      netMonthlyIncome: netMonthlyIncome,
    );
    final retirementGapMonthly =
        max(0.0, grossMonthlySalary - totalMonthlyRetirement);

    // --- Tax saving 3a (financial_core) ---
    // Indépendant sans LPP : plafond = 20% du revenu professionnel NET
    // (OPP3 art. 7 al. 2), JAMAIS du brut nu (finding independent_no_lpp-1).
    // Le NET canonique (NetIncomeBreakdown) déjà calculé pour le taux de
    // remplacement est ré-employé comme base nette annuelle.
    final netProfessionalIncome =
        isIndependantNoLpp ? netMonthlyIncome * 12 : null;
    // État civil câblé jusqu'au barème fiscal 3a (findings salarie_swiss-2/-3) :
    // un marié doit recevoir le barème marié (familyAdjustment 0.85), pas le
    // barème célibataire (1.00). householdType 'couple'/'family' = ménage marié
    // (même sémantique que budget_inputs.dart + _estimateMonthlyExpenses).
    // children : pas exposé dans les inputs du service → 0 (le détail enfants
    // est affiné en aval par response_card quand le profil le porte).
    final isMarriedHousehold =
        effectiveHousehold == 'couple' || effectiveHousehold == 'family';
    final resolvedCanton = resolveCanton(canton);
    // Gate FATCA / frontalier non quasi-résident (plan 08, expat_us-2 +
    // frontalier-1) : si l'archétype n'a pas droit à la déduction 3a en Suisse,
    // n'estime AUCUN impact fiscal — le plafond, l'économie et le taux
    // marginal sont émis à 0 (un US person voyait sinon 7258 CHF actionnables
    // alors que canContribute3a==false).
    final taxImpact =
        canContribute3a && resolvedCanton.isResolved && grossSalary > 0
            ? RetirementTaxCalculator.estimate3aTaxImpact(
                grossAnnualSalary: grossSalary,
                canton: resolvedCanton.code,
                hasLpp: !isIndependantNoLpp,
                isMarried: isMarriedHousehold,
                children: 0,
                netProfessionalIncome: netProfessionalIncome,
                age: age,
              )
            : Pillar3aTaxImpactEstimate.unavailable;
    final marginalRate =
        taxImpact.confidence == Pillar3aTaxImpactConfidence.unavailable
            ? 0.0
            : taxImpact.marginalRate;
    final plafond3a = !canContribute3a
        // Pas de déduction possible → aucun plafond déductible à afficher.
        ? 0.0
        : taxImpact.confidence == Pillar3aTaxImpactConfidence.unavailable
            ? (isIndependantNoLpp
                ? min(
                    (netProfessionalIncome ?? 0.0) * pilier3aTauxRevenuSansLpp,
                    reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp))
                : reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp))
            : taxImpact.annualCeiling;
    final taxSaving3a = taxImpact.estimatedTaxSaving;

    // --- Liquidity analysis (base nette canonique, plus de ratio plat) ---
    final estimatedMonthlyExpenses = _estimateMonthlyExpenses(
      netMonthlyIncome,
      effectiveHousehold,
      effectivePropertyOwner,
    );
    final liquidityMonths = estimatedMonthlyExpenses > 0
        ? effectiveSavings / estimatedMonthlyExpenses
        : 0.0;

    return MinimalProfileResult(
      avsMonthlyRente: avsMonthly,
      lppAnnualRente: lppAnnualRente,
      lppMonthlyRente: lppMonthly,
      totalMonthlyRetirement: totalMonthlyRetirement,
      grossMonthlySalary: grossMonthlySalary,
      replacementRate: replacementRate,
      retirementGapMonthly: retirementGapMonthly,
      taxSaving3a: taxSaving3a,
      marginalTaxRate: marginalRate,
      currentSavings: effectiveSavings,
      estimatedMonthlyExpenses: estimatedMonthlyExpenses,
      monthlyDebtImpact: effectiveDebtService,
      liquidityMonths: liquidityMonths,
      canton: resolvedCanton.isResolved ? resolvedCanton.code : canton,
      age: age,
      grossAnnualSalary: grossSalary,
      householdType: effectiveHousehold,
      isPropertyOwner: effectivePropertyOwner,
      existing3a: effective3a,
      existingLpp: effectiveLpp,
      employmentStatus: employmentStatus ?? effectiveEmployment,
      nationalityGroup: nationalityGroup,
      plafond3a: plafond3a,
      estimatedFields: estimatedFields,
    );
  }

  /// Estimate LPP balance from age and salary using cumulative bonifications.
  ///
  /// Façade qui délègue à la source canonique [LppCalculator.accumulateAvoir]
  /// (financial_core L1) — CLAUDE.md NEVER #3 : pas de calcul dupliqué L1.
  /// [arrivalAge]: démarre l'accumulation à l'arrivée (LPP art. 7), pas
  /// toujours à 25, pour les profils arrivés tardivement en Suisse.
  static double _estimateLppBalance(int age, double grossAnnualSalary,
      {int? arrivalAge}) {
    return LppCalculator.accumulateAvoir(
      currentAge: age,
      grossAnnualSalary: grossAnnualSalary,
      startAge: arrivalAge,
    );
  }

  /// Estimate monthly expenses from canonical NET income and household type.
  ///
  /// Uses typical Swiss expense ratios applied to the canonical monthly NET
  /// ([NetIncomeBreakdown.compute], canton + âge aware) — plus de ratio plat
  /// 0.75 comme proxy de net (base nette unique app-wide, matrice §2 « Marge
  /// libre »). Seuls les ratios de *dépense* par type de ménage restent ici.
  static double _estimateMonthlyExpenses(
    double monthlyNet,
    String householdType,
    bool isPropertyOwner,
  ) {
    // Expense ratio depends on household type (ratio de dépense, pas un proxy
    // de net) : housing 25-30% + LAMal 8-12% + vie courante 30-40%.
    final expenseRatio = switch (householdType) {
      'single' => 0.80,
      'couple' => 0.75,
      'family' => 0.85,
      _ => 0.80,
    };

    return monthlyNet * expenseRatio;
  }
}
