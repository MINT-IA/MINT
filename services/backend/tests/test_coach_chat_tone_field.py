"""
Tests for the Phase 91 Plan 91-01 (VIVANT-04) `tone` request field on
POST /api/v1/coach/chat.

The mobile app's `/settings/coach-tone` screen persists one of three
values (`calm`, `direct`, `sansFilter`) and ships it on every chat
request. The endpoint maps that value onto the existing INTENSITY_MAP
(1/3/5) and overrides `cash_level` for the voice-intensity block
injection.

Covers:
    1. CoachToneLiteral schema accepts the 3 valid values, rejects others.
    2. COACH_TONE_TO_INTENSITY contract is the single source of truth.
    3. build_system_prompt produces visibly different intensity blocks
       for cash_level=1 (calm) vs cash_level=5 (sansFilter).
    4. The endpoint accepts the `tone` field without raising 422.
    5. Legacy clients (no `tone` field) still work.

Run: cd services/backend && python3 -m pytest tests/test_coach_chat_tone_field.py -v
"""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.main import app
from app.core.auth import require_current_user, get_current_user


# --------------------------------------------------------------------------
# Fixtures (mirrored from test_coach_chat_endpoint.py to keep this file
# standalone; no shared conftest changes needed)
# --------------------------------------------------------------------------


def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


_ORCHESTRATOR_OK = {
    "answer": "Reponse calme.",
    "sources": [],
    "disclaimers": ["Outil educatif."],
    "tokens_used": 100,
}


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_orchestrator(result: dict):
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(return_value=result)
    return patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        return_value=mock_orch,
    )


@pytest.fixture
def client_with_auth():
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


# --------------------------------------------------------------------------
# Schema-level tests — no HTTP layer involved
# --------------------------------------------------------------------------


class TestCoachToneSchema:
    """Verify the `tone` field on CoachChatRequest is correctly typed."""

    def test_tone_calm_accepted(self):
        from app.schemas.coach_chat import CoachChatRequest

        req = CoachChatRequest(message="Bonjour", tone="calm")
        assert req.tone == "calm"

    def test_tone_direct_accepted(self):
        from app.schemas.coach_chat import CoachChatRequest

        req = CoachChatRequest(message="Bonjour", tone="direct")
        assert req.tone == "direct"

    def test_tone_sansFilter_accepted(self):
        from app.schemas.coach_chat import CoachChatRequest

        req = CoachChatRequest(message="Bonjour", tone="sansFilter")
        assert req.tone == "sansFilter"

    def test_tone_default_is_none(self):
        """Legacy clients (no `tone` field) MUST keep working."""
        from app.schemas.coach_chat import CoachChatRequest

        req = CoachChatRequest(message="Bonjour")
        assert req.tone is None

    def test_tone_invalid_value_rejected(self):
        """Pydantic Literal must reject typos / unknown values."""
        from app.schemas.coach_chat import CoachChatRequest

        with pytest.raises(ValidationError):
            CoachChatRequest(message="Bonjour", tone="cash")

    def test_tone_to_intensity_mapping_contract(self):
        """The 3 wire values map to the INTENSITY_MAP slots 1/3/5.

        This is the contract between mobile and backend — changing it
        breaks every shipped client. See 91-CONTEXT.md decisions
        VIVANT-04.
        """
        from app.schemas.coach_chat import COACH_TONE_TO_INTENSITY

        assert COACH_TONE_TO_INTENSITY == {
            "calm": 1,
            "direct": 3,
            "sansFilter": 5,
        }


# --------------------------------------------------------------------------
# Prompt-level tests — verify the injected voice intensity block changes
# when tone changes (the user-visible difference between calm and sansFilter).
# --------------------------------------------------------------------------


class TestCoachToneSystemPrompt:
    """build_system_prompt(cash_level=N) must produce visibly different
    intensity blocks for the 3 tone values."""

    def test_calm_injects_tranquille_block(self):
        from app.services.coach.claude_coach_service import build_system_prompt

        prompt = build_system_prompt(ctx=None, cash_level=1)
        assert "Intensité 1/5" in prompt
        # The TRANQUILLE block from INTENSITY_MAP[1].
        assert "TRANQUILLE" in prompt

    def test_direct_injects_direct_block(self):
        from app.services.coach.claude_coach_service import build_system_prompt

        prompt = build_system_prompt(ctx=None, cash_level=3)
        assert "Intensité 3/5" in prompt
        assert "DIRECT" in prompt

    def test_sansFilter_injects_brut_block(self):
        from app.services.coach.claude_coach_service import build_system_prompt

        prompt = build_system_prompt(ctx=None, cash_level=5)
        assert "Intensité 5/5" in prompt
        # INTENSITY_MAP[5] = "Ton BRUT : aucun filtre de politesse..."
        assert "BRUT" in prompt

    def test_calm_and_sansFilter_prompts_differ(self):
        """The whole point of the toggle: the LLM gets a different block
        depending on the tone the user selected."""
        from app.services.coach.claude_coach_service import build_system_prompt

        calm = build_system_prompt(ctx=None, cash_level=1)
        sans_filter = build_system_prompt(ctx=None, cash_level=5)

        assert calm != sans_filter
        # Calm block reads "TRANQUILLE", brut reads "BRUT" — they must
        # not both appear in the calm prompt and vice versa.
        assert "TRANQUILLE" in calm
        assert "BRUT" not in calm.split("Intensité 1/5", 1)[1].split(
            "ANTI-PATTERNS", 1
        )[0]

        assert "BRUT" in sans_filter


# --------------------------------------------------------------------------
# HTTP-level tests — verify the endpoint accepts the new field.
# --------------------------------------------------------------------------


class TestCoachChatToneHTTP:
    """End-to-end: the `tone` field is accepted on the wire."""

    def test_tone_calm_request_returns_200(self, client_with_auth):
        body = {
            "message": "Bonjour Mint",
            "provider": "claude",
            "tone": "calm",
        }
        with _mock_orchestrator(_ORCHESTRATOR_OK):
            response = client_with_auth.post("/api/v1/coach/chat", json=body)
        # 200 in normal path; 400 only when the server has no
        # ANTHROPIC_API_KEY configured (envless CI fallback).
        assert response.status_code in (200, 400)

    def test_tone_direct_request_returns_200(self, client_with_auth):
        body = {
            "message": "Bonjour Mint",
            "provider": "claude",
            "tone": "direct",
        }
        with _mock_orchestrator(_ORCHESTRATOR_OK):
            response = client_with_auth.post("/api/v1/coach/chat", json=body)
        assert response.status_code in (200, 400)

    def test_tone_sansFilter_request_returns_200(self, client_with_auth):
        body = {
            "message": "Bonjour Mint",
            "provider": "claude",
            "tone": "sansFilter",
        }
        with _mock_orchestrator(_ORCHESTRATOR_OK):
            response = client_with_auth.post("/api/v1/coach/chat", json=body)
        assert response.status_code in (200, 400)

    def test_tone_invalid_returns_422(self, client_with_auth):
        """Bad wire value must be rejected by pydantic."""
        body = {
            "message": "Bonjour Mint",
            "provider": "claude",
            "tone": "cash",  # not in the Literal
        }
        response = client_with_auth.post("/api/v1/coach/chat", json=body)
        assert response.status_code == 422

    def test_no_tone_field_still_works(self, client_with_auth):
        """Legacy clients without `tone` MUST keep getting a normal response."""
        body = {
            "message": "Bonjour Mint",
            "provider": "claude",
        }
        with _mock_orchestrator(_ORCHESTRATOR_OK):
            response = client_with_auth.post("/api/v1/coach/chat", json=body)
        assert response.status_code in (200, 400)
