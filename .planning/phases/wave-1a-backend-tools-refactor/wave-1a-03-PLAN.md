---
phase: wave-1a
plan: 03
type: execute
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/services/arbitrage/__init__.py
  - services/backend/app/services/arbitrage/cross_pillar_service.py
  - services/backend/app/models/coach_tools/cross_pillar.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_coach_tools/test_cross_pillar.py
autonomous: true
requirements: [WAVE1A-03, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Coach tool get_cross_pillar_analysis chains arbitrage.allocation_annuelle + rachat_vs_marche + pillar_3a_deep services server-side when flag ON"
    - "Response carries inputs_hash + annual3aContribution + threeARemaining + lppBuybackMax + lppCapital + taxSavingPotential"
    - "tax_saving_potential is derived via existing pillar_3a_deep / arbitrage logic — NEVER re-implemented (CLAUDE.md rule 4)"
    - "When flag OFF, dispatcher falls back to _format_cross_pillar_analysis(ctx) byte-identical"
  artifacts:
    - path: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      provides: "CrossPillarService.compute(profile_data) -> CrossPillarAnalysis dataclass — chains 3 existing modules"
      contains: "class CrossPillarService"
    - path: "services/backend/app/models/coach_tools/cross_pillar.py"
      provides: "CrossPillarAnalysisResponse Pydantic v2 model"
      contains: "class CrossPillarAnalysisResponse(BaseModel)"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_cross_pillar_analysis sibling + flag-gated dispatcher branch"
      contains: "_compute_cross_pillar_analysis"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED setting"
      contains: "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED"
    - path: "services/backend/tests/test_coach_tools/test_cross_pillar.py"
      provides: "≥10 unit tests"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      to: "services/backend/app/services/arbitrage/allocation_annuelle.py"
      via: "compare_allocation_annuelle import + call"
      pattern: "compare_allocation_annuelle"
    - from: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      to: "services/backend/app/services/pillar_3a_deep/"
      via: "import + call (tax_saving derivation)"
      pattern: "pillar_3a_deep"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      via: "CrossPillarService.compute() in _compute_cross_pillar_analysis"
      pattern: "CrossPillarService"
---

<objective>
Re-wire `get_cross_pillar_analysis` to compute the cross-pillar analysis (3a annual contribution, 3a remaining, LPP buyback max, LPP capital, tax saving potential) server-side by chaining the existing `arbitrage/allocation_annuelle.compare_allocation_annuelle`, `arbitrage/rachat_vs_marche`, and `pillar_3a_deep` modules. Implements CONTEXT D-02 + D-03 + D-04 + D-05 + D-08 + D-13.

Per RESEARCH §3 caveat #3: `tax_saving_potential` derivation must reuse the existing arbitrage/pillar_3a_deep logic — DO NOT re-implement. If the existing services do not expose a `tax_saving_potential` getter, document the gap in the SUMMARY and either (a) read it from a pre-existing helper if one is grepped during read_first, or (b) compute via `pillar_3a_deep.retroactive_3a_service` if that path exposes the marginal-rate × annual_3a math. NEVER add new financial math.

Purpose: replace Flutter-injected `ctx["annual_3a_contribution"|"lpp_buyback_max"|"tax_saving_potential"|"lpp_capital"]` with server-computed values.
Output: dispatcher path with flag-gated server-side recompute; legacy fallback preserved.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/arbitrage/allocation_annuelle.py
@services/backend/app/services/arbitrage/rachat_vs_marche.py
@services/backend/app/services/pillar_3a_deep/multi_account_service.py
@services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py
@services/backend/app/services/coach/inputs_hash.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Legacy formatter (BYTE-IDENTITY TARGET):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2301-2327:
```python
def _format_cross_pillar_analysis(ctx: dict) -> str:
    annual_3a = ctx.get("annual_3a_contribution")
    lpp_buyback = ctx.get("lpp_buyback_max")
    tax_saving = ctx.get("tax_saving_potential")
    lpp_capital = ctx.get("lpp_capital")
    if annual_3a is None and lpp_buyback is None and tax_saving is None:
        return "Données d'analyse inter-piliers non disponibles dans le profil."
    lines = ["Analyse inter-piliers :"]
    if annual_3a is not None:
        ceiling = get_3a_ceiling(ctx.get("employment_status"), ctx.get("has_2nd_pillar"))
        remaining = max(0, ceiling - float(annual_3a))
        lines.append(f"- 3a versé cette année : {_fmt_chf(annual_3a)} / {_fmt_chf(ceiling)}")
        if remaining > 0:
            lines.append(f"- 3a restant à verser : {_fmt_chf(remaining)}")
    if lpp_buyback is not None and float(lpp_buyback) > 0:
        lines.append(f"- Rachat LPP possible : jusqu'à {_fmt_chf(lpp_buyback)}")
    if lpp_capital is not None:
        lines.append(f"- Avoir LPP actuel : {_fmt_chf(lpp_capital)}")
    if tax_saving is not None and float(tax_saving) > 0:
        lines.append(f"- Économie fiscale potentielle : {_fmt_chf(tax_saving)}")
    return "\n".join(lines)
```

Existing dispatcher branch (REPLACE):
File services/backend/app/api/v1/endpoints/coach_chat.py line 1918-1919:
```python
if name == "get_cross_pillar_analysis":
    return _format_cross_pillar_analysis(ctx)
```

Existing helper:
- `get_3a_ceiling(employment_status, has_2nd_pillar)` — already imported/used by `_format_cross_pillar_analysis`. Reuse the SAME function in the server-side service.

Settings flag pattern:
```python
COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED: bool = False
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: CrossPillarService orchestrator + Pydantic response + flag (signature-only — chain existing modules)</name>
  <read_first>
    - services/backend/app/services/arbitrage/allocation_annuelle.py (FULL — find `compare_allocation_annuelle` signature)
    - services/backend/app/services/arbitrage/rachat_vs_marche.py (FULL — discover the rachat LPP service API)
    - services/backend/app/services/pillar_3a_deep/multi_account_service.py (FULL)
    - services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py (FULL — tax_saving derivation candidate)
    - services/backend/app/services/coach/inputs_hash.py
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2301-2327 (legacy formatter — byte-identity reference + reuse `get_3a_ceiling`)
    - services/backend/app/models/coach_tools/__init__.py (plans-01/02 already extended this — APPEND, don't overwrite)
  </read_first>
  <files>
    - services/backend/app/services/arbitrage/cross_pillar_service.py (create)
    - services/backend/app/services/arbitrage/__init__.py (modify — add export)
    - services/backend/app/models/coach_tools/cross_pillar.py (create)
    - services/backend/app/models/coach_tools/__init__.py (modify — add export)
    - services/backend/app/core/config.py (modify — add flag)
    - services/backend/tests/test_coach_tools/test_cross_pillar.py (create)
  </files>
  <behavior>
    - Test 1: `CrossPillarService.compute({...julien fixture salary 80000 + lpp_avoir 95000 + employment_status "salarie" + has_2nd_pillar True + annual_3a 5000...})` returns `CrossPillarAnalysis(annual_3a_contribution=Decimal("5000.00"), three_a_ceiling=Decimal("7258.00"), three_a_remaining=Decimal("2258.00"), lpp_buyback_max=Decimal(...), lpp_capital=Decimal("95000.00"), tax_saving_potential=Decimal(...))`. EXACT values for `lpp_buyback_max` and `tax_saving_potential` derived from existing services — DO NOT invent.
    - Test 2: Profile with NO 3a / NO LPP raises `ValueError("cross pillar data missing")`.
    - Test 3: `CrossPillarAnalysisResponse` serializes camelCase (`annual3aContribution`, `threeARemaining`, `lppBuybackMax`, `lppCapital`, `taxSavingPotential`, `inputsHash`, `computedAt`).
    - Test 4: `inputs_hash` is 64 hex chars.
    - Test 5: `settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED` defaults False.
    - Test 6: contract — `CrossPillarService.compute` calls into `compare_allocation_annuelle` OR `pillar_3a_deep` modules (asserted via `unittest.mock.patch`).
  </behavior>
  <action>
    Step A — Read the 4 arbitrage / pillar_3a_deep files thoroughly. Identify:
    1. The function that returns LPP buyback max for a given profile (likely `rachat_vs_marche.<something>` or a helper inside `pillar_3a_deep`).
    2. The function that returns annual 3a tax-saving potential (`pillar_3a_deep.retroactive_3a_service` is a strong candidate — the « rétroactif 3a » service computes the marginal-rate × contribution math).
    3. The function that returns the 3a ceiling (already in coach_chat.py as `get_3a_ceiling` — reuse it).

    Document the discovered signatures as a comment block at the top of `cross_pillar_service.py`. The executor MUST adapt the orchestrator call signatures to match what the existing modules expose.

    Step B — Create `services/backend/app/services/arbitrage/cross_pillar_service.py`:

    ```python
    """Wave 1a D-02 — server-side orchestrator for get_cross_pillar_analysis.

    Chains the existing arbitrage + pillar_3a_deep modules. NO new financial
    math (CLAUDE.md rule 4: financial_core reuse mandatory).

    Discovered signatures from read_first (executor — fill these in based on
    the actual code read during this task):
      - compare_allocation_annuelle(...) -> ...
      - rachat_vs_marche.<fn>(...) -> ...
      - pillar_3a_deep.retroactive_3a_service.<fn>(...) -> ... (tax saving)
      - get_3a_ceiling(employment_status, has_2nd_pillar) -> int (from coach_chat.py)
    """
    from __future__ import annotations
    from dataclasses import dataclass
    from decimal import Decimal, ROUND_HALF_UP


    @dataclass(frozen=True)
    class CrossPillarAnalysis:
        annual_3a_contribution: Decimal
        three_a_ceiling: Decimal
        three_a_remaining: Decimal
        lpp_buyback_max: Decimal
        lpp_capital: Decimal
        tax_saving_potential: Decimal


    def _q(v) -> Decimal:
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


    class CrossPillarService:
        @staticmethod
        def compute(profile_data: dict) -> CrossPillarAnalysis:
            # Validate minimum inputs.
            annual_3a = profile_data.get("annual_3a_contribution")
            lpp_avoir = profile_data.get("lpp_avoir")
            if annual_3a is None and lpp_avoir is None:
                raise ValueError("cross pillar data missing")

            # 3a ceiling — REUSE the existing helper from coach_chat.py
            # (single source of truth per OPP3 art. 7).
            from app.api.v1.endpoints.coach_chat import get_3a_ceiling
            employment_status = profile_data.get("employment_status", "salarie")
            has_2nd_pillar = profile_data.get("has_2nd_pillar", True)
            ceiling = get_3a_ceiling(employment_status, has_2nd_pillar)
            annual_3a_d = _q(annual_3a) if annual_3a is not None else Decimal("0.00")
            three_a_ceiling_d = _q(ceiling)
            three_a_remaining_d = max(Decimal("0.00"), three_a_ceiling_d - annual_3a_d)

            # LPP buyback max + capital — call into the existing arbitrage
            # rachat_vs_marche or pillar_3a_deep service. EXACT call SHAPE
            # is adapted to the signature read in <read_first>. Example:
            # from app.services.arbitrage.rachat_vs_marche import compute_lpp_buyback_max
            # buyback_max = compute_lpp_buyback_max(profile_data)
            # Fallback: if the existing service does not expose this directly,
            # read from profile_data["lpp_buyback_max"] when present (Flutter-
            # injected value persisted by financial_core) — DO NOT compute.
            lpp_buyback_max_raw = profile_data.get("lpp_buyback_max")
            if lpp_buyback_max_raw is None:
                # Use the existing arbitrage service. Executor MUST verify the
                # exact function name during <read_first> on
                # services/backend/app/services/arbitrage/rachat_vs_marche.py
                # and update the import below to match. NO silent ImportError
                # fallback — if the function does not exist under another name,
                # plan-03 scope expands to creating it (sub-agent B audit
                # listed this service as existing per .planning/audit/
                # 2026-05-14-coach-tools-inventory.md).
                from app.services.arbitrage.rachat_vs_marche import (
                    compute_lpp_buyback_max,
                )
                lpp_buyback_max_raw = compute_lpp_buyback_max(profile_data)
            lpp_buyback_max_d = _q(lpp_buyback_max_raw or 0)
            lpp_capital_d = _q(lpp_avoir) if lpp_avoir is not None else Decimal("0.00")

            # Tax saving potential — call into existing pillar_3a_deep service.
            # Fallback to profile_data["tax_saving_potential"] if persisted.
            # Executor MUST verify the actual function name during <read_first>
            # on services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py
            # and update the import below to match. NO silent ImportError fallback —
            # the audit listed this module as existing.
            tax_saving_raw = profile_data.get("tax_saving_potential")
            if tax_saving_raw is None:
                from app.services.pillar_3a_deep.retroactive_3a_service import (
                    compute_annual_tax_saving,
                )
                tax_saving_raw = compute_annual_tax_saving(profile_data)
            tax_saving_d = _q(tax_saving_raw or 0)

            return CrossPillarAnalysis(
                annual_3a_contribution=annual_3a_d,
                three_a_ceiling=three_a_ceiling_d,
                three_a_remaining=three_a_remaining_d,
                lpp_buyback_max=lpp_buyback_max_d,
                lpp_capital=lpp_capital_d,
                tax_saving_potential=tax_saving_d,
            )
    ```

    NOTE — the imports above use placeholder names (`compute_lpp_buyback_max`, `compute_annual_tax_saving`) chosen by the planner without verification. The executor MUST resolve the ACTUAL function names during `<read_first>` on the listed modules. If the actual names differ, update the imports. If the functions genuinely do not exist (audit was wrong), plan-03 scope expands to creating them — DO NOT silently fall back to 0, which would mask the gap and produce wrong CHF in the response.

    Step C — `services/backend/app/services/arbitrage/__init__.py` add:
    ```python
    from app.services.arbitrage.cross_pillar_service import (
        CrossPillarService,
        CrossPillarAnalysis,
    )
    ```

    Step D — Create `services/backend/app/models/coach_tools/cross_pillar.py`:
    ```python
    """Wave 1a D-03 — get_cross_pillar_analysis response model."""
    from datetime import datetime
    from decimal import Decimal
    from pydantic import BaseModel, ConfigDict, Field
    from pydantic.alias_generators import to_camel


    class CrossPillarAnalysisResponse(BaseModel):
        model_config = ConfigDict(
            populate_by_name=True,
            alias_generator=to_camel,
            frozen=True,
        )
        annual_3a_contribution: Decimal
        three_a_ceiling: Decimal
        three_a_remaining: Decimal
        lpp_buyback_max: Decimal
        lpp_capital: Decimal
        tax_saving_potential: Decimal
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```

    Step E — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Consumers import directly: `from app.models.coach_tools.cross_pillar import CrossPillarAnalysisResponse`.

    Step F — Flag verification (plan-00 added all 6 flags; plan-03 only READS `COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED`). Verify:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```

    Step G — Create `services/backend/tests/test_coach_tools/test_cross_pillar.py` with Tests 1-6.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_cross_pillar.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.arbitrage import CrossPillarService, CrossPillarAnalysis; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.cross_pillar import CrossPillarAnalysisResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "get_3a_ceiling\|compare_allocation_annuelle\|pillar_3a_deep\|rachat_vs_marche" services/backend/app/services/arbitrage/cross_pillar_service.py` returns ≥2.
    - `pytest services/backend/tests/test_coach_tools/test_cross_pillar.py -q` exits 0 with ≥6 tests.
    - `python3 -c "from app.services.arbitrage.rachat_vs_marche import compute_lpp_buyback_max; print('ok')"` exits 0 (or executor updates the import to the actual function name discovered in <read_first> — and the importability check uses that name instead).
    - `python3 -c "from app.services.pillar_3a_deep.retroactive_3a_service import compute_annual_tax_saving; print('ok')"` exits 0 (or executor updates to the actual function name).
    - `grep -c "except ImportError" services/backend/app/services/arbitrage/cross_pillar_service.py` returns 0 (NO silent fallback present — Issue-4 fix from checker iteration 1).
  </acceptance_criteria>
  <done>
    Orchestrator + model + flag exist; chains existing services; 6+ tests green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_cross_pillar_analysis + dispatcher + ≥5 dispatcher/parity tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1900-1930 (dispatcher entry)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2301-2327 (legacy formatter — preserve)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (breadcrumb pattern)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/tests/test_coach_tools/test_cross_pillar.py (extend)
  </files>
  <behavior>
    - Test 7: flag OFF returns byte-identical legacy output.
    - Test 8: flag ON returns parseable `CrossPillarAnalysisResponse` JSON.
    - Test 9: flag ON + `ValueError` from CrossPillarService → fallback to legacy.
    - Test 10: flag ON + `db is None` → fallback to legacy.
    - Test 11: inputs_hash deterministic.
    - Test 12: Sentry breadcrumb `coach.tool.cross_pillar` fires with non-PII payload.
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, insert `_compute_cross_pillar_analysis` ABOVE `_format_cross_pillar_analysis` (line ~2301). Mirror the pattern from plan-01 Task 2 (flag check → db check → start `_t0 = time.perf_counter()` → service call → Pydantic + inputs_hash → emit_coach_tool_breadcrumb → JSON). Use `CrossPillarService.compute(dict(profile.data))`. Emit breadcrumb via the plan-00 helper:

    ```python
    elapsed_ms = int((time.perf_counter() - _t0) * 1000)
    emit_coach_tool_breadcrumb(
        tool_name="cross_pillar",
        inputs_hash=response.inputs_hash,
        profile_id_hashed=hash_profile_id(profile_id),
        elapsed_ms=elapsed_ms,
        flag_state="on",
    )
    ```

    Import block at the top of the function body:
    ```python
    import time
    from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
    from app.utils.hashing import hash_profile_id
    ```

    Step B — Replace dispatcher branch at line ~1918:
    ```python
        if name == "get_cross_pillar_analysis":
            return _compute_cross_pillar_analysis(profile_id=profile_id, ctx=ctx, db=db)
    ```

    Step C — Extend test file with Tests 7-12.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_cross_pillar.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `grep -c "_format_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy preserved + fallback calls).
    - `grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_coach_tools/test_cross_pillar.py -q` exits 0 with ≥12 tests.
    - `grep -E "tool_name=\"cross_pillar\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (plans 01 + 02 + this).
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through `_compute_cross_pillar_analysis`; ≥12 tests green; lints green; financial_core reuse confirmed (no new math).
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-03-01 | T | Legacy `_format_cross_pillar_analysis` regression when flag OFF | mitigate | Test 7 byte-identity assertion. |
| T-WAVE1A-03-02 | I | LSFin banned-terms leak via new Python service strings | mitigate | `CrossPillarService.compute` returns numerics only; banned_terms lint enforces. |
| T-WAVE1A-03-03 | I | PII leak in Sentry breadcrumb | mitigate | Breadcrumb payload `{inputs_hash, flag_state}` only. |
| T-WAVE1A-03-04 | T | numeric drift between Flutter financial_core (tax_saving) and Python service | mitigate | Plan-07 parity harness with ±0.01 CHF tolerance; if tax_saving is sourced from `profile_data["tax_saving_potential"]` fallback, parity is exact (same value Flutter wrote). |
| T-WAVE1A-03-05 | T | re-implementation of `_calculate*` financial math (CLAUDE.md rule 4 violation) | mitigate | Acceptance criterion #4 grep proves the service IMPORTS existing modules; no new math added. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools/test_cross_pillar.py -q` exits 0.
- `pytest services/backend/ -q` full suite — zero regressions.
- `banned_terms_python.py` + `accent_lint_fr.py` green on touched files.
- `grep` proves CrossPillarService chains existing modules (does not re-implement).
</verification>

<success_criteria>
- WAVE1A-03 satisfied: chained server-side recompute when flag ON.
- WAVE1A-09 satisfied: Pydantic v2 camelCase response.
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED` flag exists, default False.
- ≥12 new backend tests, lints green, financial_core reuse confirmed.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-03-SUMMARY.md` with files, tests, lints, 0-trust self-check.
</output>
