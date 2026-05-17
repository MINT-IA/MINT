"""
Phase mint-calc-engine-v1 W3 Plan 16 — Finding 4 GC daily job tests.

Tests `app.services.cache.gc_job.purge_superseded_scenarios` against
in-memory SQLite. Predicate under test :

    DELETE FROM scenarios
    WHERE superseded_by IS NOT NULL
      AND created_at < now() - interval '<max_age_days> days'

Five scenarios :
 1. Old superseded rows → DELETED.
 2. Live rows (`superseded_by IS NULL`) → NEVER deleted (cache live entries).
 3. Recent superseded rows (within window) → NEVER deleted (audit window).
 4. `dry_run=True` returns count, mutates nothing.
 5. `max_age_days` is configurable (override the default 30).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel  # noqa: F401 — FK target
from app.models.scenario import ScenarioModel
from app.services.cache.gc_job import purge_superseded_scenarios


# --------------------------------------------------------------------- helpers
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


def _seed_scenario(
    db,
    profile_id: str,
    *,
    kind: str = "avs",
    inputs_hash: str = "h",
    superseded_by: str | None = None,
    age_days: int = 0,
) -> ScenarioModel:
    """Insert a scenario row at created_at = now - age_days.

    `superseded_by` value semantics :
        - None   → live row (`superseded_by IS NULL`).
        - "_self_NEW_UUID_" → caller-provided UUID-shape string ; this row
                              counts as superseded for GC purposes.
        - any non-None str → same as above.
    """
    row = ScenarioModel(
        id=str(uuid4()),
        profile_id=profile_id,
        kind=kind,
        inputs={},
        outputs={"v": 1},
        inputs_hash=inputs_hash,
        superseded_by=superseded_by,
        created_at=datetime.now(timezone.utc) - timedelta(days=age_days),
    )
    db.add(row)
    db.flush()
    return row


def _scenario_count(db) -> int:
    return db.query(ScenarioModel).count()


# --------------------------------------------------------------------- Test 1
def test_purges_old_superseded_rows(db_session_factory):
    """100 rows with superseded_by set + created_at=now-31d → all 100 purged."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(100):
            _seed_scenario(
                db,
                pid,
                superseded_by=str(uuid4()),
                age_days=31,
            )
        db.commit()
        assert _scenario_count(db) == 100

        deleted = purge_superseded_scenarios(db, max_age_days=30)
        assert deleted == 100
        assert _scenario_count(db) == 0
    finally:
        db.close()


# --------------------------------------------------------------------- Test 2
def test_live_rows_never_deleted(db_session_factory):
    """100 rows with superseded_by IS NULL → 0 purged (live rows preserved)."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(100):
            _seed_scenario(
                db,
                pid,
                superseded_by=None,  # live
                age_days=365,  # even ancient live rows must NOT be purged
            )
        db.commit()
        assert _scenario_count(db) == 100

        deleted = purge_superseded_scenarios(db, max_age_days=30)
        assert deleted == 0
        # All 100 live rows still present.
        assert _scenario_count(db) == 100
    finally:
        db.close()


# --------------------------------------------------------------------- Test 3
def test_recent_superseded_rows_within_window_not_deleted(db_session_factory):
    """100 superseded rows with created_at=now-10d → 0 purged (within 30d window)."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(100):
            _seed_scenario(
                db,
                pid,
                superseded_by=str(uuid4()),
                age_days=10,  # within 30d audit window
            )
        db.commit()
        assert _scenario_count(db) == 100

        deleted = purge_superseded_scenarios(db, max_age_days=30)
        assert deleted == 0
        assert _scenario_count(db) == 100
    finally:
        db.close()


# --------------------------------------------------------------------- Test 4
def test_dry_run_reports_count_without_deleting(db_session_factory):
    """dry_run=True returns the would-be-deleted count, but nothing changes in DB."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(50):
            _seed_scenario(
                db,
                pid,
                superseded_by=str(uuid4()),
                age_days=45,
            )
        for _ in range(20):
            _seed_scenario(
                db,
                pid,
                superseded_by=None,  # live, never counts
                age_days=45,
            )
        db.commit()
        before = _scenario_count(db)
        assert before == 70

        reported = purge_superseded_scenarios(db, max_age_days=30, dry_run=True)
        assert reported == 50  # only the 50 old-superseded rows

        after = _scenario_count(db)
        assert after == before, "dry_run must NOT mutate the DB"
    finally:
        db.close()


# --------------------------------------------------------------------- Test 5
def test_max_age_days_configurable(db_session_factory):
    """Override max_age_days=60 → 45-day-old superseded rows preserved."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(30):
            _seed_scenario(
                db,
                pid,
                superseded_by=str(uuid4()),
                age_days=45,
            )
        db.commit()
        assert _scenario_count(db) == 30

        # With default 30d cutoff → all 30 are old → all purged.
        # But here we override to 60d → none are past cutoff → 0 purged.
        deleted = purge_superseded_scenarios(db, max_age_days=60)
        assert deleted == 0
        assert _scenario_count(db) == 30

        # Now run with 40d cutoff (tighter than 60d but looser than default 30d).
        # 45d > 40d → all 30 purged.
        deleted = purge_superseded_scenarios(db, max_age_days=40)
        assert deleted == 30
        assert _scenario_count(db) == 0
    finally:
        db.close()


# --------------------------------------------------------------------- Test 6
def test_idempotent_second_run_zero_rows(db_session_factory):
    """Run GC twice in a row : first run purges N rows, second run purges 0."""
    db = db_session_factory()
    try:
        pid = _make_profile(db)
        for _ in range(25):
            _seed_scenario(
                db,
                pid,
                superseded_by=str(uuid4()),
                age_days=35,
            )
        db.commit()
        assert _scenario_count(db) == 25

        first_run = purge_superseded_scenarios(db, max_age_days=30)
        assert first_run == 25

        # Second run on stable state → 0 deleted.
        second_run = purge_superseded_scenarios(db, max_age_days=30)
        assert second_run == 0
        assert _scenario_count(db) == 0
    finally:
        db.close()


# --------------------------------------------------------------------- Fixture
@pytest.fixture
def db_session_factory():
    """Yield the test session factory (shared in-memory SQLite engine)."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal
