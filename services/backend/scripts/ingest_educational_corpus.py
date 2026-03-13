#!/usr/bin/env python3
"""
Thin CLI wrapper to ingest the MINT educational corpus into ChromaDB.

Usage (from services/backend/):
    python scripts/ingest_educational_corpus.py
    python scripts/ingest_educational_corpus.py --directory ../../education/inserts
    python scripts/ingest_educational_corpus.py --directory ../../education/inserts --language fr

All parsing logic lives in MarkdownIngester.ingest_directory().
This script only wires up the path and calls that method.
"""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Default corpus path: relative to this script's location (services/backend/scripts/)
_SCRIPT_DIR = Path(__file__).resolve().parent
_DEFAULT_CORPUS_DIR = str(_SCRIPT_DIR.parent.parent.parent / "education" / "inserts")

# Default ChromaDB persistence directory (matches MintVectorStore default)
_DEFAULT_CHROMA_DIR = str(_SCRIPT_DIR.parent / "data" / "chromadb")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ingest MINT educational markdown files into ChromaDB."
    )
    parser.add_argument(
        "--directory",
        default=_DEFAULT_CORPUS_DIR,
        help=(
            f"Path to the directory containing .md files. "
            f"Defaults to: {_DEFAULT_CORPUS_DIR}"
        ),
    )
    parser.add_argument(
        "--chroma-dir",
        default=_DEFAULT_CHROMA_DIR,
        help=(
            f"Path for ChromaDB persistence. "
            f"Defaults to: {_DEFAULT_CHROMA_DIR}"
        ),
    )
    parser.add_argument(
        "--language",
        default=None,
        help=(
            "Override language for all files (e.g. 'fr', 'de'). "
            "If omitted, language is auto-detected from filename suffix."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()

    corpus_dir = os.path.abspath(args.directory)
    chroma_dir = os.path.abspath(args.chroma_dir)

    if not os.path.isdir(corpus_dir):
        logger.error("Corpus directory does not exist: %s", corpus_dir)
        return 1

    logger.info("Corpus directory : %s", corpus_dir)
    logger.info("ChromaDB directory: %s", chroma_dir)
    if args.language:
        logger.info("Language override : %s", args.language)

    from app.services.rag.vector_store import MintVectorStore
    from app.services.rag.ingester import MarkdownIngester

    vector_store = MintVectorStore(persist_directory=chroma_dir)
    ingester = MarkdownIngester(vector_store=vector_store)

    total = ingester.ingest_directory(corpus_dir, language=args.language)

    logger.info("Ingestion complete: %d chunks indexed.", total)
    logger.info("Vector store now contains %d documents.", vector_store.count())

    if total == 0:
        logger.warning(
            "No chunks were ingested. Check that the directory contains .md files "
            "and that ChromaDB is installed ('pip install -e \".[rag]\"')."
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
