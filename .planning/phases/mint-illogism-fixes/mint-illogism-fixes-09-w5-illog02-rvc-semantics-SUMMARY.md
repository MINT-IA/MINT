---
phase: mint-illogism-fixes
plan: 09
subsystem: ui
tags: [a11y, semantics, accessibility, ios-bridge, voiceover, maestro, rente-vs-capital, illog-02]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-05
    provides: 3a tax-saving married plan (wave-1 prerequisite per depends_on)
provides:
  - Screen-root Semantics(container, explicitChildNodes) boundary on RenteVsCapitalScreen (canonical iOS-safe pattern)
  - Per-field Semantics(container, label)+ExcludeSemantics on _buildLabeledField (discrete AX node per input)
  - bug__ILLOG02__rvc_ax_tree_empty.yaml GREEN (was OPEN-RED) — unblocks plan 10 / ILLOG-01 Maestro gate
  - rente_vs_capital_semantics_test.dart (permanent SemanticsTester regression)
affects: [rente-vs-capital, accessibility, maestro-gates, plan-10-illog01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Screen-root Semantics(container:true, explicitChildNodes:true) wrapping the Scaffold to prevent iOS-bridge route collapse (matches mon_argent / budget)"
    - "Per-field Semantics(container, label:) with inner visual Text ExcludeSemantics-wrapped to expose one clean discrete AX node without label doubling"
    - "Authoritative AX verification via Maestro (engages the iOS accessibility service) — manual `idb describe-all` returns 1 element when AX is not engaged and must NOT be used as ground truth"

key-files:
  created:
    - apps/mobile/test/screens/rente_vs_capital_semantics_test.dart
  modified:
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
    - tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml
    - tools/simulator/flows/regression/_INDEX.md
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-VALIDATION.md

key-decisions:
  - "Root cause is iOS-accessibility-bridge collapse, NOT a Dart widget-tree defect: the Dart semantics tree was always fully populated (34 nodes confirmed via SemanticsTester under both android and iOS platform overrides). The `idb describe-all => 1 element` symptom is the bridge collapsing the route because the screen identifier sat on the AppBar title leaf with no screen-root container boundary."
  - "Escaped the LPP flow assertion parens (`\\(CHF\\)`) as a Rule-1 bug fix: Maestro matches `text` as a regex, so the original unescaped `(CHF)` was a capture group that could never match the on-screen literal — independent of AX state."
  - "Per-field Semantics needed in ADDITION to the screen-root boundary: the input-section labels were merged into one blob node, and Maestro `assertVisible` does not substring-match a merged multi-line accessibility label (it matched discrete nodes only)."

# Metrics
metrics:
  duration: ~110 min
  completed: 2026-06-11
  tasks: 2
  commits: 3
  files_created: 1
  files_modified: 4
---

# Phase mint-illogism-fixes Plan 09: W5/ILLOG-02 RenteVsCapitalScreen Accessibility Tree Summary

**One-liner:** Fixed the VoiceOver-silent / Maestro-unreachable RenteVsCapitalScreen by adding the canonical screen-root `Semantics(container, explicitChildNodes)` boundary plus per-field discrete-label semantics, taking the iOS accessibility tree from 1 element to 29 and flipping `bug__ILLOG02__rvc_ax_tree_empty.yaml` from OPEN-RED to GREEN (warm + cold on iPhone 16e), which mechanically unblocks the plan-10 / ILLOG-01 Maestro gate.

## What Was Built

### Task 1 — Diagnostic (RED) — commit `3405f83e7`
- Created `apps/mobile/test/screens/rente_vs_capital_semantics_test.dart` (216 lines): a `SemanticsTester`-style test that compiles the screen's semantics tree and asserts (a) the title + estimate-mode + LPP-field labels surface, and (b) the `rente_vs_capital_screen` identifier is a **container ancestor of the body** (the canonical contract that healthy screens satisfy).
- **Key diagnostic finding (Karpathy #1 — surfaced the inconsistency):** the Dart-level semantics tree was NEVER empty. Dumps under both android and iOS `defaultTargetPlatform` showed a fully-populated 34-node tree with the title, all field labels and controls. So the `idb ui describe-all => 1 element` device symptom is an **iOS accessibility-bridge collapse**, not a Dart widget-tree defect.
- **Root cause (cited file:line):** `rente_vs_capital_screen.dart:610-617` placed the `rente_vs_capital_screen` `Semantics(key:, identifier:, child: Text())` node directly on the SliverAppBar **title leaf** (a node inside the route `header`), with NO `container: true` and NO `explicitChildNodes: true`. The two healthy sibling screens that DO surface to `idb` wrap their whole Scaffold in `Semantics(identifier:, container:true, explicitChildNodes:true, child: Scaffold(...))` (`mon_argent_screen.dart:141-145`, `budget_screen.dart:219-223`). Without an `explicitChildNodes` screen-root boundary, the iOS bridge collapses the route subtree into the single identified header node.
- The 2nd test reproduced this deterministically (RED): the identified node only contained the title, not the body.

### Task 2 — Fix (GREEN) — commits `15a877bc6` + `fcfa53c7d`
- **Screen-root boundary** (`15a877bc6`): wrapped the `Scaffold` in `Semantics(key: Key('rente_vs_capital_screen'), identifier: 'rente_vs_capital_screen', container: true, explicitChildNodes: true, child: Scaffold(...))` and reverted the AppBar title to a plain `Text` (identifier now lives on the root boundary). This made the title + estimate-mode control findable on the real iOS bridge.
- **Per-field discrete labels** (`fcfa53c7d`): wrapped each `_buildLabeledField` in `Semantics(container: true, label: label, child: Column(...))` with the inner visual label `Text` `ExcludeSemantics`-wrapped (so the field exposes ONE clean discrete node without doubling). This de-merged the input-section blob so `Ton avoir LPP actuel (CHF)` surfaces as its own AX node.
- **Flow regex fix** (`fcfa53c7d`): escaped the literal parentheses in the LPP assertion (`"Ton avoir LPP actuel \\(CHF\\)"`). Maestro matches `text` as a regex; the original unescaped `(CHF)` was a capture group that could never match the on-screen literal — a Rule-1 bug in the flow itself.

## Device Gate Evidence (0-TRUST citations)

All on **iPhone 16e simulator, iOS 26.2** (the device the bug was triangulated on), debug `--no-codesign` build (`.nosync` xattr-strip doctrine applied before each rebuild):

- `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml`:
  - **WARM run EXIT 0** (`~/.maestro/tests/2026-06-11_191951` → re-run green): `Assert "Rente ou capital.*"` COMPLETED, `Assert "Estimer pour moi"` COMPLETED, `Assert "Ton avoir LPP actuel \(CHF\)"` COMPLETED, screenshot COMPLETED.
  - **COLD run EXIT 0** post sim-reboot (`/tmp/illog02_maestro_cold.log`): all 3 assertions COMPLETED. Satisfies the plan's froid+chaud requirement.
- `idb ui describe-all` (AX engaged, post-Maestro): **29 elements** (was **1** = the ILLOG-02 symptom), with discrete labelled nodes for `Rente ou capital : ta décision`, `Ton âge`, `Ton revenu brut annuel (CHF)`, `Ton avoir LPP actuel (CHF)`.
- `cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart test/screens/arbitrage_screens_smoke_test.dart` → **29 passed** (2 semantics + 27 arbitrage smoke).
- `cd apps/mobile && flutter analyze` → **No issues found**.
- `git diff --name-only` shows **no `.arb` file modified** (wave-7 parallelism constraint with plan 07 respected).

## Design Panel (a11y-territory change, per feedback_design_panel_before_push)

Semantics edits are a11y territory, so the 4-lens panel was applied to the diff before the final push:
- **a11y:** PASS — the change is a strict accessibility improvement. VoiceOver now reads the title, every field label and control (previously the route was a single silent node). Field labels are now properly associated with their inputs as discrete elements. No banned-term / copy change.
- **UX:** PASS — zero visual change (screenshot `/tmp/illog02_state.png` confirms the screen renders pixel-identically); the fix is invisible to sighted users and purely additive to assistive tech.
- **Adversarial:** PASS — verified the empty-tree was not masked by a transient loading state (stable across +2/+4/+6/+10s captures) and that the `idb => 1 element` reading is an AX-not-engaged artifact (authoritative measurement is Maestro, which engages AX). Both froid and chaud runs green.
- **Engineering/wiring:** PASS — surgical diff (no dart-format churn on unrelated lines, Karpathy #3), follows the established `mon_argent` / `budget` screen-root pattern, no new dependencies, no ARB churn, no `_calculate*` / financial_core boundary touched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Escaped unmatchable regex in the regression flow**
- **Found during:** Task 2 device verification.
- **Issue:** `bug__ILLOG02__rvc_ax_tree_empty.yaml` asserted `"Ton avoir LPP actuel (CHF)"`; Maestro matches `text` as a regex, so `(CHF)` was a capture group that could never match the literal on-screen `(CHF)` — the assertion was unmatchable regardless of AX-tree state.
- **Fix:** escaped the parens (`\\(CHF\\)`), aligning with the repo's existing regex convention (e.g. `.*Explique-moi.*`, `\\s`).
- **Files modified:** `tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml`
- **Commit:** `fcfa53c7d`

**2. [Plan-premise correction] RED reproduces a structural contract, not an empty Dart tree**
- The plan's Task 1 asked to "confirmer le quasi-vide en environnement de test (pas seulement sim)." The Dart semantics tree is NOT empty in the test environment (verified via SemanticsTester dumps on both platforms). The RED test instead pins the canonical screen-root contract (identifier must be a container ancestor of the body) that the pre-fix screen violates — this is the deterministic, test-reproducible expression of the same defect. The cause was cited file:line before fixing (no fix-at-random), satisfying the spirit of the acceptance criterion.

### Per-field-semantics iteration (no residual deviation)
- Several per-field semantics variants (`MergeSemantics`, bare `container:true`, `label:`-only) were trialled. The shipped variant (`Semantics(container, label) + ExcludeSemantics` inner text) is the one verified GREEN via Maestro. Intermediate manual-`idb` readings of "1 element" were an AX-not-engaged measurement artifact, not real regressions — recorded here so future work uses Maestro (not manual idb) as the AX ground truth.

## Known Stubs
None. The screen renders real engine-computed values (offline fallback to `ArbitrageEngine` confirmed on sim: `Capital estimé à 65 ans : ~619'013`).

## Threat Surface
No new network endpoints, auth paths, or schema changes. The change only widens the accessibility surface (labels that were already visible on screen are now also exposed to assistive tech) — matches the plan threat register T-ILF-09-02 disposition `accept` ("n'exposent que ce qui est déjà visible à l'écran"). T-ILF-09-01 (a11y DoS) is mitigated as planned: Semantics boundary + permanent SemanticsTester + GREEN regression flow.

## Build Constraint Note
The `.nosync` iCloud mount re-applies provenance xattrs that break codesign during `flutter build ios --simulator`; an `xattr -cr build/ios` + `dot_clean -m` strip before each rebuild was required (consistent with the walker's `--no-codesign` + `Strip xattrs before codesign` doctrine). This is the same constraint that deferred plan 06's device-proof; here it was worked around successfully to produce the device-green citations above.

## Self-Check: PASSED
- Created file present: `apps/mobile/test/screens/rente_vs_capital_semantics_test.dart` — FOUND
- Modified files present: `rente_vs_capital_screen.dart`, `bug__ILLOG02__rvc_ax_tree_empty.yaml`, `_INDEX.md`, `VALIDATION.md` — FOUND
- Commits present: `3405f83e7` (test/RED), `15a877bc6` (fix/root boundary), `fcfa53c7d` (fix/per-field + flow regex) — FOUND
- Maestro flow EXIT 0 warm + cold; `flutter analyze` 0 issues; 29 widget tests green; no ARB modified.
