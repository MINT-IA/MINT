"""
Tests — SafeMode system prompt injection.

Verifies:
- has_debt=True → prompt contains MODE PROTECTION block
- has_debt=True → prompt contains /debt/repayment route
- has_debt=True → all 5 numbered rules present in the SafeMode section
- has_debt=False → prompt does NOT contain MODE PROTECTION
- has_debt=True → MODE PROTECTION appears BEFORE ROUTING RULES (doctrinal order)
- has_debt=True → _build_context_section output contains the ACTIF line
"""

import pytest

from app.services.coach.coach_context_builder import build_coach_context
from app.services.coach.claude_coach_service import build_system_prompt, _build_context_section


def _ctx_with_debt(**kwargs):
    return build_coach_context(has_debt=True, age=35, canton="VD", **kwargs)


def _ctx_without_debt(**kwargs):
    return build_coach_context(has_debt=False, age=35, canton="VD", **kwargs)


def test_safe_mode_block_present_when_has_debt():
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    assert "MODE PROTECTION" in prompt


def test_safe_mode_block_absent_when_no_debt():
    prompt = build_system_prompt(ctx=_ctx_without_debt())
    assert "MODE PROTECTION" not in prompt


def test_safe_mode_contains_debt_repayment_route():
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    assert "/debt/repayment" in prompt


def test_safe_mode_contains_all_5_rules():
    """All 5 numbered rules must appear within the SafeMode section."""
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    # Find the SafeMode block start
    sm_start = prompt.find("MODE PROTECTION")
    assert sm_start != -1, "MODE PROTECTION not found in prompt"
    # Take a generous window after the header (1500 chars covers the ~175 word block)
    sm_section = prompt[sm_start: sm_start + 1500]
    for rule_num in ("1.", "2.", "3.", "4.", "5."):
        assert rule_num in sm_section, f"Rule {rule_num} missing from SafeMode section"


def test_safe_mode_appears_before_routing_rules():
    """RULES.md §2: SafeMode block MUST precede ROUTING RULES in the prompt."""
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    sm_pos = prompt.find("MODE PROTECTION")
    routing_pos = prompt.find("ROUTING RULES")
    assert sm_pos != -1, "MODE PROTECTION not found"
    assert routing_pos != -1, "ROUTING RULES not found"
    assert sm_pos < routing_pos, (
        f"MODE PROTECTION at {sm_pos} must appear before ROUTING RULES at {routing_pos}"
    )


def test_context_section_shows_actif_line_when_has_debt():
    ctx = _ctx_with_debt()
    section = _build_context_section(ctx)
    assert "Mode protection désendettement : ACTIF" in section


def test_context_section_no_actif_line_when_no_debt():
    ctx = _ctx_without_debt()
    section = _build_context_section(ctx)
    assert "Mode protection désendettement : ACTIF" not in section


def test_safe_mode_no_debt_ctx_none():
    """build_system_prompt(ctx=None) must never include the SafeMode block."""
    prompt = build_system_prompt(ctx=None)
    assert "MODE PROTECTION" not in prompt


def test_safe_mode_prompt_contains_33_percent_threshold():
    """The SafeMode block from RULES.md §2 references the 33% threshold."""
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    assert "33%" in prompt


def test_safe_mode_prompt_contains_3_mois():
    """The SafeMode block references the 3-month emergency-fund threshold."""
    prompt = build_system_prompt(ctx=_ctx_with_debt())
    # The block says "3 mois de charges"
    sm_start = prompt.find("MODE PROTECTION")
    sm_section = prompt[sm_start: sm_start + 1500]
    assert "3 mois" in sm_section
