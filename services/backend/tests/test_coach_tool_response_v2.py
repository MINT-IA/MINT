"""Phase mint-calc-engine-v1 Plan 10 (W2-04) — CoachToolResponseV2 envelope tests.

Parallel Change V2 (D-CE-19 Fowler pattern). V2 ships ALONGSIDE V1 — these
tests assert V2 envelope behavior in isolation. V1 coexistence is asserted in
``test_coach_tool_response_migration.py``.

Concern B (latency_tier field): Flutter routes V2 responses to the right
rendering surface — chip (L1 < 500 ms) vs narrative loader (L2/L3, 2-8 s).
The field is server-emitted, never client-input (threat T-mint-calc-10-01).
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.models.coach_tools import (
    CoachToolIncompleteV2,
    CoachToolOkV2,
    CoachToolPolicyBlockedV2,
    CoachToolResponseV2,
    LatencyTier,
)


# ─────────────────────────────────────────────────────────────────────
# Test 1 — CoachToolOkV2 constructs with latency_tier="L1"
# ─────────────────────────────────────────────────────────────────────

def test_ok_v2_constructs_with_latency_tier_l1() -> None:
    ok = CoachToolOkV2(data={"foo": 1}, latency_tier="L1")
    assert ok.status == "ok"
    assert ok.data == {"foo": 1}
    assert ok.latency_tier == "L1"


# ─────────────────────────────────────────────────────────────────────
# Test 2 — latency_tier IS REQUIRED on CoachToolOkV2 (no default)
# ─────────────────────────────────────────────────────────────────────

def test_ok_v2_rejects_missing_latency_tier() -> None:
    with pytest.raises(ValidationError) as exc_info:
        CoachToolOkV2(data={"foo": 1})  # type: ignore[call-arg]
    # Pydantic v2 lists the missing field in the error payload.
    assert "latency_tier" in str(exc_info.value) or "latencyTier" in str(
        exc_info.value
    )


# ─────────────────────────────────────────────────────────────────────
# Test 3 — Literal["L1","L2","L3"] rejects L4 / L0 / arbitrary strings
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("bad_tier", ["L4", "L0", "L1 ", "high", "", "l1"])
def test_ok_v2_rejects_invalid_latency_tier(bad_tier: str) -> None:
    with pytest.raises(ValidationError):
        CoachToolOkV2(data={"foo": 1}, latency_tier=bad_tier)  # type: ignore[arg-type]


# ─────────────────────────────────────────────────────────────────────
# Test 4 — Discriminated-union round-trip via camelCase alias
# ─────────────────────────────────────────────────────────────────────

def test_response_v2_validates_camelcase_alias() -> None:
    payload = {
        "status": "ok",
        "data": {"monthlyIncome": "7500.00"},
        "latencyTier": "L1",
    }
    resp = CoachToolResponseV2.model_validate(payload)
    # Pydantic v2 RootModel exposes the chosen variant via .root.
    assert resp.root.status == "ok"
    assert resp.root.latency_tier == "L1"
    assert resp.root.data == {"monthlyIncome": "7500.00"}


# ─────────────────────────────────────────────────────────────────────
# Test 5 — model_dump(by_alias=True) produces camelCase latencyTier
# ─────────────────────────────────────────────────────────────────────

def test_ok_v2_dumps_camelcase_latency_tier_alias() -> None:
    ok = CoachToolOkV2(data={"x": 1}, latency_tier="L2")
    dumped = ok.model_dump(by_alias=True)
    assert "latencyTier" in dumped
    # snake_case must NOT leak when by_alias=True is requested.
    assert "latency_tier" not in dumped
    assert dumped["latencyTier"] == "L2"


# ─────────────────────────────────────────────────────────────────────
# Test 6 — V1 envelope still importable + constructible (Parallel Change)
# ─────────────────────────────────────────────────────────────────────

def test_v1_envelope_still_works_alongside_v2() -> None:
    from app.models.coach_tools import (
        CoachToolIncomplete,
        CoachToolOk,
        CoachToolPolicyBlocked,
        CoachToolResponse,
    )

    # V1 ok — no latency_tier field, no breaking change.
    v1_ok = CoachToolOk(data={"foo": 1})
    assert v1_ok.status == "ok"
    assert "latency_tier" not in v1_ok.model_dump()

    # V1 incomplete still works.
    v1_inc = CoachToolIncomplete(
        missing_fields=["canton"],
        hint_fr="Indique ton canton pour estimer.",
    )
    assert v1_inc.status == "incomplete"

    # V1 policy_blocked still works.
    v1_pb = CoachToolPolicyBlocked(
        reason_code="lsfin_v1",
        message_fr="Je ne peux pas répondre.",
    )
    assert v1_pb.status == "policy_blocked"

    # V1 discriminated union still parses.
    v1_resp = CoachToolResponse.model_validate(
        {"status": "ok", "data": {"x": 1}}
    )
    assert v1_resp.root.status == "ok"


# ─────────────────────────────────────────────────────────────────────
# Test 7 — Parallel Change coexistence invariant (D-CE-19)
# V1 + V2 import simultaneously; round-trip independently; V1 rejects
# the extra latencyTier field under extra="forbid" if the boundary
# enforces it (BundleBase / _Base both inherit from BaseModel which has
# default extra="ignore" unless explicitly overridden — see _response.py).
# ─────────────────────────────────────────────────────────────────────

def test_parallel_change_coexistence_invariant() -> None:
    # (a) both envelopes import simultaneously without conflict.
    from app.models.coach_tools import (  # noqa: F401  — import-side-effect proof
        CoachToolResponse,
        CoachToolResponseV2,
        CoachToolOk,
        CoachToolOkV2,
    )

    # (b) V1 round-trip independently.
    v1_dump = {"status": "ok", "data": {"x": 1}}
    v1_model = CoachToolResponse.model_validate(v1_dump)
    assert v1_model.root.model_dump() == v1_dump

    # (b) V2 round-trip independently — by_alias for round-trip.
    v2_input = {"status": "ok", "data": {"x": 1}, "latencyTier": "L1"}
    v2_model = CoachToolResponseV2.model_validate(v2_input)
    v2_dump = v2_model.root.model_dump(by_alias=True)
    assert v2_dump == v2_input

    # (c) latency_tier is the V2-only discriminator marker.
    # V2 model_dump (no alias) produces snake_case latency_tier.
    v2_snake_dump = v2_model.root.model_dump()
    assert "latency_tier" in v2_snake_dump
    assert v2_snake_dump["latency_tier"] == "L1"

    # (d) V2 Incomplete defaults latency_tier to "L1" (sub-500ms 422 envelope).
    inc_v2 = CoachToolIncompleteV2(
        missing_fields=["canton"],
        hint_fr="Indique ton canton pour estimer.",
    )
    assert inc_v2.latency_tier == "L1"

    # (e) V2 PolicyBlocked defaults latency_tier to "L1".
    pb_v2 = CoachToolPolicyBlockedV2(
        reason_code="lsfin_v2",
        message_fr="Je ne peux pas répondre.",
    )
    assert pb_v2.latency_tier == "L1"


# ─────────────────────────────────────────────────────────────────────
# Test 8 — LatencyTier type export is the Literal["L1","L2","L3"]
# ─────────────────────────────────────────────────────────────────────

def test_latency_tier_literal_export() -> None:
    # LatencyTier is exported from app.models.coach_tools — proves the
    # public surface includes the type for downstream consumers (Plan 11+
    # dispatcher wire-up will type-hint with it).
    from typing import get_args

    assert set(get_args(LatencyTier)) == {"L1", "L2", "L3"}
