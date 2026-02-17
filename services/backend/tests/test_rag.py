"""
Tests for the RAG (Retrieval-Augmented Generation) module.

Tests vector store, ingester, guardrails, and FastAPI endpoints.
"""

import importlib
import os
import tempfile
import shutil

import pytest
from fastapi.testclient import TestClient

from app.main import app

_chromadb_available = importlib.util.find_spec("chromadb") is not None
requires_chromadb = pytest.mark.skipif(
    not _chromadb_available,
    reason="chromadb not installed — skip RAG vector tests",
)


# --------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------

def _fake_user():
    """Return a mock user object for auth override."""
    from unittest.mock import MagicMock
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    return user


@pytest.fixture
def client():
    """Test client for FastAPI app with auth override."""
    from app.core.auth import require_current_user
    app.dependency_overrides[require_current_user] = _fake_user
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(require_current_user, None)


@pytest.fixture
def temp_chromadb_dir():
    """Create a temporary directory for ChromaDB persistence."""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_chromadb_")
    yield tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def vector_store(temp_chromadb_dir):
    """Create a fresh MintVectorStore for testing."""
    from app.services.rag.vector_store import MintVectorStore

    store = MintVectorStore(persist_directory=temp_chromadb_dir)
    return store


@pytest.fixture
def sample_documents():
    """Sample documents for testing."""
    return [
        {
            "id": "doc_3a_fr_full",
            "text": (
                "Le pilier 3a est un instrument d'epargne-retraite en Suisse. "
                "Il permet de deduire les cotisations du revenu imposable. "
                "Le plafond annuel est de CHF 7056 pour les salaries."
            ),
            "metadata": {
                "source": "q_has_3a.md",
                "language": "fr",
                "category": "education_insert",
                "question_id": "q_has_3a",
                "title": "Insert: q_has_3a (Pilier 3a ?)",
                "section": "full",
            },
        },
        {
            "id": "doc_3a_de_full",
            "text": (
                "Die Saeule 3a ist ein Alterssparkonto in der Schweiz. "
                "Beitraege koennen vom steuerbaren Einkommen abgezogen werden. "
                "Die jaehrliche Obergrenze betraegt CHF 7056 fuer Angestellte."
            ),
            "metadata": {
                "source": "q_has_3a_de.md",
                "language": "de",
                "category": "education_insert",
                "question_id": "q_has_3a",
                "title": "Insert: q_has_3a (Saeule 3a?)",
                "section": "full",
            },
        },
        {
            "id": "doc_emergency_fr_full",
            "text": (
                "Le fonds d'urgence est la priorite numero 1. "
                "Il est recommande de constituer 3 a 6 mois de charges fixes. "
                "Cela protege contre les imprévus financiers."
            ),
            "metadata": {
                "source": "q_emergency_fund.md",
                "language": "fr",
                "category": "education_insert",
                "question_id": "q_emergency_fund",
                "title": "Insert: q_emergency_fund (Fonds d'urgence)",
                "section": "full",
            },
        },
    ]


@pytest.fixture
def sample_md_file():
    """Create a sample markdown file for ingestion testing."""
    content = """# Insert: q_test (Test Insert)

## Metadata
```yaml
questionId: "q_test"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Reponse "Non" a la question `q_test`.

## Inputs
- Revenu imposable
- Canton

## Outputs
- Estimation de l'economie fiscale.

## Disclaimer
"L'economie fiscale est une estimation."

## Action
"Voir mon potentiel d'economie"
"""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_md_")
    filepath = os.path.join(tmpdir, "q_test.md")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    yield filepath
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def sample_md_directory():
    """Create a directory with sample markdown files for ingestion."""
    tmpdir = tempfile.mkdtemp(prefix="mint_test_md_dir_")

    # French file
    fr_content = """# Insert: q_pilier3a (Pilier 3a)

## Metadata
```yaml
questionId: "q_pilier3a"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Reponse "Non" a la question `q_pilier3a`.

## Inputs
- Revenu imposable

## Outputs
- Potentiel d'economie d'impot.

## Disclaimer
"L'economie fiscale est une estimation."
"""
    with open(os.path.join(tmpdir, "q_pilier3a.md"), "w", encoding="utf-8") as f:
        f.write(fr_content)

    # German file
    de_content = """# Insert: q_pilier3a (Saeule 3a)

## Metadata
```yaml
questionId: "q_pilier3a"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Antwort "Nein" bei der Frage `q_pilier3a`.

## Inputs
- Steuerbares Einkommen

## Outputs
- Steuerersparnispotenzial.

## Disclaimer
"Die Steuerersparnis ist eine Schaetzung."
"""
    with open(os.path.join(tmpdir, "q_pilier3a_de.md"), "w", encoding="utf-8") as f:
        f.write(de_content)

    # README should be skipped
    with open(os.path.join(tmpdir, "README.md"), "w", encoding="utf-8") as f:
        f.write("# Education Inserts\nThis directory contains...")

    yield tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)


# --------------------------------------------------------------------------
# Vector Store Tests
# --------------------------------------------------------------------------


@requires_chromadb
class TestVectorStore:
    """Tests for MintVectorStore."""

    def test_vector_store_add_and_query(self, vector_store, sample_documents):
        """Add documents and verify retrieval works."""
        count = vector_store.add_documents(sample_documents)
        assert count == 3

        results = vector_store.query("pilier 3a epargne retraite", n_results=2)
        assert len(results) > 0
        assert results[0]["id"] is not None
        assert results[0]["text"] is not None
        assert results[0]["metadata"] is not None
        assert "distance" in results[0]

    def test_vector_store_count(self, vector_store, sample_documents):
        """Verify document count."""
        assert vector_store.count() == 0
        vector_store.add_documents(sample_documents)
        assert vector_store.count() == 3

    def test_vector_store_query_with_language_filter(self, vector_store, sample_documents):
        """Verify language filtering works."""
        vector_store.add_documents(sample_documents)

        # Query with French filter
        fr_results = vector_store.query("epargne retraite", n_results=5, language="fr")
        for r in fr_results:
            assert r["metadata"].get("language") == "fr"

        # Query with German filter
        de_results = vector_store.query("Altersvorsorge", n_results=5, language="de")
        for r in de_results:
            assert r["metadata"].get("language") == "de"

    def test_vector_store_empty_query(self, vector_store):
        """Query an empty store returns empty results."""
        results = vector_store.query("test query")
        assert results == []

    def test_vector_store_upsert(self, vector_store):
        """Verify that adding a doc with same ID updates it."""
        docs = [
            {"id": "doc1", "text": "Original text", "metadata": {"version": "1"}},
        ]
        vector_store.add_documents(docs)
        assert vector_store.count() == 1

        # Upsert with same ID
        docs_updated = [
            {"id": "doc1", "text": "Updated text", "metadata": {"version": "2"}},
        ]
        vector_store.add_documents(docs_updated)
        assert vector_store.count() == 1

        results = vector_store.query("Updated text", n_results=1)
        assert len(results) == 1
        assert results[0]["metadata"]["version"] == "2"

    def test_vector_store_skip_empty_docs(self, vector_store):
        """Documents with missing id or text are skipped."""
        docs = [
            {"id": "", "text": "some text", "metadata": {}},
            {"id": "doc1", "text": "", "metadata": {}},
            {"id": "doc2", "text": "valid text", "metadata": {}},
        ]
        count = vector_store.add_documents(docs)
        assert count == 1
        assert vector_store.count() == 1

    def test_vector_store_list_collections(self, vector_store):
        """Verify listing collections."""
        collections = vector_store.list_collections()
        assert "mint_knowledge" in collections

    def test_vector_store_reset(self, vector_store, sample_documents):
        """Verify reset clears all documents."""
        vector_store.add_documents(sample_documents)
        assert vector_store.count() == 3

        vector_store.reset()
        assert vector_store.count() == 0


# --------------------------------------------------------------------------
# Markdown Ingester Tests
# --------------------------------------------------------------------------


@requires_chromadb
class TestMarkdownIngester:
    """Tests for MarkdownIngester."""

    def test_ingest_single_file(self, vector_store, sample_md_file):
        """Ingest a single markdown file and verify chunks are created."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_file(sample_md_file, language="fr")

        # Should create: full + Trigger + Inputs + Outputs + Disclaimer + Action = 6 chunks
        assert count >= 4
        assert vector_store.count() >= 4

    def test_ingest_directory(self, vector_store, sample_md_directory):
        """Ingest a directory of markdown files."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(sample_md_directory)

        # Should have chunks from both French and German files, but not README
        assert count > 0
        assert vector_store.count() > 0

    def test_ingest_directory_skips_readme(self, vector_store, sample_md_directory):
        """README files should be skipped during ingestion."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        ingester.ingest_directory(sample_md_directory)

        # Query for README-specific content
        results = vector_store.query("This directory contains", n_results=10)
        for r in results:
            assert "README" not in r.get("metadata", {}).get("source", "")

    def test_ingest_nonexistent_directory(self, vector_store):
        """Ingesting from nonexistent directory returns 0."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory("/nonexistent/path")
        assert count == 0

    def test_ingest_nonexistent_file(self, vector_store):
        """Ingesting a nonexistent file returns 0."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_file("/nonexistent/file.md")
        assert count == 0

    def test_language_detection_from_filename(self, vector_store):
        """Verify language is auto-detected from filename suffix."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)

        assert ingester._detect_language("q_has_3a.md") == "fr"
        assert ingester._detect_language("q_has_3a_de.md") == "de"
        assert ingester._detect_language("q_has_3a_it.md") == "it"
        assert ingester._detect_language("q_has_3a_en.md") == "en"

    def test_metadata_extraction(self, vector_store):
        """Verify YAML metadata extraction from markdown content."""
        from app.services.rag.ingester import MarkdownIngester

        ingester = MarkdownIngester(vector_store=vector_store)

        content = '''# Test
## Metadata
```yaml
questionId: "q_test"
phase: "Niveau 1"
status: "READY"
```
## Trigger
- Something
'''
        metadata = ingester._extract_metadata(content)
        assert metadata["questionId"] == "q_test"
        assert metadata["phase"] == "Niveau 1"
        assert metadata["status"] == "READY"


# --------------------------------------------------------------------------
# Guardrails Tests
# --------------------------------------------------------------------------


class TestComplianceGuardrails:
    """Tests for ComplianceGuardrails."""

    def test_guardrails_banned_terms_french(self):
        """Verify banned terms in French are caught and replaced."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "Ce rendement est garanti a 5% par an.", language="fr"
        )

        assert len(result["warnings"]) > 0
        assert "garanti" not in result["text"].lower()
        assert "potentiel" in result["text"].lower()

    def test_guardrails_banned_terms_german(self):
        """Verify banned terms in German are caught."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "Diese Rendite ist garantiert.", language="de"
        )

        assert len(result["warnings"]) > 0

    def test_guardrails_banned_terms_english(self):
        """Verify banned terms in English are caught."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "This return is guaranteed and risk-free.", language="en"
        )

        assert len(result["warnings"]) >= 2  # "guaranteed" and "risk-free"

    def test_guardrails_disclaimer_tax(self):
        """Verify tax-related disclaimers are added."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "Votre deduction fiscale pourrait etre de CHF 2000.", language="fr"
        )

        assert len(result["disclaimers_added"]) >= 2  # general + tax
        # Check that tax disclaimer is present
        disclaimers_text = " ".join(result["disclaimers_added"])
        assert "fiscal" in disclaimers_text.lower() or "estimat" in disclaimers_text.lower()

    def test_guardrails_disclaimer_pension(self):
        """Verify pension-related disclaimers are added."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "Votre rente AVS sera calculee selon vos cotisations.", language="fr"
        )

        assert len(result["disclaimers_added"]) >= 2  # general + investment/pension

    def test_guardrails_clean_text_gets_general_disclaimer(self):
        """Clean text still gets the general educational disclaimer."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        result = guardrails.filter_response(
            "Voici quelques informations utiles.", language="fr"
        )

        assert len(result["warnings"]) == 0
        assert len(result["disclaimers_added"]) >= 1  # At least general
        assert "educatif" in result["disclaimers_added"][0].lower() or \
               "éducatif" in result["disclaimers_added"][0].lower()

    def test_guardrails_system_prompt_fr(self):
        """Verify French system prompt contains key rules."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt("fr")

        assert "JAMAIS" in prompt
        assert "produit financier" in prompt
        assert "garanti" in prompt
        assert "sources" in prompt

    def test_guardrails_system_prompt_de(self):
        """Verify German system prompt exists."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt("de")

        assert "NIEMALS" in prompt
        assert "Finanzprodukt" in prompt

    def test_guardrails_system_prompt_fallback(self):
        """Unknown language falls back to French."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt("xx")

        # Should return French prompt as fallback
        assert "JAMAIS" in prompt


# --------------------------------------------------------------------------
# LLM Client Tests
# --------------------------------------------------------------------------


class TestLLMClient:
    """Tests for LLMClient initialization and validation."""

    def test_llm_client_valid_providers(self):
        """Verify all supported providers can be initialized."""
        from app.services.rag.llm_client import LLMClient

        for provider in ["claude", "openai", "mistral"]:
            client = LLMClient(provider=provider, api_key="test-key-123")
            assert client.provider == provider

    def test_llm_client_default_models(self):
        """Verify default models are set correctly."""
        from app.services.rag.llm_client import LLMClient, DEFAULT_MODELS

        for provider, expected_model in DEFAULT_MODELS.items():
            client = LLMClient(provider=provider, api_key="test-key-123")
            assert client.model == expected_model

    def test_llm_client_custom_model(self):
        """Verify custom model override works."""
        from app.services.rag.llm_client import LLMClient

        client = LLMClient(
            provider="openai", api_key="test-key", model="gpt-4-turbo"
        )
        assert client.model == "gpt-4-turbo"

    def test_llm_client_unsupported_provider(self):
        """Verify unsupported provider raises ValueError."""
        from app.services.rag.llm_client import LLMClient

        with pytest.raises(ValueError, match="Unsupported provider"):
            LLMClient(provider="invalid", api_key="test-key")

    def test_llm_client_empty_api_key(self):
        """Verify empty API key raises ValueError."""
        from app.services.rag.llm_client import LLMClient

        with pytest.raises(ValueError, match="API key must not be empty"):
            LLMClient(provider="claude", api_key="")

        with pytest.raises(ValueError, match="API key must not be empty"):
            LLMClient(provider="claude", api_key="   ")


# --------------------------------------------------------------------------
# Retriever Tests
# --------------------------------------------------------------------------


@requires_chromadb
class TestRetriever:
    """Tests for MintRetriever."""

    def test_retrieve_basic(self, vector_store, sample_documents):
        """Basic retrieval returns formatted results."""
        from app.services.rag.retriever import MintRetriever

        vector_store.add_documents(sample_documents)
        retriever = MintRetriever(vector_store=vector_store)

        results = retriever.retrieve("pilier 3a", n_results=2)
        assert len(results) > 0
        assert "source" in results[0]
        assert "title" in results[0]["source"]
        assert "file" in results[0]["source"]

    def test_retrieve_with_profile_context(self, vector_store, sample_documents):
        """Retrieval with profile context enriches the query."""
        from app.services.rag.retriever import MintRetriever

        vector_store.add_documents(sample_documents)
        retriever = MintRetriever(vector_store=vector_store)

        results = retriever.retrieve(
            "epargne",
            profile_context={"canton": "VD", "age": 35},
            n_results=2,
        )
        assert len(results) > 0

    def test_retrieve_empty_store(self, vector_store):
        """Retrieval from empty store returns empty list."""
        from app.services.rag.retriever import MintRetriever

        retriever = MintRetriever(vector_store=vector_store)
        results = retriever.retrieve("test query")
        assert results == []

    def test_enrich_query(self, vector_store):
        """Test query enrichment with profile context."""
        from app.services.rag.retriever import MintRetriever

        retriever = MintRetriever(vector_store=vector_store)

        enriched = retriever._enrich_query(
            "Comment optimiser mes impots?",
            {"canton": "GE", "age": 40, "employment_status": "employed"},
        )
        assert "GE" in enriched
        assert "40" in enriched
        assert "employed" in enriched
        assert "Comment optimiser mes impots?" in enriched

    def test_enrich_query_no_context(self, vector_store):
        """Query without context is returned unchanged."""
        from app.services.rag.retriever import MintRetriever

        retriever = MintRetriever(vector_store=vector_store)

        original = "My question"
        enriched = retriever._enrich_query(original, None)
        assert enriched == original


# --------------------------------------------------------------------------
# FastAPI Endpoint Tests
# --------------------------------------------------------------------------


@requires_chromadb
class TestRAGEndpoints:
    """Tests for RAG FastAPI endpoints."""

    def test_rag_status_endpoint(self, client):
        """GET /api/v1/rag/status returns valid response."""
        response = client.get("/api/v1/rag/status")
        assert response.status_code == 200

        data = response.json()
        assert "vector_store_ready" in data
        assert "documents_count" in data
        assert "collections" in data
        assert isinstance(data["vector_store_ready"], bool)
        assert isinstance(data["documents_count"], int)
        assert isinstance(data["collections"], list)

    def test_rag_query_endpoint_no_key(self, client):
        """POST /api/v1/rag/query without API key returns 422."""
        response = client.post(
            "/api/v1/rag/query",
            json={
                "question": "What is pillar 3a?",
                "provider": "claude",
                # Missing api_key
            },
        )
        assert response.status_code == 422

    def test_rag_query_endpoint_empty_key(self, client):
        """POST /api/v1/rag/query with empty API key returns 422."""
        response = client.post(
            "/api/v1/rag/query",
            json={
                "question": "What is pillar 3a?",
                "api_key": "",
                "provider": "claude",
            },
        )
        assert response.status_code == 422

    def test_rag_query_endpoint_invalid_provider(self, client):
        """POST /api/v1/rag/query with invalid provider returns 422."""
        response = client.post(
            "/api/v1/rag/query",
            json={
                "question": "What is pillar 3a?",
                "api_key": "test-key",
                "provider": "invalid_provider",
            },
        )
        assert response.status_code == 422

    def test_rag_query_endpoint_short_question(self, client):
        """POST /api/v1/rag/query with too-short question returns 422."""
        response = client.post(
            "/api/v1/rag/query",
            json={
                "question": "ab",  # min_length=3
                "api_key": "test-key",
                "provider": "claude",
            },
        )
        assert response.status_code == 422

    def test_rag_ingest_endpoint(self, client, sample_md_directory):
        """POST /api/v1/rag/ingest ingests markdown files."""
        response = client.post(
            "/api/v1/rag/ingest",
            json={
                "directory": sample_md_directory,
            },
        )
        assert response.status_code == 200

        data = response.json()
        assert "documents_ingested" in data
        assert data["documents_ingested"] > 0
        assert data["status"] == "ok"

    def test_rag_ingest_endpoint_nonexistent_dir(self, client):
        """POST /api/v1/rag/ingest with invalid directory returns 400."""
        response = client.post(
            "/api/v1/rag/ingest",
            json={
                "directory": "/nonexistent/path/to/nowhere",
            },
        )
        assert response.status_code == 400

    def test_rag_ingest_with_language(self, client, sample_md_directory):
        """POST /api/v1/rag/ingest with language override."""
        response = client.post(
            "/api/v1/rag/ingest",
            json={
                "directory": sample_md_directory,
                "language": "fr",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["documents_ingested"] > 0

    def test_rag_status_after_ingest(self, client, sample_md_directory):
        """Verify status reflects ingested documents."""
        # Ingest first
        client.post(
            "/api/v1/rag/ingest",
            json={"directory": sample_md_directory},
        )

        # Check status
        response = client.get("/api/v1/rag/status")
        assert response.status_code == 200

        data = response.json()
        assert data["vector_store_ready"] is True
        assert data["documents_count"] > 0
        assert "mint_knowledge" in data["collections"]


# --------------------------------------------------------------------------
# Orchestrator Tests (unit tests without actual LLM calls)
# --------------------------------------------------------------------------


@requires_chromadb
class TestOrchestrator:
    """Tests for RAGOrchestrator (without actual LLM API calls)."""

    def test_orchestrator_initialization(self, vector_store):
        """Verify orchestrator can be initialized."""
        from app.services.rag.orchestrator import RAGOrchestrator

        orchestrator = RAGOrchestrator(vector_store=vector_store)
        assert orchestrator.vector_store is vector_store
        assert orchestrator.retriever is not None
        assert orchestrator.guardrails is not None

    def test_orchestrator_token_estimation(self, vector_store):
        """Verify token estimation works."""
        from app.services.rag.orchestrator import RAGOrchestrator

        orchestrator = RAGOrchestrator(vector_store=vector_store)
        tokens = orchestrator._estimate_tokens(
            "system prompt",
            "question",
            ["chunk1", "chunk2"],
            "response text",
        )
        assert tokens > 0
        assert isinstance(tokens, int)


# --------------------------------------------------------------------------
# Integration: Ingest + Query (vector store only, no LLM)
# --------------------------------------------------------------------------


@requires_chromadb
class TestRAGIntegration:
    """Integration tests for the RAG pipeline (without LLM calls)."""

    def test_ingest_then_retrieve(self, vector_store, sample_md_directory):
        """Ingest markdown files, then retrieve relevant content."""
        from app.services.rag.ingester import MarkdownIngester
        from app.services.rag.retriever import MintRetriever

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(sample_md_directory)
        assert count > 0

        retriever = MintRetriever(vector_store=vector_store)
        results = retriever.retrieve("pilier 3a epargne", n_results=3)
        assert len(results) > 0

        # Check that source info is present
        for r in results:
            assert "source" in r
            assert "file" in r["source"]

    def test_ingest_real_education_inserts(self, vector_store):
        """Ingest actual education insert files if they exist."""
        from app.services.rag.ingester import MarkdownIngester

        # Try the actual education inserts directory
        inserts_dir = os.path.normpath(
            os.path.join(
                os.path.dirname(__file__),
                "..", "..", "..", "education", "inserts",
            )
        )

        if not os.path.isdir(inserts_dir):
            pytest.skip("Education inserts directory not found")

        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(inserts_dir)
        assert count > 0

        # Verify we can retrieve something meaningful
        from app.services.rag.retriever import MintRetriever

        retriever = MintRetriever(vector_store=vector_store)
        results = retriever.retrieve("pilier 3a", n_results=3, language="fr")
        assert len(results) > 0
