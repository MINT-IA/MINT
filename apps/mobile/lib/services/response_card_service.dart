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
      'Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).';

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
  static List<ResponseCard> generateForChat(
    CoachProfile profile,
    String userMessage,
  ) {
    final lower = userMessage.toLowerCase();
    final cards = <ResponseCard>[];

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
    if (lower.contains('impot') || lower.contains('fiscal')) {
      final c = _tryTaxOptimization(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('independant') || lower.contains('indep')) {
      final c = _tryIndependant(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('patrimoine') || lower.contains('epargne')) {
      final c = _tryPatrimoine(profile);
      if (c != null) cards.add(c);
    }
    if (lower.contains('hypothe') || lower.contains('immobili')) {
      final c = _tryMortgage(profile);
      if (c != null) cards.add(c);
    }

    return cards.take(2).toList();
  }

  /// Suggested prompts personnalises selon le profil.
  /// Un 50+ voit "Quand partir a la retraite?" au lieu de "Mon score Fitness".
  static List<String> suggestedPrompts(CoachProfile profile) {
    final age = profile.age;
    final isIndep = profile.employmentStatus == 'independant';
    final isCouple = profile.isCouple;
    final hasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0;

    final prompts = <String>[];

    // Age-driven priorities
    if (age >= 50) {
      prompts.add('Quand partir a la retraite ?');
      prompts.add('Rente ou capital : que choisir ?');
      if (!hasLpp) prompts.add('Combien racheter en LPP ?');
    } else if (age >= 35) {
      prompts.add('Comment reduire mes impots ?');
      prompts.add('Combien verser en 3a cette annee ?');
      if (!hasLpp) prompts.add('Simuler un rachat LPP');
    } else {
      prompts.add('Pourquoi commencer le 3a maintenant ?');
      prompts.add('Comment fonctionne le 2e pilier ?');
    }

    // Archetype-driven
    if (isIndep) {
      prompts.add('Quelles options de prevoyance pour independant ?');
    }
    if (isCouple) {
      prompts.add('Comment coordonner notre prevoyance de couple ?');
    }
    if (profile.archetype == FinancialArchetype.expatUs) {
      prompts.add('Quelles contraintes FATCA sur mon 3a ?');
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
      subtitle: 'Économie fiscale estimée',
      chiffreChoc: ChiffreChoc(
        value: taxSaving,
        unit: 'CHF',
        explanation: daysLeft <= 60
            ? '${taxSaving.round()} CHF d\'impôts en moins si tu verses avant le 31 décembre. '
                'Plus que $daysLeft jours.'
            : '${taxSaving.round()} CHF rendus par le fisc si tu verses ${plafond.round()} CHF '
                'dans ton 3a cette année.',
      ),
      cta: const CardCta(
        label: 'Simuler mon 3a',
        route: '/simulator/3a',
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
            'Tu verses ${rachatSimule.round()} CHF, le fisc t\'en rend ${taxSaving.round()}. '
            'C\'est un rendement immédiat de ${(marginalRate * 100).toStringAsFixed(0)}\u00a0% — '
            'et l\'argent reste dans ta prévoyance.',
      ),
      cta: const CardCta(
        label: 'Simuler un rachat',
        route: '/lpp-deep/rachat',
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
        ? (lppAvoir * 0.068 / 12) // taux conversion min 6.8%
        : 0.0;

    final totalMonthly = monthlyAvs + lppMonthly;
    final currentMonthly = profile.salaireBrutMensuel * 0.78; // net approx
    final replacementRate =
        currentMonthly > 0 ? (totalMonthly / currentMonthly * 100) : 0.0;

    return ResponseCard(
      id: 'replacement_rate',
      type: ResponseCardType.replacementRate,
      title: 'Taux de remplacement',
      subtitle: 'Projection à ${profile.effectiveRetirementAge} ans',
      chiffreChoc: ChiffreChoc(
        value: replacementRate,
        unit: '%',
        explanation:
            'Aujourd\'hui tu vis avec ${currentMonthly.round()} CHF/mois. '
            'À la retraite, il t\'en restera ${totalMonthly.round()}. '
            'La différence, c\'est ${(currentMonthly - totalMonthly).round()} CHF/mois '
            'en moins — chaque mois, pour toujours.',
      ),
      cta: const CardCta(
        label: 'Explorer mes scénarios',
        route: '/simulator/rente-capital',
        icon: 'trending_up',
      ),
      urgency: profile.age >= 58 ? CardUrgency.high : CardUrgency.medium,
      disclaimer: _disclaimer,
      sources: const ['LAVS art. 29-40', 'LPP art. 14'],
      alertes: [
        if (replacementRate < 60)
          'Avec ${replacementRate.toStringAsFixed(0)}\u00a0%, ton train de vie baissera '
          'de presque moitié à la retraite. Il existe des leviers concrets pour réduire cet écart.',
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
      subtitle: '$lacunes années sans cotisation',
      chiffreChoc: ChiffreChoc(
        value: monthlyLoss * 12,
        unit: 'CHF/an',
        explanation:
            '$lacunes années manquantes = ${monthlyLoss.round()} CHF/mois de rente en moins, '
            'à vie. Commande ton extrait AVS gratuit pour connaître ta situation exacte.',
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
      title: 'Écart de visibilité couple',
      subtitle: '${score.coupleWeakName} a ${score.coupleWeakScore!.round()}%',
      chiffreChoc: ChiffreChoc(
        value: gap,
        unit: 'pts',
        explanation:
            'La projection de ${score.coupleWeakName} est floue\u00a0: '
            'on ne connaît que ${score.coupleWeakScore!.round()}\u00a0% de sa situation. '
            'Sans ses données, ta propre projection couple est faussée.',
      ),
      cta: const CardCta(
        label: 'Enrichir le profil couple',
        route: '/household',
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
      title: 'Prévoyance indépendant',
      subtitle: 'Sans LPP, ton 3a est ta prévoyance principale',
      chiffreChoc: ChiffreChoc(
        value: max3a,
        unit: 'CHF/an',
        explanation:
            'Sans LPP, personne ne cotise pour ta retraite à part toi. '
            'Tu peux verser jusqu\'à ${max3a.round()} CHF/an en 3a — '
            '5× plus qu\'un salarié. Capital actuel\u00a0: ${current3a.round()} CHF.',
      ),
      cta: const CardCta(
        label: 'Explorer mes options',
        route: '/simulator/3a',
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
      subtitle: 'Déductions estimées disponibles',
      chiffreChoc: ChiffreChoc(
        value: totalSaving,
        unit: 'CHF',
        explanation:
            '${totalSaving.round()} CHF que tu donnes au fisc au lieu de les garder. '
            'Un versement 3a et/ou un rachat LPP pourrait changer ça dès cette année.',
      ),
      cta: const CardCta(
        label: 'Découvrir mes déductions',
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
          ? 'Coussin de sécurité insuffisant'
          : 'Vue d\'ensemble',
      chiffreChoc: ChiffreChoc(
        value: total,
        unit: 'CHF',
        explanation: isUnderCushion
            ? 'Si tu perdais ton emploi demain, ton épargne tiendrait '
                '${(epargne / chargesMensuelles).toStringAsFixed(1)} mois. '
                'Ensuite\u00a0? Objectif\u00a0: 3 mois de charges (${coussinMin.round()} CHF).'
            : 'Épargne ${epargne.round()} CHF + '
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
          'En cas d\'imprévu (perte d\'emploi, panne), tu n\'as pas de filet. '
              'Objectif\u00a0: mettre ${(coussinMin / 12).round()} CHF/mois de côté pendant 1 an.',
      ],
      impactPoints: 12,
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
      title: 'Hypothèque',
      subtitle: 'Ratio LTV\u00a0: ${ltv.toStringAsFixed(0)}\u00a0%',
      chiffreChoc: ChiffreChoc(
        value: mortgage,
        unit: 'CHF',
        explanation: propertyValue > 0
            ? 'Ta dette représente ${ltv.toStringAsFixed(0)}\u00a0% de la valeur de ton bien. '
                '${ltv > 66 ? 'Au-dessus de 66\u00a0%, tu dois amortir.' : 'Ton ratio est dans la norme.'}'
            : 'Solde hypothécaire. Renseigne la valeur de ton bien pour un ratio LTV.',
      ),
      cta: const CardCta(
        label: 'Simuler la capacité',
        route: '/simulator/mortgage',
        icon: 'home',
      ),
      urgency: ltv > 80 ? CardUrgency.medium : CardUrgency.low,
      disclaimer: _disclaimer,
      sources: const ['FINMA circ. 2012/2', 'ASB directives'],
      impactPoints: 14,
    );
  }
}
