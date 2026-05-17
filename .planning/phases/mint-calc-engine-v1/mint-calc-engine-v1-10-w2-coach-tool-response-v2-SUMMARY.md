---
phase: mint-calc-engine-v1
plan: 10
wave: 2
subsystem: api
tags: [coach-tool-response-v2, latency-tier, parallel-change, d-ce-04, d-ce-19, concern-b, fowler-migration, feature-flag-rollout, pydantic-v2-rootmodel-discriminator, wave-1a-backwards-compat]

# Dependency graph
requires:
  - phase: mint-calc-engine-v1
    plan: 01
    provides: "CoachToolResponse V1 envelope (Wave 1c-A3 cherry-picked, 4-class discriminated union) — the baseline that V2 ships ALONGSIDE of per Parallel Change discipline"
  - phase: mint-calc-engine-v1
    plan: 07
    provides: "ToolRegistryAdapter Protocol with latency_tier(tool_name) method + LatencyTier Literal['L1','L2','L3'] — Plan 10 _CHIP_EMITTER_LATENCY_TIERS dict mirrors this contract on the dispatcher side and aligns the field name across the abstraction"
provides:
  - "services/backend/app/models/coach_tools/_response.py — CoachToolOkV2 (latency_tier REQUIRED) + CoachToolIncompleteV2 (default 'L1', same D-A3-01 cap=3 validator) + CoachToolPolicyBlockedV2 (default 'L1') + CoachToolResponseV2 RootModel discriminated union. V1 classes UNCHANGED (Parallel Change additive)."
  - "services/backend/app/models/coach_tools/__init__.py — exports 5 V2 symbols (+ LatencyTier) alongside the 4 V1 symbols."
  - "services/backend/app/core/config.py:COACH_TOOL_RESPONSE_V2_ENABLED — bool feature flag default False ; flip True on staging+prod after Flutter Concern B consumer plan lands (Plan 11 or post-phase)."
  - "services/backend/app/api/v1/endpoints/coach_chat.py — _CHIP_EMITTER_LATENCY_TIERS dict (5 chip-emitters → 'L1') + _wrap_chip_response_v2 (JSON payload → CoachToolOkV2 envelope) + _wrap_chip_string_response_v2 (text payload → data.text envelope for cap_status) + _maybe_wrap_v2 flag-gated dispatcher + 5 call sites wired."
  - "31 new tests across 3 test files (13 V2 unit + 9 chip-emitter migration + 9 Parallel Change invariants) — all green in isolation AND in full backend suite."
  - "Flutter Concern B routing doctrine documented (below) for downstream consumer plan."
affects: [mint-calc-engine-v1-11-w2-deprecation-shims, future-flutter-concern-b-consumer-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature-flag-gated Parallel Change wrapping — opt-in V2 envelope per chip-emitter via COACH_TOOL_RESPONSE_V2_ENABLED flag. Default OFF preserves Wave 1a backwards-compat ; flag flip activates V2 routing for Flutter Concern B chip-vs-narrative-loader surface dispatch. Pattern replicable for the next Parallel Change cycle (V2→V3 if downstream demands future field additions)."
    - "Wrapping site at the per-tool _compute_* return (not at the dispatcher) — preserves the legacy FR fallback string path unchanged. Pydantic-modelled chip-emitters use _wrap_chip_response_v2(json) ; text-only chip-emitters like cap_status use _wrap_chip_string_response_v2(text) which surfaces the payload under .data.text. The 2 wrapping helpers are 1 LOC apart in coach_chat.py — single source of envelope-construction truth."
    - "Discriminated-union mirror across V1+V2 — both envelopes use Pydantic v2 RootModel[Annotated[Union[Ok|Incomplete|PolicyBlocked], Field(discriminator='status')]]. Same camelCase aliasing via to_camel ; same D-A3-01 cap=3 validator on missing_fields (V2 uses _cap_missing_fields_v2 to keep separate from V1 — could be DRYed in a future cleanup but keeping separate matches Fowler's 'parallel implementation' discipline)."
    - "Flag-OFF passthrough at the wrapping helper level — _wrap_chip_response_v2 short-circuits on non-JSON input (returns payload unchanged for legacy FR fallback strings). This means the wrapping is opt-in PER JSON PAYLOAD, not a blanket transform of the dispatcher's `content` field."

key-files:
  created:
    - "services/backend/tests/test_coach_tool_response_v2.py (186 LOC, 8 unit tests + 5 parametrized via Literal-reject test = 13 total)"
    - "services/backend/tests/test_coach_tool_response_v2_migration.py (240 LOC, 9 chip-emitter migration tests)"
    - "services/backend/tests/test_coach_tool_response_migration.py (255 LOC, 9 Parallel Change invariants)"
  modified:
    - "services/backend/app/models/coach_tools/_response.py (+75 LOC additive — V2 classes + LatencyTier Literal)"
    - "services/backend/app/models/coach_tools/__init__.py (+10 LOC — 5 new V2 exports + LatencyTier)"
    - "services/backend/app/core/config.py (+10 LOC — COACH_TOOL_RESPONSE_V2_ENABLED bool flag default False)"
    - "services/backend/app/api/v1/endpoints/coach_chat.py (+90 LOC — _CHIP_EMITTER_LATENCY_TIERS dict + _wrap_chip_response_v2 + _wrap_chip_string_response_v2 + _maybe_wrap_v2 helper + 5 call sites wired)"
    - "services/backend/tests/test_coach_tools_scaffolding.py (+5 LOC — assertion set widened with V2 exports, mirrors Plan 01's same fix on the same test)"

key-decisions:
  - "Plan-spec deviation Rule 1 (path inaccuracy) — Plan said coach_tools.py:637-722 contains 5 chip-emitters. Reality : coach_tools.py contains tool DEFINITIONS (input_schema/name/description for Anthropic). Chip-emitter IMPLEMENTATIONS live in coach_chat.py as _compute_* + _validate_cap_response (2772 / 2876 / 3000 / 3127 / 3211). Migration target switched to coach_chat.py. Same coach internal tools area ; D-CE-19 intent honored. Plan 06 used the same playbook for substituting endpoints (path inaccuracy)."
  - "Feature flag gate (COACH_TOOL_RESPONSE_V2_ENABLED) default False — preserves Wave 1a contract for test_coach_tools_budget_snapshot.py et al. (which parse payload['monthlyIncome'] at TOP level, not under .data). Plan 11 or post-phase flips ON after Flutter consumer plan lands."
  - "cap_status (string-only tool) wraps under data.text — distinct from Pydantic-modelled chip-emitters (which wrap under data with the original camelCase fields). This keeps the V2 envelope shape predictable for Flutter consumer (always envelope[data][<key>]). Flutter Concern B plan formalizes the data.text contract."
  - "Migration cost ≤200 LOC honored — net diff `git diff --stat HEAD~5..HEAD` shows ~190 LOC in `app/` (additive). Test code excluded from migration budget per Fowler. Plan 06 averaged 200 LOC per endpoint batch ; Plan 10 stays under the panel-stated budget."

patterns-established:
  - "Parallel Change V1→V2 via feature flag + opt-in wrapping helper — replicable for any future Pydantic envelope migration. Steps : (1) ship V2 classes alongside V1 in same module, (2) export both from __init__.py, (3) add env-driven feature flag default False, (4) add helper functions that conditionally wrap the legacy payload, (5) wire wrapping at site of return (not dispatcher) so legacy fallback paths are not affected, (6) write tests that EXPLICITLY assert flag-OFF preserves legacy + flag-ON wraps in V2."
  - "Test pattern : 3 separate test files for 3 distinct concerns — (a) test_coach_tool_response_v2.py = Pydantic shape unit tests, (b) test_coach_tool_response_v2_migration.py = wiring / dispatcher / flag behavior, (c) test_coach_tool_response_migration.py = Parallel Change invariants (consumer counts + V1 retirement guard + Union[V1,V2] type). Failure mode legibility ; each file owns one axis of the migration."
  - "Migration count tracker test (Invariant #6 of Task 3) — runs `grep -rln 'CoachToolOkV2|CoachToolResponseV2' app/` and asserts ≥1 consumer in `app/`. Proves Parallel Change is in motion, not theoretical. Re-usable for any future V2→V3 migration ; just bump the grep pattern."

requirements-completed: [D-CE-04, D-CE-19, Concern-B]

# Metrics
duration: ~15min
completed: 2026-05-16
---

# Phase mint-calc-engine-v1 Plan 10: W2 CoachToolResponseV2 envelope (Parallel Change) Summary

**D-CE-04 + D-CE-19 + Concern B shipped : `CoachToolResponseV2` Pydantic v2 RootModel discriminated union ALONGSIDE V1 in `services/backend/app/models/coach_tools/_response.py` (+75 LOC additive, V1 classes UNCHANGED). 5 chip-emitter dispatchers in `coach_chat.py:_compute_*` + `cap_status` wired with opt-in V2 envelope wrapping via `COACH_TOOL_RESPONSE_V2_ENABLED` feature flag (default False — Wave 1a contract tests stay green). `LatencyTier = Literal["L1","L2","L3"]` field is REQUIRED on `CoachToolOkV2` and defaults to "L1" on `CoachToolIncompleteV2` + `CoachToolPolicyBlockedV2` per panel discipline (sub-500ms 422 envelope semantics). 31 new tests across 3 test files (13 V2 unit + 9 chip-emitter migration + 9 Parallel Change invariants), full backend suite 7136 passed (+31 vs Plan 09 baseline 7105, zero regressions, 3 xfailed unchanged). Banned-terms + accent FR lints exit 0 on all touched files. Plan 09 string state preserved intact (10 + 66 + 56 art. refs unchanged). Engram observation #132 saved via CLI fallback. V1 retirement explicitly DEFERRED to Plan 11 or post-phase per D-CE-19 Fowler discipline.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-16T21:10:51Z
- **Completed:** 2026-05-16T21:26:44Z (approximate)
- **Tasks:** 4/4 (Task 1 V2 envelope + Task 2 chip-emitter migration + Task 3 Parallel Change invariants + Task 4 verification & engram & SUMMARY)
- **Files created:** 4 (3 test files + this SUMMARY)
- **Files modified:** 5 (`_response.py` + `__init__.py` + `config.py` + `coach_chat.py` + `test_coach_tools_scaffolding.py`)

## Accomplishments

### Task 1 — V2 envelope additive (commits `670f3278` RED → `9ce25bff` GREEN)

`services/backend/app/models/coach_tools/_response.py` (+75 LOC) ships :

| Symbol | Shape |
|---|---|
| `LatencyTier` | `Literal["L1", "L2", "L3"]` — aligned with Plan 07 adapter contract |
| `CoachToolOkV2` | status="ok" + data: dict + latency_tier (REQUIRED) |
| `CoachToolIncompleteV2` | status="incomplete" + missing_fields (cap=3, V2 validator) + hint_fr (min=10) + latency_tier (default "L1") |
| `CoachToolPolicyBlockedV2` | status="policy_blocked" + reason_code + message_fr + latency_tier (default "L1") |
| `CoachToolResponseV2` | RootModel[Annotated[Union[OkV2, IncompleteV2, PolicyBlockedV2], discriminator="status"]] |

V1 classes UNCHANGED — `git diff services/backend/app/models/coach_tools/_response.py` shows only additions.

`__init__.py` exports the 5 V2 symbols (+ LatencyTier) alongside the 4 V1 symbols. `test_coach_tools_scaffolding.py::test_models_coach_tools_package_importable` assertion set widened with the new V2 exports (downstream-effect-of-Plan-10, same fix Plan 01 applied — see commit `26c5b860`).

13 V2 unit tests (`test_coach_tool_response_v2.py`) :
- 8 explicit tests + 5 parametrized via the Literal-reject test (rejects "L4", "L0", "L1 ", "high", "", "l1")
- Covers : constructs with L1 / rejects missing latency_tier / rejects bad Literal / camelCase alias round-trip / by_alias serialization / V1 still works / Parallel Change coexistence / LatencyTier type export

### Task 2 — 5 chip-emitter V2 migration (commits `455ceee8` RED → `4d99175b` GREEN)

`services/backend/app/core/config.py` :
- `COACH_TOOL_RESPONSE_V2_ENABLED: bool = False` — Plan 10 feature flag

`services/backend/app/api/v1/endpoints/coach_chat.py` :
- `_CHIP_EMITTER_LATENCY_TIERS: dict[str, str]` — 5 chip-emitter names → "L1"
- `_wrap_chip_response_v2(payload, latency_tier="L1")` — JSON payload → CoachToolOkV2 envelope
- `_wrap_chip_string_response_v2(text, latency_tier="L1")` — text payload → data.text envelope (for cap_status)
- `_maybe_wrap_v2(tool_name, payload, *, is_string_tool=False)` — flag-gated dispatcher

Wired at **5 call sites** :

| Chip-emitter | Site | Pattern |
|---|---|---|
| `get_budget_status` | `_compute_budget_status:return` | `_maybe_wrap_v2("get_budget_status", response.model_dump_json(by_alias=True))` |
| `get_retirement_projection` | `_compute_retirement_projection:return` | `_maybe_wrap_v2("get_retirement_projection", ...)` |
| `get_cross_pillar_analysis` | `_compute_cross_pillar_analysis:return` | `_maybe_wrap_v2("get_cross_pillar_analysis", ...)` |
| `get_couple_optimization` | `_compute_couple_optimization:return` | `_maybe_wrap_v2("get_couple_optimization", ...)` |
| `get_cap_status` | dispatch ``if name == "get_cap_status"`` | `_maybe_wrap_v2("get_cap_status", ..., is_string_tool=True)` |

9 V2 migration tests (`test_coach_tool_response_v2_migration.py`) :
- _CHIP_EMITTER_LATENCY_TIERS constant exposes 5 L1 entries
- _wrap_chip_response_v2 envelopes JSON payload with latencyTier
- emits camelCase alias
- rejects invalid LatencyTier
- flag OFF preserves legacy top-level camelCase shape
- flag ON wraps _compute_budget_status in V2 envelope
- flag ON wraps _compute_retirement_projection (handles legacy-fallback case too)
- _wrap_chip_string_response_v2 wraps cap_status text under data.text
- passthrough for non-JSON FR fallback

### Task 3 — Parallel Change invariants (commit `4a3659f9`)

`services/backend/tests/test_coach_tool_response_migration.py` — 9 invariant tests :

| Invariant | Asserts |
|---|---|
| 1 | Both V1 + V2 envelopes exported from app.models.coach_tools.__all__ |
| 2 | V1 envelope round-trips independently |
| 3 | V1 incomplete still caps missing_fields at 3 (D-A3-01) |
| 4 | V2 envelope round-trips with latency_tier preserved |
| 5 | V2 incomplete inherits same cap=3 |
| 6 | Union[CoachToolResponse, CoachToolResponseV2] accepts both shapes |
| 7 | Live bridge proof : _compute_budget_status emits V2 envelope when flag ON |
| 8 | Migration count tracker : V1 + V2 each have ≥1 consumer in app/ |
| 9 | V1 retirement guard : V1 classes still constructible after Plan 10 |

### Task 4 — Full suite verification + engram + SUMMARY (this section)

- Full backend suite : **7136 passed, 62 skipped, 3 xfailed, 1 warning in 113.62s** (Plan 09 baseline 7105 → +31 = 13 V2 unit + 9 migration + 9 invariant), zero regressions, 3 xfailed unchanged (Plan 09 Jaccard polish TODOs preserved).
- Banned-terms lint on 8 changed files : exit 0.
- Accent FR lint scope=backend : exit 0, 0 hits on touched files.
- Plan 09 strings PRESERVED INTACT : `coach_tools.py` art. ref count = 10 (Plan 09 baseline), adapter art. ref count = 66 (Plan 09 baseline), `_TOOL_DESCRIPTIONS_FR` len = 56 (Plan 09 baseline).
- Engram observation **#132** saved via CLI fallback : `engram save "Plan 10 W2 CoachToolResponseV2 envelope shipped (Concern B + D-CE-19)" ... --topic_key mint-calc-engine-v1:w2-plan-10:coach-tool-response-v2`.

## Task Commits

1. `670f3278` test(mint-calc-engine-v1-10): add failing V2 envelope tests (Task 1 RED)
2. `9ce25bff` feat(mint-calc-engine-v1-10): ship CoachToolResponseV2 envelope (Task 1 GREEN)
3. `455ceee8` test(mint-calc-engine-v1-10): add failing chip-emitter V2 migration tests (Task 2 RED)
4. `4d99175b` feat(mint-calc-engine-v1-10): migrate 5 chip-emitters to V2 envelope (Task 2 GREEN)
5. `4a3659f9` test(mint-calc-engine-v1-10): add Parallel Change invariant suite (Task 3)

**Plan metadata commit:** pending (this SUMMARY + STATE.md + ROADMAP.md update + verification HTML row).

## Files Created/Modified

### Created
- `services/backend/tests/test_coach_tool_response_v2.py` (186 LOC, 13 tests)
- `services/backend/tests/test_coach_tool_response_v2_migration.py` (240 LOC, 9 tests)
- `services/backend/tests/test_coach_tool_response_migration.py` (255 LOC, 9 tests)
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-10-w2-coach-tool-response-v2-SUMMARY.md` (this file)

### Modified
- `services/backend/app/models/coach_tools/_response.py` (+75 LOC additive — V2 classes + LatencyTier Literal). V1 classes UNCHANGED.
- `services/backend/app/models/coach_tools/__init__.py` (+10 LOC — 5 new V2 exports + LatencyTier).
- `services/backend/app/core/config.py` (+10 LOC — COACH_TOOL_RESPONSE_V2_ENABLED bool flag default False).
- `services/backend/app/api/v1/endpoints/coach_chat.py` (+90 LOC — _CHIP_EMITTER_LATENCY_TIERS dict + _wrap_chip_response_v2 + _wrap_chip_string_response_v2 + _maybe_wrap_v2 helper + 5 call sites wired).
- `services/backend/tests/test_coach_tools_scaffolding.py` (+5 LOC — assertion set widened with V2 exports).

**Total : 4 files created, 5 files modified.** Net diff ~+870 LOC across modules + tests (≤200 LOC in app/ source — ~185 LOC, matches Fowler Parallel Change migration budget).

## Decisions Made

1. **Plan-spec path deviation (Rule 1 documented)** — Plan said coach_tools.py:637-722 contains the 5 chip-emitters. Reality : coach_tools.py contains tool DEFINITIONS (input_schema/name/description for Anthropic). Chip-emitter IMPLEMENTATIONS live in coach_chat.py as `_compute_*` + `_validate_cap_response`. Migration target switched to coach_chat.py. Same coach internal tools area ; D-CE-19 intent honored. Plan 06 used the same playbook for substituting endpoints (3 endpoints dropped, 3 substituted) when plan-path text didn't match codebase reality.

2. **Feature-flag-gated migration (`COACH_TOOL_RESPONSE_V2_ENABLED` default False)** — preserves Wave 1a contract for `test_coach_tools_budget_snapshot.py` and 8 sister tests (which parse `payload["monthlyIncome"]` at TOP level, not under `.data`). Flag flip ON activates V2 routing for Flutter Concern B chip-vs-narrative-loader surface dispatch. Plan 11 or post-phase ships the flip on staging then prod (after Flutter consumer plan lands).

3. **cap_status string-only tool wraps under `data.text`** — distinct from Pydantic-modelled chip-emitters (which wrap under `data` with the original camelCase fields). This keeps the V2 envelope shape predictable for Flutter consumer (always `envelope[data][<key>]`). Documented as a Flutter Concern B doctrine note below.

4. **Migration cost ≤200 LOC honored** — net diff in app/ source (excluding tests) is ~185 LOC. Plan 06 averaged 200 LOC per endpoint batch ; Plan 10 stays under the panel-stated D-CE-19 budget.

5. **Two distinct wrapping helpers (`_wrap_chip_response_v2` for JSON, `_wrap_chip_string_response_v2` for text)** — keeps cap_status semantics distinct from Pydantic-modelled chip-emitters. Could be unified into a single helper with type sniffing, but distinct functions are more explicit and easier to extend (e.g. Plan 11 + might add `_wrap_chip_l2_response_v2` for L2-tier wrappers).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan path inaccuracy] Plan said coach_tools.py:637-722 contains 5 chip-emitter handlers**

- **Found during:** Pre-RED read-through of Task 2 scope
- **Issue:** Plan task 2 reads "For each of 5 chip-emitters in `coach_tools.py`, change return type ... `CoachToolOk → CoachToolOkV2`". But `coach_tools.py` is a 1289-line module of tool DEFINITIONS (input_schema/name/description, passed verbatim to Anthropic). The functions `_compute_budget_status`, `_compute_retirement_projection`, `_compute_cross_pillar_analysis`, `_format_cap_status`, `_compute_couple_optimization` actually live in `services/backend/app/api/v1/endpoints/coach_chat.py` at lines 2772 / 2876 / 3000 / 3127 (cap) / 3211. And these functions don't return `CoachToolOk(data={...})` today — they return either `model_dump_json(by_alias=True)` of a per-tool response model (BudgetSnapshotResponse etc.) or a legacy FR `_format_*` string.
- **Fix:** Migration target switched to `coach_chat.py`. Wrapping helpers introduced (`_wrap_chip_response_v2` for JSON payloads, `_wrap_chip_string_response_v2` for text). Feature flag added (`COACH_TOOL_RESPONSE_V2_ENABLED`) so existing Wave 1a contract tests stay green when flag OFF (default) and V2 envelope kicks in when flag ON.
- **Files modified:** `coach_chat.py` (helpers + 5 wired sites) + `config.py` (flag) instead of `coach_tools.py`.
- **Verification:** `grep -c "CoachToolOkV2" coach_chat.py → 7` ; `grep -c 'latency_tier' coach_chat.py → 12` ; `grep -c '"L1"' coach_chat.py → 14` ; all 5 chip-emitter contract tests still pass under flag OFF ; new V2 tests pass under flag ON. Plan acceptance grep counts (Plan task 2 §acceptance) targeted coach_tools.py — substituted with coach_chat.py grep counts (same intent, same coach-internal-tools area). Cite Plan 06 SUMMARY §Deviations #1-3 for the same playbook.
- **Committed in:** `4d99175b`.

**2. [Rule 1 - Bug auto-fix] test_coach_tools_scaffolding.py stale assertion**

- **Found during:** Task 1 GREEN verification (`pytest tests/test_coach_tools_scaffolding.py`)
- **Issue:** `test_models_coach_tools_package_importable` asserts `set(m.__all__) == {4 V1 symbols}` — correct after Plan 01 cherry-pick, but stale after Plan 10 V2 additions. Plan 01 fixed the SAME test for the SAME reason (commit `26c5b860` widened from `set(m.__all__) == set()` to `set(m.__all__) == {4 V1}`). Plan 10 just continues that pattern.
- **Fix:** Widened the assertion set with the 5 new V2 symbols (`CoachToolIncompleteV2`, `CoachToolOkV2`, `CoachToolPolicyBlockedV2`, `CoachToolResponseV2`, `LatencyTier`). Added comment explaining the V2 doctrine migration.
- **Files modified:** `services/backend/tests/test_coach_tools_scaffolding.py` (1 set widened + 5 LOC of comment).
- **Verification:** `pytest tests/test_coach_tools_scaffolding.py -q → 15 passed`.
- **Committed in:** `9ce25bff` (folded into Task 1 GREEN since both are downstream-effect-of-Plan-10).

---

**Total deviations:** 2 auto-fixed (1 Rule 1 plan-path inaccuracy ; 1 Rule 1 stale-assertion bug). **Zero architectural deviations.**

**Impact on plan:** Deviation #1 changes Task 2 file-target from coach_tools.py to coach_chat.py (same area, Plan-acceptance grep counts substituted equivalently). Deviation #2 is a downstream-effect fix that Plan 01 already established the pattern for.

## Issues Encountered

- **None blocking.** The plan-path inaccuracy (Deviation #1) was caught during pre-RED read-through and resolved via the same playbook as Plan 06.

## 0-Trust Evidence (CLAUDE.md §9.6)

| Claim | Evidence |
|---|---|
| 13 V2 unit tests green | `cd services/backend && python3 -m pytest tests/test_coach_tool_response_v2.py -q` → `13 passed in 0.30s` |
| 9 chip-emitter migration tests green | `cd services/backend && python3 -m pytest tests/test_coach_tool_response_v2_migration.py -q` → `9 passed in 0.23s` |
| 9 Parallel Change invariant tests green | `cd services/backend && python3 -m pytest tests/test_coach_tool_response_migration.py -q` → `9 passed in 0.65s` |
| Full backend suite 7136 passed (+31 vs Plan 09 7105) | `cd services/backend && python3 -m pytest tests/ -q` → `7136 passed, 62 skipped, 3 xfailed, 1 warning in 113.62s` ; Plan 09 baseline 7105 → exact +31 match (13 V2 unit + 9 migration + 9 invariant) ; zero regressions ; 3 xfailed unchanged (Plan 09 Jaccard polish TODOs preserved) |
| V1 envelope classes UNCHANGED | `git diff HEAD~5..HEAD -- services/backend/app/models/coach_tools/_response.py` shows ONLY additions in the V2 block ; no V1 class line modified |
| V1 import still works | `cd services/backend && python3 -c "from app.models.coach_tools import CoachToolOk; CoachToolOk(data={})"` exit 0 |
| V2 import works | `cd services/backend && python3 -c "from app.models.coach_tools import CoachToolOkV2; CoachToolOkV2(data={}, latency_tier='L1')"` exit 0 |
| 5 chip-emitter sites wired in coach_chat.py | `grep -c "_maybe_wrap_v2" services/backend/app/api/v1/endpoints/coach_chat.py` → `6` (1 helper def + 5 call sites) |
| `latency_tier` appears ≥5 times in coach_chat.py | `grep -c 'latency_tier' services/backend/app/api/v1/endpoints/coach_chat.py` → `12` (≥5 ✓) |
| `"L1"` appears ≥5 times in coach_chat.py | `grep -c '"L1"' services/backend/app/api/v1/endpoints/coach_chat.py` → `14` (≥5 ✓) |
| `CoachToolOkV2` appears ≥1 time in coach_chat.py | `grep -c 'CoachToolOkV2' services/backend/app/api/v1/endpoints/coach_chat.py` → `7` (3 helper bodies × 1-2 refs) |
| Plan 09 string state UNCHANGED | `grep -c 'art\. ' services/backend/app/services/coach/coach_tools.py` → `10` (Plan 09 baseline) ; `grep -c 'art\. ' adapter` → `66` (baseline) ; `len(_TOOL_DESCRIPTIONS_FR)` → `56` (baseline) |
| `class CoachToolOkV2` count in _response.py | `grep -c "class CoachToolOkV2" services/backend/app/models/coach_tools/_response.py` → `1` |
| `latency_tier` count in _response.py | `grep -c "latency_tier" services/backend/app/models/coach_tools/_response.py` → `8` (≥3 ✓) |
| `__init__.py` exports both V1 + V2 | `cd services/backend && python3 -c "import app.models.coach_tools as m; assert {'CoachToolOk','CoachToolOkV2','CoachToolResponse','CoachToolResponseV2','LatencyTier'}.issubset(set(m.__all__))"` exit 0 |
| Banned-terms lint clean on 8 touched files | `python3 tools/checks/banned_terms_python.py <8 files>` → exit 0 |
| Accent FR lint scope=backend clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0, 0 hits on touched files |
| Engram observation #132 saved | `engram save "Plan 10 W2 CoachToolResponseV2 envelope shipped (Concern B + D-CE-19)" ... --topic_key mint-calc-engine-v1:w2-plan-10:coach-tool-response-v2` → `Memory saved: #132 (architecture)` |
| 5 task commits in git log | `git log --oneline 670f3278^..4a3659f9` → 5 commits |

**Caveats (what I have NOT checked):**

- Did NOT wire `get_tool_registry_adapter()` into `coach_chat.py` — that's a separate concern (Plan 07 ships scaffolding, Plan 10 ships the envelope, Plan 11 wires the adapter). Plan 10 ships the envelope contract only, NOT the adapter dispatch.
- Did NOT flip `COACH_TOOL_RESPONSE_V2_ENABLED=true` on staging — feature flag stays False until Flutter Concern B consumer plan lands. Documented as next-step gate below.
- Did NOT verify Flutter side reads the V2 envelope — Flutter consumer plan is OUT OF SCOPE per CONTEXT §D-CE-06 (Flutter UX-only). Plan 10 ships the SERVER contract ; Flutter implements the routing in a future plan.
- Did NOT run staging pilot or device walkthrough — Plan 09 staging pilot (Task 5b) remains DEFERRED. Plan 10 ships behind the same staging gate.
- Did NOT extend the V2 envelope to L2/L3 tools — only L1 chip-emitters are wired in Plan 10. The 63 long-tail calculators (from Plan 05 REGISTRY) inherit the L2/L3 contract from Plan 07 adapter's `latency_tier(name)` method but aren't wrapped here ; the adapter-to-dispatcher bridge is Plan 11 + scope.
- USER VALUE DELIVERED : zero end-user-visible change yet. V2 envelope is OPT-IN behind a False-by-default flag. End-user impact lands when (a) Plan 11 or post-phase flips the flag, (b) Flutter consumer plan reads the latencyTier hint and routes to the right surface. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR).
- MCP `mem_save` tool NOT in this executor's tool scope (same gap as 9 prior plan SUMMARYs) ; engram save succeeded via CLI fallback. The MCP propagation fix `bc07d915 + 1b106220` does not survive the GSD agent loader stripping per anthropics/claude-code#13898.

## Flutter Concern B routing doctrine (for downstream Flutter plan)

The V2 envelope carries `latencyTier: "L1" | "L2" | "L3"` which Flutter MUST use to route responses to the right rendering surface :

| LatencyTier | Surface | Render |
|---|---|---|
| `L1` | Chip surface (sub-500ms) | `CoachCitationChipsSection` widget per Phase 94 pattern |
| `L2` | Narrative loader medium budget (2-4s) | `MintNarrativeLoader` with progress affordance |
| `L3` | Narrative loader long budget (4-8s) | `MintNarrativeLoader` with progress affordance + "calcul approfondi" copy |

Flutter consumer route :
- `apps/mobile/lib/services/coach/coach_response_router.dart` — to be created in the Flutter Concern B plan
- Reads `envelope.data.latencyTier` from the V2 JSON
- Routes payload to the right surface
- Falls back to V1 contract when `latencyTier` is absent (Wave 1a backwards-compat)

`cap_status` text payload : surfaces under `envelope.data.text` (NOT under top-level `text` field). Flutter consumer must read `envelope.data.text` for cap_status only ; for the 4 Pydantic-modelled chip-emitters, the original camelCase fields are at `envelope.data.<field>` (e.g. `envelope.data.monthlyIncome`).

## Engram Save Status

**Saved via CLI fallback :**
- `obs_id`: **#132**
- `title`: "Plan 10 W2 CoachToolResponseV2 envelope shipped (Concern B + D-CE-19)"
- `type`: `architecture`
- `topic_key`: `mint-calc-engine-v1:w2-plan-10:coach-tool-response-v2`
- `project`: `mint`
- `prior_finding_refs` (in content body) : #114 (Wave 1c-A3 envelope ships clean, V1 baseline), #103 (vendor-agnostic adapter panel synthesis, Concern B routing), #128 (Wave 1 closure handoff), #129 (Plan 07 ToolRegistryAdapter, LatencyTier definition site), #130 (Plan 08 bundles), #131 (Plan 09 tool description rewrite, _TOOL_DESCRIPTIONS_FR untouched by Plan 10)
- Content : full What/Where/Why/Tests/Learned/Prior-refs body, ~3.6 KB

**MCP route :** `mcp__plugin_engram_engram__mem_save` NOT exposed in this executor agent's tool list — 9th consecutive plan hitting this gap. CLI fallback path documented in CLAUDE.md §3 (`~/.engram/engram.db` is the live DB shared with `engram serve` + `engram mcp` daemons).

## Wave 2 Next Steps

- **Plan 11 — `w2-deprecation-shims`** : Migrates root-level `independant_service.py` + `frontalier_service.py` to canonical sub-directories with `DeprecationWarning` shims (D-CE-10). Concludes Wave 2.
- **Task 5b — staging pilot env-flip** (still DEFERRED from Plan 09) : Once Julien sign-off received, flip `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` on Railway mint-staging AND flip `COACH_TOOL_RESPONSE_V2_ENABLED=true` to activate V2 routing for Flutter Concern B consumers.
- **Future Flutter Concern B consumer plan** : implements `coach_response_router.dart` per the doctrine table above. Reads `envelope.data.latencyTier` and routes to chip surface vs narrative loader.

## Next Plan Readiness

- Plan 10 complete : V2 envelope + 5 chip-emitter migrations + Parallel Change invariants. Full backend suite green.
- Next plan : **Plan 11 — `w2-deprecation-shims`** (independant + frontalier service migration).
- W2 wave-close gated by Plan 11 ; W3 (DAG cache + pre-compute + GC) starts after W2 close.
- V1 retirement explicitly DEFERRED to Plan 11 OR post-phase per D-CE-19 Fowler discipline. Plan 11 OUT OF SCOPE for V1 deletion unless re-scoped.

## USER VALUE DELIVERED (CLAUDE.md §9 honesty stake)

**NONE end-user-visible YET.** Plan 10 ships pure-infrastructure (V2 envelope class + 5 wrapping sites + feature flag). No user-facing change without (a) Flutter Concern B consumer plan reading `latencyTier`, (b) `COACH_TOOL_RESPONSE_V2_ENABLED=true` flip on staging+prod, (c) Plan 11 wiring the adapter to dispatch.

End-user impact lands when :
1. Plan 11 or post-phase wires `get_tool_registry_adapter()` into `coach_chat.py` dispatcher.
2. Flutter consumer plan reads `envelope.data.latencyTier` and routes to chip vs narrative-loader surface.
3. Staging pilot flips `COACH_TOOL_RESPONSE_V2_ENABLED=true` + Sentry observability confirms no regression.
4. Device walkthrough confirms a real user sees chip-fast L1 responses vs narrative-loader L2-L3 responses appropriately routed.

Plan 10 is Stage 1 of 4 per CLAUDE.md §9.5 — work shipped to local `dev`, no PR yet, no merge to remote, no Railway deploy, no Flutter consumer.

## Self-Check: PASSED

Verified inline before writing this SUMMARY :

- `services/backend/app/models/coach_tools/_response.py` → FOUND (`grep -c "class CoachToolOkV2"` = 1, `grep -c "latency_tier"` = 8)
- `services/backend/app/models/coach_tools/__init__.py` → FOUND (`grep -c "CoachToolOkV2\|LatencyTier"` includes V2 + LatencyTier exports)
- `services/backend/app/core/config.py:COACH_TOOL_RESPONSE_V2_ENABLED` → FOUND (`grep -c "COACH_TOOL_RESPONSE_V2_ENABLED" config.py` = 1 def + future tests)
- `services/backend/app/api/v1/endpoints/coach_chat.py` → 5 wired sites (`grep -c "_maybe_wrap_v2"` = 6 ; 1 def + 5 calls) + helpers
- `services/backend/tests/test_coach_tool_response_v2.py` → FOUND (13 tests green)
- `services/backend/tests/test_coach_tool_response_v2_migration.py` → FOUND (9 tests green)
- `services/backend/tests/test_coach_tool_response_migration.py` → FOUND (9 tests green)
- `services/backend/tests/test_coach_tools_scaffolding.py` updated → FOUND (test_models_coach_tools_package_importable widened with V2 set)
- Commits on `dev` branch :
  - `670f3278` test(mint-calc-engine-v1-10): add failing V2 envelope tests... → FOUND
  - `9ce25bff` feat(mint-calc-engine-v1-10): ship CoachToolResponseV2 envelope... → FOUND
  - `455ceee8` test(mint-calc-engine-v1-10): add failing chip-emitter V2 migration tests... → FOUND
  - `4d99175b` feat(mint-calc-engine-v1-10): migrate 5 chip-emitters to V2 envelope... → FOUND
  - `4a3659f9` test(mint-calc-engine-v1-10): add Parallel Change invariant suite... → FOUND

---
*Phase: mint-calc-engine-v1*
*Plan: 10 — W2 CoachToolResponseV2 envelope (Parallel Change V1→V2, Concern B)*
*Completed: 2026-05-16*
