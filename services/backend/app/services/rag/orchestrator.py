"""
RAG orchestrator for MINT.

Coordinates the full RAG pipeline: retrieve, build context, generate, and filter.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.rag.guardrails import ComplianceGuardrails
from app.services.rag.llm_client import LLMClient
from app.services.rag.retriever import MintRetriever
from app.services.rag.vector_store import MintVectorStore

logger = logging.getLogger(__name__)


class RAGOrchestrator:
    """Orchestrate the full RAG pipeline."""

    def __init__(self, vector_store: MintVectorStore):
        """
        Initialize the orchestrator.

        Args:
            vector_store: The MintVectorStore for retrieval.
        """
        self.vector_store = vector_store
        self.retriever = MintRetriever(vector_store)
        self.guardrails = ComplianceGuardrails()

    async def query(
        self,
        question: str,
        api_key: str,
        provider: str,
        model: Optional[str] = None,
        profile_context: Optional[dict] = None,
        language: str = "fr",
        n_results: int = 5,
    ) -> dict:
        """
        Execute the full RAG pipeline.

        Steps:
            1. Retrieve relevant chunks from the vector store.
            2. Build context from chunks.
            3. Create LLM client with BYOK key.
            4. Generate response with guardrails system prompt.
            5. Apply post-generation compliance filter.
            6. Return answer with sources and disclaimers.

        Args:
            question: The user's question.
            api_key: User's API key (BYOK — not stored).
            provider: LLM provider ("claude", "openai", "mistral").
            model: Optional model override.
            profile_context: Optional profile data for personalization.
            language: Language code ("fr", "de", "en", "it").
            n_results: Number of context chunks to retrieve.

        Returns:
            Dict with keys: answer, sources, disclaimers, tokens_used.
        """
        # Step 1: Retrieve relevant chunks
        retrieved = self.retriever.retrieve(
            query=question,
            profile_context=profile_context,
            n_results=n_results,
            language=language,
        )

        # Step 2: Build context from chunks
        context_chunks = [r["text"] for r in retrieved if r.get("text")]

        # Step 3: Create LLM client with BYOK key
        llm_client = LLMClient(
            provider=provider,
            api_key=api_key,
            model=model,
        )

        # Step 4: Generate response with guardrails system prompt
        system_prompt = self.guardrails.build_system_prompt(
            language, profile_context=profile_context
        )
        raw_response = await llm_client.generate(
            system_prompt=system_prompt,
            user_message=question,
            context_chunks=context_chunks,
        )

        # Step 5: Apply post-generation compliance filter
        filtered = self.guardrails.filter_response(raw_response, language)

        # Step 6: Build sources list
        sources = []
        seen_sources = set()
        for r in retrieved:
            source = r.get("source", {})
            source_key = f"{source.get('file', '')}:{source.get('section', '')}"
            if source_key not in seen_sources:
                seen_sources.add(source_key)
                sources.append(source)

        # Estimate token usage (rough approximation)
        tokens_used = self._estimate_tokens(
            system_prompt, question, context_chunks, filtered["text"]
        )

        return {
            "answer": filtered["text"],
            "sources": sources,
            "disclaimers": filtered["disclaimers_added"],
            "tokens_used": tokens_used,
        }

    def _estimate_tokens(
        self,
        system_prompt: str,
        question: str,
        context_chunks: list[str],
        response: str,
    ) -> int:
        """
        Estimate token usage for the request.

        Uses tiktoken if available, otherwise a rough word-based approximation.
        """
        full_text = system_prompt + question + "".join(context_chunks) + response

        try:
            import tiktoken

            enc = tiktoken.encoding_for_model("gpt-4o")
            return len(enc.encode(full_text))
        except Exception:
            # Rough approximation: ~4 chars per token for European languages
            return len(full_text) // 4
