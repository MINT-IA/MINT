// Sub-phase 01.5 W02-T04 — R5 Runtime Kill Switch (Codex release-blocker).
//
// Tests for the kill-switch behavior at the TWO gate sites wired in
// plan 02-03:
//   * coach_chat_screen.dart `_buildCoachContext` route gate (Mapper §7.2)
//   * coach_orchestrator.dart `_calibratedArchetypes` orchestrator guard
//     (Mapper §7.4 — both generateChat and generateNarrativeComponent)
//
// The orchestrator guard is testable directly via generateChat /
// generateNarrativeComponent — these tests assert the flag flips the
// behavior in both directions:
//   1. enableCoachHardGate=true (default) + non-calibrated ctx → refusal
//   2. enableCoachHardGate=false + non-calibrated ctx → proceeds
//      (falls through to the SLM → BYOK → fallback chain instead of
//      short-circuiting at the guard)
//
// The route gate (coach_chat_screen.dart) wrapping is verified via the
// PLAN acceptance criterion (grep returns ≥ 1 FeatureFlags.enableCoachHardGate
// hit at that file) — the gate decision logic lives in the pure helper
// evaluateCoachArchetypeGate which by design stays flag-agnostic
// (Karpathy #2 — no abstraction over a single call site).

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/feature_flags.dart';

CoachContext _ctx({
  String archetype = 'swiss_native',
  Map<String, double> knownValues = const {'fri_total': 60},
  Map<String, String> dataReliability = const {},
}) {
  return CoachContext(
    firstName: 'Test',
    age: 40,
    canton: 'ZH',
    archetype: archetype,
    knownValues: knownValues,
    dataReliability: dataReliability,
  );
}

void _resetFlags() {
  // Reset to defaults (NOT leaving the killswitch in a flipped state
  // across tests). enableCoachHardGate is the flag under test — every
  // test sets it explicitly. SLM disabled so the fallback chain hits
  // the deterministic FallbackTemplates branch.
  FeatureFlags.enableCoachHardGate = true;
  FeatureFlags.slmPluginReady = false;
  FeatureFlags.enableSlmNarratives = false;
  FeatureFlags.safeModeDegraded = false;
}

void main() {
  setUp(_resetFlags);
  tearDown(_resetFlags);

  group('R5 kill switch — orchestrator generateChat', () {
    test(
        '1. enableCoachHardGate=true (default) + archetype=expat_us → refusal fires',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'expat_us');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      expect(response.refused, isTrue,
          reason: 'Default gate ON → non-calibrated archetype refused');
      expect(response.refusalReason, 'archetype_not_calibrated');
    });

    test(
        '2. enableCoachHardGate=false + archetype=expat_us → guard bypassed (no refusal)',
        () async {
      FeatureFlags.enableCoachHardGate = false;
      final ctx = _ctx(archetype: 'expat_us');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      // Flag off → orchestrator does NOT short-circuit at the guard.
      // It falls through to the SLM → BYOK → fallback chain (rollback
      // path — coach renders to all archetypes per plan 02-04 design).
      expect(response.refused, isFalse,
          reason: 'Flag false → guard MUST be bypassed (R5 rollback path)');
      expect(response.message, isNotEmpty,
          reason: 'Fallback chain still produces a message');
    });

    test('3. enableCoachHardGate=true + archetype=unknown → refusal fires',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'unknown');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      expect(response.refused, isTrue);
      expect(response.refusalReason, 'archetype_not_calibrated');
    });

    test('4. enableCoachHardGate=false + archetype=unknown → guard bypassed',
        () async {
      FeatureFlags.enableCoachHardGate = false;
      final ctx = _ctx(archetype: 'unknown');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      expect(response.refused, isFalse);
    });

    test(
        '4b. enableCoachHardGate=true + independent_no_lpp safe local topic → deterministic fallback',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(
        archetype: 'independent_no_lpp',
        knownValues: const {
          'self_employed_net_income_annual': 86400,
          'annual_3a_contribution': 6000,
        },
        dataReliability: const {
          'independentNetProfessionalIncomeAnnual': 'userInput',
        },
      );
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        history: const [],
        ctx: ctx,
        isLoggedIn: true,
      );

      final message = response.message.toLowerCase();
      expect(response.refused, isFalse,
          reason:
              'A calibrated local fallback topic should not hit LLM tiers or refusal');
      expect(message, contains('revenu net d\'activité'));
      expect(message, contains('marge 3a à vérifier'));
      expect(message, contains('86\u00a0400\u00a0chf/an'));
      expect(message, contains('6\u00a0000\u00a0chf/an'));
      expect(message, contains('11\u00a0280\u00a0chf/an'));
      expect(message, contains('revenu déterminant fiscal/avs'));
      expect(message, contains('faits mint'));
      expect(message, contains('provenance et fraîcheur'));
      expect(message, contains('revenu professionnel: saisie dans mint'));
      expect(message, contains('date par champ non affichée'));
      expect(message, contains('confirmations manquantes'));
      expect(message, contains('comparer avant de verser'));
      expect(message, contains('carte de décision'));
      expect(message, contains('marge légale 3a'));
      expect(message, contains('capacité mensuelle'));
      expect(message, contains('couverture risque'));
      expect(message, contains('fiscalité'));
      expect(message, contains('prochaine action prudente'));
      expect(message, contains('budget mensuel'));
      expect(message, contains('marge légale ≠ capacité mensuelle'));
      expect(message, isNot(contains('7\u00a0258')));
      expect(message, isNot(contains('versement 3a 2026')));
      expect(message, isNot(contains('impact fiscal indicatif')));
      expect(message, isNot(contains('2\u00a0218 chf')));
      expect(message, isNot(contains('7\u00a0137 chf')));
      expect(message, isNot(contains('3\u00a0068 chf')));
      expect(message, isNot(contains('salarié')));
      expect(message, isNot(contains('ouvre')));
      expect(message, isNot(contains('fintech')));
      expect(message, isNot(contains('meilleur')));
      expect(message, isNot(contains('optimal')));
      expect(message, isNot(contains('sans risque')));
    });

    test('4b2. independent_no_lpp context handles plain 3a capacity wording',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(
        archetype: 'independent_no_lpp',
        knownValues: const {
          'self_employed_net_income_annual': 86400,
          'annual_3a_contribution': 6000,
        },
      );
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Combien verser en 3a ?',
        history: const [],
        ctx: ctx,
        isLoggedIn: true,
      );

      final message = response.message.toLowerCase();
      expect(response.refused, isFalse);
      expect(message, contains('marge 3a à vérifier'));
      expect(message, contains('11\u00a0280\u00a0chf/an'));
      expect(message, contains('revenu déterminant fiscal/avs'));
      expect(message, contains('carte de décision'));
      expect(message, contains('lpp facultative'));
      expect(message, contains('prochaine action prudente'));
      expect(message, isNot(contains('versement 3a 2026')));
    });

    test(
        '4b3. independent_no_lpp safe local topic refuses to invent margin when income is missing',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'independent_no_lpp');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Combien verser en 3a ?',
        history: const [],
        ctx: ctx,
        isLoggedIn: true,
      );

      final message = response.message.toLowerCase();
      expect(response.refused, isFalse);
      expect(message, contains('donnée manquante'));
      expect(message, contains('ne peut pas calculer'));
      expect(message, contains('carte de décision'));
      expect(message, contains('capacité mensuelle'));
      expect(message, contains('confirmations manquantes'));
      expect(message, contains('prochaine action prudente'));
      expect(message, isNot(contains('marge légale restante serait')));
      expect(message, isNot(contains('86\u00a0400')));
      expect(message, isNot(contains('11\u00a0280')));
    });

    test(
        '4c. enableCoachHardGate=true + independent_no_lpp generic question still refuses',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'independent_no_lpp');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
        isLoggedIn: true,
      );

      expect(response.refused, isTrue);
      expect(response.refusalReason, 'archetype_not_calibrated');
    });

    test(
        '4d. enableCoachHardGate=true + expat_us using safe phrase still refuses',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'expat_us');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        history: const [],
        ctx: ctx,
        isLoggedIn: true,
      );

      expect(response.refused, isTrue);
      expect(response.refusalReason, 'archetype_not_calibrated');
      expect(response.message.toLowerCase(),
          isNot(contains('revenu net d\'activité')));
    });

    test('4e. enableCoachHardGate=true + expat_us cannot stream via SLM', () {
      FeatureFlags.enableCoachHardGate = true;
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.slmPluginReady = true;
      final ctx = _ctx(archetype: 'expat_us');

      final stream = CoachOrchestrator.streamChat(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        history: const [],
        ctx: ctx,
      );

      expect(stream, isNull,
          reason:
              'Non-calibrated archetypes must not enter SLM streaming before the hard gate');
    });

    test(
        '4f. enableCoachHardGate=true + independent_no_lpp safe route still cannot stream via SLM',
        () {
      FeatureFlags.enableCoachHardGate = true;
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.slmPluginReady = true;
      final ctx = _ctx(archetype: 'independent_no_lpp');

      final stream = CoachOrchestrator.streamChat(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        history: const [],
        ctx: ctx,
      );

      expect(stream, isNull,
          reason:
              'Route access for independent_no_lpp must stay safe-local-only and never open SLM streaming');
    });
  });

  group('R5 kill switch — orchestrator generateNarrativeComponent', () {
    test(
        '5. enableCoachHardGate=true + archetype=cross_border → refusal payload',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'cross_border');
      final out = await CoachOrchestrator.generateNarrativeComponent(
        componentType: ComponentType.tip,
        ctx: ctx,
      );
      // Refusal payload at narrative surface → fallback tier + the
      // « pas encore calibré » copy.
      expect(out.tier, CoachTier.fallback);
      expect(out.text, isNotEmpty);
    });

    test(
        '6. enableCoachHardGate=false + archetype=cross_border → guard bypassed',
        () async {
      FeatureFlags.enableCoachHardGate = false;
      final ctx = _ctx(archetype: 'cross_border');
      final out = await CoachOrchestrator.generateNarrativeComponent(
        componentType: ComponentType.tip,
        ctx: ctx,
      );
      // Flag off → narrative component proceeds; the production fallback
      // chain still produces a non-empty text.
      expect(out.text, isNotEmpty,
          reason: 'Fallback chain still produces a message when guard '
              'is bypassed');
    });
  });

  group('R5 kill switch — calibrated archetype unchanged', () {
    test(
        '7. enableCoachHardGate=true + archetype=swiss_native → no refusal (no regression)',
        () async {
      FeatureFlags.enableCoachHardGate = true;
      final ctx = _ctx(archetype: 'swiss_native');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      expect(response.refused, isFalse,
          reason: 'Calibrated archetype: never refused regardless of flag');
    });

    test(
        '8. enableCoachHardGate=false + archetype=swiss_native → still no refusal',
        () async {
      FeatureFlags.enableCoachHardGate = false;
      final ctx = _ctx(archetype: 'swiss_native');
      final response = await CoachOrchestrator.generateChat(
        userMessage: 'Comment va ma retraite ?',
        history: const [],
        ctx: ctx,
      );
      expect(response.refused, isFalse);
    });
  });
}
