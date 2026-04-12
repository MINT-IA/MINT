"""
Tests for nLPD consent guards across endpoints + auth schema coverage.

Verifies that:
1. documents.py — upload blocked without document_upload consent (403)
2. rag.py — query degrades without byok_data_sharing consent (no user context)
3. coach_chat.py — stateless without conversation_memory consent (memory_block stripped)
4. auth.py — logout accepts refresh_token in body

Run: cd services/backend && python3 -m pytest tests/test_consent_guards.py -v
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import require_current_user, get_current_user
from app.core.database import get_db
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_models import ConsentType
from tests.conftest import TestingSessionLocal, override_get_db


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _fake_user():
    """Mock authenticated user."""
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


def _grant_consent(consent_type: ConsentType):
    """Grant a specific consent for the test user in the test DB."""
    db = TestingSessionLocal()
    ConsentManager.update_consent("test-user-id", consent_type, True, db=db)
    db.close()


def _revoke_consent(consent_type: ConsentType):
    """Revoke a specific consent for the test user in the test DB."""
    db = TestingSessionLocal()
    ConsentManager.update_consent("test-user-id", consent_type, False, db=db)
    db.close()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client():
    """Test client with test DB and auth override."""
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Mock helpers
# ---------------------------------------------------------------------------


def _mock_entitlements_premium():
    """Patch recompute_entitlements to grant premium access (all features)."""
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_coach_orchestrator(result: dict):
    """Patch coach chat orchestrator to avoid needing chromadb."""
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(return_value=result)
    return patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        return_value=mock_orch,
    )


_COACH_OK_RESULT = {
    "answer": "Le 3a est un instrument puissant.",
    "sources": [],
    "disclaimers": ["Outil educatif (LSFin)."],
    "tokens_used": 100,
}


def _mock_rag_orchestrator(result: dict):
    """Patch RAG orchestrator to avoid needing chromadb."""
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(return_value=result)
    return patch(
        "app.api.v1.endpoints.rag._get_orchestrator_safe",
        new_callable=AsyncMock,
        return_value=mock_orch,
    )


_RAG_OK_RESULT = {
    "answer": "Le pilier 3a permet de deduire les cotisations.",
    "sources": [],
    "disclaimers": ["Outil educatif (LSFin)."],
    "tokens_used": 80,
}


# ===========================================================================
# 1a. documents.py — upload blocked without document_upload consent
# ===========================================================================


class TestDocumentUploadConsentGuard:
    """nLPD art. 6 al. 7: document upload requires document_upload consent."""

    def test_upload_blocked_without_document_upload_consent(self, client):
        """POST /documents/upload returns 403 when document_upload consent is not granted."""
        # No consent granted — default is False (nLPD opt-in)
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 403
        assert "document_upload" in response.json()["detail"]

    def test_upload_allowed_with_document_upload_consent(self, client):
        """POST /documents/upload does NOT return 403 when consent is granted."""
        _grant_consent(ConsentType.document_upload)

        # We still expect a non-403 response (could be 200 or other error from
        # mocked docling, but not a consent block).
        from unittest.mock import patch as _patch
        from tests.test_documents import _make_mock_parser, _make_mock_extractor
        from tests.test_documents import PARSER_PATCH, LPP_EXTRACTOR_PATCH

        with _patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor()), \
             _patch(PARSER_PATCH, return_value=_make_mock_parser()):
            response = client.post(
                "/api/v1/documents/upload",
                files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
            )
        assert response.status_code != 403

    def test_upload_blocked_returns_actionable_message(self, client):
        """403 response tells the user how to enable consent."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 403
        detail = response.json()["detail"]
        assert "Consentement" in detail
        assert "Profil" in detail or "Consentements" in detail

    def test_upload_blocked_after_consent_revoked(self, client):
        """Upload blocked again after consent is revoked."""
        _grant_consent(ConsentType.document_upload)
        _revoke_consent(ConsentType.document_upload)

        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 403


# ===========================================================================
# 1b. rag.py — degrades without byok_data_sharing consent
# ===========================================================================


class TestRAGConsentGuard:
    """nLPD art. 6 al. 7: RAG degrades without byok_data_sharing consent."""

    def test_rag_query_succeeds_without_byok_consent(self, client):
        """POST /rag/query returns 200 even without byok_data_sharing consent.

        The query still works — it just excludes user-specific context.
        """
        with _mock_rag_orchestrator(_RAG_OK_RESULT):
            response = client.post(
                "/api/v1/rag/query",
                json={
                    "question": "Qu'est-ce que le pilier 3a ?",
                    "api_key": "sk-test-12345",
                    "provider": "claude",
                },
            )
        assert response.status_code == 200
        data = response.json()
        assert "answer" in data

    def test_rag_query_without_consent_excludes_user_context(self, client):
        """Without byok_data_sharing consent, profile_context and user_id are None."""
        captured_kwargs = {}

        async def _capturing_orchestrator():
            mock_orch = MagicMock()

            async def _capture_query(**kwargs):
                captured_kwargs.update(kwargs)
                return _RAG_OK_RESULT

            mock_orch.query = _capture_query
            return mock_orch

        with patch(
            "app.api.v1.endpoints.rag._get_orchestrator_safe",
            new_callable=AsyncMock,
            side_effect=_capturing_orchestrator,
        ):
            response = client.post(
                "/api/v1/rag/query",
                json={
                    "question": "Qu'est-ce que le pilier 3a ?",
                    "api_key": "sk-test-12345",
                    "provider": "claude",
                    "profile_context": {"canton": "VD", "age": 45},
                },
            )

        assert response.status_code == 200
        # Without consent: user_id should be None and profile_context should be None
        assert captured_kwargs.get("user_id") is None
        assert captured_kwargs.get("profile_context") is None

    def test_rag_query_with_byok_consent_includes_user_context(self, client):
        """With byok_data_sharing consent, profile_context and user_id are passed."""
        _grant_consent(ConsentType.byok_data_sharing)

        captured_kwargs = {}

        async def _capturing_orchestrator():
            mock_orch = MagicMock()

            async def _capture_query(**kwargs):
                captured_kwargs.update(kwargs)
                return _RAG_OK_RESULT

            mock_orch.query = _capture_query
            return mock_orch

        with patch(
            "app.api.v1.endpoints.rag._get_orchestrator_safe",
            new_callable=AsyncMock,
            side_effect=_capturing_orchestrator,
        ):
            response = client.post(
                "/api/v1/rag/query",
                json={
                    "question": "Qu'est-ce que le pilier 3a ?",
                    "api_key": "sk-test-12345",
                    "provider": "claude",
                    "profile_context": {"canton": "VD", "age": 45},
                },
            )

        assert response.status_code == 200
        # With consent: user_id and profile_context should be present
        assert captured_kwargs.get("user_id") == "test-user-id"
        assert captured_kwargs.get("profile_context") is not None
        assert captured_kwargs["profile_context"]["canton"] == "VD"


# ===========================================================================
# 1c. coach_chat.py — stateless without conversation_memory consent
# ===========================================================================


class TestCoachChatMemoryConsentGuard:
    """nLPD art. 6 al. 7: coach chat is stateless without conversation_memory consent."""

    _COACH_BODY = {
        "message": "Comment optimiser mon 3a ?",
        "api_key": "sk-test-key-12345",
        "provider": "claude",
    }

    _COACH_BODY_WITH_MEMORY = {
        "message": "Comment optimiser mon 3a ?",
        "api_key": "sk-test-key-12345",
        "provider": "claude",
        "memory_block": "User mentioned saving 500 CHF/month in pilier 3a.",
    }

    def test_coach_chat_works_without_memory_consent(self, client):
        """POST /coach/chat returns 200 even without conversation_memory consent."""
        with _mock_coach_orchestrator(_COACH_OK_RESULT):
            response = client.post("/api/v1/coach/chat", json=self._COACH_BODY)
        assert response.status_code == 200

    def test_coach_chat_strips_memory_block_without_consent(self, client):
        """Without conversation_memory consent, memory_block is stripped (set to None)."""
        captured_memory = {"value": "SENTINEL"}

        try:
            from app.services.coach.structured_reasoning_service import StructuredReasoningService
            _ = StructuredReasoningService.reason  # verify import works
        except ImportError:
            pass

        def _capture_reason(user_message, profile_context, memory_block=None, **kw):
            captured_memory["value"] = memory_block
            # Return a minimal reasoning output
            result = MagicMock()
            result.as_system_prompt_block.return_value = ""
            return result

        with _mock_coach_orchestrator(_COACH_OK_RESULT), \
             patch(
                 "app.api.v1.endpoints.coach_chat.StructuredReasoningService.reason",
                 side_effect=_capture_reason,
             ):
            response = client.post(
                "/api/v1/coach/chat", json=self._COACH_BODY_WITH_MEMORY
            )

        assert response.status_code == 200
        # Without consent, memory_block should have been stripped to None
        assert captured_memory["value"] is None

    def test_coach_chat_preserves_memory_block_with_consent(self, client):
        """With conversation_memory consent, memory_block is preserved."""
        _grant_consent(ConsentType.conversation_memory)

        captured_memory = {"value": "SENTINEL"}

        def _capture_reason(user_message, profile_context, memory_block=None, **kw):
            captured_memory["value"] = memory_block
            result = MagicMock()
            result.as_system_prompt_block.return_value = ""
            return result

        with _mock_coach_orchestrator(_COACH_OK_RESULT), \
             patch(
                 "app.api.v1.endpoints.coach_chat.StructuredReasoningService.reason",
                 side_effect=_capture_reason,
             ):
            response = client.post(
                "/api/v1/coach/chat", json=self._COACH_BODY_WITH_MEMORY
            )

        assert response.status_code == 200
        # With consent, memory_block should be preserved (non-None)
        assert captured_memory["value"] is not None
        assert "pilier 3a" in captured_memory["value"]

    def test_coach_chat_memory_consent_revoked_strips_block(self, client):
        """After revoking conversation_memory consent, memory_block is stripped again."""
        _grant_consent(ConsentType.conversation_memory)
        _revoke_consent(ConsentType.conversation_memory)

        captured_memory = {"value": "SENTINEL"}

        def _capture_reason(user_message, profile_context, memory_block=None, **kw):
            captured_memory["value"] = memory_block
            result = MagicMock()
            result.as_system_prompt_block.return_value = ""
            return result

        with _mock_coach_orchestrator(_COACH_OK_RESULT), \
             patch(
                 "app.api.v1.endpoints.coach_chat.StructuredReasoningService.reason",
                 side_effect=_capture_reason,
             ):
            response = client.post(
                "/api/v1/coach/chat", json=self._COACH_BODY_WITH_MEMORY
            )

        assert response.status_code == 200
        assert captured_memory["value"] is None


# ===========================================================================
# 3. Logout schema — accepts refresh_token in body
# ===========================================================================


class TestLogoutRefreshToken:
    """Verify POST /auth/logout accepts a refresh_token in the request body."""

    def test_logout_accepts_refresh_token_in_body(self, client):
        """POST /auth/logout with refresh_token in body should work (blacklist both tokens).

        Register + login to get real tokens, then logout with refresh_token.
        """
        # Register a user to get real tokens
        reg_resp = client.post(
            "/api/v1/auth/register",
            json={
                "email": "logout-test@mint.ch",
                "password": "securepass123",
                "display_name": "Logout Test",
            },
        )
        assert reg_resp.status_code == 201
        tokens = reg_resp.json()
        access_token = tokens["access_token"]
        refresh_token = tokens["refresh_token"]

        # Logout with refresh_token in body — requires Bearer token header
        logout_resp = client.post(
            "/api/v1/auth/logout",
            json={"refresh_token": refresh_token},
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert logout_resp.status_code == 200
        assert logout_resp.json()["status"] == "logged_out"

    def test_logout_works_without_refresh_token_in_body(self, client):
        """POST /auth/logout works even without refresh_token (only blacklists access token)."""
        reg_resp = client.post(
            "/api/v1/auth/register",
            json={
                "email": "logout-norefresh@mint.ch",
                "password": "securepass123",
            },
        )
        assert reg_resp.status_code == 201
        access_token = reg_resp.json()["access_token"]

        logout_resp = client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert logout_resp.status_code == 200
        assert logout_resp.json()["status"] == "logged_out"

    def test_logout_with_empty_body(self, client):
        """POST /auth/logout with empty JSON body should still work."""
        reg_resp = client.post(
            "/api/v1/auth/register",
            json={
                "email": "logout-empty@mint.ch",
                "password": "securepass123",
            },
        )
        assert reg_resp.status_code == 201
        access_token = reg_resp.json()["access_token"]

        client.post(
            "/api/v1/auth/logout",
            json={},
            headers={"Authorization": f"Bearer {access_token}"},
        )
