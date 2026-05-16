---
phase: mint-calc-engine-v1
plan: 01
wave: 1
subsystem: api
tags: [fastapi, pydantic-v2, profile-grounding, coach-tool-response, lsfin, helper-module, tdd]

# Dependency graph
requires:
  - phase: wave-1c-A3-missing-fields-handshake
    provides: "CoachToolResponse envelope (CoachToolOk / CoachToolIncomplete / CoachToolPolicyBlocked) cherry-picked verbatim per D-CE-04"
provides:
  - "app.core.profile_resolver._resolve_defaults — body > profile > Pydantic default merge honoring body.model_fields_set (D-CE-07)"
  - "app.core.profile_resolver._required_profile_fields_missing — profile-key list (NOT body field names) capped at 3 (D-A3-01 envelope cap)"
  - "app.core.profile_resolver.raise_incomplete_as_422 — strict 422 with CoachToolIncomplete envelope; non-strict warning + body passthrough (D-CE-08)"
  - "app.core.profile_resolver.get_profile_filled — FastAPI dep returning authenticated user's most-recent profile.data (or {})"
  - "tests/conftest.py:client_with_blank_profile — Concern D Karpathy #4 reproduce-the-bug-first fixture"
  - "app.models.coach_tools.__init__.py exports the 4-class A3 envelope so W1 plans 02-06 + all W2-W4 can `from app.models.coach_tools import CoachToolIncomplete`"
affects: [mint-calc-engine-v1-02-w1-priority1-endpoints, mint-calc-engine-v1-03-w1-priority2-endpoints, mint-calc-engine-v1-04-w1-lucidity-payloads, mint-calc-engine-v1-05-w1-calc-registry, mint-calc-engine-v1-06-w1-sev2-batch-grounding, mint-calc-engine-v1-07-w2-tool-registry-adapter, mint-calc-engine-v1-10-w2-coach-tool-response-v2]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Schema marker = `Field(default=None, json_schema_extra={'from_profile': 'canonical_profile_key'})` for every request schema field that should grounding-merge from `_user.profile.data`"
    - "Module-level env-driven feature flag `PROFILE_GROUNDING_STRICT_MODE` re-evaluated at module-load + reload-on-monkeypatch test pattern via `importlib.reload`"
    - "Verbatim cherry-pick per D-CE-19 Fowler Parallel Change pattern — no rewrite of the A3 envelope, single source of truth"
    - "Concern D reproduce-the-bug-first fixture (`client_with_blank_profile`) used in each downstream contract test"
    - "Pollution-resistant test logger capture pattern — install a dedicated `logging.Handler` directly on the module logger rather than relying on caplog (root handlers can be cleared by upstream setup_logging)"

key-files:
  created:
    - "services/backend/app/core/profile_resolver.py (187 LOC, 4 functions + STRICT_MODE flag)"
    - "services/backend/app/models/coach_tools/_response.py (76 LOC, cherry-picked verbatim from A3 sha a55b5469)"
    - "services/backend/tests/test_profile_resolver.py (243 LOC, 10 unit tests)"
    - "services/backend/tests/test_get_profile_filled.py (133 LOC, 5 FastAPI integration tests)"
  modified:
    - "services/backend/app/models/coach_tools/__init__.py (export 4-class envelope)"
    - "services/backend/tests/conftest.py (append `client_with_blank_profile` fixture, 49 LOC)"
    - "services/backend/tests/test_coach_tools_scaffolding.py (update stale `__all__ == []` assertion to match A3 cherry-pick)"

key-decisions:
  - "Path B (cherry-pick) chosen for Task 0 — A3 PR #643 still OPEN against dev at execute-time (per A3 state in plan), not merged. Cherry-picked verbatim sha a55b5469 per D-CE-04 + D-CE-19."
  - "Switched HTTP_422_UNPROCESSABLE_ENTITY → HTTP_422_UNPROCESSABLE_CONTENT (Rule 1 auto-fix to clear upstream FastAPI DeprecationWarning, no semantic change)"
  - "Test logger capture uses dedicated `_RecordCollector` Handler attached directly to `pr._logger` instead of pytest caplog — root-handler clearing by `app.core.logging_config.setup_logging()` makes caplog brittle in full-suite ordering"

patterns-established:
  - "Pollution-resistant test logger capture : install custom Handler on the named module logger + force-reset `setLevel(WARNING)` / `disabled=False` / `propagate=True` to override any prior-test pollution of the stdlib process-global cached logger"
  - "Schema marker pattern : Pydantic v2 `Field(default=None, json_schema_extra={'from_profile': 'KEY'})` is the contract every downstream Wave-1 endpoint request schema MUST follow for `_resolve_defaults` to find the profile mapping"
  - "Envelope-cap enforcement at the model layer : `CoachToolIncomplete._cap_missing_fields` is the single point where the 3-cap applies — `raise_incomplete_as_422` does NOT pre-truncate, it builds the envelope and lets ValueError propagate if caller passes >3"

requirements-completed: [D-CE-04, D-CE-06, D-CE-07, D-CE-08, D-CE-19, D-CE-20]

# Metrics
duration: 35min
completed: 2026-05-16
---

# Phase mint-calc-engine-v1 Plan 01: W1 Shared Helpers Summary

**`_resolve_defaults` + `get_profile_filled` + `raise_incomplete_as_422` shipped at `services/backend/app/core/profile_resolver.py`; A3 `CoachToolResponse` envelope cherry-picked into dev; Concern D `client_with_blank_profile` fixture appended to `conftest.py`. Plans W1-02..W1-06 and all W2-W4 grounding work can now `from app.core.profile_resolver import _resolve_defaults, get_profile_filled, raise_incomplete_as_422` and `from app.models.coach_tools import CoachToolIncomplete`.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-16T13:55Z (approximate)
- **Completed:** 2026-05-16T14:20Z (approximate)
- **Tasks:** 5/5 (Tasks 0-4)
- **Files created:** 4
- **Files modified:** 3

## Accomplishments

- **A3 envelope unification (D-CE-04)** : the discriminated-union `CoachToolResponse` (RootModel[Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked]]) now lives on `dev`, cherry-picked verbatim per D-CE-19 Parallel Change. Single doctrine for REST 422 handshake + coach tool dispatcher.
- **Shared `_resolve_defaults` helper (D-CE-07)** : honors `body.model_fields_set` so explicit-None from the client is preserved (Test 1 — naive `if body.X is not None` would silently bypass profile grounding by omitting field, threat T-mint-calc-01-02 mitigated).
- **`raise_incomplete_as_422` feature-flag wired (D-CE-08)** : strict mode raises HTTPException(422) with CoachToolIncomplete envelope camelCase'd via `model_dump(by_alias=True)` ; non-strict mode emits WARNING log + returns resolved_body for graceful Flutter rollout. Default `false` = strict requires explicit opt-in.
- **`get_profile_filled` FastAPI dep (D-CE-06 PRIMARY enforcement layer)** : 1 indexed query per request (`user_id` + `updated_at DESC LIMIT 1`), filters on authenticated `user.id` (no cross-user access, threat T-mint-calc-01-06 mitigated).
- **Concern D fixture `client_with_blank_profile`** : reproduces the bug-first per Karpathy #4 — every W1-02..W1-06 contract test will use it to assert 422 fires on missing profile fields.

## Task Commits

Each task was committed atomically (TDD-style for Task 1 — RED then GREEN) :

| Task | Name | Commit | Type |
|------|------|--------|------|
| 0 | Cherry-pick A3 envelope + export from `__init__.py` | `36e20741` | cherry-pick |
| 1-RED | Failing tests for `profile_resolver` helpers | `8e8d9f41` | test |
| 1-GREEN | Implement `profile_resolver` shared helpers | `dd998654` | feat |
| 2 | `get_profile_filled` FastAPI integration tests | `d468e58d` | test |
| 3 | `client_with_blank_profile` pytest fixture | `fc4d0a8d` | test |
| 4 (Rule 1 inline) | Suite-order pollution fix + stale scaffolding assertion | `26c5b860` | fix |

Final metadata commit will follow this SUMMARY (per execute-plan protocol).

## Files Created/Modified

### Created
- `services/backend/app/core/profile_resolver.py` (187 LOC) — `_resolve_defaults`, `_required_profile_fields_missing`, `raise_incomplete_as_422`, `get_profile_filled`, `PROFILE_GROUNDING_STRICT_MODE` flag.
- `services/backend/app/models/coach_tools/_response.py` (76 LOC, cherry-picked from A3 sha `a55b5469` verbatim per D-CE-04).
- `services/backend/tests/test_profile_resolver.py` (243 LOC) — 10 unit tests covering precedence, cap=3 enforcement, strict/non-strict branching, env default.
- `services/backend/tests/test_get_profile_filled.py` (133 LOC) — 5 FastAPI integration tests covering happy path, blank data, missing row, race (most-recent wins), dep chain end-to-end.
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-01-w1-shared-helpers-SUMMARY.md` (this file).

### Modified
- `services/backend/app/models/coach_tools/__init__.py` — exports the 4-class envelope.
- `services/backend/tests/conftest.py` — appended `client_with_blank_profile` fixture (49 LOC), surgical change per Karpathy #3, no existing fixture touched.
- `services/backend/tests/test_coach_tools_scaffolding.py` — updated `test_models_coach_tools_package_importable` to assert the new 4-class export set instead of the stale `__all__ == []`.

## Verification Evidence (deterministic citations per 0-trust §9)

| Claim | Evidence command + result |
|-------|---------------------------|
| 10/10 unit tests green | `cd services/backend && python3 -m pytest tests/test_profile_resolver.py -q` → `10 passed in 0.20s` |
| 5/5 integration tests green | `cd services/backend && python3 -m pytest tests/test_get_profile_filled.py -q` → `5 passed in 0.23s` |
| Full backend suite green | `cd services/backend && python3 -m pytest tests/ -q` → `6947 passed, 62 skipped, 1 xfailed, 1 warning in 116.43s` |
| Envelope import works | `cd services/backend && python3 -c "from app.models.coach_tools import CoachToolIncomplete, CoachToolOk, CoachToolResponse, CoachToolPolicyBlocked; print('OK')"` → `OK` |
| camelCase serialization correct | `python3 -c "...CoachToolIncomplete(missing_fields=['canton'], hint_fr=...).model_dump(by_alias=True)"` → `{'status': 'incomplete', 'missingFields': ['canton'], 'hintFr': "..."}` |
| Banned-terms lint exit 0 | `python3 tools/checks/banned_terms_python.py services/backend/app/core/profile_resolver.py services/backend/tests/test_profile_resolver.py services/backend/tests/test_get_profile_filled.py services/backend/tests/conftest.py` → `BANNED_TERMS_EXIT_OK` |
| Accent FR lint clean | `python3 tools/checks/accent_lint_fr.py --scope backend` (filtered) → no errors on touched files |
| Helper signatures present | `grep -c "def _resolve_defaults\|def _required_profile_fields_missing\|def raise_incomplete_as_422\|def get_profile_filled\|PROFILE_GROUNDING_STRICT_MODE"` → 7 matches |
| Helper file ≥60 LOC | `wc -l services/backend/app/core/profile_resolver.py` → `186` lines |
| Envelope import in helper | `grep "from app.models.coach_tools._response import CoachToolIncomplete" services/backend/app/core/profile_resolver.py` → match |
| `Depends(get_profile_filled)` in integration test | `grep -c "Depends(get_profile_filled)" services/backend/tests/test_get_profile_filled.py` → `3` |
| Fixture appended | `grep -c "def client_with_blank_profile" services/backend/tests/conftest.py` → `1` |
| Fixture count preserved | `grep -cE "^def [a-z_]+\(\|^@pytest.fixture" services/backend/tests/conftest.py` → baseline `8` → after `10` (≥ baseline) |
| Test collection clean | `cd services/backend && python3 -m pytest tests/ --co -q | tail -5` → `7009 tests collected in 1.39s` |

**Pytest pass/fail delta vs Plan wave-1b-08 baseline** :
- Baseline per STATE.md : `6898 passed / 62 skipped / 1 xfailed`
- Post-plan : `6947 passed / 62 skipped / 1 xfailed`
- Delta : `+49 passed / +0 skipped / +0 xfailed` (=`+15` from this plan : 10 in `test_profile_resolver.py` + 5 in `test_get_profile_filled.py`, plus `~34` from intervening Tier 2 observability commits `20fa1fb4` / `fee17a0e` / `30531111`).

**A3 merge state** : Path B (cherry-picked verbatim from `origin/feature/wave-1c-A3-missing-fields-handshake` sha `a55b5469`). A3 PR #643 was OPEN against `dev` at execute-time, not merged. Per D-CE-19 Parallel Change, future A3 PR merge to dev will produce a no-op for `_response.py` (identical content) — no rebase debt.

## Decisions Made

- **Path B cherry-pick** for Task 0 (A3 PR #643 still open against dev at execute-time, not merged). Verbatim — no rewrite per D-CE-04 single doctrine.
- **HTTP_422_UNPROCESSABLE_CONTENT** constant chosen over the deprecated `HTTP_422_UNPROCESSABLE_ENTITY` (Rule 1 auto-fix, no semantic change, clears upstream FastAPI DeprecationWarning).
- **Test logger capture via dedicated `_RecordCollector` Handler** instead of pytest `caplog` — `app.core.logging_config.setup_logging()` invoked by upstream integration tests clears root handlers, which evicts caplog and produces suite-order-dependent failures. The custom handler attached directly to the module logger is robust.
- **Wave 1a `__all__ == []` scaffolding assertion updated** to the new 4-class export set — this is the correct downstream effect of D-CE-04 cherry-pick, not a regression.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug / cleanup] Upstream FastAPI `HTTP_422_UNPROCESSABLE_ENTITY` deprecation warning**
- **Found during:** Task 1 GREEN (running `pytest tests/test_profile_resolver.py -q`)
- **Issue:** `status.HTTP_422_UNPROCESSABLE_ENTITY` is deprecated in the FastAPI version on this codebase ; tests emitted a `DeprecationWarning` on every strict-mode run.
- **Fix:** Switched to `status.HTTP_422_UNPROCESSABLE_CONTENT` (same value `422`, current name).
- **Files modified:** `services/backend/app/core/profile_resolver.py`
- **Verification:** `pytest tests/test_profile_resolver.py -q` → `10 passed in 0.20s`, zero warnings.
- **Committed in:** `dd998654`

**2. [Rule 1 — Bug] Stale `test_models_coach_tools_package_importable` assertion**
- **Found during:** Task 4 (full backend suite run)
- **Issue:** `test_coach_tools_scaffolding.py` asserted `m.__all__ == []` — correct for Wave 1a's empty-marker package, but stale after Task 0 cherry-picked the A3 envelope per D-CE-04 (the legitimate downstream effect of D-CE-04 inheritance).
- **Fix:** Updated the assertion to `set(m.__all__) == {"CoachToolIncomplete", "CoachToolOk", "CoachToolPolicyBlocked", "CoachToolResponse"}` with a comment explaining the Wave 1a → mint-calc-engine-v1 doctrine migration.
- **Files modified:** `services/backend/tests/test_coach_tools_scaffolding.py`
- **Verification:** `pytest tests/test_coach_tools_scaffolding.py::test_models_coach_tools_package_importable -q` → green.
- **Committed in:** `26c5b860`

**3. [Rule 1 — Bug] Test suite-order pollution on `test_non_strict_mode_logs_warning_and_returns_resolved_body`**
- **Found during:** Task 4 (full backend suite run)
- **Issue:** The test passed in isolation but failed in the full-suite ordering. Root cause : stdlib `logging.getLogger(name)` returns a process-global cached instance. `app.core.logging_config.setup_logging()` (invoked by upstream integration tests) calls `root_logger.handlers.clear()`, evicting pytest's `caplog` handler. Also any prior test that touched the logger (level, disabled, propagate) leaked state across the `importlib.reload(pr)` boundary because reload swaps the module dict but the cached logger remains.
- **Fix:** Two-part: (a) the test now installs its own `_RecordCollector(logging.Handler)` directly on `pr._logger` instead of relying on caplog ; (b) the test force-resets `pr._logger.setLevel(WARNING)`, `pr._logger.disabled = False`, `pr._logger.propagate = True` so the handler actually fires regardless of any prior pollution.
- **Files modified:** `services/backend/tests/test_profile_resolver.py`
- **Verification:** `pytest tests/ -q` → `6947 passed, 62 skipped, 1 xfailed, 1 warning in 116.43s` — zero failures.
- **Committed in:** `26c5b860`

---

**Total deviations:** 3 auto-fixed (3 × Rule 1). All directly caused by current-plan changes (1 + 2 are downstream effects of the A3 cherry-pick ; 3 is a robustness fix on a test introduced by this plan).

**Impact on plan:** None. The 3 auto-fixes are correctness/observability improvements, no scope creep. Task ordering and acceptance criteria unchanged.

## Issues Encountered

- **None blocking.** Suite-order pollution (issue #3 above) was diagnosed and fixed in-session via Rule 1 auto-fix without escalation.

## Engram Memory Save — DEFERRED

The plan's Task 4 acceptance criteria includes `mem_save` of an observation with `topic_key: calc_engine:w1:foundation:profile_resolver_helpers_shipped` and `prior_finding_refs: [#89, #103, #104-107]`.

**Status:** NOT performed — the `plugin:engram:engram` MCP server tools (`mem_save`, `mem_search`, etc.) were not exposed in the executor agent's tool list this session. Tracked as a deferred item for the orchestrator/next session.

**To perform manually:**
```
mem_save with:
  topic_key: calc_engine:w1:foundation:profile_resolver_helpers_shipped
  type: discovery
  prior_finding_refs: [89, 103, 104, 105, 106, 107]
  content: "_resolve_defaults + get_profile_filled + raise_incomplete_as_422
            shipped at services/backend/app/core/profile_resolver.py (187 LOC).
            A3 envelope (4-class RootModel) cherry-picked verbatim per D-CE-04
            + D-CE-19 from sha a55b5469. Plans W1-02..W1-06 + all W2-W4
            grounding work can now `from app.core.profile_resolver import
            _resolve_defaults, raise_incomplete_as_422`. Concern D fixture
            client_with_blank_profile appended to conftest.py for reproduce-
            the-bug-first contract tests. 10 unit + 5 integration = 15 new
            tests green. Full suite 6947 passed (+49 vs baseline 6898)."
```

This omission does not affect verification of the plan's truth contracts, but the orchestrator should perform the save before opening downstream W1 plans so they can `prior_finding_refs` the foundation observation.

## User Setup Required

None — no external service configuration required. Pure code + tests.

## Next Phase Readiness

- **Plans W1-02 / W1-03 / W1-06 unblocked** : every grounding endpoint can now `from app.core.profile_resolver import _resolve_defaults, raise_incomplete_as_422, get_profile_filled` and `from app.models.coach_tools import CoachToolIncomplete`.
- **Plan W1-04 (lucidity payloads) unblocked** : independent helper module, no dependency on this plan's surface.
- **Plan W1-05 (calc registry) unblocked** : AST-scanner work is orthogonal but will reference `from_profile` markers added by W1-02..W1-06.
- **Plan W2-10 (CoachToolResponse V2)** has a clean V1 baseline on `dev` for Parallel Change V1→V2 migration if envelope evolves.

**No blockers carried forward.**

## USER VALUE DELIVERED (CLAUDE.md §9 honesty stake)

**NONE end-user-visible YET.** Plan 01 ships pure-infrastructure helpers + a test fixture + an envelope import surface. No REST endpoint behavior changes, no Flutter rendering surface, no narrator prompt change.

End-user impact lands when :
1. Plans W1-02 / W1-03 / W1-06 wire `_resolve_defaults` + `get_profile_filled` + `raise_incomplete_as_422` into the 12 sev-3 + 23 sev-2 endpoints identified in `W0-AUDIT-MATRIX.md`.
2. `PROFILE_GROUNDING_STRICT_MODE=true` is flipped on Railway staging.
3. Flutter ProfileProvider is verified to pre-fill canton + age + lpp_balance for live users.
4. Sim walk-through confirms a user with a blank profile receives a `CoachToolIncomplete` envelope (422) instead of a wrong-canton tax bracket.

Plan 01 is Stage 1 of 4 per CLAUDE.md §9.5 — work shipped to a local branch, no PR yet, no merge to dev, no deploy. The 6 commits sit on `dev` ready for verifier review.

## Self-Check: PASSED

Verified inline before writing this SUMMARY :

- `services/backend/app/core/profile_resolver.py` → FOUND (`wc -l` = 186)
- `services/backend/app/models/coach_tools/_response.py` → FOUND (`wc -l` = 76, cherry-picked from sha a55b5469)
- `services/backend/tests/test_profile_resolver.py` → FOUND (10 tests, all green)
- `services/backend/tests/test_get_profile_filled.py` → FOUND (5 tests, all green)
- `services/backend/tests/conftest.py:client_with_blank_profile` → FOUND (`grep -c` = 1)
- Commits on `dev` branch :
  - `36e20741` cherry-pick(wave-1c-A3): bring CoachToolResponse envelope... → FOUND
  - `8e8d9f41` test(mint-calc-engine-v1-01): add failing tests... → FOUND
  - `dd998654` feat(mint-calc-engine-v1-01): implement profile_resolver... → FOUND
  - `d468e58d` test(mint-calc-engine-v1-01): FastAPI integration tests... → FOUND
  - `fc4d0a8d` test(mint-calc-engine-v1-01): client_with_blank_profile... → FOUND
  - `26c5b860` fix(mint-calc-engine-v1-01): suite-order pollution... → FOUND

---
*Phase: mint-calc-engine-v1*
*Plan: 01 — W1 shared profile-resolver helpers + client_with_blank_profile fixture*
*Completed: 2026-05-16*
