---
phase: wave-1a-backend-tools-refactor
plan: 01
subsystem: backend-coach-tools
tags: [pydantic-v2, fastapi, coach, lsfin, inputs-hash, server-side-recompute, dispatcher]

requires:
  - phase: wave-1a-00
    provides: COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED flag, app/models/coach_tools/ package marker, emit_coach_tool_breadcrumb helper, hash_profile_id helper, 6 dispatcher marker pairs in coach_chat.py
provides:
  - "_compute_budget_status(user_id, ctx, db) — flag-gated server-side path for get_budget_status tool with newest-profile-wins ProfileModel lookup + Decimal(0.01) quantization + SHA-256 inputs_hash + D-15 Sentry breadcrumb + defensive try/except fallback to legacy formatter"
  - "BudgetSnapshot dataclass + CoachingEngine.compute_budget_snapshot(profile_data) static method on app/services/coaching_engine.py"
  - "BudgetSnapshotResponse Pydantic v2 model (frozen, alias_generator=to_camel) at app/models/coach_tools/budget_snapshot.py — camelCase JSON serialization with inputs_hash strict 64-char Field"
  - "11 unit tests at tests/test_coach_tools_budget_snapshot.py covering compute happy path + missing-both ValueError + camelCase serialization + inputs_hash length validation + settings flag default + dispatcher flag OFF byte-identity + dispatcher flag ON JSON + 3 fallback paths + parity smoke + deterministic inputs_hash"
affects: [wave-1a-02, wave-1a-03, wave-1a-04, wave-1a-05, wave-1a-06, wave-1a-07, wave-1a-08, wave-1b, wave-1c]

tech-stack:
  added: []
  patterns:
    - "Per-tool _compute_<name>(user_id, ctx, db) sibling next to legacy _format_<name>(ctx) — flag-gated, defensive fallback, D-08 dispatcher placement"
    - "ProfileModel newest-wins lookup: filter(user_id == ...).order_by(updated_at.desc()).first() — canonical pattern for plans 02-05"
    - "Flat-file test naming tests/test_coach_tools_<feature>.py (matches sibling test_coach_tools_categories.py / test_coach_tools_scaffolding.py — avoids collision with pre-existing tests/test_coach_tools.py module)"

key-files:
  created:
    - services/backend/app/models/coach_tools/budget_snapshot.py
    - services/backend/tests/test_coach_tools_budget_snapshot.py
  modified:
    - services/backend/app/services/coaching_engine.py
    - services/backend/app/api/v1/endpoints/coach_chat.py

key-decisions:
  - "Rule 3 deviation: flat-file test naming (tests/test_coach_tools_budget_snapshot.py) instead of subdirectory tests/test_coach_tools/test_budget_snapshot.py — pre-existing tests/test_coach_tools.py (Apr 2025) collides at pytest module collection. Plans 02-06 should adopt the same convention."
  - "compute_budget_snapshot accepts profile_data dict directly (no dict copy) — preserves MutableDict reference, zero copy overhead"
  - "Decimal quantization to 0.01 via ROUND_HALF_UP mirrors inputs_hash._quantize_floats convention — guarantees Python<->Dart parity at the hash layer"
  - "Defensive try/except Exception (not bare except ValueError) — DB flake, Pydantic validation error, Sentry SDK absence all fail-open to legacy formatter with logger.warning"

patterns-established:
  - "Pattern A — Per-tool dispatcher: _compute_<name> reads settings flag first, falls back to legacy _format_<name>(ctx) on flag OFF / missing user_id / db None / empty profile / ValueError / ANY Exception"
  - "Pattern B — D-15 uniform Sentry payload: tool_name + inputs_hash + profile_id_hashed + elapsed_ms + flag_state via emit_coach_tool_breadcrumb helper (NEVER ad-hoc sentry_sdk.add_breadcrumb)"
  - "Pattern C — Inline test mock for SQLAlchemy chain: _make_mock_db(profile_data) builds mock_db.query().filter().order_by().first() returning a ProfileModel-shaped MagicMock"

requirements-completed: [WAVE1A-01, WAVE1A-09, WAVE1A-10]

duration: 30min
completed: 2026-05-14
---

# Wave 1a Plan 01: get_budget_status Server-Side Recompute — Summary

**Server-side BudgetSnapshot recompute for `get_budget_status` coach tool with Pydantic v2 camelCase response + SHA-256 inputs_hash + flag-gated rollback to legacy formatter, all behind COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED (default False).**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-05-14 (post panel-fix commit e2b78fa4)
- **Completed:** 2026-05-14
- **Tasks:** 2
- **Files modified:** 4 (1 service + 1 model + 1 endpoint + 1 test, plus delete of pre-staged collision dir)
- **Net new tests:** +11 (full backend pytest 6736 → 6747, zero regressions)

## Accomplishments

- **Task 1:** `BudgetSnapshot` dataclass + `CoachingEngine.compute_budget_snapshot()` static method (Wave 1a D-02), `BudgetSnapshotResponse` Pydantic v2 model with camelCase aliases (D-03), 5 unit tests green covering happy path, ValueError fallback contract, camelCase serialization, inputs_hash length validation, and settings flag default.
- **Task 2:** `_compute_budget_status(user_id, ctx, db)` sibling function in coach_chat.py with full defensive fallback chain (flag OFF / missing user_id / db None / no ProfileModel row / profile.data empty / ValueError / ANY Exception → legacy formatter). Dispatcher branch inside the get_budget_status marker pair re-wired (markers preserved verbatim: 1/1 open/close for budget, 6/6 for all 6 sibling tools — zero collateral damage). 6 additional dispatcher/parity tests green.

## Task Commits

1. **Task 1: BudgetSnapshot + Pydantic v2 response + 5 unit tests** — `83221851` (feat)
2. **Task 2: _compute_budget_status dispatcher + 6 tests + flat-file rename** — `6aaccb5f` (feat)

## Files Created/Modified

- `services/backend/app/services/coaching_engine.py` — add Decimal/ROUND_HALF_UP imports + `BudgetSnapshot` dataclass + `CoachingEngine.compute_budget_snapshot()` static method (D-02 server-side recompute).
- `services/backend/app/models/coach_tools/budget_snapshot.py` — new `BudgetSnapshotResponse` Pydantic v2 model with frozen=True + alias_generator=to_camel + populate_by_name=True; inputs_hash strict 64-char Field (D-03).
- `services/backend/app/api/v1/endpoints/coach_chat.py` — insert `_compute_budget_status(user_id, ctx, db)` ABOVE `_format_budget_status`; replace dispatcher branch inside `# >>> dispatch: get_budget_status` markers to route through new function; append registry comment listing implementations landed.
- `services/backend/tests/test_coach_tools_budget_snapshot.py` — 11 unit tests (5 Task-1 + 6 Task-2) using monkeypatch on `settings` + MagicMock SQLAlchemy chain.

## Decisions Made

1. **Flat-file test naming** to resolve collision (Rule 3 below). Plans 02-06 should adopt the same `tests/test_coach_tools_<feature>.py` pattern.
2. **Pass `profile.data` directly** to `compute_budget_snapshot` (no `dict(...)` copy) — preserves MutableDict reference, zero copy overhead, mirrors how compute consumers should treat ORM JSON payloads (per panel decision in plan).
3. **Defensive `except Exception`** not bare `except ValueError` — covers DB flake (operational error), Pydantic v2 validation error, Sentry SDK absence, breadcrumb emit error. Always fails open to legacy formatter with `logger.warning` for ops visibility.
4. **D-15 elapsed_ms** measured from BEFORE the import block to capture cold-import latency (first call into `app.models.coach_tools.budget_snapshot`).
5. **Mock SQLAlchemy chain in tests** instead of using real SQLite session — keeps unit tests fast (0.23s for 11 tests) and avoids needing a DB fixture for behavior assertions on the dispatcher.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved pre-existing collision `tests/test_coach_tools.py` vs `tests/test_coach_tools/` directory**
- **Found during:** Task 2 verification (`pytest tests/ -q` collection failure: `import file mismatch — imported module 'tests.test_coach_tools' has this __file__ attribute: tests/test_coach_tools/` vs `tests/test_coach_tools.py`).
- **Issue:** Plan asked for `tests/test_coach_tools/test_budget_snapshot.py`. A pre-existing `tests/test_coach_tools.py` (Sprint S56+, 16KB, since 2025-04) collided at pytest module collection. The plan-00 SUMMARY explicitly documented this for plans 01-08 to resolve.
- **Fix:** Renamed `tests/test_coach_tools/test_budget_snapshot.py` → `tests/test_coach_tools_budget_snapshot.py` (flat file). Matches the existing sibling convention `test_coach_tools_categories.py` + `test_coach_tools_scaffolding.py`. Removed the empty `__init__.py` and pruned the directory.
- **Files modified:** `services/backend/tests/test_coach_tools_budget_snapshot.py` (renamed from subdir).
- **Verification:** `pytest tests/test_coach_tools_budget_snapshot.py -q` → 11 passed in 0.23s; full `pytest tests/ -q` → 6747 passed, zero regressions.
- **Committed in:** `6aaccb5f` (Task 2 commit, as `R` rename).

**2. [Rule 1 - Bug] Plan acceptance criterion required `grep -c "_compute_budget_status" coach_chat.py ≥ 3` but my initial edit produced 2 (def + dispatcher call only).**
- **Found during:** Task 2 acceptance grep audit.
- **Issue:** The plan's acceptance criterion lists "at least one comment/import" reference as part of the count-≥3 expectation; my surgical edit didn't include a third reference.
- **Fix:** Appended a one-line entry to the existing `# === Wave 1a server-side compute dispatchers ===` registry comment block: `#   - _compute_budget_status  (plan wave-1a-01)`. This is a deliberate registry comment for future plans 02-06 to mirror — gives a single visible place to enumerate implementations landed.
- **Files modified:** `services/backend/app/api/v1/endpoints/coach_chat.py`.
- **Verification:** `grep -c "_compute_budget_status" coach_chat.py` → 3.
- **Committed in:** `6aaccb5f` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking, 1 Rule 1 minor traceability adjustment).
**Impact on plan:** Both fixes within plan latitude. The Rule 3 fix establishes a pattern that plans 02-06 should adopt, removing the collision risk for all sibling plans. Zero scope creep.

## Issues Encountered

### Lint exit codes — `banned_terms_python.py` exits 1 on touched files due to PRE-EXISTING violations in untouched lines

- Run: `python3 tools/checks/banned_terms_python.py services/backend/app/services/coaching_engine.py services/backend/app/models/coach_tools/budget_snapshot.py services/backend/app/api/v1/endpoints/coach_chat.py`
- Output (4 hits, ALL pre-existing — verified via `git stash` baseline):
  - `coaching_engine.py:20` — `# NEVER use "garanti", "assure", "certain"` (docstring listing banned terms negatively)
  - `coaching_engine.py:100` — `language. No banned terms ("garanti", "assure", "certain").` (class docstring, same pattern)
  - `coaching_engine.py:760` — `f"Cela peut reduire significativement votre salaire assure "` (pre-existing `salaire assure` — missing accent on `assuré`, code I did not touch)
  - `coach_chat.py:3190` — `f"- Salaire assure LPP: {int(_d['lppInsuredSalary']):,} CHF"` (pre-existing, line I did not touch)
- Baseline `git stash` lint exit code: **1** (identical to current state). My code introduces **zero** new banned-term hits.
- Per Karpathy #3 surgical: out-of-scope to fix here. Plan-00 SUMMARY also noted line 3190 as informational. Logged for a follow-up `chore(lint)` plan or as part of the Wave 1a-08 5-gate close-out.

### Accent lint — clean on touched files

- Run: `python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coaching_engine.py` → exit 0
- Run: `python3 tools/checks/accent_lint_fr.py --file services/backend/app/models/coach_tools/budget_snapshot.py` → exit 0
- Plan acceptance criteria listed positional-args invocation; the tool uses `--file`. Used the correct invocation (per `argparse` `usage:`).

## User Setup Required

None — backend-only change, flag default OFF on prod, no Railway env-var changes needed for this plan. Wave 1c will toggle `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true` on Railway staging when validation pack is ready.

## Next Phase Readiness

- Plan 02 (`get_retirement_projection`) can land in parallel: same dispatcher pattern, same test naming (`tests/test_coach_tools_retirement_projection.py`), same flag-gated fallback shape.
- Plans 03-06 follow identical scaffolding pattern.
- Wave 1c parity-test suite (Plan 07) will consume `BudgetSnapshotResponse.inputs_hash` for `source_kind="tool_call_id"` citation registry entries (Wave 1b).
- The pre-existing banned-terms hits in `coaching_engine.py:760` + `coach_chat.py:3190` should be cleaned in a separate `chore(lint)` PR before Wave 1a-08 final 5-gate close.

## Self-Check

### Files exist
- `FOUND` — `services/backend/app/services/coaching_engine.py` (modified)
- `FOUND` — `services/backend/app/models/coach_tools/budget_snapshot.py` (new, 24 lines)
- `FOUND` — `services/backend/app/api/v1/endpoints/coach_chat.py` (modified)
- `FOUND` — `services/backend/tests/test_coach_tools_budget_snapshot.py` (new, 11 tests)

### Commits exist
- `FOUND` — `83221851` (`feat(wave-1a-01): task 1 — BudgetSnapshot + Pydantic v2 response + 5 unit tests`)
- `FOUND` — `6aaccb5f` (`feat(wave-1a-01): task 2 — _compute_budget_status dispatcher + 6 tests + flat-file rename`)

### Acceptance criteria evidence (cited verbatim)

Task 1:
- `python3 -c "from app.services.coaching_engine import CoachingEngine, BudgetSnapshot; print('ok')"` → `ok` (exit 0)
- `python3 -c "from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse; print('ok')"` → `ok` (exit 0)
- `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED" services/backend/app/core/config.py` → 1 (pre-existed from plan-00)
- `grep -c "def compute_budget_snapshot" services/backend/app/services/coaching_engine.py` → 1
- `grep -c "alias_generator=to_camel" services/backend/app/models/coach_tools/budget_snapshot.py` → 1
- `pytest tests/test_coach_tools_budget_snapshot.py -k "compute_budget_snapshot or response or flag_default" -q` → 5 passed in 0.24s
- `grep -E "monthlyIncome|monthlyExpenses|monthsLiquidity" tests/test_coach_tools_budget_snapshot.py | wc -l` → 6

Task 2:
- `grep -c "_compute_budget_status" coach_chat.py` → 3 (def + dispatcher call + registry comment)
- `grep -c "emit_coach_tool_breadcrumb(" coach_chat.py` → 1
- `grep -E "tool_name=\"budget_status\"" coach_chat.py | wc -l` → 1
- `grep -E "elapsed_ms\s*=\s*int\(" coach_chat.py | wc -l` → 1
- `grep -E "profile_id_hashed=hash_profile_id\(" coach_chat.py | wc -l` → 1
- `grep -E "flag_state=\"on\"" coach_chat.py | wc -l` → 1
- `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED" coach_chat.py` → 1
- `grep -c "_format_budget_status" coach_chat.py` → 6
- `grep -c "# >>> dispatch: get_budget_status" coach_chat.py` → 1 (marker preserved)
- `grep -c "# <<< dispatch: get_budget_status" coach_chat.py` → 1 (marker preserved)
- `grep -c "user_id=user_id" coach_chat.py` → 10 (this path + 9 pre-existing sibling sites)
- `grep -E "filter\(ProfileModel\.user_id == user_id\)" coach_chat.py | wc -l` → 2
- `grep -E "order_by\(ProfileModel\.updated_at\.desc\(\)\)" coach_chat.py | wc -l` → 2
- **CRITICAL marker integrity check**: `grep -c "# >>> dispatch: " coach_chat.py` → **6** (all 6 sibling markers intact, zero collateral damage)
- **CRITICAL marker integrity check**: `grep -c "# <<< dispatch: " coach_chat.py` → **6**

Full pytest baseline:
- `cd services/backend && python3 -m pytest tests/ -q` → `6747 passed, 62 skipped, 1 xfailed, 1 warning in 112.10s` (baseline 6736 → +11 net new, ZERO regressions; Phase 94 + 95 byte-identity preserved)

Plan-01 file count delta: +11 tests vs pre-task baseline ≥10 required → PASS.

### Self-Check: PASSED

All acceptance criteria pass with deterministic citations. The two deviations (Rule 3 flat-file rename + Rule 1 registry comment) are documented above with their files, fixes, and verification commands. No further verification is pending for this plan.

**Caveat (0-trust §9.6):** Tests exercise the dispatcher with mocked DB only. End-to-end behaviour with flag ON in staging is UNKNOWN — Wave 1c validation pack + G1 Maestro flow will exercise it. Production user value DELIVERED = NONE — flag stays OFF on prod per D-05 until Wave 1c.

---
*Phase: wave-1a-backend-tools-refactor*
*Plan: 01*
*Completed: 2026-05-14*
