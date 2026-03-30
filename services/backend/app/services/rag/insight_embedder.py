"""Embeds CoachInsights into the RAG vector store for semantic retrieval.

When a user completes a sequence, scans a document, or the coach saves
an insight, this service generates an embedding and stores it in pgvector
so the coach can retrieve it via semantic search in future sessions.

doc_type = 'memory' — distinct from 'concept', 'faq', 'canton', 'legal'.

Freshness weighting: memories < 30 days get a 1.2x score boost in retrieval.

See: MINT_FINAL_EXECUTION_SYSTEM.md §13.11 (Chantier 4)
"""

import logging
import os
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


async def embed_insight(
    insight_id: str,
    topic: str,
    summary: str,
    insight_type: str,
    metadata: Optional[dict] = None,
    created_at: Optional[datetime] = None,
    user_id: Optional[str] = None,
) -> bool:
    """Embed a CoachInsight into the pgvector store.

    Args:
        insight_id: Unique insight identifier.
        topic: Topic category (e.g., 'lpp', 'retraite', '3a').
        summary: Privacy-safe summary text (~200 chars, no PII).
        insight_type: 'goal', 'decision', 'concern', 'fact'.
        metadata: Optional structured data (NOT embedded, stored as JSONB).
        created_at: When the insight was created.

    Returns:
        True if successfully embedded, False otherwise.
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        logger.debug("No DATABASE_URL — skipping insight embedding (dev mode)")
        return False

    openai_key = os.getenv("OPENAI_API_KEY")
    if not openai_key:
        logger.debug("No OPENAI_API_KEY — cannot embed insight")
        return False

    try:
        import asyncpg

        # Truncate summary to 8000 chars (OpenAI embedding max ~8191 tokens)
        safe_summary = summary[:8000] if len(summary) > 8000 else summary

        # Generate embedding via OpenAI
        embedding = await _generate_embedding(safe_summary, openai_key)
        if embedding is None:
            return False

        # Validate embedding dimensions (text-embedding-3-small = 1536)
        if len(embedding) != 1536:
            logger.warning(
                "Unexpected embedding dimension %d for insight %s (expected 1536)",
                len(embedding), insight_id,
            )
            return False

        # Store in pgvector
        conn = await asyncpg.connect(database_url)
        try:
            await conn.execute(
                """
                INSERT INTO document_embeddings
                    (doc_id, doc_type, title, content, embedding, metadata, created_at, updated_at)
                VALUES ($1, 'memory', $2, $3, $4, $5, $6, NOW())
                ON CONFLICT (doc_id) DO UPDATE SET
                    content = EXCLUDED.content,
                    embedding = EXCLUDED.embedding,
                    metadata = EXCLUDED.metadata,
                    updated_at = NOW()
                """,
                f"insight_{insight_id}",
                f"[{insight_type}] {topic}",
                summary,
                str(embedding),
                _build_metadata(topic, insight_type, metadata, created_at, user_id),
                created_at or datetime.now(timezone.utc),
            )
            logger.info("Embedded insight %s (topic=%s)", insight_id, topic)
            return True
        finally:
            await conn.close()

    except ImportError:
        logger.debug("asyncpg not available — insight embedding skipped")
        return False
    except Exception as e:
        logger.warning("Failed to embed insight %s: %s", insight_id, e)
        return False


async def remove_insight(insight_id: str) -> bool:
    """Remove a CoachInsight embedding from the vector store."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return False

    try:
        import asyncpg

        conn = await asyncpg.connect(database_url)
        try:
            await conn.execute(
                "DELETE FROM document_embeddings WHERE doc_id = $1",
                f"insight_{insight_id}",
            )
            return True
        finally:
            await conn.close()
    except Exception as e:
        logger.warning("Failed to remove insight %s: %s", insight_id, e)
        return False


async def _generate_embedding(
    text: str, api_key: str
) -> Optional[list]:
    """Generate embedding via OpenAI text-embedding-3-small."""
    try:
        import httpx

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.openai.com/v1/embeddings",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "model": "text-embedding-3-small",
                    "input": text,
                },
                timeout=10.0,
            )
            if response.status_code != 200:
                logger.warning("Embedding API error: %d", response.status_code)
                return None
            data = response.json()
            return data["data"][0]["embedding"]
    except Exception as e:
        logger.warning("Embedding generation failed: %s", e)
        return None


def _build_metadata(
    topic: str,
    insight_type: str,
    metadata: Optional[dict],
    created_at: Optional[datetime],
    user_id: Optional[str] = None,
) -> str:
    """Build JSONB metadata string for pgvector storage."""
    import json

    meta = {
        "topic": topic,
        "insight_type": insight_type,
        "is_memory": True,
    }
    if user_id:
        meta["user_id"] = user_id
    if created_at:
        meta["created_at"] = created_at.isoformat()
    if metadata:
        # Only store non-PII keys from metadata
        safe_keys = {"templateId", "stepCount", "documentType"}
        meta.update({k: v for k, v in metadata.items() if k in safe_keys})
    return json.dumps(meta)
