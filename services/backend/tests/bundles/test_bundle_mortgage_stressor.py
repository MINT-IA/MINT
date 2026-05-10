"""Golden test for MortgageStressorBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import MortgageStressorBundle


def test_mortgage_stressor_golden():
    bundle = MortgageStressorBundle()
    assert bundle.name == "mortgage-stressor"
    # D-20 mapping
    assert bundle.allowed_tools == [
        "get_budget_status",
        "get_cap_status",
        "get_regulatory_constant",
    ]
    # Citation list non-empty (Phase 95-pending)
    assert bundle.citation_allowlist
    # Fragment must include the {safe_mode_protocol} slot (interpolated to ""
    # by `_build_prompt` when ctx.has_debt is False, otherwise the protocol
    # block at claude_coach_service.py:367-396).
    assert "{safe_mode_protocol}" in bundle.prompt_fragment
    # Fragment mentions FINMA LCB and the 33% mechanical cap
    assert "FINMA" in bundle.prompt_fragment
    assert "33%" in bundle.prompt_fragment
