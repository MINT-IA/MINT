---
phase: wave-1a
plan: 07
type: execute
wave: 2
depends_on: [wave-1a-01, wave-1a-02, wave-1a-03, wave-1a-04, wave-1a-05, wave-1a-06]
files_modified:
  - services/backend/tests/fixtures/coach_tools_parity_v1.jsonl
  - services/backend/tests/test_coach_tools_parity.py
  - services/backend/tests/test_coach_tools/conftest.py
autonomous: true
requirements: [WAVE1A-08]
must_haves:
  truths:
    - "Parity harness pytest file exists and parametrizes over 18 fixtures (3 archetypes × 6 tools)"
    - "Each parity case runs BOTH the legacy formatter path AND the new server-side path on the same input profile, asserts numeric fields within tolerance"
    - "Tolerances: CHF ±0.01, percent ±0.1pt, ratio ±0.001, months int exact"
    - "Per-tool edge case present (per VALIDATION.md sampling rule): negative surplus, age=65, lpp_buyback_max=0, single user, empty insights, un-cited cap CHF"
    - "Fixture jsonl is human-readable and version-controlled"
  artifacts:
    - path: "services/backend/tests/fixtures/coach_tools_parity_v1.jsonl"
      provides: "18 fixtures (3 archetypes × 6 tools) — Julien cross-border + Lauren freelance + edge-case per tool"
      contains: "fixture_id"
      min_lines: 18
    - path: "services/backend/tests/test_coach_tools_parity.py"
      provides: "pytest harness parametrized by tool + fixture_id"
      contains: "test_budget_status_parity\\|test_retirement_projection_parity\\|test_cross_pillar_parity\\|test_couple_parity\\|test_memory_parity\\|test_cap_garde_parity"
    - path: "services/backend/tests/test_coach_tools/conftest.py"
      provides: "Shared fixture loader (parity_fixtures fixture + per-tool fixtures fixture)"
      contains: "def parity_fixtures"
  key_links:
    - from: "services/backend/tests/test_coach_tools_parity.py"
      to: "services/backend/tests/fixtures/coach_tools_parity_v1.jsonl"
      via: "fixtures = parity_fixtures(tool='get_budget_status')"
      pattern: "coach_tools_parity_v1.jsonl"
    - from: "services/backend/tests/test_coach_tools_parity.py"
      to: "services/backend/app/api/v1/endpoints/coach_chat.py"
      via: "calls _compute_budget_status / _compute_retirement_projection / etc."
      pattern: "_compute_"
---

<objective>
Build the parity test infrastructure per CONTEXT D-06 + D-11 + VALIDATION.md Nyquist sampling rule.

**Fixture count reconciliation (checker iteration-1 issue #3):** CONTEXT.md D-06 cites « 5 seed fixtures (1 per refactored tool) » as an EXAMPLE / floor value. VALIDATION.md applies the Nyquist sampling rule and lands on 18 fixtures (3 archetypes × 6 tools). **VALIDATION.md is authoritative — 18 is the target.** D-06's « 5 » is a floor (minimum), not a ceiling. Wave 1c extends further toward the 20 paires Q&A suite.

Wave 1a ships the harness + 18 seed fixtures (3 archetypes × 6 tools); Wave 1c will extend to the full 20 paires Q&A suite.

For each refactored tool, the harness asserts that the LEGACY formatter (`_format_*(ctx)`) and the NEW server-side path (`_compute_*` with flag ON) produce equivalent numeric outputs ±tolerance, given the same profile fixture. Plan-08 wires the rollout flags so this can be run on staging with all flags ON.

Purpose: closes the Wave 1a 5-gate G4 mechanically — gives Plan-08 a single command (`pytest tests/test_coach_tools_parity.py`) that returns exit 0 if and only if every server-side path matches legacy within tolerance.
Output: harness + 18 fixtures + fixture loader.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/tests/conftest.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

JSONL fixture format (D-06):
```jsonl
{"fixture_id": "julien_v1__get_budget_status", "tool": "get_budget_status", "archetype": "cross_border", "profile": {...full ProfileModel.data slice...}, "ctx_legacy": {"monthly_income": 7500.0, "monthly_expenses": 5200.0, "months_liquidity": 4.6}, "expected": {"monthly_surplus": "2300.00", "months_liquidity": 4.6}}
```

3 archetypes per VALIDATION.md:
- Julien — cross-border worker, age ~32, married, mid-income (CHF 7500/mo).
- Lauren — independent_no_lpp, age ~28, single, freelance income (CHF 5800/mo).
- Edge case per tool (see VALIDATION.md table):
  - `get_budget_status`: monthly_expenses > monthly_income (negative surplus, months_liquidity=0).
  - `get_retirement_projection`: age=65 (rente immediate), replacement_ratio<50%.
  - `get_cross_pillar_analysis`: lpp_buyback_max=0 (no buyback room).
  - `get_couple_optimization`: civil_status="single" (returns CoupleOptimizationResult.empty()).
  - `retrieve_memories`: empty CoachInsightRecord table for user (fallback to ProfileModel.data).
  - `get_cap_status`: cap text containing CHF without `{{cite:}}` (garde must redact).

Total: 6 tools × 3 fixtures = 18.

Tolerances (D-06):
- CHF Decimal: `abs(legacy - new) <= Decimal("0.01")`
- float percent: `abs(legacy - new) <= 0.1`
- float ratio: `abs(legacy - new) <= 0.001`
- int months: exact equality.

For `get_cap_status`, parity is byte-equality of the garde-redacted string (not numeric). For `retrieve_memories`, parity is asserted on the set of returned record_ids OR on the BM25 top-1 == legacy top-1 (legacy fuzzy-matched topic against memory_block).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create 18 parity fixtures in coach_tools_parity_v1.jsonl + fixture loader conftest</name>
  <read_first>
    - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md (sampling rule table)
    - services/backend/tests/conftest.py (existing DB session fixture pattern)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2249-2415 (the 6 _format_* legacy functions — derive ctx_legacy keys + expected from these)
    - All 6 plan SUMMARYs from Wave 1 (wave-1a-01-SUMMARY.md ... wave-1a-06-SUMMARY.md) — they document the actual response shapes the server-side path emits.
    - services/backend/app/models/profile_model.py (ProfileModel.data canonical shape)
  </read_first>
  <files>
    - services/backend/tests/fixtures/coach_tools_parity_v1.jsonl (create)
    - services/backend/tests/test_coach_tools/conftest.py (create — fixture loader)
  </files>
  <behavior>
    - Each of the 18 lines in `coach_tools_parity_v1.jsonl` is a valid JSON object with keys `fixture_id`, `tool`, `archetype`, `profile`, `ctx_legacy`, `expected`.
    - `fixture_id` follows the pattern `{archetype}__{tool}` (e.g. `julien__get_budget_status`, `lauren__get_retirement_projection`, `edge_negative_surplus__get_budget_status`).
    - `parity_fixtures(tool: str)` pytest fixture returns the list of fixture dicts for that tool (3 per tool).
    - Loader raises if the JSONL is malformed (one fixture per line, no trailing comma).
  </behavior>
  <action>
    Step A — Build the 18 fixtures. For each (archetype × tool):

    `julien` archetype (cross_border, age 32, married, salary 7500/mo, lpp_avoir 95000, annual_3a 5000):
    - `julien__get_budget_status`: `profile.data = {"monthly_income": 7500.0, "monthly_expenses": 5200.0, "months_liquidity": 4.6, ...}`. `ctx_legacy = {"monthly_income": 7500.0, "monthly_expenses": 5200.0, "months_liquidity": 4.6}`. `expected = {"monthly_surplus": "2300.00", "months_liquidity": 4.6}`.
    - `julien__get_retirement_projection`: profile carries salary_gross_yearly=90000, lpp_avoir=95000, age=32, gender="M". Expected derived by RUNNING `RetirementProjectionService.compute(profile)` from plan-02 and capturing the output. (Executor: call the service in a one-shot to fill in.)
    - `julien__get_cross_pillar_analysis`: profile carries annual_3a_contribution=5000, lpp_avoir=95000, employment_status="salarie", has_2nd_pillar=true. Expected from `CrossPillarService.compute(...)`.
    - `julien__get_couple_optimization`: profile carries civil_status="marie", spouse data. Expected from `CoupleOptimizer.optimize(...)`.
    - `julien__retrieve_memories`: insert 3 CoachInsightRecord rows for user, query topic="3a". Expected top-1 record_id.
    - `julien__get_cap_status`: ctx with `cap_expected_impact="économise 1'250 CHF par an"` (NO cite) → expected text `"Impact attendu : économise [montant indisponible] par an"`.

    `lauren` archetype (independent_no_lpp, age 28, single, salary 5800/mo, no LPP):
    - 6 fixtures mirroring above, with lauren's profile values.

    `edge` archetype (one edge case per tool per VALIDATION.md):
    - `edge_negative_surplus__get_budget_status`: monthly_income=4000, monthly_expenses=5500 → expected monthly_surplus="-1500.00", months_liquidity=0.0.
    - `edge_age_65__get_retirement_projection`: profile age=65, replacement_ratio<0.5 → expected as computed.
    - `edge_no_buyback__get_cross_pillar_analysis`: lpp_buyback_max=0 → expected three_a_remaining present, lpp_buyback_max=0.00.
    - `edge_single__get_couple_optimization`: civil_status="single" → expected response with all 4 sub-results == None.
    - `edge_empty_insights__retrieve_memories`: insert 0 CoachInsightRecord, profile.data["recent_insights"]=[] → expected hits = [].
    - `edge_uncited_cap__get_cap_status`: ctx with 2 un-cited CHF tokens in cap_expected_impact → expected both replaced with `[montant indisponible]`.

    Write the 18 fixtures as ONE LINE per JSON object, no pretty-print (jsonl convention).

    Step B — Create `services/backend/tests/test_coach_tools/conftest.py`:
    ```python
    """Wave 1a parity-test fixture loader."""
    import json
    from pathlib import Path
    import pytest

    _FIXTURE_PATH = Path(__file__).parent.parent / "fixtures" / "coach_tools_parity_v1.jsonl"


    @pytest.fixture(scope="session")
    def all_parity_fixtures() -> list[dict]:
        fixtures: list[dict] = []
        with _FIXTURE_PATH.open("r", encoding="utf-8") as f:
            for lineno, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    fixtures.append(json.loads(line))
                except json.JSONDecodeError as exc:
                    raise RuntimeError(
                        f"malformed fixture at {_FIXTURE_PATH}:{lineno}: {exc}"
                    ) from exc
        return fixtures


    @pytest.fixture(scope="session")
    def parity_fixtures(all_parity_fixtures):
        """Returns a callable: parity_fixtures(tool='get_budget_status') -> list[dict]."""
        def _get(tool: str) -> list[dict]:
            return [f for f in all_parity_fixtures if f["tool"] == tool]
        return _get
    ```

    Step C — Generate the EXACTLY-expected values for each fixture by INVOKING the corresponding `_compute_*` function in an interactive python shell during execution. The executor MUST NOT hand-fabricate expected values — invoke the service / dispatcher and capture the output. Document any expected value that diverged from a hand-computed estimate in the SUMMARY.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -c "import json; lines = open('tests/fixtures/coach_tools_parity_v1.jsonl').readlines(); assert len(lines) >= 18, f'got {len(lines)} fixtures'; [json.loads(l) for l in lines]; print('ok 18 fixtures parseable')"</automated>
  </verify>
  <acceptance_criteria>
    - `wc -l services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` returns ≥18.
    - Every line is valid JSON (verify command above checks).
    - `grep -c "get_budget_status\|get_retirement_projection\|get_cross_pillar_analysis\|get_couple_optimization\|retrieve_memories\|get_cap_status" services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` returns ≥18 (one per tool entry).
    - `python3 -c "from tests.test_coach_tools.conftest import parity_fixtures" ` does not raise (after pytest pickup the fixture).
    - `grep -c "julien\|lauren\|edge" services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` returns ≥18 (each fixture is tagged with archetype).
  </acceptance_criteria>
  <done>
    18 fixtures present, jsonl parseable, loader fixture available.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create test_coach_tools_parity.py harness with one parametrized test per tool</name>
  <read_first>
    - services/backend/tests/test_coach_tools/conftest.py (just created in Task 1)
    - services/backend/tests/fixtures/coach_tools_parity_v1.jsonl (just created)
    - The 6 _compute_* functions in services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/conftest.py (DB fixture pattern)
  </read_first>
  <files>
    - services/backend/tests/test_coach_tools_parity.py (create)
  </files>
  <behavior>
    - `test_budget_status_parity[fixture_id]` runs for 3 fixtures, each asserts:
      1. Legacy: `_format_budget_status(ctx_legacy)` returns the legacy string.
      2. Server-side: with flag ON, `_compute_budget_status(profile_id, ctx_legacy, db)` returns parseable JSON with `monthlySurplus` matching `expected.monthly_surplus` ±Decimal("0.01").
    - Same pattern for retirement_projection, cross_pillar, couple_optimization.
    - `test_memory_parity[fixture_id]`: asserts the BM25 top-1 record_id matches the legacy `_handle_retrieve_memories` top-1 OR (for fallback case) returns empty list as expected.
    - `test_cap_garde_parity[fixture_id]`: asserts the garde-applied output string matches the `expected` string byte-for-byte.
    - Total: 6 tests × 3 fixtures = 18 parametrized cases.
  </behavior>
  <action>
    Step A — Create `services/backend/tests/test_coach_tools_parity.py`:

    ```python
    """Wave 1a D-06 — parity harness.

    Each refactored tool runs through BOTH:
      (a) the legacy _format_*(ctx) path
      (b) the new _compute_*(profile_id, ctx, db) path with flag ON
    Tolerances per D-06 :
      - CHF Decimal ±0.01
      - float percent ±0.1
      - float ratio ±0.001
      - int months exact
    """
    import json
    from decimal import Decimal
    import pytest

    from app.api.v1.endpoints.coach_chat import (
        _format_budget_status,
        _compute_budget_status,
        _format_retirement_projection,
        _compute_retirement_projection,
        _format_cross_pillar_analysis,
        _compute_cross_pillar_analysis,
        _format_couple_optimization,
        _compute_couple_optimization,
        _format_cap_status,
        _validate_cap_response,
    )
    from app.core.config import settings


    _CHF_TOL = Decimal("0.01")
    _PCT_TOL = 0.1
    _RATIO_TOL = 0.001


    def _enable_all_server_side(monkeypatch):
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True)
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED", True)
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True)
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True)
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True)
        monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", True)


    @pytest.mark.parametrize("fx", [None], ids=["lazy"])  # replaced by parametrize_with_fixtures
    def test_budget_status_parity(parity_fixtures, monkeypatch, db_session, fx):
        for fx in parity_fixtures("get_budget_status"):
            _enable_all_server_side(monkeypatch)
            # Insert ProfileModel for this fixture.
            from app.models.profile_model import ProfileModel
            profile = ProfileModel(id=fx["fixture_id"], data=fx["profile"])
            db_session.add(profile)
            db_session.commit()
            try:
                legacy = _format_budget_status(fx["ctx_legacy"])
                assert isinstance(legacy, str) and "Budget actuel" in legacy or "non disponibles" in legacy
                # Server-side path.
                response_json = _compute_budget_status(
                    profile_id=fx["fixture_id"], ctx=fx["ctx_legacy"], db=db_session
                )
                response = json.loads(response_json)
                expected_surplus = Decimal(fx["expected"]["monthly_surplus"])
                actual_surplus = Decimal(response["monthlySurplus"])
                assert abs(actual_surplus - expected_surplus) <= _CHF_TOL, (
                    f"{fx['fixture_id']}: surplus drift {actual_surplus} vs {expected_surplus}"
                )
                assert abs(response["monthsLiquidity"] - fx["expected"]["months_liquidity"]) <= _RATIO_TOL
            finally:
                db_session.delete(profile)
                db_session.commit()


    # Mirror pattern for: test_retirement_projection_parity, test_cross_pillar_parity,
    # test_couple_parity, test_memory_parity, test_cap_garde_parity.

    # For test_cap_garde_parity, no DB needed:
    def test_cap_garde_parity(parity_fixtures, monkeypatch):
        for fx in parity_fixtures("get_cap_status"):
            _enable_all_server_side(monkeypatch)
            legacy = _format_cap_status(fx["ctx_legacy"])
            garded = _validate_cap_response(legacy)
            assert garded == fx["expected"]["text"], (
                f"{fx['fixture_id']}: cap text drift {garded!r} vs {fx['expected']['text']!r}"
            )
    ```

    NOTE — the executor MUST fill in the remaining 4 test functions (retirement_projection, cross_pillar, couple_optimization, retrieve_memories) following the same pattern. For `couple_optimization`, deep-compare the nested response (`lpp_buyback.saving_delta`, `avs_cap.monthly_reduction`, `marriage_penalty.annual_delta`) each with ±0.01 CHF. For `retrieve_memories`, assert the returned formatted string lists the expected top-1 topic.

    Step B — If `db_session` fixture is not already present in `services/backend/tests/conftest.py`, ADD it (SQLAlchemy session with rollback per-test). Mirror the existing pattern if any.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_parity.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "^def test_" services/backend/tests/test_coach_tools_parity.py` returns ≥6 (one per tool).
    - `grep -c "_CHF_TOL\|Decimal.*0.01" services/backend/tests/test_coach_tools_parity.py` returns ≥1 (tolerance constant defined and used).
    - `grep -c "_enable_all_server_side\|COACH_TOOL_SERVER_SIDE_.*_ENABLED" services/backend/tests/test_coach_tools_parity.py` returns ≥6 (all flags toggled ON in tests).
    - `pytest services/backend/tests/test_coach_tools_parity.py -q` exits 0 with ≥18 parametrized cases.
    - `pytest services/backend/ -q` full suite — ZERO regressions versus pre-plan-07 baseline.
  </acceptance_criteria>
  <done>
    Parity harness covers all 6 tools × 3 fixtures with explicit tolerances; all parametrized cases pass.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-07-01 | T | Fixture jsonl tampering hides parity drift | mitigate | Fixtures committed under version control; PR review will catch silent edits; each fixture's `expected` values were derived by INVOKING the actual `_compute_*` function during creation (not hand-coded). |
| T-WAVE1A-07-02 | I | LSFin banned-terms in fixture FR strings | mitigate | `tools/checks/banned_terms_python.py` runs on jsonl via a glob in plan-08's close-out script. |
| T-WAVE1A-07-03 | I | PII (real names, real CHF) in fixtures | mitigate | « julien » and « lauren » are persona names not real users; CHF values are synthetic (e.g. 7500 round number). Fixture file MUST NOT contain any real email, IBAN, AHV13, or real surname. |
| T-WAVE1A-07-04 | T | Parity tolerance too loose (±0.01 CHF on a CHF 100k+ value = 0.00001% — fine; on a CHF 0.50 value = 2% — coarser) | accept | Per D-06, tolerance is absolute CHF; for couple_optimization saving_delta values typically ≥CHF 100 → ≤0.01% relative; acceptable for v1. Wave 1c can tighten if needed. |
</threat_model>

<verification>
- `pytest tests/test_coach_tools_parity.py -q` exits 0 with ≥18 cases.
- `pytest services/backend/ -q` full suite — zero regressions.
- Fixtures jsonl parseable (one JSON object per line).
- 6/6 tools have a parity test (`grep` proof).
- Tolerances explicitly cited in the source.
</verification>

<success_criteria>
- WAVE1A-08 satisfied: parity harness exists at `tests/test_coach_tools_parity.py`; 18 fixtures shipped; 6/6 tools covered; tolerances per D-06 enforced.
- Full pytest suite green at the wave-2 boundary, ready for plan-08 close-out.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-07-SUMMARY.md` with:
- 18 fixtures (table: fixture_id × tool × archetype × expected-key sample value)
- 6 parity tests (test_name + assertion summary)
- Baseline pytest count delta (`pytest services/backend/ -q | tail -1`)
- 0-trust self-check section citing automated command outputs verbatim.
</output>
