"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 cache reader tests.

Tests `app.services.cache.cache_reader.lookup` against in-memory SQLite ;
the production path on PostgreSQL exercises the Plan 12 composite partial index
`idx_scenarios_cache_lookup` (verified post-deploy via EXPLAIN ANALYZE, NOT here).
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel  # noqa: F401 — FK target
from app.models.scenario import ScenarioModel
from app.services.cache.cache_reader import lookup


def _make_profile(db, profile_id: str | None = None) -> str:
    """Insert a minimal ProfileModel and return its id (FK target for scenarios)."""
    pid = profile_id or str(uuid4())
    db.add(
        ProfileModel(
            id=pid,
            user_id=None,  # nullable per profile_model.py:36
            data={"placeholder": True},
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    )
    db.flush()
    return pid


def _make_scenario(
    db,
    *,
    profile_id: str,
    kind: str,
    inputs_hash: str,
    superseded_by: str | None = None,
    created_at: datetime | None = None,
    outputs: dict | None = None,
) -> ScenarioModel:
    row = ScenarioModel(
        id=str(uuid4()),
        profile_id=profile_id,
        kind=kind,
        inputs={"placeholder": True},
        outputs=outputs or {"value": 42},
        inputs_hash=inputs_hash,
        superseded_by=superseded_by,
        created_at=created_at or datetime.now(timezone.utc),
    )
    db.add(row)
    db.flush()
    return row


# --------------------------------------------------------------------- Test 1
def test_lookup_returns_live_row(db_session_factory):
    """After insert of (profile_id, kind, inputs_hash, superseded_by=None), lookup returns the row."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        row = _make_scenario(db, profile_id=pid, kind="avs", inputs_hash="hash-1")
        db.commit()

        result = asyncio.run(lookup(pid, "avs", "hash-1", db))
        assert result is not None
        assert result.id == row.id
        assert result.inputs_hash == "hash-1"
        assert result.superseded_by is None
    finally:
        db.close()


# --------------------------------------------------------------------- Test 2
def test_lookup_skips_superseded(db_session_factory):
    """If superseded_by is set, row is filtered out (partial-index semantics)."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        # Create a NEW row first that the OLD one will point at
        new_row = _make_scenario(db, profile_id=pid, kind="avs", inputs_hash="hash-2-new")
        _make_scenario(
            db,
            profile_id=pid,
            kind="avs",
            inputs_hash="hash-2-old",
            superseded_by=new_row.id,
            created_at=datetime.now(timezone.utc) - timedelta(hours=1),
        )
        db.commit()

        # Looking up the OLD hash returns None (superseded out)
        result = asyncio.run(lookup(pid, "avs", "hash-2-old", db))
        assert result is None

        # Looking up the NEW hash returns the live row
        result_new = asyncio.run(lookup(pid, "avs", "hash-2-new", db))
        assert result_new is not None
        assert result_new.id == new_row.id
    finally:
        db.close()


# --------------------------------------------------------------------- Test 3
def test_lookup_returns_most_recent_by_created_at_desc(db_session_factory):
    """Multiple live rows for same key — most recent by created_at DESC wins."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        now = datetime.now(timezone.utc)
        _make_scenario(
            db,
            profile_id=pid,
            kind="lpp",
            inputs_hash="hash-3",
            created_at=now - timedelta(hours=2),
        )
        middle = _make_scenario(
            db,
            profile_id=pid,
            kind="lpp",
            inputs_hash="hash-3",
            created_at=now - timedelta(hours=1),
        )
        newest = _make_scenario(
            db,
            profile_id=pid,
            kind="lpp",
            inputs_hash="hash-3",
            created_at=now,
        )
        # Sanity: middle exists
        assert middle.id != newest.id
        db.commit()

        result = asyncio.run(lookup(pid, "lpp", "hash-3", db))
        assert result is not None
        assert result.id == newest.id
    finally:
        db.close()


# --------------------------------------------------------------------- Test 4
def test_lookup_returns_none_when_missing(db_session_factory):
    """Non-existent (profile_id, kind, inputs_hash) returns None."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        # Only insert an unrelated row
        _make_scenario(db, profile_id=pid, kind="avs", inputs_hash="some-hash")
        db.commit()

        # Different kind
        assert asyncio.run(lookup(pid, "lpp", "some-hash", db)) is None
        # Different hash
        assert asyncio.run(lookup(pid, "avs", "nope", db)) is None
        # Different profile
        assert asyncio.run(lookup("missing-profile-id", "avs", "some-hash", db)) is None
    finally:
        db.close()


# --------------------------------------------------------------------- Fixture
@pytest.fixture
def db_session_factory():
    """Yield a callable producing fresh test DB sessions sharing the in-memory engine."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal
