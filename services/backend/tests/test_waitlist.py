"""Tests for POST /api/v1/waitlist — sub-phase 01.5 archetype HARD GATE.

Covers:
- HTTP contract: 201 on success × 6 archetypes, 401 on missing/malformed
  session header, 400 on invalid email / archetype / locale / consent
  values, 201 idempotent on dedup
- Persistence: row written with all required columns, defaults applied
- Consent guard: UCA art. 3(1)(o) — consentGiven must be true
- Schema ↔ model parity: Pydantic Literal must match SQLAlchemy
  _ALLOWED_ARCHETYPES tuple
- camelCase contract via alias_generator
- T-13-06 isolation: no auth dep imported

Run: cd services/backend && python3 -m pytest tests/test_waitlist.py -q
"""

from __future__ import annotations

import os
import uuid as uuid_lib

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("TESTING", "1")

from app.core.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models.waitlist_entry import (  # noqa: E402
    WaitlistEntry,
    _ALLOWED_ARCHETYPES,
    _ALLOWED_LOCALES,
    _ALLOWED_SOURCES,
)


# ---------------------------------------------------------------------------
# Test DB setup — in-memory SQLite per test
# ---------------------------------------------------------------------------

TEST_DB_URL = "sqlite:///./test_waitlist.db"
_test_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
)
_TestSessionLocal = sessionmaker(
    autocommit=False, autoflush=False, bind=_test_engine
)


def _override_get_db():
    db = _TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def _setup_db():
    Base.metadata.create_all(bind=_test_engine)
    app.dependency_overrides[get_db] = _override_get_db
    yield
    Base.metadata.drop_all(bind=_test_engine)
    app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def session_uuid() -> str:
    return str(uuid_lib.uuid4())


def _valid_body(
    archetype: str = "expat_us",
    locale: str = "fr",
    source: str = "onboarding_hard_gate",
    email: str = "ada@example.ch",
    consent_given: bool = True,
) -> dict:
    """Build a valid request body (camelCase, matches alias_generator)."""
    return {
        "email": email,
        "archetype": archetype,
        "locale": locale,
        "source": source,
        "consentGiven": consent_given,
    }


# ---------------------------------------------------------------------------
# §1 Happy-path coverage : 201 across all gated archetypes
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "archetype",
    [
        "expat_us",
        "expat_eu",
        "cross_border",
        "independent_no_lpp",
        "couple_one_works",
        "senior_post_64",
    ],
)
def test_post_waitlist_201_for_each_gated_archetype(
    client: TestClient, session_uuid: str, archetype: str
) -> None:
    response = client.post(
        "/api/v1/waitlist",
        json=_valid_body(archetype=archetype),
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 201, response.text
    payload = response.json()
    assert "id" in payload
    assert "createdAt" in payload  # alias_generator → camelCase
    assert payload["legalEntity"] == "MINT SA"
    assert "retentionPurgeAfter" in payload


def test_post_waitlist_persists_row_with_required_columns(
    client: TestClient, session_uuid: str
) -> None:
    response = client.post(
        "/api/v1/waitlist",
        json=_valid_body(),
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 201
    new_id = response.json()["id"]

    db = _TestSessionLocal()
    try:
        row = db.query(WaitlistEntry).filter(WaitlistEntry.id == new_id).first()
        assert row is not None
        assert row.email == "ada@example.ch"
        assert row.archetype == "expat_us"
        assert row.locale == "fr"
        assert row.source == "onboarding_hard_gate"
        assert row.anonymous_session_id == session_uuid
        assert row.consent_given is True
        assert row.legal_entity == "MINT SA"
        assert row.notified_at is None
        assert row.retention_purge_after > row.created_at
    finally:
        db.close()


def test_post_waitlist_normalizes_email_lowercase(
    client: TestClient, session_uuid: str
) -> None:
    response = client.post(
        "/api/v1/waitlist",
        json=_valid_body(email="Ada.LoveLace@Example.ch"),
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 201
    new_id = response.json()["id"]

    db = _TestSessionLocal()
    try:
        row = db.query(WaitlistEntry).filter(WaitlistEntry.id == new_id).first()
        assert row is not None
        # Email persisted in lowercase (dedup contract).
        assert row.email == "ada.lovelace@example.ch"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# §2 Idempotent dedup : same (email, archetype) returns existing row
# ---------------------------------------------------------------------------


def test_post_waitlist_idempotent_on_same_email_and_archetype(
    client: TestClient, session_uuid: str
) -> None:
    body = _valid_body()
    first = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert first.status_code == 201
    first_id = first.json()["id"]

    second = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert second.status_code == 201, second.text
    assert second.json()["id"] == first_id

    db = _TestSessionLocal()
    try:
        rows = db.query(WaitlistEntry).all()
        assert len(rows) == 1
    finally:
        db.close()


def test_post_waitlist_different_archetype_creates_new_row(
    client: TestClient, session_uuid: str
) -> None:
    """Same email, different archetype = different intent = new row."""
    first = client.post(
        "/api/v1/waitlist",
        json=_valid_body(archetype="expat_us"),
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert first.status_code == 201

    second = client.post(
        "/api/v1/waitlist",
        json=_valid_body(archetype="cross_border"),
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert second.status_code == 201
    assert second.json()["id"] != first.json()["id"]


# ---------------------------------------------------------------------------
# §3 Session header validation (T-13-01 mirror)
# ---------------------------------------------------------------------------


def test_post_waitlist_401_on_missing_session_header(client: TestClient) -> None:
    response = client.post("/api/v1/waitlist", json=_valid_body())
    assert response.status_code == 401
    assert "X-Anonymous-Session" in response.json()["detail"]


def test_post_waitlist_401_on_malformed_session_header(client: TestClient) -> None:
    response = client.post(
        "/api/v1/waitlist",
        json=_valid_body(),
        headers={"X-Anonymous-Session": "not-a-uuid"},
    )
    assert response.status_code == 401
    assert "UUID" in response.json()["detail"]


# ---------------------------------------------------------------------------
# §4 Pydantic input validation
# ---------------------------------------------------------------------------


def test_post_waitlist_422_on_invalid_email(
    client: TestClient, session_uuid: str
) -> None:
    body = _valid_body(email="not-an-email")
    response = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 422  # FastAPI default for Pydantic failure


def test_post_waitlist_422_on_unsupported_archetype(
    client: TestClient, session_uuid: str
) -> None:
    body = _valid_body(archetype="not-a-real-archetype")
    response = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 422


def test_post_waitlist_422_on_unsupported_locale(
    client: TestClient, session_uuid: str
) -> None:
    body = _valid_body(locale="jp")
    response = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 422


def test_post_waitlist_422_on_consent_false(
    client: TestClient, session_uuid: str
) -> None:
    """UCA art. 3(1)(o) — consent must be explicit true."""
    body = _valid_body(consent_given=False)
    response = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 422


def test_post_waitlist_default_source_other_when_omitted(
    client: TestClient, session_uuid: str
) -> None:
    body = _valid_body()
    body.pop("source")
    response = client.post(
        "/api/v1/waitlist",
        json=body,
        headers={"X-Anonymous-Session": session_uuid},
    )
    assert response.status_code == 201

    db = _TestSessionLocal()
    try:
        row = (
            db.query(WaitlistEntry)
            .filter(WaitlistEntry.id == response.json()["id"])
            .first()
        )
        assert row.source == "other"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# §5 Schema ↔ model parity (single-source-of-truth contract)
# ---------------------------------------------------------------------------


def test_schema_archetype_literal_matches_model_tuple() -> None:
    """Drift would let invalid archetypes hit the DB layer."""
    from app.schemas.waitlist import ArchetypeSlug
    from typing import get_args

    schema_values = set(get_args(ArchetypeSlug))
    model_values = set(_ALLOWED_ARCHETYPES)
    assert schema_values == model_values, (
        f"Drift between schema Literal and model tuple. "
        f"schema={schema_values} model={model_values}"
    )


def test_schema_locale_literal_matches_model_tuple() -> None:
    from app.schemas.waitlist import LocaleSlug
    from typing import get_args

    schema_values = set(get_args(LocaleSlug))
    model_values = set(_ALLOWED_LOCALES)
    assert schema_values == model_values


def test_schema_source_literal_matches_model_tuple() -> None:
    from app.schemas.waitlist import SourceSlug
    from typing import get_args

    schema_values = set(get_args(SourceSlug))
    model_values = set(_ALLOWED_SOURCES)
    assert schema_values == model_values


# ---------------------------------------------------------------------------
# §6 T-13-06 isolation guard
# ---------------------------------------------------------------------------


def test_waitlist_endpoint_imports_no_auth_dep() -> None:
    """T-13-06 — waitlist endpoint must NOT import authenticated deps.

    The waitlist screen renders BEFORE signup ; importing
    `require_current_user` or `coach_chat` would couple the public
    pre-auth path to the authenticated stack and breach T-13-06
    isolation (same constraint as anonymous_chat.py).
    """
    import inspect

    from app.api.v1.endpoints import waitlist as waitlist_endpoint

    source = inspect.getsource(waitlist_endpoint)
    forbidden_imports = [
        "from app.core.auth import",
        "require_current_user",
        "from app.api.v1.endpoints.coach_chat",
        "from app.api.v1.endpoints import coach_chat",
    ]
    for forbidden in forbidden_imports:
        assert forbidden not in source, (
            f"T-13-06 violation: waitlist endpoint imports {forbidden!r}. "
            f"The anonymous/pre-signup path must stay isolated from auth."
        )
