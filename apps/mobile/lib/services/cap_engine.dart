import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/product_cohort_service.dart';
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
    required S l,
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
        headline: l.capMissingPieceHeadline,
        whyNow: l.capMissingPieceWhyNow(top.label),
        ctaLabel: top.action,
        ctaMode: CtaMode.capture,
        captureType: top.category,
        coachPrompt: l.capCoachPromptMissingData(top.category),
        expectedImpact: l.capMissingPieceExpectedImpact(top.impact.toString()),
        confidenceLabel: l.capMissingPieceConfidenceLabel(confidence.score.round().toString()),
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
        headline: l.capDebtHeadline,
        // Reframing rule: never show bad number alone — show the lever.
        whyNow: l.capDebtWhyNow,
        ctaLabel: l.capDebtCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/debt/repayment',
        coachPrompt: l.capCoachPromptDebt,
        expectedImpact: l.capDebtExpectedImpact,
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
        headline: l.capIndepNoLppHeadline,
        whyNow: l.capIndepNoLppWhyNow,
        ctaLabel: l.capIndepNoLppCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/independants/lpp-volontaire',
        expectedImpact: l.capIndepNoLppExpectedImpact,
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
          headline: l.capDisabilityGapHeadline,
          whyNow: l.capDisabilityGapWhyNow,
          ctaLabel: l.capDisabilityGapCtaLabel,
          ctaMode: CtaMode.route,
          ctaRoute: '/invalidite',
          coachPrompt: l.capCoachPromptIndepNoLpp,
          expectedImpact: l.capDisabilityGapExpectedImpact,
          sourceCards: const ['disability'],
        ));
      }
    }

    // ── 4. Fiscal window: 3a before year-end ──
    // P1-7: Suppress 3a for retirees (age >= 65 or status retraite).
    // 3a contributions are only possible while actively employed.
    final isRetired = profile.age >= 65 ||
        profile.employmentStatus == 'retraite';
    final daysToYearEnd =
        DateTime(now.year, 12, 31).difference(now).inDays;
    // FATCA: US persons CAN contribute to 3a (Swiss law allows it),
    // but some providers refuse US persons due to PFIC/FATCA reporting.
    // We show the cap but the FATCA guidance in fallback_templates warns about restrictions.
    if (daysToYearEnd <= 90 && daysToYearEnd >= 0 && !isRetired) {
      final cards3a =
          ResponseCardService.generateForPulse(profile, l: l, limit: 5)
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
          headline: l.cap3aHeadline,
          whyNow: l.cap3aWhyNow,
          ctaLabel: l.cap3aCtaLabel,
          ctaMode: CtaMode.route,
          ctaRoute: '/pilier-3a',
          coachPrompt: l.capCoachPrompt3a,
          expectedImpact: card.chiffreChoc.value > 0
              ? 'jusqu\u2019à ${card.chiffreChoc.formatted} d\u2019économie'
              : null,
          sourceCards: [card.id],
        ));
      }
    }

    // ── 5. LPP buyback opportunity ──
    // P1-13: Hide rachat after retirement (age >= 65 or status retraite).
    final rachatMax = profile.prevoyance.rachatMaximum ?? 0;
    if (rachatMax > 5000 &&
        profile.age < 65 &&
        profile.employmentStatus != 'retraite') {
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
        headline: l.capLppBuybackHeadline,
        whyNow: l.capLppBuybackWhyNow(_formatChfRound(rachatMax)),
        ctaLabel: l.capLppBuybackCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/rachat-lpp',
        coachPrompt: l.capCoachPromptRachat,
        expectedImpact: l.capLppBuybackExpectedImpact,
        sourceCards: const ['lpp_buyback'],
      ));
    }

    // ── 6. Budget deficit → reframing rule ──
    // FIX-100: Use revenuBrutAnnuel (handles independants).
    final grossAnnualForBudget = profile.revenuBrutAnnuel;
    if (profile.totalDepensesMensuelles > 0 && grossAnnualForBudget > 0) {
      final netMensuel = profile.employmentStatus == 'independant'
          ? grossAnnualForBudget * 0.90 / 12
          : NetIncomeBreakdown.compute(
              grossSalary: grossAnnualForBudget,
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
          // Reframing: show the margin to recover, not just the red.
          headline: l.capBudgetDeficitHeadline,
          whyNow: l.capBudgetDeficitWhyNow,
          ctaLabel: l.capBudgetDeficitCtaLabel,
          ctaMode: CtaMode.route,
          ctaRoute: '/budget',
          coachPrompt: l.capCoachPromptBudgetDeficit,
          expectedImpact: l.capBudgetDeficitExpectedImpact,
          sourceCards: const ['budget'],
        ));
      }
    }

    // ── 7. Replacement rate warning (45+) ──
    if (profile.age >= 45 && profile.salaireBrutMensuel > 0) {
      final rateCards =
          ResponseCardService.generateForPulse(profile, l: l, limit: 5)
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
            headline: l.capReplacementRateHeadline,
            whyNow: l.capReplacementRateWhyNow(rate.round().toString()),
            ctaLabel: l.capReplacementRateCtaLabel,
            ctaMode: CtaMode.route,
            ctaRoute: '/rente-vs-capital',
            coachPrompt: l.capCoachPromptReplacement(rate.round().toString()),
            expectedImpact: l.capReplacementRateExpectedImpact,
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
            ? l.capCoverageCheckSeniorHeadline
            : l.capCoverageCheckHeadline,
        whyNow: _isSeniorSalarie(profile)
            ? l.capCoverageCheckSeniorWhyNow
            : l.capCoverageCheckWhyNow,
        ctaLabel: l.capCoverageCheckCtaLabel,
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

    // ── 8b. Succession planning (65+ or veuf/veuve) ──
    // P1-8: Estate planning is relevant from retirement age, not 75.
    // Also relevant when widowed (testament update, survivor rights).
    final isVeuf = profile.etatCivil == CoachCivilStatus.veuf;
    if ((profile.age >= 65 || isVeuf) &&
        !memory.completedActions.contains('estate_planning')) {
      candidates.add(CapDecision(
        id: 'estate_planning',
        kind: CapKind.prepare,
        priorityScore: _score(
          impact: 0.65,
          urgency: isVeuf ? 0.8 : 0.5,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('estate_planning', memory, now),
        ),
        headline: l.capEstatePlanningHeadline,
        whyNow: isVeuf
            ? l.capEstatePlanningWhyNowVeuf
            : l.capEstatePlanningWhyNow,
        ctaLabel: l.capEstatePlanningCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/life-event/deces-proche',
        coachPrompt: 'Aide-moi \u00e0 comprendre ce que je dois pr\u00e9voir '
            'pour la transmission de mon patrimoine\u00a0: testament, '
            'pacte successoral, b\u00e9n\u00e9ficiaires LPP et 3a.',
        sourceCards: const ['estate_planning'],
      ));
    }

    // ── 9. Life event preparation ──
    final lifeEventCap = _tryLifeEventCap(profile, confidence.score, memory, now, l);
    if (lifeEventCap != null) candidates.add(lifeEventCap);

    // ── 9b. Couple caps (ménage) ──
    // When the user is in a couple with conjoint data, generate
    // household-level caps: 3a couple, rachat LPP conjoint, AVS cap 150%.
    // Priority intentionally lower than individual critical caps.
    if (profile.isCouple && profile.conjoint != null) {
      candidates.addAll(
        _coupleCaps(profile, confidence.score, memory, now, l),
      );
    }

    // ── 9c. Top 10 Core Journeys — Tier 1 urgency caps ──
    // Life-disruption situations always outrank tax optimization or 3a.
    // Adds new urgency caps AND boosts existing aligned candidates.
    candidates.addAll(
      _top10UrgencyCaps(profile, confidence.score, memory, now, l),
    );
    _applyTop10UrgencyBoost(candidates, profile, memory, now);

    // ── 10. Goal alignment boost ──
    // If the user declared a GoalA, boost candidates that align with it.
    _applyGoalBoost(candidates, profile.goalA);

    // ── 11. Honesty clause (spec §7) ──
    // If profile has no realistic lever, acknowledge it with tact.
    final honestyCap = _tryHonestyCap(profile, confidence.score, memory, now, l);
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
          ResponseCardService.generateForPulse(profile, l: l, limit: 1);
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
        headline: l.capFallbackHeadline,
        whyNow: l.capFallbackWhyNow,
        ctaLabel: l.capFallbackCtaLabel,
        ctaMode: CtaMode.capture,
        captureType: 'profile',
        confidenceLabel: l.capMissingPieceConfidenceLabel(confidence.score.round().toString()),
      );
    }

    // Filter out caps that conflict with the user's cohort (Anti-Bullshit §6).
    // Uses explicit semantic mapping — NOT string.contains (fragile with camelCase IDs).
    final cohortResult = ProductCohortService.resolve(profile);
    if (cohortResult.suppressedTopics.isNotEmpty) {
      candidates.removeWhere((c) {
        final semantic = _capSemanticTopic(c.id);
        return semantic != null && cohortResult.suppressedTopics.contains(semantic);
      });
    }

    // Sort by priority and return the winner.
    if (candidates.isEmpty) {
      return CapDecision(
        id: 'no_cap_available',
        kind: CapKind.prepare,
        priorityScore: 0,
        // Neutral fallback — cohort-safe (FIX-155)
        headline: l.capNoCapHeadline,
        whyNow: l.capNoCapWhyNow,
        ctaLabel: l.capHonestyCtaLabel,
        ctaRoute: '/coach/chat',
        ctaMode: CtaMode.route,
        expectedImpact: l.capHonestyExpectedImpact,
        coachPrompt: null,
      );
    }
    // P0-14: Deterministic tie-breaking — use id hashCode as secondary sort
    candidates.sort((a, b) {
      final cmp = b.priorityScore.compareTo(a.priorityScore);
      return cmp != 0 ? cmp : a.id.compareTo(b.id); // Lexicographic — stable across versions
    });

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

  // ── TOP 10 SWISS CORE JOURNEYS — TIER 1 URGENCY ─────────
  //
  //  Tier 1 = life disruption. These situations ALWAYS outrank
  //  tax optimisation, 3a contributions, or LPP buyback.
  //
  //  Tier 1 signals (from docs/TOP_10_SWISS_CORE_JOURNEYS.md):
  //  - Chômage / perte d'emploi  → employmentStatus == 'chomage'
  //  - Invalidité / accident      → familyChange == 'disability'
  //  - Dette / budget sous tension→ spending > net income
  //                                 OR familyChange == 'debtCrisis'
  //  - Divorce                    → etatCivil == divorce
  //                                 OR familyChange == 'divorce'
  //
  //  Spec: docs/TOP_10_SWISS_CORE_JOURNEYS.md §2 (parcours 3, 4, 8, 11)

  /// Returns a boost multiplier (0–100) for the current profile
  /// based on Top 10 Core Journey urgency tier.
  ///
  /// - 100 → Tier 1 highest (chômage, immediate income disruption)
  /// - 90  → Tier 1 high (debt crisis, spending > net)
  /// - 80  → Tier 1 medium (divorce, LPP split + housing)
  /// - 70  → Tier 1 low (disability life event)
  /// - 0   → No Tier 1 signal
  static int _top10UrgencyBoost(CoachProfile profile, CapMemory memory) {
    // Chômage: immediate income disruption, highest urgency
    if (profile.employmentStatus == 'chomage') { return 100; }

    // Debt crisis: spending exceeds net income OR debtCrisis life event
    if (_hasDebtCrisis(profile)) { return 90; }

    // Divorce: LPP split, alimony, housing urgency
    if (profile.etatCivil == CoachCivilStatus.divorce ||
        profile.familyChange == 'divorce') { return 80; }

    // Disability life event declared
    if (profile.familyChange == 'disability') { return 70; }

    return 0;
  }

  /// True when the profile shows a debt crisis signal:
  /// - monthly spending exceeds estimated net income, OR
  /// - user declared debtCrisis as current life event.
  static bool _hasDebtCrisis(CoachProfile profile) {
    if (profile.familyChange == 'debtCrisis') return true;

    // Budget crisis: total expenses > net income
    if (profile.totalDepensesMensuelles > 0 &&
        profile.salaireBrutMensuel > 0) {
      final netMensuel = NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
        age: profile.age,
      ).monthlyNetPayslip;
      if (profile.totalDepensesMensuelles > netMensuel) return true;
    }

    return false;
  }

  /// Generate Tier 1 urgency caps not covered by the general heuristic.
  ///
  /// Currently adds:
  /// - **chomage_urgency**: fires when [profile.employmentStatus] == 'chomage'.
  ///   The general heuristic only fires a `jobLoss` life event cap when
  ///   [profile.familyChange] == 'jobLoss'. Persistent chômage status has
  ///   no dedicated cap today.
  /// - **divorce_urgency**: fires when civil status is divorce.
  ///   The life event cap fires on [profile.familyChange] == 'divorce'
  ///   during the transition; this cap covers the ongoing status.
  static List<CapDecision> _top10UrgencyCaps(
    CoachProfile profile,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
    S l,
  ) {
    final caps = <CapDecision>[];

    // ── Chômage: secure the next 90 days ──
    // employmentStatus == 'chomage' is a persistent state; the general
    // life event cap only fires for the one-time familyChange event.
    // This cap surfaces whenever chômage is the active employment status.
    if (profile.employmentStatus == 'chomage') {
      caps.add(CapDecision(
        id: 'chomage_urgency',
        kind: CapKind.secure,
        priorityScore: _score(
          impact: 1.0,
          urgency: 1.0,
          confidencePenalty: _confPenalty(confidenceScore),
          readiness: 1.0,
          recency: _recencyModifier('chomage_urgency', memory, now),
        ),
        headline: l.capChomageHeadline,
        whyNow: l.capChomageWhyNow,
        ctaLabel: l.capChomageCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/unemployment',
        coachPrompt: l.capCoachPromptUnemployment,
        expectedImpact: l.capChomageExpectedImpact,
        sourceCards: const ['unemployment'],
      ));
    }

    // ── Divorce: LPP split, alimony, housing ──
    // Civil status divorce is a persistent condition; the life event
    // 'divorce' cap fires only when familyChange is set (during transition).
    // This cap covers users whose etatCivil is already divorce.
    final isDivorced = profile.etatCivil == CoachCivilStatus.divorce;
    final hasDivorceEvent = profile.familyChange == 'divorce';
    if (isDivorced && !hasDivorceEvent) {
      // hasDivorceEvent == true means _tryLifeEventCap already handles it.
      caps.add(CapDecision(
        id: 'divorce_urgency',
        kind: CapKind.secure,
        priorityScore: _score(
          impact: 0.85,
          urgency: 0.85,
          confidencePenalty: _confPenalty(confidenceScore),
          readiness: 1.0,
          recency: _recencyModifier('divorce_urgency', memory, now),
        ),
        headline: l.capDivorceUrgencyHeadline,
        whyNow: l.capDivorceUrgencyWhyNow,
        ctaLabel: l.capDivorceUrgencyCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/divorce',
        coachPrompt: l.capCoachPromptDivorce,
        expectedImpact: l.capDivorceUrgencyExpectedImpact,
        sourceCards: const ['divorce'],
      ));
    }

    return caps;
  }

  /// Boost existing candidates whose content aligns with the active
  /// Tier 1 Core Journey urgency.
  ///
  /// Multiplies [priorityScore] by `(1 + boost / 100)` — e.g. boost 100
  /// doubles the score, boost 90 adds 90\u00a0%, ensuring Tier 1 caps
  /// outrank all tax/optimization caps regardless of their base score.
  static void _applyTop10UrgencyBoost(
    List<CapDecision> candidates,
    CoachProfile profile,
    CapMemory memory,
    DateTime now,
  ) {
    final boost = _top10UrgencyBoost(profile, memory);
    if (boost == 0) return;

    // Cap IDs that align with each Tier 1 scenario.
    final Set<String> alignedIds = {};

    if (profile.employmentStatus == 'chomage') {
      alignedIds.addAll(const {'chomage_urgency', 'debt_correct', 'budget_deficit'});
    }
    if (_hasDebtCrisis(profile)) {
      alignedIds.addAll(const {'debt_correct', 'budget_deficit', 'honesty_no_lever'});
    }
    if (profile.etatCivil == CoachCivilStatus.divorce ||
        profile.familyChange == 'divorce') {
      alignedIds.addAll(const {'divorce_urgency', 'life_event_divorce'});
    }
    if (profile.familyChange == 'disability') {
      alignedIds.addAll(const {'disability_gap', 'coverage_check', 'life_event_disability'});
    }

    if (alignedIds.isEmpty) return;

    final multiplier = 1.0 + boost / 100.0;
    for (int i = 0; i < candidates.length; i++) {
      final cap = candidates[i];
      if (!alignedIds.contains(cap.id)) continue;
      candidates[i] = CapDecision(
        id: cap.id,
        kind: cap.kind,
        priorityScore: cap.priorityScore * multiplier,
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
        isHonestyCap: cap.isHonestyCap,
        acquiredAssets: cap.acquiredAssets,
      );
    }
  }

  // ── LIFE EVENT ───────────────────────────────────────────

  /// Generate a Prepare cap if the user has declared a life event.
  static CapDecision? _tryLifeEventCap(
    CoachProfile profile,
    double confidenceScore,
    CapMemory memory,
    DateTime now,
    S l,
  ) {
    final event = profile.familyChange;
    if (event == null || event.isEmpty) return null;

    final mapping = _lifeEventMapping(event, l);
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

  static _LifeEventMapping? _lifeEventMapping(String event, S l) {
    return switch (event) {
      'marriage' => _LifeEventMapping(
          headline: l.capLeMarriageHeadline,
          whyNow: l.capLeMarriageWhyNow,
          ctaLabel: l.capLeMarriageCtaLabel,
          route: '/mariage',
        ),
      'divorce' => _LifeEventMapping(
          headline: l.capLeDivorceHeadline,
          whyNow: l.capLeDivorceWhyNow,
          ctaLabel: l.capLeDivorceCtaLabel,
          route: '/divorce',
        ),
      'birth' => _LifeEventMapping(
          headline: l.capLeBirthHeadline,
          whyNow: l.capLeBirthWhyNow,
          ctaLabel: l.capLeBirthCtaLabel,
          route: '/naissance',
        ),
      'housingPurchase' => _LifeEventMapping(
          headline: l.capLeHousingPurchaseHeadline,
          whyNow: l.capLeHousingPurchaseWhyNow,
          ctaLabel: l.capLeHousingPurchaseCtaLabel,
          route: '/hypotheque',
        ),
      'jobLoss' => _LifeEventMapping(
          headline: l.capLeJobLossHeadline,
          whyNow: l.capLeJobLossWhyNow,
          ctaLabel: l.capLeJobLossCtaLabel,
          route: '/unemployment',
        ),
      'selfEmployment' => _LifeEventMapping(
          headline: l.capLeSelfEmploymentHeadline,
          whyNow: l.capLeSelfEmploymentWhyNow,
          ctaLabel: l.capLeSelfEmploymentCtaLabel,
          route: '/segments/independant',
        ),
      'retirement' => _LifeEventMapping(
          headline: l.capLeRetirementHeadline,
          whyNow: l.capLeRetirementWhyNow,
          ctaLabel: l.capLeRetirementCtaLabel,
          route: '/rente-vs-capital',
        ),
      'concubinage' => _LifeEventMapping(
          headline: l.capLeConcubinageHeadline,
          whyNow: l.capLeConcubinageWhyNow,
          ctaLabel: l.capLeConcubinageCtaLabel,
          route: '/concubinage',
        ),
      'deathOfRelative' => _LifeEventMapping(
          headline: l.capLeDeathOfRelativeHeadline,
          whyNow: l.capLeDeathOfRelativeWhyNow,
          ctaLabel: l.capLeDeathOfRelativeCtaLabel,
          route: '/life-event/deces-proche',
        ),
      'newJob' => _LifeEventMapping(
          headline: l.capLeNewJobHeadline,
          whyNow: l.capLeNewJobWhyNow,
          ctaLabel: l.capLeNewJobCtaLabel,
          route: '/simulator/job-comparison',
        ),
      'housingSale' => _LifeEventMapping(
          headline: l.capLeHousingSaleHeadline,
          whyNow: l.capLeHousingSaleWhyNow,
          ctaLabel: l.capLeHousingSaleCtaLabel,
          route: '/life-event/housing-sale',
        ),
      'inheritance' => _LifeEventMapping(
          headline: l.capLeInheritanceHeadline,
          whyNow: l.capLeInheritanceWhyNow,
          ctaLabel: l.capLeInheritanceCtaLabel,
          route: '/explore/patrimoine',
        ),
      'donation' => _LifeEventMapping(
          headline: l.capLeDonationHeadline,
          whyNow: l.capLeDonationWhyNow,
          ctaLabel: l.capLeDonationCtaLabel,
          route: '/life-event/donation',
        ),
      'disability' => _LifeEventMapping(
          headline: l.capLeDisabilityHeadline,
          whyNow: l.capLeDisabilityWhyNow,
          ctaLabel: l.capLeDisabilityCtaLabel,
          route: '/invalidite',
        ),
      'cantonMove' => _LifeEventMapping(
          headline: l.capLeCantonMoveHeadline,
          whyNow: l.capLeCantonMoveWhyNow,
          ctaLabel: l.capLeCantonMoveCtaLabel,
          route: '/life-event/demenagement-cantonal',
        ),
      'countryMove' => _LifeEventMapping(
          headline: l.capLeCountryMoveHeadline,
          whyNow: l.capLeCountryMoveWhyNow,
          ctaLabel: l.capLeCountryMoveCtaLabel,
          route: '/expatriation',
        ),
      'debtCrisis' => _LifeEventMapping(
          headline: l.capLeDebtCrisisHeadline,
          whyNow: l.capLeDebtCrisisWhyNow,
          ctaLabel: l.capLeDebtCrisisCtaLabel,
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
    S l,
  ) {
    final conjoint = profile.conjoint!;
    final caps = <CapDecision>[];

    // ── Couple 3a: conjoint has no declared 3a ──
    // If FATCA blocks 3a, skip (canContribute3a == false).
    // P1-7: Also suppress for retired conjoint (age >= 65 or status retraite).
    final conjoint3a = conjoint.prevoyance?.totalEpargne3a ?? 0;
    final conjointCan3a = conjoint.canContribute3a;
    final conjointAge = conjoint.age ?? 99;
    final conjointIsRetired = conjointAge >= 65 ||
        conjoint.employmentStatus == 'retraite';
    if (conjoint3a == 0 && conjointCan3a && !conjointIsRetired) {
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
        headline: l.capCouple3aHeadline,
        whyNow: l.capCouple3aWhyNow,
        ctaLabel: l.capCouple3aCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/pilier-3a',
        coachPrompt: l.capCoachPromptCoupleOptim,
        expectedImpact: l.capCouple3aExpectedImpact,
        sourceCards: const ['couple_3a'],
      ));
    }

    // ── Couple LPP buyback: conjoint has significant rachat room ──
    // P1-13: Hide rachat after retirement.
    final conjointRachat = conjoint.prevoyance?.rachatMaximum ?? 0;
    if (conjointRachat > 10000 && !conjointIsRetired) {
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
        headline: l.capCoupleLppBuybackHeadline,
        whyNow: l.capCoupleLppBuybackWhyNow(_formatChfRound(conjointRachat)),
        ctaLabel: l.capCoupleLppBuybackCtaLabel,
        ctaMode: CtaMode.coach,
        coachPrompt: l.capCoachPromptCouple,
        expectedImpact: l.capCoupleLppBuybackExpectedImpact,
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
        headline: l.capCoupleAvsCapHeadline,
        whyNow: l.capCoupleAvsCapWhyNow,
        ctaLabel: l.capCoupleAvsCapCtaLabel,
        ctaMode: CtaMode.route,
        ctaRoute: '/rente-vs-capital',
        coachPrompt: l.capCoachPromptMarried,
        expectedImpact: l.capCoupleAvsCapExpectedImpact,
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
        recency: _recencyModifier('rc_${card.id}', memory, now),
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
    S l,
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

    final acquired = _acquiredAssets(profile, l);

    // Choose the right tone depending on the trigger
    String headline;
    String whyNow;
    String coachPrompt;

    if (isDebtOverwhelmed) {
      headline = l.capHonestyDebtHeadline;
      whyNow = l.capHonestyDebtWhyNow;
      coachPrompt = l.capHonestyDebtCoachPrompt;
    } else if (isCrossBorderLateLpp) {
      headline = l.capHonestryCrossBorderHeadline;
      whyNow = l.capHonestryCrossBorderWhyNow;
      coachPrompt = l.capHonestyCrossBorderCoachPrompt;
    } else {
      // Senior no LPP
      headline = l.capHonestyNoLppHeadline;
      whyNow = l.capHonestyNoLppWhyNow;
      coachPrompt = l.capHonestyNoLppCoachPrompt;
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
      ctaLabel: l.capHonestyCtaLabel,
      ctaMode: CtaMode.coach,
      coachPrompt: coachPrompt,
      expectedImpact: l.capHonestyExpectedImpact,
      sourceCards: const [],
    );
  }

  /// Build a list of what the user HAS acquired (for honesty cap).
  /// Shows the positive side even when levers are exhausted.
  static List<String> _acquiredAssets(CoachProfile profile, S l) {
    final assets = <String>[];

    // AVS is always acquired if contributed
    final avsYears = profile.prevoyance.anneesContribuees ?? 0;
    if (avsYears > 0) {
      final renteAvs = profile.prevoyance.renteAVSEstimeeMensuelle;
      if (renteAvs != null && renteAvs > 0) {
        assets.add(l.capAcquiredAvsWithRente(
          renteAvs.round().toString(),
          avsYears.toString(),
        ));
      } else {
        assets.add(l.capAcquiredAvsYearsOnly(avsYears.toString()));
      }
    } else {
      assets.add(l.capAcquiredAvsInProgress);
    }

    // LPP if any
    final lpp = profile.prevoyance.avoirLppTotal ?? 0;
    if (lpp > 0) {
      assets.add(l.capAcquiredLpp(_formatChfRound(lpp)));
    }

    // 3a if any
    final epargne3a = profile.prevoyance.totalEpargne3a;
    if (epargne3a > 0) {
      assets.add(l.capAcquired3a(_formatChfRound(epargne3a)));
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

/// Maps cap IDs to semantic topics for cohort suppression.
/// Explicit mapping avoids fragile string.contains matching
/// (e.g., 'life_event_housingPurchase' must match 'housing_purchase').
String? _capSemanticTopic(String capId) {
  final lower = capId.toLowerCase();

  // Retirement-related
  if (lower.contains('retirement') || lower.contains('retraite') ||
      lower.contains('rente') || lower.contains('decaissement')) {
    return 'retirement_deep';
  }
  // Succession / estate
  if (lower.contains('succession') || lower.contains('estate') ||
      lower.contains('testament') || lower.contains('donation') ||
      lower.contains('heritage')) {
    return 'succession';
  }
  // LPP buyback
  if (lower.contains('buyback') || lower.contains('rachat')) {
    return 'lpp_buyback';
  }
  // Withdrawal sequencing
  if (lower.contains('withdrawal') || lower.contains('decaissement')) {
    return 'withdrawal_sequencing';
  }
  // Rente vs capital
  if (lower.contains('rente_vs') || lower.contains('renteoucapital')) {
    return 'rente_vs_capital';
  }
  // Housing
  if (lower.contains('housing') || lower.contains('logement') ||
      lower.contains('hypotheque') || lower.contains('immobilier')) {
    return 'housing_purchase';
  }
  // First job
  if (lower.contains('first_job') || lower.contains('premier_emploi') ||
      lower.contains('firstjob')) {
    return 'first_job';
  }
  // Unemployment
  if (lower.contains('unemployment') || lower.contains('chomage')) {
    return 'unemployment_basics';
  }
  // Birth / family young
  if (lower.contains('birth') || lower.contains('naissance') ||
      lower.contains('bebe')) {
    return 'birth_costs';
  }
  // Job comparison — includes life_event newJob caps
  if (lower.contains('job_comparison') || lower.contains('comparaison_offre') ||
      lower.contains('newjob') || lower.contains('new_job') ||
      lower.contains('life_event_newjob')) {
    return 'job_comparison';
  }
  // Estate planning
  if (lower.contains('estate_planning')) {
    return 'estate_planning';
  }

  return null; // Unknown cap — never suppress
}
