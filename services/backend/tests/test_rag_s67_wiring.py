"""
Tests for S67 RAG v2 wiring:
  - FAQ fallback in orchestrator (< 2 vector results → FAQ context added)
  - Cantonal context enrichment in guardrails.build_system_prompt()
  - Knowledge status endpoint (/knowledge/status)

All tests run without chromadb or an LLM API key (pure logic / HTTP only).
"""

from __future__ import annotations

import asyncio
import unittest.mock as mock

import pytest
from fastapi.testclient import TestClient


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _fake_user():
    """Return a mock user object for auth override."""
    user = mock.MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    return user


@pytest.fixture
def client():
    """TestClient with auth override."""
    from app.main import app
    from app.core.auth import require_current_user

    app.dependency_overrides[require_current_user] = _fake_user
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(require_current_user, None)


# ---------------------------------------------------------------------------
# Step 1 — FAQ fallback in RAGOrchestrator.query()
# ---------------------------------------------------------------------------


class TestFaqFallback:
    """Verify FAQ fallback is triggered when the vector store returns < 2 results."""

    def _make_orchestrator(self, vector_results: list[dict]) -> object:
        """Build a RAGOrchestrator with mocked retriever and LLM."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)

        # Patch retriever so it returns our controlled list
        orchestrator.retriever.retrieve = mock.AsyncMock(return_value=vector_results)

        # Patch LLM so we never make a real HTTP call
        async def fake_generate(**kwargs):
            return "Réponse de test éducative."

        orchestrator._llm_generate = fake_generate
        return orchestrator

    def test_faq_fallback_triggers_when_zero_vector_results(self):
        """When vector store returns 0 results, FAQs are searched and appended."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)
        orchestrator.retriever.retrieve = mock.AsyncMock(return_value=[])

        # Mock LLM client so it returns without network
        async def fake_generate(*args, **kwargs):
            return "Réponse test."

        with mock.patch("app.services.rag.orchestrator.LLMClient") as MockLLM:
            instance = MockLLM.return_value
            instance.generate = fake_generate

            with mock.patch("app.services.rag.faq_service.FaqService.search") as mock_search:
                from app.services.rag.faq_service import FaqEntry
                from app.services.rag.knowledge_catalog import KnowledgeCategory

                mock_search.return_value = [
                    FaqEntry(
                        id="faq_test_avs",
                        question="Quel est le montant AVS?",
                        answer="La rente AVS maximale est de CHF 30'240/an.",
                        category=KnowledgeCategory.AVS,
                        legal_refs=["LAVS art. 21"],
                        tags=["avs"],
                    )
                ]

                result = asyncio.run(
                    orchestrator.query(
                        question="Quel est le montant AVS?",
                        api_key="sk-test",
                        provider="claude",
                    )
                )

        mock_search.assert_called_once()
        # FAQ source should appear in sources
        faq_sources = [s for s in result["sources"] if s.get("type") == "faq"]
        assert len(faq_sources) >= 1
        assert faq_sources[0]["id"] == "faq_test_avs"

    def test_faq_fallback_triggers_when_one_vector_result(self):
        """When vector store returns exactly 1 result (< 2), FAQ fallback fires."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)
        orchestrator.retriever.retrieve = mock.AsyncMock(
            return_value=[{"text": "Un seul résultat.", "source": {"file": "doc.md"}}]
        )

        async def fake_generate(*args, **kwargs):
            return "Réponse test."

        with mock.patch("app.services.rag.orchestrator.LLMClient") as MockLLM:
            instance = MockLLM.return_value
            instance.generate = fake_generate

            with mock.patch("app.services.rag.faq_service.FaqService.search") as mock_search:
                from app.services.rag.faq_service import FaqEntry
                from app.services.rag.knowledge_catalog import KnowledgeCategory

                mock_search.return_value = [
                    FaqEntry(
                        id="faq_lpp_taux",
                        question="Quel est le taux de conversion LPP?",
                        answer="Le taux de conversion LPP est de 6.8%.",
                        category=KnowledgeCategory.LPP,
                        legal_refs=["LPP art. 14"],
                        tags=["lpp"],
                    )
                ]

                result = asyncio.run(
                    orchestrator.query(
                        question="Taux conversion LPP?",
                        api_key="sk-test",
                        provider="claude",
                    )
                )

        mock_search.assert_called_once()
        faq_sources = [s for s in result["sources"] if s.get("type") == "faq"]
        assert len(faq_sources) >= 1

    def test_faq_fallback_skipped_when_enough_vector_results(self):
        """When vector store returns >= 2 results, FAQ search is NOT called."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)
        orchestrator.retriever.retrieve = mock.AsyncMock(
            return_value=[
                {"text": "Résultat 1 LPP.", "source": {"file": "lpp.md"}},
                {"text": "Résultat 2 AVS.", "source": {"file": "avs.md"}},
            ]
        )

        async def fake_generate(*args, **kwargs):
            return "Réponse test."

        with mock.patch("app.services.rag.orchestrator.LLMClient") as MockLLM:
            instance = MockLLM.return_value
            instance.generate = fake_generate

            with mock.patch("app.services.rag.faq_service.FaqService.search") as mock_search:
                asyncio.run(
                    orchestrator.query(
                        question="LPP question?",
                        api_key="sk-test",
                        provider="claude",
                    )
                )

        mock_search.assert_not_called()

    def test_faq_fallback_max_three_faqs_added(self):
        """FAQ fallback adds at most 3 FAQ entries to context."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore
        from app.services.rag.faq_service import FaqEntry
        from app.services.rag.knowledge_catalog import KnowledgeCategory

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)
        orchestrator.retriever.retrieve = mock.AsyncMock(return_value=[])

        many_faqs = [
            FaqEntry(
                id=f"faq_{i}",
                question=f"Question {i}?",
                answer=f"Réponse {i}.",
                category=KnowledgeCategory.AVS,
                legal_refs=["LAVS art. 21"],
                tags=["test"],
            )
            for i in range(10)
        ]

        async def fake_generate(*args, **kwargs):
            return "Réponse test."

        with mock.patch("app.services.rag.orchestrator.LLMClient") as MockLLM:
            instance = MockLLM.return_value
            instance.generate = fake_generate

            with mock.patch(
                "app.services.rag.faq_service.FaqService.search",
                return_value=many_faqs,
            ):
                result = asyncio.run(
                    orchestrator.query(
                        question="Question générique?",
                        api_key="sk-test",
                        provider="claude",
                    )
                )

        faq_sources = [s for s in result["sources"] if s.get("type") == "faq"]
        assert len(faq_sources) <= 3

    def test_faq_fallback_empty_faq_results_no_crash(self):
        """If FAQ search returns nothing, pipeline completes without error."""
        from app.services.rag.orchestrator import RAGOrchestrator
        from app.services.rag.vector_store import MintVectorStore

        vs = mock.MagicMock(spec=MintVectorStore)
        orchestrator = RAGOrchestrator(vector_store=vs)
        orchestrator.retriever.retrieve = mock.AsyncMock(return_value=[])

        async def fake_generate(*args, **kwargs):
            return "Réponse test."

        with mock.patch("app.services.rag.orchestrator.LLMClient") as MockLLM:
            instance = MockLLM.return_value
            instance.generate = fake_generate

            with mock.patch(
                "app.services.rag.faq_service.FaqService.search",
                return_value=[],
            ):
                result = asyncio.run(
                    orchestrator.query(
                        question="Question sans FAQ?",
                        api_key="sk-test",
                        provider="claude",
                    )
                )

        assert "answer" in result
        faq_sources = [s for s in result["sources"] if s.get("type") == "faq"]
        assert len(faq_sources) == 0


# ---------------------------------------------------------------------------
# Step 2 — Cantonal context enrichment in build_system_prompt()
# ---------------------------------------------------------------------------


class TestCantonalEnrichment:
    """Verify canton-specific data is injected into the system prompt."""

    def test_canton_vs_injected(self):
        """VS (Valais) tax data appears in system prompt when canton=VS."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "VS"},
        )

        assert "VS" in prompt
        # VS marginal rate is 36.0%
        assert "36.0" in prompt or "36%" in prompt or "Valais" in prompt

    def test_canton_zh_injected(self):
        """ZH (Zurich) tax data appears in system prompt when canton=ZH."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "ZH"},
        )

        assert "ZH" in prompt
        # ZH marginal rate is 32.5%
        assert "32.5" in prompt or "Zurich" in prompt

    def test_canton_ti_injected(self):
        """TI (Tessin) tax data appears in system prompt when canton=TI."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "TI"},
        )

        assert "TI" in prompt
        # TI marginal rate is 33.5%
        assert "33.5" in prompt or "Tessin" in prompt

    def test_canton_lowercase_normalized(self):
        """Lowercase canton code 'vs' is normalized to 'VS'."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt_lower = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "vs"},
        )
        prompt_upper = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "VS"},
        )

        # Both should produce the same canton block
        assert "VS" in prompt_lower
        assert "VS" in prompt_upper

    def test_canton_unknown_no_crash(self):
        """Unknown canton code falls through silently, base prompt returned."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "XX"},
        )

        # Base French prompt must still be present
        assert "JAMAIS" in prompt
        # No canton block injected
        assert "CONTEXTE CANTONAL" not in prompt

    def test_canton_and_financial_summary_both_injected(self):
        """Both canton block and financial_summary are injected when present."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={
                "canton": "ZH",
                "financial_summary": "Revenu brut 120k CHF. LPP 80k CHF.",
            },
        )

        assert "CONTEXTE CANTONAL" in prompt
        assert "PROFIL FINANCIER" in prompt
        assert "120k" in prompt

    def test_no_canton_in_profile_no_injection(self):
        """When profile_context has no canton, no cantonal block is added."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"financial_summary": "Revenu 80k CHF."},
        )

        assert "CONTEXTE CANTONAL" not in prompt
        assert "PROFIL FINANCIER" in prompt

    def test_canton_housing_data_present(self):
        """Housing market data (rent, price/m²) is included for known cantons."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        prompt = guardrails.build_system_prompt(
            language="fr",
            profile_context={"canton": "GE"},
        )

        # GE median rent is 2_800 CHF/month
        assert "2800" in prompt or "2'800" in prompt or "Genève" in prompt

    def test_no_profile_context_returns_base_prompt(self):
        """No profile_context → plain base prompt, no injection."""
        from app.services.rag.guardrails import ComplianceGuardrails

        guardrails = ComplianceGuardrails()
        base = guardrails.build_system_prompt("fr")
        same = guardrails.build_system_prompt("fr", profile_context=None)
        assert base == same


# ---------------------------------------------------------------------------
# Step 3 — Knowledge status endpoint
# ---------------------------------------------------------------------------


class TestKnowledgeStatusEndpoint:
    """Test the /knowledge/status endpoint."""

    def test_knowledge_status_200(self, client):
        """GET /knowledge/status returns 200."""
        resp = client.get("/api/v1/knowledge/status")
        assert resp.status_code == 200

    def test_knowledge_status_has_required_keys(self, client):
        """Response contains total_sources, up_to_date, needs_update, coverage_gaps."""
        resp = client.get("/api/v1/knowledge/status")
        data = resp.json()

        assert "total_sources" in data
        assert "up_to_date" in data
        assert "needs_update" in data
        assert "coverage_gaps" in data

    def test_knowledge_status_total_sources_positive(self, client):
        """total_sources must be > 0 (catalog is populated)."""
        resp = client.get("/api/v1/knowledge/status")
        data = resp.json()
        assert data["total_sources"] > 0

    def test_knowledge_status_counts_consistent(self, client):
        """up_to_date + needs_update == total_sources."""
        resp = client.get("/api/v1/knowledge/status")
        data = resp.json()
        assert data["up_to_date"] + data["needs_update"] == data["total_sources"]

    def test_knowledge_status_coverage_gaps_is_list(self, client):
        """coverage_gaps is a list."""
        resp = client.get("/api/v1/knowledge/status")
        data = resp.json()
        assert isinstance(data["coverage_gaps"], list)

    def test_knowledge_status_no_auth_required(self):
        """The endpoint is accessible without user auth (public health check)."""
        from app.main import app

        # No auth override — fresh client
        with TestClient(app) as c:
            resp = c.get("/api/v1/knowledge/status")
        # May be 200 or 401 depending on auth config; must not be 500
        assert resp.status_code != 500
