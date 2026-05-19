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
from sqlalchemy.exc import IntegrityError

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.user import User
from app.services.projector.fact_projector import FactEventInput, project_event
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


def test_rollback_on_fact_event_failure_leaves_both_tables_empty(
    db, user, monkeypatch,
):
    """Simulate a mid-write failure on the fact_event INSERT.

    The session.flush() call inside project_event surfaces DB errors before
    the fact_current UPSERT. After the exception, neither table should have
    more rows than the baseline — the `with session.begin()` block rolled
    back the failed write.

    We force the failure by monkeypatching uuid4 inside the projector module
    so a second call produces the SAME event_id as the first ; the PK
    collision triggers IntegrityError on flush(), which the `with
    session.begin()` block MUST roll back.
    """
    inp1 = FactEventInput(
        user_id=user.id,
        field_key="monthly_gross_income",
        value_enc=_ENV,
        valid_from=datetime(2026, 1, 1, tzinfo=timezone.utc),
        source="test",
    )
    project_event(db, inp1)

    fe_after_first = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    fc_after_first = db.query(FactCurrent).filter(FactCurrent.user_id == user.id).count()
    assert fe_after_first == 1
    assert fc_after_first == 1

    import app.services.projector.fact_projector as fp_module
    existing_event_id = db.query(FactEvent.event_id).filter(
        FactEvent.user_id == user.id
    ).scalar()

    def _stub_uuid4():
        class _Stub:
            def __str__(self):
                return existing_event_id
        return _Stub()

    monkeypatch.setattr(fp_module, "uuid4", _stub_uuid4)

    inp2 = FactEventInput(
        user_id=user.id,
        field_key="another_field",
        value_enc=_ENV,
        valid_from=datetime(2026, 2, 1, tzinfo=timezone.utc),
        source="test",
    )
    with pytest.raises(IntegrityError):
        project_event(db, inp2)

    # After the rollback, sessions can be in a tainted state until the
    # outer transaction is rolled back. Issue an explicit rollback so the
    # subsequent assertion-queries can run cleanly.
    db.rollback()

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
    project_event(db, inp_new)

    cur = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user.id,
            FactCurrent.field_key == "monthly_gross_income",
        )
        .one()
    )
    assert cur.value_enc["ct"] == "NEW"

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

    fe_count = db.query(FactEvent).filter(FactEvent.user_id == user.id).count()
    assert fe_count == 3, (
        f"fact_event lost an event — append-only invariant VIOLATED. "
        f"Expected 3 rows, got {fe_count}."
    )
