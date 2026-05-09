---
phase: 91-mvp-extractor-v2
verified: 2026-05-09T00:00:00Z
status: gaps_found
score: 5/7 requirements verified (EXTR-01 through EXTR-05 pass; EXTR-06 passes under mock; EXTR-07 partial)
re_verification: null
gaps:
  - truth: "Maestro G1 flow flow_extractor_captures_age_canton.yaml PASSES strict 3-fact assertion (EXTR-07)"
    status: partial
    reason: >
      The Maestro YAML exists (Wave 0 stub) and asserts canton + incomeGrossYearly strictly, but
      birthYear=1990 is still marked `optional: true` (YAML line 119). Wave 3 Task 3.4 would remove
      that optional flag and execute the flow on a booted sim with COACH_DUAL_LLM_ENABLED=True.
      Wave 3 has no SUMMARY — it was not executed. The EXTR-07 requirement per ROADMAP explicitly
      requires the flow to PASS on booted sim; this is unmet.
    artifacts:
      - path: "tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml"
        issue: "birthYear assertion is optional: true (line 119); strict 3-fact mode not yet activated"
    missing:
      - "Remove `optional: true` from birthYear assertion (Wave 3 Task 3.4)"
      - "Run flow on booted sim with COACH_DUAL_LLM_ENABLED=True and capture exit-0 output"
  - truth: "Stage 3 narrator eval gate: 50-fixture eval pack + harness exist, Julien on-brand decision recorded, COACH_NARRATOR_MODEL flag wired (EXTR-06 + D-01 + D-06)"
    status: failed
    reason: >
      Wave 3 was explicitly deferred (autonomous: false, two blocking human checkpoints).
      eval_narrator.py, narrator_eval_50.jsonl, and COACH_NARRATOR_MODEL config flag do not exist.
      The EXTR-06 cost regression test (Wave 2) passes under mock pricing — but the Stage 3 gate
      that decides whether Haiku (-2.5%) or Sonnet (+54%) is the narrator default has never run.
      Without the eval outcome, the narrator model is effectively hardcoded to Sonnet 4.5 at the
      Wave 2 flag-on branch (the model string in _run_extractor_stage), which is not the committed
      cost posture for production.
    artifacts:
      - path: "services/backend/tools/eval_narrator.py"
        issue: "MISSING — Wave 3 Task 3.1 not executed"
      - path: "services/backend/tests/fixtures/narrator_eval_50.jsonl"
        issue: "MISSING — Wave 3 Task 3.1 not executed"
      - path: "services/backend/app/core/config.py"
        issue: "COACH_NARRATOR_MODEL flag absent — Wave 3 Task 3.3 not executed"
    missing:
      - "50-fixture eval pack (narrator_eval_50.jsonl) across 4 categories per D-06"
      - "eval_narrator.py CLI harness running Haiku vs Sonnet and emitting pass-rate matrix"
      - "Stage 3 eval gate: Julien on-brand sign-off + ratio ≥95% Sonnet pass-rate decision"
      - "COACH_NARRATOR_MODEL flag in config.py wired to narrator model selection in coach_chat.py"
      - "G2 Julien device walkthrough on TestFlight or booted sim"

deferred: null

human_verification:
  - test: "G2 — Julien device walkthrough"
    expected: >
      Send « j'ai 80k de salaire à Lausanne, je suis né en 1990 » in anonymous chat
      with COACH_DUAL_LLM_ENABLED=True on staging. Narrator response is on-brand (no banned
      terms, no phantom save_fact/save_insight emissions). Profile drawer (if exposed)
      shows canton=VD, incomeGrossYearly=80000, birthYear=1990.
    why_human: >
      TestFlight / device walkthrough is human-only per CLAUDE.md §9.5 5-gate G2 contract.
      Claude cannot install TestFlight builds or perform live device interaction.
  - test: "Stage 3 eval — Julien on-brand sign-off on Haiku narrator responses"
    expected: >
      After eval_narrator.py is run for both Haiku and Sonnet on 50 fixtures, Julien reviews
      10 spot-checked fixtures and confirms « on-brand » verdict. Combined Haiku pass-rate
      ≥ 95% Sonnet pass-rate for ComplianceGuard + DoctrineChecks + banned-terms lint.
    why_human: >
      The on-brand judgment criterion in D-01 + D-06 is explicitly a human gate. Claude can
      run the automated checks but cannot substitute for Julien's on-brand judgment.
---

# Phase 91: MVP-EXTRACTOR-V2 Verification Report

**Phase Goal:** Split the single coach LLM into 2 distinct roles. Extractor (fatter Sonnet, JSON-only, capture-focused) separated from narrator (thin Haiku/Sonnet, delivery-only, reduced tool list).
**Verified:** 2026-05-09
**Status:** gaps_found (Wave 3 deferred — needs Julien session)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | `llm_extractor.py` module exists with `run_llm_extractor()`, `source_quote` substring check, non-fatal degradation | VERIFIED | `services/backend/app/services/coach/llm_extractor.py` exists (288 LOC); 19 tests pass including `test_hallucinated_quote_dropped`, `test_prose_response_triggers_retry_then_empty` |
| 2 | `coach_chat.py` calls extractor SEQUENTIALLY before narrator; regex floor STAGE 1 + LLM STAGE 2, merged, persisted BEFORE `_run_agent_loop` | VERIFIED | `_run_extractor_stage` at coach_chat.py:1386-1450, invoked at L2895; sequential invariant grep returns 0; `test_sequential_invariant_no_asyncio_gather_extractor_narrator` PASS |
| 3 | Narrator `stripped_tools` does NOT contain `save_fact` or `save_insight` (EXTR-04) | VERIFIED | `get_narrator_llm_tools()` returns 26 tools; runtime assertion `'save_fact' not in names and 'save_insight' not in names` passes; `TestNarratorSurface::test_narrator_tools_no_save_fact` PASS |
| 4 | Narrator system prompt does NOT contain `EXTRACTION DE PROFIL` block or `TOUJOURS appeler save_insight` (EXTR-03) | VERIFIED | `build_narrator_system_prompt()` confirmed: `'EXTRACTION DE PROFIL' not in prompt` and `'TOUJOURS appeler save_insight' not in prompt`; `test_narrator_prompt_has_no_extraction_directives` PASS |
| 5 | `extractor_schema.py` Pydantic models with `_ALLOWED_FACT_KEYS` Literal mirroring `coach_chat._SAVE_FACT_ALLOWED_KEYS` (EXTR-02 JSON-only contract) | VERIFIED | `extractor_schema.py` exists (129 LOC); 12 schema tests pass; `test_canonical_keys_mirror_coach_chat` PASS |
| 6 | Regex floor + LLM augment merge: regex wins on conflict, LLM augments missing keys (EXTR-05) | VERIFIED | `_merge_extracted()` at coach_chat.py:1303-1314 with `_REGEX_TOPIC_TO_CANONICAL_KEYS` map; `test_merge_regex_wins_on_conflict` PASS; `test_merge_llm_augments_when_regex_misses` PASS |
| 7 | Per-turn cost regression ≤+30% post-mitigations (EXTR-06) | VERIFIED (mock) | `test_cost_dual_haiku_narrator_within_30pct` PASS — -2.5% with Haiku narrator; `test_cost_dual_sonnet_narrator_exceeds_30pct_marked_xfail` XFAIL — +54% Sonnet documented as kill-policy ceiling. NOTE: this is mock-priced; Stage 3 eval that decides which model runs has not executed. |
| 8 | Maestro G1 flow `flow_extractor_captures_age_canton.yaml` PASSES strict 3-fact assertion on booted sim (EXTR-07) | PARTIAL | YAML exists; canton + incomeGrossYearly strict; `birthYear=1990` still `optional: true` (YAML line 119); flow NOT run on booted sim with flag ON; Wave 3 Task 3.4 not executed. |

**Score:** 6.5/8 truths verified (6 fully verified, 1 mock-only, 1 partial)

---

## Wave 3 Deferred — Needs Julien Session

Wave 3 (`91-03-PLAN.md`) has `autonomous: false` with two blocking human checkpoints:
- **Task 3.2** — Stage 3 eval gate: Julien on-brand sign-off + Haiku vs Sonnet narrator decision (D-01 + D-06)
- **Task 3.5** — G2 device walkthrough on TestFlight

The following must-haves from Wave 3 are NOT yet met:

| Wave 3 Must-Have | Status | Required By |
|-----------------|--------|-------------|
| 50-fixture eval pack (`narrator_eval_50.jsonl`) across 4 categories | MISSING | EXTR-06, D-06 |
| Eval harness `tools/eval_narrator.py` (Haiku vs Sonnet pass-rate matrix) | MISSING | D-01, D-06 |
| Stage 3 eval gate decision + Julien on-brand sign-off | NOT RUN | D-01, D-06 |
| `COACH_NARRATOR_MODEL` flag in config.py + wired in coach_chat.py | MISSING | D-01, Wave 3 Task 3.3 |
| Maestro G1 strict 3-fact (optional flag removed) | PARTIAL | EXTR-07 |
| Maestro G1 PASS on booted sim with `COACH_DUAL_LLM_ENABLED=True` | NOT RUN | EXTR-07 |
| G2 Julien device walkthrough + sign-off | NOT RUN | CLAUDE.md §9.5 5-gate contract |

These are not silent failures — they are documented as the explicit scope of a dedicated Wave 3 session that Julien has chosen to defer.

---

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `services/backend/app/services/coach/extractor_schema.py` | VERIFIED | 129 LOC; ExtractedFact + ExtractorOutput; 37-key Literal; commit a1bf8c6d |
| `services/backend/app/services/coach/llm_extractor.py` | VERIFIED | 288 LOC; EXTRACTOR_SYSTEM_PROMPT + run_llm_extractor; commit 9655b06d |
| `services/backend/app/services/coach/coach_tools.py` (get_narrator_llm_tools) | VERIFIED | `get_narrator_llm_tools()` defined at L1235-1267; excludes save_fact + save_insight; commit b88e8d23 |
| `services/backend/app/services/coach/claude_coach_service.py` (build_narrator_system_prompt) | VERIFIED | `build_narrator_system_prompt()` defined; uses `_NARRATOR_BASE_SYSTEM_PROMPT`; commit b88e8d23 |
| `services/backend/app/api/v1/endpoints/coach_chat.py` (STAGE 2 wiring) | VERIFIED | `COACH_DUAL_LLM_ENABLED` gated; `run_llm_extractor` imported; `_run_extractor_stage` at L1386; commit b88e8d23 |
| `services/backend/app/core/config.py` (COACH_DUAL_LLM_ENABLED) | VERIFIED | L70: `COACH_DUAL_LLM_ENABLED: bool = False`; commit 99da829d |
| `services/backend/tests/test_coach_chat_dual_llm.py` | VERIFIED | 537 LOC; 27 tests all PASS; commit b88e8d23 |
| `services/backend/tests/integration/test_dual_llm_cost.py` | VERIFIED | 4 passed + 1 xfailed; commit 5350d456 |
| `services/backend/tests/test_narrator_refuses_uncited_numbers.py` | VERIFIED | Phase 94 stub; skip-marked; commit 5350d456 |
| `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` | PARTIAL | YAML exists (Wave 0 stub); birthYear assertion optional; not yet strict; Wave 3 Task 3.4 not executed |
| `tests/fixtures/extractor_baseline_2026-05.md` | VERIFIED | Telemetry methodology documented; raw rate computation deferred to Julien (no Railway access) |
| `services/backend/tools/eval_narrator.py` | MISSING | Wave 3 Task 3.1 not executed |
| `services/backend/tests/fixtures/narrator_eval_50.jsonl` | MISSING | Wave 3 Task 3.1 not executed |
| `services/backend/app/core/config.py` (COACH_NARRATOR_MODEL) | MISSING | Wave 3 Task 3.3 not executed |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `coach_chat.py` Step 1.4 | `llm_extractor.run_llm_extractor` | `_run_extractor_stage` called at L2895 | WIRED | `grep -c "run_llm_extractor" coach_chat.py` = 2 |
| `coach_chat.py` persist path | `_persist_extracted_fact` | called inside `_run_extractor_stage` | WIRED | 4 references in coach_chat.py |
| `coach_chat.py` `_run_agent_loop` call site | `get_narrator_llm_tools() + build_narrator_system_prompt()` | flag-on branch at L3122-3158 | WIRED | 4 refs `get_narrator_llm_tools`, 2 refs `build_narrator_system_prompt` in coach_chat.py |
| anonymous chat path (no `_user`) | request-scoped `_extractor_in_memory_state` | `_extractor_in_memory_state_for_request()` factory | WIRED | 5 references; `test_flag_on_anonymous_runs_in_memory_no_db` PASS |
| `extractor_schema.ExtractedFact.key` | `coach_chat._SAVE_FACT_ALLOWED_KEYS` | `_ALLOWED_FACT_KEYS` Literal mirrors 37 keys | WIRED | `test_canonical_keys_mirror_coach_chat` PASS |
| `llm_extractor.run_llm_extractor` | `rag.llm_client.LLMClient.generate` | `LLMClient(provider, api_key, model)` in `_call_once` | WIRED | Module imports confirmed in llm_extractor.py |
| `tools/eval_narrator.py` | `tests/fixtures/narrator_eval_50.jsonl` | JSONL reader | NOT_WIRED | Wave 3 artifacts both missing |
| `flow_extractor_captures_age_canton.yaml` | `/api/v1/coach/chat` (strict 3-fact) | Maestro flow with `COACH_DUAL_LLM_ENABLED=True` | PARTIAL | YAML exists; birthYear optional; not run on sim |
| `coach_chat.py` narrator branch | `settings.COACH_NARRATOR_MODEL` | model selection in flag-on branch | NOT_WIRED | `COACH_NARRATOR_MODEL` missing from config.py |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| EXTR-01 | 91-02 | Extractor runs before narrator (sequential) | VERIFIED | `_run_extractor_stage` at L2895 executes before `_run_agent_loop` invocation; sequential invariant grep = 0; `test_sequential_invariant_no_asyncio_gather_extractor_narrator` PASS |
| EXTR-02 | 91-01 | JSON-only output | VERIFIED | `EXTRACTOR_SYSTEM_PROMPT` contains "JSON STRICT", "Pas de prose", "JSON UNIQUEMENT"; `test_extractor_system_prompt_is_french_and_json_only` PASS; Pydantic schema validates against raw JSON |
| EXTR-03 | 91-00, 91-02 | Narrator prompt has no extraction directives | VERIFIED | `build_narrator_system_prompt()` confirmed at runtime: `'EXTRACTION DE PROFIL' not in prompt` and `'TOUJOURS appeler save_insight' not in prompt`; 2 tests PASS |
| EXTR-04 | 91-02 | Narrator tool-set excludes save_fact/save_insight | VERIFIED | `get_narrator_llm_tools()` returns 26 tools; runtime assertion PASS; `_NARRATOR_EXCLUDED_TOOLS = {"save_fact", "save_insight"}` at coach_tools.py |
| EXTR-05 | 91-02 | Regex floor + LLM augment merge | VERIFIED | `_merge_extracted()` + `_REGEX_TOPIC_TO_CANONICAL_KEYS`; regex wins on conflict; LLM augments missing keys; 2 merge tests PASS |
| EXTR-06 | 91-02, 91-03 | Cost regression ≤+30% post-mitigations | VERIFIED (mock) / DEFERRED (eval gate) | Mock-cost test PASS (Haiku = -2.5%; xfail pins Sonnet = +54%); Stage 3 eval gate NOT RUN — narrator model default not yet decided; real production cost trajectory UNKNOWN |
| EXTR-07 | 91-00, 91-03 | Maestro flow `flow_extractor_captures_age_canton.yaml` PASS | PARTIAL | YAML exists; canton + incomeGrossYearly strict; birthYear `optional: true` (not strict); NOT run on booted sim with flag ON |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` | 119 | `optional: true` on birthYear assertion | Warning | Wave 3 Task 3.4 requirement not met; EXTR-07 strict assertion deferred |
| `services/backend/app/services/coach/claude_coach_service.py` | 281, 282, 440, 442, 799 | Pre-existing accent violations (`eclairage`, `deja`) | Info | Pre-existing; documented in Wave 0 + Wave 2 SUMMARYs as Karpathy #3 scope-boundary; no new violations introduced by Phase 91 changes |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `run_llm_extractor` not consumed by coach_chat in Wave 1 | `grep -rn "from app.services.coach.llm_extractor" app/ --include="*.py" \| grep -v tests/` | Returns `app/api/v1/endpoints/coach_chat.py` (Wave 2 wired correctly) | PASS |
| Sequential invariant: no `asyncio.gather` across extractor + narrator | `grep -E "asyncio\.gather.*run_llm_extractor\|asyncio\.gather.*_run_agent_loop" coach_chat.py` | 0 lines | PASS |
| EXTR-03 runtime check | `build_narrator_system_prompt()` contains no extraction directives | Both checks return OK; prompt length 30412 chars | PASS |
| EXTR-04 runtime check | `get_narrator_llm_tools()` returns 26 tools, none named save_fact/save_insight | PASS | PASS |
| EXTR-06 cost regression test | `pytest tests/integration/test_dual_llm_cost.py` | 4 passed, 1 xfailed | PASS |
| Full pytest suite | `pytest tests/ -q` | 6142 passed, 7 skipped, 1 xfailed in 107.5s | PASS |
| Maestro YAML strict assertion | `grep -cE "optional:\s*true" flow_extractor_captures_age_canton.yaml` | 1 (birthYear is optional) | FAIL (Wave 3 needed) |
| COACH_NARRATOR_MODEL in config | `grep "COACH_NARRATOR_MODEL" config.py` | Not found | FAIL (Wave 3 needed) |

---

## Human Verification Required

### 1. Stage 3 Narrator Eval — Julien On-Brand Sign-Off

**Test:** After Wave 3 Task 3.1 runs `eval_narrator.py --model haiku` and `--model sonnet` against all 50 fixtures, review the side-by-side pass-rate tables and spot-check at least 10 fixtures across the 4 categories.
**Expected:** Haiku combined pass-rate ≥ 95% Sonnet pass-rate on (a) ComplianceGuard, (b) DoctrineChecks, (c) banned-term lint, AND Julien judges Haiku responses « on-brand » per CLAUDE.md §1.
**Why human:** D-01 + D-06 explicitly mandate Julien on-brand judgment as a 4th criterion beyond automated checks. Cannot be substituted by automated guardrails alone.

### 2. G2 Device Walkthrough

**Test:** Install staging build via TestFlight (or run dev build on booted sim). Open anonymous chat, send « j'ai 80k de salaire à Lausanne, je suis né en 1990 ». Observe coach response and profile state.
**Expected:** (a) On-brand narrator response; (b) no phantom save_fact/save_insight emissions; (c) profile drawer shows canton=VD, incomeGrossYearly=80000, birthYear=1990; (d) latency ≤ 5s p50.
**Why human:** TestFlight install + device interaction is human-only per CLAUDE.md §9.5 5-gate G2 contract. Device simulator flow could theoretically be automated via Maestro (Wave 3 Task 3.4) but requires booted sim + staging flag ON — those conditions have not been prepared.

---

## Gaps Summary

Two gaps block the ROADMAP success criteria from being fully met:

**Gap 1 — EXTR-07 (Maestro G1 strict):** The Maestro flow YAML was created in Wave 0 as a regression baseline but left with `optional: true` on the birthYear assertion. Wave 3 Task 3.4 would remove this flag and run the flow on a booted sim against staging with the dual-LLM path enabled. This is the only user-visible "it works" gate per CLAUDE.md §9.2. Not executing Wave 3 means the feature is wired and unit-tested but never end-to-end verified on the actual system.

**Gap 2 — EXTR-06 / Stage 3 eval + COACH_NARRATOR_MODEL (Wave 3 Tasks 3.1–3.3):** The cost regression test passes under assumed mock pricing but the actual narrator model for production has not been decided. Without the Stage 3 eval, the narrator model defaults to whatever is hardcoded in the Wave 2 flag-on branch (Sonnet 4.5 at the time of wiring). The COACH_NARRATOR_MODEL config flag, the 50-fixture eval pack, and the eval harness are all absent. This leaves the "+54% vs -2.5% per turn" cost decision unmade — a material production concern.

**Root cause (both gaps):** Wave 3 requires Julien to be present (on-brand sign-off + G2 device walkthrough). The plan documents this correctly as `autonomous: false` with two `checkpoint:human-verify/action` tasks. Wave 3 was not scheduled in this session.

**Neither gap represents a coding defect** — Waves 0, 1, and 2 are fully verified. The dual-LLM split architecture is in place, tested, and correct. What is missing is the human-gated validation layer that authorizes promotion to staging.

---

_Verified: 2026-05-09_
_Verifier: Claude (gsd-verifier)_
