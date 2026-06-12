---
phase: mint-grounded-coach-m1
plan: 05
subsystem: coach-grounding
tags: [explain-concept, tool-choice, forced-tool, agent-loop, show-fact-card, concept-registry, claim-checker, grounding, lsfin, tdd]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-04-concept-registry-claim-checker
    provides: "CONCEPT_REGISTRY (18 curated closed-world Swiss concept pages) + claim_checker.check_claims() definitional-inversion detector — the registry this plan retrieves from and the checker this plan reuses to gate fact cards"
provides:
  - "explain_concept tool — backend-handled grounded definition retrieval (concept_key enum over CONCEPT_REGISTRY, returns canonical_fr + source as tool_result, no LLM paraphrase)"
  - "tool_choice threaded through the authenticated path (llm_client.generate → orchestrator.query → _call_with_fallback → _run_agent_loop), defaulting to auto"
  - "definition_request intent (interrogative + registry concept term) → forces explain_concept on the FIRST agent-loop call only; iterations 2..MAX revert to auto so the loop terminates with a text answer after the tool_result"
  - "_gate_fact_card_against_registry — show_fact_card content/source validated against the registry (inverted content blocked → fallback; off-registry source repaired to page source)"
  - "claim_checker.resolve_definiendum() — closed-world concept-from-text resolver (reuses the existing definiendum lexicon)"
  - "CONNAISSANCES SUISSES directive tightened — regulated concepts defined via explain_concept, never from memory"
affects: [mint-grounded-coach-m1-06-domain-corrections, mint-grounded-coach-m1-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Force-turn-1/answer-turn-2 generalised to the authenticated agent loop (mirrors anonymous_chat.py:204) — forced tool_choice on iteration 0 only, auto thereafter, with a loop-termination test"
    - "tool_choice threaded as an optional kwarg through the full RAG call chain (defaults to auto → byte-identical legacy behaviour)"
    - "Registry-gated mobile payload: a Flutter-bound card is validated against the closed-world registry BEFORE it crosses the trust boundary (claim_checker reused as the validator)"
    - "resolve_definiendum reuses the claim_checker definiendum lexicon (single source of truth — no duplicated concept-matching)"

key-files:
  created:
    - services/backend/tests/test_explain_concept_tool.py
    - services/backend/tests/test_coach_chat_intent_force.py
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/app/services/rag/llm_client.py
    - services/backend/app/services/rag/orchestrator.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/app/services/coach/claim_checker.py
    - services/backend/app/services/coach/claude_coach_service.py
    - docs/coach-tool-routing.md
    - services/backend/tests/fixtures/narrator_legacy_snapshots/*.txt (5 snapshots)

key-decisions:
  - "Forced tool_choice computed in _run_agent_loop (iteration==0 + definition_request intent + explain_concept advertised), threaded down through _call_with_fallback → orchestrator.query → llm_client.generate. Single decision point at the loop; every lower layer just passes the kwarg through (defaults to auto)."
  - "explain_concept registered as INTERNAL (fed back as tool_result like get_regulatory_constant) — never forwarded to Flutter. The mobile fact-card payload is the separate show_fact_card channel, which this plan gates."
  - "definition_request fires ONLY on interrogative + registry concept co-occurrence. Naming a concept (\"j'ai fait un rachat de 20000\") or asking a non-registry question (\"c'est quoi ton plat préféré\") does NOT force the tool — avoids regressing save_fact / route_to_screen flows."
  - "resolve_definiendum lives in claim_checker (reuses _DEFINIENDUM_LEXICON) rather than duplicating concept-matching in coach_chat — keeps the closed-world lexicon a single source of truth."

patterns-established:
  - "First-call-only forced retrieval with a deterministic loop-termination test (T-m1-05-03 mitigation — the plan-checker blocker)."
  - "Trust-boundary validation of an LLM-authored mobile payload via the deterministic claim-checker (block-or-repair), not an LLM judge (CLAUDE.md §9)."

requirements-completed: [WS-B]

# Metrics
duration: ~30min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 05: explain_concept Forced-Tool Summary

**A backend-handled `explain_concept` tool that returns the curated CONCEPT_REGISTRY page (canonical_fr + source, no LLM paraphrase), forced via `tool_choice` on definition intent on the AUTHENTICATED agent loop — FIRST call only, with iterations 2..MAX reverting to auto so the loop terminates with a text answer after the tool_result — plus a `show_fact_card` registry gate that blocks inverted-content cards and repairs off-registry sources. Full backend suite green (7808 passed).**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-06-12 (sequential session, main working tree, branch qa/runtime-navigation-spine-20260602)
- **Completed:** 2026-06-12
- **Tasks:** 4 (Tasks 1, 2+3 with commits; Task 4 snapshot-regen commit)
- **Files modified:** 14 (2 test files created, 7 production/doc modified, 5 prompt snapshots regenerated)

## Accomplishments

- **Forced grounded retrieval on definitions (WS-B, T-m1-05-01):** the authenticated path no longer lets the LLM define a regulated Swiss concept from its weights. When the user asks "c'est quoi un rachat / qu'est-ce que l'EPL / explique le splitting AVS", the turn's FIRST LLM call is forced to `tool_choice {"type":"tool","name":"explain_concept"}`; the backend resolves the concept against CONCEPT_REGISTRY (Plan 04) and feeds the curated definition + source back as the tool_result. This generalises the anonymous-surface pattern (anonymous_chat.py:204) to the authenticated agent loop.
- **First-call-only force + loop termination (T-m1-05-03, the plan-checker blocker):** the force applies to iteration 0 only. Iterations 2..MAX_AGENT_LOOP_ITERATIONS revert to `auto` — so after the explain_concept tool_result the model emits the final TEXT answer and the loop terminates ("force turn 1, answer turn 2"). The required termination test is green (see deterministic citation below).
- **show_fact_card registry gate (T-m1-05-02):** the LLM-authored card content/source channel (audit 04 §1.3 P1, flagged in Plan 04's threat-flags) is now closed. An inverted definition in a card is blocked (calm fallback text); an off-registry source for a known concept is repaired to the page source; cards about non-registry topics pass untouched.
- **Anonymous surface untouched:** no edit to `anonymous_chat.py`. The threading is additive and defaults to auto — chitchat and fact-declaration messages keep `tool_choice=auto` on every call (tested).
- **Full backend suite green:** 7808 passed, 116 skipped, 4 xfailed, 0 failed (up from Plan 04's 7784 = +24 new tests).

## Deterministic Citation — first-call-only force + loop termination

The plan-checker blocker (DoS / loop-never-answers) is pinned by `test_coach_chat_intent_force.py`:

```
cd services/backend && python3 -m pytest tests/test_coach_chat_intent_force.py -q
14 passed, 1 warning in 0.12s
```

The two load-bearing assertions (mock orchestrator, assert on `tool_choice` per `orchestrator.query` call):
- `test_definition_forces_explain_concept_on_first_call_only` — call[0] `tool_choice == {"type":"tool","name":"explain_concept"}`, call[1] `tool_choice is None` (auto), and `result["answer"]` contains the grounded text → loop TERMINATED after the tool_result.
- `test_loop_terminates_with_text_after_tool_result` — `result["answer"].strip() != ""` AND `orch.query.call_count == 2` (did NOT spin to MAX iterations).

Non-regression: `test_chitchat_stays_auto_on_all_calls` + `test_fact_declaration_stays_auto` assert `tool_choice is None` on every call for chitchat and a save_fact-routing fact declaration.

## Task Commits

1. **Task 1: explain_concept tool + registry-backed handler** — `08a6a03d8` (feat) — TDD: test (RED, collection error — `handle_explain_concept` absent) → implementation (GREEN, 10 passed). Tool added to COACH_TOOLS (closed-world concept_key enum = registry keys), registered INTERNAL, `handle_explain_concept()` returns canonical_fr + source / not-found shape, wired into `_execute_internal_tool`.
2. **Tasks 2+3: forced explain_concept on definition intent (first call only) + show_fact_card registry gate** — `cb3b5b837` (feat) — TDD: test (RED, missing `definition_request` / `_gate_fact_card_against_registry`) → implementation (GREEN, 14 passed). tool_choice threaded through 4 layers; `definition_request` intent; first-call-only force in `_run_agent_loop`; CONNAISSANCES directive tightened; `resolve_definiendum` + `_gate_fact_card_against_registry`; gate wired into the external_calls path; doc updated.
3. **Task 4: full backend suite — regenerate narrator prompt snapshots** — `268280484` (test) — the directive tightening adds exactly +1 line to the narrator prompt; regenerated the 5 byte-identity snapshots via the documented `_load.py` capture procedure (verified intended drift only: +1 line, 0 removals each). Full suite green.

_Tasks 2 and 3 were committed together — see Deviations._

## Files Created/Modified

- `services/backend/app/services/coach/coach_tools.py` (modified) — explain_concept tool definition (enum over `_CONCEPT_REGISTRY_KEYS`), added to `INTERNAL_TOOL_NAMES`, `handle_explain_concept()` handler.
- `services/backend/app/services/rag/llm_client.py` (modified) — `generate()` + `_call_claude()` accept an optional `tool_choice` kwarg; line ~227 hardcoded auto replaced by "caller override else auto".
- `services/backend/app/services/rag/orchestrator.py` (modified) — `query()` accepts + forwards `tool_choice` to `llm_client.generate`.
- `services/backend/app/api/v1/endpoints/coach_chat.py` (modified) — `_call_with_fallback` forwards `tool_choice`; `_classify_user_intent` emits `definition_request`; `_run_agent_loop` computes the first-call-only forced tool_choice; explain_concept dispatch branch; `_gate_fact_card_against_registry` + wiring into external_calls + fact-card fallback.
- `services/backend/app/services/coach/claim_checker.py` (modified) — `resolve_definiendum()` (reuses the definiendum lexicon) + `__all__`.
- `services/backend/app/services/coach/claude_coach_service.py` (modified) — CONNAISSANCES SUISSES directive: define regulated concepts via explain_concept, never from memory.
- `docs/coach-tool-routing.md` (modified) — explain_concept added to the documented `INTERNAL_TOOL_NAMES` + consequence matrix (map-freshness invariant kept in sync).
- `services/backend/tests/fixtures/narrator_legacy_snapshots/*.txt` (5 regenerated).
- `services/backend/tests/test_explain_concept_tool.py` + `tests/test_coach_chat_intent_force.py` (created).

## Decisions Made

- **Single force decision point at the loop.** The forced tool_choice is computed once in `_run_agent_loop` (iteration 0 + `definition_request` + explain_concept advertised). Every lower layer (`_call_with_fallback`, `orchestrator.query`, `llm_client.generate`, `_call_claude`) just threads the kwarg through, defaulting to auto. This keeps the "first call only" invariant in one readable place and makes the flag-OFF path byte-identical (only the hardcoded-auto branch at llm_client:227 changed, now "override else auto").
- **explain_concept is INTERNAL, not Flutter-bound.** It feeds the curated page back as a tool_result (like get_regulatory_constant) so the LLM grounds its prose on it. The mobile fact-card surface is the separate `show_fact_card` channel — that is what the Task 3 gate validates.
- **definition_request is intentionally narrow** (interrogative + registry concept term). Naming a concept without asking for its definition does not fire it — protecting the save_fact / route_to_screen flows.
- **resolve_definiendum reuses the claim_checker lexicon.** Rather than re-deriving concept-from-text matching in coach_chat, the gate calls a new `claim_checker.resolve_definiendum()` that reuses the existing `_DEFINIENDUM_LEXICON` — single source of truth.

## Deviations from Plan

### Process deviation (commit granularity)

**1. [Rule 3 - Blocking: clean-split would produce non-green commits] Tasks 2 and 3 committed together (`cb3b5b837`).**
- **Found during:** Task 3 wiring.
- **Issue:** Task 2 (forced tool_choice) and Task 3 (fact-card gate) both edit the same `_run_agent_loop` pass in `coach_chat.py` and share a single test file (`test_coach_chat_intent_force.py`). The Task-2 loop edits reference `_gate_fact_card_against_registry` (Task 3), so splitting into two commits via line-level staging would leave an intermediate commit whose module is non-importable / whose test file is partially red — violating the "each task commit is green" requirement. Interactive `git add -p` is unavailable in this environment.
- **Fix:** Committed Tasks 2+3 as one cohesive "intent-force + registry-gated fact card" unit (the two halves of the same prevention mechanism — forced retrieval + gated card — wired into the same loop pass). Both task verifications are green (14/14 in the shared test file). The commit message documents the Task 2 / Task 3 split explicitly.
- **Impact:** No scope change. All three plan tasks delivered; the only difference from the default is one commit covering two tasks.

### Auto-fixed Issues

**2. [Rule 3 - Blocking] Regenerated 5 narrator prompt byte-identity snapshots.**
- **Found during:** Task 4 (full backend suite).
- **Issue:** 11 byte-identity snapshot tests (`test_byte_identity_flag_off.py`, `test_coach_chat_bundles.py`) pin the exact narrator system-prompt bytes. The Task 2 CONNAISSANCES directive tightening (intended prompt change) added one line, making the snapshots stale.
- **Fix:** Verified the drift was exactly +1 line / 0 removals on all 5 fixtures (the explain_concept directive), then regenerated the snapshots via the documented `_load.py` capture procedure. These tests exist to catch UNINTENDED drift; this drift is intended and required by the plan.
- **Verification:** `test_citation_gate/test_byte_identity_flag_off.py` + `test_coach_chat_bundles.py` → 23 passed; full suite → 7808 passed, 0 failed.
- **Committed in:** `268280484` (Task 4 commit).

---

**Total deviations:** 1 process (commit granularity, Rule 3) + 1 auto-fix (snapshot regen, Rule 3). **Impact on plan:** No scope creep. The snapshot regen is the exact "update only the tests encoding the old behaviour, justify in SUMMARY" case the plan's Task 4 anticipated.

## Banned-term check (Task 4)

`tools/checks/banned_terms_python.py` was run on the edited files. The added CONNAISSANCES directive line (claude_coach_service.py:741) is NOT flagged — it carries no banned LSFin term and correct FR accents. All flagged lines in the output are PRE-EXISTING (the prompt's own banned-term lexicon documentation, error-message templates, the neutral "recommandé/recommended_by" provenance strings) — none introduced by this plan. The pre-commit lefthook (which includes the banned-terms gates) passed on every commit.

## Threat Model Coverage

- **T-m1-05-01** (Information disclosure / tool_choice=auto on definitions, `mitigate`): mitigated — definition intent forces explain_concept on the authenticated surface (first call). `test_definition_forces_explain_concept_on_first_call_only`.
- **T-m1-05-02** (Spoofing / show_fact_card fabricated source, `mitigate`): mitigated — `_gate_fact_card_against_registry` blocks inverted content and repairs off-registry source. `TestFactCardRegistryGate` (4 cases).
- **T-m1-05-03** (DoS / loop never answers, `mitigate`): mitigated — first-call-only force; iterations 2..MAX revert to auto; `test_loop_terminates_with_text_after_tool_result` asserts the loop ends with text in 2 calls.
- **T-m1-05-SC** (Tampering / pip installs, `accept`): no new packages — existing Anthropic SDK + pytest only. No package-legitimacy gate needed.

## Known Stubs

None. explain_concept resolves real registry pages; the forced tool_choice is wired end-to-end and tested for first-call-only + termination; the fact-card gate is wired into the external_calls path before flutter_tool_calls.extend. No placeholder/empty values flow to the UI.

## Threat Flags

None new. This plan CLOSES the Plan 04 threat-flag (the LLM-authored `show_fact_card.content`/`source` channel) — that surface is now routed through CONCEPT_REGISTRY validation. No new network endpoint, auth path, or schema change introduced.

## Next Phase Readiness

- **Plan 06 (domain corrections)** unaffected — it owns the constants-store VALUE fix (registry.py 65.0→64.5) and EPL/79b prose alignment; explain_concept will serve the corrected pages once Plan 06 lands.
- **Plan 07 (checkpoint)** — the forced-retrieval + registry-gated-card prevention is now in place to be exercised by the W1-persona walkthrough.
- **No blockers.** STATE.md / ROADMAP.md intentionally NOT modified (per the objective — orchestrator owns those writes).

## Self-Check: PASSED

- FOUND: services/backend/tests/test_explain_concept_tool.py
- FOUND: services/backend/tests/test_coach_chat_intent_force.py
- FOUND: services/backend/app/services/coach/coach_tools.py (explain_concept tool + handler at line ~1259)
- FOUND: services/backend/app/api/v1/endpoints/coach_chat.py (forced tool_choice line ~4410, gate line ~3000+)
- FOUND: services/backend/app/services/coach/claim_checker.py (resolve_definiendum)
- FOUND commit: 08a6a03d8 (Task 1 — explain_concept tool + handler)
- FOUND commit: cb3b5b837 (Tasks 2+3 — forced tool + fact-card gate)
- FOUND commit: 268280484 (Task 4 — snapshot regen)
- VERIFIED: test_coach_chat_intent_force.py → 14 passed (first-call-only force + loop termination + gate)
- VERIFIED: test_explain_concept_tool.py → 10 passed
- VERIFIED: full backend suite → 7808 passed, 116 skipped, 4 xfailed, 0 failed

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
