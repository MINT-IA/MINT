"""
HybridSearchService — pgvector similarity + PostgreSQL FTS.

Architecture:
    1. Vector similarity: cosine distance on embeddings (pgvector)
    2. Keyword FTS: PostgreSQL ts_rank with French tokenizer
    3. Score fusion: weighted combination (0.7 vector + 0.3 keyword)
    4. Fallback: keyword-only when embedding API fails

Replaces ChromaDB as the primary retrieval method in production.
ChromaDB remains for dev/CI. FaqService remains as ultimate fallback.

Compliance:
    - No PII in the search index (education + FAQ + legal only)
    - DATABASE_URL from environment (never hardcoded)
    - OPENAI_API_KEY for query embeddings only (not for chat)

Sources:
    - docs/P3_READINESS_TRACKER.md
    - services/backend/migrations/003_pgvector.sql

Sprint: P3-A Vector Store activation.
"""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# SearchResult
# ---------------------------------------------------------------------------


@dataclass
class SearchResult:
    """A single hybrid search result with separate scores."""

    doc_id: str
    doc_type: str
    title: str
    content: str
    score: float          # fused score (0.7 * vector + 0.3 * keyword)
    vector_score: float   # cosine similarity (0-1)
    keyword_score: float  # FTS ts_rank
    metadata: dict


# ---------------------------------------------------------------------------
# SQL queries
# ---------------------------------------------------------------------------

_HYBRID_SEARCH_SQL = """
WITH vector_results AS (
    SELECT doc_id, title, content, metadata, doc_type,
           1 - (embedding <=> %(query_embedding)s::vector) AS vector_score
    FROM document_embeddings
    WHERE (%(doc_types)s IS NULL OR doc_type = ANY(%(doc_types)s))
      AND (doc_type != 'memory' OR metadata::jsonb->>'user_id' = %(user_id)s OR %(user_id)s IS NULL)
    ORDER BY embedding <=> %(query_embedding)s::vector
    LIMIT %(n_results)s
),
keyword_results AS (
    SELECT doc_id, title, content, metadata, doc_type,
           ts_rank(to_tsvector('french', content), plainto_tsquery('french', %(query_text)s)) AS keyword_score
    FROM document_embeddings
    WHERE to_tsvector('french', content) @@ plainto_tsquery('french', %(query_text)s)
      AND (%(doc_types)s IS NULL OR doc_type = ANY(%(doc_types)s))
      AND (doc_type != 'memory' OR metadata::jsonb->>'user_id' = %(user_id)s OR %(user_id)s IS NULL)
    LIMIT %(n_results)s
)
SELECT COALESCE(v.doc_id, k.doc_id) AS doc_id,
       COALESCE(v.title, k.title) AS title,
       COALESCE(v.content, k.content) AS content,
       COALESCE(v.metadata, k.metadata) AS metadata,
       COALESCE(v.doc_type, k.doc_type) AS doc_type,
       COALESCE(v.vector_score, 0) AS vector_score,
       COALESCE(k.keyword_score, 0) AS keyword_score,
       (0.7 * COALESCE(v.vector_score, 0) + 0.3 * COALESCE(k.keyword_score, 0))
       * CASE
           WHEN COALESCE(v.doc_type, k.doc_type) = 'memory'
                AND COALESCE(v.metadata, k.metadata) IS NOT NULL
                AND COALESCE(v.metadata, k.metadata)::jsonb ? 'created_at'
                AND COALESCE(v.metadata, k.metadata)::jsonb->>'created_at' ~ '^\d{4}-\d{2}-\d{2}'
                AND (NOW() - (COALESCE(v.metadata, k.metadata)::jsonb->>'created_at')::timestamptz) < INTERVAL '30 days'
           THEN 1.2  -- 20% freshness boost for recent memories
           ELSE 1.0
         END AS fused_score
FROM vector_results v
FULL OUTER JOIN keyword_results k ON v.doc_id = k.doc_id
WHERE (0.7 * COALESCE(v.vector_score, 0) + 0.3 * COALESCE(k.keyword_score, 0)) >= %(min_score)s
ORDER BY fused_score DESC
LIMIT %(n_results)s;
"""

_KEYWORD_ONLY_SQL = """
SELECT doc_id, title, content, metadata, doc_type,
       0.0 AS vector_score,
       ts_rank(to_tsvector('french', content), plainto_tsquery('french', %(query_text)s)) AS keyword_score,
       ts_rank(to_tsvector('french', content), plainto_tsquery('french', %(query_text)s)) AS fused_score
FROM document_embeddings
WHERE to_tsvector('french', content) @@ plainto_tsquery('french', %(query_text)s)
  AND (%(doc_types)s IS NULL OR doc_type = ANY(%(doc_types)s))
  AND (doc_type != 'memory' OR metadata::jsonb->>'user_id' = %(user_id)s OR %(user_id)s IS NULL)
ORDER BY keyword_score DESC
LIMIT %(n_results)s;
"""

_CHECK_PGVECTOR_SQL = "SELECT 1 FROM pg_extension WHERE extname = 'vector'"


# ---------------------------------------------------------------------------
# HybridSearchService
# ---------------------------------------------------------------------------


class HybridSearchService:
    """Hybrid vector + keyword search on pgvector (Railway PostgreSQL).

    Production retrieval service. Falls back to keyword-only when the
    embedding API is unavailable (e.g., OpenAI rate limit or outage).

    Usage:
        service = HybridSearchService(db_url=os.environ["DATABASE_URL"])
        results = await service.search("rachat LPP", n_results=5)
    """

    VECTOR_WEIGHT = 0.7
    KEYWORD_WEIGHT = 0.3

    def __init__(self, db_url: str):
        """Initialize with a PostgreSQL connection string.

        Args:
            db_url: PostgreSQL connection string (from DATABASE_URL env var).
        """
        self._db_url = db_url
        self._openai_client = None  # lazy-initialized
        self._available: Optional[bool] = None

    def _get_openai_client(self):
        """Lazy-initialize the OpenAI client for query embedding."""
        if self._openai_client is None:
            try:
                import openai
                api_key = os.environ.get("OPENAI_API_KEY", "")
                if api_key:
                    self._openai_client = openai.OpenAI(api_key=api_key)
                else:
                    logger.warning("OPENAI_API_KEY not set -- vector search unavailable")
            except ImportError:
                logger.warning("openai package not installed -- vector search unavailable")
        return self._openai_client

    def _get_connection(self):
        """Get a psycopg2 connection to the PostgreSQL database."""
        import psycopg2
        return psycopg2.connect(self._db_url)

    def _embed_query(self, query: str) -> Optional[str]:
        """Embed a query string and return as pgvector-compatible string.

        Returns None if the embedding API is unavailable.
        """
        client = self._get_openai_client()
        if client is None:
            return None

        try:
            response = client.embeddings.create(
                model="text-embedding-3-small",
                input=query[:8191],
            )
            vec = response.data[0].embedding
            return "[" + ",".join(str(x) for x in vec) + "]"
        except Exception as exc:
            logger.warning("Query embedding failed: %s", exc)
            return None

    async def is_available(self) -> bool:
        """Check if pgvector is accessible on the connected PostgreSQL.

        Caches the result after first check.
        """
        if self._available is not None:
            return self._available

        try:
            conn = self._get_connection()
            with conn.cursor() as cur:
                cur.execute(_CHECK_PGVECTOR_SQL)
                row = cur.fetchone()
                self._available = row is not None
            conn.close()
        except Exception as exc:
            logger.warning("pgvector availability check failed: %s", exc)
            self._available = False

        return self._available

    async def search(
        self,
        query: str,
        n_results: int = 5,
        doc_types: Optional[list[str]] = None,
        min_score: float = 0.1,
        user_id: Optional[str] = None,
    ) -> list[SearchResult]:
        """Search using hybrid vector + keyword scoring.

        Falls back to keyword-only when embedding API is unavailable.

        Args:
            query: User's search query (natural language).
            n_results: Maximum results to return.
            doc_types: Optional filter (e.g., ["concept", "faq"]).
            min_score: Minimum fused score threshold.

        Returns:
            List of SearchResult ordered by fused_score descending.
        """
        if not query or not query.strip():
            return []

        # Attempt to embed the query for vector search
        query_embedding = self._embed_query(query)

        conn = None
        try:
            conn = self._get_connection()

            if query_embedding:
                # Hybrid search: vector + keyword
                sql = _HYBRID_SEARCH_SQL
                params = {
                    "query_embedding": query_embedding,
                    "query_text": query,
                    "n_results": n_results,
                    "doc_types": doc_types,
                    "min_score": min_score,
                    "user_id": user_id,
                }
            else:
                # Fallback: keyword-only (no embedding available)
                sql = _KEYWORD_ONLY_SQL
                params = {
                    "query_text": query,
                    "n_results": n_results,
                    "doc_types": doc_types,
                    "user_id": user_id,
                }
                logger.info("hybrid_search falling back to keyword-only (no embedding)")

            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()

            results = []
            for row in rows:
                doc_id, title, content, metadata_raw, doc_type, vector_score, keyword_score, fused_score = row
                metadata = json.loads(metadata_raw) if isinstance(metadata_raw, str) else (metadata_raw or {})
                results.append(SearchResult(
                    doc_id=doc_id,
                    doc_type=doc_type,
                    title=title or "",
                    content=content or "",
                    score=float(fused_score),
                    vector_score=float(vector_score),
                    keyword_score=float(keyword_score),
                    metadata=metadata,
                ))

            # Monitoring log
            logger.info(
                "hybrid_search query=%r results=%d top_fused=%.3f top_vector=%.3f top_keyword=%.3f mode=%s",
                query[:50],
                len(results),
                results[0].score if results else 0,
                results[0].vector_score if results else 0,
                results[0].keyword_score if results else 0,
                "hybrid" if query_embedding else "keyword_only",
            )

            return results

        except Exception as exc:
            logger.error("hybrid_search failed: %s", exc)
            return []
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass
