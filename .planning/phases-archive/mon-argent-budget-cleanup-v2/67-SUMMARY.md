Phase 67 folds the detailed Mon Argent source map behind an explicit expansion
so the default Today section stays a synthesis, while preserving the same
data-spine anchors for QA and Maestro after opening the detail panel.

## Goal

Keep Mon Argent centered on a global financial picture instead of exposing the
full source map on the first viewport.

## Context

- Product review warned against branch gravity toward debt-only work.
- Architecture review recommended a strangler cleanup inside the already wired
  Mon Argent path, without adding a new facade.
- QA review prioritized proving the Today section is a synthesis and not a
  duplicate of the deeper tabs.

## Changed

- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
  - The Today section now renders the existing `_MonArgentSituationMap` inside
    `_MonArgentDetailsExpansion`.
  - The detailed source map keeps its existing semantic key
    `mon_argent_situation_map` after expansion.
  - `_MonArgentSituationMap` can render without its own nested surface/title
    when embedded in the expansion.
- `apps/mobile/test/screens/mon_argent_screen_test.dart`
  - Tests now assert the detail rows are hidden on first paint and visible
    after opening `mon_argent_situation_expand`.
  - Maestro anchors remain covered after expansion.
- `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
  - The flow now opens `mon_argent_situation_expand` before asserting the
    detailed situation-map anchors.

## Verification

- Red-green verified: the updated Maestro-anchor test failed before the UI
  change because `mon_argent_situation_map` was still visible by default.
- `flutter test test/screens/mon_argent_screen_test.dart`
  - 14 tests passed.
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
  - No issues found.
- Focused Mon Argent suite:
  - `flutter test test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart test/services/mon_argent_patrimoine_aggregator_test.dart test/services/mon_argent/coach_whisper_service_test.dart`
  - 28 tests passed.
- YAML parse:
  - `flow_mon_argent_budget_setup_spine.yaml` parses as a two-document
    Maestro YAML file.
- `budget_read_contract.py`
  - OK.
- `wiki_lint.py lint`
  - No FAIL-level violations; 139 pre-existing warnings remain.
- Claude Opus review:
  - No blocker.
  - Important note handled: the Mon Argent Maestro flow now opens the detail
    panel before asserting `mon_argent_situation_map`.

## Expert Review

- Product manager: debt work is a guardrail, not the Mon Argent story.
- Architect review: proceed by tightening the wired path; do not create a new
  facade.
- QA: prioritize Today as synthesis, absurd-value guards, and debt-only
  regression tests.

## Next

- Add a focused guard for implausible monthly fixed charges at the Mon Argent
  boundary.
- Add a screen-level test that profile-budget freshness does not make the
  Prévoyance/Futur sections disappear.
