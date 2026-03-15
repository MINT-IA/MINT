import 'dart:math' show pow, max;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  /// [s] provides localized strings (pass `S.of(context)!` from the caller).
  ///
  /// Returns an empty list if the profile lacks minimum data
  /// (birthYear, salaire, canton).
  static ReasonerResult analyse(CoachProfile profile, {required S s}) {
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
    final rachat = _evaluateRachatLpp(profile, age, yearsToRetirement, s);
    if (rachat != null) results.add(rachat);

    // --- 2. 3a non-maxé ---
    final troisA = _evaluate3aNonMaxe(profile, age, yearsToRetirement, s);
    if (troisA != null) results.add(troisA);

    // --- 3. Amortissement indirect ---
    final amorti = _evaluateAmortissementIndirect(profile, yearsToRetirement, s);
    if (amorti != null) results.add(amorti);

    // --- 4. Échelonnement retraits 3a ---
    final echelon = _evaluateEchelonnement3a(profile, age, s);
    if (echelon != null) results.add(echelon);

    // --- 5. Split libre passage ---
    final split = _evaluateSplitLibrePassage(profile, age, s);
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
    S s,
  ) {
    final prev = profile.prevoyance;
    final lacune = prev.lacuneRachatRestante;
    if (lacune <= 0) return null;

    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    final marginalRate =
        RetirementTaxCalculator.estimateMarginalRate(revenuBrut, profile.canton);

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
      s.coachReasonerRachatLppAssumptionMarginalRate((marginalRate * 100).toStringAsFixed(0)),
      s.coachReasonerRachatLppAssumptionRendement((r * 100).toStringAsFixed(1)),
      s.coachReasonerRachatLppAssumptionLacune(lacune.toStringAsFixed(0)),
      s.coachReasonerDisclaimer,
    ];

    final risks = <String>[
      s.coachReasonerRachatLppRiskBlocage,
    ];

    if (yearsToRetirement <= 3) {
      risks.add(
        s.coachReasonerRachatLppRiskRendementLimite(yearsToRetirement),
      );
    }

    return Recommendation(
      id: 'rachat_lpp',
      kind: 'rachat_lpp',
      title: s.coachReasonerRachatLppTitle(taxSaving.toStringAsFixed(0)),
      summary: s.coachReasonerRachatLppSummary(
        lacune.toStringAsFixed(0),
        annualBuyback.toStringAsFixed(0),
        taxSaving.toStringAsFixed(0),
      ),
      why: [
        s.coachReasonerRachatLppWhy1,
        s.coachReasonerRachatLppWhy2((r * 100).toStringAsFixed(1)),
        s.coachReasonerRachatLppWhy3,
      ],
      assumptions: assumptions,
      impact: Impact(amountCHF: annualReturn, period: Period.yearly),
      risks: risks,
      alternatives: [
        s.coachReasonerRachatLppAlt1,
        s.coachReasonerRachatLppAlt2,
      ],
      evidenceLinks: [
        EvidenceLink(
          label: s.coachReasonerRachatLppEvidenceLabel,
          url: 'https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b',
        ),
      ],
      nextActions: [
        NextAction(
          type: NextActionType.simulate,
          label: s.coachReasonerRachatLppActionSimulate,
          deepLink: '/lpp-deep/rachat-echelonne',
        ),
        NextAction(
          type: NextActionType.learn,
          label: s.coachReasonerRachatLppActionLearn,
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
    S s,
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
    final marginalRate =
        RetirementTaxCalculator.estimateMarginalRate(revenuBrut, profile.canton);
    final annualTaxSaving = gap * marginalRate;

    // FV of annual contributions at estimated 3a return
    final r3a = prev.rendementMoyen3a;
    final fv = gap * ((pow(1 + r3a, yearsToRetirement) - 1) / r3a);
    final investmentGain = fv - gap * yearsToRetirement;

    final annualReturn = annualTaxSaving + investmentGain / yearsToRetirement;

    return Recommendation(
      id: '3a_non_maxe',
      kind: '3a_gap',
      title: s.coachReasoner3aTitle(gap.toStringAsFixed(0)),
      summary: s.coachReasoner3aSummary(
        gap.toStringAsFixed(0),
        annualTaxSaving.toStringAsFixed(0),
      ),
      why: [
        s.coachReasoner3aWhy1,
        s.coachReasoner3aWhy2,
        s.coachReasoner3aWhy3((r3a * 100).toStringAsFixed(1)),
      ],
      assumptions: [
        s.coachReasoner3aAssumptionPlafond(
          maxAnnual.toStringAsFixed(0),
          isIndepNoLpp ? s.coachReasoner3aStatusIndepSansLpp : s.coachReasoner3aStatusSalarieAvecLpp,
        ),
        s.coachReasoner3aAssumptionMarginalRate((marginalRate * 100).toStringAsFixed(0)),
        s.coachReasoner3aAssumptionContribActuelle(currentContrib.toStringAsFixed(0)),
        s.coachReasonerDisclaimer,
      ],
      impact: Impact(amountCHF: annualReturn, period: Period.yearly),
      risks: [
        s.coachReasoner3aRisk1,
        s.coachReasoner3aRisk2,
      ],
      alternatives: [
        s.coachReasoner3aAlt1,
      ],
      evidenceLinks: [
        EvidenceLink(
          label: s.coachReasoner3aEvidenceLabel,
          url: 'https://www.fedlex.admin.ch/eli/cc/1986/25_25_25/fr#art_3',
        ),
      ],
      nextActions: [
        NextAction(
          type: NextActionType.simulate,
          label: s.coachReasoner3aActionCompare,
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
    S s,
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
    final marginalRate =
        RetirementTaxCalculator.estimateMarginalRate(revenuBrut, profile.canton);

    // Tax advantage: direct amorti = no deduction, indirect = 3a deduction
    final taxSaving = amountToRedirect * marginalRate;
    // Plus: mortgage interest remains deductible
    final hypoRate = profile.patrimoine.mortgageRate ?? 0.015;
    final interestDeduction = hypotheque * hypoRate * marginalRate;

    final annualAdvantage = taxSaving + interestDeduction;

    return Recommendation(
      id: 'amortissement_indirect',
      kind: 'mortgage_indirect',
      title: s.coachReasonerAmortiTitle(annualAdvantage.toStringAsFixed(0)),
      summary: s.coachReasonerAmortiSummary,
      why: [
        s.coachReasonerAmortiWhy1,
        s.coachReasonerAmortiWhy2,
        s.coachReasonerAmortiWhy3,
      ],
      assumptions: [
        s.coachReasonerAmortiAssumptionHypotheque(hypotheque.toStringAsFixed(0)),
        s.coachReasonerAmortiAssumptionAmortissement(amountToRedirect.toStringAsFixed(0)),
        s.coachReasonerAmortiAssumptionTauxHypo((hypoRate * 100).toStringAsFixed(2)),
        s.coachReasonerDisclaimer,
      ],
      impact: Impact(amountCHF: annualAdvantage, period: Period.yearly),
      risks: [
        s.coachReasonerAmortiRisk1,
        s.coachReasonerAmortiRisk2,
        s.coachReasonerAmortiRisk3,
      ],
      alternatives: [
        s.coachReasonerAmortiAlt1,
        s.coachReasonerAmortiAlt2,
      ],
      evidenceLinks: [
        EvidenceLink(
          label: s.coachReasonerAmortiEvidenceLabel,
          url: 'https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_33',
        ),
      ],
      nextActions: [
        NextAction(
          type: NextActionType.simulate,
          label: s.coachReasonerAmortiActionSimulate,
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
    S s,
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
      title: s.coachReasonerEchelonnementTitle(taxSaving.toStringAsFixed(0)),
      summary: s.coachReasonerEchelonnementSummary(
        nAccounts,
        taxSaving.toStringAsFixed(0),
      ),
      why: [
        s.coachReasonerEchelonnementWhy1,
        s.coachReasonerEchelonnementWhy2,
        s.coachReasonerEchelonnementWhy3(nAccounts),
      ],
      assumptions: [
        s.coachReasonerEchelonnementAssumptionCapital(totalCapital.toStringAsFixed(0)),
        s.coachReasonerEchelonnementAssumptionCanton(profile.canton),
        if (isMarried) s.coachReasonerEchelonnementAssumptionSplitting,
        s.coachReasonerEchelonnementAssumptionRetraits,
        s.coachReasonerDisclaimer,
      ],
      impact: Impact(amountCHF: taxSaving, period: Period.oneoff),
      risks: [
        s.coachReasonerEchelonnementRisk1,
        s.coachReasonerEchelonnementRisk2,
      ],
      alternatives: [
        s.coachReasonerEchelonnementAlt1,
      ],
      evidenceLinks: [
        EvidenceLink(
          label: s.coachReasonerEchelonnementEvidenceLabel,
          url: 'https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_38',
        ),
      ],
      nextActions: [
        NextAction(
          type: NextActionType.simulate,
          label: s.coachReasonerEchelonnementActionSimulate,
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
    S s,
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
      title: s.coachReasonerSplitLpTitle(taxSaving.toStringAsFixed(0)),
      summary: s.coachReasonerSplitLpSummary(totalLP.toStringAsFixed(0)),
      why: [
        s.coachReasonerSplitLpWhy1,
        s.coachReasonerSplitLpWhy2,
      ],
      assumptions: [
        s.coachReasonerSplitLpAssumptionAvoir(totalLP.toStringAsFixed(0)),
        s.coachReasonerSplitLpAssumptionSplit(half.toStringAsFixed(0)),
        s.coachReasonerSplitLpAssumptionRetraits,
        s.coachReasonerDisclaimer,
      ],
      impact: Impact(amountCHF: taxSaving, period: Period.oneoff),
      risks: [
        s.coachReasonerSplitLpRisk1,
        s.coachReasonerSplitLpRisk2,
      ],
      alternatives: [
        s.coachReasonerSplitLpAlt1,
      ],
      evidenceLinks: [
        EvidenceLink(
          label: s.coachReasonerSplitLpEvidenceLabel,
          url: 'https://www.fedlex.admin.ch/eli/cc/1994/2386_2386_2386/fr#art_10',
        ),
      ],
      nextActions: [
        NextAction(
          type: NextActionType.learn,
          label: s.coachReasonerSplitLpActionLearn,
          deepLink: '/lpp-deep/libre-passage',
        ),
      ],
    );
  }
}
