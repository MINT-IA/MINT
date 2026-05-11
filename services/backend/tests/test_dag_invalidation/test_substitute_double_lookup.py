"""Phase 95 — D-09 double-lookup cohabitation tests."""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import patch, MagicMock

import pytest

from app.services.coach.citation_parser import _substitute_placeholders
from app.services.coach.grounding_pack import (
    GroundingPackEntry,
    ParetoPoint,
    ProjectionGroundingPack,
)


def _make_entry(value="1234.56"):
    return GroundingPackEntry(
        value=Decimal(value),
        raw={"trace": "test"},
        source_ref="test.source",
        staleness_iso=datetime.now(timezone.utc).isoformat(),
    )


def _make_pack(entries: dict):
    pareto = ParetoPoint(
        label="fiscal_pure",
        weights={"tax_saving": Decimal("1.00"), "liquidity": Decimal("0.00"), "ruin_red": Decimal("0.00")},
        allocation={"3a": Decimal("0.00"), "rachat_lpp": Decimal("0.00"), "amort_indirect": Decimal("0.00")},
        projected_outcomes={"tax_saving_chf": Decimal("0.00"), "liquidity_score": Decimal("0.00"), "ruin_prob_red": Decimal("0.00")},
    )
    return ProjectionGroundingPack(
        inputs_hash="a" * 64,
        entries=entries,
        pareto_points=[pareto, pareto, pareto],
        what_ifs={f"sensitivity_x_{i}": _make_entry() for i in range(5)},
        legal_constraints=[],
        superseded_by=None,
    )


def test_pack_hit_overrides_registry():
    pack = _make_pack({"r3a_plafond_salarie_2026": _make_entry("7056.00")})
    text = "Le plafond est {{cite:r3a_plafond_salarie_2026}} CHF."
    ctx = MagicMock()
    result = _substitute_placeholders(text, ctx, pack=pack)
    assert "7056.00" in result
    assert "{{cite:" not in result


def test_pack_miss_falls_back_to_registry():
    pack = _make_pack({})  # empty pack
    text = "Article {{cite:lifd_art_33_deduction}}."
    ctx = MagicMock()
    result = _substitute_placeholders(text, ctx, pack=pack)
    # registry returns FR description ; verify it is NOT the verbatim placeholder
    assert "{{cite:lifd_art_33_deduction}}" not in result


def test_both_miss_keeps_placeholder():
    pack = _make_pack({})
    text = "Unknown {{cite:totally_unknown_key}}."
    ctx = MagicMock()
    result = _substitute_placeholders(text, ctx, pack=pack)
    assert "{{cite:totally_unknown_key}}" in result


def test_pack_none_preserves_phase_94_behavior():
    text = "Article {{cite:lifd_art_33_deduction}}."
    ctx = MagicMock()
    with_pack_none = _substitute_placeholders(text, ctx, pack=None)
    without_pack = _substitute_placeholders(text, ctx)
    assert with_pack_none == without_pack


def test_pack_param_is_keyword_only():
    text = "x {{cite:k}}"
    ctx = MagicMock()
    pack = _make_pack({})
    with pytest.raises(TypeError):
        _substitute_placeholders(text, ctx, pack)  # positional 3rd arg


def test_sentry_breadcrumb_on_fallback():
    pack = _make_pack({})  # empty pack
    text = "{{cite:lifd_art_33_deduction}}"
    ctx = MagicMock()
    with patch("app.services.coach.citation_parser.sentry_sdk.add_breadcrumb") as mock_bc:
        _substitute_placeholders(text, ctx, pack=pack)
    # At least one breadcrumb fired ; category & message correct
    assert mock_bc.called
    call_kwargs = mock_bc.call_args.kwargs if mock_bc.call_args.kwargs else {}
    import json as _json
    serialized = _json.dumps(call_kwargs, default=str) + _json.dumps(list(mock_bc.call_args.args), default=str)
    assert "coach.grounding_pack.fallback" in serialized


def test_coach_chat_wiring_pack_kwarg_threaded():
    """Verify coach_chat.py wires pack= through to both _citation_gate calls."""
    with open("app/api/v1/endpoints/coach_chat.py") as f:
        source = f.read()
    # Count pack= occurrences within _run_narrator_with_gate function body
    wrapper_start = source.find("async def _run_narrator_with_gate")
    wrapper_end = source.find("loop_result = await _run_narrator_with_gate", wrapper_start)
    assert wrapper_start > 0, "_run_narrator_with_gate not found"
    assert wrapper_end > wrapper_start, "wrapper bounds invalid"
    wrapper_body = source[wrapper_start:wrapper_end]
    assert wrapper_body.count("pack=") >= 2, (
        f"Expected >=2 `pack=` kwargs in _run_narrator_with_gate body, "
        f"got {wrapper_body.count('pack=')}"
    )


# --- BLOCKER-3 fix : pack.inputs_hash propagation into GatedResponse ---
def test_gated_response_inputs_hash_propagated_from_pack():
    """Asserts gate() returns a GatedResponse whose inputs_hash equals
    pack.inputs_hash when pack is supplied. Covers the 7 stub sites at
    citation_parser.py:430/459/468/512/521/533 that BLOCKER-3 requires
    propagate `inputs_hash=pack.inputs_hash if pack else None` instead
    of hardcoding `inputs_hash=None`.
    """
    from app.services.coach.citation_parser import gate
    expected_hash = "abc123" + "0" * 58  # 64-char SHA256-shaped hex
    pack = _make_pack({"r3a_plafond_salarie_2026": _make_entry("7056.00")})
    # Override the inputs_hash for the assertion (frozen — must rebuild)
    pack = pack.model_copy(update={"inputs_hash": expected_hash})

    ctx = MagicMock()
    result = gate(
        response_text="Le plafond est {{cite:r3a_plafond_salarie_2026}}.",
        ctx=ctx,
        citation_allowlist=None,
        is_retry=False,
        pack=pack,
    )
    assert result.inputs_hash == expected_hash, (
        f"GatedResponse.inputs_hash = {result.inputs_hash!r}, expected "
        f"{expected_hash!r} — one of the 7 stub sites at "
        f"citation_parser.py:430/459/468/512/521/533 still hardcodes None."
    )


def test_gated_response_inputs_hash_none_when_pack_none():
    """Counter-test : pack=None keeps inputs_hash=None on the returned
    GatedResponse (Phase 94 byte-identity preserved on flag-OFF path)."""
    from app.services.coach.citation_parser import gate
    ctx = MagicMock()
    result = gate(
        response_text="Article {{cite:lifd_art_33_deduction}}.",
        ctx=ctx,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
    )
    assert result.inputs_hash is None
