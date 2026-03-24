import 'dart:math' show pow, max;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// Result of [CoachReasonerService.analyse]: ranked recommendations
/// plus the profile's confidence score.
class ReasonerResult {
  final List<Recommendation> recommendations;
  final ProjectionConfidence confidence;

  const ReasonerResult({
    required this.recommendations,
    required this.confidence,
  });
}

/// Pure Dart rules engine that analyses a [CoachProfile] and produces
/// ranked, actionable [Recommendation]s sorted by effective annual return.
///
/// 5 levers evaluated:
///   1. Rachat LPP (tax-deductible buyback)
///   2. 3a non-maxé (unused annual contribution room)
///   3. Amortissement indirect (mortgage indirect repayment via 3a)
///   4. Échelonnement retraits 3a (staggered 3a withdrawals)
///   5. Split libre passage (split free-passage accounts)
///
/// All calculations use [RetirementTaxCalculator] from financial_core —
/// no private tax methods.
///
/// Sources: LPP art. 79b, OPP3 art. 3, LIFD art. 33/38, LAVS art. 21-40.
class CoachReasonerService {
  const CoachReasonerService._();

  /// Analyse the profile and return ranked opportunities
  /// with the profile's confidence score.
  ///
  /// Returns an empty list if the profile lacks minimum data
  /// (birthYear, salaire, canton).
  static ReasonerResult analyse(CoachProfile profile) {
    final confidence = ConfidenceScorer.score(profile);
    final results = <Recommendation>[];

    final age = DateTime.now().year - profile.birthYear;
    final yearsToRetirement =
        ((profile.targetRetirementAge ?? 65) - age).clamp(0, 45);
    if (yearsToRetirement <= 0) {
      return ReasonerResult(
          recommendations: results, confidence: confidence);
    }

    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (revenuBrut <= 0) {
      return ReasonerResult(
          recommendations: results, confidence: confidence);
    }

    // --- 1. Rachat LPP ---
    final rachat = _evaluateRachatLpp(profile, age, yearsToRetirement);
    if (rachat != null) results.add(rachat);

    // --- 2. 3a non-maxé ---
    final troisA = _evaluate3aNonMaxe(profile, age, yearsToRetirement);
    if (troisA != null) results.add(troisA);

    // --- 3. Amortissement indirect ---
    final amorti = _evaluateAmortissementIndirect(profile, yearsToRetirement);
    if (amorti != null) results.add(amorti);

    // --- 4. Échelonnement retraits 3a ---
    final echelon = _evaluateEchelonnement3a(profile, age);
    if (echelon != null) results.add(echelon);

    // --- 5. Split libre passage ---
    final split = _evaluateSplitLibrePassage(profile, age);
    if (split != null) results.add(split);

    // Sort by descending annualized impact (CHF).
    // Normalize one-off amounts over years to retirement for fair comparison.
    double annualized(Recommendation r) {
      if (r.impact.period == Period.oneoff && yearsToRetirement > 0) {
        return r.impact.amountCHF / yearsToRetirement;
      }
      return r.impact.amountCHF;
    }

    results.sort((a, b) => annualized(b).compareTo(annualized(a)));

    return ReasonerResult(
        recommendations: results, confidence: confidence);
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVER 1 — Rachat LPP
  // ═══════════════════════════════════════════════════════════════

  static Recommendation? _evaluateRachatLpp(
    CoachProfile profile,
    int age,
    int yearsToRetirement,
  ) {
    final prev = profile.prevoyance;
    final lacune = prev.lacuneRachatRestante;
    if (lacune <= 0) return null;

    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      revenuBrut,
      profile.canton,
      isMarried: isMarried,
      children: profile.nombreEnfants,
    );

    // Suggested annual buyback: spread over remaining years, min 5k, max 50k
    final annualBuyback = (lacune / yearsToRetirement)
        .clamp(5000, 50000)
        .toDouble();
    final taxSaving = annualBuyback * marginalRate;

    // Compound growth of buyback at fund rate
    final r = prev.rendementCaisse;
    final futureValue = annualBuyback * ((pow(1 + r, yearsToRetirement) - 1) / r);
    final totalInvested = annualBuyback * yearsToRetirement;
    final investmentGain = futureValue - totalInvested;

    // Effective annual return = tax saving + prorated investment gain
    final annualReturn = taxSaving + investmentGain / yearsToRetirement;

    final assumptions = <String>[
      'Taux marginal estimé : ${(marginalRate * 100).toStringAsFixed(0)}%',
      'Rendement caisse : ${(r * 100).toStringAsFixed(1)}%',
      'Lacune restante : ${lacune.toStringAsFixed(0)} CHF',
      'Outil éducatif, ne constitue pas un conseil financier (LSFin)',
    ];

    final risks = <String>[
      'LPP art. 79b al. 3 : tout retrait EPL est bloqué pendant 3 ans après un rachat.',
    ];

    if (yearsToRetirement <= 3) {
      risks.add(
        'À $yearsToRetirement ans de la retraite, le rendement composé est limité.',
      );
    }

    return Recommendation(
      id: 'rachat_lpp',
      kind: 'rachat_lpp',
      title: 'Rachat LPP : économie fiscale de ${taxSaving.toStringAsFixed(0)} CHF/an',
      summary:
          'Avec une lacune de ${lacune.toStringAsFixed(0)} CHF, un rachat annuel '
          'de ${annualBuyback.toStringAsFixed(0)} CHF réduit ton impôt de '
          '${taxSaving.toStringAsFixed(0)} CHF/an et génère un capital supplémentaire '
          'à la retraite.',
      why: [
        'Déduction fiscale immédiate (LIFD art. 33 al. 1 lit. d)',
        'Le capital racheté est rémunéré au taux de la caisse (${(r * 100).toStringAsFixed(1)}%)',
        'Augmente ta rente ou ton capital LPP à la retraite',
      ],
      assumptions: assumptions,
      impact: Impact(amountCHF: annualReturn, period: Period.yearly),
      risks: risks,
      alternatives: [
        'Verser dans le 3a si le plafond n\'est pas atteint (rendement potentiellement supérieur)',
        'Amortissement indirect du prêt hypothécaire',
      ],
      evidenceLinks: const [
        EvidenceLink(
          label: 'LPP art. 79b — Rachat',
          url: 'https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b',
        ),
      ],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Simuler un rachat échelonné',
          deepLink: '/lpp-deep/rachat-echelonne',
        ),
        const NextAction(
          type: NextActionType.learn,
          label: 'Comprendre le rachat LPP',
          deepLink: '/education/rachat-lpp',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVER 2 — 3a non-maxé
  // ═══════════════════════════════════════════════════════════════

  static Recommendation? _evaluate3aNonMaxe(
    CoachProfile profile,
    int age,
    int yearsToRetirement,
  ) {
    final prev = profile.prevoyance;
    if (!prev.canContribute3a) return null; // FATCA block

    // Determine max annual contribution
    final isIndepNoLpp =
        profile.employmentStatus == 'independant' &&
        (prev.avoirLppTotal == null || prev.avoirLppTotal == 0);
    final maxAnnual =
        isIndepNoLpp ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;

    // Estimate current annual contribution from existing accounts
    // If no contribution data, assume user contributes 0
    final currentContrib = prev.totalEpargne3a > 0 && prev.nombre3a > 0
        ? (prev.totalEpargne3a / max(1, age - 25)).clamp(0, maxAnnual)
        : 0.0;

    final gap = maxAnnual - currentContrib;
    if (gap < 500) return null; // trivial gap

    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      revenuBrut,
      profile.canton,
      isMarried: isMarried,
      children: profile.nombreEnfants,
    );
    final annualTaxSaving = gap * marginalRate;

    // FV of annual contributions at estimated 3a return
    final r3a = prev.rendementMoyen3a;
    final fv = gap * ((pow(1 + r3a, yearsToRetirement) - 1) / r3a);
    final investmentGain = fv - gap * yearsToRetirement;

    final annualReturn = annualTaxSaving + investmentGain / yearsToRetirement;

    return Recommendation(
      id: '3a_non_maxe',
      kind: '3a_gap',
      title: '3a : ${gap.toStringAsFixed(0)} CHF/an de potentiel non utilisé',
      summary:
          'Tu peux encore verser ${gap.toStringAsFixed(0)} CHF/an dans ton 3a, '
          'soit une économie fiscale de ${annualTaxSaving.toStringAsFixed(0)} CHF/an.',
      why: [
        'Déduction fiscale intégrale (LIFD art. 33 al. 1 lit. e)',
        'Capital bloqué jusqu\'à 5 ans avant la retraite (OPP3 art. 3)',
        'Rendement estimé ${(r3a * 100).toStringAsFixed(1)}% > compte épargne',
      ],
      assumptions: [
        'Plafond 3a ${maxAnnual.toStringAsFixed(0)} CHF (${isIndepNoLpp ? "indépendant sans LPP" : "salarié affilié LPP"})',
        'Taux marginal estimé : ${(marginalRate * 100).toStringAsFixed(0)}%',
        'Contribution actuelle estimée : ${currentContrib.toStringAsFixed(0)} CHF/an (heuristique basée sur le solde total — précise via tes relevés)',
        'Outil éducatif, ne constitue pas un conseil financier (LSFin)',
      ],
      impact: Impact(amountCHF: annualReturn, period: Period.yearly),
      risks: const [
        'Capital bloqué jusqu\'à 60 ans (AHV21)',
        'Rendement variable selon le type de placement (fonds ou compte)',
      ],
      alternatives: const [
        'Rachat LPP si la lacune est importante (rendement fixé par le règlement de la caisse)',
      ],
      evidenceLinks: const [
        EvidenceLink(
          label: 'OPP3 art. 3 — 3e pilier',
          url: 'https://www.fedlex.admin.ch/eli/cc/1986/25_25_25/fr#art_3',
        ),
      ],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Comparer les fournisseurs 3a',
          deepLink: '/3a-deep/provider-comparator',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVER 3 — Amortissement indirect
  // ═══════════════════════════════════════════════════════════════

  static Recommendation? _evaluateAmortissementIndirect(
    CoachProfile profile,
    int yearsToRetirement,
  ) {
    final dettes = profile.dettes;
    final hypotheque = dettes.hypotheque ?? 0;
    if (hypotheque <= 0) return null;

    // Only relevant if currently doing direct amortization
    // or if amortization type is unknown
    final prev = profile.prevoyance;
    if (!prev.canContribute3a) return null; // FATCA block

    // Check if 3a is already maxed — if so, no room for indirect
    final isIndepNoLpp =
        profile.employmentStatus == 'independant' &&
        (prev.avoirLppTotal == null || prev.avoirLppTotal == 0);
    final maxAnnual =
        isIndepNoLpp ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;

    // Estimate annual amortization: 1% of mortgage balance
    final annualAmorti = hypotheque * 0.01;
    final amountToRedirect = annualAmorti.clamp(0, maxAnnual);
    if (amountToRedirect < 1000) return null;

    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      revenuBrut,
      profile.canton,
      isMarried: isMarried,
      children: profile.nombreEnfants,
    );

    // Tax advantage: direct amorti = no deduction, indirect = 3a deduction
    final taxSaving = amountToRedirect * marginalRate;
    // Plus: mortgage interest remains deductible
    final hypoRate = profile.patrimoine.mortgageRate ?? 0.015;
    final interestDeduction = hypotheque * hypoRate * marginalRate;

    final annualAdvantage = taxSaving + interestDeduction;

    return Recommendation(
      id: 'amortissement_indirect',
      kind: 'mortgage_indirect',
      title:
          'Amortissement indirect : économie de ${annualAdvantage.toStringAsFixed(0)} CHF/an',
      summary:
          'En passant à l\'amortissement indirect via le 3a, tu conserves '
          'la déduction des intérêts hypothécaires ET bénéficies de la '
          'déduction 3a.',
      why: [
        'Double déduction : intérêts hypothécaires + versement 3a (LIFD art. 33)',
        'Le capital 3a est nanti au lieu d\'être versé à la banque',
        'Effet de levier fiscal sur toute la durée du prêt',
      ],
      assumptions: [
        'Hypothèque restante : ${hypotheque.toStringAsFixed(0)} CHF',
        'Amortissement annuel estimé : ${amountToRedirect.toStringAsFixed(0)} CHF',
        'Taux hypothécaire : ${(hypoRate * 100).toStringAsFixed(2)}%',
        'Outil éducatif, ne constitue pas un conseil financier (LSFin)',
      ],
      impact: Impact(amountCHF: annualAdvantage, period: Period.yearly),
      risks: const [
        'La dette reste au même niveau jusqu\'au nantissement',
        'Risque de placement sur le capital 3a (si fonds)',
        'Certaines banques n\'acceptent pas le nantissement 3a',
      ],
      alternatives: const [
        'Amortissement direct si priorité = réduire la dette rapidement',
        'Rachat LPP si la lacune est plus avantageuse fiscalement',
      ],
      evidenceLinks: const [
        EvidenceLink(
          label: 'LIFD art. 33 — Déductions',
          url: 'https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_33',
        ),
      ],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Simuler l\'amortissement indirect',
          deepLink: '/mortgage/simulator',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVER 4 — Échelonnement retraits 3a
  // ═══════════════════════════════════════════════════════════════

  static Recommendation? _evaluateEchelonnement3a(
    CoachProfile profile,
    int age,
  ) {
    final prev = profile.prevoyance;
    if (prev.nombre3a < 2) return null; // need >= 2 accounts to stagger
    if (prev.totalEpargne3a < 20000) return null; // trivial amounts

    final retirementAge = profile.targetRetirementAge ?? 65;
    final yearsToRetirement = (retirementAge - age).clamp(0, 45);
    if (yearsToRetirement > 10) return null; // only relevant near retirement

    // Tax saving from staggering: compare lump sum vs split withdrawals
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final totalCapital = prev.totalEpargne3a;

    // Lump sum tax
    final lumpSumTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: totalCapital,
      canton: profile.canton,
      isMarried: isMarried,
    );

    // Staggered: split into N tranches over 5 years (60-65)
    final nAccounts = prev.nombre3a;
    final trancheSize = totalCapital / nAccounts;
    double staggeredTax = 0;
    for (int i = 0; i < nAccounts; i++) {
      staggeredTax += RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: trancheSize,
        canton: profile.canton,
        isMarried: isMarried,
      );
    }

    final taxSaving = lumpSumTax - staggeredTax;
    if (taxSaving < 500) return null; // not worth the complexity

    return Recommendation(
      id: 'echelonnement_3a',
      kind: '3a_staggering',
      title:
          'Échelonner les retraits 3a : économie de ${taxSaving.toStringAsFixed(0)} CHF',
      summary:
          'En retirant tes $nAccounts comptes 3a sur plusieurs années fiscales, '
          'tu économises ${taxSaving.toStringAsFixed(0)} CHF d\'impôt sur le retrait.',
      why: [
        'Progressivité de l\'impôt sur le retrait (LIFD art. 38)',
        'Chaque retrait est imposé séparément dans l\'année fiscale',
        '$nAccounts comptes = $nAccounts tranches possibles',
      ],
      assumptions: [
        'Capital total 3a : ${totalCapital.toStringAsFixed(0)} CHF',
        'Canton : ${profile.canton}',
        if (isMarried) 'Splitting conjugal appliqué',
        'Hypothèse : retraits effectués dans des années fiscales différentes',
        'Outil éducatif, ne constitue pas un conseil financier (LSFin)',
      ],
      impact: Impact(amountCHF: taxSaving, period: Period.oneoff),
      risks: const [
        'Certains cantons cumulent les retraits 2e+3e pilier dans la même année',
        'Nécessite de planifier les retraits dès 60 ans (AHV21)',
      ],
      alternatives: const [
        'Ouvrir des comptes 3a supplémentaires si > 5 ans avant la retraite',
      ],
      evidenceLinks: const [
        EvidenceLink(
          label: 'LIFD art. 38 — Imposition du capital',
          url: 'https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_38',
        ),
      ],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Simuler l\'échelonnement',
          deepLink: '/3a-deep/staggered-withdrawal',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEVER 5 — Split libre passage
  // ═══════════════════════════════════════════════════════════════

  static Recommendation? _evaluateSplitLibrePassage(
    CoachProfile profile,
    int age,
  ) {
    final prev = profile.prevoyance;
    final totalLP = prev.totalLibrePassage;
    if (totalLP < 20000) return null; // too small
    if (prev.librePassage.length >= 2) return null; // already split

    final retirementAge = profile.targetRetirementAge ?? 65;
    final yearsToRetirement = (retirementAge - age).clamp(0, 45);
    if (yearsToRetirement > 15) return null; // not urgent yet

    // Tax saving from splitting
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;

    final singleTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: totalLP,
      canton: profile.canton,
      isMarried: isMarried,
    );

    final half = totalLP / 2;
    final splitTax = RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: half,
          canton: profile.canton,
          isMarried: isMarried,
        ) *
        2;

    final taxSaving = singleTax - splitTax;
    if (taxSaving < 300) return null;

    return Recommendation(
      id: 'split_libre_passage',
      kind: 'libre_passage_split',
      title:
          'Splitter le libre passage : économie de ${taxSaving.toStringAsFixed(0)} CHF',
      summary:
          'Ton avoir de libre passage de ${totalLP.toStringAsFixed(0)} CHF peut '
          'être réparti sur 2 comptes pour réduire l\'impôt au retrait.',
      why: [
        'Même logique que l\'échelonnement 3a (LIFD art. 38)',
        'Retrait échelonné = tranches plus petites = taux effectif plus bas',
      ],
      assumptions: [
        'Avoir libre passage : ${totalLP.toStringAsFixed(0)} CHF',
        'Split en 2 comptes de ${half.toStringAsFixed(0)} CHF',
        'Hypothèse : retraits effectués dans des années fiscales différentes',
        'Outil éducatif, ne constitue pas un conseil financier (LSFin)',
      ],
      impact: Impact(amountCHF: taxSaving, period: Period.oneoff),
      risks: const [
        'Frais de transfert selon la fondation',
        'Certaines fondations n\'acceptent pas les transferts partiels',
      ],
      alternatives: const [
        'Attendre un changement d\'emploi pour effectuer le split naturellement',
      ],
      evidenceLinks: const [
        EvidenceLink(
          label: 'LFLP art. 10 — Libre passage',
          url: 'https://www.fedlex.admin.ch/eli/cc/1994/2386_2386_2386/fr#art_10',
        ),
      ],
      nextActions: [
        const NextAction(
          type: NextActionType.learn,
          label: 'Comprendre le libre passage',
          deepLink: '/libre-passage',
        ),
      ],
    );
  }
}
