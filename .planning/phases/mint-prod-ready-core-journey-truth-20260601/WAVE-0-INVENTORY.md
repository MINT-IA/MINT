---
description: Wave 0 inventory of historical bugs, Maestro evidence, release gates, and source artifacts merged into the Core Journey Truth tracker.
status: active
date: 2026-06-01
---

# Wave 0 Inventory

## Purpose

This file prevents the Core Journey Truth phase from abandoning earlier salvage and Maestro work. It records which historical artifacts are already useful, which ones are stale, and which release gates remain open.

## Inventory Rules

- Historical evidence can inform priority, but a P0 is not closed unless the current tracker row has a current command/artifact.
- `/tmp` evidence is not durable enough for release closure. Re-runs must store logs/screenshots under this phase or `.planning/_walker/`.
- A historical registry that says "resolved" is lower authority than a newer registry that explicitly re-opens a release gate.
- Unit tests prove contracts. Maestro or simulator evidence proves human-visible journey behavior.

## Consolidated Rows

| CJT ID | Source artifact | What it contributes | Current decision |
|---|---|---|---|
| CJT-003 | `.planning/phases/money-trust-contract-v1-27-maestro-money-trust-proof/VERIFICATION.md` | Existing Maestro money-trust chain passed: build, install, then `flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml` exit 0. Evidence exists under `.planning/_walker/20260526T133151/` and the phase evidence folder. | Keep P0 `in_progress`; re-run on this branch after Rapport/navigation changes before marking verified. |
| CJT-003 | `.planning/phases/money-trust-contract-v1-40-mon-argent-grouped-situation-map/VERIFICATION.md` | Mon Argent grouped situation map has widget/analyze proof and `flow_mon_argent_budget_setup_spine.yaml` exit 0. | Use as supporting evidence for Mon Argent ownership, not full Money Trust closure. |
| CJT-011 | `.planning/phases/01.1-walkthrough-first-grounding/01.1-BUG-INVENTORY.md` | Found stale Coach 3a ceiling: Coach cited 2024 value while registry had 2025 value. | Historical root cause for current Coach Trust gate; do not re-close without current tests/runtime proof. |
| CJT-011 | `.planning/phases/01.4-coach-runtime-stale-data/HANDOFF-2026-05-21.md` | Documents Phase 01.4 fix: anonymous path wired `get_regulatory_constant`, forced tool choice, and staging curl returned 7258 CHF. | Mark CJT-011 `in_progress`; run current branch tests and hero Maestro flow. |
| CJT-012 | `.planning/phases/01.5-archetype-hard-gate-fatca/HANDOFF-2026-05-22.md` | Documents hard-gate implementation and pending G1/G2/G3 gates. | Keep release blocker open until current branch has CI/staging plus Maestro G1/G2 evidence. |
| CJT-012 | `tools/simulator/flows/maestro-perfect-set/flow_hardgate_expat_us.yaml` | Runtime flow exists for expat_us waitlist gate and names its expected screenshots. | Run with `bash tools/simulator/walker.sh --archetype expat_us` then Maestro; store evidence here. |
| CJT-019 | `evidence/coach-trust/maestro-hero-20260601T232904/` | Current simulator proof shows the hero path can reach Coach composer, then redirect to waitlist after send. It also captured `01.1-hero-legacy-age-only-screen.png`, while source/tests expect date of birth. | New P0 release blocker: isolate runtime/source drift and profile-gate inputs before claiming Coach Trust or archetype-gate closure. |
| CJT-015 | `tools/simulator/flows/regression/_INDEX.md` | Newest regression index marks `S004+F006+F007` as `OPEN-RELEASE-GATE`. | Overrides older "resolved/config-green" wording; Universal Links remain release-blocking. |
| CJT-016 | `tools/simulator/flows/regression/_INDEX.md` | Documents desired CI workflow `.github/workflows/maestro-regression.yml` as future/TBD. | Keep P1 open; local command matrix is needed now, CI gate later. |
| CJT-014 | `tools/simulator/flows/regression/_INDEX.md` and older Phase 97 rows | Multiple rows cite `/tmp/*.xml` and `/tmp/*.png`. | Re-run any release-relevant flow and store durable artifacts before claiming closure. |

## Current P0 Runtime Gates

| Gate | Command | Evidence destination | Blocks release? |
|---|---|---|---|
| Money Trust | `MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=60 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml` | `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/money-trust/` | yes |
| Coach Trust | `cd services/backend && python3 -m pytest tests/test_anonymous_chat_tool_use.py -q` plus `flow_hero_marge_fiscale_3a.yaml` | `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/coach-trust/` | yes |
| Archetype Gate | `bash tools/simulator/walker.sh --archetype expat_us` then `maestro test tools/simulator/flows/maestro-perfect-set/flow_hardgate_expat_us.yaml` | `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/archetype-gate/` | yes |
| Universal Links | signed TestFlight/real-device Universal Link proof for production/staging host | `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/universal-links/` | yes |
| Phase 02 Substrate | staging/prod alembic head, `fact_event`/`fact_current`, backfill x2, projection diff | `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/phase02-substrate/` | yes |

## Immediate Execution Order

1. Run fast targeted tests for Coach Trust and hard-gate contracts.
2. Collect subagent Wave 0/0.5 audit output and update this file if they find missing historical blockers.
3. Create evidence directories.
4. Run the current-branch Maestro gates in priority order: Coach Trust, Money Trust, Archetype Gate.
5. Only after runtime gates are current, touch UI/code for Rapport back behavior or design.

## Current Contract Evidence

| Gate | Command | Result | Artifact |
|---|---|---|---|
| Coach Trust backend tool-use | `cd services/backend && python3 -m pytest tests/test_anonymous_chat_tool_use.py -q` | `4 passed` | `evidence/coach-trust/pytest_anonymous_chat_tool_use_20260601.log` |
| Archetype hard-gate contracts | `cd apps/mobile && flutter test test/router/coach_route_archetype_guard_test.dart test/services/feature_flags_coach_hard_gate_test.dart test/services/coach_hard_gate_killswitch_test.dart test/integration/archetype_hard_gate_integration_test.dart` | `24 passed` | `evidence/archetype-gate/flutter_hard_gate_contracts_20260601.summary.txt` |
| Onboarding source contract | `cd apps/mobile && flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart` | `12 passed` | `evidence/archetype-gate/flutter_onboarding_mvp_wedge_storyboard_20260601.summary.txt` |
| Coach Trust Maestro runtime | `MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=90 ... flow_hero_marge_fiscale_3a.yaml` | red: reaches Coach composer, then waitlist after send | `evidence/coach-trust/maestro-hero-20260601T232904/` |

Note: the Flutter log includes expected localhost/fallback noise in kill-switch bypass cases. The tested contract is the gate/refusal/bypass behavior, not live Coach networking.

## Runtime Findings From Current Coach Trust Run

- `flow_hero_marge_fiscale_3a.yaml` was refreshed to traverse the current onboarding wedge instead of stopping on the `Ouvrir` storyboard frame.
- First rerun `maestro-hero-20260601T231756` proved the old flow assumption was wrong: the runtime reached a legacy `Quel âge tu as ?` screen while source/tests expect `Quelle est ta date de naissance ?`.
- Second rerun `maestro-hero-20260601T232247` reached the Coach composer and stored screenshots, but after interaction the app landed on `Encore en chantier pour ton profil`; no `OPP3/LIFD/art.7/art.38` citation appeared.
- Final rerun `maestro-hero-20260601T232904` updated the flow to fail earlier on waitlist, proving the immediate blocker is profile-gate/waitlist after send rather than the citation assertion itself.
- Current interpretation: CJT-011 cannot be closed, and CJT-019 must be solved first because Coach Trust evidence depends on a profile that the gate accepts as supported.
