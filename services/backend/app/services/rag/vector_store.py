"""
ChromaDB vector store wrapper for MINT knowledge base.

Uses ChromaDB's built-in default embedding function (all-MiniLM-L6-v2 via ONNX)
so no separate sentence-transformers/torch installation is needed.

# ⚠️ RAILWAY PRODUCTION: ChromaDB persists in ./data/chromadb/
# Without a Railway persistent volume, corpus is LOST on every deploy.
# Configure volume in Railway dashboard: /data → persistent volume
"""

from __future__ import annotations

import logging
from typing import Optional

try:
    import chromadb
    from chromadb.config import Settings as ChromaSettings

    CHROMADB_AVAILABLE = True
except ImportError:
    CHROMADB_AVAILABLE = False

logger = logging.getLogger(__name__)


class MintVectorStore:
    """Local ChromaDB vector store for MINT knowledge base."""

    COLLECTION_NAME = "mint_knowledge"

    def __init__(self, persist_directory: str = "./data/chromadb"):
        """
        Initialize ChromaDB client with persistence.

        Args:
            persist_directory: Path where ChromaDB stores its data.
        """
        if not CHROMADB_AVAILABLE:
            raise ImportError(
                "chromadb is not installed. Install with: pip install -e '.[rag]'"
            )

        self._persist_directory = persist_directory
        self._client = chromadb.PersistentClient(
            path=persist_directory,
            settings=ChromaSettings(
                anonymized_telemetry=False,
                allow_reset=True,
            ),
        )
        # Create or get the main collection (uses default embedding function)
        self._collection = self._client.get_or_create_collection(
            name=self.COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )
        logger.info(
            "MintVectorStore initialized at %s with %d documents",
            persist_directory,
            self._collection.count(),
        )

    @property
    def collection(self):
        """Access the underlying ChromaDB collection."""
        return self._collection

    def add_documents(self, documents: list[dict]) -> int:
        """
        Add documents to the vector store.

        Each document dict should have:
            - id: str — unique identifier
            - text: str — the content to embed and store
            - metadata: dict — metadata (source, language, category, section, etc.)

        Args:
            documents: List of document dicts.

        Returns:
            Number of documents added.
        """
        if not documents:
            return 0

        ids = []
        texts = []
        metadatas = []

        for doc in documents:
            doc_id = doc.get("id", "")
            text = doc.get("text", "")
            metadata = doc.get("metadata", {})

            if not doc_id or not text:
                logger.warning("Skipping document with missing id or text: %s", doc_id)
                continue

            # ChromaDB metadata values must be str, int, float, or bool
            # ChromaDB >= 1.0 requires non-empty metadata dicts
            clean_metadata = {}
            for k, v in metadata.items():
                if v is None:
                    clean_metadata[k] = ""
                elif isinstance(v, (str, int, float, bool)):
                    clean_metadata[k] = v
                else:
                    clean_metadata[k] = str(v)

            # Ensure metadata is never empty (ChromaDB requirement)
            if not clean_metadata:
                clean_metadata["_source"] = "mint"

            ids.append(doc_id)
            texts.append(text)
            metadatas.append(clean_metadata)

        if not ids:
            return 0

        self._collection.upsert(
            ids=ids,
            documents=texts,
            metadatas=metadatas,
        )

        logger.info("Added/updated %d documents in vector store", len(ids))
        return len(ids)

    def query(
        self,
        query_text: str,
        n_results: int = 5,
        language: Optional[str] = None,
        where_filter: Optional[dict] = None,
    ) -> list[dict]:
        """
        Query the vector store for relevant documents.

        Args:
            query_text: The query string.
            n_results: Number of results to return.
            language: Optional language filter ("fr", "de", "en", "it").
                      Ignored when where_filter is provided (caller composes it).
            where_filter: Optional raw ChromaDB where clause. When provided,
                          the ``language`` argument is ignored.

        Returns:
            List of result dicts with keys: id, text, metadata, distance.
        """
        # Build the effective filter:
        # - If the caller passes an explicit where_filter, use it as-is.
        # - Otherwise fall back to a simple language equality filter.
        effective_filter = where_filter
        if effective_filter is None and language:
            effective_filter = {"language": language}

        try:
            results = self._collection.query(
                query_texts=[query_text],
                n_results=min(n_results, self._collection.count() or 1),
                where=effective_filter if effective_filter and self._collection.count() > 0 else None,
            )
        except Exception as e:
            logger.error("Vector store query failed: %s", e)
            return []

        # Convert ChromaDB results format to a cleaner list of dicts
        output = []
        if results and results.get("ids") and results["ids"][0]:
            for i, doc_id in enumerate(results["ids"][0]):
                output.append({
                    "id": doc_id,
                    "text": results["documents"][0][i] if results.get("documents") else "",
                    "metadata": results["metadatas"][0][i] if results.get("metadatas") else {},
                    "distance": results["distances"][0][i] if results.get("distances") else 0.0,
                })

        return output

    def count(self) -> int:
        """Return the number of documents in the store."""
        return self._collection.count()

    def list_collections(self) -> list[str]:
        """List all collection names."""
        collections = self._client.list_collections()
        # ChromaDB >= 1.0 returns Collection objects, older versions return strings
        result = []
        for c in collections:
            if isinstance(c, str):
                result.append(c)
            else:
                result.append(c.name)
        return result

    def reset(self):
        """Delete all documents from the collection (for testing)."""
        self._client.delete_collection(self.COLLECTION_NAME)
        self._collection = self._client.get_or_create_collection(
            name=self.COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )
        logger.info("Vector store reset complete")
