"""Regression test for B3 — RAGOrchestrator empty-text canned-fallback bug.

When the LLM emits only a tool_use (e.g. ``save_insight(salary=8500)``) with
no text narration, ``response_text`` is empty. The previous code called
``self.guardrails.filter_response("", language)`` unconditionally, which
triggered the ``"Sortie vide"`` fallback path inside ``ComplianceGuard`` and
returned the canned ``_SAFE_FALLBACK_FR`` (« Je suis là pour t'aider à
comprendre ta situation financière. N'hésite pas à reformuler ta question
ou explorer des simulateurs pour des estimations chiffrées. ») as the
``answer``. The agent loop in ``coach_chat.py`` then sees a non-empty
``answer_text``, skips its empty-end-turn re-prompt, and the canned text
reaches the user — masking the actual ``tool_use``.

The fix in ``orchestrator.py`` mirrors the existing guard in
``_NoRagOrchestrator`` (commit ``3483f4e3``, 2026-04-14) — skip the filter
when the text is empty.

This test asserts the symmetric behaviour for ``RAGOrchestrator``.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.rag.orchestrator import RAGOrchestrator


@pytest.mark.asyncio
async def test_query_returns_empty_answer_when_llm_returns_tool_only_no_text():
    """Empty text + tool_calls must NOT trigger the canned fallback.

    Symmetric to the existing ``_NoRagOrchestrator`` coverage. Without the
    guard at ``orchestrator.py:137-150``, ``answer`` would be the canned
    ``_SAFE_FALLBACK_FR`` from ``ComplianceGuardrails.filter_response`` —
    masking the ``tool_use`` and the agent loop's re-prompt opportunity.
    """
    # Vector store stub — return one tiny chunk so we don't hit the FAQ branch
    vector_store = MagicMock()

    orchestrator = RAGOrchestrator(vector_store=vector_store)

    # Stub the retriever to return one chunk (so faq_sources stays empty)
    orchestrator.retriever = MagicMock()
    orchestrator.retriever.retrieve = AsyncMock(
        return_value=[{"text": "context chunk", "source": {}}, {"text": "second", "source": {}}]
    )

    # Stub the LLMClient to return a tool-only response (text="" + tool_calls)
    fake_tool_call = {
        "name": "save_insight",
        "input": {"key": "salary_monthly_chf", "value": 8500},
    }

    fake_llm_response = {
        "text": "",
        "tool_calls": [fake_tool_call],
        "usage_tokens": 100,
    }

    with patch(
        "app.services.rag.orchestrator.LLMClient",
        autospec=True,
    ) as mock_llm_cls:
        mock_llm = mock_llm_cls.return_value
        mock_llm.generate = AsyncMock(return_value=fake_llm_response)

        result = await orchestrator.query(
            question="je gagne 8500 francs par mois",
            api_key="test-key",
            provider="claude",
            language="fr",
            tools=[{"name": "save_insight"}],
        )

    # CORE assertion : answer is empty (not the canned fallback)
    assert result["answer"] == "", (
        f"Expected empty answer when LLM returns tool-only with no text. "
        f"Got {result['answer']!r}. The canned _SAFE_FALLBACK_FR fallback "
        f"is leaking through — guard at orchestrator.py:137-150 is missing "
        f"or regressed."
    )

    # Tool call should be preserved so the agent loop can act on it
    assert result.get("tool_calls") == [fake_tool_call], (
        "tool_calls must be returned to caller so the agent loop in "
        "coach_chat.py can execute the save_insight call."
    )


@pytest.mark.asyncio
async def test_query_still_filters_response_when_text_is_present():
    """Non-empty text path must still go through compliance filter.

    Negative control — confirms the guard only skips the filter for
    empty/whitespace text, not for normal coach replies.
    """
    vector_store = MagicMock()
    orchestrator = RAGOrchestrator(vector_store=vector_store)
    orchestrator.retriever = MagicMock()
    orchestrator.retriever.retrieve = AsyncMock(
        return_value=[{"text": "ctx", "source": {}}, {"text": "ctx2", "source": {}}]
    )

    # Mock guardrails so we can assert filter_response was called
    orchestrator.guardrails = MagicMock()
    orchestrator.guardrails.filter_response.return_value = {
        "text": "Filtered reply",
        "warnings": [],
        "disclaimers_added": [],
    }
    orchestrator.guardrails.build_system_prompt.return_value = "system"

    fake_llm_response = {
        "text": "Voici un point sur ta situation.",
        "tool_calls": None,
        "usage_tokens": 50,
    }

    with patch(
        "app.services.rag.orchestrator.LLMClient",
        autospec=True,
    ) as mock_llm_cls:
        mock_llm = mock_llm_cls.return_value
        mock_llm.generate = AsyncMock(return_value=fake_llm_response)

        result = await orchestrator.query(
            question="ok",
            api_key="test-key",
            provider="claude",
            language="fr",
        )

    orchestrator.guardrails.filter_response.assert_called_once_with(
        "Voici un point sur ta situation.",
        "fr",
        cursor_level=None,
        profile_context=None,
        user_message="ok",
    )
    assert result["answer"] == "Filtered reply"


@pytest.mark.asyncio
async def test_query_forwards_cursor_level_to_compliance_filter():
    """RAG path must enforce the same N-level cursor as coach_chat wiring."""
    vector_store = MagicMock()
    orchestrator = RAGOrchestrator(vector_store=vector_store)
    orchestrator.retriever = MagicMock()
    orchestrator.retriever.retrieve = AsyncMock(
        return_value=[{"text": "ctx", "source": {}}, {"text": "ctx2", "source": {}}]
    )

    orchestrator.guardrails = MagicMock()
    orchestrator.guardrails.filter_response.return_value = {
        "text": "Filtered N5 reply",
        "warnings": [],
        "disclaimers_added": [],
    }
    orchestrator.guardrails.build_system_prompt.return_value = "system"

    fake_llm_response = {
        "text": "Tu devrais absolument acheter ce produit bancaire.",
        "tool_calls": None,
        "usage_tokens": 50,
    }

    with patch(
        "app.services.rag.orchestrator.LLMClient",
        autospec=True,
    ) as mock_llm_cls:
        mock_llm = mock_llm_cls.return_value
        mock_llm.generate = AsyncMock(return_value=fake_llm_response)

        result = await orchestrator.query(
            question="que dois-je faire?",
            api_key="test-key",
            provider="claude",
            language="fr",
            cursor_level="N5",
        )

    orchestrator.guardrails.filter_response.assert_called_once_with(
        "Tu devrais absolument acheter ce produit bancaire.",
        "fr",
        cursor_level="N5",
        profile_context=None,
        user_message="que dois-je faire?",
    )
    assert result["answer"] == "Filtered N5 reply"
