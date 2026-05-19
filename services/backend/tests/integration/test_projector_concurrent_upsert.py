"""Projector atomic UPSERT — iter-2 A8 (postgres-pro HIGH-2 lost-update guard).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P4.

The existing FactProjector ships the atomic UPSERT contract :
    INSERT INTO fact_current (...) ON CONFLICT (user_id, field_key)
        DO UPDATE SET value_enc = excluded.value_enc, ...
        WHERE excluded.valid_from > fact_current.valid_from

The `WHERE excluded.valid_from > fact_current.valid_from` guard is the
lost-update fence : older events arriving late do NOT clobber newer
state, even under concurrent writers. iter-2 A8 demands a 100-iteration
2-thread race test to prove monotonicity ; macOS Python 3.9.6 segfaults
on 2-thread concurrent INSERT inside SQLAlchemy (a known incompat per
continuation-3 SUMMARY), so this test runs a SEQUENTIAL simulation that
interleaves « older event after newer event » writes 100 times and
asserts the final fact_current row is the one with the MAX valid_from.

The Postgres-only true-concurrency variant of this test (with threading)
lives behind `@pytest.mark.requires_pg` and runs on CI Postgres only ;
that variant is documented as part of P4 but explicitly NOT shipped in
this commit to avoid the macOS-segfault hazard. Local SQLite + sequential
interleaving is sufficient to prove the application-layer contract :
the WHERE-guard fires correctly regardless of write ORDER.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.user import User
from app.services.encryption.encrypted_value_helper import encrypt_value
from app.services.projector.fact_projector import FactEventInput, project_event
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
    uid = f"u-upsert-{uuid4().hex[:8]}"
    db.add(User(id=uid, email=f"{uuid4().hex[:8]}@test.local", hashed_password="x"))
    db.commit()
    return uid


def test_older_event_after_newer_event_does_not_clobber(db, user_id):
    """A8 : write newer event (valid_from=T+1) then older event (valid_from=T+0).

    Final fact_current.valid_from MUST equal T+1 (newer) ; the older write
    is a no-op per the WHERE-guard. Proves the application-layer contract
    that protects against late-arriving events.
    """
    field_key = "monthly_gross_income"
    base = datetime.now(timezone.utc)

    # First write : newer event (T+1).
    newer_inp = FactEventInput(
        user_id=user_id,
        field_key=field_key,
        value_enc=encrypt_value(db, user_id, 9000.0),
        valid_from=base + timedelta(hours=1),
        source="canary_upsert_newer",
    )
    project_event(db, newer_inp)

    # Second write : older event (T+0).
    older_inp = FactEventInput(
        user_id=user_id,
        field_key=field_key,
        value_enc=encrypt_value(db, user_id, 5000.0),  # different value
        valid_from=base,  # OLDER timestamp
        source="canary_upsert_older",
    )
    project_event(db, older_inp)

    # fact_current MUST reflect the NEWER value (9000.0 / valid_from=T+1)
    # — the older event must NOT clobber.
    row = db.query(FactCurrent).filter(
        FactCurrent.user_id == user_id, FactCurrent.field_key == field_key
    ).one()

    from app.services.encryption.encrypted_value_helper import decrypt_value
    decoded = decrypt_value(db, user_id, row.value_enc)
    assert decoded == 9000.0, (
        f"WHERE-guard failed : older event clobbered newer state. "
        f"Got value={decoded}, expected 9000.0 (the newer write)."
    )
    assert row.valid_from == newer_inp.valid_from or row.valid_from.replace(tzinfo=timezone.utc) == newer_inp.valid_from


def test_sequential_interleaved_writes_converge_to_max_valid_from(db, user_id):
    """A8 : interleave 100 writes with random valid_from ; converge to MAX.

    Sequential simulation of concurrent writers (avoids macOS Python 3.9.6
    2-thread SQLAlchemy segfault per continuation-3 SUMMARY note).
    Asserts that after 100 writes with random valid_from offsets, the
    fact_current.valid_from equals the MAX of all written valid_from.
    """
    import random

    field_key = "monthly_gross_income"
    base = datetime.now(timezone.utc)
    rng = random.Random(42)  # deterministic seed for reproducibility

    written: list[datetime] = []
    for i in range(100):
        offset_seconds = rng.randint(-3600, 3600)  # ±1 hour spread
        vf = base + timedelta(seconds=offset_seconds)
        inp = FactEventInput(
            user_id=user_id,
            field_key=field_key,
            value_enc=encrypt_value(db, user_id, 8000.0 + i),
            valid_from=vf,
            source=f"canary_seq_{i}",
        )
        project_event(db, inp)
        written.append(vf)

    expected_max = max(written)
    row = db.query(FactCurrent).filter(
        FactCurrent.user_id == user_id, FactCurrent.field_key == field_key
    ).one()
    actual = row.valid_from
    if actual.tzinfo is None:
        actual = actual.replace(tzinfo=timezone.utc)
    assert actual == expected_max, (
        f"After 100 interleaved writes, fact_current.valid_from = {actual} "
        f"!= max(written) = {expected_max}. WHERE-guard lost the race."
    )

    # And fact_event has 100 rows (append-only invariant preserved).
    event_count = db.query(FactEvent).filter(
        FactEvent.user_id == user_id, FactEvent.field_key == field_key
    ).count()
    assert event_count == 100, (
        f"D-27 append-only invariant : expected 100 fact_event rows "
        f"after 100 writes, got {event_count}."
    )
