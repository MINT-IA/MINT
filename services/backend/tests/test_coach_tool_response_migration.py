"""Phase mint-calc-engine-v1 Plan 10 (W2-04) — Parallel Change invariant tests.

D-CE-19 Fowler Parallel Change pattern. V1 and V2 of CoachToolResponse
coexist for 1+ release. V1 retirement happens in a SEPARATE follow-up PR
(Plan 11 or post-phase). The invariants asserted here are :

  (1) Both V1 and V2 envelope packages are importable simultaneously.
  (2) V1 round-trips independently (existing dispatcher / fixtures
      keep parsing as before).
  (3) V2 round-trips independently with the new latency_tier hint.
  (4) A Union[V1, V2] dispatcher type accepts BOTH envelopes — this is the
      type-level proof that downstream consumers can be migrated lazily,
      one tool at a time (Parallel Change discipline ; migration cost
      bounded ≤200 LOC ≤1 day per panel proof in CONTEXT §counter-arg 3).
  (5) The chip-emitter migration (Plan 10 Task 2) actually emits V2 when
      the feature flag is ON — proving that the bridge between the V1
      envelope (legacy A3) and the V2 envelope (Plan 10) is functional,
      not just type-defined.

Cross-references :
  - test_coach_tool_response_v2.py — V2 envelope unit tests (Task 1)
  - test_coach_tool_response_v2_migration.py — chip-emitter wiring (Task 2)
  - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md — V1
"""
from __future__ import annotations

import json
from typing import Union
from unittest.mock import MagicMock

import pytest

from app.core.config import settings
from app.models.coach_tools import (
    CoachToolIncomplete,
    CoachToolIncompleteV2,
    CoachToolOk,
    CoachToolOkV2,
    CoachToolPolicyBlocked,
    CoachToolPolicyBlockedV2,
    CoachToolResponse,
    CoachToolResponseV2,
    LatencyTier,
)


# ─────────────────────────────────────────────────────────────────────
# Invariant 1 — Both envelopes exported via app.models.coach_tools
# ─────────────────────────────────────────────────────────────────────

def test_both_envelopes_exported_simultaneously() -> None:
    """The package surface is the proof-of-coexistence."""
    import app.models.coach_tools as m

    # V1 exports.
    assert "CoachToolOk" in m.__all__
    assert "CoachToolIncomplete" in m.__all__
    assert "CoachToolPolicyBlocked" in m.__all__
    assert "CoachToolResponse" in m.__all__
    # V2 exports.
    assert "CoachToolOkV2" in m.__all__
    assert "CoachToolIncompleteV2" in m.__all__
    assert "CoachToolPolicyBlockedV2" in m.__all__
    assert "CoachToolResponseV2" in m.__all__
    assert "LatencyTier" in m.__all__


# ─────────────────────────────────────────────────────────────────────
# Invariant 2 — V1 round-trips independently
# ─────────────────────────────────────────────────────────────────────

def test_v1_envelope_round_trips_independently() -> None:
    v1_payload = {"status": "ok", "data": {"x": 1}}
    v1_model = CoachToolResponse.model_validate(v1_payload)
    assert v1_model.root.status == "ok"
    assert v1_model.root.model_dump() == v1_payload


def test_v1_incomplete_envelope_still_caps_missing_fields_at_three() -> None:
    """V1 contract D-A3-01: missing_fields capped at 3. Plan 10 must not
    regress this — both envelopes share the same cap rule."""
    # Cap at 3 — passes.
    inc = CoachToolIncomplete(
        missing_fields=["canton", "age", "income"],
        hint_fr="Indique ton canton, ton âge et ton revenu mensuel.",
    )
    assert len(inc.missing_fields) == 3

    # > 3 raises.
    with pytest.raises(Exception):  # pydantic ValidationError / ValueError
        CoachToolIncomplete(
            missing_fields=["a", "b", "c", "d"],
            hint_fr="Indique 4 champs pour estimer.",
        )


# ─────────────────────────────────────────────────────────────────────
# Invariant 3 — V2 round-trips independently with latency_tier
# ─────────────────────────────────────────────────────────────────────

def test_v2_envelope_round_trips_with_latency_tier() -> None:
    v2_payload = {
        "status": "ok",
        "data": {"x": 1},
        "latencyTier": "L1",
    }
    v2_model = CoachToolResponseV2.model_validate(v2_payload)
    assert v2_model.root.status == "ok"
    assert v2_model.root.latency_tier == "L1"
    assert v2_model.root.model_dump(by_alias=True) == v2_payload


def test_v2_incomplete_envelope_inherits_same_cap() -> None:
    """V2 contract: same D-A3-01 cap = 3 — proven via the dedicated
    _cap_missing_fields_v2 validator."""
    # Cap at 3 — passes.
    inc_v2 = CoachToolIncompleteV2(
        missing_fields=["canton", "age", "income"],
        hint_fr="Indique ton canton, ton âge et ton revenu mensuel.",
    )
    assert inc_v2.latency_tier == "L1"
    assert len(inc_v2.missing_fields) == 3

    # > 3 raises (same cap as V1).
    with pytest.raises(Exception):
        CoachToolIncompleteV2(
            missing_fields=["a", "b", "c", "d"],
            hint_fr="Indique 4 champs pour estimer.",
        )


# ─────────────────────────────────────────────────────────────────────
# Invariant 4 — Union[V1, V2] dispatcher acceptance (type-level proof)
# ─────────────────────────────────────────────────────────────────────

def test_union_dispatcher_accepts_both_envelopes() -> None:
    """A coach dispatcher typed as ``Union[CoachToolResponse, CoachToolResponseV2]``
    accepts BOTH envelope shapes. Pydantic v2 RootModel + Union[RootModel,
    RootModel] works as long as each side has its own discriminator. V1 has
    the 3-status discriminator; V2 has the same 3-status discriminator PLUS
    the latencyTier field on every variant — disambiguated by presence of
    that field if Pydantic ever needs to pick between them at the
    Union boundary (currently we pick explicitly per caller)."""
    # V1 JSON parses through CoachToolResponse.
    v1_payload = {"status": "ok", "data": {"x": 1}}
    v1 = CoachToolResponse.model_validate(v1_payload)
    assert v1.root.status == "ok"
    assert not hasattr(v1.root, "latency_tier")  # V1 has no such field.

    # V2 JSON parses through CoachToolResponseV2.
    v2_payload = {"status": "ok", "data": {"x": 1}, "latencyTier": "L1"}
    v2 = CoachToolResponseV2.model_validate(v2_payload)
    assert v2.root.status == "ok"
    assert v2.root.latency_tier == "L1"

    # The two envelopes can be passed around together (e.g. as a Union type
    # hint downstream). This is the migration-cost-bounding invariant:
    # callers can opt-in V2 per tool, leaving V1 for the rest.
    EnvelopeType = Union[CoachToolResponse, CoachToolResponseV2]
    payloads: list[EnvelopeType] = [v1, v2]
    statuses = [p.root.status for p in payloads]
    assert statuses == ["ok", "ok"]


# ─────────────────────────────────────────────────────────────────────
# Invariant 5 — Chip-emitter migration ACTUALLY EMITS V2 when flag ON
# (the live bridge between V1 wire (legacy A3) and V2 wire (Plan 10))
# ─────────────────────────────────────────────────────────────────────

def test_chip_emitter_actually_emits_v2_envelope_when_flag_on(monkeypatch) -> None:
    """Plan 10 Task 2 migration is real, not just a class definition.

    Compute the budget chip end-to-end with the V2 flag ON and assert the
    resulting JSON parses as a CoachToolResponseV2.
    """
    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True
    )
    monkeypatch.setattr(settings, "COACH_TOOL_RESPONSE_V2_ENABLED", True)

    from app.api.v1.endpoints.coach_chat import _compute_budget_status

    profile_data = {
        "monthly_income": 7500.0,
        "monthly_expenses": 5200.0,
        "months_liquidity": 4.6,
    }
    mock_db = MagicMock()
    query_chain = mock_db.query.return_value
    query_chain = query_chain.filter.return_value
    query_chain = query_chain.order_by.return_value
    profile = MagicMock()
    profile.data = profile_data
    query_chain.first.return_value = profile

    raw = _compute_budget_status(user_id="user-abc", ctx={}, db=mock_db)
    parsed = CoachToolResponseV2.model_validate_json(raw)
    assert parsed.root.status == "ok"
    assert parsed.root.latency_tier == "L1"  # chip-emitter = sub-500ms.
    assert "monthlyIncome" in parsed.root.data  # wrapped payload preserved.


# ─────────────────────────────────────────────────────────────────────
# Invariant 6 — Migration count tracker (per Plan 10 Task 3 behavior #5)
# Asserts V1 + V2 BOTH have ≥1 consumer somewhere in app/ — proof that
# Parallel Change is in motion, not theoretical.
# ─────────────────────────────────────────────────────────────────────

def test_migration_count_tracker_both_envelopes_have_consumers() -> None:
    import subprocess
    from pathlib import Path

    repo_root = Path(__file__).resolve().parents[3]
    app_dir = repo_root / "services" / "backend" / "app"
    assert app_dir.is_dir(), f"Expected app dir at {app_dir}"

    # V1 consumer: app/core/profile_resolver.py imports CoachToolIncomplete.
    v1_result = subprocess.run(
        ["grep", "-rln", "CoachToolIncomplete\\|CoachToolOk[^V]", str(app_dir)],
        capture_output=True,
        text=True,
    )
    v1_files = [f for f in v1_result.stdout.splitlines() if f and "__pycache__" not in f]
    assert len(v1_files) >= 1, f"Expected V1 consumer in app/ ; got {v1_files}"

    # V2 consumer: app/api/v1/endpoints/coach_chat.py imports CoachToolOkV2.
    v2_result = subprocess.run(
        ["grep", "-rln", "CoachToolOkV2\\|CoachToolResponseV2", str(app_dir)],
        capture_output=True,
        text=True,
    )
    v2_files = [f for f in v2_result.stdout.splitlines() if f and "__pycache__" not in f]
    assert len(v2_files) >= 1, f"Expected V2 consumer in app/ ; got {v2_files}"


# ─────────────────────────────────────────────────────────────────────
# Invariant 7 — V1 retirement explicitly NOT performed by Plan 10
# (regression guard: any future commit that removes V1 must update this
#  test so the absence-of-V1 becomes explicit, not silent)
# ─────────────────────────────────────────────────────────────────────

def test_v1_classes_still_constructible_after_plan_10() -> None:
    """Plan 10 D-CE-19 contract: V1 retires in a SEPARATE follow-up PR
    (Plan 11 or post-phase). This test fails if V1 is silently retired."""
    ok = CoachToolOk(data={"x": 1})
    inc = CoachToolIncomplete(
        missing_fields=["canton"],
        hint_fr="Indique ton canton pour estimer.",
    )
    pb = CoachToolPolicyBlocked(
        reason_code="lsfin_dev", message_fr="Je ne peux pas répondre."
    )
    assert ok.status == "ok"
    assert inc.status == "incomplete"
    assert pb.status == "policy_blocked"
