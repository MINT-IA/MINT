# Phase 54 target — synthesis of post-Phase-53 5-expert MINT panel

**Date:** 2026-05-04
**Status:** Proposed (panel synthesis after Plan 53-01/02/03 all merged)
**Decision authority:** Julien (panel synthesised by Claude in autonomous mode per `feedback_post_phase_panel_loop.md`)
**Origin:** post-Phase-53 — what ships next?

## Question

Phase 53 (53-01 ScreenRegistry parity + 53-02 SequenceChatHandler wiring + 53-03 Tab 1 commitments surface) all merged. What is the next-phase target?

## Panel composition (5 parallel experts, all returned)

| Expert | Verdict |
|---|---|
| Roadmap Sequencer | **CONFIRM**: Chat Vivant single-scene injection MVP (`MintSceneRachatLPP`) — Handoff 2 Mission #2 unblocked by Mission #1 closure |
| Engineering / Wiring Reviewer | **PIVOT**: « Intent Contract Unification » — Plan 53-01's 26 ROUTABLE entries are a **registry-only mirage**: backend `ROUTE_TO_SCREEN_INTENT_TAGS` (`coach_tools.py:108-133`) and mobile `validRoutes` (`tool_call_parser.dart:64-134`) weren't updated, so the LLM cannot suggest those intents and the mobile validator drops them. P0 contract gap |
| Adversarial Trust Reviewer | **HOT-FIX**: Phase 52.4 vault metaphor sweep — `authGateSalaryMessage` says « secure vault / coffre-fort sécurisé » in 6 locales, contradicting Path A. Phase 52.3 lint missed the « vault » class. Already shipped as PR #448 |
| Coach Intelligence Architect | **PIVOT**: intentTag → tappable chip wiring on every coach opener (proactive trigger, sequence prompt, precomputed insight) — 2-3 days, lights up 3 already-working coach intelligences with no new infra |
| Production Readiness / TestFlight | **TestFlight Gate Closure** — `AUDIT_TAP_RENDER.md` 100% TODO, never executed; per `STAB-carryover.md:38` « BLOCKING TestFlight ». All other infra blockers (PrivacyInfo, account-deletion, Sentry, testflight.yml CI) are CLOSED. Single missing artifact: the autonomous walker walk |

## Convergence analysis

**Three orthogonal P0 work-streams identified, ranked by dependency:**

1. **Phase 52.4 — vault hot-fix** (Adversarial). In flight as PR #448. Independent of the others. Trust regression at consent moment.

2. **Plan 53-04 — Intent Contract Unification** (Engineering). **Must-fix BEFORE Phase 53 close-out audit declares PASS.** Without it, my Plan 53-01 « 138 ScreenEntry routes parity OK » lint claim is misleading: 26 of the new entries are unreachable from chat because the LLM whitelist + mobile validator weren't updated in lockstep. This is the same « façade-sans-câblage » class banned by Julien's discipline.

3. **Phase 54 — TestFlight Gate Closure** (Production Readiness). The literal TestFlight blocker per 3 independent sources (`MILESTONES.md:109`, `STAB-carryover.md:38`, `PITFALLS.md:191`). Walker tooling exists (`tools/simulator/walker.sh` + `test_walker_archetype.sh` per PR #443). All other infra closed.

**Why not Expert 1's chat-vivant scenes:**
- Expert 2 + Expert 4 + Expert 5 all explicitly recommend deferring scene work
- Expert 2's contract gap: « building scenes on a broken substrate compounds debt »
- Expert 4's coach-intelligence gap: « building 2-3 weeks of scene infra delivers ONE new visible artifact; wiring intentTag chips is 2-3 days and immediately makes 3 already-working intelligences tappable for the first time. Higher leverage »
- Expert 5: TestFlight ships before pre-launch UX moats matter

**Why not Expert 4's intentTag chip wiring as Phase 54:**
- It overlaps with Phase 54 (chip wiring helps walker have something to tap), so it folds into the Phase 54 walker prep work
- Standalone it's lower-impact than the literal TestFlight blocker

## Decision (Proposed)

**Sequence:**

### Phase 52.4 — Vault metaphor sweep (NOW — in flight, PR #448)
6 ARB strings + lint expansion. Already shipped.

### Plan 53-04 — Intent Contract Three-Way Parity (next — 1-2 days)
**Must-fix BEFORE Phase 53 close-out audit declares PASS.**

Single source of truth across:
- `services/backend/app/services/coach/coach_tools.py:108-133` — `ROUTE_TO_SCREEN_INTENT_TAGS` (24 today)
- `apps/mobile/lib/services/coach/tool_call_parser.dart:64-134` — `validRoutes` (70 today)
- `apps/mobile/lib/services/navigation/screen_registry.dart` — `MintScreenRegistry` (138 today)

**Approach:** generate `ROUTE_TO_SCREEN_INTENT_TAGS` and `validRoutes` from `MintScreenRegistry` at build time (Python-side from a JSON export of the Dart registry, mobile-side via codegen). New CI gate `screen_registry_three_way_parity` fails if any of the three drift. Deliver `rente_vs_capital_arbitrage → /arbitrage/rente-vs-capital` end-to-end as the acceptance test.

**Estimated 1-2 days** (per Expert 2's 3-day estimate, simplified by codegen-from-Dart-source-of-truth pattern).

### Phase 53 close-out audit (after Plan 53-04 lands)
- Walker rerun against the now-actually-routable chat (Plan 53-01 acceptance evidence T-05)
- Re-spawn the post-Phase-52.2-style 4-expert close-out panel; load-bearing question: « can a real user complete one multi-screen life-event journey end-to-end starting from chat? » — must answer YES demonstrably
- Phase 53 HTML evidence updated with PASS verdict

### Phase 54 — TestFlight Gate Closure (1 week)
Per Expert 5's verdict. Three sub-plans:

| Sub-plan | Scope | Owner-lens |
|---|---|---|
| **54-01** | Autonomous walker walkthrough across all 56 rows of `AUDIT_TAP_RENDER.md` (3 tabs + drawer). Walker reads the row list, drives sim taps via cliclick + idb, captures screenshot per row, asserts non-blank render via breadcrumb + sha256 distinctness. Fills PASS/FAIL columns; FAILs file as blocking sub-issues | Expert 5 |
| **54-02** | intentTag → tappable chip wiring (Expert 4's pivot) on `_addCoachOpenerMessage` callers: `_maybeShowProactiveTrigger`, `_injectSequencePrompt` (post-Plan 53-02), and a 4th caller reading `PrecomputedInsightsService.getCachedInsight` on chat-open. Required for the walker to tap proactive coach openers in 54-01 | Expert 4 |
| **54-03** | Triage all FAILs from 54-01, ship fixes, walker re-runs to PASS, bump `pubspec.yaml` to `2.9.0+N`, push staging → testflight.yml triggers → Apple build processes | Expert 5 |

**Phase 55 candidates (deferred):**
- Chat Vivant scenes per Expert 1 (now provably reachable post-Plan 53-04 + Phase 54)
- Activate the 9 unactivated SequenceTemplates beyond `retirement_prep`
- E2EE / Path C migration (v3.0 backlog)

## What gets demoted

- The Phase 53 close-out audit cannot run before Plan 53-04 closes the contract gap. The « 138 ScreenEntry routes parity OK » claim is technically true (registry × app.dart) but masks the contract failure.
- Chat Vivant scenes (Expert 1's CONFIRM) demoted to Phase 55 by 3-vs-1 panel split (Experts 2/4/5 pivot).

## Sources used by the panel (web research)

(Same sources as the Phase 53 panel; no new external research needed.)

## Internal artifacts referenced

- `~/Downloads/handoff 2/00-README.md` + `02-chat-vivant-services.md` (scene contract — for Phase 55 reference)
- `services/backend/app/services/coach/coach_tools.py:108-133` (`ROUTE_TO_SCREEN_INTENT_TAGS` — Plan 53-04 target)
- `apps/mobile/lib/services/coach/tool_call_parser.dart:64-134` (`validRoutes` — Plan 53-04 target)
- `apps/mobile/lib/services/navigation/screen_registry.dart` (Plan 53-04 source of truth)
- `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` (Phase 54-01 target — 56 rows, 100% TODO)
- `docs/DEVICE_GATE_V27_CHECKLIST.md` (Phase 54-01 / 54-03 sign-off matrix)
- `tools/simulator/walker.sh` + `test_walker_archetype.sh` (Phase 54-01 tooling)
- `.github/workflows/testflight.yml` (Phase 54-03 deployment pipeline)

---

*Methodology: 5 parallel sub-agents with distinct domain mandates. Synthesis by Claude in autonomous mode per `feedback_post_phase_panel_loop.md`. Decision authority remains with Julien.*

*Memory: this decision encodes « contract before scenes, walker before launch » sequencing. If a future session contemplates jumping to chat-vivant scenes ahead of TestFlight, re-read Expert 2's contract-gap evidence + Expert 5's TestFlight-blocker citations first.*
