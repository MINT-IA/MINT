import 'package:mint_mobile/constants/social_insurance.dart';
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

  static const _disclaimer =
      'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin art. 3).';

  /// Genere les cartes prioritaires pour le dashboard Pulse.
  /// Max [limit] cartes, triees par urgence puis impact.
  static List<ResponseCard> generateForPulse(
    CoachProfile profile, {
    int limit = 3,
    VisibilityScore? visibilityScore,
  }) {
    final cards = <ResponseCard>[];

    // 1. Pilier 3a (deadline annuelle)
    final card3a = _tryPillar3a(profile);
    if (card3a != null) cards.add(card3a);

    // 2. Rachat LPP (si rachat possible)
    final cardLpp = _tryLppBuyback(profile);
    if (cardLpp != null) cards.add(cardLpp);

    // 3. Taux de remplacement (si > 45 ans)
    final cardRepl = _tryReplacementRate(profile);
    if (cardRepl != null) cards.add(cardRepl);

    // 4. Lacune AVS (expats)
    final cardAvs = _tryAvsGap(profile);
    if (cardAvs != null) cards.add(cardAvs);

    // 5. Couple alert (si score gap > 15)
    if (visibilityScore != null) {
      final cardCouple = _tryCoupleAlert(profile, visibilityScore);
      if (cardCouple != null) cards.add(cardCouple);
    }

    // 6. Independant (couverture lacunaire)
    final cardIndep = _tryIndependant(profile);
    if (cardIndep != null) cards.add(cardIndep);

    // 7. Fiscalite (deductions)
    final cardTax = _tryTaxOptimization(profile);
    if (cardTax != null) cards.add(cardTax);

    // 8. Patrimoine (diversification)
    final cardPatrimoine = _tryPatrimoine(profile);
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
    String userMessage,
  ) {
    final lower = userMessage.toLowerCase();
    final cards = <ResponseCard>[];

    // ── Prevoyance & Retraite ────────────────────────────
    if (lower.contains('3a') || lower.contains('pilier')) {
      final c = _tryPillar3a(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      final c = _tryLppBuyback(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('retraite') || lower.contains('rente')) {
      final c = _tryReplacementRate(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('avs')) {
      final c = _tryAvsGap(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('libre passage')) {
      cards.add(_buildSimpleCard(
        id: 'libre_passage',
        title: 'Libre passage',
        subtitle: 'Que faire de ton avoir de libre passage',
        route: '/libre-passage',
        sources: ['LPP art. 2', 'LFLP art. 4'],
      ));
    }
    if ((lower.contains('capital') && lower.contains('rente')) ||
        lower.contains('rente ou capital') ||
        lower.contains('rente vs capital')) {
      cards.add(_buildSimpleCard(
        id: 'rente_vs_capital',
        title: 'Rente vs Capital',
        subtitle: 'Quel choix te convient ?',
        route: '/rente-vs-capital',
        sources: ['LPP art. 37', 'LIFD art. 22/38'],
      ));
    }

    // ── Fiscalite ────────────────────────────────────────
    if (lower.contains('impot') ||
        lower.contains('fiscal') ||
        lower.contains('deduction')) {
      final c = _tryTaxOptimization(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('canton') &&
        (lower.contains('compar') ||
            lower.contains('demenag') ||
            lower.contains('moins cher'))) {
      cards.add(_buildSimpleCard(
        id: 'fiscal_comparator',
        title: 'Comparateur cantonal',
        subtitle: 'Compare la charge fiscale entre cantons',
        route: '/fiscal',
        sources: ['LIFD art. 1', 'LHID'],
      ));
    }
    if ((lower.contains('retrait') && lower.contains('echelon')) ||
        (lower.contains('retrait 3a') && lower.contains('plusieur'))) {
      cards.add(_buildSimpleCard(
        id: 'staggered_withdrawal',
        title: 'Retrait 3a \u00e9chelonn\u00e9',
        subtitle: '\u00c9taler les retraits pour r\u00e9duire l\'imp\u00f4t',
        route: '/3a-deep/staggered-withdrawal',
        sources: ['LIFD art. 38', 'OPP3 art. 3'],
      ));
    }
    if ((lower.contains('rendement') && lower.contains('3a')) ||
        lower.contains('rendement r\u00e9el')) {
      cards.add(_buildSimpleCard(
        id: 'real_return_3a',
        title: 'Rendement r\u00e9el 3a',
        subtitle: 'Rendement apr\u00e8s frais, inflation et fiscal',
        route: '/3a-deep/real-return',
        sources: ['OPP3 art. 7'],
      ));
    }
    if ((lower.contains('prestataire') && lower.contains('3a')) ||
        lower.contains('viac') ||
        lower.contains('finpension') ||
        lower.contains('frankly')) {
      cards.add(_buildSimpleCard(
        id: 'comparator_3a',
        title: 'Comparateur 3a',
        subtitle: 'Compare les prestataires 3a',
        route: '/3a-deep/comparator',
        sources: ['OPP3 art. 7'],
      ));
    }

    // ── Immobilier ───────────────────────────────────────
    if (lower.contains('hypothe') ||
        lower.contains('immobili') ||
        lower.contains('acheter') ||
        lower.contains('maison')) {
      final c = _tryMortgage(profile);
      if (c != null) cards.add(c);
    }
    if ((lower.contains('louer') && lower.contains('acheter')) ||
        (lower.contains('location') && lower.contains('propriet'))) {
      cards.add(_buildSimpleCard(
        id: 'rent_vs_buy',
        title: 'Louer ou acheter',
        subtitle: 'Compare les deux sc\u00e9narios sur le long terme',
        route: '/arbitrage/location-vs-propriete',
        sources: ['CO art. 253ss', 'FINMA circ.'],
      ));
    }
    if (lower.contains('amortiss') || lower.contains('amortir')) {
      cards.add(_buildSimpleCard(
        id: 'amortization',
        title: 'Amortissement',
        subtitle: 'Direct vs indirect — quel impact fiscal',
        route: '/mortgage/amortization',
        sources: ['LIFD art. 33', 'CO art. 793ss'],
      ));
    }
    if (lower.contains('valeur locative')) {
      cards.add(_buildSimpleCard(
        id: 'imputed_rental',
        title: 'Valeur locative',
        subtitle: 'Comprendre l\'imposition du logement',
        route: '/mortgage/imputed-rental',
        sources: ['LIFD art. 21 al. 1 let. b'],
      ));
    }
    if (lower.contains('saron') ||
        (lower.contains('taux fixe') && lower.contains('hypo'))) {
      cards.add(_buildSimpleCard(
        id: 'saron_vs_fixed',
        title: 'SARON vs taux fixe',
        subtitle: 'Quel type d\'hypoth\u00e8que choisir',
        route: '/mortgage/saron-vs-fixed',
        sources: ['FINMA circ.', 'ASB directives'],
      ));
    }
    if (lower.contains('epl') ||
        lower.contains('retrait anticip') ||
        lower.contains('2e pilier') && lower.contains('achet')) {
      cards.add(_buildSimpleCard(
        id: 'epl',
        title: 'Retrait EPL',
        subtitle: 'Utiliser ton 2e pilier pour l\'immobilier',
        route: '/epl',
        sources: ['OPP2 art. 5', 'LPP art. 30c-30g'],
      ));
    }
    if (lower.contains('vend') &&
        (lower.contains('maison') ||
            lower.contains('appartement') ||
            lower.contains('immob'))) {
      cards.add(_buildSimpleCard(
        id: 'housing_sale',
        title: 'Vente immobili\u00e8re',
        subtitle: 'Imp\u00f4t sur le gain immobilier + remploi',
        route: '/life-event/housing-sale',
        sources: ['LHID art. 12'],
      ));
    }

    // ── Famille ──────────────────────────────────────────
    if (lower.contains('mari') && !lower.contains('marche')) {
      cards.add(_buildSimpleCard(
        id: 'mariage',
        title: 'Impact du mariage',
        subtitle: 'Imp\u00f4ts, AVS, LPP, succession',
        route: '/mariage',
        sources: ['CC art. 159', 'LAVS art. 35'],
      ));
    }
    if (lower.contains('divorc') || lower.contains('separat')) {
      cards.add(_buildSimpleCard(
        id: 'divorce',
        title: 'Simulateur divorce',
        subtitle: 'Partage LPP, pension, imp\u00f4ts',
        route: '/divorce',
        sources: ['CC art. 122-124', 'LPP art. 22'],
      ));
    }
    if (lower.contains('enfant') ||
        lower.contains('naissance') ||
        lower.contains('bebe')) {
      cards.add(_buildSimpleCard(
        id: 'naissance',
        title: 'Impact d\'une naissance',
        subtitle: 'Allocations, d\u00e9ductions, budget',
        route: '/naissance',
        sources: ['LAFam art. 3', 'LIFD art. 35'],
      ));
    }
    if (lower.contains('concubin') || lower.contains('pas marie')) {
      cards.add(_buildSimpleCard(
        id: 'concubinage',
        title: 'Protection concubinage',
        subtitle: 'Droits, risques et solutions',
        route: '/concubinage',
        sources: ['CC art. 462', 'LPP art. 20a'],
      ));
    }
    if (lower.contains('succession') ||
        lower.contains('herit') ||
        lower.contains('deces') && lower.contains('proche')) {
      cards.add(_buildSimpleCard(
        id: 'succession',
        title: 'Succession',
        subtitle: 'Simuler la transmission du patrimoine',
        route: '/succession',
        sources: ['CC art. 457-640', 'LIFD art. 24'],
      ));
    }
    if (lower.contains('donat') ||
        (lower.contains('donner') && lower.contains('enfant'))) {
      cards.add(_buildSimpleCard(
        id: 'donation',
        title: 'Donation',
        subtitle: 'Impact fiscal d\'une donation',
        route: '/life-event/donation',
        sources: ['LHID art. 14'],
      ));
    }

    // ── Emploi & Statut ──────────────────────────────────
    if (lower.contains('independant') ||
        lower.contains('indep') ||
        lower.contains('mon compte')) {
      final c = _tryIndependant(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('chomage') ||
        lower.contains('emploi') && lower.contains('perdu') ||
        lower.contains('licenci')) {
      cards.add(_buildSimpleCard(
        id: 'unemployment',
        title: 'Perte d\'emploi',
        subtitle: 'Indemnit\u00e9s, dur\u00e9e, d\u00e9marches',
        route: '/unemployment',
        sources: ['LACI art. 8-27'],
      ));
    }
    if ((lower.contains('premier') && lower.contains('emploi')) ||
        lower.contains('premier job') ||
        (lower.contains('debut') && lower.contains('carri'))) {
      cards.add(_buildSimpleCard(
        id: 'first_job',
        title: 'Premier emploi',
        subtitle: 'Tout comprendre d\u00e8s le d\u00e9part',
        route: '/first-job',
        sources: ['LAVS art. 3', 'LPP art. 7'],
      ));
    }
    if (lower.contains('expat') ||
        lower.contains('etranger') ||
        lower.contains('quitt') && lower.contains('suisse')) {
      cards.add(_buildSimpleCard(
        id: 'expatriation',
        title: 'Expatriation',
        subtitle: 'Impact sur AVS, LPP, 3a et imp\u00f4ts',
        route: '/expatriation',
        sources: ['LAVS art. 1a', 'ALCP', 'CDI'],
      ));
    }
    if (lower.contains('frontalier') ||
        lower.contains('permis g') ||
        lower.contains('travail') && lower.contains('france')) {
      cards.add(_buildSimpleCard(
        id: 'frontalier',
        title: 'Frontalier',
        subtitle: 'Imp\u00f4t source et particularit\u00e9s',
        route: '/segments/frontalier',
        sources: ['CDI CH-FR art. 17', 'LIFD art. 83-101'],
      ));
    }
    if ((lower.contains('compar') && lower.contains('offre')) ||
        (lower.contains('compar') && lower.contains('emploi')) ||
        lower.contains('deux offres')) {
      cards.add(_buildSimpleCard(
        id: 'job_comparison',
        title: 'Comparateur d\'offres',
        subtitle: 'Compare deux offres d\'emploi (net + pr\u00e9voyance)',
        route: '/simulator/job-comparison',
        sources: ['CO art. 319ss'],
      ));
    }
    if (lower.contains('dividende') ||
        lower.contains('salaire') && lower.contains('sarl')) {
      cards.add(_buildSimpleCard(
        id: 'dividende_vs_salaire',
        title: 'Dividende vs Salaire',
        subtitle: 'Optimiser la r\u00e9mun\u00e9ration en SARL/SA',
        route: '/independants/dividende-salaire',
        sources: ['LIFD art. 20', 'LAVS art. 4'],
      ));
    }

    // ── Assurance & Sante ────────────────────────────────
    if (lower.contains('lamal') ||
        lower.contains('franchise') ||
        lower.contains('caisse maladie')) {
      cards.add(_buildSimpleCard(
        id: 'lamal_franchise',
        title: 'Franchise LAMal',
        subtitle: 'Quelle franchise choisir\u00a0?',
        route: '/assurances/lamal',
        sources: ['LAMal art. 64', 'OAMal art. 103'],
      ));
    }
    if (lower.contains('assur') && lower.contains('couvert') ||
        lower.contains('bien assur') ||
        lower.contains('lacune') && lower.contains('assur')) {
      cards.add(_buildSimpleCard(
        id: 'coverage_check',
        title: 'Check de couverture',
        subtitle: 'V\u00e9rifier tes couvertures',
        route: '/assurances/coverage',
        sources: ['LAMal', 'LCA'],
      ));
    }
    if (lower.contains('invalid') ||
        lower.contains('incapacit') ||
        lower.contains('accident')) {
      cards.add(_buildSimpleCard(
        id: 'disability',
        title: 'Invalidit\u00e9 \u2014 lacune de revenu',
        subtitle: 'Gap entre revenu actuel et rentes AI/LPP',
        route: '/invalidite',
        sources: ['LAI art. 28-28a', 'LPP art. 23-26'],
      ));
    }
    if (lower.contains('gender') ||
        lower.contains('ecart') && lower.contains('femme')) {
      cards.add(_buildSimpleCard(
        id: 'gender_gap',
        title: '\u00c9cart femmes/hommes',
        subtitle: 'Impact du temps partiel sur la retraite',
        route: '/segments/gender-gap',
        sources: ['LAVS art. 29', 'LPP art. 7-8'],
      ));
    }

    // ── Budget & Dette ───────────────────────────────────
    if (lower.contains('patrimoine') || lower.contains('epargne')) {
      final c = _tryPatrimoine(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('budget') ||
        lower.contains('reste a vivre') ||
        lower.contains('depense')) {
      cards.add(_buildSimpleCard(
        id: 'budget',
        title: 'Budget',
        subtitle: 'Ta marge mensuelle',
        route: '/budget',
        sources: [],
      ));
    }
    if (lower.contains('dette') ||
        lower.contains('credit') && !lower.contains('credit conso')) {
      cards.add(_buildSimpleCard(
        id: 'debt_ratio',
        title: 'Ratio d\'endettement',
        subtitle: 'Evaluer ta situation de dette',
        route: '/debt/ratio',
        sources: ['CO art. 305ss'],
      ));
    }

    // ── Simulateurs divers ───────────────────────────────
    if (lower.contains('interet compose') ||
        lower.contains('interets composes') ||
        lower.contains('combien rapport')) {
      cards.add(_buildSimpleCard(
        id: 'compound_interest',
        title: 'Int\u00e9r\u00eats compos\u00e9s',
        subtitle: 'Simuler la croissance de ton \u00e9pargne',
        route: '/simulator/compound',
        sources: [],
      ));
    }
    if (lower.contains('leasing')) {
      cards.add(_buildSimpleCard(
        id: 'leasing',
        title: 'Simulateur leasing',
        subtitle: 'Co\u00fbt r\u00e9el d\'un leasing auto',
        route: '/simulator/leasing',
        sources: [],
      ));
    }
    if (lower.contains('credit conso') || lower.contains('pret personnel')) {
      cards.add(_buildSimpleCard(
        id: 'consumer_credit',
        title: 'Credit consommation',
        subtitle: 'Co\u00fbt total d\'un cr\u00e9dit conso',
        route: '/simulator/credit',
        sources: ['LCC art. 1'],
      ));
    }
    if (lower.contains('allocation') && lower.contains('annuel') ||
        lower.contains('10k') && lower.contains('mettre')) {
      cards.add(_buildSimpleCard(
        id: 'allocation_annuelle',
        title: 'Allocation annuelle',
        subtitle: 'O\u00f9 placer ton \u00e9pargne cette ann\u00e9e',
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
  /// Un 50+ voit "Quand partir \u00e0 la retraite\u00a0?" au lieu de "Mon score Fitness".
  static List<String> suggestedPrompts(CoachProfile profile) {
    final age = profile.age;
    final isIndep = profile.employmentStatus == 'independant';
    final isCouple = profile.isCouple;
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;

    final prompts = <String>[];

    // Age-driven priorities
    if (age >= 50) {
      prompts.add('Quand la retraite devient-elle tenable\u00a0?');
      prompts.add(
          'Rente ou capital\u00a0: qu\'est-ce qui me laisse le plus d\'air\u00a0?');
      if (!hasLpp) prompts.add('Que vaut un rachat LPP dans mon cas\u00a0?');
    } else if (age >= 35) {
      prompts
          .add('O\u00f9 all\u00e9ger mes imp\u00f4ts cette ann\u00e9e\u00a0?');
      prompts.add('Combien verser en 3a cette ann\u00e9e\u00a0?');
      if (!hasLpp) prompts.add('Que vaut un rachat LPP dans mon cas\u00a0?');
    } else {
      prompts.add('Pourquoi commencer le 3a maintenant ?');
      prompts.add('Le 2e pilier, concr\u00e8tement, \u00e7a fait quoi\u00a0?');
    }

    // Archetype-driven
    if (isIndep) {
      prompts.add(
          'Ind\u00e9pendant\u00a0: qu\'est-ce que je dois reconstruire\u00a0?');
    }
    if (isCouple) {
      prompts
          .add('O\u00f9 notre pr\u00e9voyance de couple boite-t-elle\u00a0?');
    }
    if (profile.archetype == FinancialArchetype.expatUs) {
      prompts
          .add('FATCA\u00a0: qu\'est-ce que \u00e7a change pour mon 3a\u00a0?');
    }

    return prompts.take(3).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  CARD GENERATORS
  // ════════════════════════════════════════════════════════════

  static ResponseCard? _tryPillar3a(CoachProfile profile) {
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
      title: 'Versement 3a ${now.year}',
      subtitle: '\u00c9conomie fiscale estim\u00e9e',
      chiffreChoc: ChiffreChoc(
        value: taxSaving,
        unit: 'CHF',
        explanation:
            '\u00c9conomie d\'imp\u00f4t estim\u00e9e si tu verses le plafond de ${plafond.round()} CHF',
      ),
      cta: const CardCta(
        label: 'Simuler mon 3a',
        route: '/pilier-3a',
        icon: 'savings',
      ),
      urgency: daysLeft <= 30
          ? CardUrgency.high
          : daysLeft <= 90
              ? CardUrgency.medium
              : CardUrgency.low,
      deadline: deadline,
      disclaimer: _disclaimer,
      sources: const ['OPP3 art. 7', 'LIFD art. 33 al. 1 let. e'],
      impactPoints: 18,
    );
  }

  static ResponseCard? _tryLppBuyback(CoachProfile profile) {
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
      title: 'Rachat LPP',
      subtitle: 'Potentiel de rachat disponible',
      chiffreChoc: ChiffreChoc(
        value: rachatMax,
        unit: 'CHF',
        explanation:
            'Rachat possible. \u00c9conomie fiscale estim\u00e9e de ${taxSaving.round()} CHF sur ${rachatSimule.round()} CHF',
      ),
      cta: const CardCta(
        label: 'Simuler un rachat',
        route: '/rachat-lpp',
        icon: 'account_balance',
      ),
      urgency: CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const ['LPP art. 79b', 'LIFD art. 33 al. 1 let. d'],
      impactPoints: 20,
    );
  }

  static ResponseCard? _tryReplacementRate(CoachProfile profile) {
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
      title: 'Taux de remplacement',
      subtitle: 'Projection \u00e0 ${profile.effectiveRetirementAge} ans',
      chiffreChoc: ChiffreChoc(
        value: replacementRate,
        unit: '%',
        explanation:
            'Revenu estim\u00e9 \u00e0 la retraite\u00a0: ${totalMonthly.round()} CHF/mois '
            'vs ${currentMonthly.round()} CHF/mois actuellement',
      ),
      cta: const CardCta(
        label: 'Explorer mes sc\u00e9narios',
        route: '/rente-vs-capital',
        icon: 'trending_up',
      ),
      urgency: profile.age >= 58 ? CardUrgency.high : CardUrgency.medium,
      disclaimer: _disclaimer,
      sources: const ['LAVS art. 29-40', 'LPP art. 14'],
      alertes: [
        if (replacementRate < 60)
          'Taux inf\u00e9rieur au seuil recommand\u00e9 de 60\u00a0%. Explore les options.',
      ],
      impactPoints: 22,
    );
  }

  static ResponseCard? _tryAvsGap(CoachProfile profile) {
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
      title: 'Lacune AVS',
      subtitle: '$lacunes ann\u00e9es de cotisation manquantes',
      chiffreChoc: ChiffreChoc(
        value: monthlyLoss * 12,
        unit: 'CHF/an',
        explanation:
            'R\u00e9duction estim\u00e9e de ta rente AVS annuelle due aux lacunes',
      ),
      cta: const CardCta(
        label: 'Voir mon extrait AVS',
        route: '/profile/bilan',
        icon: 'verified_user',
      ),
      urgency: lacunes >= 5 ? CardUrgency.medium : CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const ['LAVS art. 29 al. 2', 'RAVS art. 52b'],
      impactPoints: 15,
    );
  }

  static ResponseCard? _tryCoupleAlert(
    CoachProfile profile,
    VisibilityScore score,
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
      title: '\u00c9cart de visibilit\u00e9 couple',
      subtitle:
          '${score.coupleWeakName} \u00e0 ${score.coupleWeakScore!.round()}\u00a0%',
      chiffreChoc: ChiffreChoc(
        value: gap,
        unit: 'pts',
        explanation:
            '\u00c9cart de ${gap.round()} points entre vos deux profils. '
            '\u00c9quilibrer am\u00e9liore la projection couple.',
      ),
      cta: const CardCta(
        label: 'Enrichir le profil couple',
        route: '/couple',
        icon: 'family_restroom',
      ),
      urgency: gap >= 25 ? CardUrgency.high : CardUrgency.medium,
      disclaimer: _disclaimer,
      sources: const ['CC art. 159', 'LPP art. 19'],
      impactPoints: 16,
    );
  }

  static ResponseCard? _tryIndependant(CoachProfile profile) {
    if (profile.employmentStatus != 'independant') return null;

    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    if (hasLpp) return null; // Covered by LPP card

    const max3a = pilier3aPlafondSansLpp;
    final current3a = profile.prevoyance.totalEpargne3a;

    return ResponseCard(
      id: 'independant_coverage',
      type: ResponseCardType.independant,
      title: 'Pr\u00e9voyance ind\u00e9pendant',
      subtitle: 'Sans LPP, ton 3a est ta pr\u00e9voyance principale',
      chiffreChoc: ChiffreChoc(
        value: max3a,
        unit: 'CHF/an',
        explanation: 'Plafond 3a sans LPP: ${max3a.round()} CHF/an. '
            'Capital 3a actuel: ${current3a.round()} CHF',
      ),
      cta: const CardCta(
        label: 'Explorer mes options',
        route: '/pilier-3a',
        icon: 'savings',
      ),
      urgency: CardUrgency.medium,
      disclaimer: _disclaimer,
      sources: const ['OPP3 art. 7 al. 2', 'LIFD art. 33 al. 1 let. e'],
      impactPoints: 20,
    );
  }

  static ResponseCard? _tryTaxOptimization(CoachProfile profile) {
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
      title: 'Optimisation fiscale',
      subtitle: 'D\u00e9ductions estim\u00e9es disponibles',
      chiffreChoc: ChiffreChoc(
        value: totalSaving,
        unit: 'CHF',
        explanation:
            '\u00c9conomie d\'imp\u00f4t estim\u00e9e via 3a (${plafond3a.round()} CHF) '
            '+ rachat LPP',
      ),
      cta: const CardCta(
        label: 'D\u00e9couvrir mes d\u00e9ductions',
        route: '/fiscal',
        icon: 'receipt_long',
      ),
      urgency: CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const ['LIFD art. 33', 'LIFD art. 33 al. 1 let. d-e'],
      impactPoints: 17,
    );
  }

  static ResponseCard? _tryPatrimoine(CoachProfile profile) {
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
      title: 'Patrimoine',
      subtitle: isUnderCushion
          ? 'Coussin de s\u00e9curit\u00e9 insuffisant'
          : 'Vue d\'ensemble',
      chiffreChoc: ChiffreChoc(
        value: total,
        unit: 'CHF',
        explanation: isUnderCushion
            ? '\u00c9pargne liquide (${epargne.round()} CHF) inf\u00e9rieure '
                '\u00e0 3 mois de charges (${coussinMin.round()} CHF)'
            : '\u00c9pargne ${epargne.round()} CHF + '
                'investissements ${investissements.round()} CHF',
      ),
      cta: CardCta(
        label: isUnderCushion ? 'Analyser mon budget' : 'Voir mon patrimoine',
        route: isUnderCushion ? '/budget' : '/profile/bilan',
        icon: isUnderCushion ? 'account_balance_wallet' : 'trending_up',
      ),
      urgency: isUnderCushion ? CardUrgency.medium : CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const [],
      alertes: [
        if (isUnderCushion)
          'Coussin de s\u00e9curit\u00e9 recommand\u00e9\u00a0: ${coussinMin.round()} CHF (3 mois de charges)',
      ],
      impactPoints: 12,
    );
  }

  /// Helper: build a simple Response Card for topics without profile-driven
  /// calculations. Used for the 27 inline coach simulators (Phase 3).
  static ResponseCard _buildSimpleCard({
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
      cta: CardCta(label: 'Explorer →', route: route),
      disclaimer: _disclaimer,
      sources: sources,
      impactPoints: 10,
    );
  }

  static ResponseCard? _tryMortgage(CoachProfile profile) {
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
      title: 'Hypoth\u00e8que',
      subtitle: 'Ratio LTV\u00a0: ${ltv.toStringAsFixed(0)}\u00a0%',
      chiffreChoc: ChiffreChoc(
        value: mortgage,
        unit: 'CHF',
        explanation: 'Solde hypoth\u00e9caire. Valeur du bien\u00a0: '
            '${propertyValue.round()} CHF',
      ),
      cta: const CardCta(
        label: 'Simuler la capacit\u00e9',
        route: '/hypotheque',
        icon: 'home',
      ),
      urgency: ltv > 80 ? CardUrgency.medium : CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const ['FINMA circ. 2012/2', 'ASB directives'],
      impactPoints: 14,
    );
  }
}
