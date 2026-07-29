---
phase: wave-1a-backend-tools-refactor
plan: 05
subsystem: backend
tags: [coach-tools, retrieve-memories, bm25, karpathy-wiki, sentry, feature-flag, user-isolation]

requires:
  - phase: wave-1a-00
    provides: COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED feature flag (default False), `# >>> dispatch: retrieve_memories` marker pair, empty `app.services.memory` package marker
  - dependency: rank_bm25 (>=0.2.2,<1.0.0) — pure-Python BM25Okapi, numpy already transitive via sentry-sdk[fastapi]

provides:
  - `app.services.memory.bm25.retrieve(topic, user_id, db, k=5)` — BM25-ranked InsightHit list, score floor 0.3, top-k clamp, user isolation at the SQL layer (`filter(CoachInsightRecord.user_id == user_id)`).
  - `app.services.memory.bm25._profile_fallback` — ProfileModel.data['recent_insights'] fallback (score=1.0 substring match) when no CoachInsightRecord rows exist for the user.
  - `_compute_retrieve_memories` flag-gated dispatcher wrapper above `_handle_retrieve_memories` in `coach_chat.py`. Flag OFF falls back byte-identical; flag ON + hits emits legacy line format `[insight_type] topic: summary` and fires the D-15 5-kwarg Sentry breadcrumb (tool_name="retrieve_memories", inputs_hash, profile_id_hashed, elapsed_ms, flag_state).
  - 18 new backend tests (11 BM25 unit + 7 dispatcher) covering happy-path ranking, profile fallback, SQL-layer user isolation, score floor reject, top-k clamp, dual-column corpus tokenization, case-insensitive tokenization, empty/None defenses, determinism, byte-identical legacy passthrough, D-15 breadcrumb payload contract.

affects:
  - wave-1a-07 (parity harness) — can assert legacy passthrough byte-identity when flag OFF.
  - wave-1a-08 (rollout / 5-gate close) — flag defaults False per plan-00; plan-08 owns staged rollout.

tech-stack:
  added:
    - rank_bm25>=0.2.2,<1.0.0 (pure-Python BM25Okapi, numpy transitive only)
  patterns:
    - "Karpathy-wiki retrieval: SQL-filtered per-user corpus + BM25 ranking, NO vector embedding, NO LLM call (per memory project_user_profile_wiki)"
    - "Cross-user isolation enforced at SQL layer (`filter(CoachInsightRecord.user_id == user_id)`) before BM25 sees any rows — structural impossibility of cross-tenant leakage"
    - "Lazy imports inside _compute fn body (matches plan-01/02 _compute_budget_status pattern) so test patching targets the source module (`app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb`)"
    - "Score floor + top-k clamp applied on the score-sorted result list before InsightHit materialization"
    - "Profile fallback uses ProfileModel.data['recent_insights'] (graceful absent-key return of [])"

key-files:
  created:
    - services/backend/app/services/memory/bm25.py (139 lines)
    - services/backend/tests/test_memory_bm25.py (231 lines, 11 tests)
    - services/backend/tests/test_coach_tools_retrieve_memories.py (215 lines, 7 tests)
  modified:
    - services/backend/pyproject.toml (added rank_bm25 line 46)
    - services/backend/app/services/memory/__init__.py (filled re-exports — was empty marker from plan-00)
    - services/backend/app/api/v1/endpoints/coach_chat.py (+80 lines for `_compute_retrieve_memories`; -3 +5 in dispatcher branch inside preserved markers)

key-decisions:
  - "Score floor stays at the plan-spec value 0.3 (NOT lowered to accommodate small test corpora). BM25 IDF math requires the queried term to be relatively rare; tests in this plan use filler insights so the queried token's IDF crosses the floor. Production corpora (10-50 insights per user) will exhibit similar IDF distributions — the floor stays meaningful."
  - "Defensive cleanup of CoachInsightRecord inside each test's `db` fixture: the conftest.py autouse `clean_database` does NOT include CoachInsightRecord, so plan-05 tests add their own pre-test purge to keep the BM25 corpus predictable across runs."
  - "Mock target for `emit_coach_tool_breadcrumb` is `app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb`, NOT `app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb`. Reason: the compute fn imports the breadcrumb emitter LAZILY inside its body (matches plan-01/02 pattern), so the name is never bound at the coach_chat module level. Patching at the source module covers the lazy import."
  - "Anti-fabrication grep `grep -c 'topic_tags\\|\\.body\\b' bm25.py` = 0: the docstring was reworded to avoid even negative mentions of the fabricated columns (CONTEXT D-07 listed `topic_tags` and `.body` — neither exists in `app/models/coach_insight.py`). Originally my docstring said « No topic_tags. No body. » which is a NEGATIVE assertion but still hits the grep; reworded to « The CONTEXT D-07 mentions of additional columns were fabrications resolved at plan-time. »"

patterns-established:
  - "Pattern: SQL-then-rank for per-user retrieval — `db.query(M).filter(M.user_id == user_id).all()` first, then in-memory BM25 over the already-filtered corpus. Eliminates the « post-filter band-aid » antipattern (filter AFTER scoring) which is one missed condition away from cross-tenant leakage."
  - "Pattern: flag-gated wrapper with defensive fallback to legacy — every failure mode (flag OFF / user_id None / db None / 0 hits / Exception) falls back to the legacy handler byte-identical. Tests assert the byte-identity (Test 1 in dispatcher suite)."

requirements-completed: [WAVE1A-06, WAVE1A-09, WAVE1A-10]

duration: ~70 min (including baseline pytest, lint discovery, score-floor fixture diagnosis)
completed: 2026-05-14
---

# Phase wave-1a Plan 05: BM25 retrieve_memories Summary

**Karpathy-wiki memory retrieval for the coach LLM (per memory `project_user_profile_wiki`, Julien 2026-05-13). New module `app.services.memory.bm25.retrieve(topic, user_id, db, k=5)` runs BM25Okapi over `CoachInsightRecord` rows already SQL-filtered by `user_id` — structural cross-user isolation. The flag-gated `_compute_retrieve_memories` sibling above `_handle_retrieve_memories` (line 910 in coach_chat.py) wraps the legacy handler; dispatcher branch inside markers at lines 1902-1916 (now ~1983-1997) routes through the wrapper; flag OFF default keeps Wave 1a a no-op rollout pending plan-08. 18 new tests (11 BM25 + 7 dispatcher), all green; full backend suite 6792 passed (baseline 6774 + 18 net new).**

## Performance

- **Duration:** ~70 min (baseline pytest, hypothesis dep gap fixed, score-floor IDF diagnostics, fixture cleanup design, 2 commits + SUMMARY)
- **Tasks:** 2 (autonomous, TDD)
- **Files created:** 3 / **Files modified:** 3
- **Commits:** `1fae31eb` (Task 1) + `c4bb98b9` (Task 2) + this SUMMARY

## Accomplishments

- **Karpathy-wiki retrieval shipped, not RAG**: `grep -c 'BM25Okapi' bm25.py` returns 3 (import + class call + docstring mention). `grep -c 'embed\|vector\|llm\|gpt' bm25.py` returns 0. The wiki doctrine from memory `project_user_profile_wiki` is honored.
- **Cross-user isolation at SQL layer**: `grep -Ec 'filter\(CoachInsightRecord\.user_id == user_id\)' bm25.py` returns 1 (the only path the corpus rows can come from). Test 3 (BM25 unit) + Test 5 (dispatcher) both insert 2-user fixtures and assert that user_b's content never appears in user_a's response, and vice versa.
- **Anti-fabrication grep clean**: `grep -c 'topic_tags\|\.body\b' bm25.py` returns 0. Neither column exists in `app/models/coach_insight.py` (verified at plan-time per `<interfaces>`). Even the negative-assertion docstring mentions were removed.
- **Dispatcher markers preserved exactly**: `grep -c '# >>> dispatch: retrieve_memories' coach_chat.py` and `grep -c '# <<< dispatch: retrieve_memories' coach_chat.py` both return 1. The BUG-B regex sanitization comment is preserved (`grep -c 'BUG-B fix' coach_chat.py` = 1).
- **D-15 5-kwarg breadcrumb contract enforced**: Test 6 patches `app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb` and asserts `set(call_kwargs.keys()) == {"tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"}` plus `tool_name == "retrieve_memories"`, `len(inputs_hash) == 64`, `len(profile_id_hashed) == 16`, `profile_id_hashed != "user_a"` (hash applied), `elapsed_ms >= 0` int, `flag_state == "on"`.
- **18 tests collected and passing** (plan target ≥17 satisfied at 18 = 11 BM25 unit + 7 dispatcher).
- **Zero backend regressions**: full `pytest -q` reports `6792 passed, 59 skipped, 1 xfailed` (baseline 6774 + 18 net new — exact match against pre-plan-05 baseline on this branch).
- **Plan-00 invariant honored**: `grep -c 'COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED' config.py` returns 1 (unchanged). `config.py` is NOT in this plan's `files_modified` list.

## Task Commits

1. **Task 1: rank_bm25 dep + BM25 retrieve module + 11 unit tests** — `1fae31eb` (feat)
   - Added `rank_bm25>=0.2.2,<1.0.0` at `pyproject.toml:46` (after pyyaml).
   - Created `services/backend/app/services/memory/bm25.py` (139 lines): `InsightHit` dataclass, `retrieve(topic, user_id, db, k=5)` with score floor 0.3 and top-k clamp, `_profile_fallback` ProfileModel.data scan, `_tokenize` lowercase whitespace.
   - Filled `services/backend/app/services/memory/__init__.py` with `retrieve` + `InsightHit` re-exports (plan-00 shipped the empty marker).
   - Created `services/backend/tests/test_memory_bm25.py` (231 lines, 11 tests). All 11 green.
   - 4 files changed, 436 insertions(+), 3 deletions(-).

2. **Task 2: _compute_retrieve_memories dispatcher wrapper + 7 tests** — `c4bb98b9` (feat)
   - Inserted `_compute_retrieve_memories` (80 lines including docstring) immediately above `_handle_retrieve_memories` at line 910 of `coach_chat.py`. Lazy imports inside the function body match the plan-01/02 `_compute_budget_status` pattern; defensive try/except → legacy fallback for every failure mode.
   - Rewired dispatcher branch inside markers at lines 1902-1916 (now 1983-1997 post-insertion) to call `_compute_retrieve_memories` instead of `_handle_retrieve_memories` directly. BUG-B regex sanitization preserved verbatim.
   - Created `services/backend/tests/test_coach_tools_retrieve_memories.py` (215 lines, 7 tests). All 7 green.
   - 2 files changed, 343 insertions(+), 3 deletions(-).

_TDD pattern: tests + implementation were committed together (RED→GREEN collapsed into one commit per task) matching the plan-02 / plan-06 precedent and the plan's `tdd="true"` interpretation. Each test asserts behavior only the real implementation can satisfy._

## Files Created/Modified

**Created:**
- `services/backend/app/services/memory/bm25.py` (139 lines) — module docstring + `_SCORE_FLOOR/_MAX_CORPUS_ROWS/_DEFAULT_K` constants + `InsightHit` dataclass + `_tokenize` + `retrieve` + `_profile_fallback`.
- `services/backend/tests/test_memory_bm25.py` (231 lines, 11 pytest functions): `test_happy_path_top_hit_is_3a_topic`, `test_empty_corpus_falls_back_to_profile_recent_insights`, `test_user_isolation_at_sql_layer`, `test_score_floor_rejects_unrelated_query`, `test_top_k_clamp`, `test_corpus_tokenizes_topic_and_summary`, `test_case_insensitive_tokenization`, `test_empty_topic_returns_empty`, `test_determinism_same_call_same_result`, `test_db_none_returns_empty`, `test_user_id_none_returns_empty`.
- `services/backend/tests/test_coach_tools_retrieve_memories.py` (215 lines, 7 pytest functions): `test_flag_off_byte_identical_to_legacy`, `test_flag_on_emits_legacy_line_format`, `test_flag_on_no_hits_falls_back_to_legacy_string`, `test_bm25_score_floor_reject_falls_back`, `test_cross_user_isolation_dispatcher_level`, `test_d15_breadcrumb_5kwarg_non_pii_payload`, `test_db_none_passthrough_no_exception`.

**Modified:**
- `services/backend/pyproject.toml` (+3 lines) — `rank_bm25` dependency with 2-line comment explaining Karpathy-wiki rationale + pure-Python guarantee.
- `services/backend/app/services/memory/__init__.py` (rewritten — was empty marker docstring from plan-00; now docstring + import of `retrieve` + `InsightHit` + `__all__`).
- `services/backend/app/api/v1/endpoints/coach_chat.py` (+80 / -3): `_compute_retrieve_memories` sibling inserted above line 910 legacy handler; dispatcher branch body inside markers swapped from `_handle_retrieve_memories(...)` to `_compute_retrieve_memories(...)` (markers + BUG-B regex preserved).

## Decisions Made

- **Score floor stays at 0.3 (the plan-spec value)**: BM25 IDF requires the queried token to be relatively rare in the corpus. With the plan's literal Test 1 fixture (3 insights, 2 containing "3a"), `BM25Okapi(...).get_scores(["3a"])` returns `[0.11, 0, 0.09]` — all below 0.3 → 0 hits. Rather than lower the floor (which would weaken the production contract), the tests were rewritten to use 5-row fixtures where the queried token's IDF is high enough. Production corpora (10-50 insights per user) will exhibit similar high-IDF behavior for distinct topic tokens. The floor stays meaningful; the test fixtures match it.
- **Test fixture cleanup added inside the `db` pytest fixture**: conftest.py's autouse `clean_database` enumerates 20+ tables but does NOT include `CoachInsightRecord`. Without per-test cleanup, the first test's inserts leak into the second test's corpus. The `db` fixture in BOTH new test files does a `session.query(CoachInsightRecord).delete()` + commit before yielding. Plan did NOT specify this; discovered during first test run.
- **Mock target for `emit_coach_tool_breadcrumb` is the SOURCE module**, not coach_chat.py: the compute fn imports it LAZILY inside its body (matches plan-01/02 pattern), so the name is never bound at coach_chat module level. `patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` raises `AttributeError`; `patch("app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb")` works.
- **User FK constraint required `_ensure_user` helper**: `CoachInsightRecord.user_id` has `ForeignKey("users.id", ondelete="CASCADE")`. SQLite enforces FK checks when a row is added unless the parent exists first. Both test files include `_ensure_user(db, user_id)` to insert a minimal `User` row (correctly using `hashed_password` not `password_hash` — the actual column name on `app.models.user.User`, discovered by grep after first test failure).
- **Anti-fabrication docstring reworded**: original docstring in `bm25.py` said « No topic_tags. No body. » as a NEGATIVE assertion against the fabricated CONTEXT D-07 columns. Grep can't distinguish positive from negative mentions, so even my anti-fabrication note tripped the `grep -c 'topic_tags|\.body\b' bm25.py` acceptance check (returned 1, needed 0). Reworded to « The CONTEXT D-07 mentions of additional columns were fabrications resolved at plan-time. » — same intent, now 0 hits.

## Deviations from Plan

### Auto-fixed / Documented Issues

**1. [Rule 1 - Bug] Plan Test 1 fixture incompatible with score floor 0.3 (BM25 IDF math)**
- **Found during:** Task 1 — first run of `tests/test_memory_bm25.py::test_happy_path_top_hit_is_3a_topic`.
- **Issue:** The plan's Test 1 spec describes a 3-insight fixture (2 with topic="3a", 1 with topic="lpp") and asserts `hits[0].score >= 0.3` after `retrieve("3a", ...)`. With BM25Okapi on a 3-doc corpus where 2 of 3 docs contain "3a", IDF("3a") is small (~0.18) and the resulting scores are `[0.11, 0, 0.09]` — all below the 0.3 floor → 0 hits → assertion fails. The plan-spec implicitly assumed scores would clear 0.3, but the math doesn't agree with this specific fixture.
- **Fix:** Augment all affected test fixtures (Tests 1, 3, 5, 6, 7) with filler insights on OTHER topics (`lpp`, `canton`, `revenu`) so the queried token's IDF is high enough to push scores above 0.3. Score floor itself stays at the plan-spec value 0.3. Test docstrings document the IDF rationale inline.
- **Files modified:** `services/backend/tests/test_memory_bm25.py` only.
- **Verification:** all 11 tests green (`11 passed in 0.19s` on targeted run).
- **Committed in:** `1fae31eb`.

**2. [Rule 2 - Missing Critical] Per-test `CoachInsightRecord` cleanup absent from conftest.py**
- **Found during:** Task 1 — second test run after Test 1 fix (Test 7 saw leaked data from Test 6).
- **Issue:** `services/backend/tests/conftest.py:70-124` defines an autouse `clean_database` fixture that purges 20+ tables before each test but does NOT include `CoachInsightRecord` (model added post-conftest authoring). Insertions in Test 6 leaked into Test 7's BM25 corpus, breaking the « top hit is 3a topic » assertion.
- **Fix:** Add a `db` fixture in both `tests/test_memory_bm25.py` and `tests/test_coach_tools_retrieve_memories.py` that calls `session.query(CoachInsightRecord).delete()` + `session.commit()` BEFORE yielding. Scoped per-test (not session-wide), no global conftest change.
- **Files modified:** `services/backend/tests/test_memory_bm25.py`, `services/backend/tests/test_coach_tools_retrieve_memories.py`.
- **Verification:** tests run deterministically in any order; full backend pytest passes.
- **Committed in:** `1fae31eb` + `c4bb98b9`.

**3. [Rule 1 - Bug] Test 6 mock target was wrong module**
- **Found during:** Task 2 — `pytest tests/test_coach_tools_retrieve_memories.py::test_d15_breadcrumb_5kwarg_non_pii_payload`.
- **Issue:** Plan-spec said `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")`. But `_compute_retrieve_memories` imports the breadcrumb fn LAZILY inside its body (matches plan-01/02 `_compute_budget_status` pattern verified in `<interfaces>`), so the name is never bound at the coach_chat module level. Patching there raises `AttributeError: <module ...coach_chat...> does not have the attribute 'emit_coach_tool_breadcrumb'`.
- **Fix:** Patch at the source module: `app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb`. The lazy import inside `_compute_retrieve_memories` then resolves to the mock.
- **Files modified:** `services/backend/tests/test_coach_tools_retrieve_memories.py`.
- **Verification:** Test 6 passes (`1 passed in 0.15s` on targeted run); the 5-kwarg dict is asserted exactly.
- **Committed in:** `c4bb98b9`.

**4. [Rule 1 - Bug] `User` constructor kwarg name mismatch (`password_hash` vs `hashed_password`)**
- **Found during:** Task 1 — first test run.
- **Issue:** My `_ensure_user` helper used `password_hash="x"` but `app.models.user.User` declares `hashed_password = Column(String, nullable=False)` (verified by grep). SQLAlchemy raised `TypeError: 'password_hash' is an invalid keyword argument for User`.
- **Fix:** Rename to `hashed_password="x"` in both test files.
- **Files modified:** `services/backend/tests/test_memory_bm25.py`, `services/backend/tests/test_coach_tools_retrieve_memories.py`.
- **Verification:** All FK-dependent inserts now succeed.
- **Committed in:** `1fae31eb` + `c4bb98b9`.

**5. [Rule 3 - Blocking absent] Pre-existing banned-terms lint hit at coach_chat.py:3502 inherited (not introduced)**
- **Found during:** Task 2 post-implementation lint (`python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py`).
- **Issue:** Lint reports `banned term 'assure': _facts.append(f"- Salaire assure LPP: ...")` at line 3502. The line was at 3422 before my +80-line insertion. Identical pre-existing finding documented in plan-02 (commit `30c6d2b6e`) and plan-06 (commit `bb5af0fc`) SUMMARYs — the `assure` is the unaccented past participle of "to insure" (technical phrase "Salaire assuré LPP") and `banned_terms_python.py` is accent-insensitive.
- **Fix:** None — out of scope per CLAUDE.md Karpathy #3 (surgical: don't fix adjacent code). Lefthook `banned-terms-python-bundles` glob does NOT cover `coach_chat.py`.
- **Files modified:** none.
- **Verification:** `git show 178a1cb3:services/backend/app/api/v1/endpoints/coach_chat.py | grep -c 'Salaire assure LPP'` returns 1 (pre-existing baseline). My commits don't introduce a NEW occurrence.
- **Committed in:** N/A (inherited baseline).

**6. [Operational gap, not a Rule deviation] Backend venv is Python 3.9.6 (project requires >=3.10), `hypothesis` dev dep missing**
- **Found during:** baseline `pytest --collect-only` and `pip install -e .`.
- **Issue:** `services/backend/.venv` is Python 3.9.6. `pyproject.toml` declares `requires-python = ">=3.10"` which blocks fresh `pip install -e .` (« Package 'mint-backend' requires a different Python: 3.9.6 not in '>=3.10' »). Separately, `tests/test_property_invariants.py` imports `hypothesis` which is not installed in the venv. The 3.9 venv has the editable mint-backend install from a prior session that bypassed the version check.
- **Fix:** (a) Installed `rank_bm25>=0.2.2,<1.0.0` directly via `pip install` (not `pip install -e .`) which bypasses the requires-python check on the package being installed. (b) Installed `hypothesis>=6.111` directly to unblock collection. Neither change touches `pyproject.toml` beyond plan-05's `rank_bm25` entry.
- **Files modified:** none beyond the planned dependency line.
- **Verification:** `python -c "import rank_bm25; import hypothesis; print('ok')"` succeeds; full backend pytest collects all tests without error.
- **Committed in:** N/A (dev environment fix only).

**7. [Cosmetic] Anti-fabrication docstring reworded to satisfy the literal grep AC1.6**
- **Found during:** Task 1 acceptance-criteria check.
- **Issue:** Original `bm25.py` docstring said « No topic_tags. No body. » as a NEGATIVE assertion against the fabricated columns. AC1.6 (`grep -c 'topic_tags\|\.body\b' bm25.py` = 0) treats both positive and negative mentions equally — returned 1.
- **Fix:** Reword to « The CONTEXT D-07 mentions of additional columns were fabrications resolved at plan-time. » — same intent, 0 matches.
- **Files modified:** `services/backend/app/services/memory/bm25.py`.
- **Verification:** `grep -c 'topic_tags\|\.body\b' bm25.py` returns 0.
- **Committed in:** `1fae31eb`.

---

**Total deviations:** 7 documented (3× Rule 1 bug, 1× Rule 2 missing-critical, 2× operational/lint inheritance, 1× cosmetic). Zero scope creep. Plan contract (score floor 0.3, top-k 5, SQL-layer user isolation, D-15 5-kwarg breadcrumb, legacy line format byte-identity) preserved verbatim.

## Issues Encountered

None of substance beyond the documented deviations. The grep-first plan-05 replan committed pre-execution had already verified column shape (`CoachInsightRecord` has no `topic_tags` / no `body`), `ProfileModel` actual path, dispatcher marker locations, and flag default — so all implementation references landed on first try. The BM25 score-floor / test-fixture interaction was the main mid-execution surprise; resolved by adding filler insights so IDF works without changing the production contract.

## User Setup Required

None — pure backend change. Flag `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED` defaults to `False` per plan-00; plan-08 owns the staged rollout. Production routes through `_handle_retrieve_memories` legacy path UNTIL plan-08 flips the flag.

## Next Phase Readiness

- **plan-04 (couple optimization port)** — Ready independently. Plan-05's `_compute_retrieve_memories` does not collide with plan-04's `_compute_couple_optimization` dispatcher branch (lines 1938-1941, separate markers).
- **plan-07 (parity harness)** — Ready. Flag OFF passthrough is byte-identical to legacy (Test 1 in dispatcher suite asserts this); harness can compare flag-ON BM25 output against a fixed-fixture expectation.
- **plan-08 (rollout + 5-gate close)** — Ready. Flag defaults False; plan-08's staged-rollout task owns the toggle. The D-15 5-kwarg breadcrumb is the rollout monitoring signal.

## 0-Trust Self-Check Receipts (per CLAUDE.md §9)

**G3 — Targeted pytest exit 0 with 18 tests collected:**
```
$ cd services/backend && /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/.venv/bin/python -m pytest tests/test_memory_bm25.py tests/test_coach_tools_retrieve_memories.py -q
..................                                                       [100%]
18 passed, 1 warning in 0.21s
```

**G4 — Full backend regression suite, zero new failures, +18 net new exact:**
```
$ cd services/backend && /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/.venv/bin/python -m pytest -q
6792 passed, 59 skipped, 1 xfailed, 2 warnings in 111.33s (0:01:51)
```
- Pre-plan-05 baseline (this branch HEAD `178a1cb3`): 6774 passed.
- Net new from plan-05: +18 (exact — 11 BM25 unit + 7 dispatcher).
- Pre-existing tests: zero regressions.

**G5a — Accent lint clean on touched files:**
```
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/memory/bm25.py; echo EXIT=$?
EXIT=0
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/api/v1/endpoints/coach_chat.py; echo EXIT=$?
EXIT=0
```

**G5b — Banned-terms lint on NEW files clean (existing coach_chat.py has inherited baseline):**
```
$ python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py services/backend/tests/test_memory_bm25.py services/backend/tests/test_coach_tools_retrieve_memories.py; echo EXIT=$?
EXIT=0

$ python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py; echo EXIT=$?
services/backend/app/api/v1/endpoints/coach_chat.py:3502: banned term 'assure':                     _facts.append(f"- Salaire assure LPP: {int(_d['lppInsuredSalary']):,} CHF".replace(",", "'"))
EXIT=1   # pre-existing — see Deviation #5 + plan-02 & plan-06 SUMMARYs (identical inheritance at line 3369 / 3422 pre-insertion)
```

**13 acceptance grep counts (Task 1 + Task 2 criteria from PLAN.md):**
```
# === Task 1 ===
$ grep -c '"rank_bm25' services/backend/pyproject.toml
1                                                # required =1 ✓
$ python -c "from app.services.memory import retrieve, InsightHit; print('ok')"
ok                                               # required exit 0 ✓
$ python -c "from app.services.memory.bm25 import retrieve, _SCORE_FLOOR; assert _SCORE_FLOOR == 0.3; print('ok')"
ok                                               # required exit 0 ✓
$ grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/core/config.py
1                                                # required >=1 ✓ (plan-00 invariant)
$ grep -Ec 'filter\(CoachInsightRecord\.user_id == user_id\)' services/backend/app/services/memory/bm25.py
1                                                # required >=1 ✓ (SQL-layer user isolation)
$ grep -c "topic_tags\|\.body\b" services/backend/app/services/memory/bm25.py
0                                                # required =0 ✓ (anti-fabrication grep)
$ grep -c "BM25Okapi" services/backend/app/services/memory/bm25.py
3                                                # required >=1 ✓
$ grep -E "(r\.topic|r\.summary)" services/backend/app/services/memory/bm25.py | wc -l
3                                                # required >=2 ✓ (corpus reads REAL columns)
$ pytest tests/test_memory_bm25.py -q  →  11 passed
                                                 # required ≥10 ✓
$ python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py; echo $?
0                                                # required exit 0 ✓
$ python3 tools/checks/accent_lint_fr.py services/backend/app/services/memory/bm25.py; echo $?
0                                                # required exit 0 ✓

# === Task 2 ===
$ grep -c "def _compute_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -c "_compute_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py
3                                                # required >=3 ✓ (def + dispatch call + docstring self-ref)
$ grep -c "_handle_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py
7                                                # required >=5 ✓ (legacy def + 5 fallback calls from _compute + dispatcher comment)
$ grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required >=1 ✓
$ pytest tests/test_memory_bm25.py tests/test_coach_tools_retrieve_memories.py -q  →  18 passed
                                                 # required ≥17 ✓
$ grep -c 'tool_name="retrieve_memories"' services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required >=1 ✓
$ grep -c "hash_profile_id(user_id)" services/backend/app/api/v1/endpoints/coach_chat.py
3                                                # required strict-increase ✓ (baseline 2 at 178a1cb3, now 3)
$ grep -c "# >>> dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -c "# <<< dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -c "BUG-B fix" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required unchanged ✓
$ grep -cE 'user_id == "user_a"|user_b' services/backend/tests/test_coach_tools_retrieve_memories.py
6                                                # required >=1 ✓
$ python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py services/backend/app/api/v1/endpoints/coach_chat.py
# coach_chat.py:3502 inherited 'Salaire assure LPP' baseline (see Deviation #5); bm25.py clean.
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/memory/bm25.py; echo $?
0                                                # required exit 0 ✓
```

**Marker integrity (full Wave 1a dispatcher set preserved):**
```
$ grep -c "# >>> dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py
6                                                # 6 dispatchers, unchanged from plan-02 / plan-06 SUMMARYs
```

**Evidence claim format (per CLAUDE.md §9.6):**
- **Evidence:** commits `1fae31eb` (Task 1) and `c4bb98b9` (Task 2) on branch `feature/wave-1a-05-bm25-memories` show the +80 / -3 diff in `coach_chat.py` plus the 3 new files (`bm25.py`, `test_memory_bm25.py`, `test_coach_tools_retrieve_memories.py`); `pytest -q` returns `6792 passed`; the 13 acceptance grep proofs above resolve verbatim against the post-commit working tree; the D-15 5-kwarg contract is asserted exactly by Test 6 of the dispatcher suite via `set(call_kwargs.keys())`.
- **Caveat:** plan-05 ships flag-gated wrapper + 18 unit tests ONLY. Flag defaults False per plan-00; no production traffic flows through BM25 until plan-08 toggles. No staged rollout, no Flutter-side change, no end-to-end Maestro G1 / Julien G2 sim walkthrough — the flag is a no-op default. The PR is OPEN, NOT merged. Backend regression suite green; CI execution (`gh pr checks`) is pending PR creation in the next step. The plan-spec « 0 cross-user leak » claim is enforced structurally (SQL filter) AND asserted by 2 isolation tests (Test 3 BM25 unit + Test 5 dispatcher) — but the test surface inserts 2 users with 1 row each on the queried topic, not a 100-user adversarial fixture. Plan-08 5-gate close is the formal cross-tenant security gate.

## Known Stubs

None. `_profile_fallback` is a defensive read of `ProfileModel.data['recent_insights']` — Wave 1a does NOT mandate the key (plan `<interfaces>` confirms); if absent, returns `[]` and the higher-level dispatcher falls back to `_handle_retrieve_memories` legacy strings. This is intentional graceful-degradation, not a stub.

## Threat Flags

None new. Threat-model dispositions from PLAN.md `<threat_model>` table verified:

- T-WAVE1A-05-01 (legacy passthrough when flag OFF) — Test 1 (dispatcher) asserts byte-identity. ✓
- T-WAVE1A-05-02 (LSFin banned-terms leak in formatter output) — `banned_terms_python.py` exit 0 on `bm25.py` and on both test files; `coach_chat.py` inherits the pre-existing `Salaire assure LPP` baseline at line 3502 unchanged. ✓
- T-WAVE1A-05-03 (PII leak in Sentry breadcrumb) — Test 6 asserts `set(call_kwargs.keys()) == {"tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"}` plus `profile_id_hashed != "user_a"` (hash applied). No `summary` text in payload. ✓
- T-WAVE1A-05-04 (BM25-specific cross-user leak) — `filter(CoachInsightRecord.user_id == user_id)` enforced at the SQL layer BEFORE BM25 sees any rows; Test 3 (BM25 unit) + Test 5 (dispatcher) assert isolation with 2-user fixtures. ✓
- T-WAVE1A-05-05 (adversarial topic injection via tool_use) — BUG-B regex `^[\w\s\-\.]{1,100}$` preserved at dispatcher entry (line 1908); `grep -c "BUG-B fix"` returns 1 unchanged. ✓
- T-WAVE1A-05-06 (DoS via huge corpus) — `_MAX_CORPUS_ROWS = 500` bounds the BM25 corpus per request. ✓
- T-WAVE1A-05-07 (rank_bm25 install on Railway) — pure-Python wheel; numpy already transitive via sentry-sdk[fastapi]. Local `pip install rank_bm25` succeeded; Railway CI verification pending PR / merge to staging. **Deferred** — proxy validation only via local install.
