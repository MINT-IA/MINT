"""Endpoint-level guard: uncited narrator numbers must not reach the user."""

from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.config import settings
from app.main import app
from app.services.coach.citation_parser import FALLBACK_TEMPLATED_TEXT
from app.services.billing_service import ALL_FEATURES


def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


def test_endpoint_replaces_repeated_uncited_absurd_budget_number_with_fallback(
    monkeypatch,
):
    """First uncited answer retries; second uncited answer collapses to fallback."""
    monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", True)
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    orchestrator = MagicMock()
    orchestrator.query = AsyncMock(
        return_value={
            "answer": "Ton budget montre 19'272'200 CHF de logement mensuel.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 42,
        }
    )

    try:
        with (
            patch(
                "app.api.v1.endpoints.coach_chat.recompute_entitlements",
                return_value=("premium", ALL_FEATURES),
            ),
            patch(
                "app.api.v1.endpoints.coach_chat._get_orchestrator",
                return_value=orchestrator,
            ),
            patch(
                "app.services.consent.consent_service.consent_service.check_or_log",
                return_value=__import__(
                    "app.services.consent.consent_service",
                    fromlist=["ConsentCheckResult"],
                ).ConsentCheckResult(grant_exists=True, allow=True),
            ),
            TestClient(app) as client,
        ):
            response = client.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Peux-tu analyser mon budget ?",
                    "api_key": "sk-test-key-12345",
                    "provider": "claude",
                },
            )
    finally:
        app.dependency_overrides.pop(require_current_user, None)
        app.dependency_overrides.pop(get_current_user, None)

    assert response.status_code == 200
    message = response.json()["message"]
    assert message == FALLBACK_TEMPLATED_TEXT
    assert "19'272'200" not in message
    assert orchestrator.query.await_count == 2
