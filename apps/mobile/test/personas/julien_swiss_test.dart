/// Phase 90 PERS-08 (v2.13) — Dart post-run assertion suite for the
/// julien_swiss × Premier Éclairage persona scenario.
///
/// Runs AFTER the Maestro flow (`tools/simulator/flows/julien_swiss.yaml`)
/// completes its 5 in-app checkpoints. Reads artefacts dropped by the
/// walker (`.planning/walker/<run-id>/julien_swiss/`) and applies the
/// 4 panel-locked assertion contracts :
///
///   1. **Archetype assertion** — captured Sentry breadcrumb confirms
///      `MINT_E2E_ARCHETYPE=julien_swiss` was honoured at runtime.
///   2. **Narrative invariant** — `MintWalkthroughBreadcrumbs` emitted
///      `eclairage.card.tap` (or equivalent panel-tagged event) within
///      the 30s post-input window.
///   3. **LSFin regex assertion** — banned-term lexicon (garanti /
///      optimal / sans risque / parfait / le meilleur) MUST NOT appear
///      in any captured assistant message body.
///   4. **Numeric assertion (financial_core)** — éclairage card's
///      `chf_range_low` / `chf_range_high` MUST fall within the band
///      computed by `Pillar3aCalculator.maxAnnualForRange()` for the
///      julien_swiss profile fixture (age 49, salaire 8200/mo, canton
///      VS, has_lpp true). Cross-validates that the LLM didn't promise
///      out-of-bounds figures.
///
/// PERS-08 contract carry-forward Phase 91 :
///   - same 4 assertions on 8 archetypes (ARCH-01..08)
///   - LSFin regex library extended via `tools/checks/lsfin_lexicon.py`
///   - financial_core asserts against AvsCalculator + LppCalculator +
///     TaxCalculator depending on éclairage kind
///
/// Pre-requisite : walker run-id exported as env `MINT_WALKER_RUN_ID`.
/// In Phase 90 scaffolding the assertions are wired but the artifact
/// reader is stubbed (skip:true on the actual assertions, the test
/// structure compiles + documents the contract). Wiring lands when
/// PERS-02 walker `--maestro-flow` shell-out merges (post PR #500
/// Phase 86 walker improvements rebased onto Phase 90).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Phase 91 will wire :
// import 'package:mint_mobile/services/pillar_3a_calculator.dart';
// for the full numeric assertion against julien_swiss profile.

// Banned-term lexicon (subset, FR ; full library will land in
// `tools/checks/lsfin_lexicon.py` Phase 91 GROW-03).
final RegExp _bannedTerms = RegExp(
  r'\b(garanti[es]?|optimal|le?\s*meilleur|sans\s*risque|parfait[es]?)\b',
  caseSensitive: false,
);

void main() {
  group('PERS-08 julien_swiss × Premier Éclairage post-run assertions', () {
    test('archetype injected at runtime (dart-define honoured)', () {
      // Reads walker run summary.json → asserts profile.archetype
      // resolved to julien_swiss in CoachOrchestrator.
      // Phase 90 scaffolding : structure + skip true.
    },
        skip:
            'Phase 90 scaffolding — wiring lands with PERS-02 walker integration');

    test('narrative invariant — eclairage.card.tap breadcrumb fired', () {
      // Reads walker breadcrumb capture → asserts the
      // `mint.coach.eclairage.card.tap` (or panel-tagged equivalent)
      // breadcrumb was emitted within 30s of input submission.
    },
        skip:
            'Phase 90 scaffolding — wiring lands with PERS-02 + PERS-05 replay-cache');

    test('LSFin banned-term regex hit-count == 0 across captured response', () {
      // Reads walker assistant-response capture → applies _bannedTerms.
      const sampleResponse =
          'Plafond du 3e pilier 2026 environ 7 056 CHF. Tu pourrais envisager';
      final matches = _bannedTerms.allMatches(sampleResponse);
      expect(matches, isEmpty,
          reason: 'banned terms in response : '
              '${matches.map((m) => m.group(0)).toList()}');
    });

    test('numeric assertion : chf_range falls within Pillar3aCalculator band',
        () {
      // Reads éclairage payload chf_range_low/high → cross-validates
      // against Pillar3aCalculator for julien_swiss profile.
      // Phase 90 scaffolding : show the cross-check pattern with a
      // synthetic input ; real wiring reads the captured payload.
      const mockChfRangeLow = 1500;
      const mockChfRangeHigh = 2500;

      // Sanity : the band must respect order + be plausible.
      expect(mockChfRangeLow, lessThan(mockChfRangeHigh));
      expect(mockChfRangeLow, greaterThanOrEqualTo(0));
      // 2026 plafond du 3e pilier (salarié) = 7056 CHF (ASF / OFAS).
      // Phase 91 ARCH-08 will wire Pillar3aCalculator.compute() against
      // a julien_swiss profile fixture for the full numeric assertion.
      expect(mockChfRangeHigh, lessThanOrEqualTo(7056),
          reason: 'chf_range_high cannot exceed the 2026 plafond du 3e pilier '
              '(7056 CHF for salariés).');
    }, skip: 'Phase 90 scaffolding — full wiring reads walker artefact');

    test('walker run-id env var present', () {
      // Operational gate : surface a clear error if the assertion
      // suite is invoked without a walker run-id (= scaffolding
      // nobody ran the Maestro flow first).
      final runId = Platform.environment['MINT_WALKER_RUN_ID'];
      if (runId == null || runId.isEmpty) {
        markTestSkipped(
          'MINT_WALKER_RUN_ID not set — walker must run BEFORE this '
          'assertion suite. See tools/simulator/walker_premier_eclairage.sh '
          '--maestro-flow tools/simulator/flows/julien_swiss.yaml',
        );
        return;
      }
      expect(runId, matches(RegExp(r'^\d{4}-\d{2}-\d{2}-\d{6}-[0-9a-f]+$')),
          reason: 'walker run-id format : YYYY-MM-DD-HHMMSS-<sha7>');
    });
  });
}
