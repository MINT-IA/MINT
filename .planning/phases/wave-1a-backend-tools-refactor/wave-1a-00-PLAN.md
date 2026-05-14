---
phase: wave-1a
plan: 00
type: execute
wave: 0
depends_on: []
files_modified:
  - services/backend/app/models/coach_tools/__init__.py
  - services/backend/app/services/memory/__init__.py
  - services/backend/app/services/couple_optimizer/__init__.py
  - services/backend/app/core/config.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/app/observability/__init__.py
  - services/backend/app/observability/coach_breadcrumbs.py
  - services/backend/app/utils/hashing.py
  - services/backend/tests/test_coach_tools/__init__.py
  - services/backend/tests/test_coach_tools_scaffolding.py
autonomous: true
requirements: [WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Pure-scaffolding plan: creates the shared insertion-slot files plans 01-06 INSERT into. No business logic, no compute, no Pydantic models with fields beyond what is shared."
    - "All 6 server-side rollout flags exist in settings.py with correct defaults (5 OFF, cap-garde ON) — single source of truth"
    - "emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state) helper exists and is importable — guarantees uniform Sentry payload per D-15"
    - "hash_profile_id(profile_id) -> 16-char SHA-256 prefix helper exists and is importable"
    - "Empty Pydantic package + memory package + couple_optimizer package directories exist with __init__.py markers — plans 01-05 APPEND to these without conflict"
    - "coach_chat.py has clearly-delimited dispatcher slot comment block — plans 01-06 INSERT their _compute_<tool>() functions inside the slot"
    - "coach_chat.py dispatcher BRANCHES block (~lines 1898-1928) has per-tool labeled markers (`# >>> dispatch: get_<tool>` / `# <<< dispatch: get_<tool>`) — plans 01-06 each REPLACE the labeled section for their tool only, no race possible (panel fix: architect-review concern #1)"
    - "Plans 01-05 do NOT edit app/models/coach_tools/__init__.py — consumers in coach_chat.py import from submodule path: `from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse`. Eliminates residual parallel-write race on package init (panel fix: fastapi-pro concern #1)"
    - "coach_chat.py exposes a module-level constant `WAVE_1A_DISPATCHER_SLOT_MARKER` whose value matches the slot comment header — Test 14 asserts via constant, robust to rename (panel fix: architect-review concern #5)"
  artifacts:
    - path: "services/backend/app/models/coach_tools/__init__.py"
      provides: "Empty Pydantic package marker — plans 01-05 append per-tool response model imports"
      contains: "Wave 1a coach-tools response models"
    - path: "services/backend/app/services/memory/__init__.py"
      provides: "Empty memory package — plan-05 fills it with BM25 retrieve"
      contains: "Wave 1a"
    - path: "services/backend/app/services/couple_optimizer/__init__.py"
      provides: "Empty couple_optimizer package — plan-04 fills it with the Python port"
      contains: "Wave 1a"
    - path: "services/backend/app/core/config.py"
      provides: "All 6 Wave 1a flags added together: COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED + _RETIREMENT_PROJECTION_ENABLED + _CROSS_PILLAR_ENABLED + _COUPLE_OPTIMIZATION_ENABLED + _RETRIEVE_MEMORIES_ENABLED + COACH_CAP_CHF_GARDE_ENABLED (default True)"
      contains: "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "Delimited dispatcher slot comment block at the top of the formatters region (around line 2240) for plans 01-06 to insert into"
      contains: "Wave 1a server-side compute dispatchers"
    - path: "services/backend/app/observability/coach_breadcrumbs.py"
      provides: "emit_coach_tool_breadcrumb helper — uniform Sentry payload per D-15"
      contains: "def emit_coach_tool_breadcrumb"
    - path: "services/backend/app/utils/hashing.py"
      provides: "hash_profile_id helper — first 16 hex chars of SHA-256"
      contains: "def hash_profile_id"
    - path: "services/backend/tests/test_coach_tools_scaffolding.py"
      provides: "≥6 tests asserting all 6 flags exist with correct defaults + breadcrumb helper importable + hash helper deterministic"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/observability/coach_breadcrumbs.py"
      to: "sentry_sdk"
      via: "fail-open wrapper around sentry_sdk.add_breadcrumb"
      pattern: "sentry_sdk.add_breadcrumb"
    - from: "services/backend/app/utils/hashing.py"
      to: "hashlib.sha256"
      via: "16-char hex prefix of SHA-256"
      pattern: "hashlib.sha256"
---

<objective>
Wave 0 pure-scaffolding plan. Creates the shared insertion-slot files that plans 01-06 INSERT into so they can run truly parallel without race conditions on shared files.

Per checker iteration-1 issue #1: plans 01-06 declared `wave: 1, depends_on: []` (parallel) yet all 6 simultaneously wrote to `coach_chat.py`, `config.py`, and `models/coach_tools/__init__.py`. Wave 0 fixes this by establishing the slots upfront — Wave 1 then becomes truly parallel-safe.

Per checker iteration-1 issue #2: the per-tool Sentry breadcrumb payload was incomplete (missing `profile_id_hashed`, `elapsed_ms` per D-15). Wave 0 ships a single `emit_coach_tool_breadcrumb()` helper plans 01-05 ALL call — uniform payload, single source of truth.

Purpose: enable safe parallel execution of plans 01-06 + enforce D-15 payload uniformity.
Output: scaffolded files + shared helpers + 6+ scaffolding tests.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/core/config.py
@services/backend/app/services/coach/turn_cap.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Settings placement reference (mirror this pattern — read services/backend/app/core/config.py lines 60-95):
```python
COACH_CITATION_GATE_ENABLED: bool = False
```
The 6 Wave 1a flags are inserted as a single block immediately after the existing COACH_CITATION_GATE_ENABLED line.

Sentry breadcrumb reference (the existing pattern that emit_coach_tool_breadcrumb wraps):
File services/backend/app/services/coach/turn_cap.py lines 105-118:
```python
if sentry_sdk is None:
    return
try:
    sentry_sdk.add_breadcrumb(
        category="coach.tool.budget_status",
        message="invoked",
        level="info",
        data={"inputs_hash": ..., "flag_state": "on"},
    )
except Exception:
    pass
```

D-15 contract (verbatim from CONTEXT.md):
"Each server-side tool path emits coach.tool.<name>.invoked with inputs_hash, profile_id_hashed, elapsed_ms, flag_state (ON/OFF)."

emit_coach_tool_breadcrumb signature (this plan creates it):
```python
from typing import Literal

def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: Literal["on", "off"],
) -> None:
    """Fail-open Sentry breadcrumb emitter for Wave 1a coach tools (D-15)."""
```
Note: `flag_state` is `Literal["on", "off"]` per project idiom (config.py:102, :113) — mypy-friendly + Pydantic-friendly + future-BreadcrumbPayload-friendly (panel fix: fastapi-pro concern #3).

hash_profile_id signature:
```python
def hash_profile_id(profile_id: str) -> str:
    """First 16 hex chars of SHA-256(profile_id). Irreversible. Per D-15."""
```

Dispatcher slot placement reference:
File services/backend/app/api/v1/endpoints/coach_chat.py — the FORMATTERS slot is inserted at line 2248 (blank line ABOVE `def _format_budget_status:` which starts at line 2249, verified).

Dispatcher BRANCHES block reference (the actual race-hot region per architect-review concern #1):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 1898-1928. Each of plans 01-06 needs to mutate ONE `if name == "get_<tool>":` branch in this 30-line span. Plan-00 wraps each branch with paired markers so plans 01-06 each REPLACE the marker-delimited section for their tool only:
```python
# >>> dispatch: get_budget_status
if name == "get_budget_status":
    return _format_budget_status(ctx)
# <<< dispatch: get_budget_status
```
Six pairs total (retrieve_memories, get_budget_status, get_retirement_projection, get_cross_pillar_analysis, get_cap_status, get_couple_optimization). `get_regulatory_constant` is left unmarked (no Wave 1a refactor per CONTEXT D-02).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create empty package directories + shared helpers + dispatcher slot + flag block + scaffolding tests</name>
  <read_first>
    - services/backend/app/core/config.py (FULL — confirm Settings class structure + COACH_CITATION_GATE_ENABLED line position)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1890-1940 (dispatcher BRANCHES block — verify the 6 `if name == "get_<tool>":` branches; markers go here per Step K)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2240-2270 (top of formatters region — insertion at line 2248, ABOVE `def _format_budget_status` at line 2249)
    - services/backend/app/services/coach/turn_cap.py lines 100-125 (sentry breadcrumb fail-open pattern + `# type: ignore[union-attr]` idiom on line 108)
    - services/backend/app/services/coach/inputs_hash.py (confirm `compute_inputs_hash` exists — hash_profile_id is a DIFFERENT helper, hashes profile_id not profile slice)
    - services/backend/app/observability/ (check if directory exists — if yes, only add coach_breadcrumbs.py; if no, create __init__.py too)
    - services/backend/app/utils/hashing.py (check if exists — if yes, extend with hash_profile_id; if no, create)
    - services/backend/tests/conftest.py (existing test config — confirm pytest discovery picks up tests/test_coach_tools_scaffolding.py)
    - grep `def hash_profile_id` services/backend/ (confirm no pre-existing helper to avoid duplication)
  </read_first>
  <files>
    - services/backend/app/models/coach_tools/__init__.py (create — empty marker)
    - services/backend/app/services/memory/__init__.py (create — empty marker)
    - services/backend/app/services/couple_optimizer/__init__.py (create — empty marker)
    - services/backend/app/observability/__init__.py (create OR confirm exists)
    - services/backend/app/observability/coach_breadcrumbs.py (create)
    - services/backend/app/utils/hashing.py (create OR extend)
    - services/backend/app/core/config.py (modify — add 6-flag block in one insertion)
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — add dispatcher slot comment block)
    - services/backend/tests/test_coach_tools/__init__.py (create — empty pytest discovery marker)
    - services/backend/tests/test_coach_tools_scaffolding.py (create)
  </files>
  <behavior>
    - Test 1: `settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED is False` (default OFF).
    - Test 2: `settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED is False`.
    - Test 3: `settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False`.
    - Test 4: `settings.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED is False`.
    - Test 5: `settings.COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED is False`.
    - Test 6: `settings.COACH_CAP_CHF_GARDE_ENABLED is True` (default ON per D-09).
    - Test 7: `from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb` succeeds.
    - Test 8: `from app.utils.hashing import hash_profile_id` succeeds; `hash_profile_id("user_abc")` returns a 16-char hex string; calling twice with the same input returns the same hash (determinism).
    - Test 9: `from app.models.coach_tools import *` succeeds (empty module imports without error).
    - Test 10: `from app.services.memory import *` succeeds (empty module imports without error).
    - Test 11: `from app.services.couple_optimizer import *` succeeds.
    - Test 12: `emit_coach_tool_breadcrumb("budget_status", "a"*64, "1234567890abcdef", 42, "on")` does NOT raise — fail-open guarantee even if sentry_sdk is unavailable.
    - Test 13: SCAFFOLD-WIRING — `from app.api.v1.endpoints.coach_chat import WAVE_1A_DISPATCHER_SLOT_MARKER` succeeds AND `coach_chat.py` file content contains the constant's value. Asserts via constant (not literal grep) so rename refactors stay safe. Prevents threat T-WAVE1A-00-01.
    - Test 14: SIGNATURE-PIN D-15 — `inspect.signature(emit_coach_tool_breadcrumb).parameters` keys == `["tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"]` exactly (5 params, ordered). Prevents silent payload drift across plans 01-05 (panel fix: architect-review concern #6).
    - Test 15: DISPATCHER-MARKERS — `coach_chat.py` contains all 6 `# >>> dispatch: get_<tool>` and matching `# <<< dispatch: get_<tool>` markers (12 lines total) for budget_status, retirement_projection, cross_pillar_analysis, cap_status, couple_optimization, retrieve_memories. Prevents Wave 1 plans 01-06 merge-conflict in dispatcher branches (panel fix: architect-review concern #1).
  </behavior>
  <action>
    Step A — Create `services/backend/app/models/coach_tools/__init__.py` (verbatim):
    ```python
    """Wave 1a coach-tools response models — Pydantic v2 camelCase per D-03.

    Plans 01-05 each append their per-tool response model import to this
    module. Wave 0 (this plan) ships only the empty marker so plans 01-05
    can append without race conditions during parallel execution.
    """
    __all__: list[str] = []
    ```

    Step B — Create `services/backend/app/services/memory/__init__.py` (verbatim):
    ```python
    """Wave 1a memory retrieval package — Karpathy wiki, NOT vector RAG.

    Plan-05 fills this package with BM25 retrieve over CoachInsightRecord.
    Wave 0 (this plan) ships the empty marker.
    """
    ```

    Step C — Create `services/backend/app/services/couple_optimizer/__init__.py` (verbatim):
    ```python
    """Wave 1a couple_optimizer package — Python port of Flutter source.

    Plan-04 fills this package with the 1:1 port of
    apps/mobile/lib/services/financial_core/couple_optimizer.dart.
    Wave 0 (this plan) ships the empty marker.
    """
    ```

    Step D — If `services/backend/app/observability/__init__.py` does NOT already exist, create it with content:
    ```python
    """Wave 1a observability helpers — Sentry breadcrumb wrappers for coach tools."""
    ```
    If it already exists, leave it untouched.

    Step E — Create `services/backend/app/observability/coach_breadcrumbs.py`:
    ```python
    """Wave 1a D-15 — uniform Sentry breadcrumb emitter for coach server-side tools.

    Every _compute_<tool> path in plans 01-05 calls emit_coach_tool_breadcrumb
    with the EXACT 5-kwarg payload mandated by D-15:
      - tool_name        : str  — e.g. "budget_status"
      - inputs_hash      : str  — 64-char hex SHA-256 of profile slice
      - profile_id_hashed: str  — 16-char hex SHA-256 prefix (irreversible)
      - elapsed_ms       : int  — wall-clock ms for the compute path
      - flag_state       : Literal["on", "off"] — staged-rollout flag state

    The `coach.tool.*` breadcrumb category prefix is locked at scaffolding time.
    Non-tool coach paths need their own helper. Plan-06 (cap_status garde) does
    NOT use this helper — it has its own coach.cap.cap_chf_uncited breadcrumb
    with snippet payload (D-09).
    """
    from __future__ import annotations
    from typing import Literal

    try:
        import sentry_sdk  # type: ignore
    except Exception:  # pragma: no cover — fail-open if SDK unavailable
        sentry_sdk = None  # type: ignore


    def emit_coach_tool_breadcrumb(
        tool_name: str,
        inputs_hash: str,
        profile_id_hashed: str,
        elapsed_ms: int,
        flag_state: Literal["on", "off"],
    ) -> None:
        """Fail-open Sentry breadcrumb for Wave 1a coach tools.

        Payload is non-PII by construction:
          - inputs_hash : SHA-256 of canonical-JSON profile slice (irreversible).
          - profile_id_hashed : 16-char SHA-256 prefix (irreversible).
          - elapsed_ms, flag_state : scalar telemetry.
        """
        if sentry_sdk is None:
            return
        try:
            sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]
                category=f"coach.tool.{tool_name}",
                message="invoked",
                level="info",
                data={
                    "inputs_hash": inputs_hash,
                    "profile_id_hashed": profile_id_hashed,
                    "elapsed_ms": elapsed_ms,
                    "flag_state": flag_state,
                },
            )
        except Exception:
            # Never let telemetry break the coach response path.
            pass
    ```

    Step F — Create or extend `services/backend/app/utils/hashing.py`. If the file does NOT exist:
    ```python
    """Wave 1a D-15 — hashing helpers for coach observability."""
    from __future__ import annotations
    import hashlib


    def hash_profile_id(profile_id: str) -> str:
        """First 16 hex chars of SHA-256(profile_id).

        Used as the non-PII profile identifier in coach Sentry breadcrumbs
        (D-15). 16 chars = 64 bits of entropy — collision-safe at MINT scale
        and irreversible (cannot recover profile_id from the prefix).
        """
        return hashlib.sha256(profile_id.encode("utf-8")).hexdigest()[:16]
    ```
    If the file exists, append the `hash_profile_id` function only — do not touch other helpers.

    Step G — `services/backend/app/core/config.py` — locate the existing line `COACH_CITATION_GATE_ENABLED: bool = False` (around line 91) and INSERT the 6-flag Wave 1a block IMMEDIATELY AFTER it (single insertion, single source of truth):
    ```python
        # === Wave 1a server-side compute rollback flags (D-05, D-09) ===
        # Plans 01-06 READ these flags but do NOT add new ones.
        # Defaults: 5 per-tool flags OFF (staged rollout), cap-garde ON.
        # Staging env enables the 5 OFF flags during Wave 1c validation.
        COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED: bool = False
        COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED: bool = False
        COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED: bool = False
        COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED: bool = False
        COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED: bool = False
        COACH_CAP_CHF_GARDE_ENABLED: bool = True
        # === end Wave 1a flags ===
    ```

    Step H — `services/backend/app/api/v1/endpoints/coach_chat.py` — locate the top of the formatters region at LINE 2248 (blank line ABOVE the existing `def _format_budget_status(ctx: dict) -> str:` which starts at line 2249 — VERIFIED). Two changes here:

    H.1 — Add a module-level constant near the top of the file imports region (idiomatic location: right after the existing imports block, BEFORE the first function definition). This constant pins the slot marker so Test 13 can reference it by symbol, not literal grep (panel fix: architect-review concern #5):
    ```python
    # Wave 1a — slot marker constant referenced by tests/test_coach_tools_scaffolding.py (Test 13).
    # If you rename the slot, update this constant AND the slot comment block below in sync.
    WAVE_1A_DISPATCHER_SLOT_MARKER = "Wave 1a server-side compute dispatchers (D-08)"
    ```

    H.2 — At line 2248 (above `_format_budget_status`), INSERT the following delimited comment block. The header line EXACTLY matches `WAVE_1A_DISPATCHER_SLOT_MARKER` from H.1:
    ```python
    # === Wave 1a server-side compute dispatchers (D-08) ===
    # Plans 01-05 each insert their _compute_<tool_name>() function below
    # this comment block, ABOVE the matching legacy _format_<tool_name>().
    # Plan-06 inserts its _validate_cap_response() middleware here too.
    # Each _compute_* calls _format_<tool>(ctx) when flag OFF — forward reference
    # is intentional (Python resolves at call time), do not reorder.
    # Each _compute_* path:
    #   1. Checks settings.COACH_TOOL_SERVER_SIDE_<NAME>_ENABLED flag.
    #   2. Falls back to legacy _format_<name>(ctx) when flag OFF.
    #   3. Computes via app.services.* (chained per CONTEXT D-02).
    #   4. Wraps in Pydantic response with inputs_hash + computed_at.
    #   5. Emits Sentry breadcrumb via
    #      app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb
    #      (D-15: tool_name, inputs_hash, profile_id_hashed, elapsed_ms,
    #      flag_state). NEVER ad-hoc sentry_sdk.add_breadcrumb in _compute_*.
    # === end Wave 1a dispatchers ===
    ```

    Step I — Create `services/backend/tests/test_coach_tools/__init__.py` (empty file — pytest discovery marker for the test_coach_tools/ subdirectory plans 01-08 populate).

    Step J — Create `services/backend/tests/test_coach_tools_scaffolding.py` with the 15 tests from `<behavior>`. Test 12 mocks `sentry_sdk` to None and confirms `emit_coach_tool_breadcrumb` does not raise. Test 13 imports `WAVE_1A_DISPATCHER_SLOT_MARKER` from `app.api.v1.endpoints.coach_chat` and asserts its value appears in the file's text. Test 14 uses `inspect.signature(emit_coach_tool_breadcrumb).parameters` to pin the exact 5-kwarg D-15 contract. Test 15 reads `coach_chat.py` and asserts all 6 `# >>> dispatch: get_<tool>` / `# <<< dispatch: get_<tool>` marker pairs are present (12 marker lines, 6 tools).

    Step K — `services/backend/app/api/v1/endpoints/coach_chat.py` — wrap each of the 6 dispatcher branches at lines 1898-1928 with paired markers. PANEL FIX (architect-review concern #1): plans 01-06 all mutate this 30-line span; without per-tool markers, parallel execution races on coach_chat.py. With markers, each plan does a marker-anchored replace touching only its tool's section. Resulting file (sequence-correct):
    ```python
        # >>> dispatch: retrieve_memories
        if name == "retrieve_memories":
            import re
            raw_topic = tool_input.get("topic", "")
            # BUG-B fix: sanitize topic to prevent prompt injection via LLM tool_use.
            safe_topic = raw_topic if re.match(r'^[\w\s\-\.]{1,100}$', raw_topic, re.UNICODE) else ""
            return _handle_retrieve_memories(
                topic=safe_topic,
                memory_block=memory_block,
                max_results=min(tool_input.get("max_results", 3), 10),
                user_id=user_id,
                db=db,
            )
        # <<< dispatch: retrieve_memories

        # >>> dispatch: get_budget_status
        if name == "get_budget_status":
            return _format_budget_status(ctx)
        # <<< dispatch: get_budget_status

        # >>> dispatch: get_retirement_projection
        if name == "get_retirement_projection":
            return _format_retirement_projection(ctx)
        # <<< dispatch: get_retirement_projection

        # >>> dispatch: get_cross_pillar_analysis
        if name == "get_cross_pillar_analysis":
            return _format_cross_pillar_analysis(ctx)
        # <<< dispatch: get_cross_pillar_analysis

        # >>> dispatch: get_cap_status
        if name == "get_cap_status":
            return _format_cap_status(ctx)
        # <<< dispatch: get_cap_status

        # >>> dispatch: get_couple_optimization
        if name == "get_couple_optimization":
            return _format_couple_optimization(ctx)
        # <<< dispatch: get_couple_optimization
    ```
    `get_regulatory_constant` branch at line 1927-1928 is intentionally LEFT UNMARKED — no Wave 1a refactor per CONTEXT D-02. The 6 marker pairs are the contract for plans 01-06; plan-05 owns `retrieve_memories`, plan-01 owns `get_budget_status`, plan-02 owns `get_retirement_projection`, plan-03 owns `get_cross_pillar_analysis`, plan-06 owns `get_cap_status`, plan-04 owns `get_couple_optimization`.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_scaffolding.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/utils/hashing.py services/backend/app/core/config.py services/backend/app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.models.coach_tools import *; print('ok')"` exits 0.
    - `python3 -c "from app.services.memory import *; print('ok')"` exits 0.
    - `python3 -c "from app.services.couple_optimizer import *; print('ok')"` exits 0.
    - `python3 -c "from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb; print('ok')"` exits 0.
    - `python3 -c "from app.utils.hashing import hash_profile_id; assert len(hash_profile_id('x')) == 16; print('ok')"` exits 0.
    - `python3 -c "from app.api.v1.endpoints.coach_chat import WAVE_1A_DISPATCHER_SLOT_MARKER; print(WAVE_1A_DISPATCHER_SLOT_MARKER)"` exits 0 and prints `Wave 1a server-side compute dispatchers (D-08)`.
    - `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED\|COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED\|COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED\|COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED\|COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED\|COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/core/config.py` returns ≥6.
    - `grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py` returns 1 (cap-garde default ON — NOT False).
    - `grep -c "Wave 1a server-side compute dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (dispatcher slot marker present).
    - `grep -c "end Wave 1a dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (slot closing marker present).
    - `grep -c "# >>> dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 6 (6 opening dispatcher markers, panel fix).
    - `grep -c "# <<< dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 6 (6 closing dispatcher markers, panel fix).
    - `grep -c "Literal\[\"on\", \"off\"\]" services/backend/app/observability/coach_breadcrumbs.py` returns ≥1 (flag_state typed per panel fix fastapi-pro #3).
    - `pytest services/backend/tests/test_coach_tools_scaffolding.py -q` exits 0 with ≥15 tests collected.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/utils/hashing.py services/backend/app/core/config.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
  </acceptance_criteria>
  <done>
    All 6 flags exist with correct defaults; helpers importable; package markers present; formatters-region dispatcher slot delimited; dispatcher BRANCHES wrapped with 6 paired tool markers (panel race fix); WAVE_1A_DISPATCHER_SLOT_MARKER module-level constant exposed; D-15 signature pinned via Test 14; ≥15 scaffolding tests green. Plans 01-06 can now run truly parallel — they each marker-anchored-replace exactly one dispatcher branch + insert their _compute_<tool> in the formatters slot.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Wave 0 → Wave 1 parallel plans | Wave 0 establishes single-source-of-truth slots; Wave 1 plans only APPEND/INSERT into those slots — no shared-file race possible. |
| coach_breadcrumbs.py → sentry_sdk | Outbound telemetry; non-PII by construction (hashes only). |
| hash_profile_id → SHA-256 | Cryptographic one-way function; first-16-chars prefix is irreversible. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-00-01 | T (Tampering) | Scaffold-only plan introduces unused code if downstream plans never land | mitigate | Test 13 SCAFFOLD-WIRING imports `WAVE_1A_DISPATCHER_SLOT_MARKER` from coach_chat.py and asserts its value appears in the file text — rename-resilient (panel fix architect-review #5). Test 14 SIGNATURE-PIN asserts the D-15 5-kwarg contract via `inspect.signature` — guards against silent payload drift (panel fix architect-review #6). Test 15 DISPATCHER-MARKERS asserts the 6 paired `# >>> dispatch:` / `# <<< dispatch:` markers exist — guards against marker removal that would re-introduce the Wave 1 race. Tests 1-6 assert all 6 flags exist + 7-12 assert helpers importable. These 15 tests STAY GREEN through Wave 1c, so if a downstream plan accidentally rips out the scaffolding, this plan's tests fail and CI catches it. |
| T-WAVE1A-00-06 | T | Plans 01-06 race on coach_chat.py dispatcher branches block (lines 1898-1928) — 6 parallel edits to the same 30-line span | mitigate | Step K wraps each of the 6 dispatcher branches with paired `# >>> dispatch: get_<tool>` / `# <<< dispatch: get_<tool>` markers. Plans 01-06 each do a marker-anchored replace touching ONLY their tool's section. Test 15 asserts the 12 marker lines remain in place. Without this fix, the Wave 1 "truly parallel-safe" promise would fail (panel fix architect-review #1 + fastapi-pro #1). |
| T-WAVE1A-00-02 | I (Information disclosure) | hash_profile_id leak via short hash collision | accept | 16-char hex = 64 bits of entropy. Collision probability at MINT scale (<10^6 profiles) is negligible (≈ 10^-9). Cannot recover profile_id from the prefix (SHA-256 preimage resistance). |
| T-WAVE1A-00-03 | I | coach_breadcrumbs leaks PII via tool_name or inputs_hash | mitigate | tool_name is hardcoded ENUM-like string ("budget_status" etc.) chosen by plans 01-05 — no user data. inputs_hash is SHA-256 of profile slice — irreversible. Test payload structure asserted in scaffolding test 12. |
| T-WAVE1A-00-04 | T | Flag defaults drift (someone changes False → True on prod) | mitigate | Test 1-6 PIN the exact default values. Any drift = test failure on next CI run. |
| T-WAVE1A-00-05 | E (Elevation of privilege) | emit_coach_tool_breadcrumb crashes the coach response path if sentry_sdk raises | mitigate | Try/except wraps the entire sentry_sdk call. Test 12 asserts no raise when sentry_sdk is None. Fail-open guarantee. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools_scaffolding.py -q` exits 0 with ≥15 tests.
- `pytest services/backend/ -q` full suite — zero regressions (this plan adds tests, modifies only config.py + comment block + dispatcher branch markers in coach_chat.py).
- `banned_terms_python.py` green on touched files.
- All 6 flag defaults asserted by tests 1-6.
- Dispatcher formatters-slot marker present (grep proof) + WAVE_1A_DISPATCHER_SLOT_MARKER constant importable.
- 6 dispatcher-branches `# >>> dispatch:` and `# <<< dispatch:` marker pairs present (Test 15 + grep proof).
- D-15 signature pinned via Test 14 (`inspect.signature`).
- Helpers importable from their final paths.
</verification>

<success_criteria>
- WAVE1A-09 partially satisfied: empty Pydantic `app.models.coach_tools` package exists; plans 01-05 will populate it (via submodule-path imports — they do NOT edit `__init__.py`).
- WAVE1A-10 partially satisfied: all 6 rollback flags exist with correct defaults in settings.py.
- Race-condition mitigation (DUAL): plans 01-06 (a) INSERT `_compute_<tool>` into the formatters-region slot at line 2248 + (b) replace ONLY their tool's marker-delimited dispatcher branch at lines 1898-1928. No shared-file write contention possible.
- D-15 payload uniformity: every plan 01-05 calls `emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state)` with `flag_state: Literal["on","off"]` — single source of truth, signature pinned by Test 14.
- ≥15 scaffolding tests green; lints green; no regressions.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-00-SUMMARY.md` with:
- Files created (paths + line counts).
- All 6 flags + their defaults grep-confirmed (paste the grep output).
- emit_coach_tool_breadcrumb + hash_profile_id import-verified (paste the python3 -c outputs).
- Dispatcher slot marker grep-confirmed.
- 13 scaffolding tests collected + passed (paste pytest tail).
- 0-trust self-check section citing every command output verbatim.
</output>
