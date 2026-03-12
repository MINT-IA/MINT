"""
RAG retriever for MINT knowledge base.

Enriches queries with profile context and retrieves relevant
knowledge chunks from the vector store.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.rag.vector_store import MintVectorStore

logger = logging.getLogger(__name__)


class MintRetriever:
    """Retrieve relevant knowledge for user queries."""

    def __init__(self, vector_store: MintVectorStore):
        """
        Initialize the retriever.

        Args:
            vector_store: The MintVectorStore to query.
        """
        self.vector_store = vector_store

    def retrieve(
        self,
        query: str,
        profile_context: Optional[dict] = None,
        n_results: int = 5,
        language: Optional[str] = None,
        literacy_level: str = "beginner",
    ) -> list[dict]:
        """
        Retrieve relevant knowledge chunks for a query.

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
        # Enrich the query with profile context
        enriched_query = self._enrich_query(query, profile_context)

        # Build level filter based on literacy_level
        # "beginner" gets both level 0 (simplified) and level 1 (full).
        # "intermediate" and "advanced" get level 1 only.
        if literacy_level == "beginner":
            level_filter = {"level": {"$in": [0, 1]}}
        else:
            level_filter = {"level": 1}

        # Merge with language filter when provided
        if language:
            where_filter: Optional[dict] = {
                "$and": [
                    {"language": language},
                    level_filter,
                ]
            }
        else:
            where_filter = level_filter

        # Query the vector store with the combined filter
        results = self.vector_store.query(
            query_text=enriched_query,
            n_results=n_results,
            language=None,  # language handled in where_filter above
            where_filter=where_filter,
        )

        # Format results with source information
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
