"""Phase 97.5 W2-T5 — endpoint-level proof of the log_only ConsentService gate.

Service-layer dispatch (`check_or_log` modes, log emission, header / pointer
shapes) is unit-tested in `tests/services/consent/test_consent_service_extensions.py`.
This file proves the wiring : `/api/v1/coach/chat` POST executes the gate AND
respects each enforcement mode end-to-end (returns 200 in log_only, returns
200 in soft_block, raises 403 in hard_block when grant is missing).

Run :
    cd services/backend && python3 -m pytest tests/test_consent_gate_log_only_mode.py -v
"""
from __future__ import annotations

import logging
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import get_current_user, require_current_user
from app.core.database import get_db
from tests.conftest import override_get_db, TestingSessionLocal


def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


def _mock_entitlements_premium():
    """Grant premium so the entitlement gate doesn't pre-empt the consent gate."""
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_coach_orchestrator():
    """Stub the LLM orchestrator so the test never reaches Anthropic."""
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
def client(monkeypatch):
    # The handler requires ANTHROPIC_API_KEY (env or body.api_key). Set it so
    # the test reaches the consent gate even when the test runner has no env.
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-used-because-orchestrator-stubbed")
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), _mock_coach_orchestrator(), TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _coach_chat_payload() -> dict:
    """Minimal CoachChatRequest body that satisfies the schema."""
    return {
        "message": "ping",
        "conversation_history": [],
        "profile_context": {},
    }


def _set_enforcement_mode(monkeypatch, mode: str) -> None:
    """Set CONSENT_GATE_ENFORCEMENT_MODE on every module-bound reference.

    `app.api.v1.endpoints.coach_chat` does `from app.core.config import settings`
    at import time, so it holds a direct reference to the Settings instance
    *that existed at coach_chat import*. If an earlier test reloaded
    `app.core.config` (e.g. tests/test_config_guards.py::TestChromaDBPersistDir),
    `app.core.config.settings` now points to a NEW instance and the
    `coach_chat.settings` binding is the OLD one. Patching only one of them
    leaves the other returning the default — and the gate reads the
    coach_chat-side binding.

    Set the value on BOTH instances so the gate reads `mode` regardless of
    which one survived a prior reload. Both writes are no-op'd by pytest's
    monkeypatch teardown.
    """
    import app.core.config as _cfg
    import app.api.v1.endpoints.coach_chat as _coach
    monkeypatch.setattr(_cfg.settings, "CONSENT_GATE_ENFORCEMENT_MODE", mode, raising=False)
    monkeypatch.setattr(_coach.settings, "CONSENT_GATE_ENFORCEMENT_MODE", mode, raising=False)


def _grant_transfer_us_anthropic_for_test_user():
    """Insert an active TRANSFER_US_ANTHROPIC grant for the fake user."""
    from app.schemas.consent_receipt import ConsentPurpose
    from app.services.consent.consent_service import consent_service
    db = TestingSessionLocal()
    try:
        consent_service.grant(
            db,
            user_id="test-user-id",
            purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC.value,
            policy_version="v2.3.0",
        )
    finally:
        db.close()


# ---------------------------------------------------------------------------
# log_only mode (v2.9 default)
# ---------------------------------------------------------------------------


def test_log_only_mode_missing_consent_returns_200_and_logs(client, caplog, monkeypatch):
    """log_only + missing grant → 200 + 'consent_missing' warning log."""
    _set_enforcement_mode(monkeypatch, "log_only")
    caplog.set_level(logging.WARNING, logger="app.services.consent.consent_service")

    response = client.post("/api/v1/coach/chat", json=_coach_chat_payload())

    # log_only NEVER blocks — must not be 403 from the consent gate.
    assert response.status_code != 403, (
        f"log_only must not block ; got {response.status_code} body={response.text[:300]}"
    )
    # Structured warning log present.
    assert any(
        "consent_missing" in rec.message for rec in caplog.records
    ), "expected 'consent_missing' warning log in log_only mode with no grant"


def test_log_only_mode_with_grant_returns_200_and_no_log(client, caplog, monkeypatch):
    """log_only + grant present → 200 + NO consent_missing log."""
    _set_enforcement_mode(monkeypatch, "log_only")
    _grant_transfer_us_anthropic_for_test_user()
    caplog.set_level(logging.WARNING, logger="app.services.consent.consent_service")
    caplog.clear()

    response = client.post("/api/v1/coach/chat", json=_coach_chat_payload())

    assert response.status_code != 403
    assert not any(
        "consent_missing" in rec.message for rec in caplog.records
    ), "no warning log expected when grant exists"


# ---------------------------------------------------------------------------
# soft_block mode (v2.10 stage 2 — structure defined in v2.9, header
# propagation deferred per 97.5-PLAN.md §M.4)
# ---------------------------------------------------------------------------


def test_soft_block_mode_missing_consent_returns_200(client, monkeypatch):
    """soft_block + missing grant → 200 (non-blocking ; header propagation is v2.10)."""
    _set_enforcement_mode(monkeypatch, "soft_block")
    response = client.post("/api/v1/coach/chat", json=_coach_chat_payload())
    assert response.status_code != 403


# ---------------------------------------------------------------------------
# hard_block mode (v2.10 stage 3 — defined in v2.9, env flip is v2.10)
# ---------------------------------------------------------------------------


def test_hard_block_mode_missing_consent_returns_403_with_pointer(client, monkeypatch):
    """hard_block + missing grant → 403 + structured pointer detail."""
    _set_enforcement_mode(monkeypatch, "hard_block")
    response = client.post("/api/v1/coach/chat", json=_coach_chat_payload())
    assert response.status_code == 403
    detail = response.json().get("detail", {})
    # Structured pointer the Flutter modal will render in v2.10.
    assert isinstance(detail, dict), f"expected dict detail, got {detail!r}"
    assert detail.get("purpose") == "transfer_us_anthropic"
    assert detail.get("action", "").startswith("POST")


def test_hard_block_mode_with_grant_returns_200(client, monkeypatch):
    """hard_block + grant present → 200 (gate passes)."""
    _set_enforcement_mode(monkeypatch, "hard_block")
    _grant_transfer_us_anthropic_for_test_user()
    response = client.post("/api/v1/coach/chat", json=_coach_chat_payload())
    assert response.status_code != 403
