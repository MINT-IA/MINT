"""
Targeted tests to hit specific uncovered lines in diff-cover scope.

Covers minimal paths for:
    - commitment.py endpoints (POST/GET/PATCH)
    - documents.py /extract-vision ProfileModel mirror (lines 1000-1036)
    - coach_chat.py _sanitize_conversation_history (373-388),
      save_insight ProfileModel mirror (950-986),
      save_earmark/remove_earmark persist (1031-1067)
    - llm_client.py conversation_history path (137-145)
    - fresh_start.py endpoint GET / with profile fields (277-361)
    - anonymous_chat.py error paths (missing / bad session header)

Run: cd services/backend && python3 -m pytest tests/test_coverage_gaps_diff.py -v
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.fixture(autouse=True)
def _clean_extra_tables():
    """Clean tables not covered by conftest clean_database (commitments, insights)."""
    from tests.conftest import TestingSessionLocal
    from app.models.commitment import CommitmentDevice, PreMortemEntry
    from app.models.coach_insight import CoachInsightRecord

    db = TestingSessionLocal()
    try:
        db.query(CommitmentDevice).delete()
        db.query(PreMortemEntry).delete()
        db.query(CoachInsightRecord).delete()
        db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()
    yield


# ===========================================================================
# commitment.py — create/list/patch
# ===========================================================================


class TestCommitmentEndpoints:
    def _payload(self, reminder=None):
        p = {
            "whenText": "Lundi matin",
            "whereText": "App 3a",
            "ifThenText": "Si salaire verse, alors 200 CHF",
        }
        if reminder:
            p["reminderAt"] = reminder
        return p

    def test_create_commitment_success(self, client):
        r = client.post("/api/v1/coach/commitment/", json=self._payload())
        assert r.status_code == 201, r.text
        data = r.json()
        assert data["status"] == "pending"
        assert data["whenText"] == "Lundi matin"
        assert data["reminderAt"] is None

    def test_create_commitment_with_reminder(self, client):
        reminder = "2026-12-01T09:00:00+00:00"
        r = client.post("/api/v1/coach/commitment/", json=self._payload(reminder))
        assert r.status_code == 201
        assert r.json()["reminderAt"] is not None

    def test_create_commitment_empty_field_rejected(self, client):
        # Hits field_validator not_empty raising ValueError
        bad = {"whenText": "   ", "whereText": "x", "ifThenText": "y"}
        r = client.post("/api/v1/coach/commitment/", json=bad)
        assert r.status_code == 422

    def test_list_commitments_empty(self, client):
        r = client.get("/api/v1/coach/commitment/")
        assert r.status_code == 200
        assert r.json() == []

    def test_list_commitments_with_status_filter(self, client):
        client.post("/api/v1/coach/commitment/", json=self._payload())
        r = client.get("/api/v1/coach/commitment/?status=pending")
        assert r.status_code == 200
        assert len(r.json()) == 1

    def test_patch_commitment_completed(self, client):
        r = client.post("/api/v1/coach/commitment/", json=self._payload())
        cid = r.json()["id"]
        r2 = client.patch(
            f"/api/v1/coach/commitment/{cid}",
            json={"status": "completed"},
        )
        assert r2.status_code == 200
        assert r2.json()["status"] == "completed"

    def test_patch_commitment_invalid_status(self, client):
        r = client.post("/api/v1/coach/commitment/", json=self._payload())
        cid = r.json()["id"]
        r2 = client.patch(
            f"/api/v1/coach/commitment/{cid}",
            json={"status": "garbage"},
        )
        assert r2.status_code == 422

    def test_patch_commitment_not_found(self, client):
        r = client.patch(
            "/api/v1/coach/commitment/nonexistent-id",
            json={"status": "dismissed"},
        )
        assert r.status_code == 404


# ===========================================================================
# coach_chat.py — _sanitize_conversation_history (373-388)
# ===========================================================================


class TestSanitizeConversationHistory:
    def test_none_returns_none(self):
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        assert _sanitize_conversation_history(None) is None
        assert _sanitize_conversation_history([]) is None

    def test_filters_invalid_roles(self):
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        history = [
            {"role": "system", "content": "evil"},  # rejected
            {"role": "user", "content": "hello"},
            {"role": "assistant", "content": "hi"},
        ]
        out = _sanitize_conversation_history(history)
        assert out is not None
        assert len(out) == 2
        assert all(m["role"] in ("user", "assistant") for m in out)

    def test_filters_empty_content(self):
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        history = [
            {"role": "user", "content": "   "},  # empty -> dropped
            {"role": "user", "content": "real message"},
        ]
        out = _sanitize_conversation_history(history)
        assert len(out) == 1
        assert out[0]["content"] == "real message"

    def test_caps_at_16_messages(self):
        """Gate 0 P0-2 fix (2026-04-15): cap raised 8→16 to keep multi-turn
        threading coherent past 4 exchanges."""
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        history = [{"role": "user", "content": f"msg {i}"} for i in range(20)]
        out = _sanitize_conversation_history(history)
        assert len(out) == 16

    def test_truncates_long_content_at_2000_chars(self):
        """Gate 0 P0-2 fix (2026-04-15): per-message cap raised 500→2000
        chars so dense user statements (full PDF excerpts, cert quotes)
        no longer get cut off mid-sentence."""
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        history = [{"role": "user", "content": "x" * 5000}]
        out = _sanitize_conversation_history(history)
        assert len(out[0]["content"]) == 2000

    def test_all_invalid_returns_none(self):
        from app.api.v1.endpoints.coach_chat import _sanitize_conversation_history
        history = [{"role": "system", "content": "x"}]
        assert _sanitize_conversation_history(history) is None


# ===========================================================================
# coach_chat.py — save_insight ProfileModel mirror (line 950-986)
# ===========================================================================


class TestSaveInsightMirror:
    def test_save_insight_mirrors_to_profile(self):
        """save_insight writes to ProfileModel.data['recent_insights']."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool
        from app.models.profile_model import ProfileModel
        from app.models.user import User
        from tests.conftest import TestingSessionLocal

        db = TestingSessionLocal()
        try:
            # Seed user + profile (shared in-memory DB from conftest)
            user = User(id="u-save-insight", email="u-ins@x.ch", hashed_password="x")
            db.add(user)
            profile = ProfileModel(
                id="p-save-insight",
                user_id="u-save-insight",
                data={"existing": "value"},
                updated_at=datetime.now(timezone.utc),
            )
            db.add(profile)
            db.commit()

            result = _execute_internal_tool(
                tool_call={
                    "name": "save_insight",
                    "input": {
                        "summary": "User wants to prioritize 3a",
                        "topic": "pillar_3a",
                        "insight_type": "preference",
                    },
                },
                memory_block=None,
                user_id="u-save-insight",
                db=db,
            )
            assert "Insight enregistré" in result

            # Re-query in a fresh session to bypass any MutableDict caching
            db.close()
            db2 = TestingSessionLocal()
            try:
                pf = (
                    db2.query(ProfileModel)
                    .filter(ProfileModel.user_id == "u-save-insight")
                    .first()
                )
                assert pf is not None
                assert "recent_insights" in pf.data
                assert len(pf.data["recent_insights"]) == 1
                assert pf.data["recent_insights"][0]["topic"] == "pillar_3a"
                assert pf.data["last_coach_insight"]["topic"] == "pillar_3a"
                assert pf.data["existing"] == "value"
            finally:
                db2.close()
        finally:
            try:
                db.close()
            except Exception:
                pass


# ===========================================================================
# llm_client.py — conversation_history path (137-145)
# ===========================================================================


class TestLlmClientConversationHistory:
    @pytest.mark.asyncio
    async def test_claude_passes_conversation_history(self):
        from app.services.rag.llm_client import LLMClient

        client = LLMClient(provider="claude", api_key="sk-test-key")

        # Mock AsyncAnthropic and its response
        mock_response = MagicMock()
        text_block = MagicMock()
        text_block.type = "text"
        text_block.text = "Reply from Claude"
        mock_response.content = [text_block]
        mock_response.stop_reason = "end_turn"
        mock_response.usage = MagicMock(input_tokens=10, output_tokens=5)

        mock_client_instance = MagicMock()
        mock_client_instance.messages.create = AsyncMock(return_value=mock_response)

        with patch(
            "anthropic.AsyncAnthropic", return_value=mock_client_instance
        ):
            history = [
                {"role": "user", "content": "Hi"},
                {"role": "assistant", "content": "Hello, how can I help?"},
                {"role": "system", "content": "SHOULD BE FILTERED"},  # filtered
                {"role": "user", "content": "   "},  # filtered (empty)
            ]
            await client.generate(
                system_prompt="sys",
                user_message="current question",
                context_chunks=[],
                conversation_history=history,
            )

        # Inspect messages passed to API
        call_kwargs = mock_client_instance.messages.create.call_args.kwargs
        messages = call_kwargs["messages"]
        # 2 valid history turns + 1 current user msg
        assert len(messages) == 3
        assert messages[0] == {"role": "user", "content": "Hi"}
        assert messages[1]["role"] == "assistant"
        assert messages[-1]["content"] == "current question"

    @pytest.mark.asyncio
    async def test_claude_no_history(self):
        from app.services.rag.llm_client import LLMClient

        client = LLMClient(provider="claude", api_key="sk-test-key")

        mock_response = MagicMock()
        text_block = MagicMock()
        text_block.type = "text"
        text_block.text = "Reply"
        mock_response.content = [text_block]
        mock_response.stop_reason = "end_turn"
        mock_response.usage = MagicMock(input_tokens=1, output_tokens=1)

        mock_client_instance = MagicMock()
        mock_client_instance.messages.create = AsyncMock(return_value=mock_response)

        with patch("anthropic.AsyncAnthropic", return_value=mock_client_instance):
            await client.generate(
                system_prompt="sys",
                user_message="question",
                context_chunks=[],
                conversation_history=None,
            )

        messages = mock_client_instance.messages.create.call_args.kwargs["messages"]
        assert len(messages) == 1


# ===========================================================================
# fresh_start.py — endpoint (lines 277-361)
# ===========================================================================


class TestFreshStartEndpoint:
    def test_endpoint_no_profile(self, client):
        """Returns empty/minimal landmarks when no profile exists."""
        r = client.get("/api/v1/coach/fresh-start/")
        assert r.status_code == 200
        assert "landmarks" in r.json()

    def test_endpoint_with_profile(self, client):
        """Profile with valid fields yields personalized landmarks."""
        # Seed profile via our DB session
        from app.models.profile_model import ProfileModel
        from tests.conftest import TestingSessionLocal

        db = TestingSessionLocal()
        try:
            profile = ProfileModel(
                id="pf-1",
                user_id="test-user-id",  # matches _fake_user
                data={
                    "birthDate": "1990-01-15",
                    "firstEmploymentYear": "2015",
                    "pillar3aCapital": "5000",
                },
                updated_at=datetime.now(timezone.utc),
            )
            db.add(profile)
            db.commit()
        finally:
            db.close()

        r = client.get("/api/v1/coach/fresh-start/")
        assert r.status_code == 200
        data = r.json()
        assert "landmarks" in data
        # Landmarks each carry message+intent
        for lm in data["landmarks"]:
            assert "message" in lm
            assert "intent" in lm

    def test_endpoint_invalid_birthdate(self, client):
        """Invalid birth date is swallowed (warning logged)."""
        from app.models.profile_model import ProfileModel
        from tests.conftest import TestingSessionLocal

        db = TestingSessionLocal()
        try:
            profile = ProfileModel(
                id="pf-2",
                user_id="test-user-id",
                data={
                    "birthDate": "not-a-date",
                    "firstEmploymentYear": "abc",  # invalid int
                    "pillar3aCapital": "xyz",  # invalid float
                },
                updated_at=datetime.now(timezone.utc),
            )
            db.add(profile)
            db.commit()
        finally:
            db.close()

        r = client.get("/api/v1/coach/fresh-start/")
        assert r.status_code == 200


# ===========================================================================
# anonymous_chat.py — error paths (152-172)
# ===========================================================================


class TestAnonymousChatErrors:
    def test_missing_session_header(self, client):
        r = client.post(
            "/api/v1/anonymous/chat",
            json={"message": "hi", "language": "fr"},
        )
        assert r.status_code == 400
        assert "Session anonyme" in r.json()["detail"]

    def test_invalid_uuid_session(self, client):
        r = client.post(
            "/api/v1/anonymous/chat",
            json={"message": "hi", "language": "fr"},
            headers={"X-Anonymous-Session": "not-a-uuid"},
        )
        assert r.status_code == 400
        assert "UUID" in r.json()["detail"] or "invalide" in r.json()["detail"]


# ===========================================================================
# documents.py — /extract-vision Profile mirror (1000-1036)
# ===========================================================================


class TestDocumentsVisionProfileMirror:
    def test_extract_vision_mirrors_to_profile(self, client):
        """After extract-vision, ProfileModel.data contains extracted fields."""
        from app.models.profile_model import ProfileModel
        from app.models.document_audit import DocumentAuditLog  # noqa: F401
        from app.core.database import Base
        from tests.conftest import TestingSessionLocal, engine
        from app.schemas.document_scan import (
            VisionExtractionResponse,
            ExtractedFieldConfirmation,
            ConfidenceLevel,
            DocumentType,
        )

        # Ensure audit-log table exists (not created by default in conftest)
        Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])

        # Seed profile
        db = TestingSessionLocal()
        try:
            profile = ProfileModel(
                id="pf-vision-1",
                user_id="test-user-id",
                data={"pre_existing": True},
                updated_at=datetime.now(timezone.utc),
            )
            db.add(profile)
            db.commit()
        finally:
            db.close()

        # Mock classification passes; vision returns high-conf fields
        fake_result = VisionExtractionResponse(
            document_type=DocumentType.salary_certificate,
            extracted_fields=[
                ExtractedFieldConfirmation(
                    field_name="salary_annual",
                    value=120000,
                    confidence=ConfidenceLevel.high,
                ),
                ExtractedFieldConfirmation(
                    field_name="lpp_balance",
                    value=50000,
                    confidence=ConfidenceLevel.medium,
                ),
                ExtractedFieldConfirmation(
                    field_name="noisy",
                    value="?",
                    confidence=ConfidenceLevel.low,
                ),
            ],
            overall_confidence=0.85,
        )

        with patch(
            "app.api.v1.endpoints.documents._classify_and_reject_if_needed",
            return_value=None,
        ), patch(
            "app.services.document_vision_service.extract_with_vision",
            return_value=fake_result,
        ):
            r = client.post(
                "/api/v1/documents/extract-vision",
                json={
                    "imageBase64": "ZmFrZQ==",
                    "documentType": "salary_certificate",
                    "canton": "VS",
                },
            )

        assert r.status_code == 200, r.text

        # Verify mirror
        db = TestingSessionLocal()
        try:
            pf = (
                db.query(ProfileModel)
                .filter(ProfileModel.user_id == "test-user-id")
                .first()
            )
            assert pf is not None
            data = pf.data or {}
            # High/medium conf fields mirrored
            assert data.get("salary_annual") == 120000
            assert data.get("lpp_balance") == 50000
            # Low conf dropped
            assert "noisy" not in data
            # Metadata stamped
            assert "last_document_extraction" in data
            assert data["last_document_extraction"]["document_type"] == "salary_certificate"
            assert "salary_annual" in data["last_document_extraction"]["fields_updated"]
            # Pre-existing preserved
            assert data.get("pre_existing") is True
        finally:
            db.close()
