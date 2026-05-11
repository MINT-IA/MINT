---
description: Phase 97 W3 regression flow registry — index of all per-bug regression Maestro flows that gate Phase 97+ PRs in CI. Each flow MUST reproduce its bug RED before fix, then exit 0 GREEN after fix. The fix's resolved status in 97-BUGS-REGISTRY.md depends on its row here.
phase: 97
created: 2026-05-11
maintainer: PM Claude — Phase 97 W7 iteration loop
schema_version: 1
---

# Phase 97 Regression Flow Registry

> Bootstrapped during Phase 97 W7 iteration cycle #2 (F001 close). Phase 97
> W3 deliverable formalizes this as the 24-flow regression suite registry
> (3 features × 8 archetypes per D-08). Phase 97 W7's per-bug regression
> flows feed this index incrementally as bugs close.

## Purpose

Per CONTEXT.md D-37, no-regression guarantees come from Maestro flows
LIVING in CI. Each row below is one Maestro flow that :

1. Reproduces a specific bug from `97-BUGS-REGISTRY.md` (RED state captured
   at registration time)
2. Asserts the bug's fix is present (GREEN state required at LOCK)
3. Runs on every PR via `.github/workflows/maestro-regression.yml` (Phase
   97 W3 deliverable — TBD when this index has ≥ 3 flows)
4. Blocks PR merge on any flow failure (PR-blocking gate)

## Active flows

| Bug ID | Flow path | Status | RED-state evidence | GREEN gate |
|--------|-----------|--------|---------------------|------------|
| F001 | `bug__F001__chat_input_bar_exists.yaml` | LOCKED 2026-05-11 | `/tmp/maestro_f001_red.xml` — exit 1, step 3 fails on cold-launch precondition (S001/F012/F013/F014/F028 block end-to-end Maestro until W5) | Flutter widget test — `cd apps/mobile && flutter test test/widgets/mint_chat_overlay_test.dart` (11/11 pass) ; Maestro flow becomes runnable end-to-end post-W5 |

## Per-archetype × per-feature regression flows (Phase 97 W3 deliverable)

Below is the target structure for the 24 flow regression matrix per
CONTEXT D-08 (3 features × 8 archetypes). Filled progressively in W3.

### feature : chat_as_verb

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `chat_as_verb__swiss_native.yaml` | TBD W3 |
| expat_eu | `chat_as_verb__expat_eu.yaml` | TBD W3 |
| expat_us | `chat_as_verb__expat_us.yaml` | TBD W3 (FATCA canary) |
| cross_border | `chat_as_verb__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `chat_as_verb__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `chat_as_verb__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `chat_as_verb__returning_swiss.yaml` | TBD W3 |
| near_retirement | `chat_as_verb__near_retirement.yaml` | TBD W3 |

### feature : citation_gate

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `citation_gate__swiss_native.yaml` | TBD W3 |
| expat_eu | `citation_gate__expat_eu.yaml` | TBD W3 |
| expat_us | `citation_gate__expat_us.yaml` | TBD W3 |
| cross_border | `citation_gate__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `citation_gate__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `citation_gate__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `citation_gate__returning_swiss.yaml` | TBD W3 |
| near_retirement | `citation_gate__near_retirement.yaml` | TBD W3 |

### feature : dag_invalidation

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `dag_invalidation__swiss_native.yaml` | TBD W3 |
| expat_eu | `dag_invalidation__expat_eu.yaml` | TBD W3 |
| expat_us | `dag_invalidation__expat_us.yaml` | TBD W3 |
| cross_border | `dag_invalidation__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `dag_invalidation__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `dag_invalidation__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `dag_invalidation__returning_swiss.yaml` | TBD W3 |
| near_retirement | `dag_invalidation__near_retirement.yaml` | TBD W3 |

## CI integration (Phase 97 W3 + W6)

Future CI workflow `.github/workflows/maestro-regression.yml` will :

1. Trigger on every PR touching `apps/mobile/` OR `services/backend/` OR
   `tools/simulator/flows/` (path filter)
2. For each row in « Active flows » + the 24-flow matrix : run on the
   Mac mini self-hosted runner (per memory `project_remote_control`)
   against Railway staging
3. Aggregate per-archetype JUnit XMLs via
   `tools/simulator/merge_maestro_junit.py` into one combined report
4. Post a PR comment with pass/fail breakdown + visual diff thumbnails
   (Phase 97 W4 visual baselines)
5. Block merge on any flow failure ; merge requires green across the
   full matrix.

## How to register a new flow

1. Author Maestro YAML at `tools/simulator/flows/regression/
   bug__<id>__<feature>__<archetype>.yaml` (per CONTEXT D-07 naming).
2. Capture RED-state JUnit XML BEFORE the fix lands. Cite the artifact
   path in the « RED-state evidence » column above.
3. Implement the fix surgically (Karpathy #3 — every changed line
   traces to the bug).
4. Re-run the flow ; verify GREEN. Cite the GREEN evidence in the row.
5. Add a row to the « Active flows » table above with the bug ID, flow
   path, LOCKED date, RED-state path, GREEN gate.
6. Update `97-BUGS-REGISTRY.md` : bug row goes IN_PROGRESS → RESOLVED
   with `repro_flow:` pointing to this flow.

## Naming convention (locked per CONTEXT D-07)

- Single-bug regression flows : `bug__<id>__<short-slug>.yaml`
  Example : `bug__F001__chat_input_bar_exists.yaml`
- Feature × archetype matrix flows : `<feature>__<archetype>.yaml`
  Example : `chat_as_verb__expat_us.yaml`

Tags inside the flow YAML follow CONTEXT D-07 :
`tags: [feature:<slug>, archetype:<slug>, phase-97, regression]`.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Registry bootstrapped : 2026-05-11 (W7 iter#2 F001 close)*
