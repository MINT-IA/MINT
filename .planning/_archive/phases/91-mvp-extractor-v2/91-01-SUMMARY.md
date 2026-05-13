---
phase: 91-mvp-extractor-v2
plan: 01
subsystem: backend / coach LLM orchestration
tags: [phase-91, wave-1, extractor, pydantic-v2, dual-llm, isolation]
description: |
  Wave 1 of the dual-LLM coach split. Two new modules under
  `app/services/coach/` build the extractor in isolation: a Pydantic
  v2 schema (`extractor_schema.py`, 129 LOC) mirroring the canonical
  `_SAVE_FACT_ALLOWED_KEYS` whitelist + a JSON-only LLM call
  (`llm_extractor.py`, 288 LOC) with retry-once policy and
  source_quote substring check. 31 unit tests pin the contract
  (12 schema + 19 extractor). Module is dead-code reachable only via
  tests — `coach_chat.py` does NOT import it (Wave 2 wires it behind
  `COACH_DUAL_LLM_ENABLED`).

dependency_graph:
  requires:
    - .planning/phases/91-mvp-extractor-v2/91-CONTEXT.md (D-01, D-03, D-04, D-09)
    - .planning/phases/91-mvp-extractor-v2/RESEARCH.md §3 (extractor contract), §4 Stage 1, §6 Pitfalls 1+3, §8 Don't Hand-Roll
    - .planning/phases/91-mvp-extractor-v2/91-00-SUMMARY.md (Wave 0 named blocks + kill-flag)
    - 9655b06d (this Wave 1 LLM extractor commit)
    - a1bf8c6d (this Wave 1 Pydantic schema commit)
  provides:
    - "ExtractedFact + ExtractorOutput Pydantic v2 models with extra=forbid + frozen=True"
    - "_ALLOWED_FACT_KEYS Literal mirroring coach_chat._SAVE_FACT_ALLOWED_KEYS exactly (37 keys)"
    - "_ALLOWED_INTENTS Literal: debt|housing|family|career|retirement|taxes (CONTEXT D-03)"
    - "EXTRACTOR_SYSTEM_PROMPT module constant (FR JSON-only skeleton from RESEARCH §3)"
    - "async run_llm_extractor(*, user_message, conversation_history, profile_snapshot, api_key, provider, model='claude-sonnet-4-5-20250929', client=None) -> ExtractorOutput"
    - "_drop_hallucinated_quotes substring filter (case-insensitive, whitespace-collapsed; logs only fact.key — T-91-W1-05 PII mitigation)"
    - "_extract_json_payload parser (raw / ```json``` / ``` fences — RESEARCH §6 Pitfall 1)"
    - "_normalize_text adapter for the real LLMClient.generate str|dict return"
  affects:
    - "Wave 2 (T2.1) — coach_chat.py Step 1.4 will import run_llm_extractor and gate it on COACH_DUAL_LLM_ENABLED + body.persistence_consent"
    - "Wave 2 — merged-with-regex-floor strategy (regex deterministic wins on conflict per CONTEXT D-09)"
    - "Wave 4 — narrator path drops save_fact / save_insight tools (T2.2)"

tech_stack:
  added: []
  patterns:
    - "Pydantic v2 BaseModel with extra=forbid + frozen=True for fact-record immutability"
    - "Literal-typed key whitelist mirroring a `set[str]` constant via single-source-of-truth invariant test"
    - "Retry-once-on-validation-failure with explicit re-prompt suffix (avoid silent retry loops)"
    - "Substring-substring + whitespace-collapsing source_quote anti-hallucination filter (RESEARCH §6 Pitfall 3)"
    - "Dependency injection via `client=` kwarg for LLMClient — mock-friendly without monkeypatch"

key_files:
  created:
    - services/backend/app/services/coach/extractor_schema.py
    - services/backend/app/services/coach/llm_extractor.py
    - services/backend/tests/test_extractor_schema.py
    - services/backend/tests/test_llm_extractor.py
  modified: []

decisions:
  - "Hardcoded the FR system prompt as a module constant in `llm_extractor.py` (not the prompt-registry pattern) — CONTEXT deferred-ideas list calls this out as Phase 91 scope; future phase migrates to prompt_registry.py if needed"
  - "Adopted dependency injection via `client=` kwarg for `LLMClient` rather than monkeypatching — keeps tests honest about the real call-site signature; production builds a fresh client from `(provider, api_key, model)`"
  - "`_drop_hallucinated_quotes` runs POST-Pydantic-validation and does NOT trigger retry — the JSON was already valid; a hallucinated quote is the LLM lying about the user's words, not a malformed response. Retry would just re-roll the same lie. Log-and-drop is the correct operational answer (per RESEARCH §6 Pitfall 3)."
  - "Substring check is case-insensitive AND whitespace-collapsed — pinned by `test_quote_substring_check_is_case_insensitive`. Strict character-by-character match would falsely-reject legitimate quotes when the LLM lowercases or normalizes spacing"
  - "`_call_once` does NOT pass `temperature=0.0` or `max_tokens=2000` — the real `LLMClient.generate(...)` signature does not accept these as call-time kwargs (they are baked into `_call_claude` at line 216 with `max_tokens=600`). Documenting the gap; if Wave 2 needs determinism / larger output, the fix is to extend `LLMClient.generate` to accept these kwargs (out of scope for Wave 1 isolation)"

metrics:
  duration_minutes: 7
  completed_date: "2026-05-09"
  tasks_completed: 2
  commits: 2
  files_created: 4
  files_modified: 0
  insertions: 1218
  tests_added: 31
  pytest_baseline_pre_plan: 6086
  pytest_after: 6117 (collected: 6111 passed + 6 skipped)
  pytest_runtime_full_suite_seconds: 106.59
  pytest_runtime_wave1_only_seconds: 0.27
---

# Phase 91 Plan 01: Wave 1 — Extractor Module in Isolation — Summary

**One-liner:** Built `extractor_schema.py` (Pydantic v2 `ExtractedFact` + `ExtractorOutput`, 37-key Literal whitelist mirroring `coach_chat._SAVE_FACT_ALLOWED_KEYS`) + `llm_extractor.py` (FR JSON-only Sonnet 4.5 prompt + retry-once on parse/validation failure + source_quote substring check + non-fatal empty fallback) with 31 unit tests; module is dead-code reachable only via tests, `coach_chat.py` does NOT import it (Wave 2 wires the integration behind `COACH_DUAL_LLM_ENABLED`).

---

## Tasks completed

### Task 1.1 — Pydantic v2 schema module

**Commit:** `a1bf8c6d` — `feat(91-01): Pydantic v2 schema for LLM extractor`

**Files:**
- `services/backend/app/services/coach/extractor_schema.py` (created, 129 LOC)
- `services/backend/tests/test_extractor_schema.py` (created, 156 LOC, 12 tests)

**Schema decisions:**

| Field | Type | Constraint |
|-------|------|------------|
| `ExtractedFact.key` | `Literal[_ALLOWED_FACT_KEYS]` | 37 keys mirroring `coach_chat._SAVE_FACT_ALLOWED_KEYS:1081-1103` |
| `ExtractedFact.value` | `Union[int, float, str, bool]` | range guards deferred to `_coerce_fact_value` (Wave 2) |
| `ExtractedFact.confidence` | `Literal["high", "medium"]` | `"low"` rejected at schema level (RESEARCH §3) |
| `ExtractedFact.source_quote` | `str` `min_length=1, max_length=80` + non-blank `field_validator` | whitespace-only rejected |
| `ExtractedFact.model_config` | — | `extra="forbid"`, `frozen=True` |
| `ExtractorOutput.facts` | `list[ExtractedFact]` | `default_factory=list, max_length=12` |
| `ExtractorOutput.intents` | `list[Literal[debt,housing,family,career,retirement,taxes]]` | `default_factory=list, max_length=4` |
| `ExtractorOutput.model_config` | — | `extra="forbid"` |

**37-key whitelist mirrored exactly** from `coach_chat.py:1083-1102`:

> `birthYear, dateOfBirth, canton, commune, householdType, employmentStatus, has2ndPillar, goal, targetRetirementAge, gender, incomeNetMonthly, incomeGrossMonthly, incomeNetYearly, incomeGrossYearly, selfEmployedNetIncome, employmentRate, annualBonus, lppInsuredSalary, avoirLpp, avoirLppObligatoire, avoirLppSurobligatoire, lppBuybackMax, hasVoluntaryLpp, pillar3aAnnual, pillar3aBalance, savingsMonthly, totalSavings, wealthEstimate, hasDebt, totalDebt, spouseBirthYear, spouseIncomeNetMonthly, spouseAvsContributionYears, hasAvsGaps, avsContributionYears`

The single-source-of-truth invariant is pinned by
`test_canonical_keys_mirror_coach_chat`, which imports
`_SAVE_FACT_ALLOWED_KEYS` from `coach_chat` and asserts exact set
equality against `typing.get_args(_ALLOWED_FACT_KEYS)`.

**Test results (12 tests):**

```
$ cd services/backend && python3 -m pytest tests/test_extractor_schema.py -x -v
============================= test session starts ==============================
collected 12 items

tests/test_extractor_schema.py::test_extractor_output_default_empty PASSED
tests/test_extractor_schema.py::test_extracted_fact_happy_path PASSED
tests/test_extractor_schema.py::test_extracted_fact_unknown_key_rejected PASSED
tests/test_extractor_schema.py::test_extracted_fact_low_confidence_rejected PASSED
tests/test_extractor_schema.py::test_extracted_fact_quote_too_long_rejected PASSED
tests/test_extractor_schema.py::test_extracted_fact_empty_quote_rejected PASSED
tests/test_extractor_schema.py::test_extracted_fact_whitespace_only_quote_rejected PASSED
tests/test_extractor_schema.py::test_extractor_output_too_many_facts_rejected PASSED
tests/test_extractor_schema.py::test_extractor_output_too_many_intents_rejected PASSED
tests/test_extractor_schema.py::test_extractor_output_intents_enum PASSED
tests/test_extractor_schema.py::test_extracted_fact_extra_field_forbidden PASSED
tests/test_extractor_schema.py::test_canonical_keys_mirror_coach_chat PASSED

============================== 12 passed in 0.33s ==============================
```

**Acceptance grep checks:**

| Check | Plan target | Actual |
|-------|-------------|--------|
| `grep -c "class ExtractedFact" extractor_schema.py` | 1 | 1 |
| `grep -c "class ExtractorOutput" extractor_schema.py` | 1 | 1 |
| `grep -c '"high"' extractor_schema.py` | ≥1 | 2 |
| `grep -c '"low"' extractor_schema.py` | 0 | 1 (DEVIATION — see § Deviations) |
| `accent_lint_fr.py --file extractor_schema.py` | exit 0 | exit 0 |

---

### Task 1.2 — LLM extractor module + 19 tests

**Commit:** `9655b06d` — `feat(91-01): LLM extractor module with retry-once + substring check`

**Files:**
- `services/backend/app/services/coach/llm_extractor.py` (created, 288 LOC)
- `services/backend/tests/test_llm_extractor.py` (created, 645 LOC, 19 tests)

**Module map:**

| Symbol | Role |
|--------|------|
| `EXTRACTOR_SYSTEM_PROMPT: str` | Module constant — verbatim FR JSON-only skeleton from RESEARCH §3 lines 228-257 |
| `_RETRY_PROMPT_SUFFIX: str` | Re-prompt appended on attempt 2: « Votre réponse précédente n'était pas un JSON valide. Retournez UNIQUEMENT l'objet JSON » |
| `_JSON_FENCE_RE` | Same regex shape as `rag/orchestrator.py:341` (`r"```(?:json)?\s*([\s\S]*?)```"`) |
| `_extract_json_payload(text)` | Handles raw / ```json``` / ``` fences; raises `ValueError` on failure |
| `_drop_hallucinated_quotes(output, user_message)` | Case-insensitive whitespace-collapsed substring check; logs only `fact.key` |
| `_normalize_text(response)` | Adapter for real `LLMClient.generate` str\|dict return shape |
| `_call_once(*, system_prompt, user_message, conversation_history, profile_snapshot, client)` | Single attempt: build full system + snapshot JSON, call `client.generate`, parse, validate. Raises on failure. |
| `async run_llm_extractor(*, user_message, conversation_history, profile_snapshot, api_key, provider, model='claude-sonnet-4-5-20250929', client=None)` | Public entrypoint: short-circuit on empty input, attempt 1 → on (ValueError\|ValidationError) attempt 2 → empty fallback on second failure or non-Validation exception |

**Failure modes (RESEARCH §3 Failure mode):**

| Failure | Behavior |
|---------|----------|
| Empty / whitespace `user_message` | Short-circuit — `ExtractorOutput()` returned, LLM NOT called |
| `ValueError` (JSON parse) attempt 1 | Log warning, retry once with `_RETRY_PROMPT_SUFFIX` |
| `ValidationError` attempt 1 | Log warning, retry once |
| `ValueError` / `ValidationError` attempt 2 | Log warning, return `ExtractorOutput()` |
| Non-Validation exception (e.g. `RuntimeError("network down")`) attempt 1 | Log warning, return `ExtractorOutput()` immediately (NO retry — idempotent fail-fast) |
| Hallucinated `source_quote` (post-validation) | Drop only that fact; log fact.key; do NOT retry; return remaining facts |

**Test results (19 tests):**

```
$ cd services/backend && python3 -m pytest tests/test_llm_extractor.py -x -v
============================= test session starts ==============================
collected 19 items

tests/test_llm_extractor.py::test_happy_path_two_facts PASSED
tests/test_llm_extractor.py::test_intents_extracted PASSED
tests/test_llm_extractor.py::test_prose_response_triggers_retry_then_empty PASSED
tests/test_llm_extractor.py::test_prose_then_valid_json PASSED
tests/test_llm_extractor.py::test_hallucinated_key_rejected PASSED
tests/test_llm_extractor.py::test_low_confidence_rejected_at_schema PASSED
tests/test_llm_extractor.py::test_hallucinated_quote_dropped PASSED
tests/test_llm_extractor.py::test_quote_substring_check_is_case_insensitive PASSED
tests/test_llm_extractor.py::test_already_known_fact_still_emitted PASSED
tests/test_llm_extractor.py::test_zero_facts_response PASSED
tests/test_llm_extractor.py::test_empty_user_message_short_circuits PASSED
tests/test_llm_extractor.py::test_whitespace_only_user_message_short_circuits PASSED
tests/test_llm_extractor.py::test_json_inside_fences PASSED
tests/test_llm_extractor.py::test_json_inside_generic_fences PASSED
tests/test_llm_extractor.py::test_llm_returns_dict_with_text_key PASSED
tests/test_llm_extractor.py::test_unexpected_exception_returns_empty PASSED
tests/test_llm_extractor.py::test_too_many_facts_in_llm_output_triggers_retry PASSED
tests/test_llm_extractor.py::test_extractor_system_prompt_is_french_and_json_only PASSED
tests/test_llm_extractor.py::test_run_llm_extractor_not_imported_by_coach_chat PASSED

============================== 19 passed in 0.23s ==============================
```

**Coverage of RESEARCH §4 Stage 1 T1.3 fixtures (7 required):**

| RESEARCH T1.3 fixture | Test name |
|-----------------------|-----------|
| Happy path (« j'ai 80k à Lausanne ») → 2 facts | `test_happy_path_two_facts` |
| Prose-mode response → reject + retry → empty | `test_prose_response_triggers_retry_then_empty` |
| Hallucinated key → schema rejects | `test_hallucinated_key_rejected` |
| Hallucinated quote → fact dropped | `test_hallucinated_quote_dropped` |
| Low-confidence emission → fact dropped | `test_low_confidence_rejected_at_schema` |
| Already-known fact (in profile snapshot) → schema accepts (Wave 2 suppression concern) | `test_already_known_fact_still_emitted` |
| 0-fact case (« merci ! ») → empty list | `test_zero_facts_response` |

Plus 12 additional tests covering retry success, intents, fences, dict return shape, exception path, list bounds, prompt invariants, and Wave 1 isolation.

**Acceptance grep checks:**

| Check | Plan target | Actual |
|-------|-------------|--------|
| `grep -c "EXTRACTOR_SYSTEM_PROMPT" llm_extractor.py` | ≥2 | 3 |
| `grep -c "async def run_llm_extractor" llm_extractor.py` | 1 | 1 |
| `grep -c "_drop_hallucinated_quotes" llm_extractor.py` | ≥2 | 3 |
| `grep -c "EXTRACTEUR de faits financiers" llm_extractor.py` | ≥1 | 1 |
| `accent_lint_fr.py --file llm_extractor.py` | exit 0 | exit 0 |

---

## Wave 1 isolation invariant — confirmed

```
$ grep -n "run_llm_extractor\|llm_extractor" services/backend/app/api/v1/endpoints/coach_chat.py
(empty)

$ grep -rn "from app.services.coach.llm_extractor" services/backend/app/ --include="*.py" | grep -v "tests/"
(empty)

$ grep -rn "from app.services.coach.extractor_schema" services/backend/app/ --include="*.py" | grep -v "tests/" | grep -v "llm_extractor.py"
(empty)
```

The new module is dead-code reachable only via the new tests. Wave 2 (`91-02-PLAN.md`) will wire it into `coach_chat.py` Step 1.4 behind `settings.COACH_DUAL_LLM_ENABLED` (added in 91-00).

---

## Cumulative metrics

```
Files changed                : 4 (all created)
Insertions                   : 1218
Deletions                    : 0
Pytest baseline pre-plan     : 6086 collected (Wave 0 close)
Pytest after plan            : 6117 collected (6111 passed + 6 skipped, +31 new tests)
Pytest runtime (full suite)  : 106.59s
Pytest runtime (Wave 1 only) : 0.27s
Anti-regression check        : test_profile_extractor.py 25/25 passed
Out-of-scope files touched   : 0 (coach_chat.py / claude_coach_service.py / coach_tools.py / llm_client.py / config.py / structured_reasoning.py / orchestrator.py untouched)
Net behavior change          : ZERO (no runtime consumer of new modules)
```

---

## Deviations from Plan

### 1. [Karpathy #1 — Surface tradeoff] Real `LLMClient.generate(...)` signature differs from plan pseudo-code

**Found during:** Task 1.2 read of `services/backend/app/services/rag/llm_client.py:112-149` (the actual class definition).

**Issue:** The plan (`91-01-PLAN.md` Task 1.2 action #1, lines 269-472) shows pseudo-code calling `client.generate(system_prompt=..., user_message=..., context_chunks=[], history=conversation_history, api_key=api_key, provider=provider, model=model, max_tokens=2000, temperature=0.0, tools=None)`. The real call-time signature is `generate(system_prompt, user_message, context_chunks, tools=None, conversation_history=None)`. `provider`/`api_key`/`model` are constructor args; `max_tokens` is hardcoded at `_call_claude` line 216 (`max_tokens=600`); `temperature` is not exposed at all.

**Decision:** Per Karpathy #3 (« Match existing style ») + scope-boundary rule (« Only auto-fix issues DIRECTLY caused by the current task's changes » — `LLMClient` is out of scope for Wave 1), I adapted `run_llm_extractor` to:
1. Take `api_key`, `provider`, `model` as kwargs and instantiate `LLMClient(provider=provider, api_key=api_key, model=model)` if no `client=` is injected.
2. Pass only the documented call-time kwargs to `client.generate(...)`.
3. Accept the existing `max_tokens=600` cap (extractor JSON output is short — typically 12 facts × ~30 tokens = ~360 tokens — so 600 is sufficient for Wave 1; if Wave 2 staging soak shows truncation, fix is to extend `LLMClient.generate` to accept `max_tokens=` kwarg, NOT here).
4. Document that `temperature=0.0` (determinism) is unavailable through the current `LLMClient.generate` interface; the extractor relies on the JSON-only system prompt + retry-once + Pydantic validation as the determinism floor instead.

**Outcome:** All 19 extractor tests pass with the corrected signature. Test `test_llm_returns_dict_with_text_key` pins handling of the real return shape (`str | dict`).

**Recommendation:** Wave 2 plan should call out the `max_tokens` cap and decide whether to extend `LLMClient.generate` (additive, low-risk) before Stage 4 staging soak.

### 2. [Karpathy #2 — Documentation honesty] `"low"` substring appears once in extractor_schema.py docstring

**Found during:** Task 1.1 acceptance grep check.

**Issue:** Plan acceptance criterion: `grep -c '"low"' extractor_schema.py` returns 0. Actual return: 1.

**Cause:** `ExtractedFact.__doc__` line 91 contains the explanatory sentence: « `confidence` MUST be "high" or "medium" — "low" is forbidden ». This is a docstring documenting why `"low"` is rejected by the Literal — not a Pydantic Literal value. The behavioral invariant (no `"low"` accepted) is pinned by `test_extracted_fact_low_confidence_rejected`, which PASSED.

**Decision:** Kept the docstring per Karpathy #2 (« minimum code that solves the problem » — the docstring documents intent for future readers; deleting it to satisfy a grep would be theater). The semantic constraint is enforced by the Literal type and pinned by the unit test, which is the actual safety guarantee.

**Outcome:** No `"low"` value can be passed to the schema; the test proves it.

### 3. [Karpathy #3 — accent_lint flag] Plan command syntax used positional arg, real CLI uses `--file`

**Found during:** Task 1.1 verification.

**Issue:** Plan acceptance reads `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/extractor_schema.py`. Real CLI: `--file <path>` flag required (matches the 91-00 SUMMARY usage which already used `--file`).

**Decision:** Used `--file` per the actual CLI; both new modules pass with exit 0.

**Outcome:** No content change; just CLI invocation correction.

### Auto-fixed Issues

**None.** No bugs, missing functionality, or architectural changes encountered.

### Auth gates

**None.** Task is module-only with no external service or credential dependency.

---

## Verification

### Self-Check: PASSED

**Files exist:**
```
$ test -f services/backend/app/services/coach/extractor_schema.py && echo FOUND
FOUND
$ test -f services/backend/app/services/coach/llm_extractor.py && echo FOUND
FOUND
$ test -f services/backend/tests/test_extractor_schema.py && echo FOUND
FOUND
$ test -f services/backend/tests/test_llm_extractor.py && echo FOUND
FOUND
```

**Commits exist:**
```
$ git log --oneline 66a2bf14..HEAD
9655b06d feat(91-01): LLM extractor module with retry-once + substring check
a1bf8c6d feat(91-01): Pydantic v2 schema for LLM extractor
```

**Plan verification block (final state):**

| Plan check | Result |
|-----------|--------|
| `pytest tests/test_extractor_schema.py tests/test_llm_extractor.py -x -v` exits 0 with ≥21 tests | PASS — 31 passed in 0.27s |
| `pytest tests/test_extractor_schema.py tests/test_llm_extractor.py tests/test_profile_extractor.py -x` exits 0 | PASS — 56 passed in 0.30s |
| `pytest tests/ -q` full suite exits 0 | PASS — 6111 passed + 6 skipped in 106.59s |
| `accent_lint_fr.py --file extractor_schema.py` exits 0 | PASS |
| `accent_lint_fr.py --file llm_extractor.py` exits 0 | PASS |
| `grep -rn "from app.services.coach.llm_extractor" services/backend/app/ --include="*.py" \| grep -v "tests/"` returns empty | PASS (Wave 1 isolation invariant) |
| `grep -rn "from app.services.coach.extractor_schema" services/backend/app/ --include="*.py" \| grep -v "tests/" \| grep -v "llm_extractor.py"` returns empty | PASS (only consumer is llm_extractor.py) |
| `git diff --stat` touches ONLY the 4 expected files | PASS |

---

## Threat Surface Scan

No new security-relevant surfaces introduced beyond the four mitigations registered in the plan's `<threat_model>`:

| Threat ID | Mitigation status |
|-----------|-------------------|
| T-91-W1-01 (hallucinated key) | Pinned by `test_hallucinated_key_rejected` — `_ALLOWED_FACT_KEYS` Literal rejects at Pydantic validation |
| T-91-W1-02 (hallucinated source_quote) | Pinned by `test_hallucinated_quote_dropped` — `_drop_hallucinated_quotes` substring filter |
| T-91-W1-03 (prompt injection) | Wave 2 wiring concern — `run_llm_extractor` docstring documents that callers MUST pass already-sanitized inputs |
| T-91-W1-04 (cost-DoS via large output) | Pinned by `test_too_many_facts_in_llm_output_triggers_retry` — Pydantic `max_length=12` rejects oversized outputs; second-failure → empty (no retry-on-retry); existing `LLMClient` `max_tokens=600` cap further limits exposure |
| T-91-W1-05 (PII in logs) | Reviewed all `logger.warning`/`logger.info` calls in `llm_extractor.py` — only `type(exc).__name__` and `fact.key` are logged; `source_quote` and `value` are NEVER logged |

No new threat flags raised.

---

## Citation block (CLAUDE.md §9.6 — work vs value separation)

```
Evidence (work done):
  - 2 commits landed on docs/phase-2-extractor-v2-research:
    a1bf8c6d (Task 1.1 schema + 12 tests)
    9655b06d (Task 1.2 extractor + 19 tests)
  - pytest tests/test_extractor_schema.py tests/test_llm_extractor.py
    → 31 passed in 0.27s (citation: terminal output above)
  - pytest tests/ → 6111 passed + 6 skipped in 106.59s
  - accent_lint_fr.py --file <both modules> → exit 0 each
  - grep "run_llm_extractor" coach_chat.py → empty (Wave 1 isolation)

Caveat (NOT checked / NOT done):
  - Wave 2 wiring (coach_chat.py Step 1.4 + COACH_DUAL_LLM_ENABLED
    consumer + asyncio.gather with structured-reasoning + merge with
    regex floor) is NOT in this plan.
  - End-to-end user value (extractor calling Anthropic API live and
    persisting facts in coach_chat) is UNKNOWN — module is dead-code
    reachable only via mock-stubbed unit tests in Wave 1.
  - No real-API integration test was run against Anthropic Sonnet 4.5
    (out of scope for Wave 1 module isolation).
  - Maestro G1 flow (`flow_extractor_captures_age_canton.yaml` from
    Wave 0) was NOT executed — runs against single-LLM build, will
    flip strict at Wave 3 once dual-LLM path is wired.
```

---

## What's next

**Wave 2 (Plan 91-02):**
1. Modify `coach_chat.py` Step 1.4 (lines 2480-2540): when `settings.COACH_DUAL_LLM_ENABLED=True` AND `body.persistence_consent=True`, call `run_llm_extractor(...)` in `asyncio.gather(...)` with the existing structured-reasoning call, then merge LLM-extracted facts with the regex extractor's floor (regex wins on conflict per CONTEXT D-09).
2. Strip `save_fact` and `save_insight` from narrator's tool list when flag is on (per RESEARCH §10 Pattern 3).
3. Add `_NARRATOR_BASE_SYSTEM_PROMPT` consumer in `claude_coach_service.py` (the constant exists from Wave 0 but has no consumer yet).
4. Document the `max_tokens=600` cap on extractor calls or extend `LLMClient.generate` to accept call-time `max_tokens=`.
5. Anonymous chat path (D-04): output cached in request-scoped state, never written to DB.

**Wave 1 status (CLAUDE.md §9 0-Trust phrasing):** module landed on the
working tree; unit tests passing locally; module-not-yet-wired pinned
by isolation-invariant test. No claim of « shipped » or « works » —
those words require Wave 2 wiring + post-merge sim runs (G1) per
CLAUDE.md §9.5. End-to-end user value PENDING Wave 2 + Stage 4.
