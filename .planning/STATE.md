---
gsd_state_version: 1.0
milestone: v2.13
milestone_name: Persona Narrative Scenario Coverage
status: planning
stopped_at: v2.13 milestone declared 2026-05-05 ; panel 6-pers locked ; PROJECT/REQUIREMENTS/ROADMAP/STATE shipped on chore/milestone-v2.13-setup. Awaiting v2.12 STAMP-08 PASS before Phase 90 execute. v2.12 in flight (Phase 86 julien_swiss GREEN commit 8d3c127a, Phase 87 SHIPPED PR #498, 88-89 pending).
last_updated: "2026-05-05T22:00:00Z"
last_activity: 2026-05-05
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State: MINT v2.13 — Persona Narrative Scenario Coverage

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-05)

**Core value:** Aucun TestFlight tant que les 5 scripts journalist-defense ne sont pas green pour 5 nuits consécutives sur simulator. Single-persona narrative > matrice multi-archetype. KPI = pass rate, pas screenshot-distinct.

**Current focus:** Pre-execute. Waiting on v2.12 STAMP-08 PASS. Once unlocked → Phase 90 (10 cells + tooling adoption).

## Architecture Decisions (pre-phase, v2.13)

Panel-locked 2026-05-05 via `.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md` (6-pers panel : CI cost / E2E architecture / Storytelling / Maestro vs walker / Swiss financial / Postmortem).

- **Tooling**: hybrid 3-layer. L0 walker_premier_eclairage.sh (KEPT) + L1 Maestro YAML flows + L2 Dart post-run assertions. Pas Patrol (lock-in, CI flake reports). Pas pure walker (1800-2400 LoC bash bomb à 50 scripts). Pas pure Maestro (no SSIM, no dart-defines).
- **Scope cap**: 2 personas × 1 scenario × 5 phases = 10 cellules à Phase 90. Aucune extension avant 5 nuits nightly-green consécutives.
- **LLM mock**: replay-cache obligatoire (`tools/simulator/cache/replay/`). `MINT_LLM_CACHE_MODE=replay` default. Live opt-in pour weekly LLM regression.
- **Goldens**: R2 bucket `mint-goldens/` (pas git, pas LFS). Cloudflare R2 = $0.015/GB/mo + zero egress.
- **Locator audit lint**: `tools/checks/maestro_locator_audit.py` blocking (pre-commit + CI). Drift de `tapOn:` literal = CI red same commit.
- **Scope guards (anti-Phase-51)**: aucune persona ajoutée avant nightly-green ; aucun matrix expansion avant 10 cellules stable ; recorded-fixture mock obligatoire ; pas de walker overhaul phase ; pas de delegated_via_substitute markdown.
- **TestFlight ship gate**: 5 journalist-defense scripts × 5 nuits + walker green + flutter analyze + pytest -q. Gating Phase 92 SHIP-GATE-PASS.html.

**Past attempt corpse** (Phase 51 / Phase 74) catalogued + REUSED, not deleted (panel #6 rule « burn or commit to reuse — no half-alive »).

## Current Position

**Phase:** Pre-90 (declaration only — not yet running)
**Status:** ARCHITECTURE LOCKED, AWAITING v2.12 STAMP-08 PASS
**Effort to date:** 0d (declaration only)
**Effort to ship gate:** ~9d v2.12 + ~9d v2.13 (Phase 90+91+92 ; Phase 93 = post-launch growth)

## Phase Plan (v2.13)

| # | Phase | REQs | Effort | Pre-req | Status |
|---|---|---|---|---|---|
| 90 | 2 personas × 1 scenario × 5 phases (10 cells) + tooling adoption | PERS-01..08 (8) | 4.0d | v2.12 STAMP-PASS | Pending |
| 91 | 8 archetypes × canonical scenario each | ARCH-01..08 (8) | 3.0d | Phase 90 nightly-green 5 nuits | Pending |
| 92 | 5 journalist-defense scripts (= ship gate) | JDEF-01..08 (8) | 2.0d | Phase 91 closed | Pending |
| 93 | Croissance vers 50 par matrice swiss-financial | GROW-01..08 (8) | 4.0d | Phase 92 SHIP-GATE PASS | Pending |

**Critical path**: 90 → 91 → 92 → 93. NO parallelization.

## Carry-forward / Pre-requisites

- v2.12 PRs : Phase 86 (walker green 4 archetypes — julien_swiss GREEN today, 3 pending), Phase 87 (bare-catches Wave 1 SHIPPED), Phase 88 (12-walks cross-language pending), Phase 89 (7-gate STAMP pending)
- Existing reusable infra (Phase 51 corpse) : `walker.sh --archetype` slugs, `tools/simulator/walker_premier_eclairage.sh`, `MintWalkthroughBreadcrumbs` family (6 emit sites), `MINT_E2E_ARCHETYPE` dart-define consumer + debug overlay, 36 walker run dirs in `.planning/walker/`, 8 archetype seeds, brittle `integration_test/persona_marc_test.dart` + `persona_lea_test.dart` (will be deleted in Phase 90 and replaced with Maestro YAML flows).

## Open Questions / Risks (panel-flagged)

1. **Maestro semantic locator drift** (panel #4) — `tapOn:` literal stops resolving after refactor. **Mitigation : `tools/checks/maestro_locator_audit.py` shipped same PR as Phase 90.**
2. **Flake budget at 50 scripts** (panel #1) — industry baseline 4.5-26%, target <3% per script. **Mitigation : LLM replay-cache + sim warm-pool + auto-retry once + quarantine after 3 consecutive flakes.**
3. **R2 setup operational gap** (panel #1) — Cloudflare account + bucket not yet provisioned. **Mitigation : Phase 90 PERS-06 explicitly provisions ; until then, goldens land local-only with manifest schema validated.**
4. **Phase 90 hard-stop discipline** (panel #6) — past attempts broke this. **Mitigation : `tools/checks/persona_growth_gate.py` lint refuses scope expansion until prior personas nightly-green 5 nuits, verifiable via R2 manifest history.**
5. **Recorded-fixture mock for backend** (panel #6) — Phase 51 killed by missing API key. **Mitigation : LLM replay-cache mandatory, Phase 90 PERS-05 ships record/replay modes ; Anthropic API key never gates a script run.**

## Key Files (will be created during phases)

- `tools/simulator/flows/julien_swiss.yaml` (Phase 90)
- `tools/simulator/flows/lauren_expat_us.yaml` (Phase 90)
- `tools/simulator/flows/sofia_independent.yaml` (Phase 92)
- `tools/simulator/flows/anna_widow.yaml` (Phase 92)
- `tools/simulator/flows/jennifer_fatca.yaml` (Phase 92)
- `tools/simulator/flows/pierre_late_career.yaml` (Phase 92)
- `tools/simulator/assertions/<persona>.dart` (Phase 90+91+92)
- `tools/simulator/cache/replay/<persona>/<turn>.json` (Phase 90)
- `tools/simulator/goldens_manifest_schema.json` (Phase 90)
- `tools/simulator/scenarios_index.yaml` (Phase 93)
- `tools/checks/maestro_locator_audit.py` (Phase 90)
- `tools/checks/persona_growth_gate.py` (Phase 93)
- `tools/simulator/auto_bisect.py` (Phase 93)
- `.github/workflows/nightly-persona.yml` (Phase 92)
- `.planning/persona-tests/AUTHORING.md` (Phase 93)

## Sources

- `.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md` (panel synthesis 6-pers)
- `.planning/deep-audit-2026-04-17/02-persona-journeys.md` (10 personas audited prose, 7/10 BROKEN/PARTIAL)
- `.planning/walker/` (36 run dirs Phase 51 corpse, kept as evidence)
- `.planning/wave-0-walkthrough-verite/PLAN.md` (lean version that worked, 12 flows)
- `.planning/MVP-FLOW-walkthrough-2026-04-21.md` (single-persona narrative that produced findings)
- `apps/mobile/lib/models/coach_profile.dart` (FinancialArchetype enum, 8 values, lines 50-78)
- `apps/mobile/lib/services/coach/coach_profile_seeds.dart` (4 archetype seed JSON)

---
*Last updated: 2026-05-05 — v2.13 milestone declared, panel-locked, awaiting v2.12 STAMP-08 PASS to begin Phase 90 execution.*
