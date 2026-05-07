"""
Tests — auth coach honors user-typed numbers even with empty biography.

Regression for P2 walkthrough 2026-05-07: when a user typed
« Mon salaire est 9500 CHF... » in mode local (empty BIOGRAPHIE
FINANCIERE), the LLM responded « je ne peux pas voir ton salaire — il
semble que l'information n'ait pas été transmise correctement » then
fell back to a generic 6'600 CHF example. The user explicitly stated
their salary in the chat message; the LLM should anchor against it.

Root cause: the `_BIOGRAPHY_AWARENESS` block told the LLM « if no
BIOGRAPHIE FINANCIERE section is present, do not reference biographical
data ». The LLM conflated « biographical data » (the structured store)
with « numbers in the current message ».

Fix: append a clarifying rule that distinguishes the two so user-stated
numbers are usable regardless of biography presence.
"""

from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.coach_context_builder import build_coach_context


def _typical_ctx():
    return build_coach_context(has_debt=False, age=42, canton="VD")


def test_prompt_clarifies_user_message_numbers_are_fair_game():
    prompt = build_system_prompt(ctx=_typical_ctx())
    assert "current chat message" in prompt.lower() or "chat message" in prompt.lower(), (
        "Prompt must instruct the LLM to use numbers typed in the user's "
        "current message (P2 walkthrough fix 2026-05-07)."
    )
    # Must explicitly mention the misleading framings to forbid
    assert "je ne peux pas voir ton salaire" in prompt.lower(), (
        "Prompt must call out the « je ne peux pas voir ton salaire » "
        "anti-pattern explicitly so the LLM does not produce it."
    )


def test_prompt_says_user_numbers_anchor_response():
    prompt = build_system_prompt(ctx=_typical_ctx())
    # Acceptable variants: "anchor", "ancrer", "fair game", "doivent être", etc.
    # We assert that the rule somehow tells the LLM to USE the number.
    assert "anchor" in prompt.lower() or "ancrer" in prompt.lower() or \
        "must be used" in prompt.lower() or "fair game" in prompt.lower() or \
        "MUST be used" in prompt, (
        "Prompt must instruct the LLM that user-typed numbers MUST be used "
        "to anchor the response."
    )


def test_rule_present_with_no_context():
    """The rule belongs to the BIOGRAPHY AWARENESS block, which ships in the
    base prompt regardless of CoachContext presence."""
    prompt = build_system_prompt(ctx=None)
    assert "current chat message" in prompt.lower() or "chat message" in prompt.lower()


def test_rule_explicitly_forbids_information_not_transmitted_framing():
    """The walker observed « il semble que l'information n'ait pas été
    transmise correctement » as the misleading framing; rule must call it
    out so the LLM avoids reproducing this exact phrasing."""
    prompt = build_system_prompt(ctx=_typical_ctx())
    assert "transmise correctement" in prompt.lower() or \
        "il semble" in prompt.lower(), (
        "Prompt must explicitly forbid the « semble que l'information "
        "n'ait pas été transmise correctement » framing observed in the "
        "walker (2026-05-07)."
    )
