"""Plan 02-03 PR-2 — dual-write OFF (default) test.

Asserts that with FF_FACT_EVENT_DUAL_WRITE unset (default OFF),
`create_snapshot(...)` creates exactly 1 SnapshotModel row and 0
fact_event / fact_current rows. Proves no behaviour change in
dev/staging/prod by default.
"""
from __future__ import annotations

from uuid import uuid4

import pytest

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.snapshot import SnapshotModel
from app.models.user import User
from app.services.snapshots.snapshot_service import create_snapshot
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
    u = User(
        id=uid,
        email=f"{uuid4().hex[:8]}@dualoff.test",
        hashed_password="x",
    )
    db.add(u)
    db.commit()
    return uid


def test_dual_write_default_off_creates_no_fact_rows(monkeypatch, db, user_id):
    """Default FF unset → create_snapshot writes 1 SnapshotModel, 0 facts."""
    # Defensive : explicitly delete the env var in case the test runner
    # inherited it from CI / a sibling test.
    monkeypatch.delenv("FF_FACT_EVENT_DUAL_WRITE", raising=False)

    profile_data = {
        "age": 35,
        "gross_income": 8500.0,
        "canton": "VD",
        "archetype": "swiss_native",
        "household_type": "single",
        "pillar_3a_balance": 12345.67,  # would dual-write IF flag ON
        "lpp_avoirs_vieillesse": None,
        "archetype_tags": {"tags": ["expat_eu"], "confidence_per_tag": {}},
        "coach_extracted_facts": {"facts": ["test"]},
    }
    snap = create_snapshot(
        user_id=user_id,
        trigger="profile_update",
        profile_data=profile_data,
        db=db,
    )

    # ── Assertions ─────────────────────────────────────────────────────
    # 1. SnapshotModel row exists (the legacy path is unchanged).
    snap_rows = db.query(SnapshotModel).filter(SnapshotModel.user_id == user_id).all()
    assert len(snap_rows) == 1, (
        f"expected 1 SnapshotModel row, got {len(snap_rows)}"
    )
    assert snap_rows[0].gross_income == 8500.0

    # 2. fact_event has ZERO rows for this user (dual-write OFF).
    fe_rows = db.query(FactEvent).filter(FactEvent.user_id == user_id).all()
    assert len(fe_rows) == 0, (
        f"expected 0 fact_event rows with FF OFF, got {len(fe_rows)} : "
        f"{[r.field_key for r in fe_rows]}"
    )

    # 3. fact_current has ZERO rows for this user (dual-write OFF).
    fc_rows = db.query(FactCurrent).filter(FactCurrent.user_id == user_id).all()
    assert len(fc_rows) == 0, (
        f"expected 0 fact_current rows with FF OFF, got {len(fc_rows)} : "
        f"{[r.field_key for r in fc_rows]}"
    )

    assert snap.id is not None
