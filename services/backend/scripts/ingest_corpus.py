#!/usr/bin/env python3
"""
Ingest MINT education corpus into ChromaDB vector store.

Reads:
  - education/inserts/*.md  (40 educational concept files)
  - FAQ entries from faq_service.py (58 in-code entries)
  - legal/*.md (5 legal documents)

Produces:
  - ChromaDB collection "mint_knowledge" with embedded documents
  - Uses ChromaDB's built-in embedding (all-MiniLM-L6-v2 via ONNX)
  - No external API needed (embeddings computed locally)

Usage:
  cd services/backend
  python3 scripts/ingest_corpus.py

  # With custom persist directory:
  python3 scripts/ingest_corpus.py --persist-dir ./data/chromadb

  # Dry run (show what would be ingested without writing):
  python3 scripts/ingest_corpus.py --dry-run

Sprint: P3-A Vector Store activation.
"""

from __future__ import annotations

import argparse
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
# Document loaders
# ---------------------------------------------------------------------------


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

        # Extract question ID from filename (e.g., q_3a_accounts_count.md)
        doc_id = f"insert_{md_file.stem}"

        # Determine language from filename (_de suffix = German)
        lang = "de" if md_file.stem.endswith("_de") else "fr"

        # Determine category from filename
        category = "general"
        stem_lower = md_file.stem.lower()
        if "3a" in stem_lower or "pilier" in stem_lower:
            category = "pilier_3a"
        elif "avs" in stem_lower:
            category = "avs"
        elif "lpp" in stem_lower:
            category = "lpp"
        elif "disability" in stem_lower or "invalidite" in stem_lower:
            category = "protection"
        elif "divorce" in stem_lower or "mariage" in stem_lower or "naissance" in stem_lower:
            category = "famille"
        elif "canton" in stem_lower or "fiscal" in stem_lower:
            category = "fiscalite"
        elif "mortgage" in stem_lower or "immobilier" in stem_lower:
            category = "logement"
        elif "independant" in stem_lower or "chomage" in stem_lower:
            category = "travail"

        docs.append({
            "id": doc_id,
            "text": content,
            "metadata": {
                "source": f"education/inserts/{md_file.name}",
                "doc_type": "concept",
                "language": lang,
                "category": category,
                "level": 1,
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
        doc_id = f"faq_{faq.id}"
        docs.append({
            "id": doc_id,
            "text": f"Question: {faq.question}\n\nRéponse: {faq.answer}",
            "metadata": {
                "source": "faq_service",
                "doc_type": "faq",
                "language": "fr",
                "category": faq.category.value if hasattr(faq.category, "value") else str(faq.category),
                "level": 1,
                "faq_id": faq.id,
            },
        })

    logger.info("Loaded %d FAQ entries", len(docs))
    return docs


def _load_legal_docs(project_root: Path) -> list[dict]:
    """Load legal documents (disclaimer, CGU, privacy, etc.)."""
    legal_dir = project_root / "legal"
    if not legal_dir.exists():
        logger.warning("Legal dir not found: %s", legal_dir)
        return []

    docs = []
    for md_file in sorted(legal_dir.glob("*.md")):
        content = md_file.read_text(encoding="utf-8")
        if not content.strip():
            continue

        doc_id = f"legal_{md_file.stem}"
        docs.append({
            "id": doc_id,
            "text": content,
            "metadata": {
                "source": f"legal/{md_file.name}",
                "doc_type": "legal",
                "language": "fr",
                "category": "legal",
                "level": 1,
            },
        })

    logger.info("Loaded %d legal docs", len(docs))
    return docs


# ---------------------------------------------------------------------------
# Main ingestion
# ---------------------------------------------------------------------------


def ingest(persist_dir: str, dry_run: bool = False) -> int:
    """Ingest all corpus documents into ChromaDB.

    Args:
        persist_dir: Path to ChromaDB persist directory.
        dry_run: If True, show what would be ingested without writing.

    Returns:
        Number of documents ingested.
    """
    project_root = _BACKEND_DIR.parent.parent  # services/backend -> MINT root

    # Load all document sources
    all_docs = []
    all_docs.extend(_load_education_inserts(project_root))
    all_docs.extend(_load_faq_entries())
    all_docs.extend(_load_legal_docs(project_root))

    logger.info("Total documents to ingest: %d", len(all_docs))

    if dry_run:
        logger.info("DRY RUN — no documents written")
        for doc in all_docs:
            meta = doc.get("metadata", {})
            logger.info(
                "  %s [%s/%s] %d chars",
                doc["id"],
                meta.get("doc_type", "?"),
                meta.get("category", "?"),
                len(doc.get("text", "")),
            )
        return len(all_docs)

    # Initialize ChromaDB vector store
    from app.services.rag.vector_store import MintVectorStore

    store = MintVectorStore(persist_directory=persist_dir)

    # Check existing count
    existing = store.collection.count()
    logger.info("Existing documents in collection: %d", existing)

    # Ingest (ChromaDB upserts by ID — safe to re-run)
    added = store.add_documents(all_docs)
    final_count = store.collection.count()

    logger.info(
        "Ingestion complete: %d processed, collection now has %d documents",
        added,
        final_count,
    )
    return added


def main():
    parser = argparse.ArgumentParser(description="Ingest MINT corpus into ChromaDB")
    parser.add_argument(
        "--persist-dir",
        default=str(_BACKEND_DIR / "data" / "chromadb"),
        help="ChromaDB persist directory (default: ./data/chromadb)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be ingested without writing",
    )
    args = parser.parse_args()

    count = ingest(args.persist_dir, dry_run=args.dry_run)
    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Ingested {count} documents.")


if __name__ == "__main__":
    main()
