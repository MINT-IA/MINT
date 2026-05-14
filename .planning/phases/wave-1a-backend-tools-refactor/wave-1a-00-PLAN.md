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
def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: str,  # "on" | "off"
) -> None:
    """Fail-open Sentry breadcrumb emitter for Wave 1a coach tools (D-15)."""
```

hash_profile_id signature:
```python
def hash_profile_id(profile_id: str) -> str:
    """First 16 hex chars of SHA-256(profile_id). Irreversible. Per D-15."""
```

Dispatcher slot placement reference:
File services/backend/app/api/v1/endpoints/coach_chat.py around line 2240 (top of formatters region, ABOVE `def _format_budget_status`). The slot comment block is inserted here.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create empty package directories + shared helpers + dispatcher slot + flag block + scaffolding tests</name>
  <read_first>
    - services/backend/app/core/config.py (FULL — confirm Settings class structure + COACH_CITATION_GATE_ENABLED line position)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2230-2270 (top of formatters region — confirm insertion point at line ~2240 is ABOVE _format_budget_status)
    - services/backend/app/services/coach/turn_cap.py lines 100-125 (sentry breadcrumb fail-open pattern)
    - services/backend/app/observability/ (check if directory exists — if yes, only add coach_breadcrumbs.py; if no, create __init__.py too)
    - services/backend/app/utils/hashing.py (check if exists — if yes, extend with hash_profile_id; if no, create)
    - services/backend/tests/conftest.py (existing test config — confirm pytest discovery picks up tests/test_coach_tools_scaffolding.py)
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
    - Test 13: SCAFFOLD-WIRING — `grep "Wave 1a server-side compute dispatchers"` in coach_chat.py returns ≥1 hit (dispatcher slot exists). This is the assertion that prevents the « plan-00 unused scaffolding » threat T-WAVE1A-00-01.
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
      - flag_state       : str  — "on" | "off"

    Plan-06 (cap_status garde) does NOT use this helper — it has its own
    coach.cap.cap_chf_uncited breadcrumb with snippet payload (D-09).
    """
    from __future__ import annotations

    try:
        import sentry_sdk  # type: ignore
    except Exception:  # pragma: no cover — fail-open if SDK unavailable
        sentry_sdk = None  # type: ignore


    def emit_coach_tool_breadcrumb(
        tool_name: str,
        inputs_hash: str,
        profile_id_hashed: str,
        elapsed_ms: int,
        flag_state: str,
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
            sentry_sdk.add_breadcrumb(
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

    Step H — `services/backend/app/api/v1/endpoints/coach_chat.py` — locate the top of the formatters region (around line 2240, ABOVE the existing `def _format_budget_status(ctx: dict) -> str:`). INSERT the following delimited comment block:
    ```python
    # === Wave 1a server-side compute dispatchers (D-08) ===
    # Plans 01-05 each insert their _compute_<tool_name>() function below
    # this comment block, ABOVE the matching legacy _format_<tool_name>().
    # Plan-06 inserts its _validate_cap_response() middleware here too.
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

    Step J — Create `services/backend/tests/test_coach_tools_scaffolding.py` with the 13 tests from `<behavior>`. Test 12 mocks `sentry_sdk` to None and confirms `emit_coach_tool_breadcrumb` does not raise. Test 13 uses subprocess or `Path.read_text` to grep `coach_chat.py` for the slot marker string.
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
    - `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED\|COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED\|COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED\|COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED\|COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED\|COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/core/config.py` returns ≥6.
    - `grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py` returns 1 (cap-garde default ON — NOT False).
    - `grep -c "Wave 1a server-side compute dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (dispatcher slot marker present).
    - `grep -c "end Wave 1a dispatchers" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (slot closing marker present).
    - `pytest services/backend/tests/test_coach_tools_scaffolding.py -q` exits 0 with ≥13 tests collected.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/utils/hashing.py services/backend/app/core/config.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
  </acceptance_criteria>
  <done>
    All 6 flags exist with correct defaults; helpers importable; package markers present; dispatcher slot delimited; 13 scaffolding tests green. Plans 01-06 can now run truly parallel.
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
| T-WAVE1A-00-01 | T (Tampering) | Scaffold-only plan introduces unused code if downstream plans never land | mitigate | Test 13 SCAFFOLD-WIRING asserts `Wave 1a server-side compute dispatchers` marker present in coach_chat.py — proves slot is live. Test 1-6 assert all 6 flags exist + 7-12 assert helpers importable — these tests STAY GREEN through Wave 1c, so if a downstream plan accidentally rips out the scaffolding, this plan's tests fail and CI catches it. |
| T-WAVE1A-00-02 | I (Information disclosure) | hash_profile_id leak via short hash collision | accept | 16-char hex = 64 bits of entropy. Collision probability at MINT scale (<10^6 profiles) is negligible (≈ 10^-9). Cannot recover profile_id from the prefix (SHA-256 preimage resistance). |
| T-WAVE1A-00-03 | I | coach_breadcrumbs leaks PII via tool_name or inputs_hash | mitigate | tool_name is hardcoded ENUM-like string ("budget_status" etc.) chosen by plans 01-05 — no user data. inputs_hash is SHA-256 of profile slice — irreversible. Test payload structure asserted in scaffolding test 12. |
| T-WAVE1A-00-04 | T | Flag defaults drift (someone changes False → True on prod) | mitigate | Test 1-6 PIN the exact default values. Any drift = test failure on next CI run. |
| T-WAVE1A-00-05 | E (Elevation of privilege) | emit_coach_tool_breadcrumb crashes the coach response path if sentry_sdk raises | mitigate | Try/except wraps the entire sentry_sdk call. Test 12 asserts no raise when sentry_sdk is None. Fail-open guarantee. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools_scaffolding.py -q` exits 0 with ≥13 tests.
- `pytest services/backend/ -q` full suite — zero regressions (this plan adds tests, modifies only config.py + 1 comment block in coach_chat.py).
- `banned_terms_python.py` green on touched files.
- All 6 flag defaults asserted by tests 1-6.
- Dispatcher slot marker present (grep proof).
- Helpers importable from their final paths.
</verification>

<success_criteria>
- WAVE1A-09 partially satisfied: empty Pydantic `app.models.coach_tools` package exists; plans 01-05 will populate it.
- WAVE1A-10 partially satisfied: all 6 rollback flags exist with correct defaults in settings.py.
- Race-condition mitigation: plans 01-06 can run truly parallel — they INSERT into pre-existing slots, no shared-file writes contention.
- D-15 payload uniformity: every plan 01-05 will call `emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state)` — single source of truth.
- ≥13 scaffolding tests green; lints green; no regressions.
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
