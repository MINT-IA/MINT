import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD SERVICE — Phase 1 / Dynamic Cards
// ────────────────────────────────────────────────────────────
//
//  Genere des ResponseCards contextuelles depuis le profil.
//  Chaque carte porte un chiffre-choc, un CTA educatif,
//  un urgency level et des sources legales.
//
//  Aucun calcul duplique : delegue a financial_core/.
//  Aucun terme banni. Educatif uniquement.
// ────────────────────────────────────────────────────────────

class ResponseCardService {
  ResponseCardService._();

  /// Genere les cartes prioritaires pour le dashboard Pulse.
  /// Max [limit] cartes, triees par urgence puis impact.
  static List<ResponseCard> generateForPulse(
    CoachProfile profile, {
    required S l,
    int limit = 3,
    VisibilityScore? visibilityScore,
  }) {
    final cards = <ResponseCard>[];

    // 1. Pilier 3a (deadline annuelle)
    final card3a = _tryPillar3a(profile, l);
    if (card3a != null) cards.add(card3a);

    // 2. Rachat LPP (si rachat possible)
    final cardLpp = _tryLppBuyback(profile, l);
    if (cardLpp != null) cards.add(cardLpp);

    // 3. Taux de remplacement (si > 45 ans)
    final cardRepl = _tryReplacementRate(profile, l);
    if (cardRepl != null) cards.add(cardRepl);

    // 4. Lacune AVS (expats)
    final cardAvs = _tryAvsGap(profile, l);
    if (cardAvs != null) cards.add(cardAvs);

    // 5. Couple alert (si score gap > 15)
    if (visibilityScore != null) {
      final cardCouple = _tryCoupleAlert(profile, visibilityScore, l);
      if (cardCouple != null) cards.add(cardCouple);
    }

    // 6. Independant (couverture lacunaire)
    final cardIndep = _tryIndependant(profile, l);
    if (cardIndep != null) cards.add(cardIndep);

    // 7. Fiscalite (deductions)
    final cardTax = _tryTaxOptimization(profile, l);
    if (cardTax != null) cards.add(cardTax);

    // 8. Patrimoine (diversification)
    final cardPatrimoine = _tryPatrimoine(profile, l);
    if (cardPatrimoine != null) cards.add(cardPatrimoine);

    // Tri : high urgency d'abord, puis impact decroissant
    cards.sort((a, b) {
      final urgComp = b.urgency.index.compareTo(a.urgency.index);
      if (urgComp != 0) return urgComp;
      return b.impactPoints.compareTo(a.impactPoints);
    });

    return cards.take(limit).toList();
  }

  /// Genere des cartes pour le chat Coach, basees sur le topic.
  ///
  /// S49 Phase 3: 27+ topics couverts — chaque simulateur accessible
  /// via une Response Card dans le coach.
  static List<ResponseCard> generateForChat(
    CoachProfile profile,
    String userMessage, {
    required S l,
  }) {
    final lower = userMessage.toLowerCase();
    final cards = <ResponseCard>[];

    // ── Prevoyance & Retraite ────────────────────────────
    if (lower.contains('3a') || lower.contains('pilier')) {
      final c = _tryPillar3a(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      final c = _tryLppBuyback(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('retraite') || lower.contains('rente')) {
      final c = _tryReplacementRate(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('avs')) {
      final c = _tryAvsGap(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('libre passage')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'libre_passage',
        title: l.rcLibrePassageTitle,
        subtitle: l.rcLibrePassageSubtitle,
        route: '/libre-passage',
        sources: ['LPP art. 2', 'LFLP art. 4'],
      ));
    }
    if ((lower.contains('capital') && lower.contains('rente')) ||
        lower.contains('rente ou capital') ||
        lower.contains('rente vs capital')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'rente_vs_capital',
        title: l.rcRenteVsCapitalTitle,
        subtitle: l.rcRenteVsCapitalSubtitle,
        route: '/rente-vs-capital',
        sources: ['LPP art. 37', 'LIFD art. 22/38'],
      ));
    }

    // ── Fiscalite ────────────────────────────────────────
    if (lower.contains('impot') ||
        lower.contains('fiscal') ||
        lower.contains('deduction')) {
      final c = _tryTaxOptimization(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('canton') &&
        (lower.contains('compar') ||
            lower.contains('demenag') ||
            lower.contains('moins cher'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'fiscal_comparator',
        title: l.rcFiscalComparatorTitle,
        subtitle: l.rcFiscalComparatorSubtitle,
        route: '/fiscal',
        sources: ['LIFD art. 1', 'LHID'],
      ));
    }
    if ((lower.contains('retrait') && lower.contains('echelon')) ||
        (lower.contains('retrait 3a') && lower.contains('plusieur'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'staggered_withdrawal',
        title: l.rcStaggeredWithdrawalTitle,
        subtitle: l.rcStaggeredWithdrawalSubtitle,
        route: '/3a-deep/staggered-withdrawal',
        sources: ['LIFD art. 38', 'OPP3 art. 3'],
      ));
    }
    if ((lower.contains('rendement') && lower.contains('3a')) ||
        lower.contains('rendement r\u00e9el')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'real_return_3a',
        title: l.rcRealReturn3aTitle,
        subtitle: l.rcRealReturn3aSubtitle,
        route: '/3a-deep/real-return',
        sources: ['OPP3 art. 7'],
      ));
    }
    if ((lower.contains('prestataire') && lower.contains('3a')) ||
        lower.contains('viac') ||
        lower.contains('finpension') ||
        lower.contains('frankly')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'comparator_3a',
        title: l.rcComparator3aTitle,
        subtitle: l.rcComparator3aSubtitle,
        route: '/3a-deep/comparator',
        sources: ['OPP3 art. 7'],
      ));
    }

    // ── Immobilier ───────────────────────────────────────
    if (lower.contains('hypothe') ||
        lower.contains('immobili') ||
        lower.contains('acheter') ||
        lower.contains('maison')) {
      final c = _tryMortgage(profile, l);
      if (c != null) cards.add(c);
    }
    if ((lower.contains('louer') && lower.contains('acheter')) ||
        (lower.contains('location') && lower.contains('propriet'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'rent_vs_buy',
        title: l.rcRentVsBuyTitle,
        subtitle: l.rcRentVsBuySubtitle,
        route: '/arbitrage/location-vs-propriete',
        sources: ['CO art. 253ss', 'FINMA circ.'],
      ));
    }
    if (lower.contains('amortiss') || lower.contains('amortir')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'amortization',
        title: l.rcAmortizationTitle,
        subtitle: l.rcAmortizationSubtitle,
        route: '/mortgage/amortization',
        sources: ['LIFD art. 33', 'CO art. 793ss'],
      ));
    }
    if (lower.contains('valeur locative')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'imputed_rental',
        title: l.rcImputedRentalTitle,
        subtitle: l.rcImputedRentalSubtitle,
        route: '/mortgage/imputed-rental',
        sources: ['LIFD art. 21 al. 1 let. b'],
      ));
    }
    if (lower.contains('saron') ||
        (lower.contains('taux fixe') && lower.contains('hypo'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'saron_vs_fixed',
        title: l.rcSaronVsFixedTitle,
        subtitle: l.rcSaronVsFixedSubtitle,
        route: '/mortgage/saron-vs-fixed',
        sources: ['FINMA circ.', 'ASB directives'],
      ));
    }
    if (lower.contains('epl') ||
        lower.contains('retrait anticip') ||
        lower.contains('2e pilier') && lower.contains('achet')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'epl',
        title: l.rcEplTitle,
        subtitle: l.rcEplSubtitle,
        route: '/epl',
        sources: ['OPP2 art. 5', 'LPP art. 30c-30g'],
      ));
    }
    if (lower.contains('vend') &&
        (lower.contains('maison') ||
            lower.contains('appartement') ||
            lower.contains('immob'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'housing_sale',
        title: l.rcHousingSaleTitle,
        subtitle: l.rcHousingSaleSubtitle,
        route: '/life-event/housing-sale',
        sources: ['LHID art. 12'],
      ));
    }

    // ── Famille ──────────────────────────────────────────
    if (lower.contains('mari') && !lower.contains('marche')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'mariage',
        title: l.rcMariageTitle,
        subtitle: l.rcMariageSubtitle,
        route: '/mariage',
        sources: ['CC art. 159', 'LAVS art. 35'],
      ));
    }
    if (lower.contains('divorc') || lower.contains('separat')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'divorce',
        title: l.rcDivorceTitle,
        subtitle: l.rcDivorceSubtitle,
        route: '/divorce',
        sources: ['CC art. 122-124', 'LPP art. 22'],
      ));
    }
    if (lower.contains('enfant') ||
        lower.contains('naissance') ||
        lower.contains('bebe')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'naissance',
        title: l.rcNaissanceTitle,
        subtitle: l.rcNaissanceSubtitle,
        route: '/naissance',
        sources: ['LAFam art. 3', 'LIFD art. 35'],
      ));
    }
    if (lower.contains('concubin') || lower.contains('pas marie')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'concubinage',
        title: l.rcConcubinageTitle,
        subtitle: l.rcConcubinageSubtitle,
        route: '/concubinage',
        sources: ['CC art. 462', 'LPP art. 20a'],
      ));
    }
    if (lower.contains('succession') ||
        lower.contains('herit') ||
        lower.contains('deces') && lower.contains('proche')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'succession',
        title: l.rcSuccessionTitle,
        subtitle: l.rcSuccessionSubtitle,
        route: '/succession',
        sources: ['CC art. 457-640', 'LIFD art. 24'],
      ));
    }
    if (lower.contains('donat') ||
        (lower.contains('donner') && lower.contains('enfant'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'donation',
        title: l.rcDonationTitle,
        subtitle: l.rcDonationSubtitle,
        route: '/life-event/donation',
        sources: ['LHID art. 14'],
      ));
    }

    // ── Emploi & Statut ──────────────────────────────────
    if (lower.contains('independant') ||
        lower.contains('indep') ||
        lower.contains('mon compte')) {
      final c = _tryIndependant(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('chomage') ||
        lower.contains('emploi') && lower.contains('perdu') ||
        lower.contains('licenci')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'unemployment',
        title: l.rcUnemploymentTitle,
        subtitle: l.rcUnemploymentSubtitle,
        route: '/unemployment',
        sources: ['LACI art. 8-27'],
      ));
    }
    if ((lower.contains('premier') && lower.contains('emploi')) ||
        lower.contains('premier job') ||
        (lower.contains('debut') && lower.contains('carri'))) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'first_job',
        title: l.rcFirstJobTitle,
        subtitle: l.rcFirstJobSubtitle,
        route: '/first-job',
        sources: ['LAVS art. 3', 'LPP art. 7'],
      ));
    }
    if (lower.contains('expat') ||
        lower.contains('etranger') ||
        lower.contains('quitt') && lower.contains('suisse')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'expatriation',
        title: l.rcExpatriationTitle,
        subtitle: l.rcExpatriationSubtitle,
        route: '/expatriation',
        sources: ['LAVS art. 1a', 'ALCP', 'CDI'],
      ));
    }
    if (lower.contains('frontalier') ||
        lower.contains('permis g') ||
        lower.contains('travail') && lower.contains('france')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'frontalier',
        title: l.rcFrontalierTitle,
        subtitle: l.rcFrontalierSubtitle,
        route: '/segments/frontalier',
        sources: ['CDI CH-FR art. 17', 'LIFD art. 83-101'],
      ));
    }
    if ((lower.contains('compar') && lower.contains('offre')) ||
        (lower.contains('compar') && lower.contains('emploi')) ||
        lower.contains('deux offres')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'job_comparison',
        title: l.rcJobComparisonTitle,
        subtitle: l.rcJobComparisonSubtitle,
        route: '/simulator/job-comparison',
        sources: ['CO art. 319ss'],
      ));
    }
    if (lower.contains('dividende') ||
        lower.contains('salaire') && lower.contains('sarl')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'dividende_vs_salaire',
        title: l.rcDividendeVsSalaireTitle,
        subtitle: l.rcDividendeVsSalaireSubtitle,
        route: '/independants/dividende-salaire',
        sources: ['LIFD art. 20', 'LAVS art. 4'],
      ));
    }

    // ── Assurance & Sante ────────────────────────────────
    if (lower.contains('lamal') ||
        lower.contains('franchise') ||
        lower.contains('caisse maladie')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'lamal_franchise',
        title: l.rcLamalFranchiseTitle,
        subtitle: l.rcLamalFranchiseSubtitle,
        route: '/assurances/lamal',
        sources: ['LAMal art. 64', 'OAMal art. 103'],
      ));
    }
    if (lower.contains('assur') && lower.contains('couvert') ||
        lower.contains('bien assur') ||
        lower.contains('lacune') && lower.contains('assur')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'coverage_check',
        title: l.rcCoverageCheckTitle,
        subtitle: l.rcCoverageCheckSubtitle,
        route: '/assurances/coverage',
        sources: ['LAMal', 'LCA'],
      ));
    }
    if (lower.contains('invalid') ||
        lower.contains('incapacit') ||
        lower.contains('accident')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'disability',
        title: l.rcDisabilityTitle,
        subtitle: l.rcDisabilitySubtitle,
        route: '/invalidite',
        sources: ['LAI art. 28-28a', 'LPP art. 23-26'],
      ));
    }
    if (lower.contains('gender') ||
        lower.contains('ecart') && lower.contains('femme')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'gender_gap',
        title: l.rcGenderGapTitle,
        subtitle: l.rcGenderGapSubtitle,
        route: '/segments/gender-gap',
        sources: ['LAVS art. 29', 'LPP art. 7-8'],
      ));
    }

    // ── Budget & Dette ───────────────────────────────────
    if (lower.contains('patrimoine') || lower.contains('epargne')) {
      final c = _tryPatrimoine(profile, l);
      if (c != null) cards.add(c);
    }
    if (lower.contains('budget') ||
        lower.contains('reste a vivre') ||
        lower.contains('depense')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'budget',
        title: l.rcBudgetTitle,
        subtitle: l.rcBudgetSubtitle,
        route: '/budget',
        sources: [],
      ));
    }
    if (lower.contains('dette') ||
        lower.contains('credit') && !lower.contains('credit conso')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'debt_ratio',
        title: l.rcDebtRatioTitle,
        subtitle: l.rcDebtRatioSubtitle,
        route: '/debt/ratio',
        sources: ['CO art. 305ss'],
      ));
    }

    // ── Simulateurs divers ───────────────────────────────
    if (lower.contains('interet compose') ||
        lower.contains('interets composes') ||
        lower.contains('combien rapport')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'compound_interest',
        title: l.rcCompoundInterestTitle,
        subtitle: l.rcCompoundInterestSubtitle,
        route: '/simulator/compound',
        sources: [],
      ));
    }
    if (lower.contains('leasing')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'leasing',
        title: l.rcLeasingTitle,
        subtitle: l.rcLeasingSubtitle,
        route: '/simulator/leasing',
        sources: [],
      ));
    }
    if (lower.contains('credit conso') || lower.contains('pret personnel')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'consumer_credit',
        title: l.rcConsumerCreditTitle,
        subtitle: l.rcConsumerCreditSubtitle,
        route: '/simulator/credit',
        sources: ['LCC art. 1'],
      ));
    }
    if (lower.contains('allocation') && lower.contains('annuel') ||
        lower.contains('10k') && lower.contains('mettre')) {
      cards.add(_buildSimpleCard(
        l: l,
        id: 'allocation_annuelle',
        title: l.rcAllocationAnnuelleTitle,
        subtitle: l.rcAllocationAnnuelleSubtitle,
        route: '/arbitrage/allocation-annuelle',
        sources: ['LSFin art. 3'],
      ));
    }

    // Deduplicate by id and limit to 2 cards
    final seen = <String>{};
    final unique = cards.where((c) => seen.add(c.id)).toList();
    return unique.take(2).toList();
  }

  /// Suggested prompts personnalises selon le profil.
  /// Un 50+ voit "Quand partir a la retraite ?" au lieu de "Mon score Fitness".
  static List<String> suggestedPrompts(CoachProfile profile, {required S l}) {
    final age = profile.age;
    final isIndep = profile.employmentStatus == 'independant';
    final isCouple = profile.isCouple;
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;

    final prompts = <String>[];

    // Age-driven priorities
    if (age >= 50) {
      prompts.add(l.rcSuggestedPrompt50PlusRetirement);
      prompts.add(l.rcSuggestedPromptRenteOuCapital);
      if (!hasLpp) prompts.add(l.rcSuggestedPromptRachatLpp);
    } else if (age >= 35) {
      prompts.add(l.rcSuggestedPromptAllegerImpots);
      prompts.add(l.rcSuggestedPromptVersement3a);
      if (!hasLpp) prompts.add(l.rcSuggestedPromptRachatLpp);
    } else {
      prompts.add(l.rcSuggestedPromptCommencer3a);
      prompts.add(l.rcSuggestedPrompt2ePilier);
    }

    // Archetype-driven
    if (isIndep) {
      prompts.add(l.rcSuggestedPromptIndependant);
    }
    if (isCouple) {
      prompts.add(l.rcSuggestedPromptCouple);
    }
    if (profile.archetype == FinancialArchetype.expatUs) {
      prompts.add(l.rcSuggestedPromptFatca);
    }

    return prompts.take(3).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  CARD GENERATORS
  // ════════════════════════════════════════════════════════════

  static ResponseCard? _tryPillar3a(CoachProfile profile, S l) {
    if (profile.salaireBrutMensuel <= 0) return null;

    final isIndep = profile.employmentStatus == 'independant';
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    final plafond =
        isIndep && !hasLpp ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;

    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      profile.revenuBrutAnnuel,
      profile.canton,
    );
    final taxSaving = plafond * marginalRate;

    // Deadline: 31 decembre de l'annee en cours
    final now = DateTime.now();
    final deadline = DateTime(now.year, 12, 31);
    final daysLeft = deadline.difference(now).inDays;

    return ResponseCard(
      id: 'pillar_3a_${now.year}',
      type: ResponseCardType.pillar3a,
      title: l.rcPillar3aTitle(now.year.toString()),
      subtitle: l.rcPillar3aSubtitle,
      chiffreChoc: ChiffreChoc(
        value: taxSaving,
        unit: 'CHF',
        explanation: l.rcPillar3aExplanation(plafond.round().toString()),
      ),
      cta: CardCta(
        label: l.rcPillar3aCtaLabel,
        route: '/pilier-3a',
        icon: 'savings',
      ),
      urgency: daysLeft <= 30
          ? CardUrgency.high
          : daysLeft <= 90
              ? CardUrgency.medium
              : CardUrgency.low,
      deadline: deadline,
      disclaimer: l.rcDisclaimer,
      sources: const ['OPP3 art. 7', 'LIFD art. 33 al. 1 let. e'],
      impactPoints: 18,
    );
  }

  static ResponseCard? _tryLppBuyback(CoachProfile profile, S l) {
    final rachatMax = profile.prevoyance.rachatMaximum ?? 0;
    if (rachatMax <= 0) return null;
    if (profile.salaireBrutMensuel <= 0) return null;

    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      profile.revenuBrutAnnuel,
      profile.canton,
    );

    // Economie fiscale sur rachat de 10k (ou rachat max si < 10k)
    final rachatSimule = rachatMax.clamp(0.0, 10000.0);
    final taxSaving = rachatSimule * marginalRate;

    return ResponseCard(
      id: 'lpp_buyback',
      type: ResponseCardType.lppBuyback,
      title: l.rcLppBuybackTitle,
      subtitle: l.rcLppBuybackSubtitle,
      chiffreChoc: ChiffreChoc(
        value: rachatMax,
        unit: 'CHF',
        explanation: l.rcLppBuybackExplanation(
          taxSaving.round().toString(),
          rachatSimule.round().toString(),
        ),
      ),
      cta: CardCta(
        label: l.rcLppBuybackCtaLabel,
        route: '/rachat-lpp',
        icon: 'account_balance',
      ),
      urgency: CardUrgency.low,
      disclaimer: l.rcDisclaimer,
      sources: const ['LPP art. 79b', 'LIFD art. 33 al. 1 let. d'],
      impactPoints: 20,
    );
  }

  static ResponseCard? _tryReplacementRate(CoachProfile profile, S l) {
    if (profile.age < 45) return null;
    if (profile.age >= profile.effectiveRetirementAge) return null;
    if (profile.salaireBrutMensuel <= 0) return null;

    // Use ForecasterService-style projection
    final monthlyAvs = AvsCalculator.computeMonthlyRente(
      currentAge: profile.age,
      retirementAge: profile.effectiveRetirementAge,
      arrivalAge: profile.arrivalAge,
      grossAnnualSalary: profile.revenuBrutAnnuel,
    );

    final lppAvoir = profile.prevoyance.avoirLppTotal ?? 0;
    final lppMonthly = lppAvoir > 0
        ? (lppAvoir * lppTauxConversionSurobligDecimal / 12) // conservative 5.4% (suroblig estimate)
        : 0.0;

    final totalMonthly = monthlyAvs + lppMonthly;
    // Use NetIncomeBreakdown for consistent net calculation (same as Pulse)
    final currentMonthly = NetIncomeBreakdown.compute(
      grossSalary: profile.revenuBrutAnnuel,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: profile.age,
    ).monthlyNetPayslip;
    final replacementRate =
        currentMonthly > 0 ? (totalMonthly / currentMonthly * 100) : 0.0;

    return ResponseCard(
      id: 'replacement_rate',
      type: ResponseCardType.replacementRate,
      title: l.rcReplacementRateTitle,
      subtitle: l.rcReplacementRateSubtitle(
          profile.effectiveRetirementAge.toString()),
      chiffreChoc: ChiffreChoc(
        value: replacementRate,
        unit: '%',
        explanation: l.rcReplacementRateExplanation(
          totalMonthly.round().toString(),
          currentMonthly.round().toString(),
        ),
      ),
      cta: CardCta(
        label: l.rcReplacementRateCtaLabel,
        route: '/rente-vs-capital',
        icon: 'trending_up',
      ),
      urgency: profile.age >= 58 ? CardUrgency.high : CardUrgency.medium,
      disclaimer: l.rcDisclaimer,
      sources: const ['LAVS art. 29-40', 'LPP art. 14'],
      alertes: [
        if (replacementRate < 60) l.rcReplacementRateAlerte,
      ],
      impactPoints: 22,
    );
  }

  static ResponseCard? _tryAvsGap(CoachProfile profile, S l) {
    if (profile.arrivalAge == null) return null;
    if (profile.arrivalAge! <= 20) return null;

    // Lacunes = annees entre 20 et arrivalAge
    final lacunes = (profile.arrivalAge! - 20).clamp(0, 44);
    if (lacunes <= 0) return null;

    const fullRenteMonthly = avsRenteMaxAnnuelle / 12;
    const reductionPerYear = fullRenteMonthly / 44;
    final monthlyLoss = reductionPerYear * lacunes;

    return ResponseCard(
      id: 'avs_gap',
      type: ResponseCardType.avsGap,
      title: l.rcAvsGapTitle,
      subtitle: l.rcAvsGapSubtitle(lacunes.toString()),
      chiffreChoc: ChiffreChoc(
        value: monthlyLoss * 12,
        unit: 'CHF/an',
        explanation: l.rcAvsGapExplanation,
      ),
      cta: CardCta(
        label: l.rcAvsGapCtaLabel,
        route: '/profile/bilan',
        icon: 'verified_user',
      ),
      urgency: lacunes >= 5 ? CardUrgency.medium : CardUrgency.low,
      disclaimer: l.rcDisclaimer,
      sources: const ['LAVS art. 29 al. 2', 'RAVS art. 52b'],
      impactPoints: 15,
    );
  }

  static ResponseCard? _tryCoupleAlert(
    CoachProfile profile,
    VisibilityScore score,
    S l,
  ) {
    if (!profile.isCouple) return null;
    if (score.coupleWeakName == null || score.coupleWeakScore == null) {
      return null;
    }

    final gap = score.total - score.coupleWeakScore!;
    if (gap <= 15) return null;

    return ResponseCard(
      id: 'couple_alert',
      type: ResponseCardType.coupleAlert,
      title: l.rcCoupleAlertTitle,
      subtitle: l.rcCoupleAlertSubtitle(
        score.coupleWeakName!,
        score.coupleWeakScore!.round().toString(),
      ),
      chiffreChoc: ChiffreChoc(
        value: gap,
        unit: l.rcUnitPts,
        explanation: l.rcCoupleAlertExplanation(gap.round().toString()),
      ),
      cta: CardCta(
        label: l.rcCoupleAlertCtaLabel,
        route: '/couple',
        icon: 'family_restroom',
      ),
      urgency: gap >= 25 ? CardUrgency.high : CardUrgency.medium,
      disclaimer: l.rcDisclaimer,
      sources: const ['CC art. 159', 'LPP art. 19'],
      impactPoints: 16,
    );
  }

  static ResponseCard? _tryIndependant(CoachProfile profile, S l) {
    if (profile.employmentStatus != 'independant') return null;

    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    if (hasLpp) return null; // Covered by LPP card

    const max3a = pilier3aPlafondSansLpp;
    final current3a = profile.prevoyance.totalEpargne3a;

    return ResponseCard(
      id: 'independant_coverage',
      type: ResponseCardType.independant,
      title: l.rcIndependantTitle,
      subtitle: l.rcIndependantSubtitle,
      chiffreChoc: ChiffreChoc(
        value: max3a,
        unit: 'CHF/an',
        explanation: l.rcIndependantExplanation(
          max3a.round().toString(),
          current3a.round().toString(),
        ),
      ),
      cta: CardCta(
        label: l.rcIndependantCtaLabel,
        route: '/pilier-3a',
        icon: 'savings',
      ),
      urgency: CardUrgency.medium,
      disclaimer: l.rcDisclaimer,
      sources: const ['OPP3 art. 7 al. 2', 'LIFD art. 33 al. 1 let. e'],
      impactPoints: 20,
    );
  }

  static ResponseCard? _tryTaxOptimization(CoachProfile profile, S l) {
    if (profile.salaireBrutMensuel <= 0) return null;
    if (profile.age < 25) return null;

    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      profile.revenuBrutAnnuel,
      profile.canton,
    );

    // Total deductible: 3a + rachat LPP potentiel
    final plafond3a = profile.employmentStatus == 'independant' &&
            (profile.prevoyance.avoirLppTotal ?? 0) <= 0
        ? pilier3aPlafondSansLpp
        : pilier3aPlafondAvecLpp;
    final rachat = profile.prevoyance.rachatMaximum ?? 0;
    final totalDeductible = plafond3a + rachat.clamp(0.0, 20000.0);
    final totalSaving = totalDeductible * marginalRate;

    if (totalSaving < 500) return null; // Pas assez impactant

    return ResponseCard(
      id: 'tax_optimization',
      type: ResponseCardType.taxOptimization,
      title: l.rcTaxOptTitle,
      subtitle: l.rcTaxOptSubtitle,
      chiffreChoc: ChiffreChoc(
        value: totalSaving,
        unit: 'CHF',
        explanation: l.rcTaxOptExplanation(plafond3a.round().toString()),
      ),
      cta: CardCta(
        label: l.rcTaxOptCtaLabel,
        route: '/fiscal',
        icon: 'receipt_long',
      ),
      urgency: CardUrgency.low,
      disclaimer: l.rcDisclaimer,
      sources: const ['LIFD art. 33', 'LIFD art. 33 al. 1 let. d-e'],
      impactPoints: 17,
    );
  }

  static ResponseCard? _tryPatrimoine(CoachProfile profile, S l) {
    final epargne = profile.patrimoine.epargneLiquide;
    final investissements = profile.patrimoine.investissements;
    final total = epargne + investissements;

    if (total <= 0) return null;

    // Coussin securite: 3-6 mois de charges
    final chargesMensuelles = profile.depenses.totalMensuel > 0
        ? profile.depenses.totalMensuel
        : profile.salaireBrutMensuel * 0.65; // estimation
    final coussinMin = chargesMensuelles * 3;

    final isUnderCushion = epargne < coussinMin;

    return ResponseCard(
      id: 'patrimoine_overview',
      type: ResponseCardType.patrimoine,
      title: l.rcPatrimoineTitle,
      subtitle: isUnderCushion
          ? l.rcPatrimoineSubtitleLow
          : l.rcPatrimoineSubtitleOk,
      chiffreChoc: ChiffreChoc(
        value: total,
        unit: 'CHF',
        explanation: isUnderCushion
            ? l.rcPatrimoineExplanationLow(
                epargne.round().toString(),
                coussinMin.round().toString(),
              )
            : l.rcPatrimoineExplanationOk(
                epargne.round().toString(),
                investissements.round().toString(),
              ),
      ),
      cta: CardCta(
        label: isUnderCushion
            ? l.rcPatrimoineCtaLabelLow
            : l.rcPatrimoineCtaLabelOk,
        route: isUnderCushion ? '/budget' : '/profile/bilan',
        icon: isUnderCushion ? 'account_balance_wallet' : 'trending_up',
      ),
      urgency: isUnderCushion ? CardUrgency.medium : CardUrgency.low,
      disclaimer: l.rcDisclaimer,
      sources: const [],
      alertes: [
        if (isUnderCushion)
          l.rcPatrimoineAlerte(coussinMin.round().toString()),
      ],
      impactPoints: 12,
    );
  }

  /// Helper: build a simple Response Card for topics without profile-driven
  /// calculations. Used for the 27 inline coach simulators (Phase 3).
  static ResponseCard _buildSimpleCard({
    required S l,
    required String id,
    required String title,
    required String subtitle,
    required String route,
    List<String> sources = const [],
  }) {
    return ResponseCard(
      id: id,
      type: ResponseCardType
          .pillar3a, // generic — type is secondary for simple cards
      title: title,
      subtitle: subtitle,
      chiffreChoc: const ChiffreChoc(
        value: 0,
        unit: '',
        explanation: '',
      ),
      cta: CardCta(label: l.rcCtaDetail, route: route),
      disclaimer: l.rcDisclaimer,
      sources: sources,
      impactPoints: 10,
    );
  }

  static ResponseCard? _tryMortgage(CoachProfile profile, S l) {
    if (profile.salaireBrutMensuel <= 0) return null;
    if (profile.patrimoine.mortgageBalance == null &&
        profile.patrimoine.propertyMarketValue == null) {
      return null;
    }

    final mortgage = profile.patrimoine.mortgageBalance ?? 0;
    if (mortgage <= 0) return null;

    final propertyValue = profile.patrimoine.propertyMarketValue ?? 0;
    final ltv = propertyValue > 0 ? (mortgage / propertyValue * 100) : 0.0;

    return ResponseCard(
      id: 'mortgage_overview',
      type: ResponseCardType.mortgage,
      title: l.rcMortgageTitle,
      subtitle: l.rcMortgageSubtitle(ltv.toStringAsFixed(0)),
      chiffreChoc: ChiffreChoc(
        value: mortgage,
        unit: 'CHF',
        explanation:
            l.rcMortgageExplanation(propertyValue.round().toString()),
      ),
      cta: CardCta(
        label: l.rcMortgageCtaLabel,
        route: '/hypotheque',
        icon: 'home',
      ),
      urgency: ltv > 80 ? CardUrgency.medium : CardUrgency.low,
      disclaimer: l.rcDisclaimer,
      sources: const ['FINMA circ. 2012/2', 'ASB directives'],
      impactPoints: 14,
    );
  }
}
