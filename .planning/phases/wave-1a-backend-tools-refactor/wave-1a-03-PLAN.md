<!--
replan-history:
  - date: 2026-05-14
    reason: |
      python-pro BLOCK 0.90 (obs-67d0ed986ae0d316) on the 2026-05-13 draft —
      two grep-verifiable defects rejected by panel:
        1. CIRCULAR IMPORT — Task 1 Step B imported `get_3a_ceiling` from
           `app.api.v1.endpoints.coach_chat`, but coach_chat.py ITSELF imports
           it from `app.services.rules_engine` (line 86). An orchestrator
           service pulling back into the API endpoint = runtime circular
           import. Real home: `services/backend/app/services/rules_engine.py`
           line 396.
        2. TWO FABRICATED FUNCTION NAMES —
           - `compute_lpp_buyback_max` does NOT exist anywhere under
             `services/backend/app/services/`. Grep of
             `rachat_vs_marche.py` confirms only `compare_rachat_vs_marche`
             (line 204) + private `_build_*` helpers. `lpp_buyback_max` is
             ALWAYS treated as an INPUT (Flutter financial_core writes it
             into `profile_data["lpp_buyback_max"]`, persisted by the
             snapshot layer at `snapshots/snapshot_service.py:147`).
           - `compute_annual_tax_saving` does NOT exist anywhere under
             `services/backend/app/services/pillar_3a_deep/`. Grep of
             `retroactive_3a_service.py` confirms only
             `calculate_retroactive_3a` (line 77). The annual tax_saving
             math is INLINE multiplication: `allocation_annuelle.py:94`
             (`annual_tax_saving = contribution * taux_marginal`) and
             `rachat_vs_marche.py:99` (`tax_saving = montant * taux_marginal`).
      The previous plan waved both away with `NOTE — executor MUST resolve
      names during read_first`. That is fabrication-pushed-to-execute-time
      and was correctly rejected.
    replan_trigger: /gsd-plan-phase wave-1a-backend-tools-refactor --replan 03
    grep_verified_facts_source: live disk scan 2026-05-14
    blocker_observation: obs-67d0ed986ae0d316
-->

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
  - services/backend/tests/test_coach_tools_cross_pillar.py
autonomous: true
requirements: [WAVE1A-03, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Coach tool get_cross_pillar_analysis returns server-computed annual_3a_contribution / three_a_ceiling / three_a_remaining / lpp_buyback_max / lpp_capital / tax_saving_potential when COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED=true"
    - "three_a_ceiling is sourced from app.services.rules_engine.get_3a_ceiling (single OPP3 art. 7 source-of-truth) — never re-implemented"
    - "tax_saving_potential is derived by CALLING into app.services.arbitrage.allocation_annuelle.compare_allocation_annuelle (Strategy A primary) or read from profile_data['tax_saving_potential'] (Strategy B fallback) — never re-implemented (CLAUDE.md rule 4)"
    - "lpp_buyback_max is read from profile_data['lpp_buyback_max'] (Flutter financial_core source-of-truth per RESEARCH §3 caveat #3) — no server function recomputes it; missing value → Decimal('0.00') + Sentry breadcrumb tag"
    - "Response JSON carries inputs_hash (SHA-256 hex 64 chars) computed from the canonical-JSON profile slice"
    - "When flag OFF, dispatcher falls back to _format_cross_pillar_analysis(ctx) byte-identical"
    - "cross_pillar_service.py contains NO import from app.api.v1.endpoints.coach_chat (no circular import)"
    - "cross_pillar_service.py contains NO reference to compute_lpp_buyback_max or compute_annual_tax_saving (fabricated names purged)"
  artifacts:
    - path: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      provides: "CrossPillarService.compute(profile_data) -> CrossPillarAnalysis dataclass — chains rules_engine.get_3a_ceiling + allocation_annuelle.compare_allocation_annuelle; relays profile-supplied lpp_buyback_max / lpp_capital"
      contains: "class CrossPillarService"
    - path: "services/backend/app/models/coach_tools/cross_pillar.py"
      provides: "CrossPillarAnalysisResponse Pydantic v2 model (camelCase aliases)"
      contains: "class CrossPillarAnalysisResponse(BaseModel)"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_cross_pillar_analysis sibling next to _format_cross_pillar_analysis, plus flag-gated dispatcher branch at name == 'get_cross_pillar_analysis'"
      contains: "_compute_cross_pillar_analysis"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED setting (default False — added by plan-00)"
      contains: "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED"
    - path: "services/backend/tests/test_coach_tools_cross_pillar.py"
      provides: "≥13 unit tests (service compute + Pydantic shape + dispatcher flag ON/OFF + legacy parity + missing-buyback breadcrumb + chain assertion)"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      to: "services/backend/app/services/rules_engine.py"
      via: "from app.services.rules_engine import get_3a_ceiling"
      pattern: "from app.services.rules_engine import get_3a_ceiling"
    - from: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      to: "services/backend/app/services/arbitrage/allocation_annuelle.py"
      via: "from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle"
      pattern: "compare_allocation_annuelle"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/arbitrage/cross_pillar_service.py"
      via: "CrossPillarService.compute(profile.data) inside _compute_cross_pillar_analysis"
      pattern: "CrossPillarService"
---

<objective>
Re-wire the `get_cross_pillar_analysis` coach tool so its numeric payload is computed server-side by chaining `app.services.rules_engine.get_3a_ceiling` (OPP3 art. 7 ceiling) + `app.services.arbitrage.allocation_annuelle.compare_allocation_annuelle` (annual tax-saving via existing trajectory math) — replacing the current Flutter-injected `ctx["annual_3a_contribution"|"lpp_buyback_max"|"tax_saving_potential"|"lpp_capital"]` reads. Implements CONTEXT D-02 + D-03 + D-04 + D-05 + D-08 + D-13.

**Key reality (grep-verified 2026-05-14, drives this plan):**
1. `get_3a_ceiling` lives at `services/backend/app/services/rules_engine.py:396`. `coach_chat.py:86` already imports it from there. The orchestrator service MUST import it from `rules_engine` too — importing from `coach_chat` would create a circular import.
2. `lpp_buyback_max` has NO server function. It is computed by Flutter `financial_core` and persisted into `profile_data["lpp_buyback_max"]` (see `snapshots/snapshot_service.py:147` writing the same key from `profile_data.get("lpp_buyback_max", 0.0)`). The orchestrator RELAYS this value — it does not recompute. This matches RESEARCH §3 caveat #3 (financial_core parity) and CLAUDE.md rule 4.
3. `tax_saving_potential` has TWO acceptable sources, both reusing existing math (no re-implementation):
   - **Strategy A (preferred):** call `compare_allocation_annuelle(montant_disponible=annual_3a_contribution, taux_marginal=…, potentiel_rachat_lpp=lpp_buyback_max, annees_avant_retraite=1, …)` and read back the 3a option's first-year `cumulative_tax_delta` (sign-flipped to a positive saving). The math runs inside `_build_3a_option` at `allocation_annuelle.py:94` — `annual_tax_saving = contribution * taux_marginal`. The orchestrator is a CALLER, not a re-implementer.
   - **Strategy B (fallback):** if `taux_marginal` cannot be derived from the profile (e.g. canton + income missing), read `profile_data["tax_saving_potential"]` directly (Flutter wrote it via `coach_context_builder.py:78`). If also missing → `Decimal("0.00")` + Sentry breadcrumb tag `tax_saving_source=missing_from_profile`.

Purpose: kill the « LLM emits inter-pillar CHF numbers it read from a stale Flutter ctx » class of hallucination. Produces the `annual3aContribution` / `threeARemaining` / `lppBuybackMax` / `lppCapital` / `taxSavingPotential` known-values surface that Wave 1b will cite via `source_kind="tool_call_id"`.
Output: dispatcher path that, when the flag is ON, returns a JSON string with camelCase fields + `inputsHash`; when OFF, byte-identical legacy output.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-01-PLAN.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/rules_engine.py
@services/backend/app/services/arbitrage/allocation_annuelle.py
@services/backend/app/services/arbitrage/arbitrage_models.py
@services/backend/app/services/arbitrage/rachat_vs_marche.py
@services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py
@services/backend/app/services/coach/inputs_hash.py
@services/backend/app/services/coach/coach_context_builder.py
@services/backend/app/services/snapshots/snapshot_service.py
@CLAUDE.md

<interfaces>
<!-- Every symbol below was grep-verified on live disk 2026-05-14. -->

== Source-of-truth helpers (DO NOT re-implement, IMPORT VERBATIM) ==

From `services/backend/app/services/rules_engine.py:396` — 3a ceiling per OPP3 art. 7:
```python
def get_3a_ceiling(
    employment_status: Optional[str] = None,
    has_2nd_pillar: Optional[bool] = None,
) -> float:
    # returns 7'258 (salarié LPP) or 36'288 (indépendant sans LPP)
```

From `services/backend/app/services/rules_engine.py:370` — marginal tax rate (used by Strategy A):
```python
def calculate_marginal_tax_rate(
    canton: str, income_gross: float, household_type: str = "single"
) -> float:
    # returns combined IFD + cantonal marginal rate, clamped [0.10, 0.45]
```

From `services/backend/app/services/arbitrage/allocation_annuelle.py:324` — chained tax-saving math (Strategy A):
```python
def compare_allocation_annuelle(
    montant_disponible: float,
    taux_marginal: float,
    a3a_maxed: bool = False,
    potentiel_rachat_lpp: float = 0,
    is_property_owner: bool = False,
    taux_hypothecaire: float = 0.015,
    annees_avant_retraite: int = 20,
    rendement_3a: float = 0.02,
    rendement_lpp: float = 0.0125,
    rendement_marche: float = 0.04,
    canton: str = "VD",
) -> ArbitrageResult:
    # Builds up to 4 TrajectoireOption — the "3a" option (id="3a") carries the
    # year-1 tax saving in its trajectory[0].cumulative_tax_delta (NEGATIVE,
    # because the dataclass convention at allocation_annuelle.py:101 is
    # `cumulative_tax_delta=round(-cumulative_tax_saving, 2)` — negative = saving).
    # The orchestrator sign-flips: tax_saving = -options[3a].trajectory[0].cumulative_tax_delta.
```

From `services/backend/app/services/arbitrage/arbitrage_models.py:54` — return shape:
```python
@dataclass
class ArbitrageResult:
    options: List[TrajectoireOption]   # id ∈ {"3a", "rachat_lpp", "amortissement_indirect", "invest_libre"}
    breakeven_year: int
    premier_eclairage: str
    display_summary: str
    hypotheses: List[str]
    disclaimer: str
    sources: List[str]
    confidence_score: float
    sensitivity: Dict[str, float]

@dataclass
class TrajectoireOption:
    id: str             # "3a" for the option we read
    label: str
    trajectory: List[YearlySnapshot]   # trajectory[0].cumulative_tax_delta = -year_1_tax_saving
    terminal_value: float
    cumulative_tax_impact: float
```

From `services/backend/app/services/coach/inputs_hash.py`:
```python
def compute_inputs_hash(inputs: dict[str, Any]) -> str:  # 64-char hex SHA-256 of rfc8785 canonical JSON
```

From `services/backend/app/observability/coach_breadcrumbs.py` (shipped by plan-00):
```python
def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: str,
    extra_tags: Optional[dict] = None,    # for tax_saving_source / lpp_buyback_source
) -> None: ...
```

From `services/backend/app/utils/hashing.py`:
```python
def hash_profile_id(user_id: str | None) -> str: ...   # opaque, irreversible
```

== Legacy formatter (BYTE-IDENTITY TARGET when flag OFF — DO NOT MODIFY) ==

`services/backend/app/api/v1/endpoints/coach_chat.py` line 2595 (def at this exact line per `grep -n`):
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
        ceiling = get_3a_ceiling(
            ctx.get("employment_status"), ctx.get("has_2nd_pillar")
        )
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

== Dispatcher branch (REPLACE — markers must survive verbatim) ==

`services/backend/app/api/v1/endpoints/coach_chat.py:2008-2011` (verified by grep):
```python
    # >>> dispatch: get_cross_pillar_analysis
    if name == "get_cross_pillar_analysis":
        return _format_cross_pillar_analysis(ctx)
    # <<< dispatch: get_cross_pillar_analysis
```

== Profile keys (grep-verified — these are the canonical conventions) ==

- `profile_data["annual_3a_contribution"]` — `structured_reasoning.py:253-254`, `coach_context_builder.py`.
- `profile_data["lpp_buyback_max"]` — written by Flutter financial_core, persisted at `snapshots/snapshot_service.py:147`.
- `profile_data["lpp_avoir"]` (a.k.a. `lpp_capital` in the legacy formatter `ctx`) — `coach_context_builder.py`.
- `profile_data["tax_saving_potential"]` — `structured_reasoning.py:262`, `coach_context_builder.py:92`, `snapshots/snapshot_service.py:147`.
- `profile_data["taux_marginal"]` — when present, used as-is for Strategy A; otherwise the orchestrator derives via `calculate_marginal_tax_rate(canton, income_gross, household_type)` if `canton` + `income_gross_yearly` are present, else Strategy B fallback.
- `profile_data["canton"]`, `profile_data["income_gross_yearly"]`, `profile_data["household_type"]` — `rules_engine.py:709, 959`.
- `profile_data["employment_status"]`, `profile_data["has_2nd_pillar"]` — `rules_engine.py:396` arg names.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: CrossPillarService orchestrator + CrossPillarAnalysisResponse Pydantic + flag (chain rules_engine + allocation_annuelle, NO circular import, NO fabricated names)</name>
  <read_first>
    - services/backend/app/services/rules_engine.py:370-417 (calculate_marginal_tax_rate + get_3a_ceiling — EXACT signatures, no guessing)
    - services/backend/app/services/arbitrage/allocation_annuelle.py:75-110 (_build_3a_option — confirms `cumulative_tax_delta = -cumulative_tax_saving` convention, sign-flip needed)
    - services/backend/app/services/arbitrage/allocation_annuelle.py:324-410 (compare_allocation_annuelle signature + 3a option construction at line 371-378)
    - services/backend/app/services/arbitrage/arbitrage_models.py:38-70 (TrajectoireOption + ArbitrageResult dataclass field names)
    - services/backend/app/services/coach/inputs_hash.py (compute_inputs_hash signature, full file)
    - services/backend/app/services/coach/coach_context_builder.py:30-95 (profile_data keys conventions: tax_saving_potential, annual_3a_contribution, lpp_avoir)
    - services/backend/app/services/snapshots/snapshot_service.py:140-150 (persistence proof that lpp_buyback_max + tax_saving_potential come from profile_data, NOT a server function)
    - services/backend/app/api/v1/endpoints/coach_chat.py:86 (existing `from app.services.rules_engine import get_3a_ceiling` — use the SAME import path, do NOT import from coach_chat)
    - services/backend/app/api/v1/endpoints/coach_chat.py:2595-2620 (legacy _format_cross_pillar_analysis — byte-identity reference)
    - services/backend/tests/test_coach_tools_budget_snapshot.py (mirror its test scaffolding pattern — flat file, pytest, Decimal literals)
  </read_first>
  <files>
    - services/backend/app/services/arbitrage/cross_pillar_service.py (create)
    - services/backend/app/services/arbitrage/__init__.py (modify — append re-export at end of file, do not overwrite plan-02 or plan-04 exports)
    - services/backend/app/models/coach_tools/cross_pillar.py (create)
    - services/backend/tests/test_coach_tools_cross_pillar.py (create)
  </files>
  <behavior>
    - Test 1 (Strategy A success path): `CrossPillarService.compute({"annual_3a_contribution": 5000.0, "lpp_avoir": 95000.0, "lpp_buyback_max": 12000.0, "employment_status": "salarie", "has_2nd_pillar": True, "canton": "VD", "income_gross_yearly": 90000.0, "household_type": "single"})` returns `CrossPillarAnalysis` with `annual_3a_contribution=Decimal("5000.00")`, `three_a_ceiling=Decimal("7258.00")`, `three_a_remaining=Decimal("2258.00")`, `lpp_buyback_max=Decimal("12000.00")`, `lpp_capital=Decimal("95000.00")`, and `tax_saving_potential` derived by sign-flipping `compare_allocation_annuelle(...).options[id=="3a"].trajectory[0].cumulative_tax_delta` (the test does NOT hardcode an exact CHF — it asserts the value equals `Decimal(str(-options_3a.trajectory[0].cumulative_tax_delta)).quantize(Decimal("0.01"))` computed in the test from the same `compare_allocation_annuelle` call, proving chain reuse).
    - Test 2 (Strategy B fallback when canton missing): profile without `canton`/`income_gross_yearly` BUT with `tax_saving_potential=1814.5` → `CrossPillarAnalysis.tax_saving_potential == Decimal("1814.50")`.
    - Test 3 (both missing → 0 + tag): profile without `canton`, without `income_gross_yearly`, AND without `tax_saving_potential` → `tax_saving_potential == Decimal("0.00")` AND (asserted via mocked breadcrumb capture in Test 13) the breadcrumb extra_tag carries `tax_saving_source="missing_from_profile"`.
    - Test 4 (lpp_buyback_max RELAY, not recompute): profile with `lpp_buyback_max=15000.0` → `CrossPillarAnalysis.lpp_buyback_max == Decimal("15000.00")` (no call to any server function).
    - Test 5 (no data → ValueError): profile with neither `annual_3a_contribution` nor `lpp_avoir` nor `lpp_buyback_max` nor `tax_saving_potential` → `pytest.raises(ValueError, match="cross pillar data missing")`.
    - Test 6 (Pydantic camelCase): `CrossPillarAnalysisResponse(annual_3a_contribution=Decimal("5000.00"), three_a_ceiling=Decimal("7258.00"), three_a_remaining=Decimal("2258.00"), lpp_buyback_max=Decimal("12000.00"), lpp_capital=Decimal("95000.00"), tax_saving_potential=Decimal("1700.00"), inputs_hash="a"*64, computed_at=datetime(2026,5,14,12,0,0)).model_dump(by_alias=True)` produces keys `annual3aContribution`, `threeACeiling`, `threeARemaining`, `lppBuybackMax`, `lppCapital`, `taxSavingPotential`, `inputsHash`, `computedAt`.
    - Test 7 (inputs_hash shape): Pydantic model rejects `inputs_hash` shorter or longer than 64 chars.
    - Test 8 (settings flag default): `settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False`.
    - Test 9 (chain reuse, NOT re-implementation): `unittest.mock.patch("app.services.arbitrage.cross_pillar_service.compare_allocation_annuelle")` is called exactly once with `montant_disponible=5000.0`, `potentiel_rachat_lpp=12000.0`, `annees_avant_retraite=1` (Strategy A invocation). When the mock side-effect is set to an ArbitrageResult with a synthetic 3a option whose `trajectory[0].cumulative_tax_delta == -1700.0`, the returned `tax_saving_potential == Decimal("1700.00")`.
  </behavior>
  <action>
    Step A — Create `services/backend/app/services/arbitrage/cross_pillar_service.py`:

    ```python
    """Wave 1a D-02 — server-side orchestrator for get_cross_pillar_analysis.

    Chains the existing rules_engine + arbitrage modules. NO new financial math
    (CLAUDE.md rule 4: financial_core reuse mandatory).

    Architecture (grep-verified 2026-05-14):
      - `get_3a_ceiling` — imported from `app.services.rules_engine` (line 396).
        DO NOT import from `app.api.v1.endpoints.coach_chat` (that module ITSELF
        imports from rules_engine at line 86, so importing back here would
        create a circular import).
      - `compare_allocation_annuelle` — imported from
        `app.services.arbitrage.allocation_annuelle` (line 324). Called with
        `annees_avant_retraite=1` so trajectory[0].cumulative_tax_delta carries
        the year-1 tax saving (sign-flipped: negative = saving, per
        `_build_3a_option` line 101).
      - `lpp_buyback_max` — there is NO server function that derives this from
        a profile. Flutter financial_core writes it into
        `profile_data["lpp_buyback_max"]` (persisted at
        `snapshots/snapshot_service.py:147`). The orchestrator RELAYS this
        value; if absent → Decimal("0.00") + Sentry breadcrumb tag
        `lpp_buyback_source="missing_from_profile"` (emitted at the dispatcher
        layer in Task 2, not here — this service stays pure).
      - `tax_saving_potential`:
          * Strategy A (preferred): call `compare_allocation_annuelle(...)` with
            the profile's annual 3a contribution + marginal rate + buyback.
            Read back the 3a option's year-1 cumulative_tax_delta (sign-flipped).
            The math itself runs in `_build_3a_option` line 94
            (`annual_tax_saving = contribution * taux_marginal`) — we are a
            CALLER, not a re-implementer.
          * Strategy B (fallback when canton/income missing): read
            `profile_data["tax_saving_potential"]` directly (Flutter wrote it
            via `coach_context_builder.py:78`).
          * If neither available → Decimal("0.00") + breadcrumb tag
            `tax_saving_source="missing_from_profile"`.
    """
    from __future__ import annotations

    from dataclasses import dataclass
    from decimal import Decimal, ROUND_HALF_UP

    from app.services.rules_engine import (
        get_3a_ceiling,
        calculate_marginal_tax_rate,
    )
    from app.services.arbitrage.allocation_annuelle import (
        compare_allocation_annuelle,
    )


    @dataclass(frozen=True)
    class CrossPillarAnalysis:
        annual_3a_contribution: Decimal
        three_a_ceiling: Decimal
        three_a_remaining: Decimal
        lpp_buyback_max: Decimal
        lpp_capital: Decimal
        tax_saving_potential: Decimal
        # Diagnostic tags consumed by the dispatcher layer to enrich the
        # Sentry breadcrumb. NOT serialized into the Pydantic response.
        lpp_buyback_source: str = "from_profile"   # or "missing_from_profile"
        tax_saving_source: str = "strategy_a"      # or "strategy_b" or "missing_from_profile"


    def _q(v) -> Decimal:
        """Quantize to 2 decimals. Matches the Decimal convention used across
        Wave 1a tools (plan-01 budget_snapshot, plan-02 retirement_projection)."""
        return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


    class CrossPillarService:
        @staticmethod
        def compute(profile_data: dict) -> CrossPillarAnalysis:
            """Compute the cross-pillar analysis from a ProfileModel.data dict.

            Reads (per `coach_context_builder.py` and `_format_cross_pillar_analysis`
            ctx conventions):
              - annual_3a_contribution (CHF, optional)
              - lpp_avoir (CHF, optional; legacy ctx key was `lpp_capital`)
              - lpp_buyback_max (CHF, optional; from Flutter financial_core)
              - tax_saving_potential (CHF, optional; Strategy B fallback)
              - employment_status, has_2nd_pillar (for ceiling lookup)
              - canton, income_gross_yearly, household_type, taux_marginal
                (for Strategy A marginal-rate input)

            Raises ValueError("cross pillar data missing") if NONE of the five
            payload-bearing fields (annual_3a_contribution, lpp_avoir,
            lpp_buyback_max, tax_saving_potential, lpp_capital alias) are
            present — mirrors `_format_cross_pillar_analysis` line 2602 guard.
            """
            annual_3a = profile_data.get("annual_3a_contribution")
            lpp_avoir = profile_data.get("lpp_avoir")
            if lpp_avoir is None:
                # Legacy ctx alias — `_format_cross_pillar_analysis` reads
                # `ctx.get("lpp_capital")`. Some profiles persist under that
                # name. Accept both.
                lpp_avoir = profile_data.get("lpp_capital")
            lpp_buyback_raw = profile_data.get("lpp_buyback_max")
            tax_saving_raw_profile = profile_data.get("tax_saving_potential")

            if (
                annual_3a is None
                and lpp_avoir is None
                and lpp_buyback_raw is None
                and tax_saving_raw_profile is None
            ):
                raise ValueError("cross pillar data missing")

            # === 3a ceiling (OPP3 art. 7) — single source of truth ===
            employment_status = profile_data.get("employment_status", "salarie")
            has_2nd_pillar = profile_data.get("has_2nd_pillar", True)
            ceiling_raw = get_3a_ceiling(employment_status, has_2nd_pillar)

            annual_3a_d = _q(annual_3a) if annual_3a is not None else Decimal("0.00")
            three_a_ceiling_d = _q(ceiling_raw)
            three_a_remaining_d = max(
                Decimal("0.00"), three_a_ceiling_d - annual_3a_d
            )

            # === LPP buyback max — RELAY from profile (no server function) ===
            if lpp_buyback_raw is None:
                lpp_buyback_max_d = Decimal("0.00")
                lpp_buyback_source = "missing_from_profile"
            else:
                lpp_buyback_max_d = _q(lpp_buyback_raw)
                lpp_buyback_source = "from_profile"

            # === LPP capital — relay from profile ===
            lpp_capital_d = _q(lpp_avoir) if lpp_avoir is not None else Decimal("0.00")

            # === Tax saving — Strategy A (chain) → Strategy B (relay) → 0 + tag ===
            tax_saving_d, tax_saving_source = _derive_tax_saving(
                profile_data=profile_data,
                annual_3a=annual_3a,
                lpp_buyback_max=float(lpp_buyback_max_d),
                tax_saving_raw_profile=tax_saving_raw_profile,
            )

            return CrossPillarAnalysis(
                annual_3a_contribution=annual_3a_d,
                three_a_ceiling=three_a_ceiling_d,
                three_a_remaining=three_a_remaining_d,
                lpp_buyback_max=lpp_buyback_max_d,
                lpp_capital=lpp_capital_d,
                tax_saving_potential=tax_saving_d,
                lpp_buyback_source=lpp_buyback_source,
                tax_saving_source=tax_saving_source,
            )


    def _derive_tax_saving(
        profile_data: dict,
        annual_3a: float | None,
        lpp_buyback_max: float,
        tax_saving_raw_profile: float | None,
    ) -> tuple[Decimal, str]:
        """Pick a tax-saving derivation path. Returns (value, source_tag).

        Strategy A — chain `compare_allocation_annuelle`. Requires `annual_3a`
        (or any positive disposable amount) AND a derivable marginal rate.
        The marginal rate comes from `profile_data["taux_marginal"]` if
        present, else from `calculate_marginal_tax_rate(canton, income, type)`
        if canton + income_gross_yearly are present.

        Strategy B — read `profile_data["tax_saving_potential"]` directly.

        Fallback — return Decimal("0.00") with source tag "missing_from_profile".
        """
        montant_disponible = float(annual_3a) if annual_3a is not None else 0.0

        # Derive marginal rate (Strategy A pre-requisite).
        taux_marginal: float | None = None
        explicit_taux = profile_data.get("taux_marginal")
        if explicit_taux is not None:
            taux_marginal = float(explicit_taux)
        else:
            canton = profile_data.get("canton")
            income_gross = profile_data.get("income_gross_yearly")
            if canton and income_gross is not None:
                household = profile_data.get("household_type", "single")
                taux_marginal = calculate_marginal_tax_rate(
                    canton=str(canton),
                    income_gross=float(income_gross),
                    household_type=str(household),
                )

        # --- Strategy A: chain compare_allocation_annuelle ---
        if taux_marginal is not None and montant_disponible > 0:
            try:
                result = compare_allocation_annuelle(
                    montant_disponible=montant_disponible,
                    taux_marginal=taux_marginal,
                    a3a_maxed=False,
                    potentiel_rachat_lpp=lpp_buyback_max,
                    is_property_owner=bool(profile_data.get("is_property_owner", False)),
                    annees_avant_retraite=1,  # year-1 tax saving readout
                    canton=str(profile_data.get("canton") or "VD"),
                )
                option_3a = next(
                    (o for o in result.options if o.id == "3a"), None
                )
                if option_3a is not None and option_3a.trajectory:
                    # cumulative_tax_delta is NEGATIVE for a saving
                    # (`allocation_annuelle.py:101`). Sign-flip to positive.
                    saving = -option_3a.trajectory[0].cumulative_tax_delta
                    return _q(saving), "strategy_a"
            except Exception:
                # Defensive — never let the chain crash compute(). Fall
                # through to Strategy B / fallback.
                pass

        # --- Strategy B: relay from profile ---
        if tax_saving_raw_profile is not None:
            return _q(tax_saving_raw_profile), "strategy_b"

        # --- Fallback: 0 + tag ---
        return Decimal("0.00"), "missing_from_profile"
    ```

    Step B — Append to `services/backend/app/services/arbitrage/__init__.py` (do NOT overwrite — plan-02 / plan-04 may already export from this module). Read the file first; if `CrossPillarService` is not yet re-exported, APPEND at the end:

    ```python
    from app.services.arbitrage.cross_pillar_service import (  # noqa: E402,F401
        CrossPillarService,
        CrossPillarAnalysis,
    )
    ```

    Step C — Create `services/backend/app/models/coach_tools/cross_pillar.py`:

    ```python
    """Wave 1a D-03 — get_cross_pillar_analysis response model.

    camelCase aliases via pydantic.alias_generators.to_camel — matches the
    backend AGENT contract (CLAUDE.md §1) and the sibling plan-01
    BudgetSnapshotResponse pattern.

    Note on `annual_3a_contribution` → `annual3aContribution` alias: the
    pydantic.alias_generators.to_camel function preserves digits adjacent to
    letters, so `annual_3a_contribution` correctly maps to `annual3aContribution`
    (verified in CONTEXT D-02 must_haves and plan-01's identical pattern). If
    this ever changes, override with an explicit `Field(..., alias="annual3aContribution")`.
    """
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

    Step D — DO NOT modify `services/backend/app/models/coach_tools/__init__.py` (plan-00 created the empty marker; plans 01-05 import directly from per-tool files to avoid parallel-write races).

    Step E — Flag verification (plan-00 added all 6 Wave 1a flags as a single block). Plan-03 only READS `COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED`. Verify before proceeding:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/core/config.py
    # Expected: 1 (added by plan-00)
    ```
    If grep returns 0, STOP and confirm `depends_on: [wave-1a-00]` was honored.

    Step F — Create `services/backend/tests/test_coach_tools_cross_pillar.py` with Tests 1-9. Notes:
      - For Test 1 (Strategy A): do NOT hardcode a CHF — call `compare_allocation_annuelle` from the test itself with the same args and assert the returned `tax_saving_potential` equals the sign-flipped `option_3a.trajectory[0].cumulative_tax_delta` from that call. This proves chain reuse without coupling the test to a specific CHF value that could drift if the underlying math changes.
      - For Test 9 (chain assertion): use `unittest.mock.patch("app.services.arbitrage.cross_pillar_service.compare_allocation_annuelle")` with a side-effect returning a synthetic `ArbitrageResult` from `app.services.arbitrage.arbitrage_models`. Assert `mock.call_args.kwargs["montant_disponible"] == 5000.0`, `mock.call_args.kwargs["potentiel_rachat_lpp"] == 12000.0`, `mock.call_args.kwargs["annees_avant_retraite"] == 1`.
      - All Decimal asserts use `Decimal("…")` literals; mocked-3a trajectory[0].cumulative_tax_delta is `-1700.0` (sign-flipped → tax_saving == Decimal("1700.00")).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_cross_pillar.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.arbitrage.cross_pillar_service import CrossPillarService, CrossPillarAnalysis; print('ok')"` exits 0.
    - `python3 -c "from app.services.arbitrage import CrossPillarService, CrossPillarAnalysis; print('ok')"` exits 0 (re-export via package __init__).
    - `python3 -c "from app.models.coach_tools.cross_pillar import CrossPillarAnalysisResponse; print('ok')"` exits 0.
    - `python3 -c "from app.services.rules_engine import get_3a_ceiling; print('ok')"` exits 0 (real home of the helper).
    - `python3 -c "from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle; print('ok')"` exits 0 (real chain target).
    - `grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "from app.services.rules_engine import" services/backend/app/services/arbitrage/cross_pillar_service.py` returns ≥1 (BLOCK-1 fix: real home, not coach_chat).
    - `grep -c "from app.api.v1.endpoints.coach_chat import" services/backend/app/services/arbitrage/cross_pillar_service.py` returns 0 (BLOCK-1 fix: no circular import).
    - `grep -c "compute_lpp_buyback_max" services/backend/app/services/arbitrage/cross_pillar_service.py` returns 0 (BLOCK-2 fix: fabricated name purged).
    - `grep -c "compute_annual_tax_saving" services/backend/app/services/arbitrage/cross_pillar_service.py` returns 0 (BLOCK-2 fix: fabricated name purged).
    - `grep -c "compare_allocation_annuelle" services/backend/app/services/arbitrage/cross_pillar_service.py` returns ≥2 (import + call, chain reuse).
    - `grep -c "except ImportError" services/backend/app/services/arbitrage/cross_pillar_service.py` returns 0 (no silent fallback).
    - `grep -c "alias_generator=to_camel" services/backend/app/models/coach_tools/cross_pillar.py` returns 1.
    - `pytest services/backend/tests/test_coach_tools_cross_pillar.py -q` exits 0 with ≥9 tests collected.
  </acceptance_criteria>
  <done>
    Orchestrator + Pydantic model exist; chains rules_engine.get_3a_ceiling + allocation_annuelle.compare_allocation_annuelle by real import paths; relays profile-supplied lpp_buyback_max + tax_saving_potential without fabricating server functions; 9+ unit tests green; zero circular import; zero fabricated names.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_cross_pillar_analysis sibling + dispatcher branch + breadcrumb (incl. missing-source tags) + ≥4 more tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py:1900-2015 (dispatcher entry — `_execute_internal_tool` signature has `user_id`, NOT `profile_id`)
    - services/backend/app/api/v1/endpoints/coach_chat.py:2008-2011 (`# >>> dispatch: get_cross_pillar_analysis` marker pair, current 4-line block targeting `_format_cross_pillar_analysis`)
    - services/backend/app/api/v1/endpoints/coach_chat.py:2595-2620 (legacy formatter — preserve, do not delete or modify)
    - services/backend/app/observability/coach_breadcrumbs.py (full file — `emit_coach_tool_breadcrumb` signature, including `extra_tags` kwarg from plan-00)
    - services/backend/app/utils/hashing.py (full file — `hash_profile_id` signature)
    - services/backend/app/services/coach/inputs_hash.py (full file — `compute_inputs_hash` signature)
    - services/backend/tests/test_coach_tools_budget_snapshot.py (mirror its dispatcher-test pattern — monkeypatch flag, mock DB query, assert byte-identity legacy fallback)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — insert `_compute_cross_pillar_analysis` above the legacy formatter, replace dispatcher branch body, preserve markers)
    - services/backend/tests/test_coach_tools_cross_pillar.py (extend — append Tests 10-13)
  </files>
  <behavior>
    - Test 10 (flag OFF byte-identity): `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", False)` + call `_compute_cross_pillar_analysis(user_id="dummy", ctx={"annual_3a_contribution": 5000.0, "lpp_buyback_max": 12000.0, "tax_saving_potential": 1700.0, "lpp_capital": 95000.0, "employment_status": "salarie", "has_2nd_pillar": True}, db=mock_db)` returns the EXACT string produced by `_format_cross_pillar_analysis(ctx)` with the same ctx (string equality assertion).
    - Test 11 (flag ON success): flag True + mock DB returning a `ProfileModel` whose `.data` has the full Strategy A profile → returned JSON string parses as `CrossPillarAnalysisResponse` with `annualThreeAContribution` ≈ camelCase keys (verify `annual3aContribution`, `threeARemaining`, `lppBuybackMax`, `taxSavingPotential`, `inputsHash` length 64).
    - Test 12 (flag ON + ValueError → legacy fallback): flag True + mock DB returning a `ProfileModel` whose `.data` has NONE of the five payload-bearing fields → `CrossPillarService.compute` raises `ValueError`, dispatcher falls back to `_format_cross_pillar_analysis(ctx)` and returns its byte-identical "Données d'analyse inter-piliers non disponibles dans le profil." or partial string from the ctx.
    - Test 13 (lpp_buyback_max missing → 0 + breadcrumb tag, RESEARCH §3 caveat #3 enforcement): flag True + profile WITHOUT `lpp_buyback_max` BUT WITH `annual_3a_contribution` → response JSON has `lppBuybackMax == "0.00"` AND the captured `emit_coach_tool_breadcrumb` call kwargs include `extra_tags={"lpp_buyback_source": "missing_from_profile", "tax_saving_source": ...}` (assert via `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")`).
    - Test 14 (inputs_hash determinism): two consecutive `_compute_cross_pillar_analysis` calls with the same profile produce identical `inputsHash` strings (proves SHA-256 + canonical JSON behaviour, not random).
  </behavior>
  <action>
    Step A — Insert `_compute_cross_pillar_analysis(user_id, ctx, db) -> str` IMMEDIATELY ABOVE the existing `def _format_cross_pillar_analysis(ctx: dict) -> str:` at line ~2595. Mirror the plan-01 PANEL-FIXED pattern exactly:

    ```python
    def _compute_cross_pillar_analysis(user_id: str | None, ctx: dict, db) -> str:
        """Wave 1a D-02 server-side path for get_cross_pillar_analysis.

        Returns either:
          - JSON string `CrossPillarAnalysisResponse.model_dump_json(by_alias=True)`
            (flag ON success), OR
          - legacy FR string from `_format_cross_pillar_analysis(ctx)` (flag OFF
            or any fallback condition).

        Fallback conditions:
          - settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False, OR
          - user_id is None / db session is None, OR
          - DB returns no ProfileModel for user_id / profile.data is empty, OR
          - CrossPillarService.compute raises ValueError("cross pillar data missing"), OR
          - any other Exception (defensive — never crash the coach turn).

        Sentry breadcrumb tags (D-15 + RESEARCH §3 caveat #3):
          - lpp_buyback_source: "from_profile" or "missing_from_profile"
          - tax_saving_source: "strategy_a" | "strategy_b" | "missing_from_profile"
        """
        import time
        import logging
        from app.core.config import settings
        if not settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED:
            return _format_cross_pillar_analysis(ctx)
        if not user_id or db is None:
            return _format_cross_pillar_analysis(ctx)
        _t0 = time.perf_counter()
        try:
            from app.models.profile_model import ProfileModel
            from app.services.arbitrage.cross_pillar_service import CrossPillarService
            from app.services.coach.inputs_hash import compute_inputs_hash
            from app.models.coach_tools.cross_pillar import (
                CrossPillarAnalysisResponse,
            )
            from app.observability.coach_breadcrumbs import (
                emit_coach_tool_breadcrumb,
            )
            from app.utils.hashing import hash_profile_id
            from datetime import datetime, timezone

            # Newest-profile-wins lookup — canonical pattern (plan-01 Task 2,
            # plan-02 Task 2). Filter by user_id (FK), not id (PK).
            profile = (
                db.query(ProfileModel)
                .filter(ProfileModel.user_id == user_id)
                .order_by(ProfileModel.updated_at.desc())
                .first()
            )
            if profile is None or not profile.data:
                return _format_cross_pillar_analysis(ctx)

            analysis = CrossPillarService.compute(profile.data)

            slice_ = {
                "annual_3a_contribution": float(analysis.annual_3a_contribution),
                "lpp_buyback_max": float(analysis.lpp_buyback_max),
                "lpp_capital": float(analysis.lpp_capital),
                "tax_saving_potential": float(analysis.tax_saving_potential),
                "three_a_ceiling": float(analysis.three_a_ceiling),
            }
            response = CrossPillarAnalysisResponse(
                annual_3a_contribution=analysis.annual_3a_contribution,
                three_a_ceiling=analysis.three_a_ceiling,
                three_a_remaining=analysis.three_a_remaining,
                lpp_buyback_max=analysis.lpp_buyback_max,
                lpp_capital=analysis.lpp_capital,
                tax_saving_potential=analysis.tax_saving_potential,
                inputs_hash=compute_inputs_hash(slice_),
                computed_at=datetime.now(timezone.utc),
            )

            elapsed_ms = int((time.perf_counter() - _t0) * 1000)
            emit_coach_tool_breadcrumb(
                tool_name="cross_pillar",
                inputs_hash=response.inputs_hash,
                profile_id_hashed=hash_profile_id(user_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
                extra_tags={
                    "lpp_buyback_source": analysis.lpp_buyback_source,
                    "tax_saving_source": analysis.tax_saving_source,
                },
            )
            return response.model_dump_json(by_alias=True)
        except Exception as exc:
            logging.getLogger(__name__).warning(
                "compute_cross_pillar_analysis failed, falling back to legacy: %s",
                exc,
            )
            return _format_cross_pillar_analysis(ctx)
    ```

    Step B — Replace the dispatcher branch body INSIDE the marker pair (lines 2008-2011, verified by grep). Markers MUST be preserved verbatim.

    Find:
    ```python
        # >>> dispatch: get_cross_pillar_analysis
        if name == "get_cross_pillar_analysis":
            return _format_cross_pillar_analysis(ctx)
        # <<< dispatch: get_cross_pillar_analysis
    ```

    Replace with:
    ```python
        # >>> dispatch: get_cross_pillar_analysis
        if name == "get_cross_pillar_analysis":
            return _compute_cross_pillar_analysis(user_id=user_id, ctx=ctx, db=db)
        # <<< dispatch: get_cross_pillar_analysis
    ```

    Rationale for `user_id` (not `profile_id`): `_execute_internal_tool` signature (`coach_chat.py:1914-1924`) carries `user_id`, NOT `profile_id`. Mirrors panel fix backend-architect obs-d518b856d7e4fe1a applied to plan-01 + plan-02.

    Step C — Extend `services/backend/tests/test_coach_tools_cross_pillar.py` with Tests 10-14:
      - Use `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True|False)` to flip the flag.
      - Mock `db.query(ProfileModel).filter(...).order_by(...).first()` to return a synthetic `ProfileModel` with `.data` set to the test profile dict. Use `unittest.mock.MagicMock` chain (mirror plan-01 test setup).
      - For Test 13, patch `app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb` and assert the call's `kwargs["extra_tags"]["lpp_buyback_source"] == "missing_from_profile"`.
      - DO NOT touch any other dispatcher branch, formatter, or unrelated test (Karpathy #3 surgical scope).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_cross_pillar.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + import-in-def or comment).
    - `grep -c "_format_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy def preserved + fallback calls in _compute_).
    - `grep -c "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "# >>> dispatch: get_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved).
    - `grep -c "# <<< dispatch: get_cross_pillar_analysis" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved).
    - `grep -E "tool_name=\"cross_pillar\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "extra_tags=\{" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (D-15 + RESEARCH §3 caveat #3 tags emitted).
    - `grep -E "lpp_buyback_source" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "tax_saving_source" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (plans 01 + 02 + 03 all wired).
    - `grep -E "filter\(ProfileModel\.user_id == user_id\)" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 in `_compute_cross_pillar_analysis` body.
    - `pytest services/backend/tests/test_coach_tools_cross_pillar.py -q` exits 0 with ≥13 tests collected.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/arbitrage/cross_pillar_service.py services/backend/app/models/coach_tools/cross_pillar.py` exits 0.
    - Full backend pytest delta ≥ +13 tests versus pre-task baseline.
  </acceptance_criteria>
  <done>
    Dispatcher routes through `_compute_cross_pillar_analysis`; flag ON returns camelCase JSON + inputs_hash + chained tax_saving (Strategy A) or relayed (Strategy B) or 0+tag (fallback); flag OFF byte-identical legacy; ≥13 tests green; lints clean on touched files; financial_core reuse confirmed (no new math — caller of existing functions).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM → backend dispatcher | LLM picks tool_name; backend resolves to `_compute_cross_pillar_analysis` or legacy fallback. Adversarial LLM cannot bypass flag (server-side check). |
| backend → ProfileModel.data (DB) | Read-only profile fetch; no write surface on this path. |
| Flutter financial_core → profile_data (DB) | `lpp_buyback_max` and `tax_saving_potential` may be persisted from Flutter. Server RELAYS these values; if absent → Decimal("0.00") + Sentry tag (no fabrication). |
| backend → Sentry breadcrumb | Outbound telemetry; non-PII only. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-03-01 | T | Legacy `_format_cross_pillar_analysis` regression when flag OFF | mitigate | Test 10 asserts byte-identity of legacy output via direct string comparison. |
| T-WAVE1A-03-02 | I | LSFin banned-terms leak via new Python service strings | mitigate | `CrossPillarService.compute` returns numerics only (Decimal). NO French strings emitted by the service. Banned-terms lint enforced in verify. |
| T-WAVE1A-03-03 | I | PII leak in Sentry breadcrumb | mitigate | Breadcrumb payload is `{inputs_hash, profile_id_hashed, elapsed_ms, flag_state, extra_tags}`. `inputs_hash` is SHA-256 (irreversible). `profile_id_hashed` is irreversible via `hash_profile_id`. `extra_tags` contain only enum strings (`from_profile`, `missing_from_profile`, `strategy_a`, `strategy_b`). No raw CHF, no user_id, no canton. |
| T-WAVE1A-03-04 | T | numeric drift between Flutter financial_core (tax_saving) and Python service | mitigate | Strategy B (relay) is exact byte-identical when `profile_data["tax_saving_potential"]` is present. Strategy A reuses existing Python `compare_allocation_annuelle` math, which already shares formulas with financial_core per CONTEXT D-02. Plan-07 parity harness asserts ±0.01 CHF. |
| T-WAVE1A-03-05 | T | re-implementation of `_calculate*` financial math (CLAUDE.md rule 4 violation) | mitigate | Acceptance criteria enforce: (a) `grep -c "from app.services.rules_engine import" cross_pillar_service.py ≥ 1` (real home of `get_3a_ceiling`, no copy-paste), (b) `grep -c "compare_allocation_annuelle" cross_pillar_service.py ≥ 2` (import + call, chain reuse), (c) `grep -c "compute_lpp_buyback_max" returns 0` (fabricated name absent), (d) `grep -c "compute_annual_tax_saving" returns 0` (fabricated name absent). Service body contains NO arithmetic beyond Decimal quantization + sign-flip — all CHF/rate math runs inside the called modules. |
| T-WAVE1A-03-06 | T | circular import via `coach_chat` ↔ `cross_pillar_service` (BLOCK-1 from python-pro panel) | mitigate | Acceptance criterion: `grep -c "from app.api.v1.endpoints.coach_chat import" cross_pillar_service.py` returns 0. The service imports `get_3a_ceiling` from its real home `app.services.rules_engine` (line 396), same path coach_chat itself uses at line 86. |
| T-WAVE1A-03-07 | I | silent zero in `lpp_buyback_max` when Flutter forgets to write the field (data-quality blind spot) | mitigate | Test 13 + acceptance criterion `grep -E "lpp_buyback_source"` ≥ 1: when the field is absent the service tags the breadcrumb `lpp_buyback_source="missing_from_profile"`, making the gap observable on Sentry (Phase 95 DAG-INVALIDATION + Wave 1c eval can act on it). |

</threat_model>

<verification>
- `pytest services/backend/tests/test_coach_tools_cross_pillar.py -q` exits 0 with ≥13 tests.
- `pytest services/backend/ -q` full suite — zero regressions vs pre-plan baseline.
- `banned_terms_python.py` + `accent_lint_fr.py` green on touched files.
- `grep` proves `CrossPillarService` chains existing modules via REAL import paths and contains NO fabricated function names.
- `grep` proves NO `from app.api.v1.endpoints.coach_chat import` inside `cross_pillar_service.py` (circular import absent).
</verification>

<success_criteria>
- WAVE1A-03 satisfied: `get_cross_pillar_analysis` recomputes server-side when flag ON, chaining `rules_engine.get_3a_ceiling` + `allocation_annuelle.compare_allocation_annuelle`; legacy path preserved when flag OFF.
- WAVE1A-09 satisfied: response is a Pydantic v2 model with `alias_generator=to_camel`, asserted by Test 6.
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED` flag exists in `settings.py` (added by plan-00), default False, asserted by Test 8.
- ≥13 new backend tests, lints green, financial_core reuse confirmed (no new math, real import paths, no fabricated names, no circular import).
- python-pro BLOCK-1 + BLOCK-2 from obs-67d0ed986ae0d316 both addressed at acceptance-criterion-grep level.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-03-SUMMARY.md` with: files created/modified, tests added (per-test names), pytest baseline delta, banned-terms + accent_lint outputs, the 12 critical `grep` outputs from the acceptance_criteria sections (especially the 4 BLOCK-1/BLOCK-2 anti-fabrication greps), and the 0-trust self-check section citing each command's actual output.
</output>
