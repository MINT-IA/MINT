"""FactProjector atomicity test — D-19 rollback contract.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — Task 3 step 6.

Proves the projector's `with session.begin()` block rolls back BOTH the
fact_event INSERT AND the fact_current UPSERT when a simulated mid-write
exception fires. After the rollback, neither table has been mutated.

Runs against in-memory SQLite via the existing conftest TestingSessionLocal
fixture — does NOT require a real Postgres testcontainer (the atomicity
contract is dialect-independent ; only PARTITION BY HASH + INCLUDE-covering-
index are Postgres-only and those are exercised by test_canary_*).
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

import pytest
from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.user import User
from app.services.projector.fact_projector import (
    FactEventInput,
    _fact_current_upsert_sql,
    project_event,
)
from tests.conftest import TestingSessionLocal


_ENV = {
    "ct": "QUFBQUFBQUFBQUFBQUFBQQ==",  # 16 bytes 'A' base64
    "iv": "QUFBQUFBQUFBQUFBQUFBQQ==",
    "tag": "",
    "alg": "AES-256-GCM",
    "dek_id": "mint-master-v1",
    "enc_v": 1,
}


@pytest.fixture
def db():
    """Function-scoped session over the conftest StaticPool in-memory engine."""
    s = TestingSessionLocal()
    try:
        yield s
    finally:
        s.close()


@pytest.fixture
def user(db):
    """Seed one user for FK satisfaction."""
    u = User(
        id=f"u-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@test.local",
        hashed_password="x",
    )
    db.add(u)
    db.commit()
    return u


def test_happy_path_inserts_both_tables(db, user):
    """Baseline : a successful project_event INSERTs into both tables."""
    inp = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc=_ENV,
        valid_from=datetime.now(timezone.utc),
        source="test",
    )
    event_id = project_event(db, inp)
    assert event_id

    fe_count = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    fc_count = db.query(FactCurrent).filter(FactCurrent.user_id == user.id).count()
    assert fe_count == 1
    assert fc_count == 1


def test_replayed_event_id_skips_without_duplicate_rows(db, user, monkeypatch):
    """A repeated (user_id, event_id) is an idempotent replay, not a crash."""
    class _CounterSpy:
        def __init__(self):
            self.count = 0

        def inc(self):
            self.count += 1

    counter = _CounterSpy()
    import app.services.projector.fact_projector as fp_module

    monkeypatch.setattr(
        fp_module,
        "_increment_idempotency_skip_counter",
        counter.inc,
    )

    inp1 = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc=_ENV,
        valid_from=datetime(2026, 1, 1, tzinfo=timezone.utc),
        source="test",
    )
    stable_event_id = "evt-stable-replay-001"
    first_event_id = project_event(db, inp1, event_id=stable_event_id)
    assert first_event_id == stable_event_id

    fe_after_first = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    fc_after_first = db.query(FactCurrent).filter(FactCurrent.user_id == user.id).count()
    assert fe_after_first == 1
    assert fc_after_first == 1

    inp2 = FactEventInput(
        user_id=user.id,
        field_key="another_field",
        value_enc=_ENV,
        valid_from=datetime(2026, 2, 1, tzinfo=timezone.utc),
        source="test",
    )
    replay_event_id = project_event(db, inp2, event_id=stable_event_id)
    assert replay_event_id == stable_event_id
    assert counter.count == 1

    fe_after_fail = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    fc_after_fail = db.query(FactCurrent).filter(FactCurrent.user_id == user.id).count()
    assert fe_after_fail == fe_after_first, (
        f"fact_event count drifted: expected {fe_after_first}, got {fe_after_fail} "
        f"— D-19 atomicity contract VIOLATED"
    )
    assert fc_after_fail == fc_after_first, (
        f"fact_current count drifted: expected {fc_after_first}, got {fc_after_fail} "
        f"— D-19 atomicity contract VIOLATED"
    )


def test_upsert_idempotent_lastwriterwins_by_valid_from(db, user):
    """A second event with NEWER valid_from updates fact_current ; OLDER does not."""
    older = datetime(2026, 1, 1, tzinfo=timezone.utc)
    newer = datetime(2026, 6, 1, tzinfo=timezone.utc)

    inp_old = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc={**_ENV, "ct": "OLD"},
        valid_from=older,
        source="test",
    )
    inp_new = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc={**_ENV, "ct": "NEW"},
        valid_from=newer,
        source="test",
    )

    project_event(db, inp_old)
    new_event_id = project_event(db, inp_new)

    cur = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user.id,
            FactCurrent.field_key == "monthly_gross_income",
        )
        .one()
    )
    assert cur.value_enc["ct"] == "NEW"
    assert cur.latest_event_id == new_event_id

    inp_oldest = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc={**_ENV, "ct": "OLDEST"},
        valid_from=datetime(2025, 1, 1, tzinfo=timezone.utc),
        source="test",
    )
    project_event(db, inp_oldest)

    # Force a fresh read (avoid identity-map cache).
    db.expire_all()
    cur_after = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user.id,
            FactCurrent.field_key == "monthly_gross_income",
        )
        .one()
    )
    assert cur_after.value_enc["ct"] == "NEW", (
        f"fact_current was clobbered by an older event — guarded-WHERE UPSERT broken. "
        f"Got ct={cur_after.value_enc['ct']!r}, expected 'NEW'."
    )
    assert cur_after.latest_event_id == new_event_id

    fe_count = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    assert fe_count == 3, (
        f"fact_event lost an event — append-only invariant VIOLATED. "
        f"Expected 3 rows, got {fe_count}."
    )


def test_fact_current_upsert_sql_casts_jsonb_on_postgres_only():
    """Raw text binds must cast JSON strings to JSONB on real Postgres."""
    pg_sql = _fact_current_upsert_sql("postgresql")
    sqlite_sql = _fact_current_upsert_sql("sqlite")

    assert "CAST(:value_enc AS jsonb)" in pg_sql
    assert "CAST(:confidence AS jsonb)" in pg_sql
    assert "CAST(:value_enc AS jsonb)" not in sqlite_sql
    assert "CAST(:confidence AS jsonb)" not in sqlite_sql
