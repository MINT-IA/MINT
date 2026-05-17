"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 get_or_compute orchestrator tests.

Tests the read-through-cache + singleflight orchestrator at
`app.services.cache.get_or_compute.get_or_compute`.

Property : on cold cache, N concurrent same-key calls invoke `compute_fn` AT
MOST 1 time and all N callers receive the freshly-written row. On warm cache,
`compute_fn` is NOT invoked.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel  # noqa: F401 — FK target
from app.models.scenario import ScenarioModel
from app.services.cache import get_or_compute, _singleflight
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
def test_cold_cache_compute_fn_called_once(db_session_factory):
    """Cold cache : compute_fn called once, result persisted, returned."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        calls = 0

        async def compute() -> dict:
            nonlocal calls
            calls += 1
            return {"rente": 2300, "computed_by": "test"}

        row = asyncio.run(get_or_compute(pid, "avs", "hash-cold", compute, db))

        assert calls == 1
        assert row.inputs_hash == "hash-cold"
        assert row.outputs == {"rente": 2300, "computed_by": "test"}
        assert row.superseded_by is None

        # Persisted in DB
        count = (
            db.query(ScenarioModel)
            .filter(ScenarioModel.profile_id == pid, ScenarioModel.kind == "avs")
            .count()
        )
        assert count == 1
    finally:
        db.close()


# --------------------------------------------------------------------- Test 2
def test_warm_cache_compute_fn_not_called(db_session_factory):
    """Warm cache : compute_fn NOT invoked, cached row returned."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        # Pre-populate the cache via the writer directly.
        seeded = asyncio.run(write(pid, "lpp", "hash-warm", {"capital": 250_000}, db))

        calls = 0

        async def compute() -> dict:
            nonlocal calls
            calls += 1
            return {"WRONG": "should-not-be-called"}

        row = asyncio.run(get_or_compute(pid, "lpp", "hash-warm", compute, db))

        assert calls == 0, "compute_fn must NOT run on cache hit"
        assert row.id == seeded.id
        assert row.outputs == {"capital": 250_000}
    finally:
        db.close()


# --------------------------------------------------------------------- Test 3 (HEADLINE: stampede collapse)
def test_concurrent_cold_cache_compute_fn_called_once_singleflight(db_session_factory):
    """Headline : 10 concurrent cold-cache same-key calls → compute_fn invoked exactly 1×.

    All 10 callers receive a row whose `inputs_hash` matches the single
    compute. Stampede collapse property verified end-to-end through
    cache_reader + singleflight + cache_writer.
    """
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        # `calls` counter mutated under singleflight lock — single-threaded
        # asyncio means we don't even need an explicit Lock to guard `calls`.
        # Python 3.9 forbids creating asyncio.Lock() outside a running loop, so
        # we use a plain int counter (asyncio is single-threaded).
        state = {"calls": 0}

        async def compute() -> dict:
            state["calls"] += 1
            # Hold long enough for all 10 tasks to queue on the singleflight lock.
            await asyncio.sleep(0.02)
            return {"rente": 2300, "computed_at": "once"}

        async def runner() -> list:
            # Each coroutine gets its OWN session — mimics the FastAPI per-request
            # `Depends(get_db)` pattern. Without this, sqlalchemy autoflush + SQLite
            # raises on cross-coroutine session reuse.

            async def one_call():
                sess = db_session_factory()
                try:
                    return await get_or_compute(pid, "pillar3a", "hash-stamp", compute, sess)
                finally:
                    sess.close()

            return await asyncio.gather(*[one_call() for _ in range(10)])

        rows = asyncio.run(runner())
        calls = state["calls"]

        assert calls == 1, f"compute_fn must run exactly once across 10 concurrent calls, got {calls}"
        assert len(rows) == 10
        # All callers got a row pointing at the same inputs_hash + outputs
        first_id = rows[0].id
        for r in rows[1:]:
            assert r.id == first_id, "all callers must observe the single cached row"
        # And only 1 row was written to DB
        count = (
            db.query(ScenarioModel)
            .filter(ScenarioModel.profile_id == pid, ScenarioModel.kind == "pillar3a")
            .count()
        )
        assert count == 1
    finally:
        db.close()


# --------------------------------------------------------------------- Test 4
def test_compute_fn_raises_no_row_written(db_session_factory):
    """compute_fn exception propagates ; no cache row is written ; singleflight lock released."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)

        class ComputeFailed(Exception):
            pass

        async def compute() -> dict:
            raise ComputeFailed("boom")

        with pytest.raises(ComputeFailed, match="boom"):
            asyncio.run(get_or_compute(pid, "avs", "hash-fail", compute, db))

        # No row written.
        count = (
            db.query(ScenarioModel)
            .filter(ScenarioModel.profile_id == pid, ScenarioModel.kind == "avs")
            .count()
        )
        assert count == 0

        # Singleflight lock released — next acquire on same key proceeds.
        async def succeed_after() -> dict:
            return {"recovered": True}

        row = asyncio.run(get_or_compute(pid, "avs", "hash-recover", succeed_after, db))
        assert row.outputs == {"recovered": True}
    finally:
        db.close()


# --------------------------------------------------------------------- Fixture
@pytest.fixture
def db_session_factory():
    """Yield the test session factory."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal


@pytest.fixture(autouse=True)
def _reset_singleflight():
    """Reset module-level singleflight registry between tests to avoid cross-test contamination."""
    _singleflight._locks.clear()
    yield
    _singleflight._locks.clear()
