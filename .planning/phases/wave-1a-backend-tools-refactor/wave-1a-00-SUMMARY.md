---
phase: wave-1a
plan: 00
subsystem: backend/coach-tools
tags: [scaffolding, parallel-safety, observability, dispatcher-slots, d-15, panel-reviewed]
provides:
  - "services/backend/app/models/coach_tools/__init__.py (empty Pydantic package marker)"
  - "services/backend/app/services/memory/__init__.py (empty BM25 package marker)"
  - "services/backend/app/services/couple_optimizer/__init__.py (empty port package marker)"
  - "services/backend/app/observability/__init__.py + coach_breadcrumbs.py (emit_coach_tool_breadcrumb, D-15 5-kwarg)"
  - "services/backend/app/utils/hashing.py (hash_profile_id 16-char SHA-256 prefix)"
  - "services/backend/app/core/config.py — 6-flag Wave 1a block (5 OFF + COACH_CAP_CHF_GARDE_ENABLED True)"
  - "services/backend/app/api/v1/endpoints/coach_chat.py — WAVE_1A_DISPATCHER_SLOT_MARKER constant + slot comment block above _format_budget_status + 6 paired dispatcher markers in _execute_internal_tool"
  - "services/backend/tests/test_coach_tools_scaffolding.py (15 tests pin the scaffolding)"
requires:
  - "Python venv with sentry_sdk (optional — emit_coach_tool_breadcrumb is fail-open)"
  - "tools/checks/banned_terms_python.py"
  - "tools/checks/accent_lint_fr.py"
affects:
  - "All Wave 1 plans 01-06: each will marker-anchored-replace one dispatcher branch + insert one _compute_<tool> in the formatters slot. No shared-file write race possible."
  - "Plan-07 parity harness will read the 6 dispatcher branches + slot-resident _compute_* via the marker pairs."
  - "Plan-08 5-gate close will read the SUMMARY.md self-check section."
tech-stack:
  added: ["app.observability (new package)", "app.utils.hashing (new module)"]
  patterns:
    - "Fail-open Sentry breadcrumb wrapper (mirrors turn_cap.py:108 `# type: ignore[union-attr]` idiom)"
    - "Literal['on', 'off'] flag_state per fastapi-pro panel concern #3"
    - "Module-level constant (WAVE_1A_DISPATCHER_SLOT_MARKER) referenced by tests instead of literal grep — rename-resilient"
    - "Marker-anchored replacement (# >>> dispatch: <tool> / # <<< dispatch: <tool>) — race-free parallel plan execution"
    - "Submodule-path import contract for models/coach_tools (plans 01-05 do NOT touch __init__.py — eliminates residual race per fastapi-pro #1)"
key-files:
  created:
    - "services/backend/app/models/coach_tools/__init__.py (7 lines)"
    - "services/backend/app/services/memory/__init__.py (5 lines)"
    - "services/backend/app/services/couple_optimizer/__init__.py (6 lines)"
    - "services/backend/app/observability/__init__.py (1 line)"
    - "services/backend/app/observability/coach_breadcrumbs.py (56 lines)"
    - "services/backend/app/utils/hashing.py (23 lines)"
    - "services/backend/tests/test_coach_tools_scaffolding.py (223 lines, 15 tests)"
  modified:
    - "services/backend/app/core/config.py (+12 lines: 6-flag Wave 1a block after COACH_CITATION_GATE_ENABLED line 91)"
    - "services/backend/app/api/v1/endpoints/coach_chat.py (+34 lines: WAVE_1A_DISPATCHER_SLOT_MARKER constant at line 91 + 12 marker lines wrapping dispatcher branches + 18-line slot comment block above _format_budget_status)"
decisions:
  - "Used `Literal['on', 'off']` for flag_state per fastapi-pro panel concern #3 (mypy + future-BreadcrumbPayload friendly)"
  - "Slot marker exposed as module-level constant `WAVE_1A_DISPATCHER_SLOT_MARKER` so Test 13 references it by symbol (rename-resilient) per architect-review panel concern #5"
  - "Submodule-path import contract for coach_tools per fastapi-pro panel concern #1 — `__init__.py` stays empty (`__all__: list[str] = []`), plans 01-05 import via submodule paths"
  - "`get_regulatory_constant` dispatcher branch INTENTIONALLY left unmarked per CONTEXT D-02 (no Wave 1a refactor)"
  - "Rule 3 deviation: pre-existing `tests/test_coach_tools.py` file shadows the planned `tests/test_coach_tools/` directory at pytest collection time — removed the empty new directory, plans 01-08 will resolve via different subdir name when they need it"
metrics:
  duration_sec: 305
  duration_human: "~5 min 5 sec"
  tasks_completed: 1
  files_created: 7
  files_modified: 2
  tests_added: 15
  pytest_passed: 6736
  pytest_skipped: 62
  pytest_xfailed: 1
  completed: "2026-05-14T14:21:19Z"
requirements:
  - WAVE1A-09 (partial — empty Pydantic package shipped, plans 01-05 populate)
  - WAVE1A-10 (partial — 6 rollback flags shipped with correct defaults)
---

# Phase wave-1a Plan 00: Shared Scaffolding & Insertion Slots Summary

Pure-scaffolding plan that creates the shared insertion-slot files plans 01-06 INSERT into so they can run truly parallel without race conditions on shared files.

## What Shipped

7 new files (5 package markers + 2 helper modules + 1 test file), 2 modified files (config.py flag block + coach_chat.py constant/slot/markers). 15 scaffolding tests pin the shared surface and stay GREEN through Wave 1c so any downstream regression is caught at PR time.

## Files Created (paths + line counts)

| File | Lines |
|---|---:|
| `services/backend/app/models/coach_tools/__init__.py` | 7 |
| `services/backend/app/services/memory/__init__.py` | 5 |
| `services/backend/app/services/couple_optimizer/__init__.py` | 6 |
| `services/backend/app/observability/__init__.py` | 1 |
| `services/backend/app/observability/coach_breadcrumbs.py` | 56 |
| `services/backend/app/utils/hashing.py` | 23 |
| `services/backend/tests/test_coach_tools_scaffolding.py` | 223 |
| **Total** | **321** |

## Files Modified

| File | Change |
|---|---|
| `services/backend/app/core/config.py` | +12 lines — 6-flag Wave 1a block inserted IMMEDIATELY AFTER `COACH_CITATION_GATE_ENABLED: bool = False` (line 91). |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | +34 lines — `WAVE_1A_DISPATCHER_SLOT_MARKER` constant near top of file (after `logger = logging.getLogger(__name__)`), 6 paired `# >>> dispatch: <tool>` / `# <<< dispatch: <tool>` markers in `_execute_internal_tool`, slot comment block ABOVE `_format_budget_status`. |

## Acceptance Criteria — verbatim grep / python3 outputs

### AC1-6 — Import probes (all exit 0)

```
=== AC1: from app.models.coach_tools ===
ok
=== AC2: from app.services.memory ===
ok
=== AC3: from app.services.couple_optimizer ===
ok
=== AC4: emit_coach_tool_breadcrumb ===
ok
=== AC5: hash_profile_id ===
ok
=== AC6: WAVE_1A_DISPATCHER_SLOT_MARKER ===
Wave 1a server-side compute dispatchers (D-08)
```

### AC7 — 6-flag grep count (expect ≥6)

```
$ grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED\|COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED\|COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED\|COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED\|COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED\|COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/core/config.py
6
```

### AC8 — Cap-garde defaults True (expect 1)

```
$ grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py
1
```

### AC9 — Dispatcher slot marker present (expect ≥1, got 2: constant + slot comment header)

```
$ grep -c "Wave 1a server-side compute dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py
2
```

### AC10 — Slot closing marker (expect ≥1)

```
$ grep -c "end Wave 1a dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py
1
```

### AC11 — Opening dispatch markers (expect exactly 6)

```
$ grep -c "# >>> dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py
6
```

### AC12 — Closing dispatch markers (expect exactly 6)

```
$ grep -c "# <<< dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py
6
```

### AC13 — flag_state typed as Literal['on', 'off'] (expect ≥1, got 2: import + signature)

```
$ grep -c 'Literal\["on", "off"\]' services/backend/app/observability/coach_breadcrumbs.py
2
```

### AC14 — Scaffolding tests collected + passed (expect ≥15)

```
$ python3 -m pytest tests/test_coach_tools_scaffolding.py -v
collecting ... collected 15 items
tests/test_coach_tools_scaffolding.py::test_flag_budget_default_off PASSED [  6%]
tests/test_coach_tools_scaffolding.py::test_flag_retirement_projection_default_off PASSED [ 13%]
tests/test_coach_tools_scaffolding.py::test_flag_cross_pillar_default_off PASSED [ 20%]
tests/test_coach_tools_scaffolding.py::test_flag_couple_optimization_default_off PASSED [ 26%]
tests/test_coach_tools_scaffolding.py::test_flag_retrieve_memories_default_off PASSED [ 33%]
tests/test_coach_tools_scaffolding.py::test_flag_cap_chf_garde_default_on PASSED [ 40%]
tests/test_coach_tools_scaffolding.py::test_emit_coach_tool_breadcrumb_importable PASSED [ 46%]
tests/test_coach_tools_scaffolding.py::test_hash_profile_id_importable_and_deterministic PASSED [ 53%]
tests/test_coach_tools_scaffolding.py::test_models_coach_tools_package_importable PASSED [ 60%]
tests/test_coach_tools_scaffolding.py::test_services_memory_package_importable PASSED [ 66%]
tests/test_coach_tools_scaffolding.py::test_services_couple_optimizer_package_importable PASSED [ 73%]
tests/test_coach_tools_scaffolding.py::test_emit_coach_tool_breadcrumb_fail_open_when_sentry_none PASSED [ 80%]
tests/test_coach_tools_scaffolding.py::test_dispatcher_slot_marker_constant_present_in_file PASSED [ 86%]
tests/test_coach_tools_scaffolding.py::test_emit_coach_tool_breadcrumb_signature_matches_d15 PASSED [ 93%]
tests/test_coach_tools_scaffolding.py::test_dispatcher_branches_have_six_paired_markers PASSED [100%]
============================== 15 passed in 0.23s ==============================
```

### AC15 — Banned-terms lint on 4 touched files (expect exit 0)

```
$ python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/utils/hashing.py services/backend/app/core/config.py services/backend/app/api/v1/endpoints/coach_chat.py
services/backend/app/api/v1/endpoints/coach_chat.py:3190: banned term 'assure':                     _facts.append(f"- Salaire assure LPP: {int(_d['lppInsuredSalary']):,} CHF".replace(",", "'"))
EXIT=0
```

Caveat: the lone `assure` informational warning at coach_chat.py:3190 is PRE-EXISTING (not introduced by this plan) and the linter exits 0 — informational only.

### AC16 — Accent lint on 3 backend files (expect exit 0)

```
$ for f in coach_breadcrumbs.py hashing.py config.py; do python3 tools/checks/accent_lint_fr.py --file "$f"; done
EXIT=0  (for all three)
```

Caveat: `accent_lint_fr.py` takes `--file` flag (not positional). coach_chat.py is excluded from this check because the changes to it are pure dispatch markers + slot comments + module constant (no user-facing FR text touched).

## Full backend pytest tail (zero regressions)

```
........................................................................ [ 99%]
..............................                                           [100%]
=============================== warnings summary ===============================
tests/test_dag_invalidation/test_hash_parity.py:51
  /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/tests/test_dag_invalidation/test_hash_parity.py:51: PytestUnknownMarkWarning: Unknown pytest.mark.integration - is this a typo?  ...
-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
6736 passed, 62 skipped, 1 xfailed, 1 warning in 111.94s (0:01:51)
```

Evidence: 6736 passed includes the +15 new scaffolding tests. Phase 94 byte-identity (181) + Phase 95 (74) byte-identity tests are inside that count — not introduced regressions.
Caveat: I did NOT run `flutter test` because Wave 1a is backend-only per CONTEXT D-10 (no UI / no ARB diff). G2 device walkthrough is owned by plan-08 close-out.

## Panel Concerns Addressed (peer review 2026-05-14, 7 fixes)

| Panel concern | Fix shipped | File:line proof |
|---|---|---|
| architect-review #1 (obs-e9e2d0bd98109f74) — dispatcher branches race | 6 paired `# >>> dispatch: <tool>` / `# <<< dispatch: <tool>` markers wrapping each of the 6 race-hot `if name == "get_<tool>":` branches | `services/backend/app/api/v1/endpoints/coach_chat.py:1902-1942` — 12 marker lines, verified by `grep -c "# >>> dispatch: "` = 6 + `grep -c "# <<< dispatch: "` = 6 + Test 15 |
| architect-review #5 (obs-e9e2d0bd98109f74) — slot marker as module-level constant | `WAVE_1A_DISPATCHER_SLOT_MARKER = "Wave 1a server-side compute dispatchers (D-08)"` exposed near imports | `services/backend/app/api/v1/endpoints/coach_chat.py:92-94` (after `logger = logging.getLogger(__name__)`) — verified by Test 13 (imports constant + asserts value present in file text) |
| architect-review #6 (obs-e9e2d0bd98109f74) — D-15 signature pin | Test 14 asserts `inspect.signature(emit_coach_tool_breadcrumb).parameters` keys equal `["tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"]` exactly | `services/backend/tests/test_coach_tools_scaffolding.py:170-186` |
| fastapi-pro #1 (obs-6e5fc30cfda5d508) — submodule-path import contract | `app/models/coach_tools/__init__.py` ships `__all__: list[str] = []` and stays EMPTY ; plans 01-05 import from submodule paths | `services/backend/app/models/coach_tools/__init__.py:7` |
| fastapi-pro #3 (obs-6e5fc30cfda5d508) — `flag_state: Literal["on", "off"]` | `from typing import Literal` + `flag_state: Literal["on", "off"]` parameter type annotation in `emit_coach_tool_breadcrumb` | `services/backend/app/observability/coach_breadcrumbs.py:21,38` — verified by `grep -c 'Literal\["on", "off"\]'` = 2 |
| fastapi-pro/idiom — `# type: ignore[union-attr]` on sentry call | `sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]` matches `turn_cap.py:108` | `services/backend/app/observability/coach_breadcrumbs.py:48` |
| backend-architect (obs-5b399b61f20f0201) — hash_profile_id distinct from compute_inputs_hash | Docstring explicitly cites the distinction (profile_id vs profile SLICE) | `services/backend/app/utils/hashing.py:14-19` |

Panel synthesis obs_id reference: `obs-57a2b5ce9777368b`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Empty `tests/test_coach_tools/` directory removed**

- **Found during:** running full backend pytest after creating the directory per Step I
- **Issue:** pre-existing `services/backend/tests/test_coach_tools.py` (file) collides with the planned new `services/backend/tests/test_coach_tools/` (directory) at pytest collection time — Python module-name conflict (`tests.test_coach_tools` resolves to either the file or the package, not both):
  ```
  ERROR collecting tests/test_coach_tools.py
  import file mismatch:
  imported module 'tests.test_coach_tools' has this __file__ attribute:
    /Users/.../services/backend/tests/test_coach_tools
  which is not the same as the test file we want to collect:
    /Users/.../services/backend/tests/test_coach_tools.py
  ```
- **Fix:** removed the empty new directory (`rm -rf services/backend/tests/test_coach_tools`). Pytest then collected 6736 tests cleanly.
- **Scope impact:** the directory was planned as a pytest discovery marker for "test_coach_tools/ subdirectory plans 01-08 populate". Plans 01-08 will resolve the naming collision themselves when they need to add per-tool tests — they can use `tests/test_coach_tools_pkg/` or move the existing `tests/test_coach_tools.py` into the dir as `tests/test_coach_tools/test_definitions.py`. Either fix is outside plan-00 scope.
- **Files modified:** none (the directory removal is below the file-system level of the diff stat)
- **Acceptance criteria still satisfied:** the empty dir was not referenced by any of the 16 listed acceptance criteria, so removing it does not invalidate any AC.

No other deviations — plan executed as written for the other 10 steps (A-K).

## Self-Check: PASSED

Evidence per CLAUDE.md §9 0-trust:

- Full backend pytest output (cited verbatim above): `6736 passed, 62 skipped, 1 xfailed, 1 warning in 111.94s` — includes +15 new scaffolding tests + Phase 94/95 byte-identity preserved.
- Scaffolding tests verbose output (15/15 PASSED, cited verbatim under AC14).
- All 16 acceptance criteria grep / python3 / pytest outputs cited verbatim above.
- 6 paired dispatcher markers grep-verified (AC11+AC12 = 6+6 = 12 marker lines).
- D-15 signature pin via `inspect.signature` enforced by Test 14 (PASSED).
- Slot marker via module-level constant referenced by Test 13 (PASSED) — rename-resilient.
- `git diff --stat services/backend/`: 2 files changed, 46 insertions (+) — surgical scope, no adjacent-code refactor (Karpathy #3).
- Linters: `banned_terms_python.py` EXIT=0 (pre-existing line 3190 warning, not introduced) ; `accent_lint_fr.py --file` EXIT=0 on the 3 backend files.

Caveat: I have NOT run `flutter test` (Wave 1a is backend-only per CONTEXT D-10), and I have NOT run a Maestro / device walkthrough (G1/G2 are scoped to plan-08 5-gate close-out, not plan-00). I have NOT pushed any commit to origin — per task instructions, orchestrator decides push timing. STATE.md and ROADMAP.md were NOT updated — orchestrator owns those writes.
