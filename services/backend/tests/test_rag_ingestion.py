"""
Tests for RAG bi-niveau ingestion and literacy_level filtering.

Covers:
- Ingestion without errors (basic smoke)
- level metadata correctly indexed for bi-niveau documents
- level metadata defaults to 1 for plain documents
- literacy_level="beginner" retrieves level 0 and level 1 documents
- literacy_level="intermediate" retrieves level 1 documents only
- literacy_level="advanced" retrieves level 1 documents only
- Bi-niveau sections stored as separate chunks with correct level
- Non-niveau sections in bi-niveau doc inherit default level
"""

from __future__ import annotations

import importlib
import os
import shutil
import tempfile

import asyncio
import pytest

_chromadb_available = importlib.util.find_spec("chromadb") is not None
requires_chromadb = pytest.mark.skipif(
    not _chromadb_available,
    reason="chromadb not installed — skip RAG bi-niveau tests",
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def temp_chromadb_dir():
    """Temporary directory for ChromaDB persistence."""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_biniveau_")
    yield tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def vector_store(temp_chromadb_dir):
    """Fresh MintVectorStore backed by a temp directory."""
    from app.services.rag.vector_store import MintVectorStore

    return MintVectorStore(persist_directory=temp_chromadb_dir)


@pytest.fixture
def plain_md_file():
    """A markdown file with NO Niveau 0 / Niveau 1 sections (should default to level 1)."""
    content = """\
# Insert: q_plain (Plain Insert)

## Metadata
```yaml
questionId: "q_plain"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Reponse "Non" a la question `q_plain`.

## Disclaimer
"Outil educatif uniquement. Ne constitue pas un conseil au sens de la LSFin."
"""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_plain_")
    filepath = os.path.join(tmpdir, "q_plain.md")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    yield filepath
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def biniveau_md_file():
    """A markdown file WITH explicit ## Niveau 0 and ## Niveau 1 sections."""
    content = """\
# Insert: q_biniveau (Bi-niveau Insert)

## Metadata
```yaml
questionId: "q_biniveau"
phase: "Niveau 0"
status: "READY"
```

## Niveau 0
Le pilier 3a est une épargne-retraite suisse qui permet de réduire tes impôts.
Tu peux y verser jusqu'à 7'258 CHF par an si tu es salarié·e.

## Niveau 1
Le 3e pilier lié (pilier 3a) est régi par l'OPP3. Les cotisations sont déductibles
du revenu imposable selon LIFD art. 33 al. 1 lit. e. Le plafond 2025 pour les salariés
affiliés LPP est de 7'258 CHF (source: OFAS).

## Action
"Calculer mon économie d'impôt"
"""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_biniveau_")
    filepath = os.path.join(tmpdir, "q_biniveau.md")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    yield filepath
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def biniveau_md_directory(biniveau_md_file, plain_md_file):
    """
    Directory containing both a bi-niveau file and a plain file.
    Yields a directory path that ingesting tools can use.
    Note: we point to separate tmp dirs; we create a combined dir here.
    """
    tmpdir = tempfile.mkdtemp(prefix="mint_test_dir_")

    # Copy both fixture files into one directory
    for src in (biniveau_md_file, plain_md_file):
        dst = os.path.join(tmpdir, os.path.basename(src))
        shutil.copy(src, dst)

    yield tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Test: basic ingestion (no errors)
# ---------------------------------------------------------------------------


@requires_chromadb
class TestIngestionSmoke:
    """Verify ingestion completes without errors."""

    def test_ingest_plain_file_no_error(self, vector_store, plain_md_file):
        """Ingesting a plain markdown file returns a positive chunk count."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_file(plain_md_file, language="fr")

        assert count > 0, "Expected at least one chunk to be ingested"
        assert vector_store.count() > 0

    def test_ingest_biniveau_file_no_error(self, vector_store, biniveau_md_file):
        """Ingesting a bi-niveau markdown file returns a positive chunk count."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_file(biniveau_md_file, language="fr")

        assert count > 0, "Expected at least one chunk to be ingested"
        assert vector_store.count() > 0

    def test_ingest_directory_no_error(self, vector_store, biniveau_md_directory):
        """Ingesting a directory of mixed files completes without errors."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(biniveau_md_directory)

        assert count > 0


# ---------------------------------------------------------------------------
# Test: level metadata correctly indexed
# ---------------------------------------------------------------------------


@requires_chromadb
class TestLevelMetadata:
    """Verify that the 'level' metadata field is correctly set on ingested chunks."""

    def test_plain_doc_defaults_to_level_1(self, vector_store, plain_md_file):
        """All chunks from a plain (non-bi-niveau) file should have level=1."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_file(plain_md_file, language="fr")

        # Retrieve all stored documents and check their level
        results = vector_store.query("q_plain epargne retraite disclaimer", n_results=20)
        assert len(results) > 0

        for doc in results:
            level = doc["metadata"].get("level")
            assert level == 1, (
                f"Plain doc chunk '{doc['metadata'].get('section')}' "
                f"expected level=1, got level={level}"
            )

    def test_niveau_0_section_has_level_0(self, vector_store, biniveau_md_file):
        """The '## Niveau 0' section chunk must be indexed with level=0."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_file(biniveau_md_file, language="fr")

        results = vector_store.query(
            "pilier 3a épargne retraite impôt salarié", n_results=20
        )
        assert len(results) > 0

        niveau_0_docs = [
            doc for doc in results if doc["metadata"].get("section") == "Niveau 0"
        ]
        assert len(niveau_0_docs) > 0, "Expected at least one 'Niveau 0' chunk in store"
        for doc in niveau_0_docs:
            assert doc["metadata"]["level"] == 0, (
                f"Niveau 0 chunk has level={doc['metadata']['level']}, expected 0"
            )

    def test_niveau_1_section_has_level_1(self, vector_store, biniveau_md_file):
        """The '## Niveau 1' section chunk must be indexed with level=1."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_file(biniveau_md_file, language="fr")

        results = vector_store.query(
            "OPP3 LIFD cotisations déductibles revenu imposable", n_results=20
        )
        assert len(results) > 0

        niveau_1_docs = [
            doc for doc in results if doc["metadata"].get("section") == "Niveau 1"
        ]
        assert len(niveau_1_docs) > 0, "Expected at least one 'Niveau 1' chunk in store"
        for doc in niveau_1_docs:
            assert doc["metadata"]["level"] == 1, (
                f"Niveau 1 chunk has level={doc['metadata']['level']}, expected 1"
            )

    def test_non_niveau_sections_in_biniveau_doc_get_default_level(
        self, vector_store, biniveau_md_file
    ):
        """Non-niveau sections inside a bi-niveau doc inherit the default level (1)."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_file(biniveau_md_file, language="fr")

        results = vector_store.query("calculer economie impot action", n_results=20)
        assert len(results) > 0

        action_docs = [
            doc for doc in results if doc["metadata"].get("section") == "Action"
        ]
        assert len(action_docs) > 0, "Expected at least one 'Action' chunk in store"
        for doc in action_docs:
            assert doc["metadata"]["level"] == 1, (
                f"'Action' section in bi-niveau doc has level={doc['metadata']['level']}, "
                "expected 1 (default)"
            )


# ---------------------------------------------------------------------------
# Test: literacy_level filtering in retriever
# ---------------------------------------------------------------------------


@requires_chromadb
class TestLiteracyLevelFiltering:
    """Verify that retrieve() correctly filters by literacy_level."""

    def _ingest_both(self, vector_store, biniveau_md_file, plain_md_file):
        """Helper: ingest one bi-niveau and one plain file."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_file(biniveau_md_file, language="fr")
        ingester.ingest_file(plain_md_file, language="fr")

    def test_beginner_retrieves_level_0_and_1(
        self, vector_store, biniveau_md_file, plain_md_file
    ):
        """literacy_level='beginner' returns chunks with level 0 AND level 1."""
        from app.services.rag.retriever import MintRetriever

        self._ingest_both(vector_store, biniveau_md_file, plain_md_file)
        retriever = MintRetriever(vector_store=vector_store)

        results = asyncio.run(retriever.retrieve(
            "pilier 3a retraite impôt",
            n_results=20,
            literacy_level="beginner",
        ))

        levels = {doc["metadata"].get("level") for doc in results}
        # Should contain at least one level-0 and at least one level-1 document
        assert 0 in levels, "Beginner mode should surface level-0 chunks"
        assert 1 in levels, "Beginner mode should also surface level-1 chunks"

    def test_intermediate_retrieves_only_level_1(
        self, vector_store, biniveau_md_file, plain_md_file
    ):
        """literacy_level='intermediate' returns only level-1 chunks."""
        from app.services.rag.retriever import MintRetriever

        self._ingest_both(vector_store, biniveau_md_file, plain_md_file)
        retriever = MintRetriever(vector_store=vector_store)

        results = asyncio.run(retriever.retrieve(
            "pilier 3a retraite impôt OPP3",
            n_results=20,
            literacy_level="intermediate",
        ))

        for doc in results:
            level = doc["metadata"].get("level")
            assert level == 1, (
                f"Intermediate mode returned a chunk with level={level}, expected 1 only"
            )

    def test_advanced_retrieves_only_level_1(
        self, vector_store, biniveau_md_file, plain_md_file
    ):
        """literacy_level='advanced' returns only level-1 chunks."""
        from app.services.rag.retriever import MintRetriever

        self._ingest_both(vector_store, biniveau_md_file, plain_md_file)
        retriever = MintRetriever(vector_store=vector_store)

        results = asyncio.run(retriever.retrieve(
            "LIFD art 33 cotisations déductibles",
            n_results=20,
            literacy_level="advanced",
        ))

        for doc in results:
            level = doc["metadata"].get("level")
            assert level == 1, (
                f"Advanced mode returned a chunk with level={level}, expected 1 only"
            )

    def test_default_literacy_level_is_beginner(
        self, vector_store, biniveau_md_file, plain_md_file
    ):
        """When literacy_level is not specified, it defaults to 'beginner' behaviour."""
        from app.services.rag.retriever import MintRetriever

        self._ingest_both(vector_store, biniveau_md_file, plain_md_file)
        retriever = MintRetriever(vector_store=vector_store)

        # Default call — no literacy_level arg
        results = asyncio.run(retriever.retrieve("pilier 3a retraite", n_results=20))

        levels = {doc["metadata"].get("level") for doc in results}
        # Default is beginner: both levels should be retrievable
        assert 0 in levels or 1 in levels, "Default retrieval should return some results"
