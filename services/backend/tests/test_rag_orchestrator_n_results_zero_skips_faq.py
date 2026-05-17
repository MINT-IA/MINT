"""Wave 1c-A2.1 regression test — n_results=0 must skip FAQ fallback.

When the caller (coach_chat.py:_run_agent_loop) detects a tool-eligible intent
and passes n_results=0 to suppress legacy RAG retrieval (per the Wave 1c-A2
gate at coach_chat.py:_TOOL_ELIGIBLE_INTENTS), the orchestrator MUST also skip
the FAQ fallback at orchestrator.py:Step 1b. Otherwise the FAQ corpus re-injects
the same « consulte ahv-iv.ch » redirect chunks the orchestration-layer gate was
supposed to suppress, defeating the whole Wave A2 fix.

Evidence of the bug pre-fix:
  .planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/
  payload-2026-05-15-A2-2219.jsonl shows `wave1c_a2: RAG suppressed` log fired
  AND the WAVE1C_PAYLOAD log line still contained the full RAG-prefixed user
  message (1486 chars with 3 redirect chunks).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.rag.orchestrator import RAGOrchestrator


@pytest.mark.asyncio
async def test_query_with_n_results_zero_skips_faq_fallback():
    """When n_results=0, FaqService.search MUST NOT be called."""
    vector_store = MagicMock()
    orchestrator = RAGOrchestrator(vector_store=vector_store)
    orchestrator.retriever = MagicMock()
    orchestrator.retriever.retrieve = AsyncMock(return_value=[])  # empty

    fake_llm_response = {"text": "ok", "tool_calls": None, "usage_tokens": 1}

    with patch(
        "app.services.rag.orchestrator.LLMClient"
    ) as MockLLMClient, patch(
        "app.services.rag.orchestrator.FaqService"
    ) as MockFaq:
        MockLLMClient.return_value.generate = AsyncMock(
            return_value=fake_llm_response
        )

        await orchestrator.query(
            question="Quelle sera ma rente AVS?",
            api_key="test",
            provider="claude",
            system_prompt="test",
            n_results=0,
        )

        # The fix: FaqService.search MUST NOT be called when n_results=0
        MockFaq.search.assert_not_called()


@pytest.mark.asyncio
async def test_query_with_default_n_results_still_uses_faq_fallback_when_few_chunks():
    """When n_results defaults to 5 and retriever returns <2 chunks, FAQ fallback fires.

    Regression floor: the n_results>0 gate must NOT break the existing
    FAQ-as-context-enrichment behavior for educational queries.
    """
    vector_store = MagicMock()
    orchestrator = RAGOrchestrator(vector_store=vector_store)
    orchestrator.retriever = MagicMock()
    orchestrator.retriever.retrieve = AsyncMock(return_value=[])  # 0 chunks

    fake_llm_response = {"text": "ok", "tool_calls": None, "usage_tokens": 1}

    with patch(
        "app.services.rag.orchestrator.LLMClient"
    ) as MockLLMClient, patch(
        "app.services.rag.orchestrator.FaqService"
    ) as MockFaq:
        MockLLMClient.return_value.generate = AsyncMock(
            return_value=fake_llm_response
        )
        MockFaq.search.return_value = []  # FAQs return empty too — no enrichment

        await orchestrator.query(
            question="Comment fonctionne le 2e pilier?",
            api_key="test",
            provider="claude",
            system_prompt="test",
            # n_results omitted — defaults to 5
        )

        # The educational path must still try FAQ fallback
        MockFaq.search.assert_called_once_with("Comment fonctionne le 2e pilier?")
