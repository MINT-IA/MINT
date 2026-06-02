"""Wave 1a plan-00 scaffolding tests — 15 tests pinning the shared insertion slots.

These tests stay GREEN through Wave 1c. If a downstream plan accidentally rips
out the scaffolding, this file fails CI and the regression is caught at PR time.

Coverage:
  Tests 1-6  : all 6 settings flags exist with correct defaults (D-05, D-09).
  Tests 7-8  : emit_coach_tool_breadcrumb + hash_profile_id helpers importable.
  Tests 9-11 : empty package markers (coach_tools, memory, couple_optimizer).
  Test 12    : emit_coach_tool_breadcrumb is fail-open when sentry_sdk is None.
  Test 13    : WAVE_1A_DISPATCHER_SLOT_MARKER constant is importable AND its
               value appears in coach_chat.py file content (T-WAVE1A-00-01).
  Test 14    : SIGNATURE-PIN — emit_coach_tool_breadcrumb signature has the
               exact 5 D-15 parameters in order (panel fix architect-review #6).
  Test 15    : DISPATCHER-MARKERS — coach_chat.py contains all 6 paired
               # >>> dispatch: get_<tool> / # <<< dispatch: get_<tool> markers
               (panel fix architect-review #1).
"""
from __future__ import annotations

import inspect
from pathlib import Path



# ---------------------------------------------------------------------------
# Tests 1-6 — settings flag defaults (D-05, D-09)
# ---------------------------------------------------------------------------


def test_flag_budget_default_off():
    from app.core.config import settings
    assert settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED is False


def test_flag_retirement_projection_default_off():
    from app.core.config import settings
    assert settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED is False


def test_flag_cross_pillar_default_off():
    from app.core.config import settings
    assert settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False


def test_flag_couple_optimization_default_off():
    from app.core.config import settings
    assert settings.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED is False


def test_flag_retrieve_memories_default_off():
    from app.core.config import settings
    assert settings.COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED is False


def test_flag_cap_chf_garde_default_on():
    """D-09: cap-garde defaults ON (the OTHER 5 flags default OFF)."""
    from app.core.config import settings
    assert settings.COACH_CAP_CHF_GARDE_ENABLED is True


# ---------------------------------------------------------------------------
# Tests 7-8 — helper importability
# ---------------------------------------------------------------------------


def test_emit_coach_tool_breadcrumb_importable():
    from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
    assert callable(emit_coach_tool_breadcrumb)


def test_hash_profile_id_importable_and_deterministic():
    from app.utils.hashing import hash_profile_id
    h1 = hash_profile_id("user_abc")
    h2 = hash_profile_id("user_abc")
    assert isinstance(h1, str)
    assert len(h1) == 16, f"expected 16-char hex prefix, got {len(h1)}"
    assert h1 == h2, "hash_profile_id must be deterministic"
    # Hex-only sanity check.
    assert all(c in "0123456789abcdef" for c in h1)


# ---------------------------------------------------------------------------
# Tests 9-11 — empty package marker imports
# ---------------------------------------------------------------------------


def test_models_coach_tools_package_importable():
    import app.models.coach_tools as m
    # Wave 1a shipped __all__ = [] as an empty package marker. mint-calc-engine-v1
    # Plan 01 Task 0 cherry-picked the A3 CoachToolResponse envelope per D-CE-04
    # + D-CE-19 Parallel Change, so __all__ now exports the 4 envelope classes.
    # mint-calc-engine-v1 Plan 10 W2-04 added the V2 envelope alongside V1 per
    # D-CE-19 Parallel Change (Fowler) — Concern B latency_tier field for
    # Flutter routing. V1 stays intact; V2 is the additive sibling.
    assert hasattr(m, "__all__")
    assert set(m.__all__) == {
        # V1 (Wave 1c-A3 canonical)
        "CoachToolIncomplete",
        "CoachToolOk",
        "CoachToolPolicyBlocked",
        "CoachToolResponse",
        # V2 (Plan 10 W2-04, Parallel Change additive)
        "CoachToolIncompleteV2",
        "CoachToolOkV2",
        "CoachToolPolicyBlockedV2",
        "CoachToolResponseV2",
        "LatencyTier",
    }


def test_services_memory_package_importable():
    import app.services.memory  # noqa: F401


def test_services_couple_optimizer_package_importable():
    import app.services.couple_optimizer  # noqa: F401


# ---------------------------------------------------------------------------
# Test 12 — fail-open guarantee
# ---------------------------------------------------------------------------


def test_emit_coach_tool_breadcrumb_fail_open_when_sentry_none(monkeypatch):
    """T-WAVE1A-00-05: emit_coach_tool_breadcrumb never raises, even if SDK absent."""
    import app.observability.coach_breadcrumbs as mod

    monkeypatch.setattr(mod, "sentry_sdk", None, raising=False)
    # Should not raise — fail-open contract.
    mod.emit_coach_tool_breadcrumb(
        tool_name="budget_status",
        inputs_hash="a" * 64,
        profile_id_hashed="1234567890abcdef",
        elapsed_ms=42,
        flag_state="on",
    )


# ---------------------------------------------------------------------------
# Test 13 — SCAFFOLD-WIRING via module-level constant (T-WAVE1A-00-01)
# ---------------------------------------------------------------------------


def test_dispatcher_slot_marker_constant_present_in_file():
    """T-WAVE1A-00-01: the slot marker constant is importable AND its value
    appears in coach_chat.py file content. Rename-resilient via constant.
    """
    from app.api.v1.endpoints.coach_chat import WAVE_1A_DISPATCHER_SLOT_MARKER

    assert isinstance(WAVE_1A_DISPATCHER_SLOT_MARKER, str)
    assert WAVE_1A_DISPATCHER_SLOT_MARKER == "Wave 1a server-side compute dispatchers (D-08)"

    coach_chat_path = (
        Path(__file__).resolve().parent.parent
        / "app"
        / "api"
        / "v1"
        / "endpoints"
        / "coach_chat.py"
    )
    file_text = coach_chat_path.read_text(encoding="utf-8")
    assert WAVE_1A_DISPATCHER_SLOT_MARKER in file_text, (
        f"slot marker {WAVE_1A_DISPATCHER_SLOT_MARKER!r} not found in coach_chat.py"
    )


# ---------------------------------------------------------------------------
# Test 14 — SIGNATURE-PIN D-15 (panel fix architect-review #6)
# ---------------------------------------------------------------------------


def test_emit_coach_tool_breadcrumb_signature_matches_d15():
    """D-15 contract: 5 mandated parameters in this order + optional
    `extra_tags` for data-quality observability.

    Pinning the signature via inspect prevents silent payload drift across
    plans 01-05 (panel fix architect-review concern #6).

    Plan-03 (cross_pillar) added the optional `extra_tags: Optional[dict] = None`
    sixth parameter backward-compatibly (default None preserves plan-01/02
    call sites). The first 5 names MUST stay locked in that order; the 6th
    is allowed as an opt-in observability hook for data-quality tags
    (lpp_buyback_source, tax_saving_source, etc.).
    """
    from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb

    sig = inspect.signature(emit_coach_tool_breadcrumb)
    param_names = list(sig.parameters.keys())
    assert param_names[:5] == [
        "tool_name",
        "inputs_hash",
        "profile_id_hashed",
        "elapsed_ms",
        "flag_state",
    ], f"D-15 signature drift on first 5 params: got {param_names!r}"
    # Plan-03 extension: optional extra_tags (None-defaulted).
    if len(param_names) > 5:
        assert param_names[5] == "extra_tags", (
            f"unexpected 6th parameter: got {param_names[5]!r} "
            f"(expected 'extra_tags')"
        )
        assert sig.parameters["extra_tags"].default is None, (
            "extra_tags must default to None (backward-compat with plan-01/02)"
        )


# ---------------------------------------------------------------------------
# Test 15 — DISPATCHER-MARKERS (panel fix architect-review #1)
# ---------------------------------------------------------------------------


def test_dispatcher_branches_have_six_paired_markers():
    """T-WAVE1A-00-06: the 6 dispatcher branches plans 01-06 mutate each have
    paired # >>> dispatch: get_<tool> / # <<< dispatch: get_<tool> markers so
    parallel execution races on coach_chat.py are impossible.

    Six tools: retrieve_memories, get_budget_status, get_retirement_projection,
    get_cross_pillar_analysis, get_cap_status, get_couple_optimization.
    `get_regulatory_constant` is INTENTIONALLY UNMARKED per CONTEXT D-02.
    """
    coach_chat_path = (
        Path(__file__).resolve().parent.parent
        / "app"
        / "api"
        / "v1"
        / "endpoints"
        / "coach_chat.py"
    )
    file_text = coach_chat_path.read_text(encoding="utf-8")

    expected_tools = [
        "retrieve_memories",
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    ]
    missing = []
    for tool in expected_tools:
        open_marker = f"# >>> dispatch: {tool}"
        close_marker = f"# <<< dispatch: {tool}"
        if open_marker not in file_text:
            missing.append(open_marker)
        if close_marker not in file_text:
            missing.append(close_marker)

    assert not missing, f"missing dispatcher markers: {missing!r}"

    # Total marker line count: exactly 6 open + 6 close = 12 lines.
    open_count = file_text.count("# >>> dispatch: ")
    close_count = file_text.count("# <<< dispatch: ")
    assert open_count == 6, f"expected 6 opening markers, got {open_count}"
    assert close_count == 6, f"expected 6 closing markers, got {close_count}"
