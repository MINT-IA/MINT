---
phase: wave-1a
plan: 02
type: execute
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/services/retirement/__init__.py
  - services/backend/app/services/retirement/retirement_projection_service.py
  - services/backend/app/models/coach_tools/retirement_projection.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_coach_tools/test_retirement_projection.py
autonomous: true
requirements: [WAVE1A-02, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Coach tool get_retirement_projection chains AvsEstimationService + LppConversionService + RetirementBudgetService server-side when flag ON"
    - "Response JSON carries inputs_hash + replacementRatio + avsRente + lppCapital + monthlyRetirementIncome + monthlyGap"
    - "When flag OFF, dispatcher falls back to _format_retirement_projection(ctx) and output is byte-identical"
    - "User-facing French strings byte-identical to legacy formatter — Python service returns numerics only, no FR text"
  artifacts:
    - path: "services/backend/app/services/retirement/retirement_projection_service.py"
      provides: "RetirementProjectionService.compute(profile_data) -> RetirementProjection dataclass — chains the 3 existing retirement services"
      contains: "class RetirementProjectionService"
    - path: "services/backend/app/models/coach_tools/retirement_projection.py"
      provides: "RetirementProjectionResponse Pydantic v2 model (camelCase)"
      contains: "class RetirementProjectionResponse(BaseModel)"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_retirement_projection sibling next to _format_retirement_projection + flag-gated dispatcher branch"
      contains: "_compute_retirement_projection"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED setting"
      contains: "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED"
    - path: "services/backend/tests/test_coach_tools/test_retirement_projection.py"
      provides: "≥10 unit tests covering chain output + Pydantic shape + flag ON/OFF"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/services/retirement/retirement_projection_service.py"
      to: "services/backend/app/services/retirement/{avs_estimation_service,lpp_conversion_service,retirement_budget_service}.py"
      via: "compose(profile_data) -> chains the 3 existing services"
      pattern: "AvsEstimationService|LppConversionService|RetirementBudgetService"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/retirement/retirement_projection_service.py"
      via: "RetirementProjectionService.compute(profile.data) in _compute_retirement_projection"
      pattern: "RetirementProjectionService"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/core/config.py"
      via: "settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED flag check"
      pattern: "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED"
---

<objective>
Re-wire `get_retirement_projection` to compute server-side by chaining the 3 existing retirement services (`AvsEstimationService`, `LppConversionService`, `RetirementBudgetService`) into a single `RetirementProjectionService.compute(profile_data)` orchestrator that returns a typed dataclass with `replacement_ratio`, `avs_rente`, `lpp_capital`, `monthly_retirement_income`, `monthly_gap`. Implements CONTEXT D-02 + D-03 + D-04 + D-05 + D-08 + D-13.

Purpose: replace the Flutter-injected `ctx["replacement_ratio"|"lpp_capital"|"avs_rente"|"monthly_retirement_income"]` reads with server-computed values, so the coach's retirement claims become ground-truth.
Output: dispatcher path that, when flag ON, returns JSON with camelCase fields + `inputsHash`; when OFF, byte-identical legacy output.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/retirement/avs_estimation_service.py
@services/backend/app/services/retirement/lpp_conversion_service.py
@services/backend/app/services/retirement/retirement_budget_service.py
@services/backend/app/services/coach/inputs_hash.py
@services/backend/app/models/profile_model.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Legacy formatter (BYTE-IDENTITY TARGET):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2272-2298:
```python
def _format_retirement_projection(ctx: dict) -> str:
    replacement_ratio = ctx.get("replacement_ratio")
    monthly_income = ctx.get("monthly_income")
    monthly_retirement = ctx.get("monthly_retirement_income")
    lpp_capital = ctx.get("lpp_capital")
    avs_rente = ctx.get("avs_rente")

    if replacement_ratio is None and lpp_capital is None:
        return "Données de projection retraite non disponibles dans le profil."
    lines = ["Projection retraite :"]
    if replacement_ratio is not None:
        lines.append(f"- Taux de remplacement estimé : {_fmt_pct(replacement_ratio)}")
    if monthly_income is not None:
        lines.append(f"- Revenu actuel : {_fmt_chf(monthly_income)}/mois")
    if monthly_retirement is not None:
        lines.append(f"- Revenu retraite projeté : {_fmt_chf(monthly_retirement)}/mois")
    if monthly_income is not None and replacement_ratio is not None:
        gap = float(monthly_income) * (1 - float(replacement_ratio))
        lines.append(f"- Écart mensuel estimé : {_fmt_chf(gap)}")
    if avs_rente is not None:
        lines.append(f"- Rente AVS estimée : {_fmt_chf(avs_rente)}/an")
    if lpp_capital is not None:
        lines.append(f"- Avoir LPP actuel : {_fmt_chf(lpp_capital)}")
    return "\n".join(lines)
```

Existing dispatcher branch (REPLACE):
File services/backend/app/api/v1/endpoints/coach_chat.py line 1915-1916:
```python
if name == "get_retirement_projection":
    return _format_retirement_projection(ctx)
```

Existing services to chain (READ-ONLY references — DO NOT modify):
- `services/backend/app/services/retirement/avs_estimation_service.py` — `AvsEstimationService.estimate(...)` returns annual AVS rente.
- `services/backend/app/services/retirement/lpp_conversion_service.py` — `LppConversionService.convert(...)` returns LPP capital at retirement age + monthly converted rente.
- `services/backend/app/services/retirement/retirement_budget_service.py` — `RetirementBudgetService.compute(...)` returns budget snapshot at retirement age (income, expenses, ratio).

Executor MUST read each of those three files at the top of Task 1 to discover the exact method signature (some are static, some require constructor args). Adapt the orchestrator call site accordingly. DO NOT re-implement any calculation logic — chaining only.

Settings flag pattern (mirror plan-01):
```python
COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED: bool = False
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create RetirementProjectionService orchestrator + Pydantic response model + flag</name>
  <read_first>
    - services/backend/app/services/retirement/avs_estimation_service.py (FULL file — confirm method signature, dataclass return type)
    - services/backend/app/services/retirement/lpp_conversion_service.py (FULL file — confirm method signature)
    - services/backend/app/services/retirement/retirement_budget_service.py (FULL file — confirm method signature)
    - services/backend/app/services/retirement/__init__.py
    - services/backend/app/services/coach/inputs_hash.py
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2272-2298 (legacy formatter — byte-identity reference)
    - services/backend/app/models/coach_tools/__init__.py (created by plan-01; this plan EXTENDS it — do not overwrite)
    - services/backend/app/core/config.py lines 60-95 (flag placement pattern)
  </read_first>
  <files>
    - services/backend/app/services/retirement/retirement_projection_service.py (create)
    - services/backend/app/services/retirement/__init__.py (modify — add export)
    - services/backend/app/models/coach_tools/retirement_projection.py (create)
    - services/backend/app/models/coach_tools/__init__.py (modify — add export)
    - services/backend/app/core/config.py (modify — add flag)
    - services/backend/tests/test_coach_tools/test_retirement_projection.py (create)
  </files>
  <behavior>
    - Test 1: `RetirementProjectionService.compute(profile_data={...julien fixture...})` returns dataclass `RetirementProjection(replacement_ratio: float, avs_rente: Decimal, lpp_capital: Decimal, monthly_retirement_income: Decimal, monthly_gap: Decimal, current_monthly_income: Decimal)`.
    - Test 2: When profile_data missing `lpp_avoir` AND `salary_gross_yearly` → raises `ValueError("retirement projection inputs missing")`.
    - Test 3: `RetirementProjectionResponse` serializes with camelCase aliases (`replacementRatio`, `avsRente`, `lppCapital`, `monthlyRetirementIncome`, `monthlyGap`, `currentMonthlyIncome`, `inputsHash`, `computedAt`).
    - Test 4: `inputs_hash` length is exactly 64 hex chars.
    - Test 5: `settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED` defaults to False.
    - Test 6: chained service contract — assert `RetirementProjectionService.compute` calls AvsEstimationService, LppConversionService, RetirementBudgetService at least once each (use `unittest.mock.patch` on the 3 services).
  </behavior>
  <action>
    Step A — Read the 3 service files thoroughly. Identify their exact public APIs. Record the signatures inline as a comment block at the top of `retirement_projection_service.py` so the executor of plan-07 (parity) knows the contract.

    Step B — Create `services/backend/app/services/retirement/retirement_projection_service.py`:

    ```python
    """Wave 1a D-02 — server-side orchestrator for get_retirement_projection.

    Chains the 3 existing retirement services:
      - AvsEstimationService     (annual AVS rente from salary + age)
      - LppConversionService     (LPP capital + monthly conversion at retirement)
      - RetirementBudgetService  (budget snapshot at retirement age)

    NO calculation logic re-implementation per CLAUDE.md rule 4
    (financial_core reuse mandatory). This module ORCHESTRATES only.
    """
    from __future__ import annotations
    from dataclasses import dataclass
    from decimal import Decimal, ROUND_HALF_UP

    from app.services.retirement.avs_estimation_service import AvsEstimationService
    from app.services.retirement.lpp_conversion_service import LppConversionService
    from app.services.retirement.retirement_budget_service import RetirementBudgetService


    @dataclass(frozen=True)
    class RetirementProjection:
        replacement_ratio: float
        avs_rente: Decimal  # annual CHF
        lpp_capital: Decimal  # CHF at retirement
        monthly_retirement_income: Decimal  # CHF/month
        monthly_gap: Decimal  # current_income - retirement_income, CHF/month
        current_monthly_income: Decimal


    def _q(v) -> Decimal:
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


    class RetirementProjectionService:
        """Pure orchestrator. No state, no side effects."""

        @staticmethod
        def compute(profile_data: dict) -> RetirementProjection:
            # Validate minimum inputs. Mirror the legacy formatter guard:
            # if both replacement_ratio AND lpp_capital are missing in legacy
            # ctx, the message is "Données de projection retraite non
            # disponibles". Server-side path needs richer inputs because it
            # COMPUTES rather than reads pre-computed values.
            salary = profile_data.get("salary_gross_yearly")
            lpp_avoir = profile_data.get("lpp_avoir")
            if salary is None and lpp_avoir is None:
                raise ValueError("retirement projection inputs missing")

            # Step 1 — AVS annual rente (existing service).
            avs_annual = AvsEstimationService.estimate(profile_data)
            # Step 2 — LPP capital + conversion (existing service).
            lpp_result = LppConversionService.convert(profile_data)
            # Step 3 — retirement budget (existing service).
            budget = RetirementBudgetService.compute(profile_data)

            # NOTE: the EXACT field names on the 3 services' return types
            # MUST be read from the source files (see <read_first>). The
            # executor adapts these attribute accesses to the actual
            # dataclass / dict shape returned by each service.
            monthly_retirement = _q(budget.monthly_retirement_income)
            current_monthly = _q(budget.current_monthly_income)
            return RetirementProjection(
                replacement_ratio=float(budget.replacement_ratio),
                avs_rente=_q(avs_annual),
                lpp_capital=_q(lpp_result.capital_at_retirement),
                monthly_retirement_income=monthly_retirement,
                monthly_gap=current_monthly - monthly_retirement,
                current_monthly_income=current_monthly,
            )
    ```

    NOTE — if the actual return types of the 3 services differ from `budget.monthly_retirement_income` etc., adapt the attribute access. Document the actual signatures in a comment block. DO NOT add new calculation logic.

    Step C — `services/backend/app/services/retirement/__init__.py` add:
    ```python
    from app.services.retirement.retirement_projection_service import (
        RetirementProjectionService,
        RetirementProjection,
    )
    ```

    Step D — Create `services/backend/app/models/coach_tools/retirement_projection.py`:

    ```python
    """Wave 1a D-03 — get_retirement_projection response model."""
    from datetime import datetime
    from decimal import Decimal
    from pydantic import BaseModel, ConfigDict, Field
    from pydantic.alias_generators import to_camel


    class RetirementProjectionResponse(BaseModel):
        model_config = ConfigDict(
            populate_by_name=True,
            alias_generator=to_camel,
            frozen=True,
        )
        replacement_ratio: float
        avs_rente: Decimal
        lpp_capital: Decimal
        monthly_retirement_income: Decimal
        monthly_gap: Decimal
        current_monthly_income: Decimal
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```

    Step E — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Plan-00 left it as an empty marker; plans 01-05 each provide a per-tool file. Consumers import directly: `from app.models.coach_tools.retirement_projection import RetirementProjectionResponse`.

    Step F — Flag verification (plan-00 added all 6 flags; plan-02 only READS `COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED`). Verify:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```

    Step G — Create `services/backend/tests/test_coach_tools/test_retirement_projection.py` with Tests 1-6 from `<behavior>`. Use `unittest.mock.patch("app.services.retirement.retirement_projection_service.AvsEstimationService.estimate")` etc. for Test 6.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_retirement_projection.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.retirement.retirement_projection_service import RetirementProjectionService, RetirementProjection; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.retirement_projection import RetirementProjectionResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "AvsEstimationService\|LppConversionService\|RetirementBudgetService" services/backend/app/services/retirement/retirement_projection_service.py` returns ≥3.
    - `pytest services/backend/tests/test_coach_tools/test_retirement_projection.py -q` exits 0 with ≥6 tests.
    - `grep -E "replacementRatio|avsRente|lppCapital|monthlyRetirementIncome" services/backend/tests/test_coach_tools/test_retirement_projection.py` returns ≥4 matches.
  </acceptance_criteria>
  <done>
    Orchestrator + Pydantic model + flag exist; 6+ unit tests green; the 3 retirement services are referenced (grep proof) but unchanged.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_retirement_projection + dispatcher + ≥5 dispatcher/parity tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1900-1930 (dispatcher entry)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2272-2298 (legacy _format_retirement_projection)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (Sentry breadcrumb pattern)
    - services/backend/app/services/retirement/retirement_projection_service.py (just created in Task 1)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/tests/test_coach_tools/test_retirement_projection.py (extend)
  </files>
  <behavior>
    - Test 7: dispatcher with flag OFF returns legacy formatter output byte-identical for a known ctx.
    - Test 8: dispatcher with flag ON returns parseable `RetirementProjectionResponse` JSON with camelCase keys.
    - Test 9: dispatcher with flag ON but `compute` raises `ValueError` → falls back to legacy formatter.
    - Test 10: dispatcher with flag ON but `db is None` → falls back to legacy.
    - Test 11: inputs_hash deterministic for same profile across 2 calls.
    - Test 12: Sentry breadcrumb `coach.tool.retirement_projection` fires (mock `sentry_sdk.add_breadcrumb` and assert called with `category="coach.tool.retirement_projection"`).
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, insert `_compute_retirement_projection` ABOVE `_format_retirement_projection` (line ~2272):

    ```python
    def _compute_retirement_projection(profile_id: str | None, ctx: dict, db) -> str:
        import time
        from app.core.config import settings
        if not settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED:
            return _format_retirement_projection(ctx)
        if not profile_id or db is None:
            return _format_retirement_projection(ctx)
        _t0 = time.perf_counter()
        try:
            from app.models.profile_model import ProfileModel
            from app.services.retirement import RetirementProjectionService
            from app.services.coach.inputs_hash import compute_inputs_hash
            from app.models.coach_tools.retirement_projection import RetirementProjectionResponse
            from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
            from app.utils.hashing import hash_profile_id
            from datetime import datetime, timezone

            profile = (
                db.query(ProfileModel)
                .filter(ProfileModel.id == profile_id)
                .first()
            )
            if profile is None or not profile.data:
                return _format_retirement_projection(ctx)
            proj = RetirementProjectionService.compute(dict(profile.data))
            slice_ = {
                "salary_gross_yearly": profile.data.get("salary_gross_yearly"),
                "lpp_avoir": profile.data.get("lpp_avoir"),
                "age": profile.data.get("age"),
                "gender": profile.data.get("gender"),
            }
            response = RetirementProjectionResponse(
                replacement_ratio=proj.replacement_ratio,
                avs_rente=proj.avs_rente,
                lpp_capital=proj.lpp_capital,
                monthly_retirement_income=proj.monthly_retirement_income,
                monthly_gap=proj.monthly_gap,
                current_monthly_income=proj.current_monthly_income,
                inputs_hash=compute_inputs_hash(slice_),
                computed_at=datetime.now(timezone.utc),
            )
            # D-15 uniform Sentry payload via plan-00 helper.
            elapsed_ms = int((time.perf_counter() - _t0) * 1000)
            emit_coach_tool_breadcrumb(
                tool_name="retirement_projection",
                inputs_hash=response.inputs_hash,
                profile_id_hashed=hash_profile_id(profile_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
            )
            return response.model_dump_json(by_alias=True)
        except ValueError:
            return _format_retirement_projection(ctx)
    ```

    Step B — Replace the dispatcher branch at line ~1915. Locate:
    ```python
        if name == "get_retirement_projection":
            return _format_retirement_projection(ctx)
    ```
    Replace with:
    ```python
        if name == "get_retirement_projection":
            return _compute_retirement_projection(profile_id=profile_id, ctx=ctx, db=db)
    ```

    Step C — Extend `services/backend/tests/test_coach_tools/test_retirement_projection.py` with Tests 7-12 from `<behavior>`. Use `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", True/False)`.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_retirement_projection.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_retirement_projection" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (this plan adds one call; plan-01 added one — total grows monotonically as plans 03-05 add theirs).
    - `grep -E "tool_name=\"retirement_projection\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "elapsed_ms\s*=\s*int\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (plan-01 + this plan).
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2.
    - `grep -c "_format_retirement_projection" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy preserved + fallback calls).
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_coach_tools/test_retirement_projection.py -q` exits 0 with ≥12 tests.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through `_compute_retirement_projection`; legacy fallback preserved; ≥12 tests green; lints green.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-02-01 | T (Tampering) | Legacy `_format_retirement_projection` regression when flag OFF | mitigate | Test 7 asserts byte-identity of legacy output. |
| T-WAVE1A-02-02 | I | LSFin banned-terms leak via new Python service strings | mitigate | `RetirementProjectionService.compute` returns a dataclass of numerics only; banned_terms lint enforces on touched files. |
| T-WAVE1A-02-03 | I | PII leak in Sentry breadcrumb | mitigate | Breadcrumb payload is `{inputs_hash, flag_state}` only — no profile_id, no salary, no rente values. |
| T-WAVE1A-02-04 | T | numeric drift between Flutter financial_core and Python retirement services | mitigate | Test 10 parity smoke; Plan-07 parity harness adds 3-archetype fixture coverage with ±0.01 CHF tolerance. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools/test_retirement_projection.py -q` exits 0.
- `pytest services/backend/ -q` full suite — zero regressions.
- `banned_terms_python.py` + `accent_lint_fr.py` green on touched files.
- Dispatcher grep proves the flag-gated path is wired.
</verification>

<success_criteria>
- WAVE1A-02 satisfied: chained server-side recompute when flag ON.
- WAVE1A-09 satisfied: camelCase Pydantic response.
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED` flag exists, default False.
- ≥12 new backend tests, lints green.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-02-SUMMARY.md` with files, tests added, lints results, 0-trust self-check citing automated outputs.
</output>
