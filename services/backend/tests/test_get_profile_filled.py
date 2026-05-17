"""FastAPI integration tests for `app.core.profile_resolver.get_profile_filled`.

Plan: mint-calc-engine-v1-01-w1-shared-helpers Task 2

Verifies the dependency chains under a real FastAPI ASGI resolver (NOT pure-Python
unit tests like test_profile_resolver.py — those covered the helpers in isolation).
Uses a minimal probe app `_probe_app()` (separate from the production `app`) so the
test stays scoped to the dependency, no endpoint surface is exercised.

Reuses the in-memory SQLite + StaticPool infrastructure from `conftest.py`
(`TestingSessionLocal`, `override_get_db`, `_fake_user`, `clean_database` autouse).

5 contract tests :
  1. Profile.data == {canton:GE, age:35} → dependency returns same dict.
  2. Profile.data == None → dependency returns {}.
  3. No ProfileModel row → dependency returns {}.
  4. Two profiles for same user (race) → most-recent-by-updated_at wins.
  5. Mini probe endpoint with Depends(get_profile_filled) returns the dict
     over HTTP (proves the dep chains under FastAPI's resolver).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.database import get_db
from app.core.profile_resolver import get_profile_filled
from app.models.profile_model import ProfileModel

from tests.conftest import TestingSessionLocal, _fake_user, override_get_db


def _make_probe_app() -> FastAPI:
    """Spin up a minimal FastAPI app exposing ONE endpoint that returns
    whatever `get_profile_filled` resolved to."""
    probe = FastAPI()

    @probe.get("/_probe/profile")
    def _read_profile(profile: dict = Depends(get_profile_filled)):
        return profile

    probe.dependency_overrides[get_db] = override_get_db
    probe.dependency_overrides[require_current_user] = _fake_user
    probe.dependency_overrides[get_current_user] = _fake_user
    return probe


@pytest.fixture
def probe_client() -> TestClient:
    return TestClient(_make_probe_app())


@pytest.fixture
def db_session():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def _insert_profile(db, data: dict | None, updated_at: datetime | None = None) -> ProfileModel:
    """Insert a ProfileModel row tied to the conftest _fake_user (id=test-user-id)."""
    profile = ProfileModel(
        id=str(uuid4()),
        user_id="test-user-id",
        data=data if data is not None else {},
    )
    # The model defaults updated_at, but the most-recent-wins test needs us
    # to control it explicitly.
    if updated_at is not None:
        profile.updated_at = updated_at
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def test_returns_profile_data_dict(probe_client, db_session):
    """Test 1 — profile.data == {canton:GE, age:35} → dependency returns same dict."""
    _insert_profile(db_session, data={"canton": "GE", "age": 35})
    resp = probe_client.get("/_probe/profile")
    assert resp.status_code == 200
    assert resp.json() == {"canton": "GE", "age": 35}


def test_returns_empty_dict_when_profile_data_is_none(probe_client, db_session):
    """Test 2 — ProfileModel.data nullable=False in schema, but treat empty
    JSON object as the equivalent of "no data" — get_profile_filled returns {}."""
    # ProfileModel.data is nullable=False at the schema level, so pass {}.
    _insert_profile(db_session, data={})
    resp = probe_client.get("/_probe/profile")
    assert resp.status_code == 200
    assert resp.json() == {}


def test_returns_empty_dict_when_no_profile_row(probe_client, db_session):
    """Test 3 — no ProfileModel row → dependency returns {}."""
    # clean_database autouse fixture already wiped the table at test start;
    # no insert here. Confirm row count is 0 just to make the precondition
    # explicit for future readers.
    assert db_session.query(ProfileModel).count() == 0
    resp = probe_client.get("/_probe/profile")
    assert resp.status_code == 200
    assert resp.json() == {}


def test_picks_most_recent_profile_when_multiple(probe_client, db_session):
    """Test 4 — 2 profiles for same user (race) → most-recent by updated_at DESC wins."""
    older_ts = datetime.now(timezone.utc) - timedelta(days=2)
    newer_ts = datetime.now(timezone.utc)
    _insert_profile(db_session, data={"canton": "OLD"}, updated_at=older_ts)
    _insert_profile(db_session, data={"canton": "NEW"}, updated_at=newer_ts)
    resp = probe_client.get("/_probe/profile")
    assert resp.status_code == 200
    assert resp.json() == {"canton": "NEW"}


def test_dependency_chains_under_fastapi_resolver(probe_client, db_session):
    """Test 5 — probe endpoint using `Depends(get_profile_filled)` returns the
    dict via JSON 200 → proves the dep chains under FastAPI's resolver
    (auth + db + profile_resolver compose correctly)."""
    _insert_profile(db_session, data={"income": 95000, "lpp_balance": 250000})
    resp = probe_client.get("/_probe/profile")
    assert resp.status_code == 200
    body = resp.json()
    assert body["income"] == 95000
    assert body["lpp_balance"] == 250000
