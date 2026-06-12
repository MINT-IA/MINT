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
async def test_tools_list_is_filtered_to_grounded_tools_only():
    """Anonymous path wires the two GROUNDED read-only tools only —
    get_regulatory_constant (numbers) + explain_concept (definitions, Codex
    fix_6) — never budget / projection / write tools."""
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
        tool_names = sorted(t.get("name") for t in kwargs.get("tools", []))
        assert tool_names == ["explain_concept", "get_regulatory_constant"], (
            f"anonymous path must expose ONLY the two grounded read tools ; "
            f"got {tool_names}"
        )


# ═══════════════════════════════════════════════════════════════════════
# Codex grounding-stack review (fix_6) — explain_concept on anonymous surface
# The W1 rachat-inversion incident happened on THIS surface. Tests mirror the
# authenticated ones: force on a definition ask, auto on chitchat, loop
# terminates with grounded text after the tool_result.
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_definition_ask_forces_explain_concept():
    """Definition interrogative + registry concept -> tool_choice explain_concept."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("Un rachat LPP, c'est…")
        )

        await orchestrator.query(
            question="C'est quoi un rachat LPP exactement ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
            language="fr",
        )

        kwargs = instance.messages.create.call_args.kwargs
        assert kwargs.get("tool_choice") == {
            "type": "tool", "name": "explain_concept"
        }, (
            f"a definition ask must force explain_concept ; "
            f"got {kwargs.get('tool_choice')}"
        )


@pytest.mark.asyncio
async def test_definition_ask_takes_priority_over_finance_keyword():
    """A definition ask that also contains a finance keyword forces
    explain_concept (more specific than the number lookup)."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("Le taux de conversion…")
        )

        # "taux de conversion" matches both the finance KW (taux) and the
        # definition concept — the definition interrogative wins.
        await orchestrator.query(
            question="Explique-moi le taux de conversion LPP.",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
        )

        kwargs = instance.messages.create.call_args.kwargs
        assert kwargs.get("tool_choice") == {
            "type": "tool", "name": "explain_concept"
        }


@pytest.mark.asyncio
async def test_chitchat_uses_auto_not_explain_concept():
    """A non-definition, non-finance message stays auto (no forced tool)."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("Salut ! Avec plaisir.")
        )

        await orchestrator.query(
            question="Salut, je découvre l'app, c'est sympa !",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
        )

        kwargs = instance.messages.create.call_args.kwargs
        assert kwargs.get("tool_choice") == {"type": "auto"}


@pytest.mark.asyncio
async def test_explain_concept_loop_terminates_with_grounded_text():
    """LLM emits explain_concept -> backend resolves registry page -> 2nd call
    produces grounded text. The loop terminates with text (not an empty answer)."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    responses = [
        _fake_anthropic_tool_use_response(
            tool_name="explain_concept",
            tool_input={"concept_key": "rachat_lpp"},
            tool_use_id="tu_def_1",
        ),
        _fake_anthropic_text_response(
            "Un rachat LPP, c'est verser dans ta caisse de pension pour combler "
            "une lacune (LPP art. 79b).",
            input_tokens=15,
            output_tokens=30,
        ),
    ]

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(side_effect=responses)

        result = await orchestrator.query(
            question="C'est quoi un rachat LPP ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
            language="fr",
        )

    # Two LLM calls: explain_concept tool_use, then grounded text.
    assert instance.messages.create.call_count == 2
    # The second (follow-up) call reverted to auto.
    second_kwargs = instance.messages.create.call_args_list[1].kwargs
    assert second_kwargs.get("tool_choice") == {"type": "auto"}
    # The tool_result carried the curated registry definition (NOT from weights).
    user_blocks = second_kwargs["messages"][2]["content"]
    tool_result = next(b for b in user_blocks if b.get("type") == "tool_result")
    assert "caisse de pension" in tool_result["content"], (
        "explain_concept must feed the curated registry definition back as the "
        "tool_result (grounding, not weights)"
    )
    assert "79b" in tool_result["content"]
    # Loop terminated with grounded text.
    assert result["answer"].strip() != ""
    assert result.get("tool_calls") == [{"name": "explain_concept"}]


@pytest.mark.asyncio
async def test_get_regulatory_constant_forcing_intact():
    """Regression: the existing number-forcing path is unchanged by fix_6."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    orchestrator = _NoRagOrchestrator()
    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response("7'258 CHF.")
        )

        await orchestrator.query(
            question="Quel est le plafond 3a cette année ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
        )

        kwargs = instance.messages.create.call_args.kwargs
        assert kwargs.get("tool_choice") == {
            "type": "tool", "name": "get_regulatory_constant"
        }


@pytest.mark.asyncio
async def test_tool_grounded_answer_runs_temporal_gate_before_returning():
    """Anonymous path must fail closed on stale temporal anchors after tool use."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator
    from app.services.coach.runtime_temporal_gate import _FALLBACK_FR

    orchestrator = _NoRagOrchestrator()
    responses = [
        _fake_anthropic_tool_use_response(
            tool_name="get_regulatory_constant",
            tool_input={"key": "pillar3a.max_with_lpp"},
            tool_use_id="tu_2026",
        ),
        _fake_anthropic_text_response(
            "Si tu es salarie, tu peux verser 7'258 CHF en 2025 "
            "(OPP3 art. 7). Verser en janvier ou decembre 2025 reste possible.",
            input_tokens=15,
            output_tokens=30,
        ),
    ]

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(side_effect=responses)

        with patch(
            "app.services.regulatory.tool_handler.handle_regulatory_constant",
            return_value="pillar3a.max_with_lpp = 7258 CHF\nSource : OPP3 art. 7",
        ):
            result = await orchestrator.query(
                question="Combien je peux mettre sur mon 3a cette annee ?",
                system_prompt="System",
                api_key="sk-test",
                provider="claude",
                model="claude-sonnet-4-5-20250929",
            )

    assert result["answer"] == _FALLBACK_FR
    assert "2025" not in result["answer"]
    assert result.get("tool_calls") == [{"name": "get_regulatory_constant"}]


@pytest.mark.asyncio
async def test_text_only_answer_runs_temporal_gate_before_returning():
    """Temporal gate also protects the first-pass text-only path."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator
    from app.services.coach.runtime_temporal_gate import _FALLBACK_FR

    orchestrator = _NoRagOrchestrator()

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response(
                "Tu peux verser jusqu'a 7'258 CHF en 2025 selon l'OPP3 art. 7."
            )
        )

        result = await orchestrator.query(
            question="Combien je peux mettre sur mon 3a cette annee ?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
            language="fr",
        )

    assert result["answer"] == _FALLBACK_FR
    assert "2025" not in result["answer"]


@pytest.mark.asyncio
async def test_german_answer_runs_temporal_gate_with_localized_fallback():
    """Anonymous temporal gate must not be French-only."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator
    from app.services.coach.runtime_temporal_gate import fallback_for_language

    orchestrator = _NoRagOrchestrator()
    fallback = fallback_for_language("de")

    with patch("anthropic.AsyncAnthropic") as MockClient:
        instance = MockClient.return_value
        instance.messages.create = AsyncMock(
            return_value=_fake_anthropic_text_response(
                "Du kannst 7'258 CHF im Jahr 2025 in die Säule 3a einzahlen."
            )
        )

        result = await orchestrator.query(
            question="Wie viel kann ich dieses Jahr in die Säule 3a einzahlen?",
            system_prompt="System",
            api_key="sk-test",
            provider="claude",
            model="claude-sonnet-4-5-20250929",
            language="de",
        )

    assert result["answer"] == fallback
    assert "2025" not in result["answer"]
