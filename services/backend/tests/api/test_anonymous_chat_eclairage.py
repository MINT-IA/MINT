"""
Phase 81 — Backend eclairage contract tests.

Covers REQUIREMENTS.md §ECLB-01..05 (anti phantom contract C2):
    - ECLB-01: AnonymousChatRequest accepts optional `archetype` Literal field.
    - ECLB-02: AnonymousChatResponse carries optional `eclairage: EclairageSchema | None`.
    - ECLB-03: Backend orchestrator emits deterministic payload at coach turn 2
      when archetype is set AND emitter is pinned (env or body field).
    - ECLB-04: LSFin compliance — never absolute CHF (always low+high range),
      LSFin disclaimer always present, expanded banned-terms list rejected.
    - ECLB-05: pytest asserts `POST /api/v1/anonymous/chat
      {"message": "ok", "archetype": "julien_swiss"}` (turn 2) returns
      `eclairage.kind == "fiscal_margin_3a"`.

Run:
    cd services/backend && python -m pytest tests/api/test_anonymous_chat_eclairage.py -v
"""

from __future__ import annotations

import os
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-key")

from app.core.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.schemas.anonymous_chat import (  # noqa: E402
    AnonymousChatRequest,
    AnonymousChatResponse,
    EclairageSchema,
)
from app.services.coach.anonymous_eclairage_emitter import (  # noqa: E402
    BannedTermLeak,
    BANNED_TERMS_ECLAIRAGE,
    build_payload,
    resolve_pinned_kind,
    should_emit,
    _validate_payload,
)


# ---------------------------------------------------------------------------
# Test DB setup — isolated SQLite per-file (mirrors test_anonymous_chat.py)
# ---------------------------------------------------------------------------

TEST_DB_URL = "sqlite:///./test_anonymous_chat_eclairage.db"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(autouse=True)
def clear_force_eclairage_env(monkeypatch):
    """Ensure MINT_E2E_FORCE_ECLAIRAGE_KIND is never inherited from the shell."""
    monkeypatch.delenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", raising=False)


@pytest.fixture
def client():
    return TestClient(app)


_MOCK_LLM_RESULT = {
    "answer": "En Suisse, le 2e pilier reste un actif sous-estime.",
    "sources": [],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 100,
}

_SESSION_HEADER = "X-Anonymous-Session"
_SESSION_ID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"


# ---------------------------------------------------------------------------
# ECLB-01 — Request schema accepts archetype Literal
# ---------------------------------------------------------------------------


def test_eclb01_request_accepts_archetype_literal():
    """Optional archetype field accepts the 4 v2.10 slugs."""
    for slug in [
        "julien_swiss",
        "couple_acheteurs_lausanne",
        "jeune_diplome_zurich",
        "cadre_40_55_lpp_rachat",
    ]:
        req = AnonymousChatRequest(message="ok", archetype=slug)
        assert req.archetype == slug


def test_eclb01_request_rejects_unknown_archetype():
    """Unknown archetype slug raises Pydantic validation error."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        AnonymousChatRequest(message="ok", archetype="unknown_archetype")


def test_eclb01_request_archetype_is_optional():
    """Archetype is optional and defaults to None."""
    req = AnonymousChatRequest(message="ok")
    assert req.archetype is None


def test_eclb01_request_accepts_camelcase_archetype_alias():
    """camelCase serialization round-trip works (alias_generator=to_camel)."""
    req = AnonymousChatRequest.model_validate({
        "message": "ok",
        "archetype": "julien_swiss",
    })
    dumped = req.model_dump(by_alias=True)
    assert dumped["archetype"] == "julien_swiss"


# ---------------------------------------------------------------------------
# ECLB-02 — Response schema carries optional eclairage payload
# ---------------------------------------------------------------------------


def test_eclb02_response_eclairage_optional():
    """Eclairage field is optional and defaults to None."""
    resp = AnonymousChatResponse(
        message="hi",
        disclaimers=[],
        messages_remaining=2,
    )
    assert resp.eclairage is None


def test_eclb02_response_eclairage_round_trip_camelcase():
    """EclairageSchema serializes with camelCase aliases for Flutter consumer."""
    payload = EclairageSchema(
        kind="fiscal_margin_3a",
        headline="Une marge fiscale 3a souvent invisible",
        body="Verser sur un 3a peut faire baisser ton revenu imposable.",
        chf_range_low=600,
        chf_range_high=2_400,
        chf_range_period="year",
        soft_account_hint="Crée un compte pour ta fourchette personnelle.",
        lsfin_disclaimer="Information educative uniquement.",
    )
    resp = AnonymousChatResponse(
        message="hi",
        disclaimers=[],
        messages_remaining=1,
        eclairage=payload,
    )
    dumped = resp.model_dump(by_alias=True)
    assert dumped["eclairage"]["kind"] == "fiscal_margin_3a"
    assert dumped["eclairage"]["chfRangeLow"] == 600
    assert dumped["eclairage"]["chfRangeHigh"] == 2_400
    assert dumped["eclairage"]["chfRangePeriod"] == "year"
    assert dumped["eclairage"]["softAccountHint"]
    assert dumped["eclairage"]["lsfinDisclaimer"]


def test_eclb02_eclairage_kind_literal_enforced():
    """Unknown eclairage.kind raises Pydantic validation error."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        EclairageSchema(
            kind="not_a_real_kind",
            headline="x",
            body="x",
            chf_range_period="year",
            soft_account_hint="x",
            lsfin_disclaimer="x",
        )


# ---------------------------------------------------------------------------
# ECLB-03 — Orchestrator emits at coach turn 2 when archetype + pin present
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclb03_emits_at_turn2_with_env_pin(mock_query, client, monkeypatch):
    """Env-var pin + archetype + turn 2 → eclairage payload present."""
    mock_query.return_value = _MOCK_LLM_RESULT
    monkeypatch.setenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", "fiscal_margin_3a")

    # Turn 1 — no eclairage (gate: pre_increment_count == 0)
    resp1 = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok", "archetype": "julien_swiss"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert resp1.status_code == 200
    assert resp1.json().get("eclairage") is None

    # Turn 2 — emitter fires
    resp2 = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok", "archetype": "julien_swiss"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert resp2.status_code == 200
    eclairage = resp2.json().get("eclairage")
    assert eclairage is not None
    assert eclairage["kind"] == "fiscal_margin_3a"


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclb03_emits_at_turn2_with_body_pin(mock_query, client):
    """Body `forcedEclairageKind` pin + archetype + turn 2 → eclairage emitted."""
    mock_query.return_value = _MOCK_LLM_RESULT

    # Burn turn 1
    client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok", "archetype": "julien_swiss"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )

    # Turn 2 with body pin (camelCase via alias_generator)
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={
            "message": "ok",
            "archetype": "cadre_40_55_lpp_rachat",
            "forcedEclairageKind": "lpp_rachat_3a_nantissement",
        },
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert resp.status_code == 200
    eclairage = resp.json().get("eclairage")
    assert eclairage is not None
    assert eclairage["kind"] == "lpp_rachat_3a_nantissement"


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclb03_no_emit_without_archetype(mock_query, client, monkeypatch):
    """Pin + no archetype → free-form response (eclairage None)."""
    mock_query.return_value = _MOCK_LLM_RESULT
    monkeypatch.setenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", "fiscal_margin_3a")

    # Turn 1
    client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    # Turn 2 — no archetype → no emission
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert resp.status_code == 200
    assert resp.json().get("eclairage") is None


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclb03_no_emit_without_pin(mock_query, client):
    """Archetype but no pin → free-form (eclairage None)."""
    mock_query.return_value = _MOCK_LLM_RESULT

    # Turn 1
    client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok", "archetype": "julien_swiss"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    # Turn 2, no pin
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "ok", "archetype": "julien_swiss"},
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert resp.status_code == 200
    assert resp.json().get("eclairage") is None


def test_eclb03_should_emit_gate_unit():
    """Unit-test the should_emit gate matrix."""
    assert should_emit(
        archetype="julien_swiss",
        pre_increment_count=1,
        pinned_kind="fiscal_margin_3a",
    )
    # No archetype
    assert not should_emit(
        archetype=None,
        pre_increment_count=1,
        pinned_kind="fiscal_margin_3a",
    )
    # No pin
    assert not should_emit(
        archetype="julien_swiss",
        pre_increment_count=1,
        pinned_kind=None,
    )
    # Wrong turn
    assert not should_emit(
        archetype="julien_swiss",
        pre_increment_count=0,
        pinned_kind="fiscal_margin_3a",
    )
    assert not should_emit(
        archetype="julien_swiss",
        pre_increment_count=2,
        pinned_kind="fiscal_margin_3a",
    )


def test_eclb03_resolve_pinned_kind_body_wins(monkeypatch):
    """Body pin takes precedence over env pin."""
    monkeypatch.setenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", "fiscal_margin_3a")
    assert resolve_pinned_kind("lpp_rachat_3a_nantissement") == (
        "lpp_rachat_3a_nantissement"
    )


def test_eclb03_resolve_pinned_kind_invalid_returns_none(monkeypatch):
    """Invalid pin values resolve to None (defensive)."""
    monkeypatch.setenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", "garbage_value")
    assert resolve_pinned_kind(None) is None
    assert resolve_pinned_kind("also_garbage") is None


# ---------------------------------------------------------------------------
# ECLB-04 — LSFin compliance
# ---------------------------------------------------------------------------


def test_eclb04_chf_range_pair_required():
    """chf_range_low + chf_range_high must both be set or both null."""
    from pydantic import ValidationError

    # Only low set — invalid
    with pytest.raises(ValidationError):
        EclairageSchema(
            kind="fiscal_margin_3a",
            headline="x",
            body="x",
            chf_range_low=100,
            chf_range_high=None,
            chf_range_period="year",
            soft_account_hint="x",
            lsfin_disclaimer="x",
        )
    # Only high set — invalid
    with pytest.raises(ValidationError):
        EclairageSchema(
            kind="fiscal_margin_3a",
            headline="x",
            body="x",
            chf_range_low=None,
            chf_range_high=200,
            chf_range_period="year",
            soft_account_hint="x",
            lsfin_disclaimer="x",
        )


def test_eclb04_chf_range_high_must_be_gte_low():
    """chf_range_high >= chf_range_low (sanity)."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        EclairageSchema(
            kind="fiscal_margin_3a",
            headline="x",
            body="x",
            chf_range_low=500,
            chf_range_high=100,
            chf_range_period="year",
            soft_account_hint="x",
            lsfin_disclaimer="x",
        )


def test_eclb04_lsfin_disclaimer_non_empty():
    """LSFin disclaimer is required (min_length=1)."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        EclairageSchema(
            kind="fiscal_margin_3a",
            headline="x",
            body="x",
            chf_range_period="year",
            soft_account_hint="x",
            lsfin_disclaimer="",
        )


def test_eclb04_built_payload_always_carries_disclaimer():
    """Every emitter template renders a non-empty LSFin disclaimer."""
    for slug in [
        "julien_swiss",
        "couple_acheteurs_lausanne",
        "jeune_diplome_zurich",
        "cadre_40_55_lpp_rachat",
    ]:
        payload = build_payload(archetype=slug)
        assert payload.lsfin_disclaimer
        assert "LSFin" in payload.lsfin_disclaimer or "éducative" in payload.lsfin_disclaimer.lower()


def test_eclb04_built_payload_always_uses_range():
    """Every emitter template emits chf_range_low + chf_range_high paired."""
    for slug in [
        "julien_swiss",
        "couple_acheteurs_lausanne",
        "jeune_diplome_zurich",
        "cadre_40_55_lpp_rachat",
    ]:
        payload = build_payload(archetype=slug)
        assert payload.chf_range_low is not None
        assert payload.chf_range_high is not None
        assert payload.chf_range_high >= payload.chf_range_low


def test_eclb04_banned_terms_expanded_panel_locked():
    """Banned-terms list contains the panel-locked superset."""
    expected_present = {
        "garanti",
        "optimal",
        "parfait",
        "sans risque",
        "idéal",
        "il faut",
        "rentable",
        "profiter de",
        "opportunité",
    }
    norm = {t.lower() for t in BANNED_TERMS_ECLAIRAGE}
    missing = expected_present - norm
    assert not missing, f"missing banned terms: {missing}"


def test_eclb04_emitter_rejects_banned_term_leak():
    """A leaking template raises BannedTermLeak."""
    leaky = EclairageSchema(
        kind="fiscal_margin_3a",
        headline="C'est idéal pour toi",  # banned: idéal
        body="ok",
        chf_range_low=1,
        chf_range_high=2,
        chf_range_period="year",
        soft_account_hint="ok",
        lsfin_disclaimer="ok",
    )
    with pytest.raises(BannedTermLeak) as exc_info:
        _validate_payload(leaky)
    assert exc_info.value.field == "headline"


# ---------------------------------------------------------------------------
# ECLB-05 — Locked spec assertion (REQUIREMENTS.md)
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclb05_locked_spec_julien_swiss_turn2_returns_fiscal_margin_3a(
    mock_query, client, monkeypatch
):
    """REQUIREMENTS.md §ECLB-05.

    POST /api/v1/anonymous/chat with body {"message": "ok", "archetype":
    "julien_swiss"} on coach turn 2 returns a response whose
    eclairage.kind == "fiscal_margin_3a" (deterministic).

    Pin is provided via env var MINT_E2E_FORCE_ECLAIRAGE_KIND, matching the
    Railway-staging E2E setup described in the spec.
    """
    mock_query.return_value = _MOCK_LLM_RESULT
    monkeypatch.setenv("MINT_E2E_FORCE_ECLAIRAGE_KIND", "fiscal_margin_3a")

    body = {"message": "ok", "archetype": "julien_swiss"}

    # Turn 1 — burns the first message, no eclairage emitted yet.
    r1 = client.post(
        "/api/v1/anonymous/chat",
        json=body,
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert r1.status_code == 200

    # Turn 2 — locked-spec assertion.
    r2 = client.post(
        "/api/v1/anonymous/chat",
        json=body,
        headers={_SESSION_HEADER: _SESSION_ID},
    )
    assert r2.status_code == 200
    data = r2.json()
    assert data.get("eclairage") is not None
    assert data["eclairage"]["kind"] == "fiscal_margin_3a"
    assert data["eclairage"]["chfRangeLow"] is not None
    assert data["eclairage"]["chfRangeHigh"] is not None
    assert data["eclairage"]["lsfinDisclaimer"]
