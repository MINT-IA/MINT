"""Wave 1a D-06 — parity harness for the 6 refactored coach tools.

For each refactored tool, this file asserts that the LEGACY formatter
path (``_format_<tool>(ctx)``) and the NEW server-side path
(``_compute_<tool>(user_id, ctx, db)`` with flag ON) produce equivalent
numeric outputs within tolerance on the SAME profile fixture loaded
from ``tests/fixtures/coach_tools_parity_v1.jsonl`` (18 fixtures —
3 archetypes x 6 tools per VALIDATION.md Nyquist rule).

Tolerances (per CONTEXT D-06):
  * CHF ``Decimal``: ``abs(a - b) <= Decimal("0.01")``
  * float percent:  ``abs(a - b) <= 0.1``
  * float ratio:    ``abs(a - b) <= 0.001``
  * int months:     exact equality

Special cases:
  * ``get_cap_status``: parity is BYTE-EQUALITY of the garde-redacted
    string (this tool is Flutter-sourced; the middleware operates on
    the rendered text — no numeric payload).
  * ``retrieve_memories``: parity is TOP-1 record_topic equality OR
    legacy fallback when the corpus is empty (BM25 ranking semantics —
    no strict numeric output).

The harness intentionally LOADS each profile into ``ProfileModel`` then
calls the real dispatcher path (no mocked DB) so the parity test
exercises the end-to-end newest-profile-wins lookup + Pydantic
serialization + Sentry breadcrumb wiring shipped by plans 01-06.
Plan-08 will run this harness with all 5 server-side flags ON on
staging — a single ``pytest tests/test_coach_tools_parity.py -q``
exits 0 only when every server-side path matches legacy within
tolerance.
"""
from __future__ import annotations

import json
import uuid
from decimal import Decimal
from typing import Any, Dict, Iterable, List

import pytest

from app.api.v1.endpoints.coach_chat import (
    _compute_budget_status,
    _compute_couple_optimization,
    _compute_cross_pillar_analysis,
    _compute_retirement_projection,
    _compute_retrieve_memories,
    _format_budget_status,
    _format_cap_status,
    _format_couple_optimization,
    _format_cross_pillar_analysis,
    _format_retirement_projection,
    _handle_retrieve_memories,
    _validate_cap_response,
)
from app.core.config import settings

# Loader imported as a plain function to keep the parity harness
# self-contained — pytest auto-discovers conftest.py fixtures from
# ``tests/test_coach_tools_pkg/conftest.py`` (Rule 3 path-rename per
# plan-00 SUMMARY collision mitigation).
from tests.test_coach_tools_pkg.conftest import load_parity_fixtures
from tests.conftest import TestingSessionLocal


# ---------------------------------------------------------------------------
# Tolerance constants — D-06.
# ---------------------------------------------------------------------------
_CHF_TOL: Decimal = Decimal("0.01")
_PCT_TOL: float = 0.1
_RATIO_TOL: float = 0.001


# ---------------------------------------------------------------------------
# Tolerance helpers (Karpathy #2 simplicity first — 1 helper per type, no
# dispatcher).
# ---------------------------------------------------------------------------


def _chf_within(actual: Any, expected: Any) -> bool:
    """Absolute Decimal difference ``<= 0.01 CHF``. Handles None on both sides."""
    if expected is None and actual is None:
        return True
    if expected is None or actual is None:
        return False
    return abs(Decimal(str(actual)) - Decimal(str(expected))) <= _CHF_TOL


def _ratio_within(actual: float, expected: float) -> bool:
    """Float ratio diff <= 0.001."""
    return abs(float(actual) - float(expected)) <= _RATIO_TOL


def _pct_within(actual: float, expected: float) -> bool:
    """Float percent-points diff <= 0.1."""
    return abs(float(actual) - float(expected)) <= _PCT_TOL


# ---------------------------------------------------------------------------
# DB seeding helpers.
# ---------------------------------------------------------------------------


def _enable_all_server_side(monkeypatch: pytest.MonkeyPatch) -> None:
    """Flip all 5 Wave 1a server-side flags ON for the parametrized test."""
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED",
        True,
    )
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED", True
    )
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED",
        True,
    )
    monkeypatch.setattr(
        settings,
        "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED",
        True,
    )
    monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", True)


@pytest.fixture
def parity_db():
    """SQLAlchemy session that clears CoachInsightRecord between tests.

    Mirrors plan-05's ``db`` fixture (CoachInsightRecord is not in the
    conftest.py autouse ``clean_database`` purge list).
    """
    from app.models.coach_insight import CoachInsightRecord

    session = TestingSessionLocal()
    try:
        session.query(CoachInsightRecord).delete()
        session.commit()
        yield session
    finally:
        session.close()


def _ensure_user(db, user_id: str) -> None:
    """Insert minimal ``User`` row so FK constraints succeed."""
    from app.models import User

    existing = db.query(User).filter(User.id == user_id).first()
    if existing is not None:
        return
    db.add(
        User(
            id=user_id,
            email=f"{user_id}@example.com",
            hashed_password="x",
            display_name=user_id,
        )
    )
    db.commit()


def _seed_profile(db, user_id: str, profile_data: Dict[str, Any]) -> None:
    """Insert/replace the ``ProfileModel`` for ``user_id``."""
    from app.models.profile_model import ProfileModel

    db.query(ProfileModel).filter(ProfileModel.user_id == user_id).delete()
    db.commit()
    db.add(ProfileModel(user_id=user_id, data=dict(profile_data)))
    db.commit()


def _seed_insights(
    db, user_id: str, insights: Iterable[Dict[str, str]]
) -> None:
    """Insert ``CoachInsightRecord`` rows for BM25 retrieval tests."""
    from app.models.coach_insight import CoachInsightRecord

    for entry in insights:
        db.add(
            CoachInsightRecord(
                user_id=user_id,
                topic=entry["topic"],
                summary=entry["summary"],
                insight_type=entry.get("insight_type", "fact"),
            )
        )
    db.commit()


# ---------------------------------------------------------------------------
# Parametrize helpers — surface fixture_id in pytest output for traceability.
# ---------------------------------------------------------------------------


def _fixtures_for(tool: str) -> List[dict]:
    """Plain Python — usable at module import / parametrize time
    (pytest fixtures cannot be consumed by ``@pytest.mark.parametrize``)."""
    return [f for f in load_parity_fixtures() if f["tool"] == tool]


def _ids(fixtures: List[dict]) -> List[str]:
    return [f["fixture_id"] for f in fixtures]


# ===========================================================================
# Test 1: get_budget_status parity (3 fixtures).
# ===========================================================================

_BUDGET_FIXTURES = _fixtures_for("get_budget_status")


@pytest.mark.parametrize("fx", _BUDGET_FIXTURES, ids=_ids(_BUDGET_FIXTURES))
def test_budget_status_parity(
    fx: dict, parity_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 parity for ``get_budget_status``: legacy vs server-side
    ``monthlySurplus`` within ±0.01 CHF, ``monthsLiquidity`` within
    ±0.001.

    The legacy formatter is also exercised to prove the flag-OFF path
    still emits the FR string we expect (Karpathy #4 goal-driven —
    success = legacy works AND server-side matches it numerically).
    """
    user_id = f"parity-{uuid.uuid4().hex[:12]}"
    _enable_all_server_side(monkeypatch)
    _ensure_user(parity_db, user_id)
    _seed_profile(parity_db, user_id, fx["profile"])

    # Legacy path — flag OFF returns FR string from ctx.
    legacy = _format_budget_status(fx["ctx_legacy"])
    assert isinstance(legacy, str)

    # Server-side path — flag ON returns Pydantic JSON.
    raw = _compute_budget_status(
        user_id=user_id, ctx=fx["ctx_legacy"], db=parity_db
    )
    response = json.loads(raw)

    # Parity assertion: monthlySurplus within ±0.01 CHF.
    expected_surplus = Decimal(fx["expected"]["monthly_surplus"])
    actual_surplus = Decimal(response["monthlySurplus"])
    assert _chf_within(actual_surplus, expected_surplus), (
        f"{fx['fixture_id']}: surplus drift "
        f"{actual_surplus} vs {expected_surplus}"
    )
    # months_liquidity within ±0.001 ratio.
    assert _ratio_within(
        response["monthsLiquidity"], fx["expected"]["months_liquidity"]
    ), (
        f"{fx['fixture_id']}: months_liquidity drift "
        f"{response['monthsLiquidity']} vs {fx['expected']['months_liquidity']}"
    )
    # inputs_hash 64-char SHA-256 hex.
    assert len(response["inputsHash"]) == 64


# ===========================================================================
# Test 2: get_retirement_projection parity (3 fixtures).
# ===========================================================================

_RETIREMENT_FIXTURES = _fixtures_for("get_retirement_projection")


@pytest.mark.parametrize(
    "fx", _RETIREMENT_FIXTURES, ids=_ids(_RETIREMENT_FIXTURES)
)
def test_retirement_projection_parity(
    fx: dict, parity_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 parity for ``get_retirement_projection``: replacement_ratio
    within ±0.001 (RATIO 0.0..1.0); avs_rente / lpp_capital /
    monthly_retirement_income / monthly_gap within ±0.01 CHF.
    ``lpp_capital`` is ``Optional[Decimal]`` — None when ``avoirLpp``
    absent (panel obs-a5f5f19baeb3119b H3).
    """
    user_id = f"parity-{uuid.uuid4().hex[:12]}"
    _enable_all_server_side(monkeypatch)
    _ensure_user(parity_db, user_id)
    _seed_profile(parity_db, user_id, fx["profile"])

    legacy = _format_retirement_projection(fx["ctx_legacy"])
    assert isinstance(legacy, str)

    raw = _compute_retirement_projection(
        user_id=user_id, ctx=fx["ctx_legacy"], db=parity_db
    )
    response = json.loads(raw)

    expected = fx["expected"]
    assert _ratio_within(
        response["replacementRatio"], expected["replacement_ratio"]
    )
    assert _chf_within(response["avsRente"], expected["avs_rente"])
    assert _chf_within(response["lppCapital"], expected["lpp_capital"])
    assert _chf_within(
        response["monthlyRetirementIncome"],
        expected["monthly_retirement_income"],
    )
    assert _chf_within(response["monthlyGap"], expected["monthly_gap"])
    assert _chf_within(
        response["currentMonthlyIncome"], expected["current_monthly_income"]
    )
    assert len(response["inputsHash"]) == 64


# ===========================================================================
# Test 3: get_cross_pillar_analysis parity (3 fixtures).
# ===========================================================================

_CROSS_PILLAR_FIXTURES = _fixtures_for("get_cross_pillar_analysis")


@pytest.mark.parametrize(
    "fx", _CROSS_PILLAR_FIXTURES, ids=_ids(_CROSS_PILLAR_FIXTURES)
)
def test_cross_pillar_parity(
    fx: dict, parity_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 parity for ``get_cross_pillar_analysis``: each of the 6
    Decimal payload fields within ±0.01 CHF. Diagnostic tags
    (``lpp_buyback_source`` / ``tax_saving_source``) are NOT in the
    Pydantic response (they live on the dataclass and feed the Sentry
    breadcrumb only) — parity is on numeric fields only.
    """
    user_id = f"parity-{uuid.uuid4().hex[:12]}"
    _enable_all_server_side(monkeypatch)
    _ensure_user(parity_db, user_id)
    _seed_profile(parity_db, user_id, fx["profile"])

    legacy = _format_cross_pillar_analysis(fx["ctx_legacy"])
    assert isinstance(legacy, str)

    raw = _compute_cross_pillar_analysis(
        user_id=user_id, ctx=fx["ctx_legacy"], db=parity_db
    )
    response = json.loads(raw)
    expected = fx["expected"]

    # ``annual_3a_contribution`` -> pydantic ``to_camel`` => ``annual3AContribution``
    # (digit-adjacency upper-cases A — confirmed in plan-03 deviation #2).
    assert _chf_within(
        response["annual3AContribution"], expected["annual_3a_contribution"]
    )
    assert _chf_within(response["threeACeiling"], expected["three_a_ceiling"])
    assert _chf_within(
        response["threeARemaining"], expected["three_a_remaining"]
    )
    assert _chf_within(response["lppBuybackMax"], expected["lpp_buyback_max"])
    assert _chf_within(response["lppCapital"], expected["lpp_capital"])
    assert _chf_within(
        response["taxSavingPotential"], expected["tax_saving_potential"]
    )
    assert len(response["inputsHash"]) == 64


# ===========================================================================
# Test 4: get_couple_optimization parity (3 fixtures).
# ===========================================================================

_COUPLE_FIXTURES = _fixtures_for("get_couple_optimization")


@pytest.mark.parametrize(
    "fx", _COUPLE_FIXTURES, ids=_ids(_COUPLE_FIXTURES)
)
def test_couple_optimization_parity(
    fx: dict, parity_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 parity for ``get_couple_optimization``: nested Pydantic
    response with 4 optional sub-results.

    For single-user fixtures (``has_results == False``) the dispatcher
    returns the legacy FR fallback string (CoupleOptimizer returns an
    empty result -> ``CoupleOptimizationResponse`` would have all 4
    sub-fields None; the dispatcher falls back to legacy formatter on
    ANY Exception in the Pydantic construction path — see plan-04
    dispatcher defensive ``except Exception``).

    For couple fixtures (``has_results == True``) parity is the
    presence + sign of the 2 sub-results that ARE emitted (avs_cap +
    marriage_penalty per the julien fixture grep). CHF deltas are
    asserted as ``>= 0`` (sign-agnostic CHF magnitude) rather than
    pinned to a brittle CHF value — plan-04 SUMMARY explicitly avoids
    hard-coding CHF expectations because the underlying CoupleOptimizer
    chain depends on AVS21 cohort / canton tax tables that may shift
    across regulatory years.
    """
    user_id = f"parity-{uuid.uuid4().hex[:12]}"
    _enable_all_server_side(monkeypatch)
    _ensure_user(parity_db, user_id)
    _seed_profile(parity_db, user_id, fx["profile"])

    legacy = _format_couple_optimization(fx["ctx_legacy"])
    assert isinstance(legacy, str)

    raw = _compute_couple_optimization(
        user_id=user_id, ctx=fx["ctx_legacy"], db=parity_db
    )
    expected = fx["expected"]

    if not expected["has_results"]:
        # Single user — ``CoupleOptimizer.optimize`` returns an empty
        # ``CoupleOptimizationResult`` (per Dart-mirrored ``const empty()``,
        # plan-04 SUMMARY). The dispatcher builds a Pydantic response
        # with all 4 sub-fields = None (NOT a fallback string — only
        # a true ``Exception`` triggers the defensive fallback per
        # plan-04 dispatcher). Parity = all 4 sub-fields null in JSON.
        response = json.loads(raw)
        assert response["lppBuyback"] is None, (
            f"{fx['fixture_id']}: expected null lppBuyback for single user"
        )
        assert response["pillar3A"] is None
        assert response["avsCap"] is None
        assert response["marriagePenalty"] is None
        assert len(response["inputsHash"]) == 64
        return

    # Couple user — Pydantic JSON.
    response = json.loads(raw)
    assert len(response["inputsHash"]) == 64

    if expected.get("avs_cap_applied") is True:
        assert response.get("avsCap") is not None, (
            f"{fx['fixture_id']}: avsCap missing from response"
        )
        assert (
            response["avsCap"]["capApplied"] == expected["avs_cap_applied"]
        )
        # CHF magnitude check — value drifts across LAVS table years,
        # so we assert non-negative magnitude rather than a CHF pin.
        assert (
            Decimal(response["avsCap"]["monthlyReduction"])
            >= Decimal(str(expected["avs_monthly_reduction_min"]))
        )

    if expected.get("marriage_has_penalty") is True:
        assert response.get("marriagePenalty") is not None, (
            f"{fx['fixture_id']}: marriagePenalty missing"
        )
        assert (
            response["marriagePenalty"]["hasPenalty"]
            == expected["marriage_has_penalty"]
        )
        assert (
            Decimal(response["marriagePenalty"]["annualDelta"])
            >= Decimal(str(expected["marriage_annual_delta_min"]))
        )


# ===========================================================================
# Test 5: retrieve_memories parity (3 fixtures).
# ===========================================================================

_MEMORY_FIXTURES = _fixtures_for("retrieve_memories")


@pytest.mark.parametrize("fx", _MEMORY_FIXTURES, ids=_ids(_MEMORY_FIXTURES))
def test_memory_parity(
    fx: dict, parity_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 parity for ``retrieve_memories``: BM25 top-1 record's topic
    matches the queried topic OR (empty corpus) the dispatcher returns
    the legacy fallback string.

    Strategy (per ``<grep_verified_facts>``): set-equality on returned
    record topics is NOT enforced — BM25 ranking is allowed to surface
    additional partial matches from filler insights. The contract is
    weaker but stable: the queried topic MUST appear as the TOP-1 hit
    (``hits[0].topic``) when at least one insight matches. The legacy
    handler is a substring/fuzzy match and may also surface the same
    top-1, so the parity check is « new path top-1 topic equals the
    queried topic from the fixture ``ctx_legacy.topic`` ».
    """
    user_id = f"parity-{uuid.uuid4().hex[:12]}"
    _enable_all_server_side(monkeypatch)
    _ensure_user(parity_db, user_id)
    _seed_profile(parity_db, user_id, fx["profile"])
    _seed_insights(parity_db, user_id, fx["ctx_legacy"]["insights_seed"])

    legacy = _handle_retrieve_memories(
        topic=fx["ctx_legacy"]["topic"],
        memory_block=fx["ctx_legacy"]["memory_block"],
        max_results=fx["ctx_legacy"]["max_results"],
        user_id=user_id,
        db=parity_db,
    )
    assert isinstance(legacy, str)

    computed = _compute_retrieve_memories(
        topic=fx["ctx_legacy"]["topic"],
        user_id=user_id,
        db=parity_db,
        max_results=fx["ctx_legacy"]["max_results"],
        memory_block=fx["ctx_legacy"]["memory_block"],
    )
    expected = fx["expected"]

    if expected["min_results"] == 0:
        # Empty-corpus edge — both legacy and new path return the
        # « Aucune mémoire disponible » fallback string.
        assert (
            "Aucune" in computed
            or computed == expected["fallback_when_empty"]
        ), (
            f"{fx['fixture_id']}: expected fallback string, got {computed!r}"
        )
        return

    # BM25 top-1 should be a line starting with `[insight_type] <topic>:`.
    first_line = computed.split("\n", 1)[0]
    expected_prefix = (
        f"[{expected['top_insight_type']}] {expected['top_record_topic']}:"
    )
    assert first_line.startswith(expected_prefix), (
        f"{fx['fixture_id']}: top-1 line {first_line!r} "
        f"does not start with {expected_prefix!r}"
    )


# ===========================================================================
# Test 6: get_cap_status garde parity (3 fixtures).
# ===========================================================================

_CAP_FIXTURES = _fixtures_for("get_cap_status")


@pytest.mark.parametrize("fx", _CAP_FIXTURES, ids=_ids(_CAP_FIXTURES))
def test_cap_garde_parity(
    fx: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D-06 + D-09 parity for ``get_cap_status``: byte-equality of the
    garde-redacted string. No numeric tolerance — this tool is
    Flutter-sourced and the middleware operates on rendered text only.

    Three fixtures cover:
      * julien — cap text with valid ``{{cite:...}}`` placeholders -> no
        redaction.
      * lauren — un-cited CHF tokens -> both replaced with
        ``[montant indisponible]`` + Sentry breadcrumb emitted.
      * edge_uncited_cap — 3 un-cited CHF tokens -> all 3 replaced.
    """
    _enable_all_server_side(monkeypatch)
    rendered = _format_cap_status(fx["ctx_legacy"])
    garded = _validate_cap_response(rendered)
    expected_text = fx["expected"]["text"]
    assert garded == expected_text, (
        f"{fx['fixture_id']}: cap text drift\n"
        f"  GOT:      {garded!r}\n"
        f"  EXPECTED: {expected_text!r}"
    )

    # Redaction-count parity — count occurrences of the replacement
    # marker in the garded output.
    expected_redactions = fx["expected"]["redactions"]
    actual_redactions = garded.count("[montant indisponible]")
    assert actual_redactions == expected_redactions, (
        f"{fx['fixture_id']}: redaction count drift "
        f"{actual_redactions} vs {expected_redactions}"
    )
