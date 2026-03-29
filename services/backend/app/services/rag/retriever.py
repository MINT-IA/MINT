"""
RAG retriever for MINT knowledge base.

Enriches queries with profile context and retrieves relevant
knowledge chunks from the vector store.

Retrieval priority chain:
    1. HybridSearchService (pgvector on Railway PostgreSQL) — production
    2. MintVectorStore (ChromaDB) — dev/CI fallback
    3. Empty results — FaqService handles ultimate fallback in orchestrator

All methods are async to integrate cleanly with FastAPI's async pipeline.
No asyncio.get_event_loop() or ThreadPoolExecutor bridges needed.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.rag.vector_store import MintVectorStore

logger = logging.getLogger(__name__)


class MintRetriever:
    """Retrieve relevant knowledge for user queries."""

    def __init__(self, vector_store: MintVectorStore, hybrid_search=None):
        """
        Initialize the retriever.

        Args:
            vector_store: The MintVectorStore (ChromaDB) for dev/CI.
            hybrid_search: Optional HybridSearchService (pgvector) for production.
                When provided and available, takes priority over ChromaDB.
        """
        self.vector_store = vector_store
        self._hybrid = hybrid_search

    async def retrieve(
        self,
        query: str,
        profile_context: Optional[dict] = None,
        n_results: int = 5,
        language: Optional[str] = None,
        literacy_level: str = "beginner",
        user_id: Optional[str] = None,
    ) -> list[dict]:
        """
        Retrieve relevant knowledge chunks for a query.

        Priority chain: pgvector (production) → ChromaDB (dev/CI) → empty.
        The orchestrator handles FaqService as the ultimate fallback.

        Args:
            query: The user's question.
            profile_context: Optional profile data to enrich the query.
                Expected keys: canton, age, civil_status, employment_status.
            n_results: Number of results to return.
            language: Optional language filter.
            literacy_level: Financial literacy level of the user.
                - "beginner"     → include level 0 and level 1 documents
                - "intermediate" → level 1 documents only
                - "advanced"     → level 1 documents only

        Returns:
            List of result dicts with keys: id, text, metadata, distance, source.
        """
        # Priority 1: HybridSearchService (pgvector — production)
        if self._hybrid:
            try:
                hybrid_results = await self._hybrid.search(
                    query, n_results=n_results, user_id=user_id,
                )
                if hybrid_results:
                    formatted = []
                    for r in hybrid_results:
                        formatted.append({
                            "id": r.doc_id,
                            "text": r.content,
                            "metadata": r.metadata,
                            "distance": 1.0 - r.score,
                            "source": {
                                "title": r.title,
                                "file": r.metadata.get("source", ""),
                                "section": "",
                            },
                        })
                    logger.info(
                        "retriever used pgvector: %d results for %r",
                        len(formatted), query[:40],
                    )
                    return formatted
            except Exception as exc:
                logger.warning(
                    "pgvector retrieval failed, falling back to ChromaDB: %s", exc,
                )

        # Priority 2: ChromaDB (dev/CI fallback)
        enriched_query = self._enrich_query(query, profile_context)

        if literacy_level == "beginner":
            level_filter = {"level": {"$in": [0, 1]}}
        else:
            level_filter = {"level": 1}

        if language:
            where_filter: Optional[dict] = {
                "$and": [
                    {"language": language},
                    level_filter,
                ]
            }
        else:
            where_filter = level_filter

        results = self.vector_store.query(
            query_text=enriched_query,
            n_results=n_results,
            language=None,
            where_filter=where_filter,
        )

        formatted = []
        for result in results:
            metadata = result.get("metadata", {})
            formatted.append({
                "id": result.get("id", ""),
                "text": result.get("text", ""),
                "metadata": metadata,
                "distance": result.get("distance", 0.0),
                "source": {
                    "title": metadata.get("title", ""),
                    "file": metadata.get("source", ""),
                    "section": metadata.get("section", ""),
                },
            })

        return formatted

    def _enrich_query(
        self,
        query: str,
        profile_context: Optional[dict] = None,
    ) -> str:
        """
        Enrich the user query with profile context for better retrieval.

        This helps the vector search find more relevant results by including
        contextual information about the user's situation.
        """
        if not profile_context:
            return query

        context_parts = []

        canton = profile_context.get("canton")
        if canton:
            context_parts.append(f"Canton: {canton}")

        age = profile_context.get("age")
        if age:
            context_parts.append(f"Age: {age}")

        civil_status = profile_context.get("civil_status")
        if civil_status:
            context_parts.append(f"Statut civil: {civil_status}")

        employment_status = profile_context.get("employment_status")
        if employment_status:
            context_parts.append(f"Statut professionnel: {employment_status}")

        if context_parts:
            context_str = ", ".join(context_parts)
            return f"[Profil: {context_str}] {query}"

        return query
