"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 cache writer tests.

Tests `app.services.cache.cache_writer.write` against in-memory SQLite.

The writer maintains the `superseded_by` DAG chain : on each new write for an
existing `(profile_id, kind)` key with a NEW `inputs_hash`, the prior live row
gets its `superseded_by` flipped to the new row's id. Same `inputs_hash` →
idempotent no-op.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel  # noqa: F401 — FK target
from app.models.scenario import ScenarioModel
from app.services.cache.cache_reader import lookup
from app.services.cache.cache_writer import write


def _make_profile(db) -> str:
    pid = str(uuid4())
    db.add(
        ProfileModel(
            id=pid,
            user_id=None,
            data={"placeholder": True},
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    )
    db.flush()
    db.commit()
    return pid


# --------------------------------------------------------------------- Test 1
def test_write_first_inserts_single_row(db_session_factory):
    """Cold cache : first write inserts 1 row, superseded_by=None."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        row = asyncio.run(write(pid, "avs", "hash-1", {"rente_mensuelle": 2300}, db))

        assert row.id is not None
        assert row.profile_id == pid
        assert row.kind == "avs"
        assert row.inputs_hash == "hash-1"
        assert row.superseded_by is None
        assert row.outputs == {"rente_mensuelle": 2300}

        # Exactly 1 row for (pid, "avs")
        count = (
            db.query(ScenarioModel)
            .filter(ScenarioModel.profile_id == pid, ScenarioModel.kind == "avs")
            .count()
        )
        assert count == 1
    finally:
        db.close()


# --------------------------------------------------------------------- Test 2
def test_write_supersede_chain(db_session_factory):
    """Second write for same (profile_id, kind) but DIFFERENT inputs_hash → first row's superseded_by flipped."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)

        first = asyncio.run(write(pid, "avs", "hash-old", {"rente": 2300}, db))
        # Force created_at gap so order_by DESC is deterministic on SQLite
        first.created_at = datetime.now(timezone.utc).replace(microsecond=0)
        db.add(first)
        db.commit()

        second = asyncio.run(write(pid, "avs", "hash-new", {"rente": 2450}, db))

        # Reload first row from DB to see the supersede flip
        db.refresh(first)
        assert first.superseded_by == second.id
        assert second.superseded_by is None
        assert second.inputs_hash == "hash-new"

        # cache_reader sees ONLY the new row for either hash
        live_for_new_hash = asyncio.run(lookup(pid, "avs", "hash-new", db))
        assert live_for_new_hash is not None and live_for_new_hash.id == second.id

        # Old hash is gone from the live view (superseded out)
        live_for_old_hash = asyncio.run(lookup(pid, "avs", "hash-old", db))
        assert live_for_old_hash is None
    finally:
        db.close()


# --------------------------------------------------------------------- Test 3
def test_write_idempotent_same_inputs_hash(db_session_factory):
    """Re-write of the SAME inputs_hash for the same (profile_id, kind) is a no-op — returns the existing row."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        first = asyncio.run(write(pid, "lpp", "hash-same", {"capital": 250_000}, db))
        first_id = first.id

        second = asyncio.run(write(pid, "lpp", "hash-same", {"capital": 999_999}, db))

        # Returned the SAME row (same id) — no new insert.
        assert second.id == first_id
        # Outputs were NOT overwritten (idempotent).
        assert second.outputs == {"capital": 250_000}

        # Exactly 1 row for (pid, "lpp")
        count = (
            db.query(ScenarioModel)
            .filter(ScenarioModel.profile_id == pid, ScenarioModel.kind == "lpp")
            .count()
        )
        assert count == 1
        # And it's still live (superseded_by=None)
        db.refresh(first)
        assert first.superseded_by is None
    finally:
        db.close()


# --------------------------------------------------------------------- Test 4
def test_write_three_writes_form_chain_of_two(db_session_factory):
    """Three sequential writes with three different inputs_hash → chain of 2 supersedes."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)

        r1 = asyncio.run(write(pid, "pillar3a", "h1", {"version": 1}, db))
        r1.created_at = datetime.now(timezone.utc).replace(microsecond=0)
        db.add(r1)
        db.commit()

        r2 = asyncio.run(write(pid, "pillar3a", "h2", {"version": 2}, db))
        r2.created_at = datetime.now(timezone.utc).replace(microsecond=0)
        db.add(r2)
        db.commit()

        r3 = asyncio.run(write(pid, "pillar3a", "h3", {"version": 3}, db))

        db.refresh(r1)
        db.refresh(r2)
        db.refresh(r3)
        # r1 -> r2, r2 -> r3, r3 live.
        assert r1.superseded_by == r2.id
        assert r2.superseded_by == r3.id
        assert r3.superseded_by is None

        # Only r3 visible to the reader for h3 ; r1+r2 invisible for their hashes.
        assert asyncio.run(lookup(pid, "pillar3a", "h1", db)) is None
        assert asyncio.run(lookup(pid, "pillar3a", "h2", db)) is None
        live3 = asyncio.run(lookup(pid, "pillar3a", "h3", db))
        assert live3 is not None and live3.id == r3.id
    finally:
        db.close()


# --------------------------------------------------------------------- Fixture
@pytest.fixture
def db_session_factory():
    """Yield the test session factory (shared in-memory SQLite engine)."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal
