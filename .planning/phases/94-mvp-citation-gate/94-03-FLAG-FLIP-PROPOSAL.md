---
phase: 94
plan: 03
artifact: flag-flip-proposal
date: 2026-05-10
status: APPROVED — NO-GO + PARTIAL (Julien signed 2026-05-10 via AskUserQuestion in /gsd-execute-phase 94 Task 4 checkpoint)
flag: COACH_CITATION_GATE_ENABLED
description: Phase 94 Plan 03 Wave 2 decisional document — recommends flag disposition for COACH_CITATION_GATE_ENABLED based on the 7-gate compliance check measured against the Plan 03 eval-pack run + staging Railway provisioning.
---

# Phase 94 Flag-Flip Proposal — `COACH_CITATION_GATE_ENABLED`

**Date:** 2026-05-10
**Status:** APPROVED — NO-GO + PARTIAL (Julien signed 2026-05-10)
**Decision token:** `approved` — ratifies the recommended option below.
**Recorded by:** `/gsd-execute-phase 94` Task 4 checkpoint (AskUserQuestion, option « approved — NO-GO + PARTIAL (Recommended) »).
**Flag:** `COACH_CITATION_GATE_ENABLED`
**Current value:** prod = absent (default `False`) · staging = `true` (provisioned 2026-05-10T19:09:03Z by Plan 94-03 Task 2)
**Target value:** prod = `true` (post-flip), staging = `true` (unchanged)

## Recommendation summary

**NO-GO on prod flip ; keep staging-only ; open Wave 4 / Phase 96 ticket.**

The three measurable Stage 3 gates (G-A1 Sonnet ≥95% gate-correct, G-A2 Haiku ≥90% gate-correct, G-B latency ≤+30%) all fail by wide margins on the live 50-fixture pack. The root cause is well-understood and mechanical : the narrator's system prompt does not yet teach the `{{cite:<key>}}` placeholder syntax, so the gate (correctly per closed-world contract D-02..D-13) rejects naked numbers, the reprompt addendum D-09 does not produce placeholder-wrapped citations on retry, and fallback fires at 60-80% rate. Flipping prod today would degrade narrator quality materially (60% of user turns hitting the D-10 templated fallback « Je n'ai pas cette donnée pour l'instant »).

The gate logic itself is correct. The bottleneck is narrator prompt training.

## Eligibility checklist — per CONTEXT D-15 + D-19..D-21

| Gate | Threshold | Measured | Citation | Status |
|------|-----------|----------|----------|--------|
| G-A1 — Sonnet gate-correct | ≥95% | **6.0%** (3/50) | `94-03-EVAL-RESULTS.md` §Aggregate scores → row `sonnet gate=on` | **NOT MET** |
| G-A2 — Haiku gate-correct | ≥90% | **14.0%** (7/50) | `94-03-EVAL-RESULTS.md` §Aggregate scores → row `haiku gate=on` | **NOT MET** |
| G-B — Latency regression ≤+30% | ≤+30% | **+56%** (Sonnet on vs off with retries) | `94-03-EVAL-RESULTS.md` §Cost regression | **NOT MET** |
| G-C — Cost regression ≤+30% | ≤+30% | prompt-token delta 0% (single-call) ; completion-token cost not surfaced by LLMClient — Wave 4 measurement gap | `94-03-EVAL-RESULTS.md` §Threshold verification G-C | **UNMEASURED** |
| G-D — Maestro G1 PASS | flow exit 0 | exit 0 (16-17s wall-clock) | `/tmp/maestro_94_g1_smoke.xml` testcase status=SUCCESS | **PASS (smoke)** with scope caveat |
| G-D-scope — Gate wired on anonymous path | yes | no | `deferred-items.md` D1 | **DEFERRED** to Wave 4 / Phase 96 |
| G-E — Full backend pytest suite | ≥6296 | 6436 passed (Wave 1 baseline, unchanged) | `pytest tests/ -q --ignore=tests/integration` on commit `f00fb693` | **MET** |

Three of seven gates are NOT MET ; one DEFERRED ; one UNMEASURED ; two MET. The two MET gates (G-D smoke + G-E suite) are necessary but not sufficient for a prod flip.

## Findings that inform the recommendation

1. **Gate fires fallback on 60-80% of fixtures (across both Sonnet and Haiku).** This is not a logic bug — it is the closed-world contract working as specified : the narrator emits naked digits, the gate detects them as uncited, and the retry-once flow collapses to fallback (D-08 + D-10) when the retry also emits naked digits.
2. **Narrator system prompt does not teach `{{cite:<key>}}` placeholder syntax.** Today's `build_narrator_system_prompt` (legacy) and `build_narrator_system_prompt_from_bundles` (bundle compiler) both compose the FR system prompt without listing the citation-key registry. The reprompt addendum D-09 (« RAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. ») asks the narrator to use a syntax it has never seen — predictable failure.
3. **Latency regression is mechanical.** Sonnet single-call latency dropped to 7.7s (gate=on without retries) vs 9.4s (gate=off, no gate logic). The +56% bump comes from the retry-once path doubling wall-clock for the 80% of fixtures that retry. If retry rate drops to ≤10% (D-21 target), latency regression drops below +5% (back-of-envelope : 0.1 × 7.7 × 2 + 0.9 × 7.7 = 8.5s = +9% vs 7.7s baseline). The gate is performant per se ; the retry path is the cost driver.
4. **Anonymous chat endpoint has NO gate wrapper today** (deferred-items.md D1). This means the Maestro G1 flow as currently authored cannot verify the closed-world contract end-to-end on the anonymous surface. The 50-fixture eval pack IS the deterministic verification because the harness calls `citation_parser.gate()` directly on the narrator response (not via the API endpoint). Wiring the gate on `anonymous_chat.py` is a Wave 4 / Phase 96 scope decision.
5. **The gate logic is correct.** All 170 unit tests in `tests/test_citation_gate/` pass ; the byte-identity invariant on the flag-OFF path holds (6 snapshot tests). The flag-OFF prod path is byte-identical to pre-Phase-94 narrator behavior (D-20).

## Recommendation : **NO-GO on prod flip ; PARTIAL staging-only ; Wave 4 narrator prompt training**

| Option | Action | Rationale |
|--------|--------|-----------|
| **NO-GO + PARTIAL (recommended)** | Keep `COACH_CITATION_GATE_ENABLED=true` on staging only. Prod stays at default `False`. Open Wave 4 ticket to (a) fatten narrator system prompt with `{{cite:<key>}}` placeholder instructions + the active citation registry keys (intersected with bundle citation_allowlist when bundle compiler is ON), (b) re-run the 50-fixture eval, (c) if Sonnet ≥95% / Haiku ≥90% then re-open this proposal as a GO recommendation. | The gate is logically correct ; the narrator does not yet know the citation syntax. Flipping prod with the current narrator prompt would degrade UX (60-80% fallback rate). The risk reward is materially negative until Wave 4 fattens the narrator prompt. |
| GO | Flip prod `COACH_CITATION_GATE_ENABLED=true`. Provision Sentry alerts (see §Sentry alerts). | This is NOT justifiable on the current data : three of seven gates fail by 10x+ margins. GO would be a deliberate quality regression in service of compliance theater. |
| Pure NO-GO | Set staging `COACH_CITATION_GATE_ENABLED=false` and abandon Phase 94. | Overcorrects. The eval-pack data IS the input Wave 4 needs to fix the narrator prompt. Keeping staging ON costs ~50 API turns/day in degraded UX visible to nobody except us, vs the diagnostic value of continued staging observation. |

## Decision (Julien)

- [x] **NO-GO + PARTIAL** — keep staging ON, open Wave 4 (narrator prompt placeholder syntax + re-eval), re-evaluate post-Wave 4. **CONFIRMED by Julien 2026-05-10 — token `approved` recorded via `/gsd-execute-phase 94` Task 4 checkpoint.**
- [ ] **GO** — flip prod to true, monitor 48h, auto-revert on alert (despite G-A1/G-A2/G-B unmet)
- [ ] **Pure NO-GO** — keep prod absent AND roll back staging to false (counter-recommendation)
- [ ] Other (specify) :

### What NO-GO + PARTIAL triggers operationally

1. **No code change** required for the decision itself — staging already runs with `COACH_CITATION_GATE_ENABLED=true` (Plan 03 Task 2 commit `f00fb693`), prod has the variable absent (default `False` per `app/core/config.py:91`). The flag-OFF byte-identity invariant (Wave 0 Plan 94-01 Task 3 `test_byte_identity_flag_off`) holds on prod.
2. **Wave 4 opens** — `feature/S94-w4-narrator-citation-prompt-fattening` branch :
   - extend `services/backend/app/services/coach/claude_coach_service.py:build_narrator_system_prompt` (legacy) AND `build_narrator_system_prompt_from_bundles` (bundle path) with a citation registry fragment :
     - List every active `CITATION_REGISTRY` key with its FR description.
     - Instruct the narrator : « POUR CHAQUE chiffre, ajoute `{{cite:<key>}}` directement après le nombre. La liste des clés autorisées est ci-dessus. Si tu n'as pas de clé pour un chiffre, écris « je n'ai pas cette donnée » à la place. »
   - re-run the 50-fixture eval on both Sonnet + Haiku.
   - re-fill G-A1 / G-A2 / G-B in `94-03-EVAL-RESULTS.md` with post-Wave-4 numbers.
   - if both Stage 3 thresholds met, re-open this proposal as GO recommendation ; if not, iterate.
3. **48h Sentry pull** at T+48h (≈ 2026-05-12T19:09Z) — captures the `coach.citation_gate.*` breadcrumbs from the auth-coach traffic on staging during the soak window. Adds the soak section to `94-03-EVAL-RESULTS.md`.
4. **D-21 sunset clause** remains intact — flag + bypass code path removed in Phase 96 OR after 4 weeks of staging soak with fallback rate ≤2%. Today's fallback rate is 60-80%, far from the sunset threshold ; Wave 4 narrator-prompt fattening is the dependency.

## Post-94.1 measurement (added 2026-05-10)

Phase 94.1 Wave 4 (narrator-prompt fattening) landed on the same `feature/S94-mvp-citation-gate` branch. The citation-grammar fragment was added as a flag-conditional appendix to both narrator paths (legacy `build_narrator_system_prompt` + bundle compiler `compile_bundles`). Re-eval on the unchanged 50-fixture pack gives :

| Gate | Threshold | Pre-94.1 measurement | **Post-94.1 measurement** | Status |
|------|-----------|----------------------|---------------------------|--------|
| G-A1 — Sonnet gate-correct | ≥95% | 6.0% (3/50) | **20.0% (10/50)** | **NOT MET** (gap 75 points ; was 89) |
| G-A2 — Haiku gate-correct | ≥90% | 14.0% (7/50) | **20.0% (10/50)** | **NOT MET** (gap 70 points ; was 76) |
| G-B — Latency regression ≤+30% | ≤+30% | +56% | **+39%** | **NOT MET** (gap 9 points ; was 26) |

All three Stage 3 gates moved in the right direction but remain NOT MET. Details + per-category × verdict matrix in `../94.1-wave-4-narrator-prompt-fattening-citation-registry-cite-key-/94.1-EVAL-DELTA.md`. The signal is concentrated in the `valid_citation` category : Sonnet 1/20 → 9/20 (+800%), Haiku 6/20 → 10/20 (+67%) — the narrator does learn the syntax for ~50% of in-vocabulary fixtures, but `uncited_number` and `banned_claim` categories score 0/10 due to a SCORING CONTRACT issue (the fixture expects first-call verdict but the JSON records post-retry collapse per D-08, NOT a gate bug). Under alternative « first-call verdict matches expected » scoring, Sonnet would land around 48% and Haiku around 44%.

**Disposition unchanged : NO-GO + PARTIAL.** The thresholds still fail decisively (20% vs 95%). Staging stays ON for diagnostic value, prod stays OFF for narrator quality. Orchestrator decides GO/NO-GO on a Phase 94.2 second-iter (candidate hypothesis : intent-driven key grouping reduces the 18-bullet noise floor — full hypothesis list in `94.1-EVAL-DELTA.md` §"Root cause hypotheses for 94.2").

**No new GO recommendation.** A future 94.2 iter that lifts Sonnet ≥95% AND Haiku ≥90% AND latency ≤+30% would re-open this proposal as a GO recommendation ; today's measurement does not.

## Rollback procedure (if GO is chosen and post-flip degradation)

1. `railway variables --service MINT --set "COACH_CITATION_GATE_ENABLED=false"` from the prod environment (no code revert needed — flag-OFF path is byte-identical to pre-Phase-94 baseline per Plan 94-01 Task 3 `test_flag_off_byte_identical_to_snapshot` on 5 captured fixtures).
2. Service redeploys (~90 s).
3. Verify : narrator p50 latency returns to baseline ; error rate drops to ≤ baseline ; Sentry `coach.citation_gate.fallback` breadcrumb stops firing.
4. Open `~/Desktop/MINT.nosync/.planning/incidents/2026-MM-DD-citation-gate-flag-rollback.md` postmortem.

The flag-OFF byte-identity invariant is the safety net : the legacy code path is the same bytes it was on Phase 93.5 close-out ; rolling back is one env var.

## Sentry alerts to provision before any prod flip

| Alert | Trigger | Action |
|-------|---------|--------|
| Alert 1 | `coach.citation_gate.verdict=fallback` rate > 10% over 30-min window | Page Julien — fallback fired more than expected post-Wave-4 narrator-prompt fix |
| Alert 2 | `coach.citation_gate.retries=1` rate > 20% over 30-min window | Page — retry rate not converging toward D-21 target ≤10% |
| Alert 3 | narrator p50 latency > baseline + 30% over 30-min window | Page — latency regression beyond G-B target |
| Alert 4 | `coach.citation_gate.uncited_numbers_count` p95 > 5 | Page — narrator emitting too many uncited numbers per response (prompt regression) |

## 4-week staging soak monitoring plan (D-21)

Watched Sentry breadcrumb categories on staging (where flag is now `true`) :

- `coach.citation_gate.verdict` — distribution across {pass, rejected_uncited, rejected_banned_claim, fallback}. Target post-Wave-4 : ≥90% PASS, ≤2% fallback.
- `coach.citation_gate.retries` — count of fixtures where retry-once fired. Target post-Wave-4 : ≤10% (D-21).
- `coach.citation_gate.uncited_numbers_count` — distribution. Target post-Wave-4 : p50 = 0, p95 ≤ 2.
- `coach.citation_gate.banned_claims_count` — distribution. Target post-Wave-4 : p50 = 0, p95 ≤ 1.

Threshold breach action : Wave 4 fattens bundle anti-promise doctrine and/or extends D-12 banned-claim regex (per RESEARCH §Pitfall 6 — do NOT lift retry cap).

## D-21 sunset path

Flag + bypass code path removed in Phase 96 OR after 4-week staging soak with `coach.citation_gate.fallback` rate ≤2%. Today's measurement (Sonnet on staging, no real users yet, 50-fixture synthetic pack) is 80%. The path to ≤2% : Wave 4 narrator-prompt fattening → re-eval → if Sonnet ≥95% gate-correct, prod flip + 4-week real-traffic soak → sunset.

## 0-Trust separation per CLAUDE.md §9.4

| Layer | Content |
|-------|---------|
| WORK DONE | (1) `--gate` flag landed in eval_narrator.py + 50-fixture pack authored (commit `937e3bba`). (2) Maestro G1 smoke flow authored + 2 PASS runs on staging (commit `f00fb693`). (3) Staging Railway flag `COACH_CITATION_GATE_ENABLED=true` provisioned 2026-05-10T19:09Z (verified by `railway variables --service MINT` row). (4) 3 live eval runs landed (104 LLM API calls on Anthropic Sonnet + Haiku ; eval JSONs cited above). (5) This proposal + EVAL-RESULTS + SUMMARY authored. |
| USER VALUE DELIVERED ON STAGING | None YET. Staging flag is on but no real-user traffic is enforced through it ; the 50-fixture synthetic pack is the only traffic measured. The gate logic IS active on staging requests, but no human user is verifying staging behavior yet (G2 device-by-Julien is the next gate). |
| USER VALUE DELIVERED IN PROD | None. Prod flag is at default `False` (absent on Railway prod). The narrator on prod is byte-identical to pre-Phase-94. Phase 94 has delivered ZERO user value in prod ; that lands when Wave 4 fixes the narrator prompt + the 50-fixture eval clears Stage 3 + prod flip happens + 4-week prod soak confirms ≤2% fallback rate. |

## What this proposal does NOT claim (per CLAUDE.md §9 0-trust)

- Does NOT claim the gate is « ready » for prod. The G-A1 / G-A2 / G-B gates do not meet threshold ; the data is clear.
- Does NOT claim the gate « works » end-to-end on a real coach conversation. The 50-fixture pack is a synthetic harness ; first real-traffic measurement requires the 48h staging soak to complete with users (Julien sim walkthrough is the first user).
- Does NOT claim the closed-world contract is « validated » in prod. It is mathematically defined per CONTEXT D-02..D-13 and unit-tested in `tests/test_citation_gate/` (170 tests green), but end-to-end real-traffic validation requires Wave 4 narrator-prompt fattening first.
- Does NOT claim the flag flip is « shipped ». Per the 0-trust protocol, the flag is provisioned on staging (one citation : `railway variables --service MINT` row), and the eval data is in `94-03-EVAL-RESULTS.md` (citations : three JSON files + three stdout summaries on disk). Everything beyond that is pending Wave 4 + wall-clock soak.

## Sunset note (forward-looking)

Per CONTEXT D-21, Phase 96 OR a future Wave will :
- Delete `settings.COACH_CITATION_GATE_ENABLED` once 4-week prod soak shows ≤2% fallback rate.
- Delete the bypass code path in `coach_chat.py:_run_narrator_with_gate` (the flag-OFF branch — `if not settings.COACH_CITATION_GATE_ENABLED: return loop_result`).
- Wire the gate on `anonymous_chat.py` (D1 deferred item) AND any other narrator surface that emerges.
- Phase 95 (DAG-INVALIDATION) populates `GatedResponse.inputs_hash` from upstream projection hashes ; gate currently scopes to single response.
- Phase 96 (CHAT-AS-VERB) propagates `citation_allowlist` across turns ; gate currently scopes to single turn.

---

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
