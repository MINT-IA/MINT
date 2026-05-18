"""Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-11) — dead-COUP-04 contract lock.

Per CONTEXT.md D-11 + Phase 01 W4 SUMMARY : the COUP-04 dead path was verified
closed end-to-end. This integration test LOCKS that contract — if a future PR
re-introduces COUP-04 routing through `INTERNAL_TOOL_NAMES` (which would
silently drop the partner-aggregate flow at the backend instead of routing
through Flutter widget_renderer to SecureStorage), this test fires.

The COUP-04 contract :
  * `save_partner_estimate` MUST NOT be in `INTERNAL_TOOL_NAMES` (Flutter-bound).
  * `update_partner_estimate` MUST NOT be in `INTERNAL_TOOL_NAMES` (Flutter-bound).
  * Both tools MUST be registered in `COACH_TOOLS` (the LLM tool catalog).
  * Both tools' descriptions must reference the device-only storage discipline.
  * `partner_declared` + `partner_confidence` MUST be in `_PROFILE_SAFE_FIELDS`
    so the mobile-emitted aggregate flags don't get dropped by
    `_sanitize_profile_context` (the Stage 0 fix from 2026-05-17).
"""
from __future__ import annotations

import pytest


def test_save_partner_estimate_not_internal():
    """COUP-04 contract : `save_partner_estimate` is Flutter-bound, NOT internal."""
    from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES
    assert "save_partner_estimate" not in INTERNAL_TOOL_NAMES, (
        "COUP-04 violation : `save_partner_estimate` listed as INTERNAL — "
        "this routes the tool through backend instead of Flutter widget_renderer, "
        "which BREAKS partner-data device-only storage discipline."
    )


def test_update_partner_estimate_not_internal():
    """COUP-04 contract : `update_partner_estimate` is Flutter-bound, NOT internal."""
    from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES
    assert "update_partner_estimate" not in INTERNAL_TOOL_NAMES, (
        "COUP-04 violation : `update_partner_estimate` listed as INTERNAL — "
        "this routes the tool through backend instead of Flutter widget_renderer."
    )


def test_partner_tools_registered_in_coach_tools():
    """The two partner tools MUST be in the COACH_TOOLS catalog so the LLM can call them."""
    from app.services.coach.coach_tools import COACH_TOOLS
    names = {t["name"] for t in COACH_TOOLS}
    assert "save_partner_estimate" in names, (
        "COUP-04 setup : `save_partner_estimate` missing from COACH_TOOLS catalog."
    )
    assert "update_partner_estimate" in names, (
        "COUP-04 setup : `update_partner_estimate` missing from COACH_TOOLS catalog."
    )


def test_partner_aggregate_keys_in_profile_safe_fields():
    """COUP-04 partner-aggregate ground-truth pathway is open in _PROFILE_SAFE_FIELDS.

    The Stage 0 fix (2026-05-17) re-added `partner_declared` + `partner_confidence`
    to the whitelist. If they're dropped, the entire COUP-04 partner-aggregate
    pathway into the coach context goes dead in production. D-11 locks the contract.
    """
    from app.api.v1.endpoints.coach_chat import _PROFILE_SAFE_FIELDS
    assert "partner_declared" in _PROFILE_SAFE_FIELDS, (
        "COUP-04 dead path : `partner_declared` dropped from _PROFILE_SAFE_FIELDS. "
        "Mobile-emitted aggregate flag silently dropped by _sanitize_profile_context."
    )
    assert "partner_confidence" in _PROFILE_SAFE_FIELDS, (
        "COUP-04 dead path : `partner_confidence` dropped from _PROFILE_SAFE_FIELDS."
    )


def test_partner_tool_descriptions_mention_flutter_bound_or_device_only():
    """The two partner tools' descriptions must communicate the device-only
    storage discipline so the LLM doesn't try to confirm via backend state."""
    from app.services.coach.coach_tools import COACH_TOOLS
    for tool_name in ("save_partner_estimate", "update_partner_estimate"):
        tool = next((t for t in COACH_TOOLS if t["name"] == tool_name), None)
        assert tool is not None, f"Tool {tool_name} missing from COACH_TOOLS"
        desc = tool.get("description", "").lower()
        # Must mention either Flutter-bound, device, SecureStorage, or COUP-04.
        markers = ("flutter", "device", "secure", "securestorage", "coup-04", "coup-01")
        assert any(m in desc for m in markers), (
            f"COUP-04 discoverability : `{tool_name}` description lacks "
            f"any of {markers!r}. LLM may try to confirm via backend state."
        )
