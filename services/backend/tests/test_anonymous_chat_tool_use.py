"""Anonymous chat — tool-use loop tests (sub-phase 01.4 F-01.1-06 fix).

Verifies that the anonymous coach path wires `get_regulatory_constant` and
forces tool invocation on finance-keyword detection. Regression guard
against the « 25 fois » class of bug where the LLM hallucinated stale
plafond values (7'056 CHF 2024) instead of citing the registry (7'258 CHF
2025-2026).

See `.planning/phases/01.4-coach-runtime-stale-data/01.4-AUDIT.md` for the
root-cause analysis.
"""

import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from types import SimpleNamespace

os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-tool-use")


def _fake_anthropic_text_response(text: str, input_tokens: int = 10, output_tokens: int = 20):
    """Build a fake AsyncAnthropic.messages.create() response (text-only)."""
    return SimpleNamespace(
        content=[SimpleNamespace(type="text", text=text)],
        usage=SimpleNamespace(input_tokens=input_tokens, output_tokens=output_tokens),
    )


def _fake_anthropic_tool_use_response(
    tool_name: str, tool_input: dict, tool_use_id: str = "tu_001",
    text_before: str = "", input_tokens: int = 12, output_tokens: int = 24,
):
    """Build a fake response carrying a tool_use block."""
    content = []
    if text_before:
        content.append(SimpleNamespace(type="text", text=text_before))
    content.append(
        SimpleNamespace(
            type="tool_use", id=tool_use_id, name=tool_name, input=tool_input
        )
    )
    return SimpleNamespace(
        content=content,
        usage=SimpleNamespace(input_tokens=input_tokens, output_tokens=output_tokens),
    )


@pytest.mark.asyncio
async def test_finance_keyword_forces_tool_choice_to_get_regulatory_constant():
    """Finance keyword in question -> tool_choice = {type: tool, name: get_regulatory_constant}."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages = MagicMock()
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("Tu peux verser jusqu'à 7'258 CHF.")
        )

        await orchestrator.query(
            question="Quel est le plafond 3a cette année ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
            language="fr",
        )

        # Single call, no tool_use blocks in fake response.
        assert instance.messages.create.call_count == 1
        kwargs = instance.messages.create.call_args.kwargs
        # Couche A — tools list contains get_regulatory_constant.
        tool_names = [t.get("name") for t in kwargs.get("tools", [])]
        assert "get_regulatory_constant" in tool_names, (
            f"anonymous coach must wire get_regulatory_constant tool ; got {tool_names}"
        )
        # Couche C — forced tool_choice on finance keyword.
        assert kwargs.get("tool_choice") == {
            "type": "tool", "name": "get_regulatory_constant"
        }, (
            f"finance keyword must force tool_choice ; got {kwargs.get('tool_choice')}"
        )


@pytest.mark.asyncio
async def test_non_finance_keyword_uses_auto_tool_choice():
    """Non-finance question -> tool_choice = {type: auto} (LLM decides)."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("Bonjour ! Comment puis-je aider ?")
        )

        await orchestrator.query(
            question="Bonjour, je veux juste comprendre comment ça marche.",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
        )

        kwargs = instance.messages.create.call_args.kwargs
        assert kwargs.get("tool_choice") == {"type": "auto"}, (
            f"non-finance question should use auto tool_choice ; got {kwargs.get('tool_choice')}"
        )


@pytest.mark.asyncio
async def test_tool_use_triggers_second_call_with_tool_result():
    """LLM emits tool_use -> 2nd LLM call carries tool_result block."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()

    # 1st response: tool_use block. 2nd response: grounded text.
    responses = [
        _fake_anthropic_tool_use_response(
            tool_name="get_regulatory_constant",
            tool_input={"key": "pillar3a.max_with_lpp"},
            tool_use_id="tu_42",
        ),
        _fake_anthropic_text_response(
            "Cette année tu peux verser jusqu'à 7'258 CHF (OPP3 art. 7).",
            input_tokens=15, output_tokens=30,
        ),
    ]

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(side_effect=responses)

        # Patch the tool executor so the test doesn't need a real registry.
        # 2026-05-21 panel FLAG #1 — handler now lives in the shared module
        # (app.services.regulatory.tool_handler) for T-13-06 isolation.
        with patch(
            "app.services.regulatory.tool_handler.handle_regulatory_constant",
            return_value="pillar3a.max_with_lpp = 7258 CHF\nSource : OPP3 art. 7",
        ) as mock_handler:
            result = await orchestrator.query(
                question="Quel est le plafond 3a pour 2026 ?",
                system_prompt="System",
                api_key="sk-test",
                provider="claude",
                model="claude-sonnet-4-5-20250929",
            )

        # Two LLM calls total — first surfaces tool_use, second produces text.
        assert instance.messages.create.call_count == 2

        # Tool executor was invoked with the LLM-provided input.
        mock_handler.assert_called_once_with({"key": "pillar3a.max_with_lpp"})

        # Second call's messages array contains the assistant tool_use turn
        # followed by the user tool_result turn.
        second_kwargs = instance.messages.create.call_args_list[1].kwargs
        msgs = second_kwargs["messages"]
        assert len(msgs) == 3, f"expected user/assistant/user, got {len(msgs)} messages"
        assert msgs[0]["role"] == "user"
        assert msgs[1]["role"] == "assistant"
        # assistant content carries the tool_use block.
        assistant_blocks = msgs[1]["content"]
        assert any(b.get("type") == "tool_use" for b in assistant_blocks), (
            f"assistant turn must include tool_use block ; got {assistant_blocks}"
        )
        # user follow-up carries the tool_result block.
        assert msgs[2]["role"] == "user"
        user_blocks = msgs[2]["content"]
        assert any(b.get("type") == "tool_result" for b in user_blocks), (
            f"follow-up user turn must carry tool_result ; got {user_blocks}"
        )

        # Final answer reflects the second LLM response, not the first
        # (which was empty text + tool_use).
        assert "7'258" in result["answer"] or "7258" in result["answer"]
        # Surfaced tool-use trace for breadcrumb / verification.
        assert result.get("tool_calls") == [{"name": "get_regulatory_constant"}]


@pytest.mark.asyncio
async def test_tools_list_is_filtered_to_regulatory_only():
    """Anonymous path only wires get_regulatory_constant — not budget / projection / etc."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("noop")
        )

        await orchestrator.query(
            question="Plafond 3a ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
        )

        kwargs = instance.messages.create.call_args.kwargs
        tool_names = [t.get("name") for t in kwargs.get("tools", [])]
        # Single tool exposed to anonymous LLM.
        assert tool_names == ["get_regulatory_constant"], (
            f"anonymous path must expose ONLY get_regulatory_constant ; got {tool_names}"
        )
