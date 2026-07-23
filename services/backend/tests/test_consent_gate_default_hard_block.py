"""Défaut hard_block du consent gate coach (beads MINT_nosync-tcr).

Preuve e2e du DÉFAUT de production (aucun monkeypatch du mode, contrairement
à test_consent_gate_log_only_mode.py qui teste chaque mode explicitement) :
un utilisateur SANS grant TRANSFER_US_ANTHROPIC reçoit 403 + deny_pointer au
premier message coach, POST /consents/grant (endpoint réel), puis le même
message répond 200. C'est le contrat exact du flux mobile
(coach_chat_screen : 403 -> ConsentSheet -> grant -> retry).

RED sur dev : le défaut était log_only -> le premier POST répondait 200.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import get_current_user, require_current_user
from app.core.config import settings
from app.core.database import get_db
from tests.conftest import TestingSessionLocal, override_get_db


def _fake_user():
    user = MagicMock()
    user.id = "hardblock-user-id"
    user.email = "hardblock@mint.ch"
    user.display_name = "Hard Block"
    return user


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES

    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_coach_orchestrator():
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(return_value={
        "answer": "Reponse stub.",
        "sources": [],
        "disclaimers": ["Outil educatif (LSFin)."],
        "tokens_used": 50,
    })
    return patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        new_callable=AsyncMock,
        return_value=mock_orch,
    )


@pytest.fixture
def ungranted_client(monkeypatch):
    """Client authentifié SANS aucun receipt de consentement.

    N'utilise volontairement PAS le `client` du conftest (qui seed le grant
    pour modéliser l'utilisateur post-consentement).
    """
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-orchestrator-stubbed")
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), _mock_coach_orchestrator(), TestClient(
        app
    ) as c:
        yield c
    app.dependency_overrides.clear()


def _payload() -> dict:
    return {"message": "ping", "conversation_history": [], "profile_context": {}}


def test_default_mode_is_hard_block():
    assert settings.CONSENT_GATE_ENFORCEMENT_MODE == "hard_block", (
        "beads MINT_nosync-tcr : le défaut de production doit être "
        "hard_block maintenant que le flux mobile consent-avant-coach "
        "est livré — log_only laissait partir les données US sans grant"
    )


def test_chat_without_grant_403_then_grant_then_200(ungranted_client):
    # 1. Premier message sans grant -> 403 + deny_pointer structuré.
    first = ungranted_client.post("/api/v1/coach/chat", json=_payload())
    assert first.status_code == 403, (
        "sans grant TRANSFER_US_ANTHROPIC le coach doit refuser "
        f"(défaut hard_block) — reçu {first.status_code}"
    )
    pointer = first.json()["detail"]
    assert pointer["purpose"] == "transfer_us_anthropic"
    assert pointer["modal_copy_key"] == "consent_modal_transfer_us_anthropic"
    assert "grant" in pointer["action"]

    # 2. Le mobile présente la ConsentSheet puis POST le grant réel.
    granted = ungranted_client.post(
        "/api/v1/consents/grant",
        json={"purpose": "transfer_us_anthropic", "policy_version": "v2.4.0"},
    )
    assert granted.status_code in (200, 201), granted.text

    # 3. Retry du même message -> 200.
    retry = ungranted_client.post("/api/v1/coach/chat", json=_payload())
    assert retry.status_code == 200, retry.text
    assert retry.json()["message"]
