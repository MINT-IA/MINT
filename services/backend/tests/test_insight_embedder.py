"""Tests for insight_embedder — RAG memory embedding logic.

Tests the pure logic (metadata building, validation) without requiring
pgvector or OpenAI API. Integration tests would need a real database.
"""

import pytest
import json
from datetime import datetime, timezone

from app.services.rag.insight_embedder import (
    _build_metadata,
    embed_insight,
    remove_insight,
)


class TestBuildMetadata:
    """Test metadata construction for pgvector storage."""

    def test_basic_metadata(self):
        result = _build_metadata("lpp", "fact", None, None)
        data = json.loads(result)
        assert data["topic"] == "lpp"
        assert data["insight_type"] == "fact"
        assert data["is_memory"] is True

    def test_metadata_with_timestamp(self):
        ts = datetime(2026, 3, 28, 12, 0, 0, tzinfo=timezone.utc)
        result = _build_metadata("retraite", "goal", None, ts)
        data = json.loads(result)
        assert "2026-03-28" in data["created_at"]

    def test_metadata_filters_pii(self):
        """Only safe keys from metadata are stored."""
        meta = {
            "templateId": "housing_purchase",
            "stepCount": 4,
            "documentType": "lpp_certificate",
            "salary": 120000,  # PII — should be filtered
            "employer": "ACME Corp",  # PII — should be filtered
        }
        result = _build_metadata("3a", "decision", meta, None)
        data = json.loads(result)
        assert data["templateId"] == "housing_purchase"
        assert data["stepCount"] == 4
        assert data["documentType"] == "lpp_certificate"
        assert "salary" not in data
        assert "employer" not in data

    def test_metadata_empty_when_no_extras(self):
        result = _build_metadata("budget", "concern", {}, None)
        data = json.loads(result)
        assert data["topic"] == "budget"
        assert "salary" not in data


class TestEmbedInsightWithoutDB:
    """Test embed_insight behavior when no DATABASE_URL is set."""

    @pytest.mark.asyncio
    async def test_no_database_url_returns_false(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        result = await embed_insight(
            insight_id="test-1",
            topic="lpp",
            summary="Avoir LPP de ~350k confirmé par certificat",
            insight_type="fact",
        )
        assert result is False

    @pytest.mark.asyncio
    async def test_no_openai_key_returns_false(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        result = await embed_insight(
            insight_id="test-2",
            topic="retraite",
            summary="Taux de remplacement ~65%, gap mensuel ~2500 CHF",
            insight_type="fact",
        )
        assert result is False


class TestRemoveInsightWithoutDB:
    """Test remove_insight behavior when no DATABASE_URL is set."""

    @pytest.mark.asyncio
    async def test_no_database_returns_false(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        result = await remove_insight("nonexistent-id")
        assert result is False
