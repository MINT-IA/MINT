---
name: Maestro Paroxysm — 4-expert panel synthesis
description: Julien asked to push Maestro to its paroxysm. 4 parallel experts (Maestro/CI specialist, MINT mobile architect, QA test-pyramid SME, MINT Product PM) converged on "stop, fix drawer locator surgically, defer paroxysm campaign". Decision artifact + execution plan.
type: decision
date: 2026-05-09
status: Proposed
related:
  - .planning/phases/92-mvp-fonts-tokens-v2/92-CONTEXT.md
  - tools/simulator/README.md
  - feedback_maestro_for_sim_tests.md (memory, just-saved 2026-05-09)
  - feedback_expert_panel_pattern.md (memory)
sources:
  - https://docs.maestro.dev/extra-materials (Julien-shared)
  - https://docs.maestro.dev/reference/commands-available/assertwithai
  - https://docs.maestro.dev/maestro-flows/workspace-management/ai-test-analysis
  - https://maestro.dev/blog/visual-testing
  - https://docs.maestro.dev/maestro-cloud/ci-cd-integration/github-actions
panelists:
  - "Maestro/CI specialist (Sonnet) — paroxysm tactics + CI integration + Maestro-native visual regression"
  - "MINT mobile architect (Sonnet) — coverage gap map + selector strategy + drawer rename root cause"
  - "QA test-pyramid SME (Sonnet) — ROI math + contrarian frame + financial_core gap"
  - "MINT Product PM (Sonnet) — opportunity cost + Phase 91/92 closure dependency"
---

# Maestro Paroxysm — Panel Synthesis

## Trigger

Julien 2026-05-09 (mid-session, after Phase 92 Wave 3 G1 evidence captured via `xcrun simctl io booted screenshot` instead of Maestro):

> « Si tu as des tests à faire sur le simulateur, il faut les faire via maestrodoc. Et sache qu'un agent a travaillé dessus pour essayer de l'optimiser un maximum. J'aimerais aussi que tu passes du temps là autour pour que cet outil Maestro soit extrêmement bien utilisé et qu'on pousse les tests à son paroxysme. »

Plus full-autonomy grant + panel directive.

## Convergent verdict (4/4 panelists)

**Drawer locator regression (`flow_drawer_navigation_smoke.yaml` asserts "Explorer" visible → FAILED on iOS 26.2 sim today) is the prerequisite to everything.** Adding more flows on top of an unverified base = "speculation compounding speculation" (QA SME). Paroxysm campaign without stable baseline = theater (3/4 explicit). The fix is surgical, 1-2h.

## Divergent recommendations on what to do AFTER drawer fix

| Panelist | Tier 2 recommendation | Strongest argument |
|---|---|---|
| Maestro/CI specialist | Wire `assertScreenshot:` golden regression + `assertWithAI:` LSFin runtime gate + CI workflow | Maestro 2.2+ native visual regression supersedes the disconnected `image_diff.py` path; CI wiring multiplies leverage |
| MINT mobile architect | Author top 5 missing P0 flows (mortgage affordability, LSFin chat guard, frontalier, independant_no_lpp, anon PII scrub) | 3/18 life events covered; 6/8 archetypes have zero Maestro coverage; coverage gap is journalist-defensibility risk |
| QA test-pyramid SME | financial_core unit tests (10-15 tests, 2h) — financial_core has only 1 test file | Wrong number in financial app = trust-destroying event no E2E test catches if UI renders fine |
| MINT Product PM | Build Phase 91 Wave 3 autonomous parts (eval harness + 50 fixtures + COACH_NARRATOR_MODEL flag + strict birthYear YAML + G1 Maestro run) → bundle Julien's 91 W3 + 92 G2 into ONE review session | Every day 91 W3 stays open delays critical path 94→95→96; +54% per-turn cost vs Haiku narrator until Wave 3 lands |

## Drawer rename root cause (Mobile architect, deepest analysis)

NOT a string rename. Two-part bug:

1. `apps/mobile/lib/app.dart:454` defines `/explore` as a bare `GoRoute` (not `ScopedGoRoute(scope: RouteScope.public)`). The redirect logic at line 279 reads: `final scope = topRoute is ScopedGoRoute ? topRoute.scope : RouteScope.authenticated`. Bare `GoRoute` defaults to `RouteScope.authenticated`. **An anon cold-launch deep-linked to `/explore` redirects to `/auth/register`, never lands on `MintShell`.** "Explorer" tab label only appears INSIDE the shell.

2. Two perfect-set flows fall back to `point: "95%, 8%"` pixel coordinate to open the drawer (`flow_drawer_navigation_smoke.yaml`, `flow_empty_state_cascade.yaml`) because `Semantics(label: 'open-profile-drawer', button: true)` was deferred on the AppBar `IconButton` at `apps/mobile/lib/screens/explore/explorer_screen.dart:24`. Pixel locators are a known fragility wound.

**Fix path** (architect's surgical recommendation, 2 files):
- `apps/mobile/lib/app.dart:454` — change `/explore` from bare `GoRoute` to `ScopedGoRoute(scope: RouteScope.public)`. Anon Explorer access is documented product intent (`app.dart:242`).
- `apps/mobile/lib/screens/explore/explorer_screen.dart:24` — wrap profile `IconButton` in `Semantics(label: 'ouvrir-profil-drawer', button: true, child: ...)`.
- `tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml` + `flow_empty_state_cascade.yaml` — replace `point: "95%, 8%"` with `tapOn: text: "ouvrir-profil-drawer"`.

This single 4-file change (2 product, 2 flow) unblocks the drawer smoke flow, removes pixel fallbacks in 2 flows, and fixes a real product bug (anonymous users currently can't reach Explorer when deep-linked).

## Counter-arguments and data gaps

- **Counter (PM)**: opportunity cost of paroxysm campaign vs Phase 91 Wave 3 closure. Strong. PM acknowledges Maestro's strategic role peaks at Phase 96 (Chat-as-Verb cards), not now. Iteration-driven Maestro (one flow per PR as G1 gate, mandatory) replicates "paroxysm" outcome at zero opportunity cost over the next 5 PRs.
- **Counter (QA SME)**: backend has 6,142 tests vs financial_core has 1 test file. Test pyramid is inverted — bottleneck is unit:financial_core ratio, not Maestro coverage. "A regression in financial_core silently breaks every projection on every screen."
- **Data gap**: Julien's intent on "paroxysm" — is it (A) maximum theoretical coverage now, or (B) Maestro becomes mandatory for next 5 PRs and library grows organically? PM strongly recommends (B). All panelists implicitly support (B).
- **Data gap**: cost of macOS GitHub Actions runner. QA SME flagged "macOS runners are 10x ubuntu cost." For solo-dev pre-launch budget, this is real. Need usage estimate before wiring perfect-set as PR gate.
- **Data gap**: Julien's CONTEXT.md for `/explore` route — is bare `GoRoute` an oversight or intentional? Mobile architect believes it's an oversight (anon Explorer access is documented product intent). Worth confirming before changing.

## Decided execution plan (orchestrator synthesis)

**Tier 1 — Drawer surgical fix (1-1.5h, ALL panelists agree)**

1. Pre-flight: run `flow_drawer_navigation_smoke.yaml` with `--debug-output /tmp/drawer-debug` to capture the actual view hierarchy XML at the failure point. Confirm the architect's hypothesis that the shell isn't reached, not that "Explorer" is renamed.
2. Fix `app.dart:454` `/explore` route to `ScopedGoRoute(scope: RouteScope.public)`.
3. Wrap profile `IconButton` in `explorer_screen.dart:24` with `Semantics(label: 'ouvrir-profil-drawer', button: true)`.
4. Update `flow_drawer_navigation_smoke.yaml` + `flow_empty_state_cascade.yaml`: replace `point: "95%, 8%"` with `tapOn: text: "ouvrir-profil-drawer"` (or `id:` if Maestro reads Semantics labels via id).
5. Run full perfect-set baseline (`bash tools/simulator/maestro_perfect_set.sh --skip-build --flow-set default --continue-on-fail`). Capture PASS/FAIL matrix as evidence.
6. Commit as 2 commits: `fix(91-92): /explore route public scope + Semantics label on drawer button` (product) + `test(maestro): replace pixel fallbacks with semantic locators` (flows). Or 1 atomic if cleaner.

**Tier 2 — DEFERRED to next session, with explicit ranking:**

- **#1 (highest strategic value)**: Phase 91 Wave 3 autonomous parts (PM's recommendation). Unblocks critical path 94→95→96. Bundle Julien's 91 W3 + 92 G2 review.
- **#2 (highest trust value)**: financial_core unit tests (QA SME's recommendation). 10-15 tests for AVS/LPP/3a calculators. 2h.
- **#3 (highest leverage-compounding)**: CI Maestro wiring (Maestro/CI specialist). One job in `ci.yml` running perfect-set on PR. Makes Maestro mandatory by contract.
- **#4 (highest coverage)**: 5 missing P0 flows (mobile architect). Mortgage affordability + LSFin chat guard + frontalier + independant_no_lpp + anon PII.

This ordering follows Julien's stated TestFlight launch trajectory: unblock 91 W3 (critical path) → trust foundation → leverage multiplication → coverage expansion.

## Notes for future panel iterations

- Maestro CLI on macOS Tahoe **runs successfully via the `maestro_env.sh` wrapper** (Java 25 from openjdk Homebrew, JANSI deprecation warnings noise-only). No symlink/sudo needed.
- `assertScreenshot:` + `cropOn:` is Maestro 2.2.0+ native visual regression. Architecturally cleaner than the standalone `image_diff.py` path. Adopt at Tier 2.
- `assertWithAI:` requires Maestro Cloud free login (`maestro login` + `MAESTRO_CLOUD_API_KEY` secret). Useful for LSFin runtime banned-term assertion against dynamic LLM coach output.
- 3/18 life events covered today. Major archetypes missing: expat_eu, cross_border, independent_no_lpp, recent_arrival, near_retirement, young_starter (6/8 archetype gap).
- ARB locale coverage: only FR tested in Maestro. de/en/es/it/pt all uncovered.
