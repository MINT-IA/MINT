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
        headline: 'Il manque une pièce',
        whyNow: '${top.label} — sans cette donnée, '
            'ta projection reste floue.',
        ctaLabel: top.action,
        ctaMode: CtaMode.capture,
        captureType: top.category,
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
        headline: 'Ta dette pèse',
        // Reframing rule: never show bad number alone — show the lever.
        whyNow: 'Rembourser le taux le plus élevé d\u2019abord '
            'libère de la marge chaque mois.',
        ctaLabel: 'Voir mon plan',
        ctaMode: CtaMode.route,
        ctaRoute: '/debt/repayment',
        expectedImpact: 'marge à retrouver',
        sourceCards: const ['debt_ratio'],
      ));
    }

    // ── 3. Critical: independent with zero LPP ──
    if (profile.employmentStatus == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal == 0)) {
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
          headline: 'Cette année compte encore',
          whyNow: 'Un versement 3a peut encore alléger '
              'tes impôts et renforcer ta retraite.',
          ctaLabel: 'Simuler mon 3a',
          ctaMode: CtaMode.route,
          ctaRoute: '/pilier-3a',
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
        headline: 'Rachat LPP disponible',
        whyNow: 'Tu peux racheter jusqu\u2019à '
            '${_formatChfRound(rachatMax)} et déduire de tes impôts.',
        ctaLabel: 'Simuler un rachat',
        ctaMode: CtaMode.route,
        ctaRoute: '/rachat-lpp',
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
          // Reframing: show the margin to recover, not just the red.
          headline: 'Ta marge à retrouver',
          whyNow: 'Ton budget serre. '
              'Ajuster une enveloppe peut redonner de l\u2019air.',
          ctaLabel: 'Ajuster mon budget',
          ctaMode: CtaMode.route,
          ctaRoute: '/budget',
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
            headline: 'Ta retraite pince encore',
            whyNow:
                '${rate.round()}\u00a0% de taux de remplacement. '
                'Un rachat ou un 3a change la trajectoire.',
            ctaLabel: 'Explorer mes scénarios',
            ctaMode: CtaMode.route,
            ctaRoute: '/rente-vs-capital',
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
          impact: 0.5,
          urgency: hasMortgage ? 0.6 : 0.4,
          confidencePenalty: _confPenalty(confidence.score),
          readiness: 1.0,
          recency: _recencyModifier('coverage_check', memory, now),
        ),
        headline: 'Ta couverture mérite un check',
        whyNow: 'IJM, AI, LPP invalidité — '
            'vérifie que ton filet tient.',
        ctaLabel: 'Vérifier',
        ctaMode: CtaMode.route,
        ctaRoute: '/invalidite',
        sourceCards: const [],
      ));
    }

    // ── 9. Goal alignment boost ──
    // If the user declared a GoalA, boost candidates that align with it.
    _applyGoalBoost(candidates, profile.goalA);

    // ── 10. Fallback: best ResponseCard → Cap ──
    // (renumbered from 9)
    if (candidates.isEmpty) {
      final cards =
          ResponseCardService.generateForPulse(profile, limit: 1);
      if (cards.isNotEmpty) {
        final card = cards.first;
        candidates.add(_fromResponseCard(card, confidence.score, memory, now));
      }
    }

    // ── 10. Ultimate fallback: enrichment ──
    if (candidates.isEmpty) {
      return CapDecision(
        id: 'fallback_enrich',
        kind: CapKind.complete,
        priorityScore: 1.0,
        headline: 'Complète ton profil',
        whyNow: 'Plus MINT te connaît, plus les leviers sont précis.',
        ctaLabel: 'Enrichir',
        ctaMode: CtaMode.capture,
        captureType: 'profile',
        confidenceLabel: 'confiance ${confidence.score.round()}\u00a0%',
      );
    }

    // Sort by priority and return the winner.
    candidates.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return candidates.first;
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
        },
      GoalAType.achatImmo => {
          'lpp_buyback',
          'budget_deficit',
        },
      GoalAType.independance => {
          'indep_no_lpp',
          'pillar_3a',
        },
      GoalAType.debtFree => {
          'debt_correct',
          'budget_deficit',
        },
      GoalAType.custom => <String>{},
    };
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

  // ── HELPERS ──────────────────────────────────────────────

  static String _formatChfRound(double amount) {
    final rounded = (amount / 1000).round();
    if (rounded >= 1000) {
      return 'CHF\u00a0${(amount / 1000000).toStringAsFixed(1)}M';
    }
    return 'CHF\u00a0${rounded}k';
  }
}
