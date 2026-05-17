---
phase: 91-mvp-extractor-v2
plan: 02
subsystem: backend / coach LLM orchestration
tags: [phase-91, wave-2, dual-llm, extractor, narrator, kill-flag, byte-identity]
description: |
  Wave 2 wires the LLM extractor module (Wave 1) into `coach_chat.py`
  Step 1.4 behind the `COACH_DUAL_LLM_ENABLED` flag (default False —
  flag-OFF path is byte-identical to today). Three concerns landed:
  (1) STAGE 2 invocation runs SEQUENTIALLY between the regex extractor
  (STAGE 1) and the narrator agent loop, with merge-with-regex-floor
  on conflict (D-09), in-memory state for anonymous chat (D-04), and
  a 30s TTL cache of canonical values only (D-10/D-11);
  (2) narrator surface narrowed via `get_narrator_llm_tools()` (excludes
  save_fact + save_insight per EXTR-04) + `build_narrator_system_prompt()`
  (extraction directives stripped per EXTR-03), both gated on the flag;
  (3) cost regression integration test pins ≤ +30% Haiku-narrator path
  (EXTR-06) and `xfail`-pins +54% Sonnet fallback ceiling per
  ADR-20260419-v2.8-kill-policy.md.

dependency_graph:
  requires:
    - .planning/phases/91-mvp-extractor-v2/91-CONTEXT.md (D-04, D-05, D-09, D-10, D-11, D-12)
    - .planning/phases/91-mvp-extractor-v2/RESEARCH.md §3 + §5 + §6 + §10
    - .planning/phases/91-mvp-extractor-v2/91-00-SUMMARY.md (Wave 0 named blocks + kill-flag)
    - .planning/phases/91-mvp-extractor-v2/91-01-SUMMARY.md (Wave 1 extractor module + schema)
    - b88e8d23 (Wave 2 wiring + narrator surface)
    - 5350d456 (Wave 2 cost regression test + Phase 94 stub)
  provides:
    - "_run_extractor_stage() — STAGE 2 wrapper, sequential, behind COACH_DUAL_LLM_ENABLED"
    - "_persist_extracted_fact() — refactor of save_fact persistence; D-04 anon vs auth branching"
    - "_merge_extracted() — regex-floor-wins-on-conflict per D-09 via _REGEX_TOPIC_TO_CANONICAL_KEYS map"
    - "_extractor_cache_get/set/key — 30s in-memory TTL cache, canonical values only (D-10/D-11)"
    - "_extractor_in_memory_state_for_request — request-scoped dict factory (D-04)"
    - "get_narrator_llm_tools() in coach_tools.py — excludes save_fact + save_insight (EXTR-04)"
    - "build_narrator_system_prompt() in claude_coach_service.py — uses _NARRATOR_BASE_SYSTEM_PROMPT (EXTR-03)"
    - "_run_agent_loop now accepts optional `tools=` parameter (default get_llm_tools() — flag-OFF preserved)"
  affects:
    - "Wave 3 (Plan 91-03) — Maestro G1 multi-fact flow strict assertion + Stage 3 narrator eval pack"
    - "Wave 4 (Stage 4 staging soak) — telemetry + cost monitoring with flag flipped to True"
    - "Phase 94 CITATION-GATE — runtime parser hooks into the trimmed narrator surface this wave shipped"

tech_stack:
  added: []
  patterns:
    - "Sequential extractor → persist → narrator pipeline (no asyncio.gather across them — RESEARCH §6 Pitfall 2)"
    - "Flag-gated divergence at builder + tool-list call sites; legacy path byte-identical when flag OFF"
    - "Tools parameter on _run_agent_loop (default get_llm_tools()) keeps body untouched per RESEARCH §10 Pattern 2"
    - "Shared private _build_prompt(base_template=…) parametric refactor of build_system_prompt"
    - "In-memory TTL dict for cache (CONTEXT D-10's documented in-memory-fallback path; Redis client wiring deferred until staging soak proves the cache hit-rate)"
    - "xfail strict=True ceiling pin pattern for documenting kill-policy fallback ceilings"

key_files:
  created:
    - services/backend/tests/test_coach_chat_dual_llm.py (537 LOC, 27 tests)
    - services/backend/tests/integration/test_dual_llm_cost.py (236 LOC, 4 passed + 1 xfailed)
    - services/backend/tests/test_narrator_refuses_uncited_numbers.py (37 LOC, Phase 94 stub)
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py (+404 LOC; helpers + STAGE 2 wiring + flag-gated narrator branching)
    - services/backend/app/services/coach/coach_tools.py (+45 LOC; _NARRATOR_EXCLUDED_TOOLS + get_narrator_llm_tools)
    - services/backend/app/services/coach/claude_coach_service.py (+72 / -25 LOC; _build_prompt private worker + build_narrator_system_prompt wrapper + __all__ extension)
    - services/backend/tests/test_llm_extractor.py (+33 / -13 LOC; Wave 1 isolation invariant flipped to Wave 2 wiring invariant)

decisions:
  - "Tasks 2.1 + 2.2 committed as one atomic feat() commit (b88e8d23) instead of two separate commits — coach_chat.py imports both helpers at the same call site, splitting would create artificial intermediate states (Karpathy #2 Simplicity First). Plan-level deviation documented here."
  - "Cache backend = pure in-memory TTL dict (no Redis wiring). CONTEXT D-10 explicitly says « in-memory dict fallback if Redis env unset »; Wave 2 ships the fallback path. If Stage 4 staging soak shows cache hit-rate matters across multi-worker deployment, follow-up phase wires Redis. Per Karpathy #2."
  - "D-05 vs EXTR-04: narrator's tool list EXCLUDES save_insight (per EXTR-04 + RESEARCH §3 + milestone « 2 prompts, 2 guardrails, 2 budgets »). The OWNERSHIP question (D-05: insight detection is narrative judgment) is preserved — a follow-up phase MAY re-introduce save_insight as a narrator tool if Stage 3 eval shows under-call symptoms. Until then, insight capture falls back to the regex/heuristic floor."
  - "_run_agent_loop accepts optional tools= kwarg (default get_llm_tools()) instead of refactoring stripped_tools site INSIDE the body. RESEARCH §10 Pattern 2 says « only the system_prompt + tools change »; adding a parameter satisfies that without modifying body logic."
  - "Wave 1 isolation invariant test (`test_run_llm_extractor_not_imported_by_coach_chat`) is FLIPPED in this wave to `test_run_llm_extractor_imported_by_coach_chat_in_wave_2` — auto-fix Rule 1 because the original test's own docstring documented Wave 2 as the expected breaking point. Test now pins both the import AND the sequential invariant."

metrics:
  duration_minutes: 35
  completed_date: "2026-05-09"
  tasks_completed: 3
  commits: 2
  files_created: 3
  files_modified: 4
  insertions: 1389
  deletions: 25
  tests_added: 32 (27 dual_llm + 4 cost regression passed + 1 cost xfail + 1 Phase 94 skip — the 27+4+1+1 = 33; net +32 since 1 Wave 1 test was inverted in place)
  pytest_baseline_pre_plan: 6117 (6111 passed + 6 skipped per Wave 1 close)
  pytest_after: 6150 (6142 passed + 7 skipped + 1 xfailed)
  pytest_runtime_full_suite_seconds: 107.75
---

# Phase 91 Plan 02: Wave 2 — Dual-LLM Wiring — Summary

**One-liner:** Wired the Wave 1 LLM extractor module into `coach_chat.py` Step 1.4 behind `COACH_DUAL_LLM_ENABLED` (default False — flag-OFF byte-identical to today); narrator surface narrowed via `get_narrator_llm_tools()` (no `save_fact`/`save_insight` per EXTR-04) and `build_narrator_system_prompt()` (no extraction directives per EXTR-03); 27 dual-LLM behavior tests + 5 cost regression tests pin the EXTR-01/03/04/05/06 contracts; sequential invariant grep returns 0 (no `asyncio.gather` across extractor + narrator).

---

## Tasks completed

### Task 2.1 — Wire extractor STAGE 2 (combined with Task 2.2 in commit b88e8d23)

**Commit:** `b88e8d23` — `feat(91-02): wire dual-LLM extractor + narrator surface narrowing (Wave 2)`

**Files modified:**
- `services/backend/app/api/v1/endpoints/coach_chat.py` — STAGE 2 wiring, helpers, narrator branching
- `services/backend/tests/test_coach_chat_dual_llm.py` — created, 27 tests

**Helpers added in coach_chat.py (before `AGENT_LOOP_DEADLINE_SECONDS` at L1453):**

| Symbol | Purpose | Lines |
|--------|---------|-------|
| `_REGEX_TOPIC_TO_CANONICAL_KEYS` | Map regex `Fact.topic` → set of canonical `_SAVE_FACT_*` keys for D-09 conflict detection | 1230-1244 |
| `_persist_extracted_fact(fact, *, user_id, db, in_memory_state=None)` | D-04 branching persistence: auth → DB; anonymous → in-memory dict | 1247-1300 |
| `_merge_extracted(regex_covered_keys, llm_facts)` | Regex-floor-wins-on-conflict per D-09 | 1303-1314 |
| `_extractor_in_memory_state_for_request()` | Factory returning fresh `dict` per request (D-04) | 1317-1322 |
| `_extractor_cache_get/set/key` | 30s TTL in-memory cache; canonical values only (D-10/D-11) | 1331-1356 |
| `_run_extractor_stage(*, sanitized_message, …)` | Public STAGE 2 wrapper used at the endpoint | 1359-1450 |

**Wiring sites (refactor map):**

| coach_chat.py site | Before (line) | After (line) | Change |
|--------------------|---------------|--------------|--------|
| Imports | L52-58 | L52-65 | +`settings`, +`build_narrator_system_prompt`, +`get_narrator_llm_tools`, +`run_llm_extractor`, +`ExtractedFact`, +`ExtractorOutput` |
| `_build_system_prompt_with_memory` | L758 | L758-769 | Branches on `settings.COACH_DUAL_LLM_ENABLED` (flag-ON → narrator builder; flag-OFF → legacy) |
| `_run_agent_loop` signature | L2330-2345 | L2330-2346 | +`tools: Optional[list[dict]] = None` parameter |
| `_run_agent_loop` body L2371 | `stripped_tools = get_llm_tools()` | `stripped_tools = tools if tools is not None else get_llm_tools()` | Caller pre-computes; body untouched per RESEARCH §10 Pattern 2 |
| Step 1.4 STAGE 2 invocation | (new) | L2867-2895 | Calls `_run_extractor_stage(...)` AFTER regex extractor + BEFORE `_build_system_prompt_with_memory` |
| Anonymous PROFIL block | (new) | L2982-3025 | Surfaces `_extractor_in_memory_state` to narrator system prompt for anonymous chat (D-04) |
| `_run_agent_loop` call site | L3107-3123 | L3122-3158 | Pre-computes `_narrator_tools` based on flag; passes via `tools=` |

**Test results — test_coach_chat_dual_llm.py:**

```
$ cd services/backend && python3 -m pytest tests/test_coach_chat_dual_llm.py -v
collected 27 items

tests/test_coach_chat_dual_llm.py::TestMergeExtracted::test_merge_regex_only_no_llm_facts PASSED
tests/test_coach_chat_dual_llm.py::TestMergeExtracted::test_merge_llm_augments_when_regex_misses PASSED
tests/test_coach_chat_dual_llm.py::TestMergeExtracted::test_merge_regex_wins_on_conflict PASSED
tests/test_coach_chat_dual_llm.py::TestPersistExtractedFact::test_anonymous_writes_to_in_memory_state_only PASSED
tests/test_coach_chat_dual_llm.py::TestPersistExtractedFact::test_anonymous_value_coerced_via_coerce_fact_value PASSED
tests/test_coach_chat_dual_llm.py::TestPersistExtractedFact::test_anonymous_invalid_value_rejected PASSED
tests/test_coach_chat_dual_llm.py::TestPersistExtractedFact::test_no_user_no_state_returns_false PASSED
tests/test_coach_chat_dual_llm.py::TestPersistExtractedFact::test_authenticated_writes_to_db PASSED
tests/test_coach_chat_dual_llm.py::TestExtractorCache::test_cache_set_then_get_round_trips PASSED
tests/test_coach_chat_dual_llm.py::TestExtractorCache::test_cache_expired_entry_returns_none PASSED
tests/test_coach_chat_dual_llm.py::TestExtractorCache::test_cache_canonical_values_only_no_source_quote_d11 PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_off_does_not_call_llm_extractor PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_pure_ack_skips_extractor PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_authenticated_no_consent_skips_extractor PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_extractor_failure_returns_empty PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_anonymous_runs_in_memory_no_db PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_regex_floor_wins_on_conflict PASSED
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_cache_hit_skips_second_call PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_narrator_tools_no_save_fact PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_narrator_excluded_tools_set_documented PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_legacy_get_llm_tools_still_includes_save_fact PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_narrator_prompt_has_no_extraction_directives PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_narrator_prompt_keeps_delivery_doctrine PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_legacy_path_keeps_full_prompt PASSED
tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_legacy_base_prompt_byte_identity_preserved PASSED
tests/test_coach_chat_dual_llm.py::TestInMemoryStateHelper::test_factory_returns_fresh_dict_each_call PASSED
tests/test_coach_chat_dual_llm.py::test_sequential_invariant_no_asyncio_gather_extractor_narrator PASSED

============================== 27 passed in 0.27s ==============================
```

---

### Task 2.2 — Narrator surface (combined with Task 2.1 in commit b88e8d23)

**coach_tools.py — `get_narrator_llm_tools()` (L1235-1267):**

```python
_NARRATOR_EXCLUDED_TOOLS: set[str] = {"save_fact", "save_insight"}


def get_narrator_llm_tools() -> list[dict[str, Any]]:
    """Narrator-scoped tool list (Phase 91 Wave 2, EXTR-04)."""
    _LLM_ALLOWED_FIELDS = {"name", "description", "input_schema"}
    return [
        {k: v for k, v in tool.items() if k in _LLM_ALLOWED_FIELDS}
        for tool in COACH_TOOLS
        if tool.get("name") not in _NARRATOR_EXCLUDED_TOOLS
    ]
```

**claude_coach_service.py — `_build_prompt` + `build_narrator_system_prompt`:**
- `build_system_prompt` and `build_narrator_system_prompt` are now thin wrappers around shared private `_build_prompt(*, base_template, ctx, language, cash_level)` (L749-794).
- Difference: one keyword argument (`base_template=_BASE_SYSTEM_PROMPT` vs `_NARRATOR_BASE_SYSTEM_PROMPT`).
- Legacy `_BASE_SYSTEM_PROMPT` byte-identity preserved (Wave 0 SHA256 invariant test still PASSES — `tests/test_claude_coach_service.py::test_base_system_prompt_blocks`).

---

### Task 2.3 — Cost regression integration test + Phase 94 stub

**Commit:** `5350d456` — `test(91-02): cost regression integration test + Phase 94 stub (Wave 2)`

**Files created:**
- `services/backend/tests/integration/test_dual_llm_cost.py` (236 LOC, 5 tests)
- `services/backend/tests/test_narrator_refuses_uncited_numbers.py` (37 LOC, skip-marked Phase 94 stub)

**Test results:**

```
$ cd services/backend && python3 -m pytest tests/integration/test_dual_llm_cost.py tests/test_narrator_refuses_uncited_numbers.py -v
collected 6 items

tests/integration/test_dual_llm_cost.py::test_cost_legacy_baseline PASSED
tests/integration/test_dual_llm_cost.py::test_cost_dual_haiku_narrator_within_30pct PASSED
tests/integration/test_dual_llm_cost.py::test_cost_dual_sonnet_narrator_exceeds_30pct_marked_xfail XFAIL
tests/integration/test_dual_llm_cost.py::test_cache_hit_eliminates_extractor_cost PASSED
tests/integration/test_dual_llm_cost.py::test_skip_on_empty_eliminates_extractor_cost PASSED
tests/test_narrator_refuses_uncited_numbers.py::test_narrator_refuses_uncited_numbers SKIPPED

=================== 4 passed, 1 skipped, 1 xfailed in 0.30s ====================
```

**Cost computations (RESEARCH §5 ASSUMED rates):**
- Legacy Sonnet baseline: $0.0195/turn (4500 in × $3/1M + 400 out × $15/1M).
- Dual Haiku narrator: $0.0190/turn = -2.5% vs baseline (≤ +30% EXTR-06 PASS).
- Dual Sonnet narrator: $0.0300/turn = +54% (xfail strict pin — kill-policy ceiling per ADR-20260419-v2.8-kill-policy.md).
- Cache hit: extractor cost eliminated → $0.0136/turn (cache savings ≈ $0.0054).
- Skip-on-empty: extractor cost eliminated → narrator-only $0.0175/turn.

---

## Sequential invariant proof (T-91-W2-01)

```
$ grep -E "asyncio\.gather.*run_llm_extractor|asyncio\.gather.*_run_agent_loop|asyncio\.gather.*_run_extractor_stage" services/backend/app/api/v1/endpoints/coach_chat.py | wc -l
0
```

The extractor → persist → narrator chain is strictly sequential (RESEARCH §6 Pitfall 2). Pinned by `tests/test_coach_chat_dual_llm.py::test_sequential_invariant_no_asyncio_gather_extractor_narrator`.

---

## Flag-OFF invariance proof

The legacy single-LLM path is byte-identical to today when `COACH_DUAL_LLM_ENABLED=False`:

1. **`_BASE_SYSTEM_PROMPT` byte-identity** (Wave 0 invariant, still GREEN):
   ```
   tests/test_claude_coach_service.py::test_base_system_prompt_blocks PASSED
   ```
2. **Legacy tools list still contains save_fact + save_insight**:
   ```
   tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_legacy_get_llm_tools_still_includes_save_fact PASSED
   ```
3. **Legacy prompt still contains EXTRACTION DE PROFIL block**:
   ```
   tests/test_coach_chat_dual_llm.py::TestNarratorSurface::test_legacy_path_keeps_full_prompt PASSED
   ```
4. **`_run_agent_loop` `tools=None` defaults to `get_llm_tools()` — body branch is `tools if tools is not None else get_llm_tools()`** (`coach_chat.py:L2374`).

When the flag is OFF: every call site uses the legacy path and produces a system prompt + tool list bytewise-equal to today. No DB write path changed. No log line changed.

---

## D-04 anonymous-chat path

**Code citation:** `coach_chat.py:L1247-1300` (`_persist_extracted_fact` D-04 branch) + `L2982-3025` (anonymous PROFIL block builder).

**Test citation:**
```
tests/test_coach_chat_dual_llm.py::TestRunExtractorStage::test_flag_on_anonymous_runs_in_memory_no_db PASSED
```

The anonymous-chat path:
1. Runs the extractor LLM regardless of `persistence_consent` (D-04 carve-out).
2. Persists merged facts to a **request-scoped Python dict** (`_extractor_in_memory_state_for_request()`).
3. NEVER touches the DB. `_persist_extracted_fact` returns `False` if `user_id is None` AND `in_memory_state is None`.
4. Narrator's PROFIL block surfaces the in-memory facts so the narrator « reads the fresh consolidated profile » (RESEARCH §3 contract holds for anonymous chat).

---

## D-05 vs EXTR-04 resolution narrative

CONTEXT.md D-05 says « save_insight stays narrator-side » as an OWNERSHIP decision (insight detection is narrative judgment, not fact extraction).

EXTR-04 + RESEARCH §3 narrator tool list explicitly REMOVE save_insight from the narrator's tools.

**Resolution in Wave 2:** the narrator's TOOL LIST excludes save_insight per EXTR-04 + RESEARCH §3 + the milestone architectural commitment (« 2 prompts, 2 guardrails, 2 budgets »). The OWNERSHIP question is preserved — D-05 says insight detection is narrative judgment, so a follow-up phase MAY re-introduce save_insight as a NARRATOR tool if Stage 3 narrator eval shows under-call symptoms. Until then, insight capture falls back to the regex/heuristic floor (matches today's degraded baseline).

This trade-off is documented inline in `coach_tools.py:L1226-1244` (the `_NARRATOR_EXCLUDED_TOOLS` block comment) and in `91-02-PLAN.md` Task 2.2 PART A NOTE.

---

## Pytest output (citation per CLAUDE.md §9.6)

```
$ cd services/backend && python3 -m pytest tests/ -q
6142 passed, 7 skipped, 1 xfailed in 107.75s (0:01:47)
```

Baseline (Wave 1 close): 6111 passed + 6 skipped.
After Wave 2: 6142 passed + 7 skipped + 1 xfailed = +31 passed + +1 skipped + +1 xfailed = +33 net.
- 27 new in `test_coach_chat_dual_llm.py` (passed).
- 4 new passed in `test_dual_llm_cost.py` (1 xfailed, 0 failed).
- 1 new skipped in `test_narrator_refuses_uncited_numbers.py` (Phase 94 stub).
- 1 Wave 1 invariant test was inverted in place (still 1 test, behavior flipped).

---

## Lint output

```
$ python3 tools/checks/banned_terms_arb.py
OK — 6 locale(s) clean (no positive LSFin banned-term uses).

$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/api/v1/endpoints/coach_chat.py
(exit 0 — clean)

$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/coach_tools.py
(exit 0 — clean)

$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/claude_coach_service.py
5 PRE-EXISTING violations (lines 281, 282, 440, 442, 799 — « eclairage », « deja »).
NO NEW violations introduced by Wave 2 (verified by `git diff HEAD`).
Per CLAUDE.md §7 #3 Surgical, pre-existing violations stay untouched.
Same scope-boundary decision as Wave 0 SUMMARY § 1.

$ python3 tools/checks/accent_lint_fr.py --file services/backend/tests/integration/test_dual_llm_cost.py
(exit 0 — clean)

$ python3 tools/checks/accent_lint_fr.py --file services/backend/tests/test_narrator_refuses_uncited_numbers.py
(exit 0 — clean)
```

---

## Acceptance grep summary

| Acceptance criterion | Plan target | Actual |
|----------------------|-------------|--------|
| `_persist_extracted_fact` references in coach_chat.py | ≥ 2 | 4 |
| `from app.services.coach.llm_extractor import run_llm_extractor` | 1 | 1 |
| `settings.COACH_DUAL_LLM_ENABLED` references | ≥ 1 | 4 |
| `_merge_extracted` references | ≥ 2 | 2 |
| `_extractor_in_memory_state` references | ≥ 2 | 5 |
| `asyncio.gather` across extractor + narrator | 0 | 0 |
| `save_fact` references in coach_tools.py | ≥ 1 | 11 |
| `def get_narrator_llm_tools` | 1 | 1 |
| `_NARRATOR_EXCLUDED_TOOLS` references | ≥ 2 | 3 |
| `def get_llm_tools` (legacy preserved) | 1 | 1 |
| `def build_narrator_system_prompt` | 1 | 1 |
| `def build_system_prompt` (legacy preserved) | 1 | 1 |
| `get_narrator_llm_tools` used in coach_chat.py | ≥ 1 | 4 |
| `build_narrator_system_prompt` used in coach_chat.py | ≥ 1 | 2 |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Wave 1 isolation invariant test inverted**
- **Found during:** Task 2.1 verification (full pytest run).
- **Issue:** `tests/test_llm_extractor.py::test_run_llm_extractor_not_imported_by_coach_chat` asserted `coach_chat.py` does NOT import `run_llm_extractor`. Wave 2 imports it — by design.
- **Fix:** Renamed to `test_run_llm_extractor_imported_by_coach_chat_in_wave_2` and inverted the assertion. The test now pins (a) the import landed, (b) no `asyncio.gather(...)` across extractor + narrator (sequential invariant).
- **Justification:** The original test's own docstring (line 635-636 pre-flip) said « Wave 2 will. If this test fails, Wave 2 wiring leaked into Wave 1 ». The flip is the planned outcome at the planned time.
- **Files modified:** `services/backend/tests/test_llm_extractor.py` (committed in `b88e8d23`).
- **Commit:** `b88e8d23`.

### Notes / scope-boundary decisions

**1. [Karpathy #2 — Simplicity First] Cache backend = pure in-memory TTL dict.**
- CONTEXT D-10 says « Redis backend, in-memory dict fallback if Redis env unset ». Wave 2 ships ONLY the in-memory fallback path (no Redis client wiring).
- **Why:** the `app.core.rate_limit` module exposes a SlowAPI `Limiter` with a Redis storage URI, but does NOT export a Redis client object directly. Wiring a separate `redis.Redis` client adds 30+ LOC of connection/timeout/error-handling surface for what is at this stage an OPTIONAL optimization (the CONTEXT D-10 carve-out explicitly says in-memory is acceptable).
- **Stage 4 staging gate:** if cache hit-rate matters across multi-worker deployment, follow-up phase wires Redis. Documented as deferred in this SUMMARY.

**2. [Karpathy #2 — Simplicity First] Tasks 2.1 + 2.2 committed atomically as one feat.**
- The plan wants 3 separate per-task commits. Tasks 2.1 + 2.2 modify overlapping lines in `coach_chat.py` (the imports + the `_run_agent_loop` call site both branch on the flag and use BOTH `_run_extractor_stage` AND `get_narrator_llm_tools`). Splitting would require artificial intermediate states.
- **Outcome:** one commit `b88e8d23` covers Tasks 2.1+2.2, one commit `5350d456` covers Task 2.3. Net 2 commits instead of planned 3.
- **Trade-off:** less granular bisect history, but cleaner intermediate state. Accepted.

**3. [Karpathy #3 — Surgical] Pre-existing accent_lint_fr violations in `claude_coach_service.py` untouched.**
- 5 violations on lines 281, 282, 440, 442, 799 — same as Wave 0 SUMMARY documented. My Wave 2 refactor (`_build_prompt` + `build_narrator_system_prompt` wrappers) introduced ZERO new violations (verified by `git diff HEAD | grep -E "^\+.*premier eclairage|^\+.*deja "` returning empty).
- Per Wave 0 precedent and CLAUDE.md §7 #3, these stay untouched. Out of scope for Phase 91.

**4. [Plan Task 2.1 step 8] Anonymous PROFIL block placement.**
- Plan said « Update the « PROFIL UTILISATEUR » block builder at L2611-2619 to MERGE `_extractor_in_memory_state` into the profile snapshot ».
- **Implementation:** added a NEW block at coach_chat.py L2982-3025 immediately AFTER the existing `if _user and db:` PROFIL block. Reason: the existing block is gated on `_user` being non-None — anonymous chat skips it entirely. Modifying its body would have introduced a flag-dependent branch inside an already complex try/except. A separate parallel block for the anonymous case keeps both code paths surgical (CLAUDE.md §7 #3).

### Auth gates

**None.** Module-level wiring + unit/integration tests; no external service or credential dependency exercised in Wave 2.

---

## Verification

### Self-Check: PASSED

**Files exist:**
```
$ test -f services/backend/tests/test_coach_chat_dual_llm.py && echo FOUND
FOUND
$ test -f services/backend/tests/integration/test_dual_llm_cost.py && echo FOUND
FOUND
$ test -f services/backend/tests/test_narrator_refuses_uncited_numbers.py && echo FOUND
FOUND
```

**Commits exist:**
```
$ git log --oneline e506577e..HEAD
5350d456 test(91-02): cost regression integration test + Phase 94 stub (Wave 2)
b88e8d23 feat(91-02): wire dual-LLM extractor + narrator surface narrowing (Wave 2)
```

**Plan verification block (final state):**

| Plan check | Result |
|-----------|--------|
| `pytest tests/test_coach_chat_dual_llm.py tests/integration/test_dual_llm_cost.py tests/test_narrator_refuses_uncited_numbers.py -x -v` | PASS — 27+4+1 skipped+1 xfailed in 0.31s |
| `pytest tests/ -q` full suite | PASS — 6142 passed + 7 skipped + 1 xfailed in 108s |
| `pytest tests/test_profile_extractor.py -q` (25 anti-regression) | PASS — 25 passed in 0.04s |
| `accent_lint_fr.py --file <coach_chat.py>` | PASS exit 0 |
| `accent_lint_fr.py --file <coach_tools.py>` | PASS exit 0 |
| `accent_lint_fr.py --file <claude_coach_service.py>` | DEVIATION — 5 PRE-EXISTING violations untouched (Wave 0 same scope-boundary decision); 0 new violations introduced |
| `banned_terms_arb.py` | PASS — 6 locales clean |
| Sequential invariant grep | PASS — 0 matches |
| Flag-OFF byte-identity (Wave 0 SHA256 + this wave's `test_legacy_path_keeps_full_prompt`) | PASS |
| `git diff --stat e506577e..HEAD` touches only the 7 expected files | PASS |
| Zero modifications to `structured_reasoning.py`, `llm_client.py`, `profile_extractor.py`, `orchestrator.py`, `extractor_schema.py`, `llm_extractor.py` | PASS (only test_llm_extractor.py was modified — Rule 1 Wave 1 invariant flip) |

---

## Threat Surface Scan

No new security-relevant surface introduced beyond the four mitigations registered in the plan's `<threat_model>`:

| Threat ID | Mitigation status |
|-----------|-------------------|
| T-91-W2-01 (stale profile race) | Pinned by `test_sequential_invariant_no_asyncio_gather_extractor_narrator` — sequential invariant grep returns 0 |
| T-91-W2-02 (narrator hallucinates save_fact after removal) | Pinned by `test_narrator_tools_no_save_fact` + `test_narrator_prompt_has_no_extraction_directives` — both EXTR-03 + EXTR-04 hold simultaneously |
| T-91-W2-03 (extractor over-extracts) | Wave 1 substring check + this wave's regex floor wins via `_merge_extracted` + `_coerce_fact_value` range guards in `_persist_extracted_fact` |
| T-91-W2-04 (cache leaks PII source_quote in Redis) | Pinned by `test_cache_canonical_values_only_no_source_quote_d11` — payload type is `list[dict]` with `key` + `value` only |
| T-91-W2-05 (anonymous DB write) | Pinned by `test_anonymous_writes_to_in_memory_state_only` + `test_no_user_no_state_returns_false` |
| T-91-W2-06 (cost-DoS) | EXTR-06 cost test pins ≤ +30% with Haiku narrator + cache + skip-on-empty; integration test ships in commit `5350d456` |
| T-91-W2-07 (extractor failure cascades) | Pinned by `test_flag_on_extractor_failure_returns_empty` — narrator runs anyway with regex floor; failure is non-fatal |
| T-91-W2-08 (« tests passing ≠ feature working ») | Acknowledged — Wave 3 ships Maestro G1 + Julien G2 device sign-off. Wave 2 unit + integration tests are NECESSARY but NOT SUFFICIENT for « ready » per CLAUDE.md §9.2 |

No new threat flags raised.

---

## Citation block (CLAUDE.md §9.6 — work vs value separation)

```
Evidence (work done):
  - 2 commits landed on docs/phase-2-extractor-v2-research:
    b88e8d23 (Tasks 2.1+2.2 wiring + 27 dual-LLM tests + 1 Wave-1 test inverted)
    5350d456 (Task 2.3 cost regression + Phase 94 stub — 4 passed + 1 xfailed + 1 skipped)
  - pytest tests/test_coach_chat_dual_llm.py tests/integration/test_dual_llm_cost.py
    tests/test_narrator_refuses_uncited_numbers.py
    → 31 passed + 1 skipped + 1 xfailed in 0.31s (citation: terminal output above)
  - pytest tests/ → 6142 passed + 7 skipped + 1 xfailed in 107.75s
    (baseline 6111 passed + 6 skipped → +31 passed + +1 skipped + +1 xfailed)
  - banned_terms_arb.py → exit 0 (6 locales clean)
  - sequential invariant grep → 0 matches in coach_chat.py
  - Wave 0 byte-identity test (SHA256 on _BASE_SYSTEM_PROMPT) still PASSING

Caveat (NOT checked / NOT done):
  - End-to-end Maestro G1 multi-fact flow against booted iOS sim
    (deferred to Wave 3 per plan critical_rules — "Maestro G1 PASS is
    Wave 3 work, do NOT claim it").
  - Stage 3 narrator eval (Haiku vs Sonnet on 50 fixtures) — D-06 gate,
    blocking Stage 4 staging flip.
  - Real Anthropic API integration test against Sonnet 4.5 / Haiku 4.5
    (only mock-stubbed unit tests in Wave 2; no live LLM call).
  - Stage 0 D-07 telemetry baseline (Sonnet under-calls save_fact rate)
    deferred to Julien per Wave 0 SUMMARY — open dependency BEFORE
    Stage 4 flip, NOT a Wave 2 blocker.
  - Cost regression test uses ASSUMED Anthropic pricing (RESEARCH §5
    A1+A2); re-validate if Stage 0 telemetry shows >20% drift.
  - Per CLAUDE.md §9.5 trap: Wave 2 PRs (b88e8d23 + 5350d456) are at
    Stage 1 of 4 (PR-opened-equivalent on a feature branch). Cannot
    claim « shipped » or « ready » or « works » for the dual-LLM path
    until (a) merge to dev, (b) Stage 3 eval pass, (c) Stage 4 staging
    soak, (d) post-merge sim run.
```

---

## What's next

**Wave 3 (Plan 91-03 — to be planned):**
1. Strict-mode flip on `flow_extractor_captures_age_canton.yaml` (D-08): birthYear assertion goes from OPTIONAL → STRICT.
2. Stage 3 narrator eval pack: 50 PII-scrubbed production turns × Haiku narrator + Sonnet narrator. Pass criteria: ≥ 95% Sonnet pass-rate on ComplianceGuard + DoctrineChecks + banned-term lint, plus Julien on-brand sign-off.
3. End-to-end Maestro G1 walkthrough on booted sim — anonymous chat path with multi-fact extraction (« j'ai 80k de salaire à Lausanne, je suis né en 1990 »).

**Wave 4 (Stage 4 staging soak):**
1. Flip `COACH_DUAL_LLM_ENABLED=True` on staging.
2. Monitor cost regression (target ≤ +30% per EXTR-06).
3. Monitor extractor recall lift on the cohort that Stage 0 telemetry baseline (D-07) flagged as under-called.
4. Julien G2 device sign-off — TestFlight build with flag ON.

**Open dependencies for Stage 4:**
- Stage 0 telemetry baseline raw-rate computation (D-07) — Julien runs the grep over Sentry/Railway logs.
- Stage 3 eval verdict (Haiku vs Sonnet narrator) — D-06 gate.
- ANTHROPIC_API_KEY rate-limit headroom for the +1 LLM call/turn during staging soak.

**Wave 2 status (CLAUDE.md §9 0-Trust phrasing):** wiring landed on
working tree branch `docs/phase-2-extractor-v2-research`; pytest GREEN
locally with full sequential invariant + byte-identity proofs;
Maestro G1 + Stage 3 eval + post-merge sim verification PENDING. No
claim of « shipped », « ready », or « works » — those words require
Stage 3 eval + Stage 4 staging soak + post-merge sim runs (per
CLAUDE.md §9.5 trap).

---

## Self-Check: PASSED

```
Files exist:
  FOUND: services/backend/app/api/v1/endpoints/coach_chat.py
  FOUND: services/backend/app/services/coach/coach_tools.py
  FOUND: services/backend/app/services/coach/claude_coach_service.py
  FOUND: services/backend/tests/test_coach_chat_dual_llm.py
  FOUND: services/backend/tests/integration/test_dual_llm_cost.py
  FOUND: services/backend/tests/test_narrator_refuses_uncited_numbers.py
  FOUND: .planning/phases/91-mvp-extractor-v2/91-02-SUMMARY.md

Commits exist:
  5350d456 test(91-02): cost regression integration test + Phase 94 stub (Wave 2)
  b88e8d23 feat(91-02): wire dual-LLM extractor + narrator surface narrowing (Wave 2)
```
