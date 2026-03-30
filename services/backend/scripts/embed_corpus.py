#!/usr/bin/env python3
"""
Embed the MINT knowledge corpus into pgvector (Railway PostgreSQL).

Reads education inserts, FAQ entries, and legal docs, embeds them
with text-embedding-3-small, and stores in the document_embeddings table.

Usage:
    cd services/backend
    python3 scripts/embed_corpus.py              # full run
    python3 scripts/embed_corpus.py --dry-run     # count only, no API/DB calls

Requires:
    - DATABASE_URL env var (Railway PostgreSQL with pgvector extension)
    - OPENAI_API_KEY env var (for text-embedding-3-small embeddings)
    - migrations/003_pgvector.sql already executed

Cost: ~$0.001 for 103 documents (~50K tokens at $0.02/1M tokens)

Sprint: P3-A Vector Store activation.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from pathlib import Path

# Add backend root to sys.path for imports
_BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BACKEND_DIR))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Document loaders (shared with ingest_corpus.py)
# ---------------------------------------------------------------------------


def _extract_title(content: str) -> str:
    """Extract the first H1 or H2 heading from markdown content."""
    for line in content.split("\n"):
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped.lstrip("# ").strip()
        if stripped.startswith("## "):
            return stripped.lstrip("# ").strip()
    return ""


def _load_education_inserts(project_root: Path) -> list[dict]:
    """Load education inserts from markdown files."""
    inserts_dir = project_root / "education" / "inserts"
    if not inserts_dir.exists():
        logger.warning("Education inserts dir not found: %s", inserts_dir)
        return []

    docs = []
    for md_file in sorted(inserts_dir.glob("*.md")):
        if md_file.name == "README.md":
            continue
        content = md_file.read_text(encoding="utf-8")
        if not content.strip():
            continue

        doc_id = md_file.stem
        lang = "de" if doc_id.endswith("_de") else "fr"
        title = _extract_title(content) or doc_id

        docs.append({
            "doc_id": doc_id,
            "doc_type": "concept",
            "title": title,
            "content": content,
            "metadata": {
                "source": f"education/inserts/{md_file.name}",
                "language": lang,
            },
        })

    logger.info("Loaded %d education inserts", len(docs))
    return docs


def _load_faq_entries() -> list[dict]:
    """Load FAQ entries from the in-code FAQ service."""
    try:
        from app.services.rag.faq_service import FaqService
        all_faqs = FaqService.all_faqs()
    except Exception as exc:
        logger.warning("Could not load FAQ entries: %s", exc)
        return []

    docs = []
    for faq in all_faqs:
        category_str = faq.category.value if hasattr(faq.category, "value") else str(faq.category)
        docs.append({
            "doc_id": f"faq_{faq.id}",
            "doc_type": "faq",
            "title": faq.question,
            "content": f"Question: {faq.question}\n\nReponse: {faq.answer}",
            "metadata": {
                "category": category_str,
                "legal_refs": faq.legal_refs,
                "tags": faq.tags,
                "language": "fr",
            },
        })

    logger.info("Loaded %d FAQ entries", len(docs))
    return docs


def _load_legal_docs(project_root: Path) -> list[dict]:
    """Load legal documents."""
    legal_dir = project_root / "legal"
    if not legal_dir.exists():
        logger.warning("Legal dir not found: %s", legal_dir)
        return []

    docs = []
    for md_file in sorted(legal_dir.glob("*.md")):
        content = md_file.read_text(encoding="utf-8")
        if not content.strip():
            continue
        title = _extract_title(content) or md_file.stem
        docs.append({
            "doc_id": md_file.stem.lower(),
            "doc_type": "legal",
            "title": title,
            "content": content,
            "metadata": {"source": f"legal/{md_file.name}", "language": "fr"},
        })

    logger.info("Loaded %d legal docs", len(docs))
    return docs


# ---------------------------------------------------------------------------
# Embedding
# ---------------------------------------------------------------------------


def _get_embedding(client, text: str) -> list[float]:
    """Embed text using text-embedding-3-small (1536 dimensions)."""
    # Truncate to ~8000 tokens (~32000 chars) to stay within API limits
    truncated = text[:32000]
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=truncated,
    )
    return response.data[0].embedding


# ---------------------------------------------------------------------------
# Database insertion
# ---------------------------------------------------------------------------


def _upsert_document(
    conn,
    doc_id: str,
    doc_type: str,
    title: str,
    content: str,
    embedding: list[float],
    metadata: dict,
) -> None:
    """Insert or update a document in the document_embeddings table."""
    embedding_str = "[" + ",".join(str(x) for x in embedding) + "]"
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO document_embeddings (doc_id, doc_type, title, content, embedding, metadata)
            VALUES (%s, %s, %s, %s, %s::vector, %s::jsonb)
            ON CONFLICT (doc_id) DO UPDATE SET
                content = EXCLUDED.content,
                embedding = EXCLUDED.embedding,
                metadata = EXCLUDED.metadata,
                title = EXCLUDED.title,
                updated_at = NOW()
            """,
            (doc_id, doc_type, title, content, embedding_str, json.dumps(metadata)),
        )
    conn.commit()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def embed_corpus(database_url: str, dry_run: bool = False) -> int:
    """Embed all corpus documents into pgvector.

    Args:
        database_url: PostgreSQL connection string.
        dry_run: If True, count documents without embedding or inserting.

    Returns:
        Number of documents processed.
    """
    project_root = _BACKEND_DIR.parent.parent  # services/backend -> MINT root

    # Load all sources
    all_docs = []
    all_docs.extend(_load_education_inserts(project_root))
    all_docs.extend(_load_faq_entries())
    all_docs.extend(_load_legal_docs(project_root))

    logger.info("Total documents to process: %d", len(all_docs))

    if dry_run:
        logger.info("DRY RUN -- no API calls or database writes")
        total_chars = sum(len(d["content"]) for d in all_docs)
        est_tokens = total_chars // 4
        est_cost = est_tokens * 0.02 / 1_000_000
        logger.info("Estimated: %d chars, ~%d tokens, ~$%.4f", total_chars, est_tokens, est_cost)
        for doc in all_docs:
            logger.info("  %s [%s] %s (%d chars)", doc["doc_id"], doc["doc_type"], doc["title"][:50], len(doc["content"]))
        return len(all_docs)

    # Initialize OpenAI client
    import openai
    openai_key = os.environ.get("OPENAI_API_KEY")
    if not openai_key:
        logger.error("OPENAI_API_KEY not set. Cannot embed documents.")
        sys.exit(1)
    client = openai.OpenAI(api_key=openai_key)

    # Connect to PostgreSQL
    import psycopg2
    conn = psycopg2.connect(database_url)
    logger.info("Connected to PostgreSQL")

    # Verify pgvector extension
    with conn.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'")
        if not cur.fetchone():
            logger.error("pgvector extension not installed. Run: CREATE EXTENSION vector;")
            sys.exit(1)
    logger.info("pgvector extension verified")

    # Embed and insert
    success = 0
    errors = 0
    total_tokens_est = 0

    for i, doc in enumerate(all_docs):
        try:
            embedding = _get_embedding(client, doc["content"])
            _upsert_document(
                conn,
                doc_id=doc["doc_id"],
                doc_type=doc["doc_type"],
                title=doc["title"],
                content=doc["content"],
                embedding=embedding,
                metadata=doc.get("metadata", {}),
            )
            chars = len(doc["content"])
            total_tokens_est += chars // 4
            success += 1
            logger.info(
                "Embedded %d/%d: %s [%s] (%d dims, %d chars)",
                i + 1, len(all_docs), doc["doc_id"], doc["doc_type"],
                len(embedding), chars,
            )
        except Exception as exc:
            errors += 1
            logger.error("Failed %d/%d: %s -- %s", i + 1, len(all_docs), doc["doc_id"], exc)

    conn.close()

    est_cost = total_tokens_est * 0.02 / 1_000_000
    logger.info(
        "Embedding complete: %d success, %d errors, ~%d tokens, ~$%.4f estimated cost",
        success, errors, total_tokens_est, est_cost,
    )
    return success


def main():
    parser = argparse.ArgumentParser(description="Embed MINT corpus into pgvector")
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL connection string (default: $DATABASE_URL)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Count docs without embedding")
    args = parser.parse_args()

    if not args.dry_run and not args.database_url:
        logger.error("DATABASE_URL not set. Use --database-url or set the env var.")
        sys.exit(1)

    count = embed_corpus(args.database_url or "dry-run", dry_run=args.dry_run)
    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Processed {count} documents.")


if __name__ == "__main__":
    main()
