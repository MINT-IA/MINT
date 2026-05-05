# MINT — Fondation

## What This Is

MINT is a Swiss financial lucidity & education app (Flutter + FastAPI) that gives users financial peace-of-mind, clarity, and control with near-zero effort. MINT is a living dossier that collects, understands, and reveals what matters about the user's financial life. Infrastructure plumbing is fixed (v2.4). This milestone transforms MINT from working infrastructure into a product that hooks, converts, and retains users through the anonymous→value→premium flow and the 5 expert audit innovations.

## Core Value

**Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.**

## Current Milestone: v2.12 Production-Ready Sim Validation (in flight)

**Goal :** Aucun TestFlight tant que Claude n'a pas validé que l'app tourne PARFAITEMENT sur simulator — 4 archetypes × 3 langues × 7 quality gates. Le walker est la machine de vérité ; Julien ne fait aucun test. Le STAMP-08 (`.planning/phases/89-stamp/STAMP-PASS-<date>.html`) est la seule autorisation de tag v2.12.0.

**Doctrine v2.12 :** No-Ship-Without-Perfect-Sim. Pas de wishful thinking. 4 phases sequential, 32 REQs panel-locked.

**4 phases (86-89) :**
- **Phase 86 — Walker green réel 4 archetypes (FR)** — **STATUS 2026-05-05 : julien_swiss GREEN (commit 8d3c127a, 6/6 captures, 82s, exit 0). 3 archetypes restants.**
- **Phase 87 — Bare-catches sweep Wave 1 (15 paths critiques)** — **STATUS : SHIPPED (PR #498).**
- **Phase 88 — Cross-language walker FR+DE+EN × 4 archetypes = 12 walks** — pending.
- **Phase 89 — Quality stamp + No-Ship-Until-Perfect gate (7-gate)** — pending.

## Next Milestone (planned, post v2.12 STAMP-PASS): v2.13 Persona Narrative Scenario Coverage

**Goal :** Bâtir la couche de validation narrative que v2.12 promet — un suite de scripts persona-driven exécutés nightly sur simulator, avec assertions sémantiques (Sentry breadcrumbs + LSFin regex + financial_core numeric) plutôt que pixel-SHA. Le KPI est **pass rate**, pas screenshot-distinct. Le ship gate TestFlight devient « 5 journalist-defense scripts green pour 5 nuits consécutives + walker green + flutter analyze clean + pytest -q clean ».

**Doctrine v2.13 :** Single-persona narrative walkthroughs produisent des findings ; multi-archetype scripted matrices produisent « gaps_found » et se font renommer (preuve empirique : Phase 51 + Phase 74). On cap initialement à **2 personas × 1 scenario × 5 phases = 10 cellules** ; on ne grandit qu'après 5 nuits nightly-green consécutives. Aucune exception.

**Architecture (panel-locked 6-pers, 2026-05-05) :**

- L0 = walker_premier_eclairage.sh (existing, KEPT) — owns flutter build dart-defines, sim boot, install, launch, Sentry pull, artifact bundle.
- L1 = Maestro YAML flows (`tools/simulator/flows/<persona>.yaml`) — in-app tap choreography via semantic locators, JAMAIS pixel coords.
- L2 = Dart post-run assertion suite (`tools/simulator/assertions/<persona>.dart`) — semantic events from `MintWalkthroughBreadcrumbs` + LSFin regex library + `financial_core/` numeric assertions + archetype assertion.
- LLM mocked via replay-cache (`tools/simulator/cache/replay/`). `MINT_LLM_CACHE=replay` mode reads from cache ; `record` populates ; live opt-in for weekly LLM regression.
- Goldens à R2 (`mint-goldens/`), pas git, pas LFS.
- `tools/checks/maestro_locator_audit.py` blocking lint pour drift de `tapOn:` literals.

**4 phases planned (90-93, post Phase 89 STAMP-PASS) :**

- **Phase 90 — 2 personas × 1 scenario × 5 phases = 10 cellules + tooling adoption** (4.0d) : Maestro CLI install + idb verify, walker.sh `--maestro-flow` shell-out, replay-cache schema + record/replay modes, R2 bucket + manifest, locator audit lint. julien_swiss + lauren_expat_us, scénario Premier Éclairage. 8 PERS-* REQs.
- **Phase 91 — 8 archetypes × canonical scenario each (8 scripts)** (3.0d) : per panel #2 « if this works, persona works » set. Numeric assertions wired to AvsCalculator/LppCalculator/TaxCalculator/ConfidenceScorer. LSFin regex library (panel #5) intégrée comme post-run lint. 8 ARCH-* REQs.
- **Phase 92 — 5 journalist-defense scripts (= TestFlight ship gate)** (2.0d) : Sofia (indép sans LPP) + Lauren (« c'est garanti combien ») + Anna (deuil 23h) + Jennifer (FATCA 3a) + Pierre (rente vs capital). Plus 5 dangerous-scenario regex gates avec mitigation post-gen. 8 JDEF-* REQs.
- **Phase 93 — Croissance vers 50 scripts par matrice swiss-financial** (4.0d) : 8 archetypes × 18 life events réduit à ~50 cellules priorisées (panel #5's matrix). Stop quand journalist-defensible (no new story changes safety profile). 8 GROW-* REQs.

**Quality gates v2.13 (Phase 92 ship-gate) :**
1. 5 journalist-defense scripts pass for 5 consecutive nights
2. Walker green 12 walks (carry-forward v2.12 STAMP-01)
3. `flutter analyze` clean + `pytest -q` green
4. LSFin regex library: 0 banned-term hits across all 13+ scripts
5. Per-script: ≥1 narrative invariant + ≥1 numeric assertion + ≥1 LSFin assertion + ≥1 archetype assertion
6. Suite-level flake budget : ≤3% per script, auto-retry once, quarantine after 3 consecutive flakes
7. Locator audit lint exits 0

**Hard scope guards (so v2.13 cannot become Phase 51) :**
1. NO new persona before all current are nightly-green for 5 nights.
2. NO life-events × archetypes matrix expansion before 10 cells stable.
3. ANY backend dependency MUST have a recorded-fixture mock. ANTHROPIC_API_KEY must NOT gate any script.
4. NO « walker overhaul » phase. Coord drift = locator-layer fix, point.
5. NO « delegated_via_substitute » markdown. Pass or fail, no third state.
6. Each phase has HARD STOP at scope cap. Phase 90 = 10 cells, period.

**Sources :**
- `.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md` (panel synthesis)
- `.planning/deep-audit-2026-04-17/02-persona-journeys.md` (10 personas audited prose, 7/10 BROKEN/PARTIAL — input)
- `.planning/walker/` (36 run dirs Phase 51 corpse)
- `.planning/wave-0-walkthrough-verite/PLAN.md` (lean version that worked)
- `.planning/MVP-FLOW-walkthrough-2026-04-21.md` (single-persona narrative that produced findings)

**Carry-forward de v2.12 :** Walker integrity (Phase 86), bare-catch ledger + lint (Phase 87), cross-language walker (Phase 88), 7-gate STAMP (Phase 89). v2.13 = la couche narrative au-dessus.

**Out of scope v2.13 (deferred to v2.14+) :**
- Wave 2 bare-catches (next 50)
- Couple mode wiring
- iPhone SE / iPad viewports
- Banking + LPP API integration (v3.0+)
- Wiki coach v3 (post-TestFlight)
- Patrol migration (Maestro YAML wins per panel #4)
- Live-LLM regression run nightly (weekly opt-in suffit)

## Previous Milestone: v2.8 L'Oracle & La Boucle (shipped 2026-04-25 with gaps)

5 phases shipped (30.5 Context Sanity Core + 30.6 Advanced + 30.7 Tools Déterministes + 31 Instrumenter + 32 Cartographier) + 13 decimal patches (30.8-30.20: LAND-01 fix, FIX-02 anonymous CTA, doc extraction uplift, error mapping, etc.). 4 phases unshipped (33/34/35/36) — carried forward to v2.9 or deferred. Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md).

## Requirements

### Validated

- ✓ AVS calculations (rente, couple, 13th, gaps, deferral) — golden tests pass, values verified
- ✓ Capital withdrawal tax (progressive brackets, married discount) — golden tests pass
- ✓ Constants sync (Flutter ↔ backend, 2025/2026 values) — verified
- ✓ Confidence scorer (11 components, Bayesian, 86 usages) — well wired
- ✓ Design system (MintColors, MintTextStyles, MintSpacing) — 0 hardcoded colors
- ✓ Compliance guard (5 layers, PII scrubbing, disclaimer injection) — functional
- ✓ CI pipeline (7 workflows, accessibility/readability gates) — healthy
- ✓ Token security (JWT in SecureStorage, BYOK in SecureStorage) — proper compartmentation
- ✓ MEMORY.md retention + dashboard agent-drift — v2.8 (CTX-01..02)
- ✓ CLAUDE.md restructure + UserPromptSubmit hook — v2.8 (CTX-03..05)
- ✓ MCP tools déterministes (get_swiss_constants / check_banned_terms / validate_arb_parity / check_accent_patterns) — v2.8 (TOOL-01..04)
- ✓ Sentry Replay Flutter 9.14.0 + global error boundary 3-prongs + trace_id round-trip — v2.8 (OBS-01..07)
- ✓ Route registry-as-code 150 routes + /admin/routes + parity lint — v2.8 (MAP-01..05)
- ✓ LPP CPE / HOTELA extractor 8→15/18 fields + 56 regression tests — v2.8 (decimal 30.18-30.20)
- ✓ Tax LIFD-citation false-positive fix + AVS IK table heuristic — v2.8 (decimal 30.19)
- ✓ Anonymous flow `/anonymous/intent` route wired + error mapping — v2.8 (decimal 30.14-30.15)
- ✓ Backend README first-run + ANTHROPIC_API_KEY documented — v2.8 (decimal 30.16)
- ✓ MVP wedge T9 email-demain killed + DESIGN.md spec — v2.8 (decimal 30.17)
- ✓ Walker green julien_swiss FR (Phase 86, commit 8d3c127a 2026-05-05) — proof point first scripted persona

### Active

See `.planning/REQUIREMENTS.md` for v2.13 requirements (PERS-* / ARCH-* / JDEF-* / GROW-*).

### Out of Scope (v2.13)

See « Out of scope v2.13 » block above.

## Context

### Codebase State (2026-05-05, entrée v2.13)
- Flutter: 0 compile errors, ~9327+ tests pass
- Backend: Railway staging + production live, ~5925 tests pass
- v2.11 wiring shipped (PRs #490-#496) ; v2.12 validation in flight (Phase 86 julien_swiss GREEN today)
- Phase 87 bare-catches Wave 1 SHIPPED (PR #498) — ledger 318 catches grandfathered, lint blocking
- 6-expert panel verdict landed 2026-05-05 (Persona Narrative Scenario Coverage)
- Walker_premier_eclairage.sh just achieved first GREEN run integrated stack (8d3c127a)
- Past attempt corpse documented: Phase 51 walker (36 run dirs in `.planning/walker/`), 8 archetype seeds, breadcrumb infra, debug overlay — all REUSED in v2.13 (panel rule #5 « burn or commit to reuse — no half-alive »).

## Constraints

- **Device gate**: persona walker green = the only device gate Julien needs. No human testing per memory feedback_device_gates.
- **No retirement framing**: MINT is NOT a retirement app. 18 life events.
- **Branch protocol**: feature/* → dev → staging → main. Never push to staging/main directly.
- **Compliance**: All coach output through ComplianceGuard. No banned terms. Educational only.
- **Sequential execution at the milestone level**, parallel agents WITHIN a phase via worktrees.
- **No new features in v2.13** — testing infra only. Bug-fixes-of-record from script failures DO ship — that's the whole point.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wire Flutter to /coach/chat endpoint | /coach/chat already has agent loop, tools, server-key fallback | ✓ Done v2.7+ |
| Sequential execution, no parallel plans | Parallel agents caused the 2026-04 mess | ✓ Worktree pattern v2.10+ |
| Device gate (flutter run on iPhone) | tests green ≠ app works | ✓ Replaced v2.13 by walker = machine of truth |
| **v2.8**: lefthook pre-commit local | Pre-commit local = feedback <5s | ✓ Done |
| **v2.8**: 0 feature nouvelle | Compression > création | ✓ Done |
| **v2.12**: Walker = machine de vérité, pas device walkthrough Julien | Memory feedback_device_gates : Claude does device walkthroughs autonomously via sim+idb | ✓ Done |
| **v2.13**: Persona scripts = Maestro YAML + walker shell + Dart assertions | Panel 6-pers 2026-05-05 ; Patrol rejected (CI flake reports), pure walker rejected (1800 LoC bash bomb), pure Maestro rejected (no SSIM, no dart-defines) | ✓ Decided 2026-05-05 |
| **v2.13**: Cap Phase 90 at 10 cells, grow only after 5-night nightly-green | Phase 51 postmortem (336 cells → gaps_found) | ✓ Decided 2026-05-05 |
| **v2.13**: LLM replay-cache mandatory, no live API gates suite | Phase 51 killed by missing ANTHROPIC_API_KEY | ✓ Decided 2026-05-05 |
| **v2.13**: 5 journalist-defense scripts = TestFlight ship gate, not 50 | Panel #3 + #5 convergence | ✓ Decided 2026-05-05 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-05-05 — v2.12 Phase 86 (julien_swiss GREEN) + Phase 87 (SHIPPED PR #498) ; v2.13 milestone declared, panel-locked (`.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`)*
