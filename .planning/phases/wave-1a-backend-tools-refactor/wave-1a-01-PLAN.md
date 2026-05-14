---
phase: wave-1a
plan: 01
type: execute
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/services/coaching_engine.py
  - services/backend/app/models/coach_tools/budget_snapshot.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_coach_tools/test_budget_snapshot.py
autonomous: true
requirements: [WAVE1A-01, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Coach tool get_budget_status returns server-computed monthly_income / monthly_expenses / monthly_surplus / months_liquidity read from ProfileModel.data when COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true"
    - "Response JSON carries inputs_hash (SHA-256 hex 64 chars) computed from the canonical-JSON profile slice"
    - "When flag OFF, dispatcher falls back to _format_budget_status(ctx) and the legacy string output is byte-identical"
    - "User-facing French strings are byte-identical to legacy formatter (no LSFin regression, no accent regression)"
  artifacts:
    - path: "services/backend/app/services/coaching_engine.py"
      provides: "CoachingEngine.compute_budget_snapshot(profile) -> BudgetSnapshot dataclass"
      contains: "def compute_budget_snapshot"
    - path: "services/backend/app/models/coach_tools/budget_snapshot.py"
      provides: "BudgetSnapshotResponse Pydantic v2 model (camelCase aliases)"
      contains: "class BudgetSnapshotResponse(BaseModel)"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_budget_status(profile_id, ctx, db) sibling next to _format_budget_status, plus flag-gated dispatcher branch at name == 'get_budget_status'"
      contains: "_compute_budget_status"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED setting (default False)"
      contains: "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED"
    - path: "services/backend/tests/test_coach_tools/test_budget_snapshot.py"
      provides: "≥10 unit tests (service compute + Pydantic shape + dispatcher flag ON/OFF + legacy parity)"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/coaching_engine.py"
      via: "CoachingEngine(profile).compute_budget_snapshot() inside _compute_budget_status"
      pattern: "compute_budget_snapshot"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/coach/inputs_hash.py"
      via: "compute_inputs_hash(slice) packed into BudgetSnapshotResponse.inputs_hash"
      pattern: "compute_inputs_hash"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/core/config.py"
      via: "settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED flag check before calling _compute_budget_status"
      pattern: "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED"
---

<objective>
Re-wire the `get_budget_status` coach tool so its numeric payload is computed server-side from `ProfileModel.data` via `CoachingEngine.compute_budget_snapshot`, replacing the current Flutter-injected `ctx["monthly_income"|"monthly_expenses"|"months_liquidity"]` reads. Implements CONTEXT D-02 (per-tool Python service mapping) + D-03 (Pydantic v2 camelCase) + D-04 (inputs_hash) + D-05 (rollback flag) + D-08 (dispatcher placement) + D-13 (verbatim FR copy).

Purpose: kill the « LLM emits CHF numbers it read from Flutter, no server-side ground-truth » class of hallucination for budget answers. Produces the `monthlyIncome`/`monthlyExpenses` known-values surface that Wave 1b's `source_kind="tool_call_id"` registry entries will cite.
Output: dispatcher path that, when the flag is ON, returns a JSON string carrying camelCase fields + `inputsHash`; when OFF, byte-identical legacy output.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md
@.planning/audit/2026-05-14-coach-tools-inventory.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coaching_engine.py
@services/backend/app/services/coach/inputs_hash.py
@services/backend/app/models/profile_model.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Existing reusable helpers (DO NOT re-implement):

From services/backend/app/services/coach/inputs_hash.py:
```python
def compute_inputs_hash(inputs: dict[str, Any]) -> str:  # 64-char hex SHA-256 of rfc8785 canonical JSON
```

From pydantic.alias_generators:
```python
from pydantic.alias_generators import to_camel  # snake_case -> camelCase (used project-wide, ex: app/schemas/auth.py:8)
```

Existing legacy formatter (BYTE-IDENTITY TARGET — copy strings VERBATIM to Python service if it ever produces them, do not rewrite):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2249-2269:
```python
def _format_budget_status(ctx: dict) -> str:
    monthly_income = ctx.get("monthly_income")
    monthly_expenses = ctx.get("monthly_expenses")
    months_liquidity = ctx.get("months_liquidity")
    if monthly_income is None and monthly_expenses is None:
        return "Données budgétaires non disponibles dans le profil."
    lines = ["Budget actuel :"]
    if monthly_income is not None:
        lines.append(f"- Revenu net mensuel : {_fmt_chf(monthly_income)}")
    if monthly_expenses is not None:
        lines.append(f"- Charges mensuelles : {_fmt_chf(monthly_expenses)}")
    if monthly_income is not None and monthly_expenses is not None:
        margin = float(monthly_income) - float(monthly_expenses)
        lines.append(f"- Marge libre : {_fmt_chf(margin)}")
    if months_liquidity is not None:
        lines.append(f"- Réserve de liquidités : {float(months_liquidity):.1f} mois")
    return "\n".join(lines)
```

Existing dispatcher branch (REPLACE):
File services/backend/app/api/v1/endpoints/coach_chat.py line 1912-1913:
```python
if name == "get_budget_status":
    return _format_budget_status(ctx)
```

Settings pattern (mirror this):
File services/backend/app/core/config.py line 91:
```python
COACH_CITATION_GATE_ENABLED: bool = False
```

Sentry breadcrumb pattern (mirror this — non-PII, fail-open):
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
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add compute_budget_snapshot to CoachingEngine + BudgetSnapshotResponse Pydantic model + flag</name>
  <read_first>
    - services/backend/app/services/coaching_engine.py (read the full class to choose insertion point; do not duplicate dataclass names)
    - services/backend/app/services/coach/inputs_hash.py (full file — confirm compute_inputs_hash signature)
    - services/backend/app/models/profile_model.py (full file — confirm ProfileModel.data is a JSON dict)
    - services/backend/app/schemas/anonymous_chat.py lines 1-60 (template for ConfigDict(populate_by_name=True, alias_generator=to_camel))
    - services/backend/app/core/config.py lines 60-95 (mirror COACH_CITATION_GATE_ENABLED placement)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2249-2269 (legacy _format_budget_status — byte-identity reference)
  </read_first>
  <files>
    - services/backend/app/services/coaching_engine.py (modify — add method + BudgetSnapshot dataclass)
    - services/backend/app/models/coach_tools/__init__.py (create — empty marker re-exporting BudgetSnapshotResponse)
    - services/backend/app/models/coach_tools/budget_snapshot.py (create — Pydantic v2 model)
    - services/backend/app/core/config.py (modify — add COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED: bool = False after COACH_CITATION_GATE_ENABLED line 91)
  </files>
  <behavior>
    - Test 1: `CoachingEngine.compute_budget_snapshot(profile_data)` with `{"monthly_income": 7500.0, "monthly_expenses": 5200.0, "months_liquidity": 4.6}` returns dataclass `BudgetSnapshot(monthly_income=Decimal("7500.00"), monthly_expenses=Decimal("5200.00"), monthly_surplus=Decimal("2300.00"), months_liquidity=4.6)`.
    - Test 2: When `monthly_income` AND `monthly_expenses` are both None in profile_data, `compute_budget_snapshot` raises `ValueError("budget data missing")`. (Dispatcher will catch and fall through to legacy.)
    - Test 3: `BudgetSnapshotResponse(monthly_income=Decimal("7500.00"), monthly_expenses=Decimal("5200.00"), monthly_surplus=Decimal("2300.00"), months_liquidity=4.6, inputs_hash="a"*64, computed_at=datetime(2026,5,14,12,0,0)).model_dump(by_alias=True)` produces keys `monthlyIncome`, `monthlyExpenses`, `monthlySurplus`, `monthsLiquidity`, `inputsHash`, `computedAt` (camelCase, NOT snake_case).
    - Test 4: Pydantic model rejects `inputs_hash` shorter than 64 chars OR longer than 64 chars (`Field(..., min_length=64, max_length=64)`).
    - Test 5: settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED defaults to False.
  </behavior>
  <action>
    Step A — `services/backend/app/services/coaching_engine.py`:
    Insert ABOVE the existing `class CoachingEngine` (or after the existing `@dataclass class CoachingTip` block at line ~62) a new dataclass and a new method:

    ```python
    from decimal import Decimal

    @dataclass
    class BudgetSnapshot:
        monthly_income: Decimal
        monthly_expenses: Decimal
        monthly_surplus: Decimal  # income - expenses
        months_liquidity: float
    ```

    Add this method on `class CoachingEngine` (the existing class at line ~79):

    ```python
    @staticmethod
    def compute_budget_snapshot(profile_data: dict) -> BudgetSnapshot:
        """Read budget fields from ProfileModel.data and compute the snapshot.

        Wave 1a D-02 — server-side recompute path for get_budget_status.
        Reads the SAME keys the legacy _format_budget_status reads from ctx
        (monthly_income, monthly_expenses, months_liquidity), preserving
        byte-identity at the formatter boundary.
        """
        mi = profile_data.get("monthly_income")
        me = profile_data.get("monthly_expenses")
        ml = profile_data.get("months_liquidity")
        if mi is None and me is None:
            raise ValueError("budget data missing")
        # Decimal quantization mirrors inputs_hash._quantize_floats convention.
        from decimal import ROUND_HALF_UP
        def _q(v):
            return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        mi_d = _q(mi) if mi is not None else Decimal("0.00")
        me_d = _q(me) if me is not None else Decimal("0.00")
        return BudgetSnapshot(
            monthly_income=mi_d,
            monthly_expenses=me_d,
            monthly_surplus=mi_d - me_d,
            months_liquidity=float(ml) if ml is not None else 0.0,
        )
    ```

    Step B — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Plan-00 created the empty marker; plans 01-05 do NOT re-export through it (avoids parallel-write race). Consumers import directly from the per-tool file: `from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse`.

    Step C — create `services/backend/app/models/coach_tools/budget_snapshot.py`:
    ```python
    """Wave 1a D-03 — get_budget_status response model.

    camelCase aliases via pydantic.alias_generators.to_camel match the
    backend AGENT contract (CLAUDE.md §1).
    """
    from datetime import datetime
    from decimal import Decimal
    from pydantic import BaseModel, ConfigDict, Field
    from pydantic.alias_generators import to_camel


    class BudgetSnapshotResponse(BaseModel):
        model_config = ConfigDict(
            populate_by_name=True,
            alias_generator=to_camel,
            frozen=True,
        )

        monthly_income: Decimal
        monthly_expenses: Decimal
        monthly_surplus: Decimal
        months_liquidity: float
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```

    Step D — Flag verification (plan-00 already added all 6 Wave 1a flags including `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED: bool = False` to `settings.py` as a single block). Plan-01 only READS the flag via `from app.core.config import settings`. Verify before proceeding:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED" services/backend/app/core/config.py
    # Expected: 1 (added by plan-00)
    ```
    If the grep returns 0, plan-00 has not landed yet — STOP and re-check `depends_on: [wave-1a-00]` in this plan's frontmatter is honored.

    Step E — plan-00 already created `services/backend/tests/test_coach_tools/__init__.py`. Plan-01 does NOT touch it.

    Step F — create `services/backend/tests/test_coach_tools/test_budget_snapshot.py` with the 5 tests in `<behavior>` (use `pytest.raises(ValueError, match="budget data missing")` for Test 2; use `Decimal("7500.00")` literals for Test 1).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_budget_snapshot.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.coaching_engine import CoachingEngine, BudgetSnapshot; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "def compute_budget_snapshot" services/backend/app/services/coaching_engine.py` returns ≥1.
    - `grep -c "alias_generator=to_camel" services/backend/app/models/coach_tools/budget_snapshot.py` returns 1.
    - `pytest services/backend/tests/test_coach_tools/test_budget_snapshot.py -q` exits 0 with ≥5 tests collected.
    - `grep -E "monthlyIncome|monthlyExpenses|monthsLiquidity" services/backend/tests/test_coach_tools/test_budget_snapshot.py` returns ≥3 matches (camelCase serialization asserted in Test 3).
  </acceptance_criteria>
  <done>
    Service method + Pydantic response model + settings flag exist; 5 unit tests green; no other code touched yet (dispatcher wiring is Task 2).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_budget_status sibling + dispatcher branch + parity smoke + ≥5 more tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1850-1930 (dispatcher entry — see the `if name == "get_budget_status"` branch at 1912)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2240-2270 (legacy _format_budget_status — preserve this function as-is, do not delete)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (Sentry breadcrumb pattern — fail-open, non-PII)
    - services/backend/app/services/coach/inputs_hash.py (compute_inputs_hash signature)
    - services/backend/app/models/profile_model.py (confirm `data` is the JSON dict field on the ORM row)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/tests/test_coach_tools/test_budget_snapshot.py (extend — add 5+ dispatcher / parity tests)
  </files>
  <behavior>
    - Test 6: dispatcher with `settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=False` returns exact legacy string from `_format_budget_status(ctx)` (byte-identity).
    - Test 7: dispatcher with flag ON + profile carrying `{"monthly_income": 7500.0, "monthly_expenses": 5200.0, "months_liquidity": 4.6}` returns a JSON string parseable as `BudgetSnapshotResponse` whose `monthlyIncome=="7500.00"`, `monthsLiquidity==4.6`, `inputsHash` 64 hex chars.
    - Test 8: dispatcher with flag ON + profile missing budget data → falls back to legacy formatter (returns `"Données budgétaires non disponibles dans le profil."`).
    - Test 9: dispatcher with flag ON + DB session missing → falls back to legacy (no crash).
    - Test 10: parity smoke — when same inputs feed both paths and convert back to numeric, `Decimal(json["monthlySurplus"]) == Decimal("7500.00") - Decimal("5200.00") == Decimal("2300.00")`; tolerance is 0 (exact CHF).
    - Test 11: `inputs_hash` is deterministic — same profile slice produces same hash across two consecutive calls.
  </behavior>
  <action>
    Step A — `services/backend/app/api/v1/endpoints/coach_chat.py`:

    Insert a new function `_compute_budget_status` IMMEDIATELY ABOVE the existing `def _format_budget_status(ctx: dict) -> str:` at line ~2249:

    ```python
    def _compute_budget_status(user_id: str | None, ctx: dict, db) -> str:
        """Wave 1a D-02 server-side path for get_budget_status.

        Returns either:
          - JSON string `BudgetSnapshotResponse.model_dump_json(by_alias=True)` (flag ON success), OR
          - legacy FR string from `_format_budget_status(ctx)` (flag OFF / fallback).

        Falls back to legacy formatter when:
          - settings flag is OFF, OR
          - user_id is None / db session is None, OR
          - DB returns no ProfileModel for user_id / profile.data is empty, OR
          - CoachingEngine raises ValueError("budget data missing"), OR
          - ANY other Exception (defensive: DB flake, Pydantic validation, breadcrumb error).
        """
        import time
        import logging
        from app.core.config import settings
        if not settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED:
            return _format_budget_status(ctx)
        if not user_id or db is None:
            return _format_budget_status(ctx)
        _t0 = time.perf_counter()
        try:
            from app.models.profile_model import ProfileModel
            from app.services.coaching_engine import CoachingEngine
            from app.services.coach.inputs_hash import compute_inputs_hash
            from app.models.coach_tools.budget_snapshot import BudgetSnapshotResponse
            from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
            from app.utils.hashing import hash_profile_id
            from datetime import datetime, timezone

            # Newest-profile-wins lookup — matches canonical pattern at
            # coach_chat.py:2018-2022 + :2074-2078. Filters by user_id (FK)
            # not by id (PK) because a user may have multiple ProfileModel rows.
            profile = (
                db.query(ProfileModel)
                .filter(ProfileModel.user_id == user_id)
                .order_by(ProfileModel.updated_at.desc())
                .first()
            )
            if profile is None or not profile.data:
                return _format_budget_status(ctx)
            snapshot = CoachingEngine.compute_budget_snapshot(profile.data)
            slice_ = {
                "monthly_income": float(snapshot.monthly_income),
                "monthly_expenses": float(snapshot.monthly_expenses),
                "months_liquidity": snapshot.months_liquidity,
            }
            response = BudgetSnapshotResponse(
                monthly_income=snapshot.monthly_income,
                monthly_expenses=snapshot.monthly_expenses,
                monthly_surplus=snapshot.monthly_surplus,
                months_liquidity=snapshot.months_liquidity,
                inputs_hash=compute_inputs_hash(slice_),
                computed_at=datetime.now(timezone.utc),
            )
            # D-15 uniform Sentry payload via plan-00 helper.
            elapsed_ms = int((time.perf_counter() - _t0) * 1000)
            emit_coach_tool_breadcrumb(
                tool_name="budget_status",
                inputs_hash=response.inputs_hash,
                profile_id_hashed=hash_profile_id(user_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
            )
            return response.model_dump_json(by_alias=True)
        except Exception as exc:  # defensive fallback per python-pro panel
            logging.getLogger(__name__).warning(
                "compute_budget_status failed, falling back to legacy: %s", exc
            )
            return _format_budget_status(ctx)
    ```

    Step B — Replace the dispatcher branch INSIDE the marker pair shipped by plan-00 (around lines 1918-1921 post plan-00 commit ab91203e). The markers MUST be preserved. Locate the EXACT 4-line block:
    ```python
        # >>> dispatch: get_budget_status
        if name == "get_budget_status":
            return _format_budget_status(ctx)
        # <<< dispatch: get_budget_status
    ```
    Replace WITH (markers preserved verbatim, body changed):
    ```python
        # >>> dispatch: get_budget_status
        if name == "get_budget_status":
            return _compute_budget_status(user_id=user_id, ctx=ctx, db=db)
        # <<< dispatch: get_budget_status
    ```
    Acceptance after edit: `grep -c "# >>> dispatch: get_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns 1 AND `grep -c "# <<< dispatch: get_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns 1.

    Why `user_id` not `profile_id`: the enclosing `_execute_internal_tool` function (coach_chat.py:1834) has `user_id` in its signature but NOT `profile_id`. Verified by panel backend-architect concern #2 (obs-d518b856d7e4fe1a). Pre-edit grep proof: `grep -c "profile_id" services/backend/app/api/v1/endpoints/coach_chat.py` returns 0 in dispatcher region.

    Step C — Extend `services/backend/tests/test_coach_tools/test_budget_snapshot.py` with the 6 tests in `<behavior>` Tests 6-11. Use `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True)` (or `False`) to flip the flag. Mock `db.query(...).filter(...).order_by(...).first()` to return a `ProfileModel` with the test `data` dict. For Test 6 (flag OFF), call `_compute_budget_status(user_id="dummy", ctx={"monthly_income": 7500.0, ...}, db=mock_db)` and assert the returned string equals the exact legacy output.

    DO NOT touch any other dispatcher branch, formatter, or unrelated test. Karpathy #3 surgical scope.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_budget_snapshot.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/coaching_engine.py services/backend/app/models/coach_tools/budget_snapshot.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/coaching_engine.py services/backend/app/models/coach_tools/budget_snapshot.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + at least one comment/import).
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (D-15 helper called from _compute_budget_status).
    - `grep -E "tool_name=\"budget_status\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "elapsed_ms\s*=\s*int\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (elapsed_ms computed before breadcrumb emission).
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (D-15 profile_id_hashed kwarg present).
    - `grep -E "flag_state=\"on\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "_format_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy def preserved + fallback calls).
    - `grep -c "# >>> dispatch: get_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved post-edit, panel fix).
    - `grep -c "# <<< dispatch: get_budget_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved post-edit, panel fix).
    - `grep -c "user_id=user_id" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (dispatcher passes user_id, not profile_id — panel fix backend-architect #2).
    - `grep -E "filter\(ProfileModel\.user_id == user_id\)" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (canonical newest-profile-wins lookup pattern).
    - `grep -E "order_by\(ProfileModel\.updated_at\.desc\(\)\)" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_coach_tools/test_budget_snapshot.py -q` exits 0 with ≥10 tests collected.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coaching_engine.py services/backend/app/models/coach_tools/budget_snapshot.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coaching_engine.py services/backend/app/models/coach_tools/budget_snapshot.py` exits 0.
    - Full backend pytest delta is `+10 tests minimum` versus pre-task baseline (`pytest services/backend/ -q` count increases).
  </acceptance_criteria>
  <done>
    Dispatcher routes through `_compute_budget_status`; flag ON returns JSON with camelCase fields + inputs_hash; flag OFF returns byte-identical legacy string; ≥10 unit tests green; lints clean on touched files.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM → backend dispatcher | LLM picks tool_name; backend resolves to `_compute_budget_status` or legacy fallback. Adversarial LLM cannot bypass flag (server-side check). |
| backend → ProfileModel.data (DB) | Read-only profile fetch; no write surface on this path. |
| backend → Sentry breadcrumb | Outbound telemetry; must be non-PII. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-01-01 | T (Tampering) | `_format_budget_status` regression when flag OFF | mitigate | Test 6 asserts byte-identity of legacy output via direct string comparison. |
| T-WAVE1A-01-02 | I (Information disclosure) | LSFin banned-terms leak via new Python service strings | mitigate | `compute_budget_snapshot` returns a dataclass of numerics ONLY — no FR strings. All user-facing strings come from `_format_budget_status` (unchanged) OR from the Pydantic JSON shape (no FR text). `banned_terms_python.py` gate in the verify command enforces. |
| T-WAVE1A-01-03 | I | PII leak in Sentry breadcrumb | mitigate | Breadcrumb payload is `{inputs_hash, flag_state}` only — `inputs_hash` is SHA-256 of profile slice, irreversible; no `profile_id`, no raw CHF values, no `user_id`. |
| T-WAVE1A-01-04 | T | numeric drift between Flutter legacy `_format_budget_status` and Python `compute_budget_snapshot` | mitigate | Test 10 parity smoke compares numeric output ±0.00 (exact, since both read the same `ctx`/`profile.data` keys with same Decimal quantization). |
</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools/test_budget_snapshot.py -q` exits 0 with ≥10 tests.
- `pytest services/backend/ -q` full suite exits 0 with zero regressions versus pre-plan baseline.
- `python3 tools/checks/banned_terms_python.py <touched files>` exits 0.
- `python3 tools/checks/accent_lint_fr.py <touched files>` exits 0.
- Dispatcher branch in `coach_chat.py` reads the flag (grep returns ≥1 hit).
- Sentry breadcrumb category `coach.tool.budget_status` present in the dispatcher path.
</verification>

<success_criteria>
- WAVE1A-01 satisfied: `get_budget_status` recomputes server-side when flag ON; legacy path preserved when flag OFF.
- WAVE1A-09 satisfied: response is a Pydantic v2 model with `alias_generator=to_camel`, asserted by Test 3.
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED` flag exists in `settings.py`, default False, asserted by Test 5 and consumed by `_compute_budget_status`.
- ≥10 new backend tests, lints green, no LSFin regression.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-01-SUMMARY.md` with: files created/modified, tests added, pytest baseline delta, lints results, banned-terms check, accent check, 0-trust self-check section citing automated outputs.
</output>
