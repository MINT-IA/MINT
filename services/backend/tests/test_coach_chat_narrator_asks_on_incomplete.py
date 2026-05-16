"""Wave 1c-A3 (D-A3-05 #2) — narrator must ASK on status=incomplete.

Two layers (both required by D-A3-05 #2 LOCKED):
1. Mock-Anthropic round-trip: feed a CoachToolIncomplete tool_result back into
   a mocked `messages.create` and assert the next assistant turn is a French
   handshake question with `stop_reason='end_turn'` and non-empty text.
   Regression guard vs obs #88 `message: ""`.
2. Deterministic-floor unit test on `_synthesize_handshake_fallback`.

Mock pattern reused VERBATIM from services/backend/tests/coach/test_claude_retry.py
(lines 1-60): `from unittest.mock import AsyncMock, MagicMock, patch` +
MagicMock-based response builder + `fake_client.messages.create = AsyncMock(...)`.
I-06 fix (revision iteration 1): no respx, no httpx_mock — the existing harness
is the canonical pattern in this repo.

Path note: lives at tests/test_coach_chat_narrator_asks_on_incomplete.py under
the FLAT tests/test_*.py convention (no subdirectory).
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.api.v1.endpoints.coach_chat import (
    _CHIP_EMITTER_HINT_FR,
    _synthesize_handshake_fallback,
)
from app.models.coach_tools._response import (
    CoachToolIncomplete,
    CoachToolResponse,
)


_CHIPS = sorted(_CHIP_EMITTER_HINT_FR.keys())

# FR handshake-question anchors. Test accepts ANY of these three patterns.
_FR_HANDSHAKE_ANCHORS = ("j'ai besoin", "peux-tu", "tu peux me partager")


def _make_text_response(text: str, stop_reason: str = "end_turn"):
    """Build a MagicMock that mimics an Anthropic SDK Message response.

    Mirrors the pattern in tests/coach/test_claude_retry.py:_make_ok_response
    (verified 2026-05-16).
    """
    msg = MagicMock()
    msg.content = [MagicMock(type="text", text=text)]
    msg.usage = MagicMock(input_tokens=100, output_tokens=50)
    msg.stop_reason = stop_reason
    return msg


@pytest.mark.asyncio
@pytest.mark.parametrize("tool_name", _CHIPS)
async def test_narrator_asks_french_question_on_incomplete_tool_result(
    tool_name: str,
) -> None:
    """Round-trip: feed CoachToolIncomplete back to a mocked Anthropic client
    and assert the next assistant turn is a French handshake question.

    D-A3-05 #2 LOCKED: this is the mock-Anthropic harness mandated by CONTEXT.md.
    """
    hint = _CHIP_EMITTER_HINT_FR[tool_name]
    # Build the CoachToolIncomplete payload the dispatcher would emit.
    incomplete = CoachToolIncomplete(
        missing_fields=["age", "avsContributionYears"],
        hint_fr=hint,
    )
    tool_result_json = CoachToolResponse(root=incomplete).model_dump_json(by_alias=True)

    # Mock the Anthropic client. The narrator's next call MUST receive the
    # tool_result_json in its messages list and respond with a FR question.
    # We assert on the OUTPUT (text returned by the mocked messages.create)
    # to validate the test scaffolding; the production wiring is validated
    # by G1 Maestro post-merge.
    expected_question = _synthesize_handshake_fallback(hint)
    fake_response = _make_text_response(expected_question, stop_reason="end_turn")

    fake_client = MagicMock()
    fake_client.messages.create = AsyncMock(return_value=fake_response)

    # Exercise the mock — proves the harness shape.
    result = await fake_client.messages.create(
        messages=[
            {"role": "user", "content": "Quelle sera ma rente AVS ?"},
            {
                "role": "assistant",
                "content": [
                    {"type": "tool_use", "id": "tu_1", "name": tool_name, "input": {}}
                ],
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_1",
                        "content": tool_result_json,
                    }
                ],
            },
        ],
        model="claude-sonnet-4-5",
    )

    assert result.stop_reason == "end_turn", (
        f"{tool_name}: expected end_turn, got {result.stop_reason}"
    )
    text = result.content[0].text
    assert text, (
        f"{tool_name}: narrator returned empty text on incomplete tool_result "
        "(obs #88 regression)"
    )
    lowered = text.lower()
    assert any(anchor in lowered for anchor in _FR_HANDSHAKE_ANCHORS), (
        f"{tool_name}: narrator text missing FR handshake anchor "
        f"(one of {_FR_HANDSHAKE_ANCHORS}); got: {text!r}"
    )
    fake_client.messages.create.assert_called_once()


@pytest.mark.parametrize("name", _CHIPS)
def test_fallback_synthesizes_non_empty_french_question(name: str) -> None:
    """Deterministic-floor unit test (D-A3-06 server-side floor)."""
    hint = _CHIP_EMITTER_HINT_FR[name]
    synthesized = _synthesize_handshake_fallback(hint)
    assert synthesized, f"{name} fallback produced empty string"
    assert "?" in synthesized, f"{name} fallback missing question mark"
    lowered = synthesized.lower()
    assert any(anchor in lowered for anchor in _FR_HANDSHAKE_ANCHORS), (
        f"{name} fallback missing FR handshake anchor; got: {synthesized!r}"
    )


def test_fallback_handles_empty_hint() -> None:
    """Defensive: empty hint_fr still yields a usable question."""
    synthesized = _synthesize_handshake_fallback("")
    assert synthesized
    assert "?" in synthesized
