import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/response_card_service.dart';

// ────────────────────────────────────────────────────────────
//  CAP ENGINE — V1 Heuristic
// ────────────────────────────────────────────────────────────
//
//  Pure function. No ML. No side effects.
//
//  Job: "If MINT could only propose one thing right now,
//        what would be the most useful?"
//
//  Hierarchy (V1):
//  1. Critical risk (debt, protection)
//  2. Missing blocking data (confidence < 45)
//  3. Fiscal/retirement lever with time window
//  4. Budget correction
//  5. Life event preparation
//  6. Best ResponseCard fallback
//
//  Spec: docs/MINT_CAP_ENGINE_SPEC.md
// ────────────────────────────────────────────────────────────

class CapEngine {
  CapEngine._();

  /// Compute the single most useful cap for the user right now.
  ///
  /// Never returns null if [profile] is not null.
  /// Falls back to a generic enrichment cap if nothing else applies.
  static CapDecision compute({
    required CoachProfile profile,
    required DateTime now,
    CapMemory memory = const CapMemory(),
  }) {
    final candidates = <CapDecision>[];

    // ── 1. Confidence-driven: missing blocking data ──
    final confidence = ConfidenceScorer.score(profile);
    if (confidence.score < 45 && confidence.prompts.isNotEmpty) {
      final top = confidence.prompts.first;
      candidates.add(CapDecision(
        id: 'complete_${top.category}',
        kind: CapKind.complete,
        priorityScore: _score(
          impact: 0.7,
          urgency: 0.8,
          confidencePenalty: 1.0,
          readiness: 1.0,
          recency: _recencyModifier('complete_${top.category}', memory, now),
        ),
        headline: 'Confiance ${confidence.score.round()}\u00a0% — ${top.label}',
        whyNow: 'Sans cette donnée, ta projection reste indicative. '
            '${top.action} affinerait de +${top.impact}\u00a0pts.',
        ctaLabel: top.action,
        ctaMode: CtaMode.capture,
        captureType: top.category,
        coachPrompt: 'Aide-moi à comprendre pourquoi '
            '${top.category} est important pour ma situation.',
        expectedImpact: '+${top.impact} pts de confiance',
        confidenceLabel: 'confiance ${confidence.score.round()}\u00a0%',
        blockingData: [top.category],
        sourceCards: const [],
      ));
    }

    // ── 2. Critical: debt ──
    if (profile.dettes.hasDette && profile.dettes.totalDettes > 10000) {
      candidates.add(CapDecision(
        id: 'debt_correct',
        kind: CapKind.correct,
        priorityScore: _score(
          impact: 0.9,
          urgency: 0.9,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('debt_correct', memory, now),
        ),
        headline: 'CHF\u00a0${_formatChfRound(profile.dettes.totalDettes)} de dette',
        whyNow: 'Rembourser le taux le plus élevé d\u2019abord '
            'libère de la marge chaque mois.',
        ctaLabel: 'Voir mon plan',
        ctaMode: CtaMode.route,
        ctaRoute: '/debt/repayment',
        coachPrompt: 'Aide-moi à prioriser le remboursement '
            'de mes dettes. Par quoi commencer\u00a0?',
        expectedImpact: 'marge à retrouver',
        sourceCards: const ['debt_ratio'],
      ));
    }

    // ── 3. Critical: independent with zero LPP ──
    final isIndepNoLpp = profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal == 0);
    if (isIndepNoLpp) {
      candidates.add(CapDecision(
        id: 'indep_no_lpp',
        kind: CapKind.secure,
        priorityScore: _score(
          impact: 0.85,
          urgency: 0.8,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('indep_no_lpp', memory, now),
        ),
        headline: 'Ton 2e pilier\u00a0: CHF\u00a00',
        whyNow: 'Sans LPP, ta retraite = AVS seule. '
            'Un filet volontaire change la trajectoire.',
        ctaLabel: 'Construire mon filet',
        ctaMode: CtaMode.route,
        ctaRoute: '/independants/lpp-volontaire',
        expectedImpact: 'retraite renforcée',
        sourceCards: const ['independant_coverage'],
      ));

      // ── 3b. Disability gap for independent without LPP ──
      // Without LPP, disability coverage = AI only (~30% of income).
      // The gap can reach ~70%. This is the most under-estimated risk.
      if (!memory.completedActions.contains('disability_gap')) {
        candidates.add(CapDecision(
          id: 'disability_gap',
          kind: CapKind.secure,
          priorityScore: _score(
            impact: 0.9,
            urgency: 0.85,
            confidencePenalty: _confPenalty(confidence.score),
            readiness: 1.0,
            recency: _recencyModifier('disability_gap', memory, now),
          ),
          headline: 'Ton filet invalidité\u00a0: AI seule',
          whyNow: 'Sans LPP, ton filet invalidité se limite '
              'à l\u2019AI. L\u2019écart peut surprendre.',
          ctaLabel: 'Voir l\u2019écart',
          ctaMode: CtaMode.route,
          ctaRoute: '/invalidite',
          coachPrompt: 'Je suis indépendant\u00b7e sans LPP. '
              'Aide-moi à comprendre l\u2019écart entre mon revenu '
              'et ce que l\u2019AI couvrirait en cas d\u2019invalidité.',
          expectedImpact: 'comprendre le gap ~70\u00a0%',
          sourceCards: const ['disability'],
        ));
      }
    }

    // ── 4. Fiscal window: 3a before year-end ──
    final daysToYearEnd =
        DateTime(now.year, 12, 31).difference(now).inDays;
    if (daysToYearEnd <= 90 && daysToYearEnd >= 0) {
      final cards3a = ResponseCardService.generateForPulse(profile, limit: 5)
          .where((c) => c.type == ResponseCardType.pillar3a)
          .toList();
      if (cards3a.isNotEmpty) {
        final card = cards3a.first;
        candidates.add(CapDecision(
          id: 'pillar_3a',
          kind: CapKind.optimize,
          priorityScore: _score(
            impact: 0.75,
            urgency: daysToYearEnd <= 30 ? 1.0 : 0.7,
            confidencePenalty: _confPenalty(confidence.score),
            readiness: 1.0,
            recency: _recencyModifier('pillar_3a', memory, now),
          ),
          headline: '3a\u00a0: déduction fiscale avant le 31\u00a0déc.',
          whyNow: 'Un versement 3a cette année réduit '
              'directement ton impôt et renforce ta retraite.',
          ctaLabel: 'Simuler mon 3a',
          ctaMode: CtaMode.route,
          ctaRoute: '/pilier-3a',
          coachPrompt: 'Combien je peux économiser avec un versement 3a '
              'cette année\u00a0? Quelles sont mes options\u00a0?',
          expectedImpact: card.chiffreChoc.value > 0
              ? 'jusqu\u2019à ${card.chiffreChoc.formatted} d\u2019économie'
              : null,
          sourceCards: [card.id],
        ));
      }
    }

    // ── 5. LPP buyback opportunity ──
    final rachatMax = profile.prevoyance.rachatMaximum ?? 0;
    if (rachatMax > 5000) {
      candidates.add(CapDecision(
        id: 'lpp_buyback',
        kind: CapKind.optimize,
        priorityScore: _score(
          impact: 0.7,
          urgency: 0.5,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('lpp_buyback', memory, now),
        ),
        headline: 'Rachat LPP\u00a0: jusqu\u2019à ${_formatChfRound(rachatMax)} de déduction',
        whyNow: 'Ce montant est déductible de ton revenu imposable. '
            'L\u2019effet sur ta retraite et tes impôts est immédiat.',
        ctaLabel: 'Simuler un rachat',
        ctaMode: CtaMode.route,
        ctaRoute: '/rachat-lpp',
        coachPrompt: 'Aide-moi à comprendre si un rachat LPP '
            'est intéressant dans ma situation. Quel montant\u00a0?',
        expectedImpact: 'déduction fiscale',
        sourceCards: const ['lpp_buyback'],
      ));
    }

    // ── 6. Budget deficit → reframing rule ──
    if (profile.totalDepensesMensuelles > 0 &&
        profile.salaireBrutMensuel > 0) {
      final netMensuel = NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
        age: profile.age,
      ).monthlyNetPayslip;
      final libre = netMensuel - profile.totalDepensesMensuelles;
      if (libre < 0) {
        candidates.add(CapDecision(
          id: 'budget_deficit',
          kind: CapKind.correct,
          priorityScore: _score(
            impact: 0.8,
            urgency: 0.7,
            confidencePenalty: _confPenalty(confidence.score),
            readiness: 1.0,
            recency: _recencyModifier('budget_deficit', memory, now),
          ),
          headline: 'Budget\u00a0: CHF\u00a0${_formatChfRound(libre.abs())}/mois à retrouver',
          whyNow: 'Ton budget est en tension. '
              'Ajuster un poste de dépense redonne de la marge.',
          ctaLabel: 'Ajuster mon budget',
          ctaMode: CtaMode.route,
          ctaRoute: '/budget',
          coachPrompt: 'Mon budget est en déficit. '
              'Quels postes je pourrais ajuster en priorité\u00a0?',
          expectedImpact: 'marge mensuelle',
          sourceCards: const ['budget'],
        ));
      }
    }

    // ── 7. Replacement rate warning (45+) ──
    if (profile.age >= 45 && profile.salaireBrutMensuel > 0) {
      final rateCards =
          ResponseCardService.generateForPulse(profile, limit: 5)
              .where((c) => c.type == ResponseCardType.replacementRate)
              .toList();
      if (rateCards.isNotEmpty) {
        final card = rateCards.first;
        final rate = card.chiffreChoc.value;
        if (rate > 0 && rate < 65) {
          candidates.add(CapDecision(
            id: 'replacement_rate',
            kind: CapKind.prepare,
            priorityScore: _score(
              impact: 0.7,
              urgency: profile.age >= 55 ? 0.8 : 0.5,
              confidencePenalty: _confPenalty(confidence.score),
              readiness: 1.0,
              recency: _recencyModifier('replacement_rate', memory, now),
            ),
            headline: '${rate.round()}\u00a0% de remplacement — les leviers existent',
            whyNow:
                'Un rachat LPP ou un versement 3a '
                'change le calcul. Explore tes options.',
            ctaLabel: 'Voir mes leviers retraite',
            ctaMode: CtaMode.route,
            ctaRoute: '/explore/retraite',
            coachPrompt: 'Mon taux de remplacement est de ${rate.round()}%. '
                'Aide-moi à arbitrer entre 3a et rachat LPP.',
            expectedImpact: '+4 à +7 pts',
            sourceCards: [card.id],
          ));
        }
      }
    }

    // ── 8. Protection gap ──
    // Only trigger if a real signal exists:
    // - has dependents (couple or children)
    // - OR has a mortgage (need life insurance)
    // - OR age 50+ (disability gap matters more)
    // Never trigger on just "age >= 35 salarié".
    //
    // Differentiated urgency:
    // - Salarié 50+ → moderate trigger (disability gap ~40%)
    // - Salarié with dependents/mortgage → normal trigger
    final hasDependents = profile.isCouple || profile.nombreEnfants > 0;
    final hasMortgage = (profile.patrimoine.mortgageBalance ?? 0) > 0;
    final isSenior = profile.age >= 50;
    if ((hasDependents || hasMortgage || isSenior) &&
        profile.employmentStatus != 'independant' &&
        !memory.completedActions.contains('coverage_check')) {
      candidates.add(CapDecision(
        id: 'coverage_check',
        kind: CapKind.secure,
        priorityScore: _score(
          impact: _isSeniorSalarie(profile) ? 0.65 : 0.5,
          urgency: hasMortgage
              ? 0.6
              : _isSeniorSalarie(profile)
                  ? 0.55
                  : 0.4,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('coverage_check', memory, now),
        ),
        headline: _isSeniorSalarie(profile)
            ? 'Invalidité après 50 ans\u00a0: un angle mort\u00a0?'
            : 'Ta couverture mérite un check',
        whyNow: _isSeniorSalarie(profile)
            ? 'Après 50 ans, l\u2019écart entre revenu et rentes '
                'AI\u00a0+\u00a0LPP peut dépasser 40\u00a0%. '
                'Ton IJM couvre-t-elle le reste\u00a0?'
            : 'IJM, AI, LPP invalidité — '
                'vérifie que ton filet tient.',
        ctaLabel: 'Vérifier',
        ctaMode: CtaMode.route,
        ctaRoute: '/invalidite',
        coachPrompt: _isSeniorSalarie(profile)
            ? 'J\u2019ai plus de 50 ans. Aide-moi à comprendre '
                'ce que couvrent l\u2019AI et la LPP invalidité, '
                'et si une IJM est utile dans mon cas.'
            : null,
        sourceCards: const [],
      ));
    }

    // ── 9. Life event preparation ──
    final lifeEventCap = _tryLifeEventCap(profile, confidence.score, memory, now);
    if (lifeEventCap != null) candidates.add(lifeEventCap);

    // ── 9b. Couple caps (ménage) ──
    // When the user is in a couple with conjoint data, generate
    // household-level caps: 3a couple, rachat LPP conjoint, AVS cap 150%.
    // Priority intentionally lower than individual critical caps.
    if (profile.isCouple && profile.conjoint != null) {
      candidates.addAll(
        _coupleCaps(profile, confidence.score, memory, now),
      );
    }

    // ── 10. Goal alignment boost ──
    // If the user declared a GoalA, boost candidates that align with it.
    _applyGoalBoost(candidates, profile.goalA);

    // ── 11. Honesty clause (spec §7) ──
    // If profile has no realistic lever, acknowledge it with tact.
    final honestyCap = _tryHonestyCap(profile, confidence.score, memory, now);
    if (honestyCap != null) {
      // Honesty cap overrides weaker candidates — return immediately.
      // Only real critical caps (debt, missing data) should beat it,
      // and those are already in candidates with higher scores.
      if (candidates.isEmpty) {
        return honestyCap;
      }
      candidates.add(honestyCap);
    }

    // ── 12. Fallback: best ResponseCard → Cap ──
    if (candidates.isEmpty) {
      final cards =
          ResponseCardService.generateForPulse(profile, limit: 1);
      if (cards.isNotEmpty) {
        final card = cards.first;
        candidates.add(_fromResponseCard(card, confidence.score, memory, now));
      }
    }

    // ── 13. Ultimate fallback: enrichment ──
    if (candidates.isEmpty) {
      return CapDecision(
        id: 'fallback_enrich',
        kind: CapKind.complete,
        priorityScore: 1.0,
        headline: 'Confiance ${confidence.score.round()}\u00a0% — enrichis ton profil',
        whyNow: 'Chaque donnée ajoutée affine tes projections '
            'et révèle des leviers concrets.',
        ctaLabel: 'Enrichir',
        ctaMode: CtaMode.capture,
        captureType: 'profile',
        confidenceLabel: 'confiance ${confidence.score.round()}\u00a0%',
      );
    }

    // Sort by priority and return the winner.
    candidates.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Enrich the winner with supporting signals from other candidates.
    final winner = candidates.first;
    final signals = <CapSignal>[];
    for (int i = 1; i < candidates.length && signals.length < 2; i++) {
      final c = candidates[i];
      if (c.id != winner.id) {
        signals.add(CapSignal(
          label: c.headline,
          value: c.expectedImpact ?? c.ctaLabel,
          route: c.ctaRoute,
        ));
      }
    }

    if (signals.isEmpty) return winner;

    return CapDecision(
      id: winner.id,
      kind: winner.kind,
      priorityScore: winner.priorityScore,
      headline: winner.headline,
      whyNow: winner.whyNow,
      ctaLabel: winner.ctaLabel,
      ctaMode: winner.ctaMode,
      ctaRoute: winner.ctaRoute,
      coachPrompt: winner.coachPrompt,
      captureType: winner.captureType,
      expectedImpact: winner.expectedImpact,
      confidenceLabel: winner.confidenceLabel,
      blockingData: winner.blockingData,
      supportingSignals: signals,
      sourceCards: winner.sourceCards,
      isHonestyCap: winner.isHonestyCap,
      acquiredAssets: winner.acquiredAssets,
    );
  }

  // ── LIFE EVENT ───────────────────────────────────────────

  /// Generate a Prepare cap if the user has declared a life event.
  static CapDecision? _tryLifeEventCap(
    CoachProfile profile,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
  ) {
    final event = profile.familyChange;
    if (event == null || event.isEmpty) return null;

    final mapping = _lifeEventMapping(event);
    if (mapping == null) return null;

    return CapDecision(
      id: 'life_event_$event',
      kind: CapKind.prepare,
      priorityScore: _score(
        impact: 0.65,
        urgency: 0.6,
        confidencePenalty: _confPenalty(confidenceScore),
        readiness: 1.0,
        recency: _recencyModifier('life_event_$event', memory, now),
      ),
      headline: mapping.headline,
      whyNow: mapping.whyNow,
      ctaLabel: mapping.ctaLabel,
      ctaMode: CtaMode.route,
      ctaRoute: mapping.route,
      sourceCards: const [],
    );
  }

  static _LifeEventMapping? _lifeEventMapping(String event) {
    return switch (event) {
      'marriage' => const _LifeEventMapping(
          headline: 'Mariage en vue',
          whyNow: 'Impôts, AVS, LPP, succession — tout change.',
          ctaLabel: 'Voir l\u2019impact',
          route: '/mariage',
        ),
      'divorce' => const _LifeEventMapping(
          headline: 'Divorce en cours',
          whyNow: 'Partage LPP, pension, impôts — anticipe.',
          ctaLabel: 'Simuler',
          route: '/divorce',
        ),
      'birth' => const _LifeEventMapping(
          headline: 'Naissance prévue',
          whyNow: 'Allocations, déductions, budget — prépare-toi.',
          ctaLabel: 'Voir l\u2019impact',
          route: '/naissance',
        ),
      'housingPurchase' => const _LifeEventMapping(
          headline: 'Achat immobilier',
          whyNow: 'EPL, 3a, hypothèque — tout se joue maintenant.',
          ctaLabel: 'Simuler ma capacité',
          route: '/hypotheque',
        ),
      'jobLoss' => const _LifeEventMapping(
          headline: 'Perte d\u2019emploi',
          whyNow: 'Chômage, LPP, budget — les 3 urgences.',
          ctaLabel: 'Voir mes droits',
          route: '/unemployment',
        ),
      'selfEmployment' => const _LifeEventMapping(
          headline: 'Passage à l\u2019indépendance',
          whyNow: 'LPP volontaire, 3a max, IJM — ton filet à reconstruire.',
          ctaLabel: 'Vérifier ma couverture',
          route: '/independants/lpp-volontaire',
        ),
      'retirement' => const _LifeEventMapping(
          headline: 'Retraite à l\u2019horizon',
          whyNow: 'Capital ou rente, décaissement, timing — c\u2019est le moment.',
          ctaLabel: 'Explorer mes options',
          route: '/rente-vs-capital',
        ),
      'concubinage' => const _LifeEventMapping(
          headline: 'Vie commune',
          whyNow: 'Pas de cap AVS 150\u00a0%, pas de partage LPP automatique — anticipe.',
          ctaLabel: 'Voir les différences',
          route: '/concubinage',
        ),
      'deathOfRelative' => const _LifeEventMapping(
          headline: 'Perte d\u2019un proche',
          whyNow: 'Succession, rentes de survivant, délais — ce qui est urgent.',
          ctaLabel: 'Voir les démarches',
          route: '/deces-proche',
        ),
      'newJob' => const _LifeEventMapping(
          headline: 'Nouveau poste',
          whyNow: 'LPP, libre passage, 3a — trois choses à vérifier.',
          ctaLabel: 'Comparer',
          route: '/job-comparison',
        ),
      'housingSale' => const _LifeEventMapping(
          headline: 'Vente immobilière',
          whyNow: 'Plus-value, remboursement EPL, réinvestissement — planifie.',
          ctaLabel: 'Voir l\u2019impact',
          route: '/housing-sale',
        ),
      'inheritance' => const _LifeEventMapping(
          headline: 'Héritage reçu',
          whyNow: 'Impôts, intégration au patrimoine, rachat LPP — arbitre.',
          ctaLabel: 'Voir mes options',
          route: '/explore/patrimoine',
        ),
      'donation' => const _LifeEventMapping(
          headline: 'Donation envisagée',
          whyNow: 'Avancement d\u2019hoirie, fiscalité, rapport — anticipe.',
          ctaLabel: 'Voir l\u2019impact',
          route: '/donation',
        ),
      'disability' => const _LifeEventMapping(
          headline: 'Risque invalidité',
          whyNow: 'AI, LPP invalidité, IJM — vérifie ton filet.',
          ctaLabel: 'Vérifier ma couverture',
          route: '/invalidite',
        ),
      'cantonMove' => const _LifeEventMapping(
          headline: 'Déménagement cantonal',
          whyNow: 'Impôts, LAMal, charges — l\u2019impact peut surprendre.',
          ctaLabel: 'Comparer les cantons',
          route: '/demenagement-cantonal',
        ),
      'countryMove' => const _LifeEventMapping(
          headline: 'Départ de Suisse',
          whyNow: 'Libre passage, AVS, 3a — ce qui te suit, ce qui reste.',
          ctaLabel: 'Voir les conséquences',
          route: '/expatriation',
        ),
      'debtCrisis' => const _LifeEventMapping(
          headline: 'Situation de dette',
          whyNow: 'Prioriser, restructurer, protéger l\u2019essentiel — par étapes.',
          ctaLabel: 'Voir mon plan',
          route: '/debt/repayment',
        ),
      _ => null,
    };
  }

  // ── GOAL ALIGNMENT ───────────────────────────────────────

  /// Boost candidates that align with the user's declared GoalA.
  /// Multiplies priorityScore by 1.3 for aligned caps.
  static void _applyGoalBoost(List<CapDecision> candidates, GoalA? goalA) {
    if (goalA == null) return;

    final alignedIds = _goalAlignedCapIds(goalA.type);
    if (alignedIds.isEmpty) return;

    for (int i = 0; i < candidates.length; i++) {
      final cap = candidates[i];
      if (alignedIds.contains(cap.id)) {
        // Replace with boosted copy (CapDecision is immutable)
        candidates[i] = CapDecision(
          id: cap.id,
          kind: cap.kind,
          priorityScore: cap.priorityScore * 1.3,
          headline: cap.headline,
          whyNow: cap.whyNow,
          ctaLabel: cap.ctaLabel,
          ctaMode: cap.ctaMode,
          ctaRoute: cap.ctaRoute,
          coachPrompt: cap.coachPrompt,
          captureType: cap.captureType,
          expectedImpact: cap.expectedImpact,
          confidenceLabel: cap.confidenceLabel,
          blockingData: cap.blockingData,
          supportingSignals: cap.supportingSignals,
          sourceCards: cap.sourceCards,
        );
      }
    }
  }

  static Set<String> _goalAlignedCapIds(GoalAType goalType) {
    return switch (goalType) {
      GoalAType.retraite => {
          'pillar_3a',
          'lpp_buyback',
          'replacement_rate',
          'coverage_check',
          'couple_3a',
          'couple_lpp_buyback',
          'couple_avs_cap',
        },
      GoalAType.achatImmo => {
          'lpp_buyback',
          'budget_deficit',
        },
      GoalAType.independance => {
          'indep_no_lpp',
          'disability_gap',
          'pillar_3a',
        },
      GoalAType.debtFree => {
          'debt_correct',
          'budget_deficit',
        },
      GoalAType.custom => <String>{},
    };
  }

  // ── COVERAGE CHECK HELPERS ──────────────────────────────

  /// True if the user is a salarié aged 50+.
  /// Used to differentiate coverage check urgency/messaging.
  static bool _isSeniorSalarie(CoachProfile profile) =>
      profile.age >= 50 && profile.employmentStatus == 'salarie';

  /// Generate household-level caps when conjoint data is available.
  ///
  /// Three possible caps:
  /// - **couple_3a**: conjoint has no declared 3a → double fiscal deduction.
  /// - **couple_lpp_buyback**: conjoint has significant rachat room (> 10k).
  /// - **couple_avs_cap**: married couple, both working → LAVS art. 35
  ///   plafonnement 150% reminder (~10'000 CHF/an impact).
  ///
  /// All couple caps use inclusive voice ("vous deux", "votre ménage").
  /// Priority intentionally below critical individual caps.
  static List<CapDecision> _coupleCaps(
    CoachProfile profile,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
  ) {
    final conjoint = profile.conjoint!;
    final caps = <CapDecision>[];

    // ── Couple 3a: conjoint has no declared 3a ──
    // If FATCA blocks 3a, skip (canContribute3a == false).
    final conjoint3a = conjoint.prevoyance?.totalEpargne3a ?? 0;
    final conjointCan3a = conjoint.canContribute3a;
    if (conjoint3a == 0 && conjointCan3a) {
      caps.add(CapDecision(
        id: 'couple_3a',
        kind: CapKind.optimize,
        priorityScore: _score(
          impact: 0.6,
          urgency: 0.45,
          confidencePenalty: _confPenalty(confidenceScore),
          readiness: 1.0,
          recency: _recencyModifier('couple_3a', memory, now),
        ),
        headline: 'À deux, un levier de plus',
        whyNow: 'Votre ménage peut déduire 2\u00a0\u00d7\u00a07\u2019258\u00a0CHF '
            'en cotisant chacun au 3a. '
            'Le compte de votre conjoint\u00b7e n\u2019est pas encore renseigné.',
        ctaLabel: 'Simuler le 3a couple',
        ctaMode: CtaMode.route,
        ctaRoute: '/pilier-3a',
        coachPrompt: 'Comment optimiser notre prévoyance à deux\u00a0? '
            'Mon\u00b7ma conjoint\u00b7e n\u2019a pas encore de 3a.',
        expectedImpact: 'jusqu\u2019à 14\u2019516\u00a0CHF de déductions',
        sourceCards: const ['couple_3a'],
      ));
    }

    // ── Couple LPP buyback: conjoint has significant rachat room ──
    final conjointRachat = conjoint.prevoyance?.rachatMaximum ?? 0;
    if (conjointRachat > 10000) {
      caps.add(CapDecision(
        id: 'couple_lpp_buyback',
        kind: CapKind.optimize,
        priorityScore: _score(
          impact: 0.6,
          urgency: 0.4,
          confidencePenalty: _confPenalty(confidenceScore),
          readiness: 1.0,
          recency: _recencyModifier('couple_lpp_buyback', memory, now),
        ),
        headline: 'Rachat LPP\u00a0: le levier conjoint',
        whyNow: 'Votre conjoint\u00b7e dispose d\u2019un rachat possible '
            'de ${_formatChfRound(conjointRachat)}. '
            'Prioriser le TMI le plus élevé maximise la déduction.',
        ctaLabel: 'Comparer les rachats',
        ctaMode: CtaMode.coach,
        coachPrompt: 'Nous sommes en couple. '
            'Aide-nous à comparer un rachat LPP sur mon profil '
            'vs celui de mon\u00b7ma conjoint\u00b7e. '
            'Qui a le TMI le plus élevé\u00a0?',
        expectedImpact: 'optimisation fiscale ménage',
        sourceCards: const ['couple_lpp_buyback'],
      ));
    }

    // ── AVS couple cap 150% (married only, LAVS art. 35) ──
    // Only applies to married couples. Concubins are NOT capped.
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final bothWork = profile.salaireBrutMensuel > 0 &&
        (conjoint.salaireBrutMensuel ?? 0) > 0;
    if (isMarried && bothWork) {
      caps.add(CapDecision(
        id: 'couple_avs_cap',
        kind: CapKind.prepare,
        priorityScore: _score(
          impact: 0.5,
          urgency: 0.3,
          confidencePenalty: _confPenalty(confidenceScore),
          readiness: 1.0,
          recency: _recencyModifier('couple_avs_cap', memory, now),
        ),
        headline: 'AVS couple\u00a0: le plafond 150\u00a0%',
        whyNow: 'Marié\u00b7es, vos rentes AVS cumulées sont plafonnées '
            'à 150\u00a0% de la rente maximale (LAVS art.\u00a035). '
            'L\u2019écart peut atteindre ~10\u2019000\u00a0CHF/an.',
        ctaLabel: 'Voir l\u2019impact AVS',
        ctaMode: CtaMode.route,
        ctaRoute: '/retraite',
        coachPrompt: 'Nous sommes mariés et nous travaillons tous les deux. '
            'Aide-nous à comprendre l\u2019impact du plafonnement AVS '
            'à 150\u00a0% sur notre retraite.',
        expectedImpact: 'comprendre le delta ~10k/an',
        sourceCards: const ['couple_avs'],
      ));
    }

    return caps;
  }

  // ── SCORING ──────────────────────────────────────────────

  static double _score({
    required double impact,
    required double urgency,
    required double confidencePenalty,
    required double readiness,
    required double recency,
  }) {
    return impact * urgency * confidencePenalty * readiness * recency;
  }

  /// Confidence penalty: low confidence pushes toward Complete caps.
  static double _confPenalty(double confidenceScore) {
    if (confidenceScore >= 60) return 1.0;
    if (confidenceScore >= 40) return 0.85;
    return 0.6; // Heavy penalty — prefer Complete caps
  }

  /// Recency modifier: avoid re-serving the same cap.
  /// Uses injected [now] for determinism (pure function contract).
  static double _recencyModifier(
      String capId, CapMemory memory, DateTime now) {
    if (memory.lastCapServed != capId) return 1.0;
    if (memory.lastCapDate == null) return 1.0;

    final hoursSince = now.difference(memory.lastCapDate!).inHours;
    if (hoursSince >= 24) return 1.0;
    if (hoursSince >= 12) return 0.7;
    if (hoursSince >= 6) return 0.4;
    return 0.2; // Served very recently — strongly penalize
  }

  // ── RESPONSE CARD → CAP ──────────────────────────────────

  static CapDecision _fromResponseCard(
    ResponseCard card,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
  ) {
    return CapDecision(
      id: 'rc_${card.id}',
      kind: _kindFromCardType(card.type),
      priorityScore: _score(
        impact: card.impactPoints / 25.0,
        urgency: card.urgency == CardUrgency.high
            ? 0.9
            : card.urgency == CardUrgency.medium
                ? 0.6
                : 0.4,
        confidencePenalty: _confPenalty(confidenceScore),
        readiness: 1.0,
        recency: _recencyModifier(card.id, memory, now),
      ),
      headline: card.title,
      whyNow: card.subtitle,
      ctaLabel: card.cta.label,
      ctaMode: CtaMode.route,
      ctaRoute: card.cta.route,
      expectedImpact: card.chiffreChoc.value > 0
          ? card.chiffreChoc.formatted
          : null,
      sourceCards: [card.id],
    );
  }

  static CapKind _kindFromCardType(ResponseCardType type) {
    switch (type) {
      case ResponseCardType.pillar3a:
      case ResponseCardType.lppBuyback:
      case ResponseCardType.taxOptimization:
        return CapKind.optimize;
      case ResponseCardType.replacementRate:
      case ResponseCardType.renteVsCapital:
        return CapKind.prepare;
      case ResponseCardType.avsGap:
      case ResponseCardType.coupleAlert:
        return CapKind.complete;
      case ResponseCardType.patrimoine:
      case ResponseCardType.mortgage:
        return CapKind.optimize;
      case ResponseCardType.independant:
        return CapKind.secure;
    }
  }

  // ── HONESTY CLAUSE (spec §7) ────────────────────────────

  /// Detect profiles where no realistic lever exists at useful horizon.
  ///
  /// Criteria (any one triggers):
  /// - Age 60+ with zero or near-zero LPP (< 5k) and not independent
  /// - Debt > 200% of annual gross income (overwhelmed, levers are marginal)
  /// - Cross-border 62+ with zero LPP (no time to build meaningful 2nd pillar)
  ///
  /// When triggered, produces a calm cap that:
  /// - Acknowledges the limit honestly
  /// - Shows what IS acquired (AVS, partial LPP, 3a)
  /// - Orients toward a human specialist via coach
  static CapDecision? _tryHonestyCap(
    CoachProfile profile,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
  ) {
    final age = profile.age;
    final lpp = profile.prevoyance.avoirLppTotal ?? 0;
    final revenuAnnuel = profile.revenuBrutAnnuel;
    final totalDettes = profile.dettes.totalDettes;
    final archetype = profile.archetype;

    // Case 1: 60+ with negligible LPP (salarié or retraité)
    final isSeniorNoLpp = age >= 60 &&
        lpp < 5000 &&
        profile.employmentStatus != 'independant';

    // Case 2: Debt exceeds 200% of annual income (debt spiral)
    final isDebtOverwhelmed =
        revenuAnnuel > 0 && totalDettes > revenuAnnuel * 2;

    // Case 3: Cross-border 62+ with zero LPP
    final isCrossBorderLateLpp = archetype == FinancialArchetype.crossBorder &&
        age >= 62 &&
        lpp == 0;

    if (!isSeniorNoLpp && !isDebtOverwhelmed && !isCrossBorderLateLpp) {
      return null;
    }

    final acquired = _acquiredAssets(profile);

    // Choose the right tone depending on the trigger
    String headline;
    String whyNow;
    String coachPrompt;

    if (isDebtOverwhelmed) {
      headline = 'Ta situation mérite un regard expert';
      whyNow = 'Les leviers classiques ne suffisent pas ici. '
          'Un\u00b7e spécialiste en désendettement peut '
          't\u2019aider à construire un plan réaliste.';
      coachPrompt = 'Ma dette dépasse largement mon revenu annuel. '
          'Les simulateurs ne suffisent plus. '
          'Oriente-moi vers un\u00b7e spécialiste en désendettement.';
    } else if (isCrossBorderLateLpp) {
      headline = 'Faisons le point ensemble';
      whyNow = 'À ton horizon, les leviers 2e pilier sont limités. '
          'Un\u00b7e spécialiste frontalier peut identifier '
          'des pistes que MINT ne couvre pas encore.';
      coachPrompt = 'Je suis frontalier\u00b7ère proche de la retraite '
          'sans LPP. Quelles options réalistes existent\u00a0? '
          'Oriente-moi vers un\u00b7e spécialiste.';
    } else {
      // Senior no LPP
      headline = 'Ton socle est là';
      whyNow = 'Les leviers classiques ne changent pas beaucoup '
          'la donne ici. Un\u00b7e spécialiste peut t\u2019aider '
          'à voir plus loin.';
      coachPrompt = 'J\u2019approche de la retraite avec peu de 2e pilier. '
          'Aide-moi à comprendre ce qui est acquis '
          'et oriente-moi vers un\u00b7e spécialiste.';
    }

    return CapDecision(
      id: 'honesty_no_lever',
      kind: CapKind.prepare,
      isHonestyCap: true,
      acquiredAssets: acquired,
      // High priority: when honesty triggers, other "lever" caps are
      // misleading for this profile. No confidence penalty — the diagnosis
      // is clear regardless of data completeness. Only debt_correct
      // with goal boost (0.9×0.9×1.3 ≈ 1.05) can legitimately outrank.
      priorityScore: _score(
        impact: 0.9,
        urgency: 0.85,
        confidencePenalty: 1.0, // No penalty — honesty is data-independent
        readiness: 1.0,
        recency: _recencyModifier('honesty_no_lever', memory, now),
      ),
      headline: headline,
      whyNow: whyNow,
      ctaLabel: 'Parler au coach',
      ctaMode: CtaMode.coach,
      coachPrompt: coachPrompt,
      expectedImpact: 'clarification',
      sourceCards: const [],
    );
  }

  /// Build a list of what the user HAS acquired (for honesty cap).
  /// Shows the positive side even when levers are exhausted.
  static List<String> _acquiredAssets(CoachProfile profile) {
    final assets = <String>[];

    // AVS is always acquired if contributed
    final avsYears = profile.prevoyance.anneesContribuees ?? 0;
    if (avsYears > 0) {
      final renteAvs = profile.prevoyance.renteAVSEstimeeMensuelle;
      if (renteAvs != null && renteAvs > 0) {
        assets.add('AVS\u00a0: ~${renteAvs.round()}\u00a0CHF/mois '
            '($avsYears ans cotisés)');
      } else {
        assets.add('AVS\u00a0: $avsYears années cotisées');
      }
    } else {
      assets.add('AVS\u00a0: droits en cours');
    }

    // LPP if any
    final lpp = profile.prevoyance.avoirLppTotal ?? 0;
    if (lpp > 0) {
      assets.add('LPP\u00a0: ${_formatChfRound(lpp)} acquis');
    }

    // 3a if any
    final epargne3a = profile.prevoyance.totalEpargne3a;
    if (epargne3a > 0) {
      assets.add('3a\u00a0: ${_formatChfRound(epargne3a)} épargnés');
    }

    return assets;
  }

  // ── HELPERS ──────────────────────────────────────────────

  static String _formatChfRound(double amount) {
    final rounded = (amount / 1000).round();
    if (rounded >= 1000) {
      return 'CHF\u00a0${(amount / 1000000).toStringAsFixed(1)}M';
    }
    return 'CHF\u00a0${rounded}k';
  }
}

/// Internal mapping for life event → cap content.
class _LifeEventMapping {
  final String headline;
  final String whyNow;
  final String ctaLabel;
  final String route;

  const _LifeEventMapping({
    required this.headline,
    required this.whyNow,
    required this.ctaLabel,
    required this.route,
  });
}
