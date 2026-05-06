"""Phase 93 — Plan 02 — FATCA pre-emission gate (positive path).

When archetype == ``expat_us`` AND the user message matches the FATCA
topic regex, the LLM call MUST be short-circuited and a hand-off card
returned instead. The audit log MUST receive one row with
``eclairage_kind="fatca_handoff"``.

Per OAR-G art. 24 + FINMA Guidance 8/2024 §VI.

Closes:
    - REQUIREMENTS.md COMP-04
    - USER_WALKTHROUGH_2026-05-06 BUG #22 P1
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.database import get_db
from app.main import app
from app.models.coach_message_audit import CoachMessageAudit
from app.services.coach.fatca_gate import (
    _topic_is_fatca_sensitive,
    build_fatca_handoff_card,
)
from app.utils.audit_hash import hash_for_audit
from tests.conftest import override_get_db


# ---------------------------------------------------------------------------
# Fixtures (mirror tests/test_audit_log_emit_on_coach_chat.py)
# ---------------------------------------------------------------------------


def _fake_user():
    user = MagicMock()
    user.id = "fatca-user-id"
    user.email = "expat@mint.ch"
    user.display_name = "Expat User"
    return user


_VALID_BODY = {
    "message": "J'ai 70k de 3a, je dois faire quoi ?",
    "api_key": "sk-test-key-12345",
    "provider": "claude",
    "profile_context": {"archetype": "expat_us"},
}


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES

    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_orchestrator_with_counter():
    """Mock orchestrator returning a tracked counter so the test can
    assert the LLM was NEVER called (counter == 0 on positive gate).
    """
    counter = {"calls": 0}
    mock_orch = MagicMock()

    async def _query(*_args, **_kwargs):
        counter["calls"] += 1
        return {
            "answer": "(this should never appear when the gate fires)",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 100,
        }

    mock_orch.query = AsyncMock(side_effect=_query)
    return (
        patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            return_value=mock_orch,
        ),
        counter,
    )


@pytest.fixture
def client_with_auth():
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


def _audit_rows_for_user(user_id: str) -> list[CoachMessageAudit]:
    from tests.conftest import TestingSessionLocal

    session = TestingSessionLocal()
    try:
        return (
            session.query(CoachMessageAudit)
            .filter(CoachMessageAudit.session_id == user_id)
            .all()
        )
    finally:
        session.close()


@pytest.fixture(autouse=True)
def _wipe_audit_rows_between_tests():
    from tests.conftest import TestingSessionLocal

    session = TestingSessionLocal()
    try:
        session.query(CoachMessageAudit).delete()
        session.commit()
    finally:
        session.close()
    yield


# ---------------------------------------------------------------------------
# Pure-unit tests on the gate helpers (no FastAPI client)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "message,expected_label",
    [
        ("J'ai 70k de 3a, je dois faire quoi ?", "3a_or_pillar3a"),
        ("Je veux ouvrir un 3eme pilier", "3a_or_pillar3a"),
        ("Mon troisième pilier", "3a_or_pillar3a"),
        ("pillar 3a contributions?", "3a_or_pillar3a"),
        ("Que veut dire PFIC ?", "pfic"),
        ("foreign trust planning", "foreign_trust_fbar"),
        ("form 3520 deadline", "foreign_trust_fbar"),
        ("FBAR threshold", "foreign_trust_fbar"),
        ("the CH-US treaty", "treaty"),
        ("convention CH-US", "treaty"),
    ],
)
def test_topic_regex_matches_fatca_sensitive_messages(message, expected_label):
    assert _topic_is_fatca_sensitive(message) == expected_label


@pytest.mark.parametrize(
    "message",
    [
        "Je veux faire un budget mensuel",
        "comment fonctionne mon hypothèque",
        "j'ai des questions sur mon assurance maladie",
        "comment optimiser mon AVS",
        "",
    ],
)
def test_topic_regex_does_not_match_unrelated_messages(message):
    assert _topic_is_fatca_sensitive(message) is None


def test_build_fatca_handoff_card_fr_contains_no_banned_terms():
    """All 6 locales must be free of LSFin banned terms (CLAUDE.md règle 1)."""
    banned = ("optimal", "garanti", "meilleur", "parfait", "sans risque")
    for lang in ("fr", "en", "de", "es", "it", "pt"):
        payload = build_fatca_handoff_card(lang)
        text = payload.message.lower()
        for word in banned:
            assert word not in text, (
                f"banned term '{word}' found in {lang} hand-off message"
            )


def test_build_fatca_handoff_card_fr_uses_proper_diacritics():
    """FR copy must use proper diacritics (CLAUDE.md règle 2)."""
    fr = build_fatca_handoff_card("fr")
    text = fr.message
    # Positive: proper diacritics present.
    assert "spécialisé" in text or "spécialiste" in text
    assert "décision" in text
    # Negative: no ASCII-e where diacritic is required.
    assert "specialiste" not in text
    assert "decision" not in text


def test_build_fatca_handoff_card_unknown_language_falls_back_to_fr():
    payload = build_fatca_handoff_card("xx")
    fr = build_fatca_handoff_card("fr")
    assert payload.message == fr.message


def test_build_fatca_handoff_card_tool_call_shape_matches_dispatcher():
    """tool_call uses the existing {name, input} Anthropic shape."""
    payload = build_fatca_handoff_card("fr")
    assert payload.tool_call.get("name") == "show_handoff_card"
    inp = payload.tool_call.get("input") or {}
    assert inp.get("kind") == "fatca"
    # ARB key names mirror the keys we ship in app_*.arb (Task 2).
    assert inp.get("title_key") == "fatcaHandoffTitle"
    assert inp.get("body_key") == "fatcaHandoffBody"
    assert inp.get("cta_key") == "fatcaHandoffCta"


# ---------------------------------------------------------------------------
# End-to-end: gate fires on /api/v1/coach/chat
# ---------------------------------------------------------------------------


def test_fatca_gate_fires_for_expat_us_3a_question(client_with_auth):
    """Positive path: expat_us + 3a question → hand-off card, no LLM call."""
    breadcrumb_calls: list[dict] = []

    def _capture_breadcrumb(**kwargs):
        breadcrumb_calls.append(kwargs)

    orch_patch, counter = _mock_orchestrator_with_counter()
    with orch_patch, patch(
        "sentry_sdk.add_breadcrumb",
        side_effect=_capture_breadcrumb,
    ):
        resp = client_with_auth.post("/api/v1/coach/chat", json=_VALID_BODY)

    assert resp.status_code == 200, resp.text
    payload = resp.json()

    # 1. The LLM was never called (gate short-circuited).
    assert counter["calls"] == 0, (
        "LLM was called even though the FATCA gate should have short-circuited"
    )

    # 2. Response message is the localized hand-off body, not generic 3a advice.
    assert "FATCA" in payload["message"]
    assert "spécialiste" in payload["message"]
    # No banned terms.
    lower = payload["message"].lower()
    for w in ("optimal", "garanti", "meilleur", "parfait", "sans risque"):
        assert w not in lower

    # 3. tool_calls contains a show_handoff_card with kind=fatca.
    # Response uses camelCase alias (toolCalls) per CoachChatBaseModel.
    tool_calls = payload.get("toolCalls") or payload.get("tool_calls") or []
    assert tool_calls, "toolCalls missing on hand-off response"
    handoff_tc = tool_calls[0]
    assert handoff_tc.get("name") == "show_handoff_card"
    assert handoff_tc.get("input", {}).get("kind") == "fatca"

    # 4. response_meta tags model_used as the gate so observability can split.
    response_meta = payload.get("responseMeta") or payload.get("response_meta") or {}
    assert response_meta.get("modelUsed") == "fatca_handoff_gate" or \
        response_meta.get("model_used") == "fatca_handoff_gate"

    # 5. Sentry breadcrumb fired with the topic_match label.
    fatca_breadcrumbs = [
        b for b in breadcrumb_calls if b.get("category") == "compliance.fatca_gate"
    ]
    assert len(fatca_breadcrumbs) == 1, (
        f"expected 1 fatca breadcrumb, got {len(fatca_breadcrumbs)}"
    )
    assert fatca_breadcrumbs[0]["data"]["archetype"] == "expat_us"
    assert fatca_breadcrumbs[0]["data"]["topic_match"] == "3a_or_pillar3a"

    # 6. Audit log row written with eclairage_kind="fatca_handoff".
    rows = _audit_rows_for_user("fatca-user-id")
    assert len(rows) == 1, f"expected 1 audit row, got {len(rows)}"
    row = rows[0]
    assert row.archetype == "expat_us"
    assert row.eclairage_kind == "fatca_handoff"
    assert row.banned_term_hit is False
    assert row.prompt_hash == hash_for_audit(_VALID_BODY["message"])
    # response_hash is the hash of the hand-off message (not raw text).
    assert row.response_hash == hash_for_audit(payload["message"])
