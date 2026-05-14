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
  - services/backend/tests/test_coach_tools_retirement_projection.py
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
    - path: "services/backend/tests/test_coach_tools_retirement_projection.py"
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
    - services/backend/tests/test_coach_tools_retirement_projection.py (create)
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
    Step A — Verify the 3 service signatures (already done by panel — documented below).

    **Verified real APIs** (see panel obs-54a6659a6008b907 + obs-a5f5f19baeb3119b):

    ```python
    # AvsEstimationService — INSTANCE method, 6 kwargs scalaires, NOT dict input
    AvsEstimationService().estimate(
        current_age: int,
        retirement_age: int = 65,
        is_couple: bool = False,
        annees_lacunes: int = 0,
        life_expectancy: int = 87,
        gross_salary: float = 0.0,
    ) -> AvsEstimation  # .rente_mensuelle, .rente_annuelle, .rente_couple_mensuelle, ...

    # LppConversionService — INSTANCE method `compare` (NOT `convert`)
    LppConversionService().compare(
        capital_lpp: float,
        canton: str = "ZH",
        retirement_age: int = 65,
        life_expectancy: int = 87,
        taux_marginal_revenu: float = 0.25,
    ) -> LppConversionResult  # .capital_total, .option_rente_nette_mensuelle, .option_capital_net, .breakeven_age, ...

    # RetirementBudgetService — INSTANCE method `reconcile` (NOT `compute`)
    RetirementBudgetService().reconcile(
        avs_mensuel: float,
        lpp_mensuel: float,
        capital_3a_net: float,
        autres_revenus: float,
        depenses_mensuelles: float,
        revenu_pre_retraite: float,
        is_couple: bool = False,
    ) -> RetirementBudget  # .total_revenus_mensuels, .solde_mensuel, .taux_remplacement (PERCENT 0-100), ...
    ```

    **Canonical chain reference**: `services/backend/app/api/v1/endpoints/overview.py:200-246` (chains AVS + LPP with forward-projection; does NOT yet chain Budget — plan-02 is the first caller).

    **Profile schema**: camelCase per Flutter↔backend contract. Keys to read: `birthYear`, `householdType`, `canton`, `avsContributionYears`, `avoirLpp`, `lppInsuredSalary`, `pillar3aBalance`, `monthlyIncome`, `monthlyExpenses`, `desiredRetirementAge`. NO snake_case alternates.

    Step B — Create `services/backend/app/services/retirement/retirement_projection_service.py`:

    ```python
    """Wave 1a D-02 — server-side orchestrator for get_retirement_projection.

    Chains the 3 existing retirement services:
      - AvsEstimationService     (monthly AVS rente from age + salary)
      - LppConversionService     (LPP capital + monthly conversion at retirement)
      - RetirementBudgetService  (budget reconciliation at retirement age)

    NO calculation logic re-implementation per CLAUDE.md rule 4
    (financial_core reuse mandatory). This module ORCHESTRATES only.

    Real API signatures verified 2026-05-14 by panel
    (obs-54a6659a6008b907, obs-a5f5f19baeb3119b):
      AvsEstimationService().estimate(current_age, retirement_age=65, is_couple=False,
                                       annees_lacunes=0, life_expectancy=87, gross_salary=0.0)
        -> AvsEstimation(.rente_mensuelle, .rente_annuelle, ...)
      LppConversionService().compare(capital_lpp, canton="ZH", retirement_age=65,
                                      life_expectancy=87, taux_marginal_revenu=0.25)
        -> LppConversionResult(.option_rente_nette_mensuelle, .option_capital_net, .capital_total, ...)
      RetirementBudgetService().reconcile(avs_mensuel, lpp_mensuel, capital_3a_net,
                                           autres_revenus, depenses_mensuelles,
                                           revenu_pre_retraite, is_couple=False)
        -> RetirementBudget(.total_revenus_mensuels, .solde_mensuel, .taux_remplacement, ...)
        NOTE: .taux_remplacement is PERCENT (0-100), NOT a 0-1 ratio.
    """
    from __future__ import annotations
    from dataclasses import dataclass
    from datetime import date
    from decimal import Decimal, ROUND_HALF_UP
    from typing import Optional

    from app.services.retirement.avs_estimation_service import AvsEstimationService
    from app.services.retirement.lpp_conversion_service import LppConversionService
    from app.services.retirement.retirement_budget_service import RetirementBudgetService


    @dataclass(frozen=True)
    class RetirementProjection:
        # Ratio 0.0-1.0 (computed = budget.taux_remplacement / 100). NOT a percent.
        replacement_ratio: float
        # Monthly AVS rente (CHF) — NOT annual; matches legacy formatter expectation.
        avs_rente: Decimal
        # LPP capital at retirement age (forward-projected) — None if no LPP avoir.
        lpp_capital: Optional[Decimal]
        # Total monthly retirement income (AVS + LPP rente net + mensualised 3a + other).
        monthly_retirement_income: Decimal
        # current_monthly_income - monthly_retirement_income (CHF/month, can be negative).
        monthly_gap: Decimal
        # Pre-retirement monthly income (from profile.monthlyIncome).
        current_monthly_income: Decimal


    def _q(v: float | int | Decimal | None) -> Decimal:
        """Quantize to 2-decimal Decimal with ROUND_HALF_UP, matching inputs_hash.py:51."""
        if v is None:
            return Decimal("0.00")
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


    def _age_from_birth_year(birth_year: int | None) -> Optional[int]:
        """Compute current age from birth year (matches overview.py helper)."""
        if not birth_year:
            return None
        try:
            return date.today().year - int(birth_year)
        except (TypeError, ValueError):
            return None


    class RetirementProjectionService:
        """Pure orchestrator. No state, no side effects."""

        # Default product assumptions per Wave 1a (documented in CONTEXT, may
        # become user-editable in Wave 2). All defaults match overview.py canon.
        DEFAULT_RETIREMENT_AGE = 65
        DEFAULT_LIFE_EXPECTANCY = 87
        DEFAULT_TAUX_MARGINAL_LPP = 0.25
        DEFAULT_EXPENSE_RATIO = 0.70  # depenses_mensuelles = 70% of pre-retirement income if unknown
        LPP_REAL_RETURN_RATE = 1.02   # matches overview.py:231 forward-projection
        LPP_INSURED_CONTRIB_RATE = 0.18  # matches overview.py:231

        @staticmethod
        def compute(profile_data: dict) -> RetirementProjection:
            # camelCase keys (Flutter→backend contract).
            birth_year = profile_data.get("birthYear")
            current_age = _age_from_birth_year(birth_year)
            household_type = profile_data.get("householdType")
            is_couple = household_type == "couple"
            canton = profile_data.get("canton") or "ZH"
            avoir_lpp = profile_data.get("avoirLpp")
            lpp_insured = profile_data.get("lppInsuredSalary") or 0.0
            avs_contrib_years = profile_data.get("avsContributionYears")
            pillar3a_balance = profile_data.get("pillar3aBalance") or 0.0
            monthly_income = profile_data.get("monthlyIncome")
            monthly_expenses = profile_data.get("monthlyExpenses")
            desired_retirement_age = (
                profile_data.get("desiredRetirementAge")
                or RetirementProjectionService.DEFAULT_RETIREMENT_AGE
            )

            # Validate minimum inputs — need age + at least one income source.
            if current_age is None or (avoir_lpp is None and monthly_income is None):
                raise ValueError("retirement projection inputs missing")

            # 1. AVS estimate
            annees_lacunes = 0
            if avs_contrib_years is not None:
                try:
                    annees_lacunes = max(0, 44 - int(avs_contrib_years))
                except (TypeError, ValueError):
                    annees_lacunes = 0
            avs = AvsEstimationService().estimate(
                current_age=current_age,
                retirement_age=desired_retirement_age,
                is_couple=is_couple,
                annees_lacunes=annees_lacunes,
                life_expectancy=RetirementProjectionService.DEFAULT_LIFE_EXPECTANCY,
                gross_salary=float((monthly_income or 0.0) * 12),
            )

            # 2. LPP forward-projection + compare. Match overview.py:226-246.
            lpp_capital_net: Optional[Decimal] = None
            lpp_rente_mensuelle_net = 0.0
            if avoir_lpp is not None and float(avoir_lpp) > 0:
                years_to_retirement = max(0, desired_retirement_age - current_age)
                projected_capital = (
                    float(avoir_lpp) * (RetirementProjectionService.LPP_REAL_RETURN_RATE ** years_to_retirement)
                    + float(lpp_insured) * RetirementProjectionService.LPP_INSURED_CONTRIB_RATE * years_to_retirement
                )
                lpp = LppConversionService().compare(
                    capital_lpp=projected_capital,
                    canton=canton,
                    retirement_age=desired_retirement_age,
                    life_expectancy=RetirementProjectionService.DEFAULT_LIFE_EXPECTANCY,
                    taux_marginal_revenu=RetirementProjectionService.DEFAULT_TAUX_MARGINAL_LPP,
                )
                lpp_capital_net = _q(lpp.option_capital_net)
                lpp_rente_mensuelle_net = lpp.option_rente_nette_mensuelle

            # 3. Retirement budget reconcile.
            current_monthly = float(monthly_income or 0.0)
            depenses = float(
                monthly_expenses
                if monthly_expenses is not None
                else current_monthly * RetirementProjectionService.DEFAULT_EXPENSE_RATIO
            )
            budget = RetirementBudgetService().reconcile(
                avs_mensuel=avs.rente_mensuelle,
                lpp_mensuel=lpp_rente_mensuelle_net,
                capital_3a_net=float(pillar3a_balance),
                autres_revenus=0.0,
                depenses_mensuelles=depenses,
                revenu_pre_retraite=current_monthly,
                is_couple=is_couple,
            )

            # Convert percent (0-100) to ratio (0.0-1.0). Critical unit fix
            # per panel obs-54a6659a6008b907 concern #6 and obs-a5f5f19baeb3119b C4.
            replacement_ratio = float(budget.taux_remplacement) / 100.0

            monthly_retirement = _q(budget.total_revenus_mensuels)
            current_monthly_q = _q(current_monthly)
            return RetirementProjection(
                replacement_ratio=replacement_ratio,
                avs_rente=_q(avs.rente_mensuelle),
                lpp_capital=lpp_capital_net,
                monthly_retirement_income=monthly_retirement,
                monthly_gap=current_monthly_q - monthly_retirement,
                current_monthly_income=current_monthly_q,
            )
    ```

    The orchestrator uses real method names (`estimate`, `compare`, `reconcile`), instance-method invocation, the verified chain order from overview.py (AVS → LPP forward-projection → LPP compare → Budget reconcile with computed scalars), camelCase profile keys, and Optional[Decimal] for lpp_capital. The unit conversion `budget.taux_remplacement / 100.0` is the critical fix preventing 6000% replacement_ratio output.

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
        replacement_ratio: float  # ratio 0.0-1.0, NOT percent (panel obs-a5f5f19baeb3119b C4)
        avs_rente: Decimal  # monthly CHF
        lpp_capital: Optional[Decimal] = None  # null when no LPP avoir (panel obs-a5f5f19baeb3119b H3)
        monthly_retirement_income: Decimal
        monthly_gap: Decimal
        current_monthly_income: Decimal
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```
    Note `from typing import Optional` at top of file.

    Step E — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Plan-00 left it as an empty marker; plans 01-05 each provide a per-tool file. Consumers import directly: `from app.models.coach_tools.retirement_projection import RetirementProjectionResponse`.

    Step F — Flag verification (plan-00 added all 6 flags; plan-02 only READS `COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED`). Verify:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```

    Step G — Create `services/backend/tests/test_coach_tools_retirement_projection.py` with Tests 1-6 from `<behavior>`. Use `unittest.mock.patch("app.services.retirement.retirement_projection_service.AvsEstimationService.estimate")` etc. for Test 6.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_retirement_projection.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.retirement.retirement_projection_service import RetirementProjectionService, RetirementProjection; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.retirement_projection import RetirementProjectionResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "AvsEstimationService\|LppConversionService\|RetirementBudgetService" services/backend/app/services/retirement/retirement_projection_service.py` returns ≥3.
    - `pytest services/backend/tests/test_coach_tools_retirement_projection.py -q` exits 0 with ≥6 tests.
    - `grep -E "replacementRatio|avsRente|lppCapital|monthlyRetirementIncome" services/backend/tests/test_coach_tools_retirement_projection.py` returns ≥4 matches.
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
    - services/backend/tests/test_coach_tools_retirement_projection.py (extend)
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
    def _compute_retirement_projection(user_id: str | None, ctx: dict, db) -> str:
        import time
        import logging
        from app.core.config import settings
        if not settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED:
            return _format_retirement_projection(ctx)
        if not user_id or db is None:
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

            # Newest-profile-wins lookup — matches canonical pattern at coach_chat.py:2018-2022.
            profile = (
                db.query(ProfileModel)
                .filter(ProfileModel.user_id == user_id)
                .order_by(ProfileModel.updated_at.desc())
                .first()
            )
            if profile is None or not profile.data:
                return _format_retirement_projection(ctx)
            proj = RetirementProjectionService.compute(profile.data)
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
                profile_id_hashed=hash_profile_id(user_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
            )
            return response.model_dump_json(by_alias=True)
        except Exception as exc:  # defensive fallback per python-pro panel
            logging.getLogger(__name__).warning(
                "compute_retirement_projection failed, falling back to legacy: %s", exc
            )
            return _format_retirement_projection(ctx)
    ```

    Step B — Replace the dispatcher branch INSIDE the marker pair shipped by plan-00. Locate the EXACT 4-line block:
    ```python
        # >>> dispatch: get_retirement_projection
        if name == "get_retirement_projection":
            return _format_retirement_projection(ctx)
        # <<< dispatch: get_retirement_projection
    ```
    Replace WITH (markers preserved verbatim):
    ```python
        # >>> dispatch: get_retirement_projection
        if name == "get_retirement_projection":
            return _compute_retirement_projection(user_id=user_id, ctx=ctx, db=db)
        # <<< dispatch: get_retirement_projection
    ```
    Why `user_id` not `profile_id`: `_execute_internal_tool` signature at coach_chat.py:1834 has `user_id`, not `profile_id` (panel fix backend-architect obs-d518b856d7e4fe1a).

    Step C — Extend `services/backend/tests/test_coach_tools_retirement_projection.py` with Tests 7-12 from `<behavior>`. Use `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", True/False)`.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_retirement_projection.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/retirement/retirement_projection_service.py services/backend/app/models/coach_tools/retirement_projection.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_retirement_projection" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (this plan adds one call; plan-01 added one — total grows monotonically as plans 03-05 add theirs).
    - `grep -E "tool_name=\"retirement_projection\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "elapsed_ms\s*=\s*int\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 (plan-01 + this plan).
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2.
    - `grep -c "_format_retirement_projection" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy preserved + fallback calls).
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_coach_tools_retirement_projection.py -q` exits 0 with ≥12 tests.
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
- `pytest services/backend/tests/test_coach_tools_retirement_projection.py -q` exits 0.
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
