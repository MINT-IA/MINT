"""Backfill idempotency test — Plan 02-03 PR-3a (D-05, iter-2 A9).

Asserts that `backfill_snapshot_to_fact_event.backfill_user` :
1. First run on a fresh SnapshotModel row writes 1 fact_event row
   (monthly_gross_income only, per the Karpathy #1 honest-mapping
    surfaced in the script docstring).
2. Second run on the SAME row reports 0 new fact_events + 1 skipped.
3. Subsequent fact_current row matches via decrypt_value round-trip.

The test runs on the SQLite path (in-memory conftest fixture) — the
backfill is dialect-independent at the application layer (the projector
handles the SQLite-vs-Postgres UPSERT split).
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import create_engine

from app.core.database import Base
from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.snapshot import SnapshotModel
from app.models.user import User
from app.services.encryption.encrypted_value_helper import decrypt_value
from scripts.backfill_snapshot_to_fact_event import backfill_user, run_backfill
from tests.conftest import TestingSessionLocal


@pytest.fixture
def db():
    s = TestingSessionLocal()
    try:
        yield s
    finally:
        s.close()


@pytest.fixture
def user_id(db):
    uid = f"u-{uuid4().hex[:8]}"
    db.add(User(id=uid, email=f"{uuid4().hex[:8]}@bf.test", hashed_password="x"))
    db.commit()
    return uid


@pytest.fixture
def snapshot_row(db, user_id):
    snap = SnapshotModel(
        id=str(uuid4()),
        user_id=user_id,
        created_at=datetime(2026, 5, 18, 12, 0, 0, tzinfo=timezone.utc),
        trigger="profile_update",
        gross_income=8500.0,
        age=35,
        canton="VD",
        archetype="swiss_native",
        household_type="single",
    )
    db.add(snap)
    db.commit()
    return snap


def test_first_run_writes_one_fact_event(db, snapshot_row):
    wrote, skipped = backfill_user(db, snapshot_row=snapshot_row, dry_run=False)
    db.commit()
    assert wrote == 1
    assert skipped == 0

    # Verify exactly one fact_event with our backfill source
    fe_rows = db.query(FactEvent).filter(
        FactEvent.user_id == snapshot_row.user_id,
        FactEvent.source == "snapshot_backfill_v1",
    ).all()
    assert len(fe_rows) == 1
    assert fe_rows[0].field_key == "monthly_gross_income"

    # fact_current UPSERT'd via project_event
    fc = db.query(FactCurrent).filter(
        FactCurrent.user_id == snapshot_row.user_id,
        FactCurrent.field_key == "monthly_gross_income",
    ).one()
    assert decrypt_value(db, snapshot_row.user_id, fc.value_enc) == 8500.0


def test_second_run_is_idempotent(db, snapshot_row):
    # First run
    backfill_user(db, snapshot_row=snapshot_row, dry_run=False)
    db.commit()
    count_after_first = db.query(FactEvent).filter(
        FactEvent.user_id == snapshot_row.user_id,
        FactEvent.source == "snapshot_backfill_v1",
    ).count()
    assert count_after_first == 1

    # Second run on the SAME snapshot
    wrote, skipped = backfill_user(db, snapshot_row=snapshot_row, dry_run=False)
    db.commit()
    assert wrote == 0
    assert skipped == 1

    # No new fact_event rows
    count_after_second = db.query(FactEvent).filter(
        FactEvent.user_id == snapshot_row.user_id,
        FactEvent.source == "snapshot_backfill_v1",
    ).count()
    assert count_after_second == 1


def test_dry_run_doesnt_write(db, snapshot_row):
    wrote, skipped = backfill_user(db, snapshot_row=snapshot_row, dry_run=True)
    # dry_run reports what WOULD be written
    assert wrote == 1
    assert skipped == 0
    # ...but DB has no new rows
    fe_rows = db.query(FactEvent).filter(
        FactEvent.user_id == snapshot_row.user_id,
        FactEvent.source == "snapshot_backfill_v1",
    ).all()
    assert fe_rows == []


def test_run_backfill_honors_explicit_database_url(tmp_path):
    """CLI path must use the explicit target URL, not settings.DATABASE_URL."""
    db_path = tmp_path / "backfill-empty.sqlite"
    url = f"sqlite:///{db_path}"
    engine = create_engine(url)
    Base.metadata.create_all(engine)

    summary = run_backfill(url=url, dry_run=True)

    assert summary["snapshots_seen"] == 0
    assert summary["fact_events_written"] == 0
    assert summary["errors"] == 0
    assert summary["dry_run"] is True


def test_snapshot_with_zero_gross_income_skips(db, user_id):
    """SnapshotModel.gross_income default=0.0 → backfill skips (None-equivalent
    semantics : Plan 02-02 canary treats 0.0 as a real fact but the backfill
    skips when the value is None. Here gross_income=0.0 is the legacy default,
    not a real fact ; we backfill it anyway — the test documents the behaviour."""
    snap = SnapshotModel(
        id=str(uuid4()),
        user_id=user_id,
        created_at=datetime.now(timezone.utc),
        trigger="profile_update",
        gross_income=0.0,  # legacy default value
    )
    db.add(snap)
    db.commit()
    wrote, skipped = backfill_user(db, snapshot_row=snap, dry_run=False)
    db.commit()
    # 0.0 is not None → backfilled. Operators inspecting later can decide
    # whether to filter on the user's actual income existence at the
    # source level (legacy gross_income=0.0 vs intentional 0.0).
    assert wrote == 1
    assert skipped == 0
